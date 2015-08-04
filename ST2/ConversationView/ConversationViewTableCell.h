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
#import <UIKit/UIKit.h>


@interface ConversationViewTableCell : UITableViewCell

+ (CGFloat)avatarSize;
+ (CGFloat)titlePaddingLeft;

+ (void)preferredContentSizeChanged:(NSNotification *)notification;

+ (void) getTitleRect:(CGRect*)rectOut titleAttributes:(NSDictionary**) titleAttributesOut;

@property (nonatomic, copy) NSString * conversationId; // for async operations (such as image fetching)

#pragma mark - Public Properties
/**
 * Avatar image of the remote user.
 *
 * When set by ConversationVC configureCell:withIndexPath: the
 * property setter configures the avatarImageView with this image.
 */
@property (nonatomic, strong) UIImage * avatar;

/** 
 * Container for the conversation remote user's avatar image
 */
@property (weak, nonatomic) IBOutlet UIImageView *avatarImgView;

/** 
 * The badgeString indicates the number of unread messages in
 * the conversation represented by the cell.
 *
 * When set by ConversationVC configureCell:withIndexPath: the
 * property setter configures the private lblBadge with an
 * NSAttributedString using this value and sets it visible.
 *
 * Note that if set with a nil string value, the lblBadge text
 * is set to nil and the badge hidden.
 *
 * When the cell awakens from nib the initialBadgeConfig method
 * sets the lblBadge properties, including rounding the corners
 * to create a round badge with colored border.
 */
@property (nonatomic, copy) NSString * badgeString;

/** 
 * When set by ConversationVC configureCell:withIndexPath: the
 * property setter configures the private lblBadge background
 * color using this value.
 */
@property (nonatomic, strong) UIColor * badgeColor;

@property (nonatomic, strong) UIColor * badgeBorderColor;

/** 
 * When set by ConversationVC configureCell:withIndexPath: the
 * property setter configures the private lblBadge NSAttributedString
 * text color using this value.
 */
@property (nonatomic, strong) UIColor * badgeTitleColor;

/** 
 * When set by ConversationVC configureCell:withIndexPath: the
 * property setter configures the private lblBadge with an
 * NSAttributedString using this value. The date is formatted
 * using the [NSDate+SCDate whenString] implementation to use
 * current locale and time-only, date-only, and weekday
 * representations.
 */
@property (nonatomic, strong) NSDate * date;

/**
 * The getter returns the ivar value if not nil, or 
 * [UIColor darkGrayColor] as a default.
 *
 * When set by ConversationVC configureCell:withIndexPath: the
 * property setter configures the private lblDate NSAttributedString
 * text color attribute using this value.
 */
@property (nonatomic, strong) UIColor * dateColor;

/**
 * This image property displays images on the right side of the cell
 * related to the state of the conversation, for example, the right 
 * angle arrow image, indicating the remote user messaged last.
 *
 * The getter method for this property returns the private 
 * leftBadgeImageView image.
 *
 * When set by ConversationVC configureCell:withIndexPath: the
 * property setter configures the private leftBadgeImageView image
 * with this value.
 */
@property (nonatomic, strong) UIImage * leftBadgeImage;

/**
 * Outgoing message flag.
 */
@property (nonatomic, assign) BOOL isOutgoing;

/**
 * Flag property indicating the conversation is a system status,
 * e.g., "Requesting Keying".
 */
@property (nonatomic, assign) BOOL isStatus;

/** 
 * When set by ConversationVC configureCell:withIndexPath: the
 * property setter configures the private lblSubTitle 
 * NSAttributedString text color attribute using this value.
 */
@property (nonatomic, strong) UIColor * subTitleColor;

/** 
 * When set by ConversationVC configureCell:withIndexPath: the
 * property setter configures the private lblSubTitle with an
 * NSAttributedString using this value.
 */
@property (nonatomic, copy) NSString * subTitleString;

/** 
 * When set by ConversationVC configureCell:withIndexPath: the
 * property setter configures the private lblTitle NSAttributedString
 * text color attribute using this value.
 */
@property (nonatomic, strong) UIColor * titleColor;

/** 
 * When set by ConversationVC configureCell:withIndexPath: the
 * property setter configures the private lblTitle with an
 * NSAttributedString using this value.
 */
@property (nonatomic, copy) NSString * titleString;

@end
