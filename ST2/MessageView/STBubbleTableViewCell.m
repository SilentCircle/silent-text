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
#import "STBubbleTableViewCell.h"
#import "STTiledBubbleView.h"
#import "STLogging.h"
#import "AppConstants.h"
#import "SCloudManager.h"
#import "YapCache.h"
#import "YapCollectionKey.h"

#import "UIImage+Thumbnail.h"
#import "UIImage+maskColor.h"

#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTCoreTypes.h>

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_INFO; // | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

// DATA DETECTION

const UIDataDetectorTypes cellDataDetectorTypes = UIDataDetectorTypeAll;

//
// TIMESTAMP
//

// Fixed height of timestamp label
const CGFloat kTimestampHeight = 30;

// Padding around timestamp (if displayed)
const CGFloat kPaddingVerticalBetweenTimestampAndTopOfCell    = 1; // top
const CGFloat kPaddingVerticalBetweenTimestampAndBubble       = 2; // bottom
const CGFloat kPaddingHorizontalBetweenTimestampAndEdgeOfCell = 3; // left & right

//
// AVATAR
//

// Avatar width and height
const CGFloat kAvatarWidth  = 42;
const CGFloat kAvatarHeight = 42;

// Status icon
const CGFloat kStatusIconWidth  = 30;
const CGFloat kStatusIconHeight = 30;

// Space between avatar and edge of cell / tableView.
const CGFloat kPaddingHorizontalBetweenAvatarAndEdgeOfCell = 3;

// A vertical bump to shift avatar upwards from where it would normally sit.
// That is, rather than sitting on the same floor as the text bubble, this will shift it up.
const CGFloat kPaddingVerticalAvatarBump = 2;

//
// BUBBLE
//

// Minimum width and height of bubbles
const CGFloat kMinBubbleWidth = 40;
const CGFloat kMinBubbleHeight = kAvatarHeight + kPaddingVerticalAvatarBump;

// External padding, between top of bubble and top of the cell.
// Not used if a timestamp is present.
const CGFloat kPaddingVerticalBetweenBubbleAndTopOfCell = 2;

// External padding, between bottom of bubble and bottom of the cell.
// Not used if a footer is present.
const CGFloat kPaddingVerticalBetweenBubbleAndBottomOfCell = 2;

// External padding, between edge of bubble and avatar
const CGFloat kPaddingHorizontalBetweenBubbleAndAvatar = -11;

// External padding, between edge of statusView and avatar
const CGFloat kPaddingHorizontalBetweenStatusAndAvatar = 4;

// External padding, between edge of bubble and non-avatar side.
// This is a minimum value for when bubbles are at their widest.
// There is a setting for when cell is with & without buttons.
const CGFloat kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithSideButtons = 60;
const CGFloat kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithoutSideButtons = 20;

// If not displaying an avatar,
// external padding, between edge of bubble and avatar-side (NO avatar)
const CGFloat kPaddingHorizontalBetweenBubbleAndAvatarSideWithoutAvatar = 3;

// Internal padding, between the bubble content (which includes text and possibly name) and the bubble border
const CGFloat kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForText          = 3;
const CGFloat kPaddingVerticalBetweenBubbleContentAndBottomOfBubbleForText       = 4;
const CGFloat kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText   = 11;
const CGFloat kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForText  = 11;

const CGFloat kPaddingHorizontalExtraBetweenBubbleContentAndLeftEdgeOfBubbleForTextWithStatus = kStatusIconWidth;

const CGFloat kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForMedia         = 2;
const CGFloat kPaddingVerticalBetweenBubbleContentAndBottomOfBubbleForMedia      = 2;
const CGFloat kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForMedia  = 2;
const CGFloat kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForMedia = 2;

// The width of the "tail" on the bubble,
// where it curves into a point that points at the avatar
const CGFloat kBubbleTailWidth = 21;

// Vertical padding between the name and the regular text in the bubble (if a name is displayed)
const CGFloat kPaddingVerticalBetweenNameAndText = 6;

// Vertical padding between the name and the image in the bubble (if a name is displayed)
const CGFloat kPaddingVerticalBetweenNameAndMedia = 6;

// Fixed height of name label
const CGFloat kNameHeight = 16;

//
// UITextView padding
//

// The UITextView has some padding on the top, left, bottom & right.
// If we set a contentInset on the UITextView, then we risk cutting off some text.
// So rather than do that, we set these values which do effectively do the same thing.
// That is, we move the frame of the UITextView according to kUITextViewTopInset & kUITextViewLeftInset.
// And we decrement the calculated text size according to the insets,
// even though we set the actual frame size of the UITextView according to what it calculates.
const CGFloat kUITextViewTopInset = -6;
const CGFloat kUITextViewLeftInset = -2;
const CGFloat kUITextViewBottomInset = -6;
const CGFloat kUITextViewRightInset = -2;

//
// BUTTONS
//

// Width and Height of burnButton & geoButton
const CGFloat kButtonDiameter = 24;

// Space between button and bubble.
// And space between each button (if there are multiple)
const CGFloat kPaddingHorizontalBetweenButtonAndBubble = 6;
const CGFloat kPaddingHorizontalBetweenButtons = 4;

//
// FOOTER
//

// Fixed height of timestamp label
const CGFloat kFooterHeight = 24;

// Padding around footer (if displayed)
const CGFloat kPaddingVerticalBetweenFooterAndBubble       = 2; // top
const CGFloat kPaddingVerticalBetweenFooterAndBottomOfCell = 1; // bottom

// A horizontal bump to shift footer a bit from where it would normally sit.
// Positive numbers shifts towards center, negative numbers shift towards the edge of the screen.
const CGFloat kPaddingHorizontalFooterBump = 0;

// Places an orange UIView behind the text,
// in the position where the UITextView should be drawing its text.
#define DEBUG_UITEXTVIEW_CONTENT_INSET 0


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation STBubbleTableViewCell
{
	UITapGestureRecognizer *tapRecognizer;
	UITapGestureRecognizer *avatarTapRecognizer;
	UITapGestureRecognizer *statusTapRecognizer;
    
	MBProgressHUD *progressHUD;
	
#if DEBUG_UITEXTVIEW_CONTENT_INSET
	UIView *debugView;
#endif
}

static YapCache *progressHudCache;
static UITextView *sizeCalcTextView;

+ (void)initialize
{
	static BOOL initialized = NO;
	if (initialized == NO) {
		initialized = YES;
		
		progressHudCache = [[YapCache alloc] initWithCountLimit:25];
		progressHudCache.allowedKeyClasses = [NSSet setWithObject:[YapCollectionKey class]];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(scloudOperation:)
		                                             name:NOTIFICATION_SCLOUD_OPERATION
		                                           object:nil];
		
		sizeCalcTextView = [[UITextView alloc] initWithFrame:CGRectZero];
		sizeCalcTextView.scrollsToTop = NO;
		sizeCalcTextView.backgroundColor = [UIColor clearColor];
		sizeCalcTextView.editable = NO;
		sizeCalcTextView.allowsEditingTextAttributes = NO;
		sizeCalcTextView.textAlignment = NSTextAlignmentLeft;
		sizeCalcTextView.dataDetectorTypes = cellDataDetectorTypes;
		sizeCalcTextView.textColor = [UIColor blackColor];
		sizeCalcTextView.scrollEnabled = NO;
		sizeCalcTextView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0); // top, left, bottom, right
	}
}

+ (void)scloudOperation:(NSNotification *)notification
{
	NSDictionary *userInfo = notification.userInfo;
	
	NSString *status = [userInfo objectForKey:@"status"];
	
	BOOL drop = [status isEqualToString:NOTIFICATION_SCLOUD_UPLOAD_COMPLETE] ||
	            [status isEqualToString:NOTIFICATION_SCLOUD_DOWNLOAD_COMPLETE];
	
	if (drop)
	{
		YapCollectionKey *identifier = [userInfo objectForKey:@"identifier"];;
		
		double delayInSeconds = 5.0;
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
			
			[progressHudCache removeObjectForKey:identifier];
		});
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Height Calculations

