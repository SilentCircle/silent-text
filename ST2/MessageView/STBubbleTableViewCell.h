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
#import "BubbleView.h"
#import "STBubbleView.h"
#import "MBProgressHUD.h"
#import "AppTheme.h"
#import "STBubbleCellButton.h"

@class STBubbleTableViewCell;
@protocol STBubbleTableViewCellDelegate;

typedef enum
{
    kBubbleSignature_None,
    kBubbleSignature_Corrupt,
    kBubbleSignature_Verified,
    kBubbleSignature_KeyNotFound
} BubbleSignature_State;


@interface STBubbleTableViewCell : UITableViewCell <MBProgressHUDDelegate>

+ (CGFloat)heightForCellWithText:(NSString *)text
                        textFont:(UIFont *)textFont
                            name:(NSString *)nameOrNil
                        nameFont:(UIFont *)nameFont
                        maxWidth:(CGFloat)maxWidth
                       hasAvatar:(BOOL)hasAvatar
                     sideButtons:(BOOL)hasSideButtons // burn || geo button(s)
                       timestamp:(BOOL)hasTimestamp
                          footer:(BOOL)hasFooter;

+ (CGFloat)heightForCellWithImage:(UIImage *)image
                             name:(NSString *)nameOrNil
                         nameFont:(UIFont *)nameFont
                         maxWidth:(CGFloat)maxWidth
                        hasAvatar:(BOOL)hasAvatar
                      sideButtons:(BOOL)hasSideButtons // burn || geo button(s)
                        timestamp:(BOOL)hasTimestamp
                           footer:(BOOL)hasFooter;

+ (CGFloat)heightForCellWithStatusText:(NSString *)statusText
                          textFont:(UIFont *)textFont
                              name:(NSString *)name
                          nameFont:(UIFont *)nameFont
                          maxWidth:(CGFloat)maxWidth
                         hasAvatar:(BOOL)hasAvatar
                       sideButtons:(BOOL)hasSideButtons
                         timestamp:(BOOL)hasTimestamp
                            footer:(BOOL)hasFooter;

+ (CGFloat) widthForSideButtonsWithBurn:(BOOL)hasBurn hasGeo:(BOOL)hasGeo isFYEO:(BOOL)isFYEO isUnPlayed:(BOOL)isUnPlayed;

@property (nonatomic, weak) id <STBubbleTableViewCellDelegate> delegate;

@property (nonatomic, strong) NSString *messageId; // for async image loading

- (void)refreshColorsFromTheme;

// Main UI components

@property (nonatomic, strong) AppTheme * theme;

@property (nonatomic, strong)			BubbleView	  * bubbleView;
@property (nonatomic, strong, readonly) UIImageView   * avatarImageView;

@property (nonatomic, strong, readonly) UITextView    * textView;
@property (nonatomic, strong, readonly) UILabel       * timestampLabel;
@property (nonatomic, strong, readonly) UILabel       * nameLabel;
@property (nonatomic, strong, readonly) UILabel       * footerLabel;

@property (nonatomic, strong, readonly) UIView        * statusView;
@property (nonatomic, strong, readonly) UIImageView   * statusImageView;

// Side buttons

@property (nonatomic, strong, readonly) STBubbleCellButton * burnButton;
@property (nonatomic, strong, readonly) STBubbleCellButton * geoButton;
@property (nonatomic, strong, readonly) STBubbleCellButton * fyeoButton;

// Overlay buttons

@property (nonatomic, strong, readonly) STBubbleCellButton * failureButton;
@property (nonatomic, strong, readonly) STBubbleCellButton * pendingButton;
@property (nonatomic, strong, readonly) STBubbleCellButton * ignoredButton;
@property (nonatomic, strong, readonly) STBubbleCellButton * plainTextButton;
@property (nonatomic, strong, readonly) STBubbleCellButton * signatureVerfiedButton;
@property (nonatomic, strong, readonly) STBubbleCellButton * signatureCorruptButton;
@property (nonatomic, strong, readonly) STBubbleCellButton * signatureKNFButton;
@property (nonatomic, strong, readonly) STBubbleCellButton * unplayedButton;
 

// Message state

@property (nonatomic, assign) BOOL isOutgoing;
@property (nonatomic, assign) BOOL canCopyContents;
@property (nonatomic, assign) BOOL hasBurn;
@property (nonatomic, assign) BOOL hasGeo;
@property (nonatomic, assign) BOOL failure;
@property (nonatomic, assign) BOOL pending;
@property (nonatomic, assign) BOOL ignored;
@property (nonatomic, assign) BOOL isPlainText;
@property (nonatomic, assign) BOOL isFYEO;
@property (nonatomic, assign) BOOL unplayed;

@property (nonatomic, assign) BubbleSignature_State signature;

// Convenience properties

@property (nonatomic, readonly) BOOL hasTimestamp;
@property (nonatomic, readonly) BOOL hasName;
@property (nonatomic, readonly) BOOL hasFooter;
@property (nonatomic, readonly) BOOL hasSideButtons;


// The progressHUD is configured by the UI for a specific message,
// and is animated in various ways. So we keep a cache of these items around.
// This allows:
// - pre-existing progressHUD instances to be migrated from cell to cell
// - pre-existing progressHUD instances to maintain their animations during cell migration
//
// progressHudForConversationId:messageId:         - Creates or returns an existing HUD
// existingProgressHudForConversationId:messageId: - Only returns a HUD if it already exists

- (MBProgressHUD *)progressHudForConversationId:(NSString *)conversationId messageId:(NSString *)messageId;
- (MBProgressHUD *)existingProgressHudForConversationId:(NSString *)conversationId messageId:(NSString *)messageId;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol STBubbleTableViewCellDelegate <NSObject>
@optional

#define kTappedImageOfCell  (@selector(tappedImageOfCell:))
- (void) tappedImageOfCell: (STBubbleTableViewCell *) cell;
#define kTapOnCell  (@selector(tapOnCell))
- (void) tapOnCell;

#define kTappedImageOfAvatar  (@selector(tappedImageOfAvatar:))
- (void) tappedImageOfAvatar: (STBubbleTableViewCell *) cell;
- (void) tappedGeo: (STBubbleTableViewCell *) cell;
- (void) tappedFYEO: (STBubbleTableViewCell *) cell;
- (void) tappedBurn: (STBubbleTableViewCell *) cell;
- (void) tappedFailure: (STBubbleTableViewCell *) cell;
- (void) tappedPending: (STBubbleTableViewCell *) cell;
- (void) tappedIgnored: (STBubbleTableViewCell *) cell;
- (void) tappedSignature: (STBubbleTableViewCell *) cell signatureState:(BubbleSignature_State)signature;
- (void) tappedIsPlainText: (STBubbleTableViewCell *) cell;
- (void) tappedUnplayed: (STBubbleTableViewCell *) cell;


#define kTappedStatusIcon  (@selector(tappedStatusIcon:))
- (void) tappedStatusIcon: (STBubbleTableViewCell *) cell;

@end
