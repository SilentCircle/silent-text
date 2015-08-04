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
//  NSString+SCUtilities.m
//  SilentText
//

#import <SCCrypto/SCcrypto.h>

#import "NSString+SCUtilities.h"

@implementation NSString (SCUtilities)

+ (NSString *)hexEncodeBytes:(const uint8_t *)bytes length:(NSUInteger)length
{
    NSString *encodedString = nil;
    
    char hexDigit[] = "0123456789abcdef";
    uint8_t         *oBuf   = NULL;
    unsigned long   len =  (length * 2) ;
    
    oBuf = XMALLOC(len);
	if (oBuf)
	{
		*oBuf= 0;
          
        register int    i;
        uint8_t *p = oBuf;
        
        for (i = 0; i < length; i++)
         {
            *p++ =  hexDigit[ bytes[i] >>4];
            *p++ =  hexDigit[ bytes[i] &0xF];
        }
        
		encodedString = [[NSString alloc] initWithBytesNoCopy:oBuf
		                                               length:len
		                                             encoding:NSUTF8StringEncoding
		                                         freeWhenDone:YES];
	}
	
	return encodedString;
}

- (NSString *)urlEncodedString
{
    // From the docs for CFURLCreateStringByAddingPercentEscapes:
    //   "If you are uncertain of the correct encoding, you should use UTF-8 (kCFStringEncodingUTF8),
    //    which is the encoding designated by RFC 3986 as the correct encoding for use in URLs."
    
	CFStringRef encodedString = NULL;
	encodedString = CFURLCreateStringByAddingPercentEscapes(NULL,
	                                           (CFStringRef)self,
	                                                        NULL,                   // charactersToLeaveUnescaped
	                                           (CFStringRef)@"!*'();:@&=+$,/?%#[]", // legalURLCharactersToBeEscaped
	                                                        kCFStringEncodingUTF8);

	return (__bridge_transfer NSString *)encodedString;
}

