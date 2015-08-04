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
//  AppThemeView.m
//  ST2
//
//  Created by mahboud on 1/20/14.
//

#import "STBubbleView.h"
#import "AppThemeView.h"
#import "AppTheme.h"
#import "AppDelegate.h"
#import "AddressBookManager.h"
#import "AvatarManager.h"
#import "UIImage+Crop.h"
#import "UIImage+Thumbnail.h"
#import "STLocalUser.h"
#import "STLogging.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


//#define kAvatarDiameter 64
static const CGFloat kAvatarDiameter = 64; //ET 06/11/14

@interface AppThemeView ()
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UIImageView *otherAvatar;
@property (weak, nonatomic) IBOutlet STBubbleView *otherBubbleView;
@property (weak, nonatomic) IBOutlet UILabel *otherLabel;
@property (weak, nonatomic) IBOutlet UIImageView *selfAvatar;
@property (weak, nonatomic) IBOutlet STBubbleView *selfBubbleView;
@property (weak, nonatomic) IBOutlet UILabel *selfLabel;
//@property (weak, nonatomic) IBOutlet UINavigationBar *navBar;
@property (weak, nonatomic) IBOutlet UILabel *pseudoNavBar;

@end

@implementation AppThemeView

- (id)initWithThemeName:(NSString *)name andTheme:(AppTheme *) theme
{
	
    self = 	[[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:self options:nil] firstObject];
;
    if (self) {
        // Custom initialization

//		self.frame = frame;
		//	self.view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
//		DDLogVerbose(@"theme is %@", theme);
//		_navBar.barStyle =  (theme.navBarIsBlack) ? UIBarStyleBlackTranslucent : UIBarStyleDefault;
//		_navBar.translucent = theme.navBarIsTranslucent;
//		_navBar.topItem.title = name;
		
		_pseudoNavBar.backgroundColor = [UIColor colorWithWhite:(theme.navBarIsBlack ? 0 : 1.0) alpha:(theme.navBarIsTranslucent ? 0.75 : 1.0)];
		_pseudoNavBar.textColor = theme.navBarTitleColor?:[UIColor blackColor];
		_pseudoNavBar.text = theme.localizedName;
	//	self.navigationController.navigationBar.tintColor = [STPreferences navItemTintColor];
//		UILabel *label = (UILabel *) self.navigationItem.titleView;
//		label.textColor = theme.navBarTitleColor;
		
		static NSString *const kDefaultAvatarIcon = @"silhouette.png";
		UIImage *defaultImage = [UIImage imageNamed: kDefaultAvatarIcon];
		_otherAvatar.image = [defaultImage avatarImageWithDiameter:kAvatarDiameter];
		
		UIImage *selfAvatar = NULL;
		if(STDatabaseManager.currentUser)
		{
            selfAvatar = [[AvatarManager sharedInstance] imageForUser:STDatabaseManager.currentUser];
	 		
		}
		if (selfAvatar)
			_selfAvatar.image = [selfAvatar avatarImageWithDiameter:kAvatarDiameter];
		else
			_selfAvatar.image = [defaultImage avatarImageWithDiameter:kAvatarDiameter];
		self.backgroundColor = theme.backgroundColor;

		_selfBubbleView.bubbleColor = theme.selfBubbleColor;
        _selfBubbleView.bubbleBorderColor = theme.selfBubbleBorderColor ?  :[UIColor whiteColor];
		_selfBubbleView.authorTypeSelf = YES;
		_selfLabel.textColor = theme.selfBubbleTextColor;
		[_selfBubbleView setNeedsDisplay];
		
		_otherBubbleView.bubbleColor = theme.otherBubbleColor;
        _otherBubbleView.bubbleBorderColor = theme.otherBubbleBorderColor ? :[UIColor whiteColor];

		_otherBubbleView.authorTypeSelf = NO;
		_otherLabel.textColor =  theme.otherBubbleTextColor;
		[_otherBubbleView setNeedsDisplay];
		_dateLabel.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15];
		_dateLabel.textColor = theme.messageLabelTextColor;
		_dateLabel.textAlignment = NSTextAlignmentCenter;
		_dateLabel.layer.cornerRadius = 10;
		_dateLabel.font = [UIFont systemFontOfSize:14.0];
    }
    return self;
}


@end
