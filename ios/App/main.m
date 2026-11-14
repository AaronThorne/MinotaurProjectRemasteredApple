#import <UIKit/UIKit.h>
#import <GameController/GameController.h>
#import "TrippyBackground.h"
#import "BlingTitle.h"
#import "PixelFont.h"
#import "InfoViewController.h"
#include "SDL.h"
#include "SDL_syswm.h"
#include "SDL_main.h"

extern int mpr_run_game(const char *path);
extern void mpr_capture_test_frame(void);
static NSString *selectedGame;
static UIWindow *pickerWindow;
static UIWindow *menuWindow;
static UIButton *menuButton;
static BOOL gameRunning;
static uint64_t presentedFrames;
static UIWindowScene *gameScene;
static void installMenuButton(UIWindow *window);
int mpr_mobile_gamepad_profile(void) {
    if (getenv("MPR_TEST_GAMEPAD") && (getenv("MPR_TEST_SEQUENCE") || getenv("MPR_AUTOSTART"))) {
        return 1;
    }
    for (GCController *controller in GCController.controllers) {
        if (controller.extendedGamepad != nil) return 1;
    }
    return 0;
}

int mpr_is_phone(void) { return UIDevice.currentDevice.userInterfaceIdiom==UIUserInterfaceIdiomPhone; }

@interface MinotaurSceneDelegate : UIResponder <UIWindowSceneDelegate>
@end
@implementation MinotaurSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    gameScene=(UIWindowScene *)scene;
    NSLog(@"Minotaur window scene connected");
}
@end

@interface GameMenuWindow : UIWindow
@end

@implementation GameMenuWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return [hit isDescendantOfView:menuButton] ? hit : nil;
}
@end

uint32_t mpr_screen_framebuffer(void) {
    SDL_Window *window = SDL_GL_GetCurrentWindow();
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    return window && SDL_GetWindowWMInfo(window, &info) ? info.info.uikit.framebuffer : 0;
}
void mpr_prepare_present(void) {
    if (++presentedFrames==1 || presentedFrames%300==0) fprintf(stderr,"Minotaur presented frame %llu\n",presentedFrames);
    if (presentedFrames==120 && getenv("MPR_CAPTURE_FRAME")) mpr_capture_test_frame();
    SDL_Window *window = SDL_GL_GetCurrentWindow();
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (window && SDL_GetWindowWMInfo(window, &info)) {
        UIWindow *gameWindow = info.info.uikit.window;
        if (gameRunning && gameWindow.windowScene && menuWindow.windowScene != gameWindow.windowScene) {
            installMenuButton(gameWindow);
        }
        typedef void (*Bind)(unsigned, unsigned);
        Bind bind = (Bind)SDL_GL_GetProcAddress("glBindRenderbuffer");
        if (!bind) bind = (Bind)SDL_GL_GetProcAddress("glBindRenderbufferOES");
        if (bind) bind(0x8D41, info.info.uikit.colorbuffer);
    }
}

