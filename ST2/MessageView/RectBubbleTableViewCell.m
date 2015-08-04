//
//  BizChatBubbleTableViewCell.m
//  BizChatBubbleTableViewCellDemo
//
//  Created by Cedric Vandendriessche on 18/04/12.
//  Copyright 2011 FreshCreations. All rights reserved.
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "RectBubbleTableViewCell.h"
#import <QuartzCore/QuartzCore.h>
#import "MobileCoreServices/UTCoreTypes.h"

//#define CLASS_DEBUG 1
#import "DDGMacros.h"
#ifdef CLASS_DEBUG
#define CleanLog(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

#else
#define CleanLog(FORMAT, ...) ;
#endif
#define kBizChatBubbleGutterWidth		60
#define kBizChatBubbleImageWidth		42
#define minBubbleWidth					90
#define minBubbleHeight					kBizChatBubbleImageWidth

#define kContentPad      				4.0f
#define kMediaContentPad  				3.0f
#define kBubbleHeightPad				5.0f
#define kBubbleImageWidthPad			3.0f
#define kBubbleGapFromSideOrAvatarX		13.0f
#define kBubbleGapFromBottomY			6.0f
#define kBubbleCalloutWidth				15
#define kBubbleNonCalloutWidth			0.0f
#define kTextSizeFudge					5.0f
#define flag_diameter 					30
#define kHorizontalPad					10.0
#define kVerticalPad					6.0

@interface RectBubbleTableViewCell ()

@property (nonatomic, readonly) CGSize textSize;

@property (strong, nonatomic) UITapGestureRecognizer *tapRecognizer;
@property (strong, nonatomic) UITapGestureRecognizer *avatarTapRecognizer;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;

#define kLongPress  (@selector(longPress:))
- (void) longPress: (UILongPressGestureRecognizer *) gestureRecognizer;

#define kTap  (@selector(tap:))
- (void) tap: (UITapGestureRecognizer *) gestureRecognizer;


#define kTapAvatar  (@selector(avatarTap:))
- (void) avatarTap: (UITapGestureRecognizer *) gestureRecognizer;

#define kResend  (@selector(resend:))
- (void) resend: (id) sender;


#define kForward  (@selector(forward:))
- (void) forward: (id) sender;

#define kBurnItem  (@selector(burnItem:))
- (void) burnItem: (id) sender;


@end

@implementation RectBubbleTableViewCell

@dynamic    height;
@dynamic    textSize;

- (void) dealloc {
	
	[NSNotificationCenter.defaultCenter removeObserver: self];
	
} // -dealloc

#pragma mark - Accessor methods.



- (CGSize) textSize {
	CGRect tempBounds = _textView.bounds;
	_textView.bounds = self.contentView.bounds;
	NSInteger numFlags = 0;
	if (_hasBurn)
		numFlags++;
	if (_hasGeo)
		numFlags++;

	CGSize size = [RectBubbleTableViewCell sizeForText:self.textView.text withFont:self.textView.font hasAvatar:self.imageView.image ? YES : NO numberOfFlags:numFlags withMaxWidth:self.contentView.bounds.size.width];
	_textView.bounds = tempBounds;
	return size;
}
+ (CGSize) sizeForText: (NSString *) text withFont:(UIFont *) font hasAvatar: (BOOL) hasAvatar numberOfFlags:(NSInteger)flags withMaxWidth:(CGFloat) maxWidth {
	
	CGSize size;
	
	CGFloat newMaxWidth = hasAvatar ? maxWidth - kBizChatBubbleGutterWidth - kBizChatBubbleImageWidth : maxWidth - kBizChatBubbleGutterWidth;
	size = (CGSizeMake(newMaxWidth /**- 16**/, 1024.0f));
	
	size = [text sizeWithFont: font //self.textView.font
			constrainedToSize: size
				lineBreakMode: NSLineBreakByWordWrapping];
	size.width += 16;		//these two lines are experimental values used temporarily until
//	size.width = newMaxWidth;		//this makes all bubbles max width
	size.height += 8;		// i figure out the best values to keep textview from getting a scroll indicator
	return size;
	
} // -textSize

