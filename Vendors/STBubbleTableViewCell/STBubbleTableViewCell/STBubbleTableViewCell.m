//
//  STBubbleTableViewCell.m
//  STBubbleTableViewCellDemo
//
//  Created by Cedric Vandendriessche on 18/04/12.
//  Copyright 2011 FreshCreations. All rights reserved.
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "STBubbleTableViewCell.h"
#import <QuartzCore/QuartzCore.h>
#import "MobileCoreServices/UTCoreTypes.h"

//#define CLASS_DEBUG 1
#import "DDGMacros.h"
//#define CleanLog(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#define CleanLog(FORMAT, ...) ;

const CGFloat kSTBubbleGutterWidth = 70.0;
const CGFloat kSTBubbleImageWidth  = 60.0f;

@interface STBubbleTableViewCell ()

@property (nonatomic, readonly) CGSize textSize;

@property (strong, nonatomic) UITapGestureRecognizer *tapRecognizer;
@property (strong, nonatomic) UITapGestureRecognizer *avatarTapRecognizer;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;
// these are performance enhancements originally tested, but don't discernably show any improvement.  They're faster, but it is unnoticeable.
//@property (strong, nonatomic) UIImageView *burnImageView;
//@property (strong, nonatomic) UIImageView *geoImageView;

//@property (nonatomic) CGFloat gutterWidth;   // Default value: kSTBubbleGutterWidth
//@property (nonatomic) CGFloat imageWidth;    // Default value: kSTBubbleImageWidth

//- (CGFloat) heightForContentViewWithTextSize: (CGSize) size;

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

@implementation STBubbleTableViewCell

@dynamic    height;
@dynamic    textSize;

- (void) dealloc {
	
	[NSNotificationCenter.defaultCenter removeObserver: self];
	
} // -dealloc

#pragma mark - Accessor methods.


const CGFloat kHorizontalPad = 8.0f;

- (CGSize) textSize {
	CGRect tempBounds = _textView.bounds;
	_textView.bounds = self.contentView.bounds;
	CGSize size = [STBubbleTableViewCell sizeForText:self.textView.text withFont:self.textView.font hasAvatar:self.imageView.image ? YES : NO withMaxWidth:self.contentView.bounds.size.width];
	_textView.bounds = tempBounds;
	return size;
}
+ (CGSize) sizeForText: (NSString *) text withFont:(UIFont *) font hasAvatar: (BOOL) hasAvatar withMaxWidth:(CGFloat) maxWidth {
	
	CGSize size;
	//= contentView.bounds.size;
	
	size = (hasAvatar ?
			CGSizeMake(maxWidth - kSTBubbleGutterWidth - kSTBubbleImageWidth - kHorizontalPad, 1024.0f) :
			CGSizeMake(maxWidth - kSTBubbleGutterWidth, 1024.0f));
	
	size = [text sizeWithFont: font //self.textView.font
			constrainedToSize: size
				lineBreakMode: UILineBreakModeWordWrap];
	size.width += 14;		//these two lines are experimental values used temporarily until
	size.height += 14;		// i figure out the best values to keep textview from getting a scroll indicator
	return size;
	
} // -textSize