@interface GameTile : UIButton
@property(nonatomic,strong) UIImageView *artwork;
@property(nonatomic,strong) UILabel *gameTitle;
@end
@implementation GameTile
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor colorWithRed:0.035 green:0.025 blue:0.09 alpha:0.76];
        self.layer.cornerRadius=16;
        self.layer.borderWidth=1;
        self.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.10].CGColor;
        self.artwork=[[UIImageView alloc] init];
        self.artwork.contentMode=UIViewContentModeScaleAspectFit;
        self.artwork.layer.cornerRadius=14;
        self.artwork.clipsToBounds=YES;
        self.artwork.layer.magnificationFilter=kCAFilterNearest;
        self.artwork.layer.minificationFilter=kCAFilterNearest;
        self.artwork.translatesAutoresizingMaskIntoConstraints=NO;
        self.gameTitle=[[PixelLabel alloc] init];
        self.gameTitle.textColor=UIColor.whiteColor;
        self.gameTitle.font=[UIFont systemFontOfSize:19 weight:UIFontWeightSemibold];
        self.gameTitle.textAlignment=NSTextAlignmentCenter;
        self.gameTitle.numberOfLines=2;
        self.gameTitle.adjustsFontSizeToFitWidth=YES;
        self.gameTitle.minimumScaleFactor=0.85;
        [self.gameTitle setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        [self.gameTitle.heightAnchor constraintGreaterThanOrEqualToConstant:14].active=YES;
        UIStackView *content=[[UIStackView alloc] initWithArrangedSubviews:@[self.artwork,self.gameTitle]];
        content.axis=UILayoutConstraintAxisVertical;content.alignment=UIStackViewAlignmentCenter;
        content.spacing=10;content.userInteractionEnabled=NO;content.translatesAutoresizingMaskIntoConstraints=NO;
        [self addSubview:content];
        NSLayoutConstraint *preferredSize=[self.artwork.heightAnchor constraintEqualToConstant:88];
        preferredSize.priority=UILayoutPriorityDefaultHigh;
        [NSLayoutConstraint activateConstraints:@[
            [content.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [content.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [content.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:14],
            [content.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-14],
            [content.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor constant:14],
            [content.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor constant:-14],
            [self.artwork.widthAnchor constraintEqualToAnchor:self.artwork.heightAnchor],
            [self.artwork.heightAnchor constraintLessThanOrEqualToConstant:88],
            [self.artwork.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:-32],
            [self.artwork.heightAnchor constraintLessThanOrEqualToAnchor:self.heightAnchor multiplier:0.64],
            preferredSize,
        ]];
        self.isAccessibilityElement=YES;
    }
    return self;
}
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor=highlighted?[UIColor colorWithRed:0.15 green:0.08 blue:0.26 alpha:0.94]:[UIColor colorWithRed:0.035 green:0.025 blue:0.09 alpha:0.76];
    self.artwork.alpha=highlighted?0.75:1;
}
- (void)setEnabled:(BOOL)enabled { [super setEnabled:enabled];self.alpha=enabled?1:0.4; }
@end

