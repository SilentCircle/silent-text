/*
Copyright (C) 2015, Silent Circle, LLC. All rights reserved.

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
#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/NSColor.h>
#endif

#import "XplatformUI.h"

/**
 * This class mirrors DDTTYLogger's color options,
 * which allows you to get the same color profile that you're used to in Xcode.
**/
@interface SCDatabaseLoggerColorProfiles : NSObject <NSCopying>

- (void)setForegroundColor:(OSColor *)txtColor backgroundColor:(OSColor *)bgColor forFlag:(int)mask;
- (void)setForegroundColor:(OSColor *)txtColor backgroundColor:(OSColor *)bgColor forFlag:(int)mask context:(int)ctxt;

- (void)setForegroundColor:(UIColor *)txtColor backgroundColor:(UIColor *)bgColor forTag:(id <NSCopying>)tag;

- (void)clearColorsForFlag:(int)mask;
- (void)clearColorsForFlag:(int)mask context:(int)context;

- (void)clearColorsForTag:(id <NSCopying>)tag;

- (void)clearColorsForAllFlags;
- (void)clearColorsForAllTags;
- (void)clearAllColors;

- (void)getForegroundColor:(OSColor **)txtColorPtr
           backgroundColor:(OSColor **)bgColorPtr
                   forFlag:(int)mask
                   context:(int)ctxt
                       tag:(id)tag;

@end
