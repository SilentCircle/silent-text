/*
Copyright (C) 2013-2015, Silent Circle, LLC. All rights reserved.

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
//  STBubbleView.m
//  SilentText
//
//  Created by mahboud on 12/3/12.
//

#import "STBubbleView.h"
#import <QuartzCore/QuartzCore.h>

@interface STBubbleView ()
//#ifdef done_using_an_imageview
//@property (nonatomic, strong) UIImageView *mediaImageView;
//#endif
@end

@implementation STBubbleView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
//#ifdef done_with_media_image_drawn_into_calayer
//		self.mediaLayer = [CALayer layer];
//		_mediaLayer.backgroundColor = [UIColor clearColor].CGColor;
//		// shadow
//		//		_mediaLayer.shadowOffset = CGSizeMake(0, 3);
//		//		_mediaLayer.shadowRadius = 5.0;
//		//		_mediaLayer.shadowColor = [UIColor blackColor].CGColor;
//		//		_mediaLayer.shadowOpacity = 0.8;
//		// frame
//		//		_mediaLayer.frame = CGRectZero;
//		//		_mediaLayer.borderColor = [UIColor blackColor].CGColor;
//		//		_mediaLayer.borderWidth = 1.0;
//		_mediaLayer.cornerRadius = 10.0;
//		[self.layer addSublayer:_mediaLayer];
//		
//		self.mediaImageLayer = [CALayer layer];
//		_mediaImageLayer.cornerRadius = 10.0;
//		_mediaImageLayer.masksToBounds = YES;
//		//		_mediaImageLayer.bounds = CGRectZero;
//		[_mediaLayer addSublayer:_mediaImageLayer];
//#endif
//#ifdef done_using_an_imageview
//		self.mediaImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
//		self.mediaImageView.layer.cornerRadius = 10.0;
//		self.mediaImageView.layer.masksToBounds = YES;
//		self.mediaImageView.autoresizingMask = UIViewAutoresizingNone;
//		[self addSubview: self.mediaImageView];
//#endif
		[self reset];
    }
    return self;
}

- (void) reset
{
	self.opaque = NO;
	self.backgroundColor = [UIColor clearColor];
	self.transform = CGAffineTransformIdentity;
	self.userInteractionEnabled = YES;
	self.alpha = 1.0;

//#ifdef done_using_an_imageview
//	self.image = nil;
//#endif
	self.mediaImage = nil;
	self.mediaFrame = CGRectZero;
	self.transform = CGAffineTransformIdentity;
//#ifdef done_with_media_image_drawn_into_calayer
//	_mediaImageLayer.contents = nil;
//#endif
}


- (void)setMediaFrame:(CGRect)mediaFrame
{
	_mediaFrame = mediaFrame;
//#ifdef done_with_media_image_drawn_into_calayer
//	//	[CATransaction begin];
//	//	[CATransaction setDisableActions:YES];
//	//	_mediaLayer.frame = mediaFrame;
//	//	_mediaImageLayer.frame = _mediaLayer.bounds;
//	//	[CATransaction commit];
//#endif
//#ifdef done_using_an_imageview
//	_mediaImageView.frame = mediaFrame;
//#endif
	[self setNeedsDisplay];
}
- (void)setBubbleImage:(UIImage *)bubbleImage
{
	[self setNeedsDisplay];
}
- (void)setSelected:(BOOL)selected
{
	_selected = selected;
	[self setNeedsDisplay];
}
- (void)setMediaImage:(UIImage *)mediaImage
{
	_mediaImage = mediaImage;
//#ifdef done_using_an_imageview
//	_mediaImageView.image = mediaImage;
//#endif
	if (mediaImage) {
//#ifdef done_with_media_image_drawn_into_calayer
//		//		[CATransaction begin];
//		//		[CATransaction setDisableActions:YES];
//		//
//		//		_mediaImageLayer.contents = (id) mediaImage.CGImage;
//		//		[CATransaction commit];
//#endif
		[self setNeedsDisplay];
	}
}

CGPathRef CreateBubblePath(CGRect rect, BOOL rightPointing, BOOL skipPoint)
{
	CGMutablePathRef		path;
	CGFloat 	cornerRadius = 10,
	calloutRadius = 21;
	if (skipPoint) {
		rect = CGRectInset(rect, 1, 1);
	}
	// Draw and fill the bubble
	path = CGPathCreateMutable();
	CGFloat minX = CGRectGetMinX(rect);
	CGFloat maxX = CGRectGetMaxX(rect);
	CGFloat minY = CGRectGetMinY(rect);
	CGFloat maxY = CGRectGetMaxY(rect);
	
	if (rightPointing)	 {
		maxX -= calloutRadius;
	}
	else {
		minX += calloutRadius;
	}
	CGPathMoveToPoint(path, nil, minX + cornerRadius, minY);
	//	CGContextMoveToPoint(context, minX + cornerRadius, minY);
	//	CGContextAddArcToPoint(context, maxX, minY, maxX, minY + cornerRadius, cornerRadius);
	CGPathAddArcToPoint(path, nil, maxX, minY, maxX, maxY, cornerRadius);
	if (skipPoint) {
		CGPathAddArcToPoint(path, nil, maxX, maxY, minX, maxY, cornerRadius);
		CGPathAddArcToPoint(path, nil, minX, maxY, minX, minY, cornerRadius);
	}
	else if (rightPointing) {
		CGPathAddArcToPoint(path, nil, maxX, maxY,
							maxX + calloutRadius, maxY, calloutRadius);
		CGPathAddArcToPoint(path, nil, minX, maxY, minX, maxY - cornerRadius, cornerRadius);
	}
	else {
		CGPathAddArcToPoint(path, nil, maxX, maxY, minX /**- calloutRadius**/, maxY, cornerRadius);
		CGPathAddLineToPoint(path, nil, minX - calloutRadius, maxY);
		CGPathAddArcToPoint(path, nil, minX, maxY, minX, maxY - calloutRadius, calloutRadius);
	}
	
	CGPathAddArcToPoint(path, nil, minX, minY, minX + cornerRadius, minY, cornerRadius);
	CGPathCloseSubpath(path);
	CGPathRef				ret;
	ret = CGPathCreateCopy(path);
	CGPathRelease(path);
	return ret;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
	
	CGFloat strokeWidth = 0.2;
	
	CGRect rrect = CGRectInset(rect, 1, 1);
	//	rrect = rect;
	// Get the context
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetShouldAntialias (context, YES);
	CGContextSetLineWidth(context, strokeWidth);
	CGContextSetAlpha(context, 1.0);

    CGContextSetStrokeColorWithColor(context,
                                     _selected?_bubbleSelectionColor.CGColor:_bubbleBorderColor.CGColor);
 	
	CGPathRef path = CreateBubblePath(rrect, _authorTypeSelf, NO);
	if (_mediaImage) {
		CGContextSaveGState(context);
		CGContextAddPath(context, path);
		CGContextSetFillColorWithColor(context, _bubbleColor.CGColor);
		CGContextFillPath(context);
		CGPathRef path2 = CreateBubblePath(rrect, _authorTypeSelf, YES);
		
//*** 	to color them with the natural bubble color instead of white:
//  take this out if we no longer want any inside part of the bubble showing under the image
//		CGContextAddPath(context, path2);
// 		CGContextSetFillColorWithColor(context, _bubbleColor.CGColor);
//		CGContextFillPath(context);
//***
		
		CGContextAddPath(context, path2);
		CGContextClip(context);
		// flip the context and then draw the image
		CGAffineTransform transform = CGAffineTransformConcat(CGAffineTransformIdentity, CGAffineTransformMakeScale(1.0, -1.0));
		transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(0.0, _mediaFrame.size.height + _mediaFrame.origin.y));
		CGRect mediaRect = _mediaFrame;
		mediaRect.origin.y = 0;
		CGContextConcatCTM(context, transform);
		CGContextDrawImage(context, mediaRect, _mediaImage.CGImage);
		CGContextRestoreGState(context);
		CGContextAddPath(context, path);
		CGContextStrokePath(context);
		CGPathRelease(path2);
	}
	else {
		CGContextSetFillColorWithColor(context, _bubbleColor.CGColor);
		CGContextAddPath(context, path);
		CGContextDrawPath(context, kCGPathFillStroke);
	}
	
