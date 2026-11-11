#import "BlingTitle.h"
#import "PixelFont.h"

static void FillDisplayRows(CGContextRef context, CGRect rect, CGFloat coverage) {
    if (rect.size.width <= 0 || rect.size.height <= 0 || coverage <= 0) return;
    CGContextSetAlpha(context, coverage);
    CGContextFillRect(context, CGContextConvertRectToUserSpace(context, rect));
}

// Snap the columns horizontally and blend the first and last display rows
// of each vertical run, so the square cells stay solid as the letters move.
static void DrawMovingGlyph(CGContextRef context, unichar character, CGPoint origin,
                            CGFloat pixel, UIColor *colour) {
    const uint8_t *rows = PixelGlyph(character);
    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, colour.CGColor);
    for (int column = 0; column < 5; column++) {
        int first = -1;
        for (int row = 0; row <= 7; row++) {
            BOOL lit = row < 7 && (rows[row] & (1 << (4 - column)));
            if (lit) {
                if (first < 0) first = row;
            } else if (first >= 0) {
                CGRect rect = CGContextConvertRectToDeviceSpace(context, CGRectMake(
                    origin.x + column * pixel, origin.y + first * pixel,
                    pixel, (row - first) * pixel));
                CGFloat left = round(CGRectGetMinX(rect));
                CGFloat width = round(CGRectGetMaxX(rect)) - left;
                CGFloat low = floor(CGRectGetMinY(rect));
                CGFloat high = floor(CGRectGetMaxY(rect));
                if (low == high) {
                    FillDisplayRows(context, CGRectMake(left, low, width, 1), rect.size.height);
                } else {
                    FillDisplayRows(context, CGRectMake(left, low, width, 1), low + 1 - CGRectGetMinY(rect));
                    FillDisplayRows(context, CGRectMake(left, low + 1, width, high - low - 1), 1);
                    FillDisplayRows(context, CGRectMake(left, high, width, 1), CGRectGetMaxY(rect) - high);
                }
                first = -1;
            }
        }
    }
    CGContextRestoreGState(context);
}

@class BlingTitle;
@interface BlingClock : NSObject
@property(nonatomic,weak) BlingTitle *owner;
- (void)tick:(CADisplayLink *)link;
@end

@interface BlingTitle ()
@property(nonatomic,strong) CADisplayLink *clock;
@property(nonatomic,strong) BlingClock *clockTarget;
@property(nonatomic) CFTimeInterval started;
@end

@implementation BlingClock
- (void)tick:(CADisplayLink *)link { [self.owner setNeedsDisplay]; }
@end

