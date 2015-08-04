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
#import "SCDatabaseLogger.h"


@interface SCDatabaseLogger (JID)

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
+ (NSUInteger)maskJIDsInAttributedString:(NSMutableAttributedString *)attrStr;

@end
