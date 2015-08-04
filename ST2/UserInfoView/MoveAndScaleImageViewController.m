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
#import "MoveAndScaleImageViewController.h"
#import "UIImage+Crop.h"
#import "STLogging.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


@implementation MoveAndScaleImageViewController
{
	UIImage *image;
	UIImageView *imageView;
	
	BOOL hasViewDidAppear;
}

@synthesize delegate = delegate;

- (id)initWithMediaInfo:(NSDictionary *)mediaInfo
{
	if ((self = [super initWithNibName:@"MoveAndScaleImageViewController" bundle:nil]))
	{
		image = [mediaInfo objectForKey:UIImagePickerControllerEditedImage];
		if (image == nil)
			image = [mediaInfo objectForKey:UIImagePickerControllerOriginalImage];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
	DDLogAutoTrace();
	[super viewDidLoad];
	
	// Configure the basic properties of the scrollView
	
	scrollView.delegate = self;
	scrollView.contentSize = image.size;
	scrollView.backgroundColor = [UIColor blackColor];
	
	imageView = [[UIImageView alloc] initWithImage:image];
	[scrollView addSubview:imageView];
	
	// Configure the circle overlay
	//
	// We give it minimum insets on the top and bottom so the cirlce isn't over the labels or buttons.
	//
	// We use the topInsetView & bottomInsetView to calculate these offsets.
	// These are hidden views that are laid out automatically using constraints.
	// So you can easily edit these values by modifying the topInsetView or bottomInsetView in the xib.
	// Please don't manually edit the values here. Please modify the xib. Please.
	//
	// The actual insets of the circle will depend on the width and height of the circleOverlay frame.
	// For example, in portrait mode the width is less than the height.
	// So the circle diameter can only be as big as the width.
	// And so the top & bottom insets will be larger than the min values specified below,
	// as to center the circle within the frame.
	
	CGFloat viewHeight = self.view.bounds.size.height;
	
	CGFloat topInset = topInsetView.frame.origin.y;
	CGFloat bottomInset = viewHeight - (bottomInsetView.frame.origin.y + bottomInsetView.frame.size.height);
	
	circleOverlay.minCircleInsets = UIEdgeInsetsMake(topInset, 0, bottomInset, 0); // top, left, bottom, right
	
	// Perform all the calculations for insets & zoomScale
	
	[self recalculate];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
	
	[self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewDidAppear:animated];
	
	hasViewDidAppear = YES;
}

- (void)viewDidLayoutSubviews
{
	DDLogAutoTrace();
	[self recalculate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Preferences
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)recalculate
{
	DDLogAutoTrace();
	
	// Now we want to calculate how to display the image in the scrollView.
	//
	// First we fetch the bounding rectangle of the circle in the circleOverlay,
	// and set the contentInset of the scrollView to match the circle.
	// This way the image can be moved around relative to the circle.
	// Meaning the image edges can come all the way to the circle edge, but not beyond them.
	
	scrollView.contentInset = circleOverlay.circleInsets;
	
	// Now calculate the the minimumZoomScale.
	// The image can only get as small as the circleRect.
	
	CGSize imageSize = image.size;
	
	CGRect circleRect = circleOverlay.circleRect;
	CGSize circleSize = circleRect.size;
	
	CGFloat minWZoomScale = circleSize.width / imageSize.width;
	CGFloat minHZoomScale = circleSize.height / imageSize.height;
	
	CGFloat minZoomScale = MAX(minWZoomScale, minHZoomScale);
	
	DDLogVerbose(@"minZoomScale: %.2f", minZoomScale);
	scrollView.minimumZoomScale = minZoomScale;
	
	// Now calculate the maximumZoomScale.
	// The idea is to keep the zoomed image from getting too blurry.
	// So with a minimum image size in mind, we calculate a max zoom so the image within the circle
	// doesn't get smaller than the minimum image size.
	//
	// Math is hard:
	//
	// circleDiameter * (1 / zoomScale) = imageWidthAndHeightInCircleAtZoomScale
	//
	// For example:
	// 500 * (1 / 2) = 250
	//
	// So given a minimum target value for imageWidthAndHeightInCircleAtZoomScale,
	// solve for unknown zoomScale variable ==>
	//
	// zoomScale = 1 / (imageWidthAndHeightInCircleAtZoomScale / circleDiameter)
	
	CGFloat circleDiameter = circleSize.width; // width == height
	CGFloat targetMinImageSize = 200;
	
	CGFloat maxZoomScale = 1 / (targetMinImageSize / circleDiameter);
	
	if (maxZoomScale < minZoomScale)
		maxZoomScale = minZoomScale;
	
	if (maxZoomScale > (minZoomScale * 8)) // prevent huge zoom scale
		maxZoomScale = (minZoomScale * 8);
	
	DDLogVerbose(@"maxZoomScale: %.2f", maxZoomScale);
	scrollView.maximumZoomScale = maxZoomScale;
	
	// Now give a sane placement of the image within the scrollView
	
	if (hasViewDidAppear)
	{
		// There's no need to move the image (set contentOffset).
		// It defaults to being centered (which is what we want).
		// And automatically keeps its approximate position if zoomScale is changed (again what we want).
		
		CGFloat zoomScale = scrollView.zoomScale;
		
		if (zoomScale < minZoomScale)
			zoomScale = minZoomScale;
		
		if (zoomScale > maxZoomScale)
			zoomScale = maxZoomScale;
		
		DDLogVerbose(@"zoomScale: %.2f", zoomScale);
		scrollView.zoomScale = zoomScale;
	}
	else
	{
		DDLogVerbose(@"zoomScale: %.2f", minZoomScale);
		scrollView.zoomScale = minZoomScale;
		
		// center the photo within the circle
		
		CGSize contentSize = scrollView.contentSize;
		CGPoint contentOffset;
		contentOffset.x = (contentSize.width - circleSize.width) / 2.0f;
		contentOffset.y = 0;
		
		contentOffset.x -= scrollView.contentInset.left;
		contentOffset.y -= scrollView.contentInset.top;
		
		scrollView.contentOffset = contentOffset;
	}
}

- (UIImage *)croppedImage
{
	CGFloat zoomScale = scrollView.zoomScale;
	DDLogVerbose(@"scrollView.zoomScale: %.2f", zoomScale);
	
	DDLogVerbose(@"scrollView.contentSize: %@", NSStringFromCGSize(scrollView.contentSize));
	DDLogVerbose(@"scrollView.contentOffset: %@", NSStringFromCGPoint(scrollView.contentOffset));
	
	// Fetch the contentOffset of the image within the scrollView.
	// The image may be panned and zoomed.
	
	CGPoint contentOffset = scrollView.contentOffset;
	
	// Adjust for the contentInsets.
	//
	// For example, if scrollView.contentInset.top is 124,
	// and the image is in the upper left corner of the circle,
	// then the contentOffset.y value would be -124.
	//
	// Note: The contentInset matches up with the circleRect.
	
	DDLogVerbose(@"scrollView.contentInset: %@", NSStringFromUIEdgeInsets(scrollView.contentInset));
	
	contentOffset.x += scrollView.contentInset.left;
	contentOffset.y += scrollView.contentInset.top;
	
	DDLogVerbose(@"contentOffset (contentInset adjustment): %@", NSStringFromCGPoint(contentOffset));
	
	// Adjust for the zoomScale
	//
	// For example, if the image is 100*100 and the zoomScale is 2,
	// then scrollView.contentSize would be 200*200,
	// and scrollView.contentOffset is similarly scaled.
	//
	// Note: The contentInset is not scaled, which is why this calculation must come after the contentInset adjustment.
	
	contentOffset.x *= (1.0f / zoomScale);
	contentOffset.y *= (1.0f / zoomScale);
	
	DDLogVerbose(@"contentOffset (zoomScale adjustment): %@", NSStringFromCGPoint(contentOffset));
	
	// Now that we have the contentOffset of the image within the circle, we need the size.
	
	CGRect circleRect = circleOverlay.circleRect;
	
	CGRect imageRect;
	imageRect.origin = contentOffset;
	imageRect.size.width = circleRect.size.width * (1.0f / zoomScale);
	imageRect.size.height = circleRect.size.height * (1.0f / zoomScale);
	
	imageRect.origin.x = roundf(imageRect.origin.x);
	imageRect.origin.y = roundf(imageRect.origin.y);
	imageRect.size.width = roundf(imageRect.size.width);
	imageRect.size.height = roundf(imageRect.size.height);
	
	DDLogVerbose(@"imageRect (pre-check): %@", NSStringFromCGRect(imageRect));
	
	CGSize imageSize = image.size;
	DDLogVerbose(@"imageSize: %@", NSStringFromCGSize(imageSize));
	
	// Make sure rounding didn't give us bad values (off by 1)
	
	if ((imageRect.origin.x + imageRect.size.width) > imageSize.width)
		imageRect.size.width = imageSize.width - imageRect.origin.x;
	
	if ((imageRect.origin.y + imageRect.size.height) > imageSize.height)
		imageRect.size.height = imageSize.height - imageRect.origin.y;
	
	DDLogVerbose(@"imageRect (final): %@", NSStringFromCGRect(imageRect));
	
	return [image crop:imageRect];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)cancelButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
	SEL selector = @selector(moveAndScaleImageViewControllerDidCancel:);
	if ([delegate respondsToSelector:selector]){
		[delegate moveAndScaleImageViewControllerDidCancel:self];
	}
}

- (IBAction)chooseButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
	UIImage *croppedImage = [self croppedImage];
	
	SEL selector = @selector(moveAndScaleImageViewController:didChooseImage:);
	if ([delegate respondsToSelector:selector]){
		[delegate moveAndScaleImageViewController:self didChooseImage:croppedImage];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UIScrollViewDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
	return imageView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale
{
	// Nothing to do here.
	// But this delegate method is required in order to support zooming.
	
	DDLogVerbose(@"scrollViewDidEndZooming:withView:atScale: %.2f", scale);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MoveAndScaleImageCircleOverlay
{
	CAShapeLayer *fillLayer;
}

@synthesize minCircleInsets = minCircleInsets;

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		[self setLayerProperties];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]))
	{
		[self setLayerProperties];
	}
	return self;
}

