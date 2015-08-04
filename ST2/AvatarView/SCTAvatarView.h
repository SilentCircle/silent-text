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
//  SCTAvatarView.h
//  ST2
//
//  Created by Eric Turner on 8/5/14.
//

#import <UIKit/UIKit.h>
#import "SCTAvatarViewDelegate.h"

@class AppTheme;
@class SCTAvatarView;
@class STConversation;
@class SCTHelpButton;
@class STUser;


@interface SCTAvatarView : UIView

@property (nonatomic, weak) IBOutlet id<SCTAvatarViewDelegate> delegate;

// Views
@property (nonatomic, weak) UIImage *avatarImage;
@property (nonatomic, readonly) CGRect avatarImageRect;
//@property (nonatomic, weak) IBOutlet UIButton *btnConversation;
@property (nonatomic, weak) IBOutlet SCTHelpButton *btnHelpInfo;

@property (nonatomic, weak) IBOutlet UIButton *btnKeyInfo;
@property (nonatomic, weak) IBOutlet UILabel *lblDisplayName;
@property (nonatomic, weak) IBOutlet UILabel *lblOrganizationName;

// Conversation/Users
@property (nonatomic, strong) STConversation *conversation;
@property (nonatomic, strong) NSArray *multiCastUsers;
@property (nonatomic, strong) STUser *user;


- (void)updateConversation:(STConversation *)convo;

- (void)updateUser:(STUser *)aUser;

- (void)updateAllViews;
- (void)updateAllViewsWithAvatar:(UIImage *)anImage animated:(BOOL)animated;
- (void)updateAvatar;
- (void)setAvatarImage:(UIImage *)anImage withAnimation:(BOOL)animated;
//- (UIImage *)defaultAvatarImageWithRingColor:(UIColor *)ringColor;

- (void)updateAvatarWithDefaultImage;
- (void)updateAvatarWithDefaultImageWithAnimation:(BOOL)animated;

- (void)showCreatePublicKeyButton;
- (void)hideCreatePublicKeyButton;

- (void)startCreatePublicKeySpinner;
- (void)stopCreatePublicKeySpinner;

//- (void)showConversationButton:(BOOL)show;

- (void)showInfoButtonForClass:(Class)class;

@end
