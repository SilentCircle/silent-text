//
//  STBubbleView.m
//  SilentText
//
//  Created by mahboud on 12/3/12.
//  Copyright (c) 2012 Silent Circle, LLC. All rights reserved.
//

#import "STBubbleView.h"
#import <QuartzCore/QuartzCore.h>

@interface STBubbleView ()
#ifdef done_using_an_imageview
@property (nonatomic, strong) UIImageView *mediaImageView;
#endif
@end

@implementation STBubbleView



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
	self.alpha = 1.0;
	self.opaque = YES;
	self.backgroundColor = [UIColor clearColor];
	self.transform = CGAffineTransformIdentity;
    self.frame = CGRectZero;
	self.bubbleImage = nil;
#ifdef done_using_an_imageview
	self.image = nil;
#endif
    self.mainFrame = CGRectZero;
	self.mediaImage = nil;
	self.mediaFrame = CGRectZero;
	_mediaImageLayer.contents = nil;
	//	self.burnImage = nil;
	//	self.geoImage = nil;
	[self setNeedsDisplay];
	//#ifdef done_with_media_image_drawn_into_calayer
	//	[CATransaction begin];
	//	[CATransaction setDisableActions:YES];
	//	_mediaLayer.frame = CGRectZero;
	//	_mediaImageLayer.frame = CGRectZero;
	//	[CATransaction commit];
	//#endif
}

- (void)setMainFrame:(CGRect)mainFrame
{
	_mainFrame = mainFrame;
	[self setNeedsDisplay];
}
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
	_bubbleImage = bubbleImage;
	[self setNeedsDisplay];
//#ifdef done_using_an_imageview
	self.image = bubbleImage;
//#endif
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
//- (void)setGeoImage:(UIImage *)geoImage
//{
//	_geoImage = geoImage;
//}
//- (void)setBurnImage:(UIImage *)burnImage
//{
//	_burnImage = burnImage;
//}
//
//- (CGRect) geoRect
//{
//	return CGRectMake(self.frame.size.width - 40, self.frame.size.height - 38, 24, 24);
//}
//- (CGRect) burnRect
//{
//	return CGRectMake(self.frame.size.width - 64, self.frame.size.height - 40, 24, 24);
//}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
//- (void)drawRect:(CGRect)rect
//{

//	[_bubbleImage drawInRect:rect];
//
//	[[NSString stringWithFormat:@"bubble rect: %@ for imagesize %@", NSStringFromCGRect(rect), NSStringFromCGSize(_mediaImage.size)] drawInRect:rect withFont:[UIFont systemFontOfSize:14]];
//#ifndef done_with_media_image_drawn_into_calayer
//	if (_mediaImage) {
//		CGContextRef ctx = UIGraphicsGetCurrentContext();
//		CGContextSaveGState(ctx);
//		CGPathRef roundedCorners = [UIBezierPath bezierPathWithRoundedRect:_mediaFrame cornerRadius:10].CGPath;
//		CGContextAddPath(ctx, roundedCorners);
//		CGContextClip(ctx);
//		[_mediaImage drawInRect:_mediaFrame];
//		CGContextRestoreGState(ctx);
//	}
//#endif
//}

// this would make the flags look better.

//- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
//{
//	if (layer != _mediaLayer && layer != _mediaImageLayer) {
//		[super drawLayer:layer inContext:ctx];
//
//	}
//	else if (layer == _mediaImageLayer) {
//		if (_geoImage) {
//			//		[_geoImage drawInRect:CGRectMake(self.frame.size.width - 40, self.frame.size.height - 38, 24, 24)];
//			[_geoImage drawInRect:[self geoRect]];
//		}
//		if (_burnImage) {
//			//		[_burnImage drawInRect:CGRectMake(self.frame.size.width - 64, self.frame.size.height - 40, 24, 24)];
//			[_burnImage drawInRect:[self burnRect]];
//		}
//	}
//}

@end