+(CGFloat) quickHeightForContentViewWithText:(NSString *) text withFont:(UIFont *) font withAvatar:(BOOL) hasAvatar withMaxWidth:(CGFloat)maxWidth
{
	CGFloat height = [STBubbleTableViewCell sizeForText:text withFont:font hasAvatar:hasAvatar withMaxWidth: maxWidth].height;// + 2.0f * (kBubbleHeightPad + kContentPad);
	
	if (hasAvatar) {
		
		CGFloat minHeight = kSTBubbleImageWidth + 2.0f * kContentPad;
		
		height = (height < minHeight ? minHeight : height) + kSTBubbleImageWidth / 2;
	}
	CleanLog(@"QH-text: %@, text height: %f", text, height);
	
	return height;
	
	
}
+(CGFloat) quickHeightForContentViewWithImage:(UIImage *) image withAvatar:(BOOL) hasAvatar
{
	if (hasAvatar) {
		CleanLog(@"QH-image, height: %f", image.size.height + kSTBubbleImageWidth / 2);
		return image.size.height + kSTBubbleImageWidth / 2;// + 2.0f * (kBubbleHeightPad + kContentPad) + 16;
	}
	CleanLog(@"QH-image, height: %f", image.size.height);
	
	return image.size.height;// + 2.0f * (kBubbleHeightPad + kContentPad) + 16;
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
		self.bubbleView = [[STBubbleView alloc] initWithFrame:CGRectZero];
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
		//		_textView.numberOfLines = 0;
		//		_textView.lineBreakMode = UILineBreakModeWordWrap;
		_textView.editable = NO;
		_textView.dataDetectorTypes = UIDataDetectorTypeAll;
		_textView.textColor = [UIColor blackColor];
		//		_textView.font = [UIFont systemFontOfSize:20.0];
		_textView.scrollEnabled = NO;
		[_bubbleView addSubview:_textView];
		//****
		//  for testing
		//		self.contentView.layer.borderColor = [UIColor lightGrayColor].CGColor;
		//		self.contentView.layer.borderWidth = 1.0;
		//		self.imageView.layer.borderColor = [UIColor blueColor].CGColor;
		//		self.imageView.layer.borderWidth = 1.0;
		//
		//		_textView.backgroundColor = [UIColor whiteColor];
		//		_textView.alpha = 0.5;
		//		_bubbleView.mediaLayer.borderColor = [UIColor redColor].CGColor;
		//		_bubbleView.mediaLayer.borderWidth = 1.0;
		// end testing
		//****
		self.imageView.userInteractionEnabled = YES;
		// optimizing
		//		self.imageView.layer.cornerRadius = 5.0;
		//		self.imageView.layer.masksToBounds = YES;
		
		//		_textView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		//		_bubbleView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		
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
		// defaults
		//		_authorType  = STBubbleTableViewCellAuthorTypeNone;
		////		_gutterWidth = kSTBubbleGutterWidth;
		////		_imageWidth  = kSTBubbleImageWidth;
		//		_canCopyContents = YES;
	}
	return self;
	
} // -initWithStyle:reuseIdentifier:


- (void) prepareForReuse {
	
	DDGLog(@"old cell: %@", self.textView.text);
	self.frame = CGRectZero;
	
	_authorType = STBubbleTableViewCellAuthorTypeNone;
	//	_gutterWidth = kSTBubbleGutterWidth;
	//	_imageWidth  = kSTBubbleImageWidth;
	_canCopyContents = YES;
	
	//    [self.bubbleView removeGestureRecognizer: self.longPressRecognizer];
	//    self.longPressRecognizer = nil;
	
	//    _badgeImage = nil;
	self.bubbleImage = nil;
	self.selectedBubbleImage = nil;
	_bubbleImage = nil;
	_selectedBubbleImage = nil;
	
	self.imageView.image = nil;
	//    [self.imageView removeGestureRecognizer: self.avatarTapRecognizer];
	//	self.textLabel.text = _textView.text;
	//	self.textLabel.frame = CGRectMake(0,0,200,50);
	//	self.textLabel.alpha = 0.80;
	// profiling shows that these next two lines contribute ~5% and ~1% of the total time during scrolling
	//	_textView.text = nil;
	//	_textView.frame = CGRectZero;
	// testing change:
	//	NSLog(@"%s, is this always followed by configure?", __PRETTY_FUNCTION__);
	
	
	//    [self.bubbleView removeGestureRecognizer: self.tapRecognizer];
	//    self.tapRecognizer = nil;
	
	[self.bubbleView reset];
	self.hasGeo = NO;
	self.burn = NO;
	self.failure = NO;
} // -prepareForReuse


