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
//
//  AppTheme.h
//  ST2
//
//  Created by mahboud on 10/28/13.
//

#import <Foundation/Foundation.h>

#define kAppThemeChangeNotification @"AppThemeChangeNotification"
#define kNotificationUserInfoTheme @"theme"
#define kNotificationUserInfoName	@"name"

@interface AppTheme : NSObject

// consider nav bar and nav bars for minor view controllers, since backgrounds with a clashing nav bar are ugly
@property (nonatomic, strong, readonly) UIFont   * conversationBodyFont;
@property (nonatomic, strong, readonly) UIFont   * conversationHeaderFont;
@property (nonatomic, strong, readonly) UIColor  * conversationBodyColor;
@property (nonatomic, strong, readonly) UIColor  * conversationHeaderColor;
@property (nonatomic, strong, readonly) UIFont   * messageHeaderFont;
@property (nonatomic, strong, readonly) UIColor  * messageHeaderColor;
@property (nonatomic, strong, readonly) UIFont   * messageBodyFont;
@property (nonatomic, strong, readonly) UIColor  * backgroundTextColor;
@property (nonatomic, strong, readonly) UIColor  * selfBubbleColor;
@property (nonatomic, strong, readonly) UIColor  * selfBubbleTextColor;
@property (nonatomic, strong, readonly) UIColor  * selfBubbleBorderColor;
@property (nonatomic, strong, readonly) UIColor  * selfAvatarBorderColor;
@property (nonatomic, strong, readonly) NSDictionary  * selfLinkTextAttributes;
@property (nonatomic, strong, readonly) UIColor  * otherBubbleColor;
@property (nonatomic, strong, readonly) UIColor  * otherBubbleTextColor;
@property (nonatomic, strong, readonly) UIColor  * otherBubbleBorderColor;
@property (nonatomic, strong, readonly) UIColor  * otherAvatarBorderColor;
@property (nonatomic, strong, readonly) NSDictionary  * otherLinkTextAttributes;
@property (nonatomic, strong, readonly) UIColor  * bubbleSelectionBorderColor;
@property (nonatomic, strong, readonly) UIColor  * messageLabelTextColor;
@property (nonatomic, strong, readonly) UIColor  * messageLabelBGColor;
@property (nonatomic, strong, readonly) UIColor  * appTintColor;
@property (nonatomic, strong, readonly) NSString * backgroundImageFileName;
@property (nonatomic, strong, readonly) UIColor  * plainBackgroundColor;
@property (nonatomic, strong, readonly) UIColor  * navBarColor;
@property (nonatomic, strong, readonly) UIColor  * navBarTitleColor;
@property (nonatomic, assign, readonly) BOOL       navBarIsBlack;
@property (nonatomic, assign, readonly) BOOL       navBarIsTranslucent;
@property (nonatomic, assign, readonly) BOOL       chatOptionsIsDark;
@property (nonatomic, assign, readonly) BOOL       scrollerColorIsWhite;
@property (nonatomic, assign, readonly) NSString * localizedName;
@property (nonatomic, strong, readonly) NSString * themeKey;


- (UIColor *) backgroundColor;
- (UIColor *) blurredBackgroundColor;

+ (NSInteger) count;
+ (NSString *) getThemeKeyForIndex:(NSInteger) index;
+ (NSArray *) getAllThemeKeys;
+ (instancetype) getThemeBySelectedKey;
+ (instancetype) getThemeByKey:(NSString *) key;
+ (void) selectWithKey:(NSString *) key;
+ (NSString *) getSelectedKey;
+ (void) setSelectedKey:(NSString *) key;

@end
