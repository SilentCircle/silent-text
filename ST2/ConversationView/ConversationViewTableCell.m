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
#import <QuartzCore/QuartzCore.h>

#import "ConversationViewTableCell.h"
#import "NSDate+SCDate.h"
#import "UIImage+Thumbnail.h"
#import "SCDateFormatter.h"
#import "SCCalendar.h"
#import "SilentTextStrings.h"
#import "STLogging.h"

#define BADGE_BORDER_WIDTH   1.f //2.f //ET 01/30/15 1px thin border
#define BADGE_BORDER_COLOR  [UIColor whiteColor]
#define BADGE_COLOR         [UIColor blackColor]
#define BADGE_TITLE_COLOR   [UIColor whiteColor]

#define AVATAR_SIZE         60.f
#define AVATAR_PADDING_LEFT  5.f

#define LEFT_BADGE_SIZE          28.f
#define LEFT_BADGE_PADDING_RIGHT 10.f

#define DATE_TEXT_STYLE     UIFontTextStyleCaption1
#define DATE_PADDING_TOP     4.F
#define DATE_PADDING_RIGHT  10.0
#define DATE_HEIGHT         21.f
#define DATE_COLOR [UIColor darkGrayColor]

#define PADDING_BETWEEN_TEXT_BADGE 0.f
#define PADDING_BETWEEN_TEXT_TITLE 2.f
#define PADDING_BETWEEN_TITLE_DATE 0.f

#define SUBTITLE_COLOR [UIColor blackColor]

#define TEXT_PADDING_LEFT   74.f
#define TEXT_PADDING_RIGHT  10.f

#define TITLE_PADDING_TOP    1.f
#define TITLE_PADDING_LEFT  64.f
#define TITLE_PADDING_RIGHT 86.f
#define TITLE_COLOR [UIColor blackColor]


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Added comment to update develop branch with JIRA ticket number,
// after an aborted merge with ST924_badgeColor merged without comment.
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Logging
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Log levels: off, error, warn, info, verbose
#if DEBUG && eturner
static const int ddLogLevel = LOG_LEVEL_INFO | LOG_LEVEL_WARN | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_WARN;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)

@interface ConversationViewTableCell ()
// Note that the leftBadgeImgView property displays on the right side of the cell
// This private imageView property is the container for the public leftBadgeImage 
// image property.
@property (weak, nonatomic) IBOutlet UIImageView *leftBadgeImgView;
@end

@implementation ConversationViewTableCell
{
    //ET 01/16/15 New nib outlet ivars
    @public
    __weak IBOutlet UILabel *lblBadge;
    __weak IBOutlet UILabel *lblDate;
    __weak IBOutlet UILabel *lblSubTitle;
    __weak IBOutlet UILabel *lblTitle;
}

static CGFloat maxDateWidth = 0.0;

+ (CGFloat)avatarSize
{
	return AVATAR_SIZE;
}

+ (CGFloat)titlePaddingLeft
{
	return TITLE_PADDING_LEFT;
}


//ET 01/16/15
/** 
 * Returns rect and string attributes dictionary pointers with which to draw the formatted date string.
 * 
 *
 * NOTE: This method is only called by ConversationVC to forward to STUser for multicast display name.
 */
+ (void) getTitleRect:(CGRect*)rectOut titleAttributes:(NSDictionary**) titleAttributesOut
{
    CGRect bounds = (CGRect){
        .origin.x = 0,
        .origin.y = 0,
        .size.width = 320,
        .size.height = 79 };
    
    UIFont *dateFont = [UIFont preferredFontForTextStyle:DATE_TEXT_STYLE];
    
    CGFloat dateWidth = [ConversationViewTableCell maxDateWidth];
    CGRect dateRect = (CGRect){
        .origin.x = bounds.size.width - DATE_PADDING_RIGHT - dateWidth,
        .origin.y = DATE_PADDING_TOP,
        .size.width = dateWidth,
        .size.height = dateFont.lineHeight
    };
    
    UIFont *titleFont = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    
    CGRect titleRect = (CGRect){
        .origin.x = TITLE_PADDING_LEFT,
        .origin.y = TITLE_PADDING_TOP,
        .size.width = dateRect.origin.x - PADDING_BETWEEN_TITLE_DATE - TITLE_PADDING_LEFT,
        .size.height = titleFont.lineHeight
    };
    
    NSMutableParagraphStyle *titleStyle = [[NSMutableParagraphStyle alloc] init];
    titleStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    titleStyle.alignment = NSTextAlignmentLeft;
    
    NSDictionary* titleAttributes = @{   NSFontAttributeName: titleFont,
                                         NSParagraphStyleAttributeName: titleStyle };
    
    if(titleAttributesOut) *titleAttributesOut = titleAttributes;
    if(rectOut) *rectOut = titleRect;
    
}