+(CGFloat) quickHeightForContentViewWithText:(NSString *) text withFont:(UIFont *) font withAvatar:(BOOL) hasAvatar numberOfFlags:(NSInteger)flags withMaxWidth:(CGFloat)maxWidth
{
	CGFloat height = [RectBubbleTableViewCell sizeForText:text withFont:font hasAvatar:hasAvatar numberOfFlags: flags withMaxWidth: maxWidth].height + kVerticalPad;
	CGFloat minHeight = 0;
//	if (hasTwoFlags)
//		minHeight = 2 * flag_diameter;
	
	if (hasAvatar) {
		
		minHeight =  minHeight > kBizChatBubbleImageWidth ? minHeight : kBizChatBubbleImageWidth; // replace with min/max
		
	}
	minHeight += 1;
	height = (height < minHeight ? minHeight : height); // replace with min/max
		
	CleanLog(@"QH-text: %@, text height: %f", text, height);
	
	return height + kHorizontalPad;
	
	
}
+(CGFloat) quickHeightForContentViewWithImage:(UIImage *) image withAvatar:(BOOL) hasAvatar
{
	if (hasAvatar) {
		CleanLog(@"QH-image, height: %f", image.size.height + kBizChatBubbleImageWidth / 2);
		return image.size.height + kVerticalPad;
	}
	CleanLog(@"QH-image, height: %f", image.size.height);
	
	return image.size.height + kVerticalPad;
}


- (CGFloat) height {
	DDGTrace();
//	return [self heightForContentViewWithTextSize: self.textSize];
	return 0;
} // -height


- (id) initWithStyle: (UITableViewCellStyle) style reuseIdentifier: (NSString *) reuseIdentifier {
	
	DDGTrace();

	self = [super initWithStyle: style reuseIdentifier: reuseIdentifier];
	
	if (self) {
		
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		//***
		self.contentView.alpha = 1.0;
		self.contentView.opaque = YES;
		self.contentView.backgroundColor = [UIColor clearColor];
		//****
		self.bubbleView = [[RectBubbleView alloc] initWithFrame:CGRectZero];
		_bubbleView.userInteractionEnabled = YES;
		[self.contentView addSubview: _bubbleView];
		
		//****
		_bubbleView.alpha = 1.0;
		_bubbleView.opaque = YES;
		_bubbleView.backgroundColor = [UIColor clearColor];
		//****
		self.textView = [UITextView new];
		_textView.scrollsToTop = NO;
		_textView.backgroundColor = [UIColor clearColor];
		_textView.editable = NO;
		_textView.textAlignment = NSTextAlignmentLeft;
		_textView.dataDetectorTypes = UIDataDetectorTypeAll;
		_textView.textColor = [UIColor blackColor];
		_textView.scrollEnabled = NO;
		[_bubbleView addSubview:_textView];
		//****
#define bubble_testing 1
#if bubble_testing
	//  for testing
		self.contentView.layer.borderColor = [UIColor lightGrayColor].CGColor;
		self.contentView.layer.borderWidth = 1.0;
		self.imageView.layer.borderColor = [UIColor blueColor].CGColor;
		self.imageView.layer.borderWidth = 1.0;

		_textView.backgroundColor = [UIColor whiteColor];
		_textView.alpha = 0.5;
//		_bubbleView.mediaLayer.borderColor = [UIColor redColor].CGColor;
//		_bubbleView.mediaLayer.borderWidth = 1.0;
	// end testing
#endif
		//****
		self.imageView.userInteractionEnabled = YES;
		
		UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
		longPressRecognizer.minimumPressDuration = 0.25;
		[_bubbleView addGestureRecognizer:longPressRecognizer];
		
		UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
		[_bubbleView addGestureRecognizer:tapRecognizer];
		
		UITapGestureRecognizer *avatarTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTap:)];
		[self.imageView addGestureRecognizer:avatarTapRecognizer];
		
		self.burnImage = [UIImage imageNamed:@"flame_btn"];
		self.geoImage = [UIImage imageNamed:@"map_btn"];
		self.failureImage = [UIImage imageNamed:@"failure-btn"];
	}
	return self;
	
} // -initWithStyle:reuseIdentifier:


- (void) prepareForReuse {
	[super prepareForReuse];  // why was this missing???
	DDGLog(@"old cell: %@", self.textView.text);
	self.frame = CGRectZero;

	_authorType = BubbleTableViewCellAuthorTypeNone;
	_canCopyContents = YES;
	
	self.imageView.image = nil;

	[self.bubbleView reset];
	self.hasGeo = NO;
	self.hasBurn = NO;
	self.failure = NO;
} // -prepareForReuse