@implementation BlingTitle
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=UIColor.clearColor;self.opaque=NO;self.userInteractionEnabled=NO;
        self.isAccessibilityElement=YES;self.accessibilityLabel=@"Minotaur Project";
        self.accessibilityTraits=UIAccessibilityTraitHeader;
        self.started=CACurrentMediaTime();
        self.clockTarget=[[BlingClock alloc] init];self.clockTarget.owner=self;
        self.clock=[CADisplayLink displayLinkWithTarget:self.clockTarget selector:@selector(tick:)];
        self.clock.preferredFramesPerSecond=60;self.clock.paused=YES;
        [self.clock addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        for(NSString *name in @[UIApplicationDidEnterBackgroundNotification,UIApplicationDidBecomeActiveNotification,UIAccessibilityReduceMotionStatusDidChangeNotification])
            [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateAnimation:) name:name object:nil];
    }
    return self;
}
- (void)dealloc { [self.clock invalidate];[NSNotificationCenter.defaultCenter removeObserver:self]; }
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric,176); }
- (void)layoutSubviews { [super layoutSubviews];[self setNeedsDisplay]; }
- (void)setRunning:(BOOL)running { _running=running;[self updateAnimation:nil]; }
- (void)updateAnimation:(NSNotification *)notification {
    BOOL background=UIApplication.sharedApplication.applicationState==UIApplicationStateBackground || [notification.name isEqualToString:UIApplicationDidEnterBackgroundNotification];
    self.clock.paused=!self.running || background || UIAccessibilityIsReduceMotionEnabled();
    if(getenv("MPR_CAPTURE_PICKER"))NSLog(@"Bling title %@",self.clock.paused?@"paused/static":@"animating");
    [self setNeedsDisplay];
}
- (UIColor *)colour:(CGFloat)hue alpha:(CGFloat)alpha {
    return [UIColor colorWithHue:hue-floor(hue) saturation:0.82 brightness:1 alpha:alpha];
}
- (void)drawRect:(CGRect)rect {
    CGContextRef context=UIGraphicsGetCurrentContext();
    CGContextSetShouldAntialias(context,false);
    // Keep the same pixel artwork and wave proportions in a shorter phone header.
    CGFloat scale=MIN(1,self.bounds.size.height/176);
    CGContextScaleCTM(context,scale,scale);
    BOOL still=UIAccessibilityIsReduceMotionEnabled();
    CGFloat t=still?2.5:CACurrentMediaTime()-self.started;
    CGFloat width=self.bounds.size.width/scale,mid=width/2;
    NSString *word=@"MINOTAUR";
    CGFloat pixel=MAX(4,MIN(10,floor((width-80)/47)));
    CGFloat wordWidth=PixelTextWidth(word,pixel),left=round(mid-wordWidth/2);
    for(NSUInteger i=0;i<word.length;i++) {
        NSString *letter=[word substringWithRange:NSMakeRange(i,1)];
        const uint8_t *rows=PixelGlyph([word characterAtIndex:i]);
        // Continuous travelling sine waves, sampled at 60 Hz. Keep the glyphs
        // square while their positions move smoothly through the whole bounce.
        CGFloat x=left+i*6*pixel+(still?0:3*sin(t*0.75)+2*sin(t*1.5-i*0.35));
        CGFloat y=24+(still?0:16*sin(t*2.7-i*0.82)+4.5*sin(t*4.05+i*0.58)+3.5*sin(t*1.15));
        DrawPixelText(context,letter,CGPointMake(x+3,y+4),pixel,[UIColor colorWithWhite:0 alpha:0.88]);
        if(!still)for(int echo=2;echo>=1;echo--) {
            CGFloat lag=t-echo*0.11;
            CGFloat trailX=left+i*6*pixel+3*sin(lag*0.75)+2*sin(lag*1.5-i*0.35);
            CGFloat trailY=24+16*sin(lag*2.7-i*0.82)+4.5*sin(lag*4.05+i*0.58)+3.5*sin(lag*1.15);
            DrawPixelText(context,letter,CGPointMake(trailX,trailY),pixel,[self colour:i*0.10+t*0.055+echo*0.17 alpha:echo==1?0.25:0.12]);
        }
        for(int row=0;row<7;row++) {
            // Hard palette bands, without bevels or smooth font outlines.
            UIColor *colour=[self colour:row/8.0+i*0.025+t*0.055 alpha:1];
            CGContextSetFillColorWithColor(context,colour.CGColor);
            for(int column=0;column<5;column++)if(rows[row]&(1<<(4-column)))
                CGContextFillRect(context,CGRectMake(x+column*pixel,y+row*pixel,pixel,pixel));
        }
    }
    NSString *project = @"PROJECT";
    CGFloat projectPixel = MIN(5, pixel);
    CGFloat projectWidth = (project.length * 7 - 2) * projectPixel;
    CGFloat projectLeft = round(mid - projectWidth / 2);
    for (NSUInteger i = 0; i < project.length; i++) {
        unichar letter = [project characterAtIndex:i];
        CGFloat x = projectLeft + i * 7 * projectPixel;
        CGFloat y = 125 + (still ? 0 : 3 * sin(t * 1.85 - i * 0.52 + 1.5));
        CGFloat hue = 0.51 + 0.045 * i + (still ? 0 : 0.04 * sin(t * 1.5));
        UIColor *ink = [UIColor colorWithHue:hue saturation:0.42 brightness:1 alpha:1];
        DrawMovingGlyph(context, letter, CGPointMake(x + 2, y + 3), projectPixel,
                        [UIColor colorWithWhite:0 alpha:0.88]);
        DrawMovingGlyph(context, letter, CGPointMake(x, y), projectPixel, ink);
    }
    for(int i=0;i<6;i++) {
        CGFloat side=i<3?-1:1;
        CGFloat x=mid+side*(wordWidth/2+22+(i%3)*16)+3*sin(t*1.1+i);
        CGFloat y=62+15*sin(t*1.8+i*0.9);
        if(x<8||x>width-8)continue;
        CGContextSetFillColorWithColor(context,[self colour:i/6.0+t*0.04 alpha:0.9].CGColor);
        CGContextFillRect(context,CGRectMake(x-2,y-6,4,12));
        CGContextFillRect(context,CGRectMake(x-6,y-2,12,4));
    }
    // Three interlaced sine ribbons run below the title.
    CGFloat span=MIN(width-40,wordWidth+70);
    for(int band=0;band<3;band++)for(int i=0;i<span/3;i++) {
        CGFloat x=mid-span/2+i*3;
        CGFloat y=170+2.5*sin(i*0.12-t*(2.0+band*0.22)+band*2.1)+sin(i*0.06+t*0.8);
        CGContextSetFillColorWithColor(context,[self colour:band/3.0+i/(span/3.0)*0.3+t*0.045 alpha:0.8].CGColor);
        CGContextFillRect(context,CGRectMake(x,y,3,1.5));
    }
}
@end