- (void)setMinCircleInsets:(UIEdgeInsets)newMinCircleInsets
{
	if (!UIEdgeInsetsEqualToEdgeInsets(minCircleInsets, newMinCircleInsets))
	{
		minCircleInsets = newMinCircleInsets;
		[self setNeedsLayout];
	}
}

- (void)layoutSubviews
{
	[self setLayerProperties];
}

- (UIEdgeInsets)circleInsets
{
	CGRect bounds = self.bounds;
	CGRect circleRect = self.circleRect;
	
	UIEdgeInsets circleInsets;
	circleInsets.left = circleRect.origin.x;
	circleInsets.top = circleRect.origin.y;
	circleInsets.right = bounds.size.width - circleRect.origin.x - circleRect.size.width;
	circleInsets.bottom = bounds.size.height - circleRect.origin.y - circleRect.size.height;
	
	return circleInsets;
}

- (CGRect)circleRect
{
	CGRect insetBounds = self.bounds;
	insetBounds.origin.x += minCircleInsets.left;
	insetBounds.origin.y += minCircleInsets.top;
	insetBounds.size.width -= (minCircleInsets.left + minCircleInsets.right);
	insetBounds.size.height -= (minCircleInsets.top + minCircleInsets.bottom);
	
	CGRect circleRect;
	CGFloat diameter;
	
	if (insetBounds.size.width <= insetBounds.size.height)
	{
		diameter = insetBounds.size.width; // diameter is shorter side (width)
		
		circleRect.origin.x = insetBounds.origin.x;
		circleRect.origin.y = insetBounds.origin.y + ((insetBounds.size.height - diameter) / 2.0f);
		circleRect.size.width = diameter;
		circleRect.size.height = diameter;
	}
	else // if (insetBounds.size.width > insetBounds.size.height)
	{
		diameter = insetBounds.size.height; // diameter is shorter size (height)
		
		circleRect.origin.x = insetBounds.origin.x + ((insetBounds.size.width - diameter) / 2.0f);
		circleRect.origin.y = insetBounds.origin.y;
		circleRect.size.width = diameter;
		circleRect.size.height = diameter;
	}
	
	// round to nearest integer value
	
	circleRect.origin.x = roundf(circleRect.origin.x);
	circleRect.origin.y = roundf(circleRect.origin.y);
	
	return circleRect;
}

- (void)setLayerProperties
{
	CGRect fillBounds = self.bounds;
	CGRect circleRect = [self circleRect];
	
	UIBezierPath *circlePath = [UIBezierPath bezierPathWithOvalInRect:circleRect];
	[circlePath setUsesEvenOddFillRule:YES];
	
	UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:fillBounds cornerRadius:0];
	[path appendPath:circlePath];
	[path setUsesEvenOddFillRule:YES];
	
	if (fillLayer == nil)
	{
		fillLayer = [CAShapeLayer layer];
		fillLayer.path = path.CGPath;
		fillLayer.fillRule = kCAFillRuleEvenOdd;
		fillLayer.fillColor = [[UIColor blackColor] CGColor];
		fillLayer.opacity = 0.7;
		
		[self.layer addSublayer:fillLayer];
	}
	else
	{
		fillLayer.path = path.CGPath;
	}
}

@end