- (void) placeFlags
{
	CGRect bubbleFrame = _bubbleView.frame;

	if (_hasBurn) {
		CGRect frame = _burnButton.frame;
		if (_hasGeo)
			frame.origin.y = (self.contentView.bounds.size.height - 2.0 * frame.size.height) / 3.0;
		else
			frame.origin.y = _bubbleView.center.y - frame.size.height/2;
		if (_authorType == BubbleTableViewCellAuthorTypeUser)	 {
			frame.origin.x = bubbleFrame.origin.x - 2.0 * frame.size.width / 3.0;
		}
		else if (_authorType == BubbleTableViewCellAuthorTypeOther)	 {
			frame.origin.x = bubbleFrame.origin.x + bubbleFrame.size.width - 1.0 * frame.size.width / 3.0;
		}
		_burnButton.frame = frame;
	}
	if (_hasGeo) {
		CGRect frame = _geoButton.frame;
		if (_hasBurn)
			frame.origin.y = 2.0 * (self.contentView.bounds.size.height - 2.0 * frame.size.height) / 3.0 + frame.size.height;
		else
			frame.origin.y = _bubbleView.center.y - frame.size.height/2;
		if (_authorType == BubbleTableViewCellAuthorTypeUser)	 {
			frame.origin.x = bubbleFrame.origin.x - 2.0 * frame.size.width / 3.0;
		}
		else if (_authorType == BubbleTableViewCellAuthorTypeOther)	 {
			frame.origin.x = bubbleFrame.origin.x + bubbleFrame.size.width - 1.0 * frame.size.width / 3.0;
		}
		_geoButton.frame = frame;
	}
	if (_failure) {
		CGRect frame = _failureButton.frame;
		frame.origin.y = _bubbleView.frame.origin.y - frame.size.height / 4;
		if (_authorType == BubbleTableViewCellAuthorTypeUser)	 {
			frame.origin.x =  _bubbleView.frame.origin.x - frame.size.width/2;
		}
		else if (_authorType == BubbleTableViewCellAuthorTypeOther)	 {
			frame.origin.x = _bubbleView.frame.origin.x + _bubbleView.frame.size.width - frame.size.width/2;
		}
		_failureButton.frame = frame;
	}
}

- (void) layoutSubviews {
	[super layoutSubviews];
	DDGTrace();
	CGRect bounds = self.contentView.bounds;

	CGFloat imageViewOffset;

	if (self.imageView.image) {
		imageViewOffset = kBizChatBubbleImageWidth / 2 + kBubbleGapFromSideOrAvatarX;//-3
		CGFloat leftSide;
		if (_authorType == BubbleTableViewCellAuthorTypeUser) {
			leftSide = bounds.size.width  - kBizChatBubbleImageWidth - kBubbleImageWidthPad;
		}
		else {
			leftSide = kBubbleImageWidthPad;
		}
		self.imageView.frame = CGRectMake(leftSide,
										  (bounds.size.height - kBizChatBubbleImageWidth) / 2,
										  kBizChatBubbleImageWidth,
										  kBizChatBubbleImageWidth);
	}
	else {
		imageViewOffset = 0;
		self.imageView.frame = CGRectZero;
	}
	CGFloat bubbleWidth;
	CGFloat bubbleHeight;
	if (self.bubbleView.mediaImage) {
		CGFloat calloutAffordance = kMediaContentPad + ((_authorType == BubbleTableViewCellAuthorTypeUser) ? kBubbleNonCalloutWidth : kBubbleCalloutWidth + 5);
		CGSize photoSize = _bubbleView.mediaImage.size;
		bubbleWidth = photoSize.width + kBubbleNonCalloutWidth + kBubbleCalloutWidth + 2 * kMediaContentPad + 5;
		bubbleHeight = photoSize.height + 2 * kMediaContentPad + kBubbleNonCalloutWidth;
		_bubbleView.mediaFrame = CGRectMake(calloutAffordance,
											kMediaContentPad,
											photoSize.width,
											photoSize.height);
	}
	else {
		CGFloat calloutAffordance = kContentPad + ((_authorType == BubbleTableViewCellAuthorTypeUser) ? kBubbleNonCalloutWidth : kBubbleCalloutWidth);
		CGSize size   = self.textSize;
		bubbleWidth  = size.width + kBubbleNonCalloutWidth + kBubbleCalloutWidth + 2 * kContentPad;
		float horizLocation, vertLocation;
		if (bubbleWidth < minBubbleWidth) {
			horizLocation = (minBubbleWidth - bubbleWidth) / 2.0;
			bubbleWidth = minBubbleWidth;
		}
		else
			horizLocation = 0;
		bubbleHeight = size.height + kBubbleHeightPad;
		if (bubbleHeight < minBubbleHeight) {
			vertLocation = (minBubbleHeight - bubbleHeight) / 2.0;
			bubbleHeight = minBubbleHeight;
		}
		else
			vertLocation = 0;

		self.textView.frame = CGRectIntegral(CGRectMake(
														horizLocation + calloutAffordance,
														vertLocation - 2,
														size.width + 5,//+3? Otherwise the text wraps odly
														size.height));
	}
	CGFloat leftSide;
	if (_authorType == BubbleTableViewCellAuthorTypeUser) {
		leftSide = bounds.size.width - bubbleWidth - imageViewOffset;
	}
	else {
		leftSide = imageViewOffset;
	}
	
	_bubbleView.frame    = CGRectMake(leftSide,
									  (bounds.size.height - bubbleHeight) / 2,
									  bubbleWidth,
									  bubbleHeight);

	[self placeFlags];
	_bubbleView.authorTypeSelf = (_authorType == BubbleTableViewCellAuthorTypeUser);
	_bubbleView.selected = self.selected;
} // -layoutSubviews


