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
//  SCTHelpManager.h
//  ST2
//
//  Created by Eric Turner on 7/26/14.
//

#import <Foundation/Foundation.h>

extern NSString * const SCT_DEFAULT_HELP;
extern NSString * const SCT_CONVERSATION_DETAILS_HELP;


/**
 * A class to centralize access to Help resources, such as language-localized content.
 */
@interface SCTHelpManager : NSObject


#pragma mark Help Content
+ (NSString *)contentForKey:(NSString *)aKey;

+ (NSString *)contentForKey:(NSString *)aKey inTable:(NSString *)tblName;


#pragma mark Help Titles
+ (NSString *)simpleHelpTitle;

+ (NSString *)helpTitleWithContext:(NSString *)context;

#pragma mark Utilities
+ (NSString *)stringForKey:(NSString *)key inTable:(NSString *)tblName;

// unblurred self view image (i.e. contentView - without navbar)
// HelpDetailsVC creates the blurred image from this one
+ (UIImage *)bgImageFromSubView:(UIView *)aView parentView:(UIView *)pView;

@end
