/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

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
//  BizChatBubbleView.m
//  SilentText
//
//  Created by mahboud on 12/3/12.
//

#import "RectBubbleView.h"
#import <QuartzCore/QuartzCore.h>

@interface RectBubbleView ()
#ifdef done_using_an_imageview
@property (nonatomic, strong) UIImageView *mediaImageView;
#endif
@end

@implementation RectBubbleView



- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
#ifdef done_with_media_image_drawn_into_calayer
		self.mediaLayer = [CALayer layer];
		_mediaLayer.backgroundColor = [UIColor clearColor].CGColor;
// shadow
//		_mediaLayer.shadowOffset = CGSizeMake(0, 3);
//		_mediaLayer.shadowRadius = 5.0;
//		_mediaLayer.shadowColor = [UIColor blackColor].CGColor;
//		_mediaLayer.shadowOpacity = 0.8;
// frame
//		_mediaLayer.frame = CGRectZero;
//		_mediaLayer.borderColor = [UIColor blackColor].CGColor;
//		_mediaLayer.borderWidth = 1.0;
		_mediaLayer.cornerRadius = 10.0;
		[self.layer addSublayer:_mediaLayer];
		
		self.mediaImageLayer = [CALayer layer];
		_mediaImageLayer.cornerRadius = 10.0;
		_mediaImageLayer.masksToBounds = YES;
//		_mediaImageLayer.bounds = CGRectZero;
		[_mediaLayer addSublayer:_mediaImageLayer];
#endif
#ifdef done_using_an_imageview
		self.mediaImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
		self.mediaImageView.layer.cornerRadius = 10.0;
		self.mediaImageView.layer.masksToBounds = YES;
		self.mediaImageView.autoresizingMask = UIViewAutoresizingNone;
		[self addSubview: self.mediaImageView];
#endif
		[self reset];
    }
    return self;
}

- (void) reset
{
	self.opaque = YES;
	self.backgroundColor = [UIColor clearColor];
	self.transform = CGAffineTransformIdentity;
//    self.frame = CGRectZero;
//	self.bubbleImage = nil;
#ifdef done_using_an_imageview
	self.image = nil;
#endif
//    self.mainFrame = CGRectZero;
	self.mediaImage = nil;
	self.mediaFrame = CGRectZero;
	self.alpha = 1.0;
	self.transform = CGAffineTransformIdentity;

	_mediaImageLayer.contents = nil;
//	self.burnImage = nil;
//	self.geoImage = nil;
//	[self setNeedsDisplay];
//#ifdef done_with_media_image_drawn_into_calayer
//	[CATransaction begin];
//	[CATransaction setDisableActions:YES];
//	_mediaLayer.frame = CGRectZero;
//	_mediaImageLayer.frame = CGRectZero;
//	[CATransaction commit];
//#endif
}
//
//- (void)setMainFrame:(CGRect)mainFrame
//{
//	_mainFrame = mainFrame;
//	[self setNeedsDisplay];
//}
- (void)setMediaFrame:(CGRect)mediaFrame
{
	_mediaFrame = mediaFrame;
#ifdef done_with_media_image_drawn_into_calayer
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	_mediaLayer.frame = mediaFrame;
	_mediaImageLayer.frame = _mediaLayer.bounds;
	[CATransaction commit];
#endif
#ifdef done_using_an_imageview
	_mediaImageView.frame = mediaFrame;
#endif
	[self setNeedsDisplay];
}
- (void)setBubbleImage:(UIImage *)bubbleImage
{
//	_bubbleImage = bubbleImage;
	//	self.layer.contents = (id) _bubbleImage.CGImage;
	[self setNeedsDisplay];
	//#ifdef done_using_an_imageview
	//	self.image = bubbleImage;
	//#endif
}
- (void)setSelected:(BOOL)selected
{
	_selected = selected;
	[self setNeedsDisplay];
}
- (void)setMediaImage:(UIImage *)mediaImage
{
	_mediaImage = mediaImage;
#ifdef done_using_an_imageview
	_mediaImageView.image = mediaImage;
#endif
	if (mediaImage) {
#ifdef done_with_media_image_drawn_into_calayer
		[CATransaction begin];
		[CATransaction setDisableActions:YES];

		_mediaImageLayer.contents = (id) mediaImage.CGImage;
		[CATransaction commit];
#endif
		[self setNeedsDisplay];
	}
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code

	CGFloat strokeWidth = 2.0,
	//				widthOfPopUpTriangle = 20,
	//				heightOfPopUpTriangle = 20,
	cornerRadius = 4,
	calloutRadius = 15,
	bubbleOffset = 5;
	// Get the context
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetShouldAntialias (context, YES);
	//		CGContextSetMiterLimit(context, 1);
	//		CGContextSetLineJoin(context, kCGLineJoinRound);
	CGContextSetLineWidth(context, strokeWidth);
	CGContextSetAlpha(context, 0.8);
	CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
//	CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
	
	// Draw and fill the bubble
	CGContextBeginPath(context);
	CGRect rrect = CGRectInset(self.bounds, 1, 1);
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
	
	UIGraphicsEndImageContext();
	
}
@end