- (void) placeFlags
{
	//	CGFloat offset = 0;
	//	CGFloat bubbleWidth = _bubbleView.frame.size.width;
	if (_burn) {
		CGRect frame = _burnButton.frame;
		if (_hasGeo)
			frame.origin.y = (self.contentView.bounds.size.height - 2.0 * frame.size.height) / 3.0;
		else
			frame.origin.y = _bubbleView.center.y;
		if (_authorType == STBubbleTableViewCellAuthorTypeUser)	 {
			//			frame.origin.x =  _bubbleView.frame.origin.x - frame.size.width;
			frame.origin.x = 2 * kContentPad;
		}
		else if (_authorType == STBubbleTableViewCellAuthorTypeOther)	 {
			//			frame.origin.x = _bubbleView.frame.origin.x + bubbleWidth;
			frame.origin.x = self.contentView.bounds.size.width - frame.size.width - 2 * kContentPad;
		}
		_burnButton.frame = frame;
		//		offset = frame.size.width + 2;
	}
	if (_hasGeo) {
		CGRect frame = _geoButton.frame;
		if (_burn)
			frame.origin.y = 2.0 * (self.contentView.bounds.size.height - 2.0 * frame.size.height) / 3.0 + frame.size.height;
		else
			frame.origin.y = _bubbleView.center.y;
		if (_authorType == STBubbleTableViewCellAuthorTypeUser)	 {
			//			frame.origin.x = offset;
			frame.origin.x = 2 * kContentPad;
		}
		else if (_authorType == STBubbleTableViewCellAuthorTypeOther)	 {
			//			frame.origin.x = self.contentView.frame.size.width - frame.size.width - offset;
			frame.origin.x = self.contentView.bounds.size.width - frame.size.width - 2 * kContentPad;
		}
		_geoButton.frame = frame;
	}
	if (_failure) {
		CGRect frame = _failureButton.frame;
		frame.origin.y = _bubbleView.frame.origin.y - frame.size.height / 4;
		if (_authorType == STBubbleTableViewCellAuthorTypeUser)	 {
			frame.origin.x =  _bubbleView.frame.origin.x - frame.size.width/2;
		}
		else if (_authorType == STBubbleTableViewCellAuthorTypeOther)	 {
			//			frame.origin.x = _bubbleView.frame.origin.x + bubbleWidth + offset;
			frame.origin.x = _bubbleView.frame.origin.x + _bubbleView.frame.size.width - frame.size.width/2;
		}
		_failureButton.frame = frame;
	}
}


const CGFloat kContentPad      = 4.0f;
const CGFloat kBubbleHeightPad = 6.0f;
const CGFloat kBubbleWidthPad  = 7.0f;
const CGFloat kBubbleCalloutWidth = 9.0f;
const CGFloat kBubbleNonCalloutWidth = 3.0f;
const CGFloat kTextSizeFudge = 5.0f;

#define space_needed_for_icons	10