/**
 * Calculates and returns the size of the bubble (excluding the tail).
 * 
 * This size represents:
 * - the content (text & optional name)
 * - the internal padding within the bubble (left, right, top, bottom)
**/
+ (CGSize)bubbleSizeWithText:(NSString *)text
                    textFont:(UIFont *)textFont
                        name:(NSString *)name
                    nameFont:(UIFont *)nameFont
                    maxWidth:(CGFloat)maxCellWidth
                   hasAvatar:(BOOL)hasAvatar
                 sideButtons:(BOOL)hasSideButtons
             isStatusMessage:(BOOL)hasStatus
{
	CGFloat maxBubbleWidth;
	CGFloat maxTextWidth;
	
	if (hasAvatar)
	{
		if (hasSideButtons)
		{
			maxBubbleWidth = maxCellWidth
			               - kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithSideButtons
			               - kBubbleTailWidth
			               - kPaddingHorizontalBetweenBubbleAndAvatar
			               - kAvatarWidth
			               - kPaddingHorizontalBetweenAvatarAndEdgeOfCell;
		}
		else
		{
			maxBubbleWidth = maxCellWidth
			               - kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithoutSideButtons
			               - kBubbleTailWidth
			               - kPaddingHorizontalBetweenBubbleAndAvatar
			               - kAvatarWidth
			               - kPaddingHorizontalBetweenAvatarAndEdgeOfCell;
		}
	}
	else
	{
		if (hasSideButtons)
		{
			maxBubbleWidth = maxCellWidth
			               - kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithSideButtons
			               - kBubbleTailWidth
			               - kPaddingHorizontalBetweenBubbleAndAvatarSideWithoutAvatar;
		}
		else
		{
			maxBubbleWidth = maxCellWidth
			               - kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithoutSideButtons
			               - kBubbleTailWidth
			               - kPaddingHorizontalBetweenBubbleAndAvatarSideWithoutAvatar;
		}
	}
	
	maxTextWidth = maxBubbleWidth
	             - kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText
	             - kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForText;
	
	if (hasStatus)
		maxTextWidth -= kPaddingHorizontalExtraBetweenBubbleContentAndLeftEdgeOfBubbleForTextWithStatus;
	
	CGSize maxTextSize = CGSizeMake(maxTextWidth, INFINITY);
	
	// This code doesn't work properly when the string contains emoji's:
/*	NSStringDrawingOptions textOptions = (NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading);
	NSDictionary *textAttributes = @{ NSFontAttributeName : textFont };

	CGRect textRect = [text boundingRectWithSize:maxTextSize options:textOptions attributes:textAttributes context:nil];

	CGSize textSize1;
	textSize1.width = ceilf(textRect.size.width);
	textSize1.height = ceilf(textRect.size.height);
*/
	sizeCalcTextView.font = textFont;
	[sizeCalcTextView setText:text];
	CGSize textSize = [sizeCalcTextView sizeThatFits:maxTextSize];
	
	textSize.height += (kUITextViewTopInset + kUITextViewBottomInset);
	textSize.width  += (kUITextViewLeftInset + kUITextViewRightInset);
	
	CGSize size;
	
	if (name.length > 0)
	{
		NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
		style.lineBreakMode = NSLineBreakByTruncatingTail;
		style.alignment = NSTextAlignmentLeft;
	
		NSDictionary *attributes = @{
			NSFontAttributeName: nameFont,
			NSParagraphStyleAttributeName: style,
		};
		
		NSStringDrawingOptions options = 0; // single-line configuration
	
		CGRect nameRect = [name boundingRectWithSize:CGSizeMake(maxTextWidth, 0.0) // 0.0 means no constraint
		                                     options:options
		                                  attributes:attributes
		                                     context:nil];
		
		// From Apple's documentation for the boundingRectWithSize:::: method:
		//
		//     returns fractional sizes (in the size component of the returned CGRect);
		//     to use a returned size to size views, you must use raise its value to
		//     the nearest higher integer using the ceil function.
		
		CGFloat nameWidth = ceilf(nameRect.size.width);
		
		size.width = MAX(textSize.width, nameWidth);
		size.height = textSize.height + kNameHeight + kPaddingVerticalBetweenNameAndText;
	}
	else
	{
		size = textSize;
	}
	
	size.width += kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText;
	size.width += kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForText;
	size.height += kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForText;
	size.height += kPaddingVerticalBetweenBubbleContentAndBottomOfBubbleForText;
    
	if (hasStatus)
		size.width += kPaddingHorizontalExtraBetweenBubbleContentAndLeftEdgeOfBubbleForTextWithStatus;
 	
	return size;
}

/**
 * Calculates and returns the size of the bubble (excluding the tail).
 *
 * This size represents:
 * - the content (image & optional name)
 * - the internal padding within the bubble (left, right, top, bottom)
**/
+ (CGSize)bubbleSizeWithImage:(UIImage *)image
                         name:(NSString *)name
                     nameFont:(UIFont *)nameFont
                     maxWidth:(CGFloat)maxCellWidth
                    hasAvatar:(BOOL)hasAvatar
                  sideButtons:(BOOL)hasSideButtons
{
	CGFloat maxBubbleWidth;
	CGFloat maxImageWidth;
	CGFloat maxTextWidth;
	
	if (hasAvatar)
	{
		if (hasSideButtons)
		{
			maxBubbleWidth = maxCellWidth
			               - kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithSideButtons
			               - kBubbleTailWidth
			               - kPaddingHorizontalBetweenBubbleAndAvatar
			               - kAvatarWidth
			               - kPaddingHorizontalBetweenAvatarAndEdgeOfCell;
		}
		else
		{
			maxBubbleWidth = maxCellWidth
			               - kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithoutSideButtons
			               - kBubbleTailWidth
			               - kPaddingHorizontalBetweenBubbleAndAvatar
			               - kAvatarWidth
			               - kPaddingHorizontalBetweenAvatarAndEdgeOfCell;
		}
	}
	else
	{
		if (hasSideButtons)
		{
			maxBubbleWidth = maxCellWidth
			               - kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithSideButtons
			               - kBubbleTailWidth
			               - kPaddingHorizontalBetweenBubbleAndAvatarSideWithoutAvatar;
		}
		else
		{
			maxBubbleWidth = maxCellWidth
			               - kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithoutSideButtons
			               - kBubbleTailWidth
			               - kPaddingHorizontalBetweenBubbleAndAvatarSideWithoutAvatar;
		}
	}
	
	maxImageWidth = maxBubbleWidth
	              - kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForMedia
	              - kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForMedia;
	
	maxTextWidth = maxBubbleWidth
	             - kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText
	             - kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForText;
	
	
	CGSize imageSize = image.size;
	if (imageSize.width > maxImageWidth)
		imageSize.width = maxImageWidth;
	
	CGSize size;
	
	if (name.length > 0)
	{
		
		NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
		style.lineBreakMode = NSLineBreakByTruncatingTail;
		style.alignment = NSTextAlignmentLeft;
	
		NSDictionary *attributes = @{
			NSFontAttributeName: nameFont,
			NSParagraphStyleAttributeName: style,
		};
		
		NSStringDrawingOptions options = 0; // single-line configuration
	
		CGRect nameRect = [name boundingRectWithSize:CGSizeMake(maxTextWidth, 0.0) // 0.0 means no constraint
		                                     options:options
		                                  attributes:attributes
		                                     context:nil];
		
		// From Apple's documentation for the boundingRectWithSize:::: method:
		//
		//     returns fractional sizes (in the size component of the returned CGRect);
		//     to use a returned size to size views, you must use raise its value to
		//     the nearest higher integer using the ceil function.
		
		CGSize nameSize = (CGSize){
			.width  = ceilf(nameRect.size.width),
			.height = ceilf(nameRect.size.height)
		};
		
		nameSize.width += kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText;
		nameSize.width += kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForText;
		
		imageSize.width += kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForMedia;
		imageSize.width += kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForMedia;
		
		size.width = MAX(imageSize.width, nameSize.width);
		size.height = imageSize.height + kNameHeight + kPaddingVerticalBetweenNameAndMedia;
		
		size.height += kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForText;
		size.height += kPaddingVerticalBetweenBubbleContentAndBottomOfBubbleForMedia;
		
		return size;
	}
	else
	{
		size = imageSize;
		
		size.width += kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForMedia;
		size.width += kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForMedia;
		size.height += kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForMedia;
		size.height += kPaddingVerticalBetweenBubbleContentAndBottomOfBubbleForMedia;
	}
	
	return size;
}

/**
 * Quick method to get only the height of a text cell with the given parameters.
**/
+ (CGFloat)heightForCellWithStatusText:(NSString *)statusText
                              textFont:(UIFont *)textFont
                                  name:(NSString *)name
                              nameFont:(UIFont *)nameFont
                              maxWidth:(CGFloat)maxWidth
                             hasAvatar:(BOOL)hasAvatar
                           sideButtons:(BOOL)hasSideButtons
                             timestamp:(BOOL)hasTimestamp
                                footer:(BOOL)hasFooter
{
	// Get the size of the bubble (excluding tail).
	
	CGSize bubbleSize = [self bubbleSizeWithText:statusText
	                                    textFont:textFont
	                                        name:name
	                                    nameFont:nameFont
	                                    maxWidth:maxWidth
	                                   hasAvatar:hasAvatar
	                                 sideButtons:hasSideButtons
	                             isStatusMessage:YES];
	
	CGFloat bubbleHeight = bubbleSize.height;
	
	if (bubbleHeight < kMinBubbleHeight)
		bubbleHeight = kMinBubbleHeight;
	
	CGFloat height = bubbleHeight;
    
	if (hasTimestamp)
	{
		// Add room for timestamp, and timestamp padding at the top
		height += kPaddingVerticalBetweenTimestampAndBubble
		       +  kTimestampHeight
		       +  kPaddingVerticalBetweenTimestampAndTopOfCell;
	}
	else
	{
		// Add room for normal bubble padding at the top
		height += kPaddingVerticalBetweenBubbleAndTopOfCell;
	}
    
	if (hasFooter)
	{
		// Add room for footer, and footer padding at the bottom
		height += kPaddingVerticalBetweenFooterAndBubble
		       +  kFooterHeight
		       +  kPaddingVerticalBetweenFooterAndBottomOfCell;
	}
	else
	{
		// Add room for normal bubble padding at the bottom
		height += kPaddingVerticalBetweenBubbleAndBottomOfCell;
	}
	
	return height;
}


/**
 * Quick method to get only the height of a text cell with the given parameters.
**/
+ (CGFloat)heightForCellWithText:(NSString *)text
                        textFont:(UIFont *)textFont
                            name:(NSString *)name
                        nameFont:(UIFont *)nameFont
                        maxWidth:(CGFloat)maxWidth
                       hasAvatar:(BOOL)hasAvatar
                     sideButtons:(BOOL)hasSideButtons
                       timestamp:(BOOL)hasTimestamp
                          footer:(BOOL)hasFooter
{
	// Get the size of the bubble (excluding tail).
	
	CGSize bubbleSize = [self bubbleSizeWithText:text
	                                    textFont:textFont
	                                        name:name
	                                    nameFont:nameFont
	                                    maxWidth:maxWidth
	                                   hasAvatar:hasAvatar
	                                 sideButtons:hasSideButtons
                                 isStatusMessage:NO];
	
	CGFloat bubbleHeight = bubbleSize.height;
	
	if (bubbleHeight < kMinBubbleHeight)
		bubbleHeight = kMinBubbleHeight;
	
	CGFloat height = bubbleHeight;

	if (hasTimestamp)
	{
		// Add room for timestamp, and timestamp padding at the top
		height += kPaddingVerticalBetweenTimestampAndBubble
		       +  kTimestampHeight
		       +  kPaddingVerticalBetweenTimestampAndTopOfCell;
	}
	else
	{
		// Add room for normal bubble padding at the top
		height += kPaddingVerticalBetweenBubbleAndTopOfCell;
	}

	if (hasFooter)
	{
		// Add room for footer, and footer padding at the bottom
		height += kPaddingVerticalBetweenFooterAndBubble
		       +  kFooterHeight
		       +  kPaddingVerticalBetweenFooterAndBottomOfCell;
	}
	else
	{
		// Add room for normal bubble padding at the bottom
		height += kPaddingVerticalBetweenBubbleAndBottomOfCell;
	}
	
	return height;
}