/**
 * Calculates the width of a date as an attributed string, formatted for current locale, 
 * and current preferred font settings.
 *
 * NOTE: This class method is only called by the getTitleRect:titleAttributes: class method to calculate a
 * width, with which STUser derives a multicast display name.
 */
+ (CGFloat)maxDateWidth
{
	if (maxDateWidth == 0.0)
	{
		// We're going to calculate the maximum length dateString.
		// This is based on the current locale, and current preferred font settings.
		//
		// Note: This code is highly dependent on [NSDate+SCDate whenString] implementation.
		
		UIFont *dateFont = [UIFont preferredFontForTextStyle:DATE_TEXT_STYLE];
		NSDictionary *dateAttributes = @{ NSFontAttributeName: dateFont };
		
		NSDate *today = [NSDate date];
		
		NSCalendar *calendar = [SCCalendar cachedAutoupdatingCurrentCalendar];
		NSDateComponents *components = [[NSDateComponents alloc] init];
		
		// Time only (12:30 AM)
		{
			components.hour = 12;
			components.minute = 30;
			NSDate *date = [calendar dateFromComponents:components];
			
			NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterNoStyle
			                                                               timeStyle:NSDateFormatterShortStyle];
			NSString *dateStr = [formatter stringFromDate:date];
			
			CGSize size = [dateStr sizeWithAttributes:dateAttributes];
			maxDateWidth = MAX(maxDateWidth, size.width);
		}
		
		// Date only (2020-12-30)
		{
			components.year = 2020;
			components.month = 12;
			components.day = 30;
			NSDate *date = [calendar dateFromComponents:components];
			
			NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterShortStyle
			                                                               timeStyle:NSDateFormatterNoStyle];
			NSString *dateStr = [formatter stringFromDate:date];
			
			CGSize size = [dateStr sizeWithAttributes:dateAttributes];
			maxDateWidth = MAX(maxDateWidth, size.width);
		}
		
		// Yesterday (Hier, Gestern, Ayer, ...)
		{
			NSDate *date = [today dateByAddingTimeInterval:(-24 * 60 * 60)];
			
			NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
			                                                               timeStyle:NSDateFormatterNoStyle
			                                              doesRelativeDateFormatting:YES];
			NSString *dateStr = [formatter stringFromDate:date];
			
			CGSize size = [dateStr sizeWithAttributes:dateAttributes];
			maxDateWidth = MAX(maxDateWidth, size.width);
		}
		
		// Weekdays
		{
			NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithLocalizedFormat:@"EEEE"];
			
			for (int i = 0; i < 7; i++)
			{
				NSDate *date = [today dateByAddingTimeInterval:(i * 24 * 60 * 60)];
				
				NSString *dateStr = [formatter stringFromDate:date];
				
				CGSize size = [dateStr sizeWithAttributes:dateAttributes];
				maxDateWidth = MAX(maxDateWidth, size.width);
			}
		}
		
		// Round-up to nearest whole integer
		maxDateWidth = ceil(maxDateWidth);
	}
	
	return maxDateWidth;
}

+ (void)preferredContentSizeChanged:(NSNotification *)notification
{
	// Reset maxDateWidth static ivar.
	// This will cause it to get recalculated in maxDateWidth method (above).
	maxDateWidth = 0.0;
}

#pragma mark - Public Property Ivars