- (void) layoutSubviews {
	[super layoutSubviews];
	DDGTrace();
	_bubbleView.bubbleImage = self.bubbleImage;
	CGRect bounds = self.contentView.bounds;
	//
	//	if (!self.bubbleView.mediaImage) {
	//		_textView.bounds = bounds; //self.contentView.bounds;	// workaround for odd bug that makes text with multiple spaces behave like there's only one space
	//
	//		bounds.size.height = [STBubbleTableViewCell quickHeightForContentViewWithText:self.textView.text
	//															  withFont:self.textView.font
	//															withAvatar:self.imageView.image ? YES : NO
	//																withMaxWidth:self.contentView.bounds.size.width];
	//	}
	//	else
	//		bounds.size.height = [STBubbleTableViewCell quickHeightForContentViewWithImage:self.bubbleView.mediaImage
	//															 withAvatar:self.imageView.image ? YES : NO];
	//	self.contentView.bounds = bounds;
	
	//	DDGTrace();
	CGFloat imageViewOffset;
	if (self.imageView.image) {
		imageViewOffset = kSTBubbleImageWidth + kHorizontalPad * 3.0f / 2.0f;
		CGFloat leftSide;
		if (_authorType == STBubbleTableViewCellAuthorTypeUser) {
			leftSide = bounds.size.width  - kSTBubbleImageWidth - kHorizontalPad / 2.0f;
		}
		else {
			leftSide = kHorizontalPad / 2.0f;
		}
		self.imageView.frame = CGRectMake(leftSide,
										  bounds.size.height - kSTBubbleImageWidth - 2 * kContentPad,
										  kSTBubbleImageWidth,
										  kSTBubbleImageWidth);
	}
	else {
		imageViewOffset = 0;
		self.imageView.frame = CGRectZero;
	}
	CGFloat bubbleWidth;
	CGFloat bubbleHeight;
	CGFloat calloutAffordance = (_authorType == STBubbleTableViewCellAuthorTypeUser) ? kBubbleNonCalloutWidth : kBubbleCalloutWidth;
	//	CGFloat calloutFactor = (_authorType == STBubbleTableViewCellAuthorTypeUser) ? -1.0 : 1.0;
	if (self.bubbleView.mediaImage) {
		CGSize photoSize = _bubbleView.mediaImage.size;
		bubbleWidth = photoSize.width + kBubbleNonCalloutWidth + kBubbleCalloutWidth;//+ 2;
		bubbleHeight = photoSize.height + 2 * kBubbleNonCalloutWidth + 4;
		_bubbleView.mediaFrame = CGRectMake(calloutAffordance,
											kBubbleNonCalloutWidth,
											photoSize.width,
											photoSize.height);
	}
	else {
		//		CleanLog(@"%s: %@",__PRETTY_FUNCTION__, self.textView.text);
		CGSize size   = self.textSize;
		bubbleWidth  = size.width + kBubbleNonCalloutWidth + kBubbleCalloutWidth;
		bubbleHeight = size.height + 2 * kBubbleNonCalloutWidth;
		self.textView.frame = CGRectMake(calloutAffordance - 1,
										 0,
										 size.width + 3,//+3?
										 size.height);
	}
	CGFloat leftSide;
	if (_authorType == STBubbleTableViewCellAuthorTypeUser) {
		leftSide = bounds.size.width - bubbleWidth - imageViewOffset;
	}
	else {
		leftSide = imageViewOffset;
	}
	
	_bubbleView.frame    = CGRectMake(leftSide,
									  0,
									  bubbleWidth,
									  bubbleHeight);
	
	//	self.textView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	//	_bubbleView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[self placeFlags];
	
	//
	//    if (self.canCopyContents) {
	//
	//        self.longPressRecognizer = [UILongPressGestureRecognizer.alloc initWithTarget: self action: kLongPress];
	//        [self.bubbleView addGestureRecognizer: self.longPressRecognizer];
	//    }
} // -layoutSubviews


#pragma mark - UIGestureRecognizer methods