/**
 * Quick method to get only the height of a media cell with the given parameters.
**/
+ (CGFloat)heightForCellWithImage:(UIImage *)image
                             name:(NSString *)name
                         nameFont:(UIFont *)nameFont
                         maxWidth:(CGFloat)maxCellWidth
                        hasAvatar:(BOOL)hasAvatar
                      sideButtons:(BOOL)hasSideButtons
                        timestamp:(BOOL)hasTimestamp
                           footer:(BOOL)hasFooter
{
	// Get the size of the bubble (excluding tail).
	
	CGSize bubbleSize = [self bubbleSizeWithImage:image
	                                         name:name
	                                     nameFont:nameFont
	                                     maxWidth:maxCellWidth
	                                    hasAvatar:hasAvatar
	                                  sideButtons:hasSideButtons];
	
	CGFloat bubbleHeight = bubbleSize.height;
	
	if (bubbleHeight < kMinBubbleHeight)
		bubbleHeight = kMinBubbleHeight;
	
	CGFloat height = bubbleHeight;
    
	if (hasTimestamp)
	{
		// Add room for timestamp, and timestamp padding
		height += kPaddingVerticalBetweenTimestampAndBubble
		       +  kTimestampHeight
		       +  kPaddingVerticalBetweenTimestampAndTopOfCell;
	}
	else
	{
		// Add room for normal bubble padding at the top
		height += kPaddingVerticalBetweenBubbleAndTopOfCell;
	}

	if (hasFooter)
	{
		// Add room for footer, and footer padding
		height += kPaddingVerticalBetweenFooterAndBubble
		       +  kFooterHeight
		       +  kPaddingVerticalBetweenFooterAndBottomOfCell;
	}
	else
	{
		// Add room for normal bubble padding at the top
		height += kPaddingVerticalBetweenBubbleAndBottomOfCell;
	}
	
	return height;
}

+ (CGFloat) widthForSideButtonsWithBurn:(BOOL)hasBurn hasGeo:(BOOL)hasGeo isFYEO:(BOOL)isFYEO isUnPlayed:(BOOL)isUnPlayed
{
    CGFloat	shiftForOtherButtons = 0;
    
    if(hasBurn || hasGeo || isFYEO ||isUnPlayed)
    {
        shiftForOtherButtons += kPaddingHorizontalBetweenButtonAndBubble;
        
    }
    if(hasBurn)
    {
        shiftForOtherButtons += kButtonDiameter + kPaddingHorizontalBetweenButtons;
    }
    
    if(hasGeo)
    {
        shiftForOtherButtons += kButtonDiameter + kPaddingHorizontalBetweenButtons;
    }
    
    if(isFYEO)
    {
        shiftForOtherButtons += kButtonDiameter + kPaddingHorizontalBetweenButtons;
    }
    
    if(isUnPlayed)
    {
        shiftForOtherButtons += kButtonDiameter + kPaddingHorizontalBetweenButtons;
    }
    

    return  shiftForOtherButtons;
    

}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize delegate = delegate;

@synthesize messageId = messageId;

@synthesize theme = theme;

@synthesize bubbleView = bubbleView;
@synthesize avatarImageView = avatarImageView;
@synthesize statusImageView = statusImageView;

@synthesize textView = textView;
@synthesize timestampLabel = timestampLabel;
@synthesize nameLabel = nameLabel;
@synthesize footerLabel = footerLabel;
@synthesize statusView = statusView;

@synthesize burnButton = burnButton;
@synthesize geoButton = geoButton;
@synthesize fyeoButton = fyeoButton;

@synthesize failureButton = failureButton;
@synthesize pendingButton = pendingButton;
@synthesize ignoredButton = ignoredButton;
@synthesize plainTextButton = plainTextButton;
@synthesize signatureCorruptButton = signatureCorruptButton;
@synthesize signatureVerfiedButton = signatureVerfiedButton;
@synthesize signatureKNFButton = signatureKNFButton;
@synthesize unplayedButton = unplayedButton;

@synthesize isOutgoing = isOutgoing;
@synthesize canCopyContents = canCopyContents;
@synthesize hasBurn = hasBurn;
@synthesize hasGeo = hasGeo;
@synthesize isFYEO = isFYEO;
@synthesize failure = failure;
@synthesize pending = pending;
@synthesize ignored = ignored;
@synthesize unplayed = unplayed;
@synthesize signature = signature;
@synthesize isPlainText = isPlainText;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define debug_view_clipping	0
#if debug_view_clipping
static int indexxx;
#endif

- (id)initWithStyle: (UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	DDLogAutoTrace();

	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
	{
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		
		self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth;// | UIViewAutoresizingFlexibleHeight;
		self.contentView.alpha = 1.0;
		self.contentView.opaque = NO;
		self.backgroundColor = [UIColor clearColor];
		self.contentView.backgroundColor = [UIColor clearColor];
		self.clipsToBounds = YES;				// prevents clipping

		// bubbleView
		
		bubbleView = [[STBubbleView alloc] initWithFrame:CGRectZero];

        // avatarImageView
		
		avatarImageView = [[UIImageView alloc] init];
		avatarImageView.userInteractionEnabled = YES;
		
		[self.contentView addSubview:avatarImageView];
        
		// textView
		
		textView = [[UITextView alloc] initWithFrame:CGRectZero];
		textView.scrollsToTop = NO;
		textView.backgroundColor = [UIColor clearColor];
		textView.editable = NO;
		textView.allowsEditingTextAttributes = NO;
		textView.textAlignment = NSTextAlignmentLeft;
		textView.dataDetectorTypes = cellDataDetectorTypes;
		textView.textColor = [UIColor blackColor];
        textView.linkTextAttributes = nil;
		textView.scrollEnabled = NO;
		textView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0); // top, left, bottom, right
		
	#if DEBUG_UITEXTVIEW_CONTENT_INSET
		
		textView.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.0 alpha:0.1];
		
		debugView = [[UIView alloc] init];
		debugView.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.1];

		[bubbleView addSubview:debugView];
		
	#endif
		
//		[bubbleView addSubview:textView];
		[self configureBubbleView:bubbleView];
		
		// Gesture recognizers
				
		avatarTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTap:)];
		[avatarImageView addGestureRecognizer:avatarTapRecognizer];

  		canCopyContents = YES;
	}
	return self;	
}

- (void)prepareForReuse
{
#if debug_view_clipping
	indexxx++;
#endif
	[super prepareForReuse];
//	DDLogPink(@"old cell: %@", self.textView.text);
	
	if ([bubbleView isKindOfClass:[STTiledBubbleView class]])
	{
		UIColor *bubbleColor = bubbleView.bubbleColor;
		[bubbleView removeFromSuperview];
		self.bubbleView = [[STBubbleView alloc] initWithFrame:CGRectZero];
		[self configureBubbleView:bubbleView];
		bubbleView.bubbleColor = bubbleColor;
	}
	else
	{
		[self.bubbleView reset];
	}
	
	messageId = nil;
	
	avatarImageView.image = nil;
    statusImageView.image = nil;
	
	timestampLabel.text = nil;
	nameLabel.text = nil;
	footerLabel.text = nil;
	
	if (progressHUD)
	{
		[progressHUD removeFromSuperview];
		progressHUD = nil;
	}
}

- (void)configureBubbleView:(BubbleView *)aBubbleView
{
	aBubbleView.userInteractionEnabled = YES;
	
	[aBubbleView addSubview:textView];
	[self.contentView addSubview: aBubbleView];
	tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
	tapRecognizer.cancelsTouchesInView = NO;
	[bubbleView addGestureRecognizer:tapRecognizer];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Lazy UI Initialization
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (UILabel *)timestampLabel
{
	if (timestampLabel == nil)
	{
		timestampLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		timestampLabel.autoresizingMask = UIViewAutoresizingNone;
		
		if (theme) {
			timestampLabel.backgroundColor = theme.messageLabelBGColor;
			timestampLabel.textColor = theme.messageLabelTextColor;
		}
		else {
			timestampLabel.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15];
			timestampLabel.textColor = [UIColor blackColor];
		}
		
		timestampLabel.layer.cornerRadius = 10;
		timestampLabel.clipsToBounds = YES;
		
		timestampLabel.textAlignment = NSTextAlignmentCenter;
		timestampLabel.font = [UIFont systemFontOfSize:14.0];
	}
	
	return timestampLabel;
}

- (UILabel *)nameLabel
{
	if (nameLabel == nil)
	{
		nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		nameLabel.backgroundColor = [UIColor clearColor];
		nameLabel.font = [UIFont systemFontOfSize:12.0];
		nameLabel.textColor = theme.messageHeaderColor?:[UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:0.9];
		
		[bubbleView addSubview:nameLabel];
	}

	return nameLabel;
}

- (UILabel *)footerLabel
{
	if (footerLabel == nil)
	{
		footerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		footerLabel.backgroundColor = [UIColor clearColor];
		footerLabel.font = [UIFont systemFontOfSize:11.0];
        
 		[self.contentView addSubview:footerLabel];
	}
	
    if (theme)
        footerLabel.textColor = theme.messageLabelTextColor;
    else
        footerLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.2 alpha:0.5];
    
    if(failure)
        footerLabel.textColor = [UIColor redColor];


	return footerLabel;
}