@synthesize avatar           = avatar;
@synthesize badgeColor       = badgeColor;
@synthesize badgeBorderColor = badgeBorderColor;
@synthesize badgeString      = badgeString;
@synthesize badgeTitleColor  = badgeTitleColor;
@synthesize conversationId   = conversationId;
@synthesize date             = date;
@synthesize dateColor        = dateColor;
@synthesize isOutgoing       = isOutgoing;
@synthesize isStatus         = isStatus;
@synthesize leftBadgeImage   = leftBadgeImage;
@synthesize subTitleColor    = subTitleColor;
@synthesize subTitleString   = subTitleString;
@synthesize titleColor       = titleColor;
@synthesize titleString      = titleString;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Cell Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Set rounded badge label attribs
    [self initialBadgeConfig];
    
    // Clear working layout values
    _avatarImgView.image    = nil;
    _leftBadgeImgView.image = nil;
    lblBadge.text           = nil;
    lblDate.text            = nil;
    lblSubTitle.text        = nil;
    lblTitle.text           = nil;
}

- (void)prepareForReuse
{
    [super prepareForReuse];

    // Per Apple:
    // For performance reasons, you should only reset attributes of the cell that are not related to content, 
    // for example, alpha, editing, and selection state. The table view's delegate in tableView:cellForRowAtIndexPath: 
    // should always reset all content when reusing a cell.    
    self.accessoryType = UITableViewCellAccessoryNone;
    self.highlighted = NO;
    self.selected    = NO;    
    lblBadge.hidden  = YES;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Avatar
- (UIImage *)avatar
{
    return _avatarImgView.image;
}

- (void)setAvatar:(UIImage *)newAvatar
{
    if (avatar != newAvatar)
        _avatarImgView.image = newAvatar;
}


#pragma mark - Badge
/** When the cell awakens from nib this method
 * sets the lblBadge properties, including rounding the corners
 * to create a round badge with colored border. Label default
 * values are updated via setters.
 */
- (void)initialBadgeConfig
{
    lblBadge.hidden = NO;
    lblBadge.layer.cornerRadius = lblBadge.frame.size.height/2;
    lblBadge.layer.borderWidth = BADGE_BORDER_WIDTH;
    [self setBadgeBorderColor: BADGE_BORDER_COLOR];
    [self setBadgeColor: BADGE_COLOR];
    lblBadge.numberOfLines = 1;
    lblBadge.clipsToBounds = YES;
    lblBadge.hidden = YES;
}

// If string value is nil, set badge hidden
- (void)setBadgeString:(NSString *)strBadge
{
    if (strBadge)
    {
        lblBadge.hidden = NO;
        
        badgeString = strBadge;
        NSDictionary *attribs = [self badgeAttributes];
        NSAttributedString *attribStr = [[NSAttributedString alloc] initWithString:strBadge 
                                                                        attributes:attribs];
        lblBadge.attributedText = attribStr;
        [self setBadgeBorderColor:self.badgeBorderColor];
        [self setBadgeColor:self.badgeColor];
    }
    else
    {
        badgeString = nil;
        lblBadge.text = nil;
        lblBadge.hidden = YES;
    }
}

/**
 * @return Attributed string attributes configured for lblBadge
 */
- (NSDictionary *)badgeAttributes
{
    UIFont *badgeFont = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    NSMutableParagraphStyle *badgeStyle = [[NSMutableParagraphStyle alloc] init];
    badgeStyle.alignment = NSTextAlignmentCenter;
//    CGSize badgeTextSize = [@"99+" sizeWithAttributes:badgeAttributes]; //sized in nib
    NSDictionary *badgeAttribs = @{ 
                                   NSFontAttributeName: badgeFont,
                                   NSParagraphStyleAttributeName: badgeStyle,
                                   NSForegroundColorAttributeName: self.badgeTitleColor };
    return badgeAttribs;
}

- (UIColor *)badgeTitleColor
{
    if (badgeTitleColor)
        return badgeTitleColor;
    else
        return BADGE_TITLE_COLOR;
}

- (void)setBadgeTitleColor:(UIColor *)bdgTtlColor
{
    if (![badgeTitleColor isEqual:bdgTtlColor])
    {
        badgeTitleColor = bdgTtlColor;
        lblBadge.textColor = badgeTitleColor;
    }
}

- (UIColor *)badgeColor
{
    if (badgeColor)
        return badgeColor;
    else
        return BADGE_COLOR;
}

- (void)setBadgeColor:(UIColor *)newBadgeColor
{
    if (![badgeColor isEqual:newBadgeColor])
    {
        badgeColor = newBadgeColor;
        lblBadge.backgroundColor = newBadgeColor;
    }
}

- (UIColor *)badgeBorderColor
{
    if (badgeBorderColor)
        return badgeBorderColor;
    else
        return BADGE_BORDER_COLOR;
}

- (void)setBadgeBorderColor:(UIColor *)bbColor
{
    if (![badgeBorderColor isEqual:bbColor])
    {
        badgeBorderColor = bbColor;
        lblBadge.layer.borderColor = bbColor.CGColor;
    }    
}

#pragma mark - Date
- (void)setDate:(NSDate *)aDate
{
    if (aDate)
    {
        date = aDate;
        NSString *txtDate = [date whenString];
        NSDictionary *attribs = [self dateAttributes];
        NSAttributedString *attribStr = [[NSAttributedString alloc] initWithString:txtDate 
                                                                        attributes:attribs];
        lblDate.attributedText = attribStr;
        [lblDate layoutIfNeeded];
    }
    else
    {
        lblDate.attributedText = nil;
          [lblDate layoutIfNeeded];
    }
    
}

/**
 * @return Attributed string attributes configured for lblDate
 */
- (NSDictionary *)dateAttributes
{
    UIFont *dateFont = [UIFont preferredFontForTextStyle:DATE_TEXT_STYLE];    
    NSMutableParagraphStyle *dateStyle = [[NSMutableParagraphStyle alloc] init];
    dateStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    dateStyle.alignment = NSTextAlignmentRight;
    
    NSDictionary *dateAttribs = @{
                                  NSFontAttributeName: dateFont,
                                  NSParagraphStyleAttributeName: dateStyle,
                                  NSForegroundColorAttributeName: self.dateColor };
    return dateAttribs;
}

- (UIColor *)dateColor
{
    if (dateColor)
        return dateColor;
    else
        return DATE_COLOR;
}

- (void)setDateColor:(UIColor *)aColor
{
    if (![dateColor isEqual:aColor])
    {
        dateColor = aColor;
        lblDate.textColor = aColor;
    }
}


#pragma mark - Left Badge Image

- (UIImage *)leftBadgeImage
{
    return _leftBadgeImgView.image;
}

- (void)setLeftBadgeImage:(UIImage *)img
{
    _leftBadgeImgView.image = img;
}


#pragma mark - SubTitle
- (void)setSubTitleString:(NSString *)strSubTitle
{

    
    
    ////////////////
/*
 for ST-1080 Unicode DOS Attack - Crafted Text Repeatedly Kills STi
  
     It's triggered by Devanagari nonspacing mark and a combining character getting split, by the ellipsis,
  from the character with which it's supposed to combine causing the IOS text rendering code to crash.
 
 the following state machine looks for such a combination, will likely cause false positives
   
 */
    
#warning  TEMPORARY workaround for Unicode of death DOS attack
    
    BOOL isUnicodeAttack = NO;
 
    
    NSData  *data = [strSubTitle dataUsingEncoding:NSUTF8StringEncoding];
    if(data.length)
    {
         const unsigned char *bytes = [data bytes];
        
        int state = 0;
        for (int i = 0; i < [data length] && !isUnicodeAttack; i++)
        {
            
            // LOOK FOR PATTERN 20 + (Dx | Fx | Fx) + (a4 | a5)
            switch( state)
            {
                case 0:
                    if(bytes[i] == 0x20) state = 1; break;
                    
                case 1:
                    if((bytes[i] && 0xf0 == 0xD0)
                       ||(bytes[i] && 0xf0 == 0xE0)
                       ||(bytes[i] && 0xf0 == 0xF0))
                        state = 2;
                    else
                        state = 0;
                    break;
                    
                case 2:
                    if((bytes[i]  == 0xA4)
                       ||(bytes[i] == 0xA5))
                        state = 3;
                    else
                        state = 0;
                    break;
                    
                case 3:
                    isUnicodeAttack = YES;
                    break;
            }
            
        }
    }
        
      
    if(isUnicodeAttack)
    {
        NSMutableParagraphStyle *subTitleStyle = [[NSMutableParagraphStyle alloc] init];
        subTitleStyle.alignment = NSTextAlignmentLeft;

        NSDictionary *subTitleAttribs = @{
                                          NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline],
                                          NSParagraphStyleAttributeName: subTitleStyle,
                                          NSForegroundColorAttributeName: [UIColor redColor] };

        
        
        NSAttributedString *attribStr = [[NSAttributedString alloc] initWithString:@"<Possible Unicode DOS Attack Detected>"
                                                                        attributes:subTitleAttribs];
        lblSubTitle.attributedText = attribStr;
        
         
    } else

 /////////////////////////
        
    if (strSubTitle)
    {
        subTitleString = strSubTitle;
        NSDictionary *attribs = [self subTitleAttributes];
        NSAttributedString *attribStr = [[NSAttributedString alloc] initWithString:strSubTitle 
                                                                        attributes:attribs];
        lblSubTitle.attributedText = attribStr;
    }
}

