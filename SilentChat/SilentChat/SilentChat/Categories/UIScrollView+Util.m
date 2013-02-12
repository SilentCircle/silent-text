/*
Copyright © 2012-2013, Silent Circle, LLC.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal 
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
//
//  UIScrollView+Util.m
//  

#import "UIScrollView+Util.h"

@implementation UIScrollView (Util)

- (CGRect)zoomRectForScale:(float)scale withCenter:(CGPoint)center {
	
	CGRect zoomRect;
	
	// the zoom rect is in the content view's coordinates. 
	//    At a zoom scale of 1.0, it would be the size of the imageScrollView's bounds.
	//    As the zoom scale decreases, so more content is visible, the size of the rect grows.
	
	zoomRect.size.height = self.frame.size.height / scale;
	zoomRect.size.width  = self.frame.size.width  / scale;
	
	// choose an origin so as to get the right center.
	zoomRect.origin.x    = center.x / self.zoomScale - (zoomRect.size.width  / 2.0);
	zoomRect.origin.y    = center.y / self.zoomScale - (zoomRect.size.height / 2.0);
    
	return zoomRect;
}

- (void) prepStandardScrollViewGesturesWithSingleTapTarget:(id) target action:(SEL) action
{
	UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:target action:action];
	[self addGestureRecognizer:singleTap];
//	[singleTap release];
	
	UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
	[doubleTap setNumberOfTapsRequired: 2];
	[singleTap requireGestureRecognizerToFail:doubleTap];
	[self addGestureRecognizer:doubleTap];
//	[doubleTap release];
	
	UITapGestureRecognizer *twoFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerTap:)];
	[twoFingerTap setNumberOfTouchesRequired: 2];
	[self addGestureRecognizer:twoFingerTap];
//	[twoFingerTap release];
	
	UITapGestureRecognizer *threeFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleThreeFingerTap:)];
	[threeFingerTap setNumberOfTouchesRequired: 3];
	[self addGestureRecognizer:threeFingerTap];
//	[threeFingerTap release];
	
}
// MARK: GestureRecognizers
#define kZoomStep 2.0
- (void)handleDoubleTap:(UIGestureRecognizer *)gestureRecognizer {
//	// double tap zooms in
	float newScale = [self zoomScale] * kZoomStep;
	CGRect zoomRect = [self zoomRectForScale:newScale withCenter:[gestureRecognizer locationInView:self]];//[self viewForZoomingInScrollView:scrollView]]];
	[self zoomToRect:zoomRect animated:YES];
}
- (void)handleTwoFingerTap:(UIGestureRecognizer *)gestureRecognizer {
	// two-finger tap zooms out
	[self setZoomScale: self.zoomScale / kZoomStep animated:YES];
}

- (void)handleThreeFingerTap:(UIGestureRecognizer *)gestureRecognizer {
	// three-finger tap
	if (self.zoomScale == 1.0)
		[self setZoomScale: self.minimumZoomScale animated:YES];
	else
		[self setZoomScale: 1.0 animated:YES];
}

@end