- (UIImageView *)statusImageView
{
	if (statusImageView == nil)
	{
		statusImageView = [[UIImageView alloc] init];
		statusImageView.userInteractionEnabled = YES;
		
		[self.contentView addSubview:statusImageView];
		
		statusTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(statusTap:)];
		[statusImageView addGestureRecognizer:statusTapRecognizer];
	}
	
	return statusImageView;
}

- (UIView *)statusView
{
	if (statusView == nil)
	{
		statusView = [[UIView alloc] initWithFrame:CGRectZero];
		statusView.autoresizingMask = UIViewAutoresizingNone;
		
		if (theme) {
			statusView.backgroundColor = theme.messageLabelBGColor;
		}
		else {
			statusView.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15];
		}
		
		statusView.layer.cornerRadius = 10;
		statusView.clipsToBounds = YES;
		
		[self.contentView addSubview:statusView];
	}
	
	return statusView;
}

- (MBProgressHUD *)progressHUD
{
	if (progressHUD == nil)
	{
		progressHUD = [[MBProgressHUD alloc] init];
		progressHUD.mode = MBProgressHUDModeIndeterminate;
		progressHUD.animationType = MBProgressHUDAnimationFade;
		progressHUD.square = NO;
		progressHUD.cornerRadius = 10.0F; // should be same as bubbleView.mediaImageView.layer.cornerRadius
		progressHUD.opacity = 0.25;
		progressHUD.delegate = self;
        progressHUD.labelFont = [UIFont boldSystemFontOfSize:12];
 		
		[bubbleView addSubview:progressHUD];
		[self setNeedsLayout];
	}
	
	return progressHUD;
}

- (STBubbleCellButton *)button:(STBubbleCellButton *)button withImage:(UIImage *)image andDiameter:(CGFloat) diameter
{
	if (button == nil)
	{
		button = [[STBubbleCellButton alloc ]initWithImage:image andDiameter: diameter];
		[button addTarget:self action:@selector(buttonTap:) forControlEvents:UIControlEventTouchUpInside];
	}
	button.layer.borderColor = bubbleView.bubbleBorderColor.CGColor;
	
	return button;

}

- (STBubbleCellButton *)burnButton
{
	return burnButton = [self button:burnButton withImage:[UIImage imageNamed:@"flame_btn"] andDiameter:kButtonDiameter];
}

- (STBubbleCellButton *)geoButton
{
	return geoButton = [self button:geoButton withImage:[UIImage imageNamed:@"map_btn"] andDiameter:kButtonDiameter];
}

- (STBubbleCellButton *)fyeoButton
{
	return fyeoButton = [self button:fyeoButton withImage:[UIImage imageNamed:@"fyeo-on"] andDiameter:kButtonDiameter];
}

- (STBubbleCellButton *)failureButton
{
	return failureButton = [self button:failureButton withImage:[UIImage imageNamed:@"failure-btn"] andDiameter:22];
}

- (STBubbleCellButton *)plainTextButton
{
	return plainTextButton = [self button:plainTextButton withImage:[UIImage imageNamed:@"plaintext"] andDiameter:24];
}


- (STBubbleCellButton *)ignoredButton
{
	return ignoredButton = [self button:ignoredButton withImage:[[UIImage imageNamed:@"attention_error"] maskWithColor:[UIColor lightGrayColor]] andDiameter:16];
}

- (STBubbleCellButton *)unplayedButton
{
	return unplayedButton = [self button:unplayedButton withImage:[[UIImage imageNamed:@"unplayed"] maskWithColor:theme.appTintColor] andDiameter:kButtonDiameter];
}


- (STBubbleCellButton *)pendingButton
{
	CGFloat pending_button_size	= kButtonDiameter;
	return pendingButton = [self button:pendingButton withImage:[UIImage imageNamed:@"pending"]  andDiameter:pending_button_size];
}

- (STBubbleCellButton *)signatureVerfiedButton
{
	return signatureVerfiedButton = [self button:signatureVerfiedButton withImage:[[UIImage imageNamed:@"checkmark-circled"] maskWithColor:[UIColor colorWithRed:0 green:.7 blue: 0 alpha:.6 ]] andDiameter:16];
}

- (STBubbleCellButton *)signatureCorruptButton
{
	return signatureCorruptButton = [self button:signatureCorruptButton withImage:[[UIImage imageNamed:@"X-circled"] maskWithColor:[UIColor colorWithRed:1.0 green:.0 blue: 0 alpha:.6 ]] andDiameter:16];
}

- (STBubbleCellButton *)signatureKNFButton
{
	return signatureKNFButton = [self button:signatureKNFButton withImage:[[UIImage imageNamed:@"X-circled"]
													  maskWithColor:[UIColor colorWithRed:1.0 green:1.0 blue: 0 alpha:.6 ]] andDiameter:16];
//	if (signatureKNFButton == nil)
//	{
//		CGRect buttonFrame = CGRectMake(0, 0, 16, 16);
//		
//		signatureKNFButton = [STBubbleCellButtons buttonWithType:UIButtonTypeCustom];
//		signatureKNFButton.frame = buttonFrame;
// 		
//		UIImage *sigKNFImage = [[UIImage imageNamed:@"X-circled"]
//                                    maskWithColor:[UIColor colorWithRed:1.0 green:1.0 blue: 0 alpha:.6 ]];
//		
//		[signatureKNFButton setImage:sigKNFImage forState:UIControlStateNormal];
//        [signatureKNFButton addTarget:self action:@selector(buttonTap:) forControlEvents:UIControlEventTouchUpInside];
//	}
//	
//	return signatureKNFButton;
}

- (MBProgressHUD *)progressHudForConversationId:(NSString *)inConversationId messageId:(NSString *)inMessageId
{
	if (progressHUD)
		return progressHUD;
	
	YapCollectionKey *cacheKey = [[YapCollectionKey alloc] initWithCollection:inConversationId key:inMessageId];
	
	progressHUD = [progressHudCache objectForKey:cacheKey];
	if (progressHUD)
	{
		[bubbleView addSubview:progressHUD];
		[self setNeedsLayout];
	}
	else // if (progressHUD == nil)
	{
		progressHUD = [[MBProgressHUD alloc] init];
		progressHUD.mode = MBProgressHUDModeIndeterminate;
		progressHUD.animationType = MBProgressHUDAnimationFade;
		progressHUD.square = NO;
		progressHUD.cornerRadius = 10.0F; // should be same as bubbleView.mediaImageView.layer.cornerRadius
		progressHUD.opacity = 0.25;
		progressHUD.delegate = self;
        progressHUD.labelFont = [UIFont boldSystemFontOfSize:12];
 		
		[bubbleView addSubview:progressHUD];
		[self setNeedsLayout];
		
		[progressHudCache setObject:progressHUD forKey:cacheKey];
	}
	
	return progressHUD;
}

- (MBProgressHUD *)existingProgressHudForConversationId:(NSString *)inConversationId messageId:(NSString *)inMessageId
{
	if (progressHUD)
		return progressHUD;
	
	YapCollectionKey *cacheKey = [[YapCollectionKey alloc] initWithCollection:inConversationId key:inMessageId];
	
	progressHUD = [progressHudCache objectForKey:cacheKey];
	if (progressHUD)
	{
		[bubbleView addSubview:progressHUD];
		[self setNeedsLayout];
	}
	
	return progressHUD;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableViewCell overrides
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
	[super setSelected:selected animated:animated];
	
	bubbleView.selected = selected;
	
	if (selected)
	{
		statusView.layer.borderColor = [theme.bubbleSelectionBorderColor CGColor];
		statusView.layer.borderWidth = 0.2;
	}
	else
	{
		statusView.layer.borderColor = NULL;
		statusView.layer.borderWidth = 0.0;
	}
}

//- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
//	
////    DDLogPurple(@"%p setHighlighted(%@)",self, @(highlighted));
//
//    [super setHighlighted:highlighted animated:animated];
//  }
//
//- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
//
////    DDLogPurple(@"%p setEditing(%@)", self, @(editing));
//    
//    [super setEditing:editing animated:animated];
//}
//

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Custom Setters
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setHasBurn:(BOOL)inHasBurn
{
	hasBurn = inHasBurn;
	if (hasBurn)
	{
		// Go through self.burnButton property for lazy initialization of button
		if (self.burnButton.superview == nil)
			[self.contentView addSubview:self.burnButton];
	}
	else
	{
		// Do not go through self.burnButton property to avoid lazy initialization
		if (burnButton && burnButton.superview)
			[burnButton removeFromSuperview];
	}
}

- (void)setHasGeo:(BOOL)newHasGeo
{
	hasGeo = newHasGeo;
	if (hasGeo)
	{
		// Go through self.geoButton property for lazy initialization of button
		if (self.geoButton.superview == nil)
			[self.contentView addSubview:self.geoButton];
	}
	else
	{
		// Do not go through self.geoButton property to avoid lazy initialization
		if (geoButton && geoButton.superview)
			[geoButton removeFromSuperview];
	}
}

- (void)setIsFYEO:(BOOL)newIsFYEO
{
	isFYEO = newIsFYEO;
	if (isFYEO)
	{
		// Go through self.geoButton property for lazy initialization of button
		if (self.fyeoButton.superview == nil)
			[self.contentView addSubview:self.fyeoButton];
	}
	else
	{
		// Do not go through self.geoButton property to avoid lazy initialization
		if (fyeoButton && fyeoButton.superview)
			[fyeoButton removeFromSuperview];
	}
}

- (void)setIsPlainText:(BOOL)newPlainText
{
	isPlainText = newPlainText;
	if (isPlainText)
	{
		// Go through self.geoButton property for lazy initialization of button
		if (self.plainTextButton.superview == nil)
			[self.contentView addSubview:self.plainTextButton];
	}
	else
	{
		// Do not go through self.geoButton property to avoid lazy initialization
		if (plainTextButton && plainTextButton.superview)
			[plainTextButton removeFromSuperview];
	}
    
}

