#import <UIKit/UIKit.h>
const uint8_t *PixelGlyph(unichar character);
CGFloat PixelTextWidth(NSString *text,CGFloat pixel);
void DrawPixelText(CGContextRef context,NSString *text,CGPoint origin,CGFloat pixel,UIColor *colour);
@interface PixelLabel : UILabel
@end