@interface GamePicker : UIViewController
@property(nonatomic,strong) TrippyBackground *backdrop;
@property(nonatomic,strong) BlingTitle *blingTitle;
@property(nonatomic,strong) UIScrollView *phoneScroll;
@property(nonatomic,strong) UIView *phoneContent;
@property(nonatomic,strong) NSMutableArray<GameTile *> *phoneTiles;
@property(nonatomic,strong) UILayoutGuide *pickerContent;
@end
@implementation GamePicker
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.clearColor;
    self.backdrop=[[TrippyBackground alloc] initWithFrame:self.view.bounds];
    self.backdrop.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.backdrop];
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
    configuration.title = @"Info";
    configuration.image = [UIImage systemImageNamed:@"info.circle"];
    configuration.imagePadding = 6;
    configuration.baseForegroundColor = UIColor.whiteColor;
    configuration.baseBackgroundColor = [UIColor colorWithRed:0.30 green:0.18 blue:0.55 alpha:1.0];
    UIButton *info = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    info.translatesAutoresizingMaskIntoConstraints = NO;
    info.accessibilityIdentifier = @"MinotaurInfo";
    [info addTarget:self action:@selector(showInfo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:info];

    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.text = [NSString stringWithFormat:@"Version %@", version ?: @"—"];
    versionLabel.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightRegular];
    versionLabel.textColor = UIColor.lightGrayColor;
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:versionLabel];

    self.pickerContent = [[UILayoutGuide alloc] init];
    [self.view addLayoutGuide:self.pickerContent];
    [NSLayoutConstraint activateConstraints:@[
        [info.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:4],
        [info.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-16],
        [info.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        [self.pickerContent.topAnchor constraintEqualToAnchor:info.bottomAnchor constant:4],
        [versionLabel.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-16],
        [versionLabel.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-4],
        [self.pickerContent.bottomAnchor constraintEqualToAnchor:versionLabel.topAnchor constant:-4],
        [self.pickerContent.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [self.pickerContent.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
    ]];
    if(mpr_is_phone()) { [self buildPhonePicker];return; }
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis=UILayoutConstraintAxisVertical;stack.spacing=26;stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:stack];
    UILayoutGuide *safe=self.pickerContent;
    NSLayoutConstraint *width=[stack.widthAnchor constraintEqualToAnchor:safe.widthAnchor multiplier:0.82];
    width.priority=UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *height=[stack.heightAnchor constraintEqualToConstant:760];
    height.priority=UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
        width,[stack.widthAnchor constraintLessThanOrEqualToConstant:840],
        height,[stack.heightAnchor constraintLessThanOrEqualToAnchor:safe.heightAnchor constant:-48],
    ]];
    BlingTitle *title=[[BlingTitle alloc] initWithFrame:CGRectZero];
    self.blingTitle=title;
    [title.heightAnchor constraintEqualToConstant:176].active=YES;
    [title setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [title setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [stack addArrangedSubview:title];
    UIStackView *grid=[[UIStackView alloc] init];
    grid.axis=UILayoutConstraintAxisVertical;grid.spacing=36;grid.distribution=UIStackViewDistributionFillEqually;
    [stack addArrangedSubview:grid];
    NSArray *games=@[@[@"Gridrunner",@"Gridrunner"],@[@"SuperOxWars",@"Super Ox Wars"],@[@"Minotron2112",@"Minotron 2112"],@[@"MinotaurRescue",@"Minotaur Rescue"],@[@"FiveADay",@"Five A Day"],@[@"Deflex",@"Deflex"],@[@"CavernsOfMinos",@"Caverns of Minos"],@[@"GoatUp",@"Goat Up"],@[@"GoatUp2",@"Goat Up 2"]];
    NSArray *compiled=[NSArray arrayWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"CompiledGames" withExtension:@"plist"]];
    for (int row=0;row<3;row++) {
        UIStackView *line=[[UIStackView alloc] init];line.spacing=48;line.distribution=UIStackViewDistributionFillEqually;
        for (int column=0;column<3;column++) {
            NSArray *game=games[row*3+column];GameTile *button=[[GameTile alloc] initWithFrame:CGRectZero];
            NSString *path=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Icons/%@.png",game[0]]];
            button.artwork.image=[[UIImage imageWithContentsOfFile:path] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            button.gameTitle.text=game[1];button.accessibilityIdentifier=game[0];button.accessibilityLabel=game[1];
            button.layer.borderColor=[UIColor colorWithHue:(row*3+column)/9.0 saturation:0.75 brightness:1 alpha:0.38].CGColor;
            button.enabled=[compiled containsObject:game[0]];
            [button addTarget:self action:@selector(selectGame:) forControlEvents:UIControlEventTouchUpInside];
            [line addArrangedSubview:button];
        }
        [grid addArrangedSubview:line];
    }

}
- (void)buildPhonePicker {
    self.phoneScroll=[[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.phoneScroll.backgroundColor=UIColor.clearColor;
    self.phoneScroll.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;
    self.phoneScroll.indicatorStyle=UIScrollViewIndicatorStyleWhite;
    self.phoneScroll.alwaysBounceVertical=YES;
    [self.view addSubview:self.phoneScroll];
    self.phoneContent=[[UIView alloc] init];[self.phoneScroll addSubview:self.phoneContent];
    self.blingTitle=[[BlingTitle alloc] initWithFrame:CGRectZero];[self.phoneContent addSubview:self.blingTitle];
    self.phoneTiles=[NSMutableArray array];
    NSArray *games=@[@[@"Gridrunner",@"Gridrunner"],@[@"SuperOxWars",@"Super Ox Wars"],@[@"Minotron2112",@"Minotron 2112"],@[@"MinotaurRescue",@"Minotaur Rescue"],@[@"FiveADay",@"Five A Day"],@[@"Deflex",@"Deflex"],@[@"CavernsOfMinos",@"Caverns of Minos"],@[@"GoatUp",@"Goat Up"],@[@"GoatUp2",@"Goat Up 2"]];
    NSArray *compiled=[NSArray arrayWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"CompiledGames" withExtension:@"plist"]];
    for(NSUInteger i=0;i<games.count;i++) {
        NSArray *game=games[i];GameTile *tile=[[GameTile alloc] initWithFrame:CGRectZero];
        NSString *path=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Icons/%@.png",game[0]]];
        tile.artwork.image=[[UIImage imageWithContentsOfFile:path] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        tile.gameTitle.text=game[1];tile.accessibilityIdentifier=game[0];tile.accessibilityLabel=game[1];
        tile.layer.borderColor=[UIColor colorWithHue:i/9.0 saturation:0.75 brightness:1 alpha:0.38].CGColor;
        tile.enabled=[compiled containsObject:game[0]];
        [tile addTarget:self action:@selector(selectGame:) forControlEvents:UIControlEventTouchUpInside];
        [self.phoneContent addSubview:tile];[self.phoneTiles addObject:tile];
    }

}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if(!self.phoneScroll)return;
    CGRect safe=self.pickerContent.layoutFrame;
    self.phoneScroll.frame=safe;
    CGFloat width=MIN(840,safe.size.width-32),left=(safe.size.width-width)/2;
    NSInteger columns=safe.size.width>600?3:2;
    NSInteger rows=(self.phoneTiles.count+columns-1)/columns;
    CGFloat gap=18,tileWidth=(width-gap*(columns-1))/columns,tileHeight=116;
    self.blingTitle.frame=CGRectMake(left,8,width,112);
    for(NSUInteger i=0;i<self.phoneTiles.count;i++)
        self.phoneTiles[i].frame=CGRectMake(left+(i%columns)*(tileWidth+gap),138+(i/columns)*(tileHeight+gap),tileWidth,tileHeight);
    CGFloat bottom=138+rows*tileHeight+(rows-1)*gap;
    CGFloat contentHeight=MAX(safe.size.height,bottom+20);
    self.phoneContent.frame=CGRectMake(0,0,safe.size.width,contentHeight);
    self.phoneScroll.contentSize=self.phoneContent.bounds.size;
}
- (void)showInfo {
    [self showInfoWithCredits:YES];
}
- (void)showInfoWithCredits:(BOOL)showCredits {
    InfoViewController *info = [[InfoViewController alloc] initShowingCredits:showCredits];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:info];
    navigation.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    navigation.modalPresentationStyle = mpr_is_phone() ? UIModalPresentationPageSheet : UIModalPresentationFormSheet;
    [self presentViewController:navigation animated:YES completion:nil];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.backdrop.running=!gameRunning;
    self.blingTitle.running=!gameRunning;
    const char *infoPreview = getenv("MPR_PREVIEW_INFO");
    if (infoPreview) {
        BOOL credits = strcmp(infoPreview, "credits") == 0;
        unsetenv("MPR_PREVIEW_INFO");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showInfoWithCredits:credits];
        });
    }
    if(getenv("MPR_CAPTURE_PICKER")) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,0.5*NSEC_PER_SEC),dispatch_get_main_queue(),^{[self capturePicker:@"Picker.png"];});
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3.0*NSEC_PER_SEC),dispatch_get_main_queue(),^{[self capturePicker:@"PickerLater.png"];});
    }
}
- (void)capturePicker:(NSString *)filename {
    [self.view layoutIfNeeded];
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithBounds:self.view.bounds];
    UIImage *background=[self.backdrop snapshotImage];
    UIImage *image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){
        [background drawInRect:self.view.bounds];
        self.backdrop.hidden=YES;
        [self.view.layer renderInContext:context.CGContext];
        self.backdrop.hidden=NO;
    }];
    [UIImagePNGRepresentation(image) writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:[@"Documents" stringByAppendingPathComponent:filename]] atomically:YES];
    NSLog(@"Saved picker layout verification frame %@",filename);
}
- (void)selectGame:(UIButton *)sender { selectedGame=sender.accessibilityIdentifier; }
- (void)returnToGames:(id)sender {
    if (gameRunning) { SDL_Event event={0}; event.type=SDL_QUIT; SDL_PushEvent(&event); }
}
@end