#if 0
	strokeWidth = 2.0;
	//				widthOfPopUpTriangle = 20,
	//				heightOfPopUpTriangle = 20,
	CGFloat cornerRadius = 4,
	calloutRadius = 15,
	bubbleOffset = 5;
	// Get the context
//	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetShouldAntialias (context, YES);
	//		CGContextSetMiterLimit(context, 1);
	//		CGContextSetLineJoin(context, kCGLineJoinRound);
	CGContextSetLineWidth(context, strokeWidth);
	CGContextSetAlpha(context, 0.8);
	CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
	//	CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
	
	// Draw and fill the bubble
	CGContextBeginPath(context);
	rrect = CGRectInset(self.bounds, 1, 1);
	//	rrect.size.width -= calloutRadius;
	CGFloat minX = CGRectGetMinX(rrect);
	CGFloat maxX = CGRectGetMaxX(rrect);
	CGFloat minY = CGRectGetMinY(rrect);
	CGFloat maxY = CGRectGetMaxY(rrect);
	CGFloat midX = CGRectGetMidX(rrect);
	CGFloat midY = CGRectGetMidY(rrect);
	if (_mediaImage)
		CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
	else
		CGContextSetFillColorWithColor(context, _bubbleColor.CGColor);
	
	if (_selected) {
		CGContextSetRGBStrokeColor(context, 0.0, 0.20, 0.9, 0.8);
	}
	
	if (_authorTypeSelf)	 {
		maxX -= calloutRadius + bubbleOffset;
		CGContextMoveToPoint(context, midX, minY);
		CGContextAddArcToPoint(context, maxX, minY, maxX, midY, cornerRadius);
		CGContextAddLineToPoint(context, maxX, midY - calloutRadius / 2);
		CGContextAddLineToPoint(context, maxX + calloutRadius / 2, midY);
		CGContextAddLineToPoint(context, maxX, midY + calloutRadius / 2);
		CGContextAddArcToPoint(context, maxX, maxY, midX, maxY, cornerRadius);
		CGContextAddArcToPoint(context, minX, maxY, minX, midY, cornerRadius);
		CGContextAddArcToPoint(context, minX, minY, midX, minY, cornerRadius);
	}
	else {
		minX += calloutRadius + bubbleOffset;
		CGContextMoveToPoint(context, midX, minY);
		CGContextAddArcToPoint(context, maxX, minY, maxX, midY, cornerRadius);
		CGContextAddArcToPoint(context, maxX, maxY, midX, maxY, cornerRadius);
		CGContextAddArcToPoint(context, minX, maxY, minX, midY, cornerRadius);
		CGContextAddLineToPoint(context, minX, midY + calloutRadius / 2);
		CGContextAddLineToPoint(context, minX - calloutRadius / 2, midY);
		CGContextAddLineToPoint(context, minX, midY - calloutRadius / 2);
		CGContextAddArcToPoint(context, minX, minY, midX, minY, cornerRadius);
	}
	
	CGContextClosePath(context);
	//	CGContextStrokePath(context);
	CGContextDrawPath(context, kCGPathFillStroke);
#endif
	UIGraphicsEndImageContext();
	CGPathRelease(path);
	
}

@end
