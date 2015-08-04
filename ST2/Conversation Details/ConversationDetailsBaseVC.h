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
#import "ConversationDetailsDelegate.h"
#import "SCTAvatarViewDelegate.h"
#import "NewGroupInfoVCDelegate.h"

@class AppTheme;
@class STConversation;
@class STDynamicHeightView;
@class SCTHelpButton;
@class STUser;
@class YapDatabaseConnection;

/**
 * This class encapsulates the following "header view" features:
 * - Title / display name
 * - SubTitle / organization/user name
 * - Group/User avatar 
 *
 * ## Discussion
 *
 * This base class handles the display of the "header view", i.e. the avatar image and title and subtitle. For a
 * point-to-point conversation the title is user displayName and the subtitle, the userName. For a group conversation
 * the displayName is the conversation title, and the userName, a string containing group user names.
 *
 * A tap on the avatar, title label, or subtitle label, all fire the userAvatarAction handler, which messages the
 * displayUserInfoFromCKVC delegate callback. On the iPhone, this results in pushing a groupInfoVC or 
 * userInfoVC instance on the navigation controller stack. On iPad, the current result is that the 
 * conversation details popover is dismissed (this should probably be considered a bug).
 *
 * Addtionally to this "header view" functionality, consistent across subclass views, this base class exposes the
 * conversation scimpState instance, and multiCastInfo dictionary, used by subclasses, and implements the 
 * didChangeState method. Updates are fired by the MessagesViewController databaseConnectionDidUpdate: for a
 * database update notification.
 *
 * ## History
 *
 * 07/24/14
 * This base class, ConversationDetailsVC, and ConversationDetailsSecurityVC, were refactored from the original
 * ConversationKeyViewController class and layout into discrete controllers and layouts to encapsulate view-specific 
 * information and controls, and for addtional UX (HelpDetailsVC views). 
 *
 * ET Note: the btnKeyInfo property was renamed from keyInfo to avoid semantic collision with scimpState keyInfo, from 
 * which is derived conversation security data, however the intended function of this button property is a bit of a
 * mystery. In IB, btnKeyInfo is wired to the keyInfoTapped: method, which has no implementation. There is an
 * updateUserKeyInfo: method implemented in this class which has no callers. Whether this button was or was intended to
 * be related to btnKeyInfo is unknown.
 */
@interface ConversationDetailsBaseVC : UIViewController <UINavigationControllerDelegate, SCTAvatarViewDelegate, GroupInfoViewControllerDelegate,
                                        UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning>
{
    STUser *_user;
}

// AvatarView
@property (nonatomic, weak) IBOutlet UIView *avatarContainerView;
@property (nonatomic, weak) IBOutlet SCTAvatarView *avatarView;
//ET 12/16/14 DEPRECATED (moved to EditUserInfoVC private ivar) ST-871
//@property (nonatomic, strong) UIImage *avatarImage; 
@property (nonatomic) BOOL loadAvatarViewFromNib;

@property (nonatomic, strong) STConversation *conversation; //ET: exposed in base class as property

// Container Subviews
@property (nonatomic, weak) IBOutlet STDynamicHeightView *containerView;
@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property (nonatomic, weak) IBOutlet UIView *refreshControlContainerView;
@property (nonatomic, weak) IBOutlet STDynamicHeightView *contentView;

/** This property is a precaution, originally implemented from uncertainty about potential differences in iPhone/iPad
 * navCon handling. The idea is that if on iPhone, if the navCon containing MessagesViewController has a delegate, this
 * storage property will preserve the ability to reset the navCon delegate back to the original after we're finished.
 */
@property (nonatomic, weak) id<UINavigationControllerDelegate> cachedNavDelegate;

@property (nonatomic, weak) id<ConversationDetailsDelegate> delegate;

@property (nonatomic, assign) BOOL isInPopover;
@property (nonatomic, assign) BOOL isModal;

@property (nonatomic, strong) NSArray *multiCastUsers;

@property (nonatomic, weak) id presentingController;

@property (nonatomic, weak, readonly) AppTheme *theme;

@property (nonatomic, weak, readonly) YapDatabaseConnection *uiDbConnection;
@property (nonatomic, strong) STUser *user;


#pragma mark Initialization
- (instancetype)initWithProperNib;
- (instancetype)initWithConversation:(STConversation *)convo;
- (instancetype)initWithUser:(STUser *)aUser;
//ET 12/16/14 DEPRECATED (moved to EditUserInfoVC private ivar) ST-871
//- (instancetype)initWithUser:(STUser *)aUser avatarImage:(UIImage *)avImg;

#pragma mark Views
- (void)updateAllViews;
- (NSLayoutConstraint *)heightConstraintFor:(UIView *)item;
- (NSLayoutConstraint *)topConstraintFor:(id)item;
/**
 * This method is queried * by our own code * when creating popover controllers.
 * It is conceptually similar to the deprecated contentSizeForViewInPopover method.
 **/
- (CGSize)preferredPopoverContentSize;
- (BOOL)isPresentedIniOS7Popover;
- (BOOL)isPresentedIniOS8Popover;
- (void)resetPreferredContentSize;
- (void)resetPopoverSizeIfNeeded;


- (void)databaseConnectionDidUpdate:(NSNotification *)notification;
- (void)didChangeState;

- (void)popOutOfPresentationContainer;
- (void)popToConversation:(NSString *)conversationId;
+ (void)popToConversation:(NSString *)conversationId;

#pragma mark Action handlers
- (void)presentHelpWithButton:(SCTHelpButton *)btn;
- (void)handleAvatarAction:(SCTAvatarView *)aView;


@end