static void installMenuButton(UIWindow *window) {
    menuWindow.hidden = YES;
    menuWindow = [[GameMenuWindow alloc] initWithWindowScene:window.windowScene];
    menuWindow.windowLevel = window.windowLevel + 1;
    menuWindow.backgroundColor = UIColor.clearColor;
    menuWindow.rootViewController = [[UIViewController alloc] init];
    UIView *overlay = menuWindow.rootViewController.view;
    overlay.backgroundColor = UIColor.clearColor;
    UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
    configuration.title = @"Games";
    configuration.image = [UIImage systemImageNamed:@"chevron.left"];
    configuration.imagePadding = 5;
    configuration.baseForegroundColor = UIColor.whiteColor;
    configuration.baseBackgroundColor = [UIColor colorWithWhite:0.12 alpha:0.92];
    menuButton = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    menuButton.accessibilityIdentifier = @"ReturnToGames";
    menuButton.accessibilityLabel = @"Return to games";
    menuButton.translatesAutoresizingMaskIntoConstraints = NO;
    [menuButton addTarget:pickerWindow.rootViewController action:@selector(returnToGames:) forControlEvents:UIControlEventTouchUpInside];
    [overlay addSubview:menuButton];
    UILayoutGuide *safeArea = overlay.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [menuButton.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:8],
        [menuButton.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:12],
        [menuButton.heightAnchor constraintGreaterThanOrEqualToConstant:44]
    ]];
    menuWindow.hidden = NO;
}