- (void)setFailure:(BOOL)newFailure
{
	failure = newFailure;
	if (failure)
	{
		// Go through self.failureButton property for lazy initialization of button
		if (self.failureButton.superview == nil)
		 [self.contentView addSubview:self.failureButton];
	}
	else
	{
		// Do not go through self.failureButton property to avoid lazy initialization
		if (failureButton && failureButton.superview)
			[failureButton removeFromSuperview];
	}
}

- (void)setPending:(BOOL)newPending
{
	pending = newPending;
	if (pending)
	{
		// Go through pendingButton property for lazy initialization of button
		if (self.pendingButton.superview == nil)
            [self.contentView addSubview:self.pendingButton];
	}
	else
	{
		// Do not go through pendingButton property to avoid lazy initialization
		if (pendingButton && pendingButton.superview)
			[pendingButton removeFromSuperview];
	}
}

- (void)setIgnored:(BOOL)newIgnored
{
	ignored = newIgnored;
	if (ignored)
	{
		// Go through ignoredButton property for lazy initialization of button
		if (self.ignoredButton.superview == nil)
            [self.contentView addSubview:self.ignoredButton];
	}
	else
	{
		// Do not go through ignoredButton property to avoid lazy initialization
		if (ignoredButton && ignoredButton.superview)
			[ignoredButton removeFromSuperview];
	}
}

- (void)setUnplayed:(BOOL)newUnplayed
{
	unplayed = newUnplayed;
	if (unplayed)
	{
		// Go through unplayedButton property for lazy initialization of button
		if (self.unplayedButton.superview == nil)
            [self.contentView addSubview:self.unplayedButton];
	}
	else
	{
		// Do not go through unplayedButton property to avoid lazy initialization
		if (unplayedButton && unplayedButton.superview)
			[unplayedButton removeFromSuperview];
	}
}