#pragma mark - UIGestureRecognizer methods


- (void) longPress: (UILongPressGestureRecognizer *) gestureRecognizer {
	
	DDGTrace();
    
	if(gestureRecognizer.state == UIGestureRecognizerStateBegan) {
		
		NSMutableArray* menuItems = [[NSMutableArray alloc] init];
		
		UIMenuItem *burnItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Burn", @"Burn") action:kBurnItem];
		[menuItems addObject:burnItem];
		
		if (_canCopyContents)
		{
			UIMenuItem *forward = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Forward", @"Forward") action:kForward];
			[menuItems addObject:forward];
			
			UIMenuItem *resend = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Send Again", @"Send Again") action:kResend];
			[menuItems addObject:resend];
		}
		
		
		UIMenuController *menuController = [UIMenuController sharedMenuController];

		[self becomeFirstResponder];
		
		[menuController setMenuItems:menuItems];
		
		[menuController setTargetRect: _bubbleView.frame inView: self];
		[menuController setMenuVisible:YES animated:YES];
		
		_bubbleView.selected = YES;
		if([_delegate respondsToSelector: @selector(selectedBubble:selected:)]) {
			
			[_delegate selectedBubble:self selected:YES];
		}

		[NSNotificationCenter.defaultCenter addObserver: self
											   selector: @selector(willHideMenuController:)
												   name: UIMenuControllerWillHideMenuNotification
												 object: nil];
		
		
	}
	
} // -longPress:


- (void) avatarTap: (UITapGestureRecognizer *) gestureRecognizer {
	if (!self.imageView.image)
		return;
	if([_delegate respondsToSelector: kTappedImageOfAvatar]) {
		
		[_delegate tappedImageOfAvatar: self];
	}
	
} // -avatarTap:



- (void) tap: (UITapGestureRecognizer *) gestureRecognizer {
	if (_bubbleView.mediaImage) {
		CGPoint hitPoint = [gestureRecognizer locationInView:_bubbleView];
		if(CGRectContainsPoint (_bubbleView.mediaFrame,
								hitPoint)
		   && [_delegate respondsToSelector: kTappedImageOfCell]) {
			
			[_delegate tappedImageOfCell: self];
			return;
		}
	}
} // -tap:

- (IBAction) flagTap:(id) sender
{
	if (sender == (id) _geoButton) {
		if([_delegate respondsToSelector: @selector(tappedGeo:)]) {
			
			[_delegate tappedGeo: self];
			return;
		}
	}
	if (sender == (id) _burnButton) {
		if([_delegate respondsToSelector: @selector(tappedBurn:)]) {
			
			[_delegate tappedBurn: self];
			return;
		}
	}
	if (sender == (id) _failureButton) {
		if([_delegate respondsToSelector: @selector(tappedFailure:)]) {
			
			[_delegate tappedFailure: self];
			return;
		}
	}
	
}

#pragma mark - UIMenuController methods


- (BOOL) canPerformAction: (SEL) selector withSender: (id) sender {
	
	BOOL doIt = NO;
	
	if(selector == @selector(copy:) || selector == @selector(forward:) )
	{
		doIt = _canCopyContents;
		
	}
	else if(selector == kResend)
	{
		doIt = _authorType == BubbleTableViewCellAuthorTypeUser;
	}
	
	else if(selector == kBurnItem)
	{
		doIt = YES;
	}
	
	return doIt;
} // -canPerformAction:withSender:


- (BOOL) canBecomeFirstResponder {
	
	DDGTrace();
	
	return YES;
	
} // -canBecomeFirstResponder


- (void) burnItem: (id) sender {
	
	if([_delegate respondsToSelector: kTappedDeleteMenu]) {
		
		[_delegate tappedDeleteMenu: self];
	}
	
} // -resend:



