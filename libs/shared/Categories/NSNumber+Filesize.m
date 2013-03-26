/*
Copyright © 2012-2013, Silent Circle, LLC.  All rights reserved.

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
//  NSNumber+Filesize.m
//  SilentText
//

#import "NSNumber+Filesize.h"

@implementation NSNumber (Filesize)

- (NSString *)fileSizeString
{
    if (self == nil) return nil;
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:1];
    
    NSString *formattedString = nil;
    uint64_t size = [self unsignedLongLongValue];
    if (size < 1000) {
        NSString *formattedNumber = [formatter stringFromNumber:[NSNumber numberWithFloat:size]];
        formattedString = [NSString stringWithFormat:@"%@ B", formattedNumber];
    }
    else if (size < 1000 * 1000) {
        NSString *formattedNumber = [formatter stringFromNumber:[NSNumber numberWithFloat:size / 1000.0]];
        formattedString = [NSString stringWithFormat:@"%@ KB", formattedNumber];
    }
    else if (size < 1000 * 1000 * 1000) {
        NSString *formattedNumber = [formatter stringFromNumber:[NSNumber numberWithFloat:size / 1000.0 / 1000.0]];
        formattedString = [NSString stringWithFormat:@"%@ MB", formattedNumber];
    }
    else {
        NSString *formattedNumber = [formatter stringFromNumber:[NSNumber numberWithFloat:size / 1000.0 / 1000.0 / 1000.0]];
        formattedString = [NSString stringWithFormat:@"%@ GB", formattedNumber];
    }
    
    formatter = NULL;
     
    return formattedString;
}


@end