- (void)setSignature:(BubbleSignature_State)newSignature
{
	signature = newSignature;
    
	if (newSignature == kBubbleSignature_Verified)
	{
        if (signatureCorruptButton && signatureCorruptButton.superview)
			[signatureCorruptButton removeFromSuperview];

        if (signatureKNFButton && signatureKNFButton.superview)
			[signatureKNFButton removeFromSuperview];

		// Go through pendingButton property for lazy initialization of button
		if (self.signatureVerfiedButton.superview == nil)
            [self.contentView addSubview:self.signatureVerfiedButton];
	}
    else if (newSignature == kBubbleSignature_KeyNotFound)
	{
        if (signatureCorruptButton && signatureCorruptButton.superview)
			[signatureCorruptButton removeFromSuperview];

        if (signatureVerfiedButton && signatureVerfiedButton.superview)
			[signatureVerfiedButton removeFromSuperview];
        
		// Go through signatureButton property for lazy initialization of button
		if (self.signatureKNFButton.superview == nil)
            [self.contentView addSubview:self.signatureKNFButton];
	}
    else if (newSignature == kBubbleSignature_Corrupt)
	{
        if (signatureVerfiedButton && signatureVerfiedButton.superview)
			[signatureVerfiedButton removeFromSuperview];
  
        if (signatureKNFButton && signatureKNFButton.superview)
			[signatureKNFButton removeFromSuperview];

		// Go through signatureButton property for lazy initialization of button
		if (self.signatureCorruptButton.superview == nil)
            [self.contentView addSubview:self.signatureCorruptButton];
	}
	else
	{
		// Do not go through signatureButton property to avoid lazy initialization
		if (signatureVerfiedButton && signatureVerfiedButton.superview)
			[signatureVerfiedButton removeFromSuperview];
        
        if (signatureCorruptButton && signatureCorruptButton.superview)
			[signatureCorruptButton removeFromSuperview];

	    if (signatureKNFButton && signatureKNFButton.superview)
			[signatureKNFButton removeFromSuperview];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Custom Getters
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)hasTimestamp
{
	return ([timestampLabel.text length] > 0);
}

- (BOOL)hasName
{
	return nameLabel.text.length > 0;
}

- (BOOL)hasFooter
{
	return ([footerLabel.text length] > 0);
}

- (BOOL)hasSideButtons
{
	return hasBurn || hasGeo || isFYEO || unplayed;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Layout
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)refreshColorsFromTheme
{
	if (statusImageView.image != nil)
	{
		// Status Message
		
		textView.textColor = theme.messageLabelTextColor;
		textView.linkTextAttributes = nil;
	}
	else if (isOutgoing)
	{
		// Outgoing Message (right side of table)
		
		bubbleView.bubbleColor          = theme.selfBubbleColor;
		bubbleView.bubbleBorderColor    = theme.selfBubbleBorderColor;
		bubbleView.bubbleSelectionColor = theme.bubbleSelectionBorderColor;
		
		textView.textColor = theme.selfBubbleTextColor;
		textView.linkTextAttributes = theme.selfLinkTextAttributes;
	}
	else
	{
		// Incoming Message (left side of table)
		
		bubbleView.bubbleColor          = theme.otherBubbleColor;
		bubbleView.bubbleBorderColor    = theme.otherBubbleBorderColor;
		bubbleView.bubbleSelectionColor = theme.bubbleSelectionBorderColor;
		
		textView.textColor = theme.otherBubbleTextColor;
		textView.linkTextAttributes = theme.otherLinkTextAttributes;
	}
//	NSLog(@"%s: textColor: %@, bubblecolor %@", __PRETTY_FUNCTION__, textView.textColor, bubbleView.bubbleColor);
//	CGFloat white, alpha;
//	[bubbleView.bubbleColor getWhite:&white alpha:&alpha];
//	if (white != 0.25)
//		NSLog(@"stophi");
	timestampLabel.textColor = theme.messageLabelTextColor;
	
	if (failure)
		footerLabel.textColor = [UIColor redColor];
	else
		footerLabel.textColor = theme.messageLabelTextColor;
}

- (void)layoutSubviews
{
	DDLogAutoTrace();
	[super layoutSubviews];
	
	CGRect bounds = self.contentView.bounds;

	BOOL hasAvatar = (avatarImageView.image != nil);
	BOOL hasStatus = (statusImageView.image != nil);
    
	BOOL hasSideButtons = [self hasSideButtons];
	
	CGFloat topOffset;
	CGFloat bottomOffset;
	
	//
	// Timestamp
	//
	
	if (timestampLabel.text.length > 0)
	{
		CGRect fullFrame = (CGRect){
			.origin.x = kPaddingHorizontalBetweenTimestampAndEdgeOfCell,
			.origin.y = kPaddingVerticalBetweenTimestampAndTopOfCell,
			.size.width = bounds.size.width - (2 * kPaddingHorizontalBetweenTimestampAndEdgeOfCell),
			.size.height = kTimestampHeight
		};
		
		CGSize textSize = [timestampLabel.text sizeWithAttributes:@{ NSFontAttributeName : timestampLabel.font }];
		textSize.width += 40;
		textSize.height += 4;
		
		if (textSize.width > fullFrame.size.width)
			textSize.width = fullFrame.size.width;
		
		if (textSize.height > fullFrame.size.height)
			textSize.height = fullFrame.size.height;
		
		CGRect timestampFrame = (CGRect){
			.origin.x = fullFrame.origin.x + ((fullFrame.size.width - textSize.width) / 2),
			.origin.y = fullFrame.origin.y + ((fullFrame.size.height - textSize.height) / 2),
			.size = textSize
		};
		
		if (timestampLabel.superview == nil)
			[self.contentView addSubview:timestampLabel];
		
		timestampLabel.frame = timestampFrame;
		
		topOffset = kPaddingVerticalBetweenTimestampAndTopOfCell
		          + kTimestampHeight
		          + kPaddingVerticalBetweenTimestampAndBubble;
	}
	else
	{
		if (timestampLabel.superview)
			[timestampLabel removeFromSuperview];
		
		topOffset = kPaddingVerticalBetweenBubbleAndTopOfCell;
	}

	//
	// Footer
	//
	
	if (footerLabel.text.length > 0)
	{
		CGFloat offsetNear = 0;
		CGFloat offsetFar = 0;
		
		if (hasAvatar)
		{
			offsetNear = kPaddingHorizontalBetweenAvatarAndEdgeOfCell
			           + kAvatarWidth
			           + kPaddingHorizontalBetweenBubbleAndAvatar
			           + kPaddingHorizontalFooterBump;
			
			if (hasSideButtons)
				offsetFar = kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithSideButtons;
			else
				offsetFar = kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithoutSideButtons;
		}
		else
		{
			offsetNear = kPaddingHorizontalBetweenBubbleAndAvatarSideWithoutAvatar + kPaddingHorizontalFooterBump;
			
			if (hasSideButtons)
				offsetFar = kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithSideButtons;
			else
				offsetFar = kPaddingHorizontalBetweenBubbleAndNonAvatarSideMinimumWithoutSideButtons;
		}
		
		CGRect footerFrame = (CGRect){
			.origin.x = isOutgoing ? offsetFar : offsetNear,
			.origin.y = bounds.size.height - kFooterHeight - kPaddingVerticalBetweenFooterAndBottomOfCell,
			.size.width = bounds.size.width - offsetNear - offsetFar,
			.size.height = kFooterHeight
		};
		
		if (footerLabel.superview == nil)
			[self.contentView addSubview:footerLabel];
		
		footerLabel.frame = footerFrame;
		footerLabel.textAlignment = isOutgoing ? NSTextAlignmentRight : NSTextAlignmentLeft;
		
		bottomOffset = kPaddingVerticalBetweenFooterAndBubble
		             + kFooterHeight
		             + kPaddingVerticalBetweenFooterAndBottomOfCell;
	}
	else
	{
		footerLabel.frame = CGRectZero;
		
		bottomOffset = kPaddingVerticalBetweenBubbleAndBottomOfCell;
	}
	
	//
	// Avatar
	//
	
	if (hasAvatar)
	{
		if (isOutgoing)
		{
			avatarImageView.frame = (CGRect){
				.origin.x = bounds.size.width  - kAvatarWidth - kPaddingHorizontalBetweenAvatarAndEdgeOfCell,
				.origin.y = bounds.size.height - kAvatarHeight - bottomOffset - kPaddingVerticalAvatarBump,
				.size.width = kAvatarWidth,
				.size.height = kAvatarHeight
			};
			avatarImageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		}
		else
		{
			avatarImageView.frame = (CGRect){
				.origin.x = kPaddingHorizontalBetweenAvatarAndEdgeOfCell,
				.origin.y = bounds.size.height - kAvatarHeight - bottomOffset - kPaddingVerticalAvatarBump,
				.size.width = kAvatarWidth,
				.size.height = kAvatarHeight
			};
			avatarImageView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
		}
	}
	else
	{
		avatarImageView.frame = CGRectZero;
	}
	
    
	//
	// Bubble & Content
	//
	
	CGSize bubbleSize;
	
	if (bubbleView.mediaImage)
	{
		//
		// Media Message
		//
		
		if (textView.superview == statusView)
		{
			[bubbleView addSubview:nameLabel];
			[bubbleView addSubview:textView];
			
			statusView.hidden = YES;
			bubbleView.hidden = NO;
		}
		
		textView.hidden = YES;
		
		bubbleSize = [STBubbleTableViewCell bubbleSizeWithImage:bubbleView.mediaImage
		                                                  name:nameLabel.text
		                                              nameFont:nameLabel.font
		                                              maxWidth:bounds.size.width
		                                             hasAvatar:hasAvatar
		                                           sideButtons:hasSideButtons];
		
		CGFloat xOffset = isOutgoing ? 0 : kBubbleTailWidth;
		
		if (bubbleSize.width < kMinBubbleWidth)
			bubbleSize.width = kMinBubbleWidth;
		
		if (bubbleSize.height < kMinBubbleHeight)
			bubbleSize.height = kMinBubbleHeight;
		
		// If the bubble is extra wide (due to kMinBubbleWidth requirement, or because name is wider than image),
		// then we want to center the image within the excess space.
		
		CGFloat imgWidthAvailable = bubbleSize.width
		                          - kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForMedia
		                          - kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForMedia;
		
		CGFloat imgOffset = (imgWidthAvailable - bubbleView.mediaImage.size.width) / 2.0;
		
		if ([self hasName])
		{
			CGFloat nameWidth = bubbleSize.width
			                  - kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText
			                  - kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForText;
	          
			nameLabel.hidden = NO;
			nameLabel.frame = (CGRect){
				.origin.x = kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText + xOffset,
				.origin.y = kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForText,         // pin to top
				.size.width = nameWidth,
				.size.height = kNameHeight
			};
			
			bubbleView.mediaFrame = (CGRect){
				.origin.x = kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForMedia + xOffset + imgOffset,
				.origin.y = bubbleSize.height - bubbleView.mediaImage.size.height -
				            kPaddingVerticalBetweenBubbleContentAndBottomOfBubbleForMedia,     // pin to bottom
				.size = bubbleView.mediaImage.size
			};
		}
		else
		{
			nameLabel.hidden = YES;
			nameLabel.frame = CGRectZero;
			
			bubbleView.mediaFrame = (CGRect){
				.origin.x = kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForMedia + xOffset + imgOffset,
				.origin.y = bubbleSize.height - bubbleView.mediaImage.size.height -
							kPaddingVerticalBetweenBubbleContentAndBottomOfBubbleForMedia,     // pin to bottom
				.size = bubbleView.mediaImage.size
			};
		}
		
		bubbleSize.width += kBubbleTailWidth;
		
		if (bubbleSize.height > 8000) // views more than 8K cause problems so we must switch to tiled layers
		{
			UIColor *bubbleColor = bubbleView.bubbleColor;
			[bubbleView removeFromSuperview];
			self.bubbleView = [[STTiledBubbleView alloc] initWithFrame:CGRectZero];
			[self configureBubbleView:bubbleView];
			bubbleView.bubbleColor = bubbleColor;
		}
		
		CGFloat avatarOffset;
		if (hasAvatar)
		{
			avatarOffset = kPaddingHorizontalBetweenAvatarAndEdgeOfCell
			             + kAvatarWidth
			             + kPaddingHorizontalBetweenBubbleAndAvatar;
		}
		else
		{
			avatarOffset = kPaddingHorizontalBetweenBubbleAndAvatarSideWithoutAvatar;
		}
		
		if (isOutgoing)
		{
			bubbleView.frame = (CGRect){
				.origin.x = bounds.size.width - avatarOffset - bubbleSize.width,
				.origin.y = bounds.size.height - bubbleSize.height - bottomOffset,
				.size = bubbleSize
			};
		}
		else
		{
			bubbleView.frame = (CGRect){
				.origin.x = avatarOffset,
				.origin.y = bounds.size.height - bubbleSize.height - bottomOffset,
				.size = bubbleSize
			};
		}
		
		bubbleView.authorTypeSelf = isOutgoing;
		bubbleView.selected = self.selected;
	}
	else if (!hasStatus)
	{
		//
		// Text Message
		//
		
		if (textView.superview == statusView)
		{
			[bubbleView addSubview:nameLabel];
			[bubbleView addSubview:textView];
			
			statusView.hidden = YES;
			bubbleView.hidden = NO;
		}
		
		bubbleSize = [STBubbleTableViewCell bubbleSizeWithText:textView.text
		                                              textFont:textView.font
		                                                  name:nameLabel.text
		                                              nameFont:nameLabel.font
		                                              maxWidth:bounds.size.width
		                                             hasAvatar:hasAvatar
		                                           sideButtons:hasSideButtons
                                               isStatusMessage:hasStatus];
		
		CGFloat xOffset = isOutgoing ? 0 : kBubbleTailWidth;
		CGFloat yOffset = 0;
		
		CGFloat widthOffset = 0;
		CGFloat heightOffset = 0;
		
		if (bubbleSize.width < kMinBubbleWidth)
		{
			// if we force the bubble to be wider, we want
			// name and text to "center" within extra area.
			widthOffset = (kMinBubbleWidth - bubbleSize.width);
			xOffset += ((kMinBubbleWidth - bubbleSize.width) / 2);
			bubbleSize.width = kMinBubbleWidth;
		}
		if (bubbleSize.height < kMinBubbleHeight)
		{
			// if we force the bubble to be taller, we want:
			// - name pinned to the top still
			// - text to center in area below name
			heightOffset = (kMinBubbleHeight - bubbleSize.height);
			yOffset = ((kMinBubbleHeight - bubbleSize.height) / 2);
			bubbleSize.height = kMinBubbleHeight;
		}
		
		CGFloat contentWidth = bubbleSize.width
		                     - kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText
		                     - kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForText;
		
		CGFloat contentHeight = bubbleSize.height
		                      - kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForText
		                      - kPaddingVerticalBetweenBubbleContentAndBottomOfBubbleForText;
		
		if ([self hasName])
		{
			nameLabel.hidden = NO;
			nameLabel.frame = (CGRect){
				.origin.x = kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText
				          + xOffset,
				.origin.y = kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForText,         // pin to top
				.size.width = contentWidth - widthOffset,
				.size.height = kNameHeight
			};
			
			CGFloat xOffsetExtra = hasStatus
			  ? kPaddingHorizontalExtraBetweenBubbleContentAndLeftEdgeOfBubbleForTextWithStatus
			  : 0.0;
			
			CGFloat textWidth = contentWidth - widthOffset - xOffsetExtra
			                  - kUITextViewLeftInset - kUITextViewRightInset;
			
			CGFloat textHeight = contentHeight - heightOffset
			                   - kNameHeight - kPaddingVerticalBetweenNameAndText
			                   - kUITextViewTopInset - kUITextViewBottomInset;
			
			textView.hidden = NO;
			textView.frame = (CGRect){
				.origin.x = kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText
				          + xOffset
				          + xOffsetExtra
				          + kUITextViewLeftInset,
				.origin.y = bubbleSize.height                                                  // pin to bottom
				          - kPaddingVerticalBetweenBubbleContentAndBottomOfBubbleForText
				          - textHeight
				          - yOffset,
				.size.width = textWidth,
				.size.height = textHeight
			};
		}
		else
		{
			nameLabel.hidden = YES;
			nameLabel.frame = CGRectZero;
			
			CGFloat xOffsetExtra = hasStatus
			  ? kPaddingHorizontalExtraBetweenBubbleContentAndLeftEdgeOfBubbleForTextWithStatus
			  : 0.0;
			
			textView.hidden = NO;
			textView.frame = (CGRect){
				.origin.x = kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText
				          + xOffset
				          + xOffsetExtra
				          + kUITextViewLeftInset,
				.origin.y = kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForText
				          + yOffset
				          + kUITextViewTopInset,
				.size.width = contentWidth - xOffsetExtra - kUITextViewLeftInset - kUITextViewRightInset,
				.size.height = contentHeight - kUITextViewTopInset - kUITextViewBottomInset
			};
		}
		
		#if DEBUG_UITEXTVIEW_CONTENT_INSET
		
		CGRect debugViewFrame = textView.frame;
		debugViewFrame.origin.x -= kUITextViewLeftInset;
		debugViewFrame.origin.y -= kUITextViewTopInset;
		debugViewFrame.size.width += (kUITextViewLeftInset + kUITextViewRightInset);
		debugViewFrame.size.height += (kUITextViewTopInset + kUITextViewBottomInset);
		
		debugView.frame = debugViewFrame;
		
		#endif
		
		bubbleSize.width += kBubbleTailWidth;
		
		if (bubbleSize.height > 8000) // views more than 8K cause problems so we must switch to tiled layers
		{
			UIColor *bubbleColor = bubbleView.bubbleColor;
			[bubbleView removeFromSuperview];
			self.bubbleView = [[STTiledBubbleView alloc] initWithFrame:CGRectZero];
			[self configureBubbleView:bubbleView];
			bubbleView.bubbleColor = bubbleColor;
		}
		
		CGFloat avatarOffset;
		if (hasAvatar)
		{
			avatarOffset = kPaddingHorizontalBetweenAvatarAndEdgeOfCell
			             + kAvatarWidth
			             + kPaddingHorizontalBetweenBubbleAndAvatar;
		}
		else
		{
			avatarOffset = kPaddingHorizontalBetweenBubbleAndAvatarSideWithoutAvatar;
		}
		
		if (isOutgoing)
		{
			bubbleView.frame = (CGRect){
				.origin.x = bounds.size.width - avatarOffset - bubbleSize.width,
				.origin.y = bounds.size.height - bubbleSize.height - bottomOffset,
				.size = bubbleSize
			};
		}
		else
		{
			bubbleView.frame = (CGRect){
				.origin.x = avatarOffset,
				.origin.y = bounds.size.height - bubbleSize.height - bottomOffset,
				.size = bubbleSize
			};
		}
		
		bubbleView.authorTypeSelf = isOutgoing;
		bubbleView.selected = self.selected;
	}
	else // if (hasStatus)
	{
		//
		// Status Message
		//
		
		if (textView.superview == bubbleView)
		{
			[self.statusView addSubview:nameLabel];
			[self.statusView addSubview:textView];
			
			bubbleView.hidden = YES;
			statusView.hidden = NO;
		}
		
		bubbleSize = [STBubbleTableViewCell bubbleSizeWithText:textView.text
		                                              textFont:textView.font
		                                                  name:nameLabel.text
		                                              nameFont:nameLabel.font
		                                              maxWidth:bounds.size.width
		                                             hasAvatar:hasAvatar
		                                           sideButtons:hasSideButtons
                                               isStatusMessage:hasStatus];
		
		CGFloat xOffset = 0;
		CGFloat yOffset = 0;
		
		CGFloat widthOffset = 0;
		CGFloat heightOffset = 0;
		
		if (bubbleSize.width < kMinBubbleWidth)
		{
			// if we force the bubble to be wider, we want
			// name and text to "center" within extra area.
			widthOffset = (kMinBubbleWidth - bubbleSize.width);
			xOffset += ((kMinBubbleWidth - bubbleSize.width) / 2);
			bubbleSize.width = kMinBubbleWidth;
		}
		if (bubbleSize.height < kMinBubbleHeight)
		{
			// if we force the bubble to be taller, we want:
			// - name pinned to the top still
			// - text to center in area below name
			heightOffset = (kMinBubbleHeight - bubbleSize.height);
			yOffset = ((kMinBubbleHeight - bubbleSize.height) / 2);
			bubbleSize.height = kMinBubbleHeight;
		}
		
		CGFloat contentWidth = bubbleSize.width
		                     - kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText
		                     - kPaddingHorizontalBetweenBubbleContentAndRightEdgeOfBubbleForText;
		
		CGFloat contentHeight = bubbleSize.height
		                      - kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForText
		                      - kPaddingVerticalBetweenBubbleContentAndBottomOfBubbleForText;
		
		if (nameLabel.text.length > 0)
		{
			nameLabel.hidden = NO;
			nameLabel.frame = (CGRect){
				.origin.x = kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText
				          + xOffset,
				.origin.y = kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForText,         // pin to top
				.size.width = contentWidth - widthOffset,
				.size.height = kNameHeight
			};
			
			CGFloat xOffsetExtra = hasStatus
			  ? kPaddingHorizontalExtraBetweenBubbleContentAndLeftEdgeOfBubbleForTextWithStatus
			  : 0.0;
			
			CGFloat textWidth = contentWidth - widthOffset - xOffsetExtra
			                  - kUITextViewLeftInset - kUITextViewRightInset;
			
			CGFloat textHeight = contentHeight - heightOffset
			                   - kNameHeight - kPaddingVerticalBetweenNameAndText
			                   - kUITextViewTopInset - kUITextViewBottomInset;
			
			textView.hidden = NO;
			textView.frame = (CGRect){
				.origin.x = kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText
				          + xOffset
				          + xOffsetExtra
				          + kUITextViewLeftInset,
				.origin.y = bubbleSize.height                                                  // pin to bottom
				          - kPaddingVerticalBetweenBubbleContentAndBottomOfBubbleForText
				          - textHeight
				          - yOffset,
				.size.width = textWidth,
				.size.height = textHeight
			};
		}
		else
		{
			nameLabel.hidden = YES;
			nameLabel.frame = CGRectZero;
			
			CGFloat xOffsetExtra = hasStatus
			  ? kPaddingHorizontalExtraBetweenBubbleContentAndLeftEdgeOfBubbleForTextWithStatus
			  : 0.0;
			
			textView.hidden = NO;
			textView.frame = (CGRect){
				.origin.x = kPaddingHorizontalBetweenBubbleContentAndLeftEdgeOfBubbleForText
				          + xOffset
				          + xOffsetExtra
				          + kUITextViewLeftInset,
				.origin.y = kPaddingVerticalBetweenBubbleContentAndTopOfBubbleForText
				          + yOffset
				          + kUITextViewTopInset,
				.size.width = contentWidth - xOffsetExtra - kUITextViewLeftInset - kUITextViewRightInset,
				.size.height = contentHeight - kUITextViewTopInset - kUITextViewBottomInset
			};
		}
		
	//	bubbleSize.width += kBubbleTailWidth;
		
		if (bubbleSize.height > 8000) // views more than 8K cause problems so we must switch to tiled layers
		{
			UIColor *bubbleColor = bubbleView.bubbleColor;
			[bubbleView removeFromSuperview];
			self.bubbleView = [[STTiledBubbleView alloc] initWithFrame:CGRectZero];
			[self configureBubbleView:bubbleView];
			bubbleView.bubbleColor = bubbleColor;
		}
		
		CGFloat avatarOffset;
		if (hasAvatar)
		{
			avatarOffset = kPaddingHorizontalBetweenAvatarAndEdgeOfCell
			             + kAvatarWidth
			             + kPaddingHorizontalBetweenStatusAndAvatar;
		}
		else
		{
			avatarOffset = kPaddingHorizontalBetweenBubbleAndAvatarSideWithoutAvatar;
		}
		
		
		if (isOutgoing)
		{
			statusView.frame = (CGRect){
				.origin.x = bounds.size.width - avatarOffset - bubbleSize.width,
				.origin.y = bounds.size.height - bubbleSize.height - bottomOffset,
				.size = bubbleSize
			};
		}
		else
		{
			statusView.frame = (CGRect){
				.origin.x = avatarOffset,
				.origin.y = bounds.size.height - bubbleSize.height - bottomOffset,
				.size = bubbleSize
			};
		}
		
		if (self.selected)
		{
			statusView.layer.borderColor = [theme.bubbleSelectionBorderColor CGColor];
			statusView.layer.borderWidth = 0.2;
		}
		else
		{
			statusView.layer.borderColor = NULL;
			statusView.layer.borderWidth = 0.0;
		}
		
		statusImageView.frame = (CGRect){
			.origin.x = statusView.frame.origin.x + 10,
			.origin.y = statusView.frame.origin.y + ((statusView.frame.size.height - kStatusIconHeight) / 2.0F),
			.size.width = kStatusIconWidth,
			.size.height = kStatusIconHeight
		};
	}

	//
	// Progress HUD
	//
	
	if (progressHUD)
	{
		if (bubbleView.mediaImage)
		{
			// The progressHUD wants to set it's own frame.
			// So we have to give it more information about the frame we want it to have.
			
			CGFloat wOffset =  0.0F; // nudge width
			CGFloat hOffset =  0.0F; // nudge height
			
			CGFloat xOffset = -0.5F; // nudge x position
			CGFloat yOffset =  0.0F; // nudge y position
			
			CGRect frame = bubbleView.mediaFrame;
			frame.size.width += wOffset;
			frame.size.height += hOffset;
			
			progressHUD.frame = frame;
			progressHUD.minSize = frame.size;
			
			CGPoint bubbleCenter;
			bubbleCenter.x = bubbleView.frame.size.width / 2.0F;
			bubbleCenter.y = bubbleView.frame.size.height / 2.0F;
			
			CGPoint mediaCenter;
			mediaCenter.x = frame.origin.x + (frame.size.width / 2.0F);
			mediaCenter.y = frame.origin.y + (frame.size.height / 2.0F);
			
			progressHUD.xOffset = mediaCenter.x - bubbleCenter.x + xOffset;
			progressHUD.yOffset = mediaCenter.y - bubbleCenter.y + yOffset;
		}
		else
		{
			progressHUD.frame = CGRectZero;
			progressHUD.hidden = YES;
		}
	}
	
	//
	// Buttons
	//
	
	CGFloat	shiftForOtherButtons = 0;

    
    if (unplayed)
	{
		CGRect frame = self.unplayedButton.frame;
		frame.origin.y = bubbleView.center.y - (frame.size.height / 2);
		
		if (isOutgoing)
		{
			frame.origin.x = bubbleView.frame.origin.x - frame.size.width
            - kPaddingHorizontalBetweenButtonAndBubble  - shiftForOtherButtons;
		}
		else
		{
			frame.origin.x = bubbleView.frame.origin.x + bubbleView.frame.size.width
            + kPaddingHorizontalBetweenButtonAndBubble + shiftForOtherButtons;
		}
		
		unplayedButton.frame = frame;
		shiftForOtherButtons += frame.size.width + kPaddingHorizontalBetweenButtons;
	}
    

	if (hasBurn)
	{
        CGRect frame = self.burnButton.frame;
		frame.origin.y = bubbleView.center.y - (frame.size.height / 2);
		
		if (isOutgoing)
		{
			frame.origin.x = bubbleView.frame.origin.x - frame.size.width
            - kPaddingHorizontalBetweenButtonAndBubble  - shiftForOtherButtons;
		}
		else
		{
			frame.origin.x = bubbleView.frame.origin.x + bubbleView.frame.size.width
            + kPaddingHorizontalBetweenButtonAndBubble + shiftForOtherButtons;
		}
		
		burnButton.frame = frame;
		shiftForOtherButtons += frame.size.width + kPaddingHorizontalBetweenButtons;
	}
	
 
	if (hasGeo)
	{
		CGRect frame = self.geoButton.frame;
		frame.origin.y = bubbleView.center.y - (frame.size.height / 2);
		
		if (isOutgoing)
		{
			frame.origin.x = bubbleView.frame.origin.x - frame.size.width
				               - kPaddingHorizontalBetweenButtonAndBubble - shiftForOtherButtons;
		}
		else
		{
			frame.origin.x = bubbleView.frame.origin.x + bubbleView.frame.size.width
				               + kPaddingHorizontalBetweenButtonAndBubble + shiftForOtherButtons;
		}
		
		geoButton.frame = frame;
		shiftForOtherButtons += frame.size.width + kPaddingHorizontalBetweenButtons;
	}
 	
	if (isFYEO)
	{
		CGRect frame = self.fyeoButton.frame;
		frame.origin.y = bubbleView.center.y - (frame.size.height / 2);
		
		if (isOutgoing)
		{
			frame.origin.x = bubbleView.frame.origin.x - frame.size.width
				- kPaddingHorizontalBetweenButtonAndBubble  - shiftForOtherButtons;
		}
		else
		{
			frame.origin.x = bubbleView.frame.origin.x + bubbleView.frame.size.width
				+ kPaddingHorizontalBetweenButtonAndBubble + shiftForOtherButtons;
		}
		
		fyeoButton.frame = frame;
		shiftForOtherButtons += frame.size.width + kPaddingHorizontalBetweenButtons;
	}

    

    
	if (isPlainText)
    {
        CGRect frame = self.plainTextButton.frame;
		frame.origin.y = bubbleView.frame.origin.y - (frame.size.height / 4);
		
		if (isOutgoing)
			frame.origin.x =  bubbleView.frame.origin.x - (frame.size.width/2);
		else
			frame.origin.x = bubbleView.frame.origin.x + bubbleView.frame.size.width - (frame.size.width/2);
		
		plainTextButton.frame = frame;
	}
	
	if (failure)
	{
		CGRect frame = self.failureButton.frame;
		frame.origin.y = bubbleView.frame.origin.y;
		
		if (isOutgoing)
			frame.origin.x =  bubbleView.frame.origin.x - frame.size.width/2;
		else
			frame.origin.x = bubbleView.frame.origin.x + bubbleView.frame.size.width - frame.size.width/2;
		
		failureButton.frame = frame;
	}
    
    if (pending)
	{
		CGRect frame = self.pendingButton.frame;
		frame.origin.y = bubbleView.frame.origin.y;
		
		if (isOutgoing)
			frame.origin.x =  bubbleView.frame.origin.x + bubbleView.frame.size.width - (2 * frame.size.width / 3)- kBubbleTailWidth;
		else
			frame.origin.x = bubbleView.frame.origin.x + (2 * frame.size.width / 3) + kBubbleTailWidth;
		
		pendingButton.frame = frame;
	}

    if (ignored)
	{
		CGRect frame = self.ignoredButton.frame;
		frame.origin.y = bubbleView.frame.origin.y;
		
		if (isOutgoing)
			frame.origin.x =  bubbleView.frame.origin.x - (frame.size.width/2);
		else
			frame.origin.x = bubbleView.frame.origin.x + bubbleView.frame.size.width - (frame.size.width/2);
		
		ignoredButton.frame = frame;
	}
    
    
    if (signature)
	{
		CGRect frame = self.signatureCorruptButton.frame;
	 	frame.origin.y = bubbleView.frame.origin.y;
		
		if (isOutgoing)
			frame.origin.x =  bubbleView.frame.origin.x - (frame.size.width/2);
		else
			frame.origin.x = bubbleView.frame.origin.x + bubbleView.frame.size.width - (frame.size.width/2);
		
		signatureCorruptButton.frame = frame;
    
        frame = self.signatureKNFButton.frame;
	 	frame.origin.y = bubbleView.frame.origin.y;
		
		if (isOutgoing)
			frame.origin.x =  bubbleView.frame.origin.x - (frame.size.width/2);
		else
			frame.origin.x = bubbleView.frame.origin.x + bubbleView.frame.size.width - (frame.size.width/2);
		
		signatureKNFButton.frame = frame;

        frame = self.signatureVerfiedButton.frame;
	 	frame.origin.y = bubbleView.frame.origin.y;
		
		if (isOutgoing)
			frame.origin.x =  bubbleView.frame.origin.x - (frame.size.width/2);
		else
			frame.origin.x = bubbleView.frame.origin.x + bubbleView.frame.size.width - (frame.size.width/2);
		
		signatureVerfiedButton.frame = frame;
	}
	//
#if debug_view_clipping
	UIColor *collorrr;
	switch (indexxx % 5) {
		case 0:
			collorrr = [UIColor yellowColor];
			break;
			
		case 1:
			collorrr = [UIColor redColor];
			break;
			
		case 2:
			collorrr = [UIColor purpleColor];
			break;
			
		case 3:
			collorrr = [UIColor blueColor];
			break;
			
		case 4:
			collorrr = [UIColor magentaColor];
			break;
			
		default:
			break;
	}
	//	[self prettyForDebug:self.superview.superview color:[UIColor redColor] borderWidth: 1];
	UIView *view1, *view2;
	view1 = self.contentView.superview.subviews[0];
//	view2 = self.contentView.superview.subviews[1];

	[self prettyForDebug:view1 color:[UIColor clearColor] borderWidth: 1];
//	[self prettyForDebug:view2 color:[UIColor brownColor] borderWidth: 3];
	[self prettyForDebug:self color:collorrr borderWidth: 2];
//	[self prettyForDebug:self.contentView color:[UIColor orangeColor] borderWidth: 2];
//	[self prettyForDebug:bubbleView color:[UIColor magentaColor] borderWidth: 1];
//	[self prettyForDebug:textView color:[UIColor lightGrayColor] borderWidth: 1];
//	[self prettyForDebug:timestampLabel color:[UIColor greenColor] borderWidth: 1];
//	[self prettyForDebug:nameLabel color:[UIColor greenColor] borderWidth: 1];
//	[self prettyForDebug:footerLabel color:[UIColor blueColor] borderWidth: 2];
//	[self prettyForDebug:statusView color:[UIColor purpleColor] borderWidth: 1];
#endif
}

#if debug_view_clipping
- (void)prettyForDebug:(UIView *)view color:(UIColor *)color borderWidth:(CGFloat)borderWidth
{
	view.backgroundColor = [color colorWithAlphaComponent:0.3];
	view.layer.borderColor = color.CGColor;
	view.layer.borderWidth = borderWidth;
}
#endif
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UIGestureRecognizer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)avatarTap:(UITapGestureRecognizer *)gestureRecognizer
{
	if (avatarImageView.image == nil)
		return;
	
	if ([delegate respondsToSelector: kTappedImageOfAvatar]) {
		[delegate tappedImageOfAvatar: self];
	}
}