/**
 * Extended context for this method:
 * 
 * - https://tickets.silentcircle.org/browse/WEB-1090
 * - https://tickets.silentcircle.org/browse/STA-783
 * - https://tickets.silentcircle.org/browse/ST-730
 * - https://tickets.silentcircle.org/browse/WEB-1722
**/
- (NSString *)urlEncodedBase64SafeString
{
	NSString *base64safe = self;
	
	base64safe = [base64safe stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
	base64safe = [base64safe stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
	
	return [base64safe urlEncodedString];
}

- (NSString *)urlDecodedString
{
	CFStringRef decodedString = NULL;
	decodedString = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
	                                                  (__bridge CFStringRef)self,
	                                                                        CFSTR(""),
	                                                                        kCFStringEncodingUTF8);
	
	return (__bridge_transfer NSString *)decodedString;
}

+ (NSString *)timeIntervalToStringWithInterval:(NSTimeInterval)interval
{
    NSString *retVal = NSLocalizedString(@"At time of event", @"At time of event");
    if (interval == 0) return retVal;
    
    int second = 1;
    int minute = second*60;
    int hour = minute*60;
    int day = hour*24;
    // interval can be before (negative) or after (positive)
    int num = fabs(interval);
    
	NSString *unit = NSLocalizedString(@"day", @"day");
    
    if (num >= day) {
        num /= day;
        if (num > 1) unit = NSLocalizedString(@"days", @"days");
    } else if (num >= hour) {
        num /= hour;
        unit = (num > 1) ? NSLocalizedString(@"hours", @"hours") : NSLocalizedString(@"hour", @"hour");
    } else if (num >= minute) {
        num /= minute;
        unit = (num > 1) ? NSLocalizedString(@"minutes", @"minutes") : NSLocalizedString(@"minute", @"minute");
    } else if (num >= second) {
        num /= second;
        unit = (num > 1) ? NSLocalizedString(@"seconds", @"seconds") : NSLocalizedString(@"second", @"second");
        
    }
    
    return [NSString stringWithFormat:@"%d %@", num, unit];
}

- (NSString *)sha1String
{
    uint8_t hash[20]; // SHA-1
    const char *utf8 = [self UTF8String];
    
    HASH_DO(kHASH_Algorithm_SHA1, utf8, strlen(utf8), sizeof(hash), hash);
	
	NSData *data = [NSData dataWithBytesNoCopy:hash length:sizeof(hash) freeWhenDone:NO];
	return [data base64EncodedStringWithOptions:0];
}

+ (BOOL)isString:(NSString *)string1 equalToString:(NSString *)string2
{
	if (string1 == nil && string2 == nil)
		return YES;
	else
		return [string1 isEqualToString:string2];
	
	// Note:
	//
	// if (string1 == nil) => [string1 isEqualToString:string2] == NO
	// if (string2 == nil) => [string1 isEqualToString:string2] == NO
}



/** ET 08/06/14
 * A utility method used by several conversation details methods to derive a substring from a given string.
 *
 * @param toString The string char or chars marking the extent of the substring length.
 * @param aString  The string from which to derive the return substring.
 * @return
 */
+ (NSString *)substringToString:(NSString *)toString inString:(NSString *)aString
{
    NSString *subStr = nil;
    NSRange range = [aString rangeOfString:toString];
    if (range.location != NSNotFound)
    {
        subStr = [aString substringToIndex:range.location];
    }
    return subStr;
}

/** 
 * @return `YES` if the given string is nil, or after trimming, has no characters, otherwise `NO`.
 */
+ (BOOL)stringIsNilOrEmpty:(NSString *)str {
    return (nil == str || [str isEmpty]);
}

/** 
 * @return `YES` if the given string, trimmed, has characters, otherwise `NO`.
 */
+ (BOOL)stringIsNotEmpty:(NSString *)str {
    return nil != str && [[str trimmedString] length] > 0;
}

/**
 * @return A new string from the given string trimmed of whitespace and newline chars.
 */
+ (NSString *)trimmedString:(NSString *)str {
    return [str stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

/**
 * Validates the given string instance as email address.
 *
 * @see http://stackoverflow.com/questions/3139619/check-that-an-email-address-is-valid-on-ios
 * also http://stackoverflow.com/questions/5428304/email-validation-on-textfield-in-iphone-sdk
 * @see isValidEmail instance method
 */
+ (BOOL)isValidEmail:(NSString *)str {
    BOOL stricterFilter = YES; // Discussion http://blog.logichigh.com/2010/09/02/validating-an-e-mail-address/
    NSString *stricterFilterString = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
    NSString *laxString = @".+@.+\\.[A-Za-z]{2}[A-Za-z]*";
    NSString *emailRegex = stricterFilter ? stricterFilterString : laxString;
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:str];
}

/** 
 * @return `NO` if the trimmed self has no characters, otherwise `YES`.
 */
- (BOOL)isEmpty {
    return [[self trimmedString] length] == 0;
}

/** 
 * @return `YES` if the trimmed self has characters, otherwise `NO`.
 */
- (BOOL)isNotEmpty {
    return [[self trimmedString] length] > 0;
}

/**
 * Wrapper for trimmedString class category method to return a new string trimmed of whitespace and newline chars.
 * @return A new string trimmed of whitespace and newline chars.
 * @see trimmedString class category method
 */
- (NSString *)trimmedString {
    return [NSString trimmedString:self];
}

/**
 * Wrapper for isValidEmail class category method to validate string instance as email address.
 * @see isValidEmail class category method
 */
- (BOOL)isValidEmail {
    return [NSString isValidEmail:self];
}

/** 
 * @return A new NSString made by appending the "\n" newline character. 
 */
- (NSString *)stringByAppendingNewline {
    return [NSString stringWithFormat:@"%@%@",self,@"\n"];
}

@end
