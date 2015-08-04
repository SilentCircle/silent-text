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
//  NSString+SCUtilities.h
//  SilentText
//

#import <Foundation/Foundation.h>

@interface NSString (SCUtilities)

+ (NSString *)hexEncodeBytes:(const uint8_t *)bytes length:(NSUInteger)length;

- (NSString *)urlEncodedString;
- (NSString *)urlEncodedBase64SafeString;

- (NSString *)urlDecodedString;

+ (NSString *)timeIntervalToStringWithInterval:(NSTimeInterval)interval;

- (NSString *)sha1String;

+ (BOOL)isString:(NSString *)string1 equalToString:(NSString *)string2;


/** ET 08/06/14
 * A utility method used by several conversation details methods to derive a substring from a given string.
 *
 * @param toString The string char or chars marking the extent of the substring length.
 * @param aString  The string from which to derive the return substring.
 * @return
 */
+ (NSString *)substringToString:(NSString *)toString inString:(NSString *)aString;

/** 
 * @return `YES` if the given string is nil, or after trimming, has no characters, otherwise `NO`.
 */
+ (BOOL)stringIsNilOrEmpty:(NSString *)str;

/** 
 * @return `YES` if the given string, trimmed, has characters, otherwise `NO`.
 */
+ (BOOL)stringIsNotEmpty:(NSString *)str;

/**
 * @return A new string from the given string trimmed of whitespace and newline chars.
 */
+ (NSString *)trimmedString:(NSString *)str;

/**
 * Validates the given string instance as email address.
 *
 * @see http://stackoverflow.com/questions/3139619/check-that-an-email-address-is-valid-on-ios
 * also http://stackoverflow.com/questions/5428304/email-validation-on-textfield-in-iphone-sdk
 * @see isValidEmail instance method
 */
+ (BOOL)isValidEmail:(NSString *)str;

/** 
 * @return `NO` if the trimmed self has no characters, otherwise `YES`.
 */
- (BOOL)isEmpty;

/** 
 * @return `YES` if the trimmed self has characters, otherwise `NO`.
 */
- (BOOL)isNotEmpty;

/**
 * Wrapper for trimmedString class category method to return a new string trimmed of whitespace and newline chars.
 * @return A new string trimmed of whitespace and newline chars.
 * @see trimmedString class category method
 */
- (NSString *)trimmedString;

/**
 * Wrapper for isValidEmail class category method to validate string instance as email address.
 * @see isValidEmail class category method
 */
- (BOOL)isValidEmail;

/** 
 * @return A new NSString made by appending the "\n" newline character. 
 */
- (NSString *)stringByAppendingNewline;

@end
