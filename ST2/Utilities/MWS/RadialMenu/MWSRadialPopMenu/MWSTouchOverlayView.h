

@import UIKit;

@class MWSTouchOverlayView;

@protocol TouchOverlayDelegate <NSObject>
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
@end

@interface MWSTouchOverlayView : UIView

@property (nonatomic, weak) id<TouchOverlayDelegate> delegate;

@end
