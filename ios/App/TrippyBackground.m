#import "TrippyBackground.h"
#import <MetalKit/MetalKit.h>
#import <CoreImage/CoreImage.h>
#import <simd/simd.h>

typedef struct {
    vector_float2 resolution;
    float time;
    float motion;
    vector_uint4 sprites;
} BackgroundUniforms;

@interface TrippyBackground () <MTKViewDelegate>
@property(nonatomic,strong) MTKView *canvas;
@property(nonatomic,strong) id<MTLCommandQueue> queue;
@property(nonatomic,strong) id<MTLRenderPipelineState> pipeline;
@property(nonatomic,copy) NSArray<id<MTLTexture>> *spriteSheets;
@property(nonatomic) vector_uint4 sprites;
@property(atomic,strong) id<MTLTexture> lastFrame;
@property(nonatomic) CFTimeInterval started;
@end

@implementation TrippyBackground
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.userInteractionEnabled=NO;
        self.backgroundColor=[UIColor colorWithRed:0.025 green:0.01 blue:0.065 alpha:1];
        id<MTLDevice> device=MTLCreateSystemDefaultDevice();
        if(!device)return self;
        MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:device];
        MTLTextureDescriptor *fallbackDescriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:NO];
        id<MTLTexture> fallback = [device newTextureWithDescriptor:fallbackDescriptor];
        if (!fallback) return self;
        NSMutableArray<id<MTLTexture>> *sheets = [NSMutableArray array];
        for (NSString *name in @[@"PickerCamels", @"PickerFighter", @"PickerInvader", @"PickerWhiteCamel", @"PickerGoat"]) {
            NSURL *url = [NSBundle.mainBundle URLForResource:name withExtension:@"png" subdirectory:@"Icons"];
            id<MTLTexture> sheet = url ? [loader newTextureWithContentsOfURL:url
                options:@{MTKTextureLoaderOptionOrigin: MTKTextureLoaderOriginTopLeft, MTKTextureLoaderOptionSRGB: @NO}
                error:NULL] : nil;
            [sheets addObject:sheet ?: fallback];
        }
        self.spriteSheets = sheets;
        self.canvas=[[MTKView alloc] initWithFrame:self.bounds device:device];
        self.canvas.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.canvas.colorPixelFormat=MTLPixelFormatBGRA8Unorm;
        self.canvas.preferredFramesPerSecond=30;
        self.canvas.autoResizeDrawable=NO;
        self.canvas.framebufferOnly=getenv("MPR_CAPTURE_PICKER")==NULL;
        self.canvas.clearColor=MTLClearColorMake(0.025,0.01,0.065,1);
        self.canvas.paused=YES;
        self.canvas.delegate=self;
        self.queue=[device newCommandQueue];
        NSError *error=nil;
        id<MTLLibrary> library=[device newDefaultLibrary];
        MTLRenderPipelineDescriptor *descriptor=[[MTLRenderPipelineDescriptor alloc] init];
        descriptor.vertexFunction=[library newFunctionWithName:@"minotaurBackgroundVertex"];
        descriptor.fragmentFunction=[library newFunctionWithName:@"minotaurBackgroundFragment"];
        descriptor.colorAttachments[0].pixelFormat=self.canvas.colorPixelFormat;
        if(library)self.pipeline=[device newRenderPipelineStateWithDescriptor:descriptor error:&error];
        if(!self.pipeline){NSLog(@"Background renderer could not start: %@",error);return self;}
        [self addSubview:self.canvas];
        self.started=CACurrentMediaTime();
        NSNotificationCenter *notifications=NSNotificationCenter.defaultCenter;
        for(NSString *name in @[UIApplicationDidEnterBackgroundNotification,UIApplicationDidBecomeActiveNotification,UIAccessibilityReduceMotionStatusDidChangeNotification])
            [notifications addObserver:self selector:@selector(updateAnimation:) name:name object:nil];
        NSLog(@"Psychedelic picker background ready");
    }
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)shuffleSprites {
    vector_uint4 previous = self.sprites;
    vector_uint4 next;
    do {
        uint32_t choices[] = {1, 2, 3, 6, 7, 9, 11};
        for (uint32_t index = 0; index < 4; index++) {
            uint32_t pick = index + arc4random_uniform(7 - index);
            next[index] = choices[pick];
            choices[pick] = choices[index];
        }
    } while (simd_equal(next, previous));
    self.sprites = next;
    if (getenv("MPR_CAPTURE_PICKER")) {
        NSLog(@"Picker sprites %u %u %u %u", next[0], next[1], next[2], next[3]);
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    // The soft background needs fewer pixels than the sharp UIKit icons.
    self.canvas.drawableSize=CGSizeMake(MAX(1,self.bounds.size.width*0.85),MAX(1,self.bounds.size.height*0.85));
    if(self.running)[self.canvas draw];
}
- (void)setRunning:(BOOL)running { _running=running;[self updateAnimation:nil]; }
- (void)updateAnimation:(NSNotification *)notification {
    BOOL background=UIApplication.sharedApplication.applicationState==UIApplicationStateBackground || [notification.name isEqualToString:UIApplicationDidEnterBackgroundNotification];
    self.canvas.paused=!self.running || background || UIAccessibilityIsReduceMotionEnabled();
    if(getenv("MPR_CAPTURE_PICKER"))NSLog(@"Picker background %@",self.canvas.paused?@"paused/static":@"animating");
    if(self.running && !background)[self.canvas draw];
}
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}
- (void)drawInMTKView:(MTKView *)view {
    if(!self.pipeline)return;
    MTLRenderPassDescriptor *pass=view.currentRenderPassDescriptor;
    id<CAMetalDrawable> drawable=view.currentDrawable;
    if(!pass || !drawable)return;
    BackgroundUniforms uniforms = {
        {view.drawableSize.width, view.drawableSize.height},
        (float)(CACurrentMediaTime() - self.started),
        UIAccessibilityIsReduceMotionEnabled() ? 0 : 1,
        self.sprites
    };
    id<MTLCommandBuffer> command=[self.queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder=[command renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:self.pipeline];
    [encoder setFragmentBytes:&uniforms length:sizeof(uniforms) atIndex:0];
    for (NSUInteger i = 0; i < self.spriteSheets.count; i++) {
        [encoder setFragmentTexture:self.spriteSheets[i] atIndex:i];
    }
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];
    if(getenv("MPR_CAPTURE_PICKER")) {
        __weak TrippyBackground *weakSelf=self;
        id<MTLTexture> texture=drawable.texture;
        [command addCompletedHandler:^(id<MTLCommandBuffer> buffer){weakSelf.lastFrame=texture;}];
    }
    [command presentDrawable:drawable];[command commit];
}
- (UIImage *)snapshotImage {
    id<MTLTexture> texture=self.lastFrame;
    if(!texture)return nil;
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
    CIImage *image=[CIImage imageWithMTLTexture:texture options:@{kCIImageColorSpace:(__bridge id)colorSpace}];
    CGColorSpaceRelease(colorSpace);
    if(!image)return nil;
    image=[image imageByApplyingTransform:CGAffineTransformMake(1,0,0,-1,0,image.extent.size.height)];
    CIContext *context=[CIContext contextWithMTLDevice:self.canvas.device];
    CGImageRef rendered=[context createCGImage:image fromRect:image.extent];
    UIImage *result=rendered?[UIImage imageWithCGImage:rendered]:nil;
    if(rendered)CGImageRelease(rendered);
    return result;
}
@end