- (void) resend: (id) sender {
	
	if([_delegate respondsToSelector: kTappedResendMenu]) {
		
		[_delegate tappedResendMenu: self];
	}
	
} // -resend:



- (void) forward: (id) sender {
	
	if([_delegate respondsToSelector: kTappedForwardMenu]) {
		
		[_delegate tappedForwardMenu: self];
	}
	
} // -resend:


- (void) copy: (id) sender {
	
	UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
	NSMutableDictionary *items = [NSMutableDictionary dictionaryWithCapacity:2];
	
	if(self.textView.text)
		[items setValue:self.textView.text forKey:(NSString *)kUTTypeUTF8PlainText];
	
	if(self.bubbleView.mediaImage) {
		NSData *jpegData = UIImageJPEGRepresentation(self.bubbleView.mediaImage, 1.0);
		[items setValue:jpegData forKey:(NSString *)kUTTypeJPEG];
	}
	
	pasteboard.items = [NSArray arrayWithObject:items];
	
} // -copy:


- (void) willHideMenuController: (NSNotification *) notification {
	
	DDGTrace();
	
	_bubbleView.selected = NO;
	if([_delegate respondsToSelector: @selector(selectedBubble:selected:)]) {
		
		[_delegate selectedBubble:self selected:NO];
	}

	[NSNotificationCenter.defaultCenter removeObserver: self
												  name: UIMenuControllerWillHideMenuNotification 
												object: nil];
	
} // -willHideMenuController:

#define flag_border_color whiteColor
#define flag_bgnd_color	blackColor
#define flag_size {0,0,flag_diameter,flag_diameter}
- (void) setHasBurn:(BOOL)burn
{
	_hasBurn = burn;
	if (burn) {
		if (!_burnButton) {
			self.burnButton = [UIButton buttonWithType:UIButtonTypeCustom];
			_burnButton.contentMode = UIViewContentModeCenter;
			CGRect frame = flag_size;
			_burnButton.frame = frame;
			_burnButton.layer.backgroundColor = [UIColor flag_bgnd_color].CGColor;
			_burnButton.layer.borderColor = [UIColor flag_border_color].CGColor;
			_burnButton.layer.borderWidth = 2.0;
			_burnButton.layer.cornerRadius = frame.size.width/2;
			[_burnButton setImage:_burnImage forState:UIControlStateNormal];
			[_burnButton addTarget:self action:@selector(flagTap:) forControlEvents:UIControlEventTouchUpInside];
		}
		if (![_burnButton superview])
			[self.contentView addSubview:_burnButton];
	}
	else if (_burnButton) {
		if ([_burnButton superview])
			[_burnButton removeFromSuperview];
	}
}
- (void) setHasGeo:(BOOL)hasGeo
{
	//	_bubbleView.geoImage = hasGeo ? _geoImage : nil;
	_hasGeo = hasGeo;
	if (hasGeo) {
		if (!_geoButton) {
			self.geoButton = [UIButton buttonWithType:UIButtonTypeCustom];
			_geoButton.contentMode = UIViewContentModeCenter;
			CGRect frame = flag_size;
			_geoButton.frame = frame;
			_geoButton.layer.backgroundColor = [UIColor flag_bgnd_color].CGColor;
			_geoButton.layer.borderColor = [UIColor flag_border_color].CGColor;
			_geoButton.layer.borderWidth = 2.0;
			_geoButton.layer.cornerRadius = frame.size.width/2;
			[_geoButton setImage:_geoImage forState:UIControlStateNormal];
			[_geoButton addTarget:self action:@selector(flagTap:) forControlEvents:UIControlEventTouchUpInside];
		}
		if (![_geoButton superview])
			[self.contentView addSubview:_geoButton];
	}
	else if (_geoButton) {
		if ([_geoButton superview])
			[_geoButton removeFromSuperview];
	}
}
- (void) setFailure:(BOOL)failure
{
	_failure = failure;
	if (failure) {
		if (!_failureButton) {
			self.failureButton = [UIButton buttonWithType:UIButtonTypeCustom];
			CGRect frame = {0,0,29,29};
			_failureButton.frame = frame;
			[_failureButton setImage:_failureImage forState:UIControlStateNormal];
			[_failureButton addTarget:self action:@selector(flagTap:) forControlEvents:UIControlEventTouchUpInside];
		}
		[self.contentView addSubview:_failureButton];
	}
	else if (_failureButton)
		[_failureButton removeFromSuperview];
}


@end