/**
 * @return Attributed string attributes configured for lblSubTitle
 */
- (NSDictionary *)subTitleAttributes
{
    UIFont *subTitleFont;
    if (self.isStatus)
        subTitleFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    else
        subTitleFont = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    
    NSMutableParagraphStyle *subTitleStyle = [[NSMutableParagraphStyle alloc] init];
    subTitleStyle.alignment = NSTextAlignmentLeft;
    
    NSDictionary *subTitleAttribs = @{
                                      NSFontAttributeName: subTitleFont,
                                      NSParagraphStyleAttributeName: subTitleStyle,
                                      NSForegroundColorAttributeName: self.subTitleColor };
    return subTitleAttribs;
}
- (UIColor *)subTitleColor
{
    if (subTitleColor)
        return subTitleColor;
    else
        return SUBTITLE_COLOR;
}

- (void)setSubTitleColor:(UIColor *)aColor
{
    if (![subTitleColor isEqual:aColor])
    {
        subTitleColor = aColor;
        lblSubTitle.textColor = aColor;
    }
}


#pragma mark - Title
- (void)setTitleString:(NSString *)strTitle
{
    if (strTitle)
    {
        titleString = strTitle;
        NSDictionary *attribs = [self titleAttributes];
        NSAttributedString *attribStr = [[NSAttributedString alloc] initWithString:strTitle 
                                                                        attributes:attribs];
        lblTitle.attributedText = attribStr;
    }
}

