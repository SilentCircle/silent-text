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
#import "SCDatabaseLogger+JID.h"
#import "XMPPJID.h"


@implementation SCDatabaseLogger (JID)

/**
 * Attempts to mask any JIDs in the given attributed string.
 * 
 * That is, the method will use regular expression matching to find JIDs of the form:
 * - user@domain.tld
 * - user@domain.tld/resource
 * 
 * It will then replace them with something like:
 * - masked-user@domain.tld
 * - masked-user@domain.tld/masked-resource
 * 
 * Where every occurrence of user@domain.tld is masked with the same masked-user@domain.tld.
 * For example, if the original string is this:
 * 
 *   Got a message from: alice@sc.com/abc123
 *   Sending message to: bob@sc.com
 *   Got a message from: alice@sc.com/abc123
 *   Sending message to: alice@sc.com
 *
 * Then the masked string will be something like this:
 * 
 *   Got a message from: masked-A16Y@sc.com/masked-4GH8
 *   Sending message to: masked-R79A@sc.com
 *   Got a message from: masked-A16Y@sc.com/masked-4GH8
 *   Sending message to: masked-A16Y@sc.com
 * 
 * @return
 *     The number of JIDs that were masked.
**/
+ (NSUInteger)maskJIDsInAttributedString:(NSMutableAttributedString *)attrStr
{
	NSUInteger maskedCount = 0;
	NSMutableDictionary *masks = [NSMutableDictionary dictionary];
	
	// This is not perfect.
	// There are many valid JIDs that won't be caught by this regex.
	// But it will catch most, and the effort required to catch all is non-negligible.
	//
	NSString *expression = @"[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,4}(/[A-Z0-9-]+)?";
	
	NSError *error = nil;
	NSRegularExpression *regex =
	  [NSRegularExpression regularExpressionWithPattern:expression
	                                            options:NSRegularExpressionCaseInsensitive
	                                              error:&error];
	
	if (error) {
		NSLog(@"Error creating regex: %@", error);
		return 0;
	}
	
	NSMutableString *str = attrStr.mutableString;
	NSRange range = NSMakeRange(0, str.length);
	
	NSTextCheckingResult *match = nil;
	do
	{
		match = [regex firstMatchInString:str options:0 range:range];
		
		if (match)
		{
			NSString *replacement = @"masked@domain.tld";
			
			NSRange matchRange = match.range;
			
			NSString *jidStr = [str substringWithRange:match.range];
			XMPPJID *jid = [XMPPJID jidWithString:jidStr];
			
			if (jid)
			{
				replacement = [masks objectForKey:jid];
				if (replacement == nil)
				{
					NSString *user = nil;
					NSString *resource = nil;
					
					if (jid.user)
					{
						NSString *uuid = [[[NSUUID UUID] UUIDString] lowercaseString];
						user = [NSString stringWithFormat:@"masked-%@", uuid];
					}
					
					if (jid.resource)
					{
						NSString *uuid = [[[NSUUID UUID] UUIDString] lowercaseString];
						resource = [NSString stringWithFormat:@"masked-%@", uuid];
					}
					
					if (resource)
						replacement = [NSString stringWithFormat:@"%@@%@/%@", user, jid.domain, resource];
					else
						replacement = [NSString stringWithFormat:@"%@@%@", user, jid.domain];
					
					[masks setObject:replacement forKey:jid];
				}
			}
			
			[str replaceCharactersInRange:matchRange withString:replacement];
			maskedCount++;
			
			range.location = matchRange.location + replacement.length;
			range.length = str.length - range.location;
		}
		
	} while (match);
	
	return maskedCount;
}

@end