static int collectionMain(int argc, char **argv) {
    @autoreleasepool {
        GamePicker *picker=[[GamePicker alloc] init];
        while (!gameScene) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        pickerWindow=[[UIWindow alloc] initWithWindowScene:gameScene];
        pickerWindow.rootViewController=picker;
        [picker loadViewIfNeeded];
        NSString *autostart=getenv("MPR_AUTOSTART") ? @(getenv("MPR_AUTOSTART")) : nil;
        NSMutableArray *sequence=getenv("MPR_TEST_SEQUENCE") ? [[@(getenv("MPR_TEST_SEQUENCE")) componentsSeparatedByString:@","] mutableCopy] : nil;
        while (YES) {
            UIApplication.sharedApplication.idleTimerDisabled=YES;
            selectedGame=autostart; autostart=nil;
            if(sequence.count){selectedGame=sequence.firstObject;[sequence removeObjectAtIndex:0];}
            [picker.backdrop shuffleSprites];
            pickerWindow.hidden=NO;[pickerWindow makeKeyAndVisible];
            picker.backdrop.running=YES;
            picker.blingTitle.running=YES;
            while (!selectedGame) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            NSString *game=selectedGame;
            NSLog(@"Starting game %@",game);
            NSString *resource=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Runtime"];
            NSURL *support=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
            NSURL *data=[support URLByAppendingPathComponent:[@"Games" stringByAppendingPathComponent:game]];
            NSError *error=nil;
            if (![NSFileManager.defaultManager fileExistsAtPath:data.path]) {
                [NSFileManager.defaultManager createDirectoryAtURL:data.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error];
                NSURL *seed=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:[@"GameData" stringByAppendingPathComponent:game]];
                if (!error) [NSFileManager.defaultManager copyItemAtURL:seed toURL:data error:&error];
            }
            if (error) { NSLog(@"Could not prepare game: %@",error); continue; }
            setenv("MPR_RESOURCE_DIR",resource.fileSystemRepresentation,1);
            setenv("MPR_DATA_DIR",data.path.fileSystemRepresentation,1);
            setenv("MPR_GAME_ID",game.UTF8String,1);
            NSString *ipa=[[data.path stringByAppendingPathComponent:@"touchHLE_apps"] stringByAppendingPathComponent:[game stringByAppendingString:@".ipa"]];
            picker.backdrop.running=NO;
            picker.blingTitle.running=NO;
            pickerWindow.hidden=YES; gameRunning=YES;presentedFrames=0;
            if (getenv("MPR_SMOKE_SECONDS")) {
                int seconds=atoi(getenv("MPR_SMOKE_SECONDS"));
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)seconds*NSEC_PER_SEC),dispatch_get_main_queue(),^{
                    UIWindow *window = menuButton.window;
                    if (!gameRunning || selectedGame != game || !window) return;
                    [window layoutIfNeeded];
                    CGRect bounds = menuButton.bounds;
                    CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
                    center = [menuButton convertPoint:center toView:window];
                    CGPoint outside = CGPointMake(CGRectGetMidX(window.bounds), CGRectGetMidY(window.bounds));
                    if ([[window hitTest:center withEvent:nil] isDescendantOfView:menuButton] &&
                        ![window hitTest:outside withEvent:nil]) {
                        [menuButton sendActionsForControlEvents:UIControlEventTouchUpInside];
                    } else {
                        NSLog(@"Games button hit testing failed in %@", game);
                    }
                });
            }
            mpr_run_game(ipa.fileSystemRepresentation);
            NSLog(@"Returned to game picker from %@",game);
            gameRunning=NO;menuWindow.hidden=YES;menuWindow=nil;menuButton=nil;
        }
    }
    return 0;
}

#undef main
int main(int argc, char **argv) { return SDL_UIKitRunApp(argc,argv,collectionMain); }
