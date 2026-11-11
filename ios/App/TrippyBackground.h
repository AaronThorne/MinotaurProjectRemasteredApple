#import <UIKit/UIKit.h>

@interface TrippyBackground : UIView
@property(nonatomic) BOOL running;
- (void)shuffleSprites;
- (UIImage *)snapshotImage;
@end