- (void) longPress: (UILongPressGestureRecognizer *) gestureRecognizer {
	
	DDGTrace();
	//	[_delegate unhideNavBar];
    
	if(gestureRecognizer.state == UIGestureRecognizerStateBegan) {
		
		NSMutableArray* menuItems = [[NSMutableArray alloc] init];
		
		UIMenuItem *burnItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Burn",@"Burn") action:kBurnItem];
		[menuItems addObject:burnItem];
		
		if (_canCopyContents)
		{
			UIMenuItem *forward = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Forward",@"Forward") action:kForward];
			[menuItems addObject:forward];
			
			UIMenuItem *resend = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Send Again",@"Send Again") action:kResend];
			[menuItems addObject:resend];
		}
		
		
		UIMenuController *menuController = [UIMenuController sharedMenuController];
		//		if([_delegate respondsToSelector: @selector(resignActiveTextEntryField)]) {
		//
		//			[_delegate resignActiveTextEntryField];
		//		}
		[self becomeFirstResponder];
		
		[menuController setMenuItems:menuItems];
		
		[menuController setTargetRect: _bubbleView.frame inView: self];
		[menuController setMenuVisible:YES animated:YES];
		
		if (self.selectedBubbleImage) {
			
			_bubbleView.bubbleImage = self.selectedBubbleImage;
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
	else {
		[_delegate unhideNavBar];
		
	}
	// these are performance enhancements originally tested, but don't discernably show any improvement.  They're faster, but it is unnoticeable.
	//	if (_bubbleView.geoImage) {
	//		CGPoint hitPoint = [gestureRecognizer locationInView:_bubbleView];
	//		if(CGRectContainsPoint (_bubbleView.geoRect,
	//								hitPoint)
	//		   && [_delegate respondsToSelector: @selector(tappedGeo:)]) {
	//
	//			[_delegate tappedGeo: self];
	//			return;
	//		}
	//	}
	//	if (_bubbleView.burnImage) {
	//		CGPoint hitPoint = [gestureRecognizer locationInView:_bubbleView];
	//		if(CGRectContainsPoint (_bubbleView.burnRect,
	//								hitPoint)
	//		   && [_delegate respondsToSelector: @selector(tappedBurn:)]) {
	//
	//			[_delegate tappedBurn: self];
	//			return;
	//		}
	//	}
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
		doIt = _authorType == STBubbleTableViewCellAuthorTypeUser;
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
	
	_bubbleView.bubbleImage = self.bubbleImage;
	
	[NSNotificationCenter.defaultCenter removeObserver: self
												  name: UIMenuControllerWillHideMenuNotification
												object: nil];
	
} // -willHideMenuController:

#define flag_border_color lightGrayColor
#define flag_bgnd_color	blackColor
#define flag_size {0,0,30,30}
- (void) setBurn:(BOOL)burn
{
	//	_bubbleView.burnImage = burn ? _burnImage : nil;
	_burn = burn;
	if (burn) {
		if (!_burnButton) {
			self.burnButton = [UIButton buttonWithType:UIButtonTypeCustom];
			_burnButton.contentMode = UIViewContentModeCenter;
			CGRect frame = flag_size;
			//			frame.size = _burnImage.size;
			_burnButton.frame = frame;// = CGRectInset(frame, 3, 2);
									  // shadow
									  //		_burnButton.layer.shadowOffset = CGSizeMake(0, 3);
									  //		_burnButton.layer.shadowRadius = 5.0;
									  //		_burnButton.layer.shadowColor = [UIColor blackColor].CGColor;
									  //		_burnButton.layer.shadowOpacity = 0.8;
									  // frame
									  //		_burnButton.layer.frame = CGRectZero;
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
			//			frame.size = _geoImage.size;
			_geoButton.frame = frame;// = CGRectInset(frame, 3, 2);
									 // shadow
									 //		_geoButton.layer.shadowOffset = CGSizeMake(0, 3);
									 //		_geoButton.layer.shadowRadius = 5.0;
									 //		_geoButton.layer.shadowColor = [UIColor blackColor].CGColor;
									 //		_geoButton.layer.shadowOpacity = 0.8;
									 // frame
									 //		_geoButton.layer.frame = CGRectZero;
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
			//			_failureButton.contentMode = UIViewContentModeScaleAspectFit;
			CGRect frame = {0,0,29,29};
			//			frame.size = _failureImage.size;
			_failureButton.frame = frame;// = CGRectInset(frame, 3, 2);
										 // shadow
										 //		_failureButton.layer.shadowOffset = CGSizeMake(0, 3);
										 //		_failureButton.layer.shadowRadius = 5.0;
										 //		_failureButton.layer.shadowColor = [UIColor blackColor].CGColor;
										 //		_failureButton.layer.shadowOpacity = 0.8;
										 // frame
										 //		_failureButton.layer.frame = CGRectZero;
										 //			_failureButton.layer.backgroundColor = [UIColor darkGrayColor].CGColor;
										 //			_failureButton.layer.borderColor = [UIColor flag_border_color].CGColor;
										 //			_failureButton.layer.borderWidth = 1.0;
										 //			_failureButton.layer.cornerRadius = frame.size.width/2;
			[_failureButton setImage:_failureImage forState:UIControlStateNormal];
			[_failureButton addTarget:self action:@selector(flagTap:) forControlEvents:UIControlEventTouchUpInside];
		}
		[self.contentView addSubview:_failureButton];
	}
	else if (_failureButton)
		[_failureButton removeFromSuperview];
}

// this feels slower
//- (void)drawRect:(CGRect)rect {
//
//    if(self.badgeImage)
//    {
//        CGContextRef context = UIGraphicsGetCurrentContext();
//        CGContextSaveGState(context);
//
//        CGRect contentRect = [self.contentView bounds];
//        CGRect badgeRect = CGRectZero;
//
//        if (_authorType == STBubbleTableViewCellAuthorTypeUser)
//        {
//
//            badgeRect =  CGRectMake( contentRect.size.width - self.bubbleView.frame.size.width -12,
//                                                  contentRect.size.height-24  , 12, 12) ;
//        }
//        else if (_authorType == STBubbleTableViewCellAuthorTypeOther) {
//
//            badgeRect =  CGRectMake( self.bubbleView.frame.size.width ,
//                                                  contentRect.size.height - 20 , 12, 12) ;
//
//         }
//
//         [self.badgeImage drawInRect:badgeRect];
//
//        CGContextRestoreGState(context);
//     }
//
//    [super drawRect:rect];
//
//};

// these are performance enhancements originally tested, but don't discernably show any improvement.  They're faster, but it is unnoticeable.

//- (void) setBurn:(BOOL)burn
//{
////	_bubbleView.burnImage = burn ? _burnImage : nil;
//	_burn = burn;
//	if (burn) {
//		if (!_burnImageView) {
//			self.burnImageView = [[UIImageView alloc] initWithImage:_burnImage];
//			_burnImageView.contentMode = UIViewContentModeScaleAspectFit;
//			CGRect frame = _burnImageView.frame;
//			_burnImageView.frame = frame = CGRectInset(frame, 3, 2);
//			// shadow
//			//		_burnImageView.layer.shadowOffset = CGSizeMake(0, 3);
//			//		_burnImageView.layer.shadowRadius = 5.0;
//			//		_burnImageView.layer.shadowColor = [UIColor blackColor].CGColor;
//			//		_burnImageView.layer.shadowOpacity = 0.8;
//			// frame
//			//		_burnImageView.layer.frame = CGRectZero;
//			_burnImageView.layer.backgroundColor = [UIColor darkGrayColor].CGColor;
//			_burnImageView.layer.borderColor = [UIColor lightGrayColor].CGColor;
//			_burnImageView.layer.borderWidth = 1.0;
//			_burnImageView.layer.cornerRadius = frame.size.width/4;
//		}
//		_burnImageView.image = _burnImage;
//		[self.contentView addSubview:_burnImageView];
//	}
//	else if (_burnImageView)
//		[_burnImageView removeFromSuperview];
//
//}
//- (void) setHasGeo:(BOOL)hasGeo
//{
////	_bubbleView.geoImage = hasGeo ? _geoImage : nil;
//	_hasGeo = hasGeo;
//	if (hasGeo) {
//		if (!_geoImageView) {
//			self.geoImageView = [[UIImageView alloc] initWithImage:_geoImage];
//			_geoImageView.contentMode = UIViewContentModeScaleAspectFit;
//			CGRect frame = _geoImageView.frame;
//			_geoImageView.frame = frame = CGRectInset(frame, 3, 2);
//			// shadow
//			//		_geoImageView.layer.shadowOffset = CGSizeMake(0, 3);
//			//		_geoImageView.layer.shadowRadius = 5.0;
//			//		_geoImageView.layer.shadowColor = [UIColor blackColor].CGColor;
//			//		_geoImageView.layer.shadowOpacity = 0.8;
//			// frame
//			//		_geoImageView.layer.frame = CGRectZero;
//			_geoImageView.layer.backgroundColor = [UIColor darkGrayColor].CGColor;
//			_geoImageView.layer.borderColor = [UIColor lightGrayColor].CGColor;
//			_geoImageView.layer.borderWidth = 1.0;
//			_geoImageView.layer.cornerRadius = frame.size.width/4;
//		}
//		_geoImageView.image = _geoImage;
//		[self.contentView addSubview:_geoImageView];
//	}
//	else if (_geoImageView)
//		[_geoImageView removeFromSuperview];
//}



@end
