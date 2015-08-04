/*
 
 Erica Sadun, http://ericasadun.com
 iOS 7 Cookbook
 Use at your own risk. Do no harm.
 
 */

#import "MWSTouchOverlayView.h"

@implementation MWSTouchOverlayView

// Basic Touches processing

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
//    [self sendEvent:event];
    if ([_delegate respondsToSelector:@selector(touchesBegan:withEvent:)])
        [_delegate touchesBegan:touches withEvent:event];

}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
//    [self sendEvent:event];
    if ([_delegate respondsToSelector:@selector(touchesMoved:withEvent:)])
        [_delegate touchesMoved:touches withEvent:event];

}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
//    [self sendEvent:event];
    if ([_delegate respondsToSelector:@selector(touchesEnded:withEvent:)])
        [_delegate touchesEnded:touches withEvent:event];

}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
//    [self sendEvent:event];
    if ([_delegate respondsToSelector:@selector(touchesCancelled:withEvent:)])
        [_delegate touchesCancelled:touches withEvent:event];
}

//- (void)sendEvent:(UIEvent *)event
//{
//	NSSet *touches = [event allTouches];
//	NSMutableSet *began = nil;
//	NSMutableSet *moved = nil;
//	NSMutableSet *ended = nil;
//	NSMutableSet *cancelled = nil;
//	
//	// sort the touches by phase so we can handle them similarly to normal event dispatch
//	for (UITouch *touch in touches) {
//		switch ([touch phase]) {
//			case UITouchPhaseBegan:
//				if (!began) began = [NSMutableSet set];
//				[began addObject:touch];
//				break;
//			case UITouchPhaseMoved:
//				if (!moved) moved = [NSMutableSet set];
//				[moved addObject:touch];
//				break;
//			case UITouchPhaseEnded:
//				if (!ended) ended = [NSMutableSet set];
//				[ended addObject:touch];
//				break;
//			case UITouchPhaseCancelled:
//				if (!cancelled) cancelled = [NSMutableSet set];
//				[cancelled addObject:touch];
//				break;
//			default:
//				break;
//		}
//	}
//    
//	// call delegate methods to handle the touches
//	if (began && [_delegate respondsToSelector:@selector(touchesBegan:withEvent:)])
//        [_delegate touchesBegan:began withEvent:event];
//	if (moved && [_delegate respondsToSelector:@selector(touchesMoved:withEvent:)])
//        [_delegate touchesMoved:moved withEvent:event];
//	if (ended && [_delegate respondsToSelector:@selector(touchesEnded:withEvent:)])
//        [_delegate touchesEnded:ended withEvent:event];
//	if (cancelled && [_delegate respondsToSelector:@selector(touchesCancelled:withEvent:)])
//        [_delegate touchesCancelled:cancelled withEvent:event];
//}

@end