/**
 * @return Attributed string attributes configured for lblTitle
 */
- (NSDictionary *)titleAttributes
{
    UIFont *titleFont = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    NSMutableParagraphStyle *titleStyle = [[NSMutableParagraphStyle alloc] init];
    titleStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    titleStyle.alignment = NSTextAlignmentLeft;
    
    NSDictionary *titleAttribs = @{
                                   NSFontAttributeName: titleFont,
                                   NSParagraphStyleAttributeName: titleStyle,
                                   NSForegroundColorAttributeName: self.titleColor };
    return titleAttribs;
}

- (UIColor *)titleColor
{
    if (titleColor)
        return titleColor;
    else
        return TITLE_COLOR;
}

- (void)setTitleColor:(UIColor *)newTitleColor
{
    if (![titleColor isEqual:newTitleColor])
        titleColor = newTitleColor;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableViewCell overrides
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
//    [super setSelected:selected animated:animated];
//}

/**
 * If lblBadge is visible and badgeString is not nil, set the badge backgroundColor.
 *
 * This implementation fixes the "ghosting" of the lblBadge when tapped. 
 * The ghosting condition occurs when a message is recieved for a conversation not
 * currently selected (the ConversationVC tableView cell is not selected (iPad)).
 * This may be while the app is active or when the ConversationVC sets up its
 * tableView when becoming active.
 *
 * When the user taps the cell displaying the (unread message count) lblBadge,
 * the lblBadge background color goes momentarily clear during the tap, i.e.
 * "ghosting", then the lblBadge is set to hidden when the badgeString is set
 * to nill in ConversationVC willSelectRowAtIndexPath. Setting the lblBadge
 * background color in this method maintains the original appearance of the 
 * lblBadge for the duration of the tap, i.e. no ghosting, then disappears
 * at the end of the tap event, as expected.
 */
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];

    if (NO == lblBadge.isHidden && badgeString.length > 0)
        lblBadge.backgroundColor = self.badgeColor;
}

@end