- (void)statusTap:(UITapGestureRecognizer *)gestureRecognizer
{
	if (statusImageView.image == nil)
		return;
	
	if ([delegate respondsToSelector: kTappedStatusIcon]) {
		[delegate tappedStatusIcon: self];
	}
}

- (void)tap:(UITapGestureRecognizer *)gestureRecognizer
{
	if ([delegate respondsToSelector: kTapOnCell])
		[delegate tapOnCell];

	if (bubbleView.mediaImage)
	{
		CGPoint hitPoint = [gestureRecognizer locationInView:bubbleView];
		if (CGRectContainsPoint(bubbleView.mediaFrame, hitPoint))
		{
			if ([delegate respondsToSelector: kTappedImageOfCell])
				[delegate tappedImageOfCell: self];
		}
	}
}

- (IBAction)buttonTap:(id)sender
{
	if (sender == burnButton)
	{
		if ([delegate respondsToSelector:@selector(tappedBurn:)])
			[delegate tappedBurn:self];
	}
	else if (sender == geoButton)
	{
		if ([delegate respondsToSelector:@selector(tappedGeo:)])
			[delegate tappedGeo:self];
	}
	else if (sender == failureButton)
	{
		if ([delegate respondsToSelector:@selector(tappedFailure:)])
			[delegate tappedFailure:self];
	}
 	else if (sender == plainTextButton)
	{
		if ([delegate respondsToSelector:@selector(tappedIsPlainText:)])
			[delegate tappedIsPlainText:self];
	}
     else if (sender == pendingButton)
	{
		if ([delegate respondsToSelector:@selector(tappedPending:)])
			[delegate tappedPending:self];
	}
    else if (sender == ignoredButton)
	{
		if ([delegate respondsToSelector:@selector(tappedIgnored:)])
			[delegate tappedIgnored:self];
	}
   else if (sender == signatureVerfiedButton)
	{
		if ([delegate respondsToSelector:@selector(tappedSignature:signatureState:)])
			[delegate tappedSignature:self signatureState:kBubbleSignature_Verified];
	}
   else if (sender == signatureKNFButton)
   {
       if ([delegate respondsToSelector:@selector(tappedSignature:signatureState:)])
           [delegate tappedSignature:self signatureState:kBubbleSignature_KeyNotFound];
   }
   else if (sender == signatureCorruptButton)
	{
		if ([delegate respondsToSelector:@selector(tappedSignature:signatureState:)])
			[delegate tappedSignature:self signatureState:kBubbleSignature_Corrupt];
	}
    else if (sender == fyeoButton)
	{
		if ([delegate respondsToSelector:@selector(tappedFYEO:)])
			[delegate tappedFYEO:self];
	}
    else if (sender == unplayedButton)
	{
		if ([delegate respondsToSelector:@selector(tappedUnplayed:)])
			[delegate tappedUnplayed:self];
	}
    

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark MBProgressHUD delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)hudWasHidden:(MBProgressHUD *)hud
{
	if (hud == progressHUD)
	{
		[progressHUD removeFromSuperview];
		progressHUD = nil;
	}
}

@end
