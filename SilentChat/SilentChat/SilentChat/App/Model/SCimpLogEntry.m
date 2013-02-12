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
//  SCimpLogEntry.m
//  SilentText
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "SCimpLogEntry.h"
#import "Conversation.h"

#include "cryptowrappers.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

NSString *const kSCimpLogEntryEntity = @"SCimpLogEntry";

@implementation SCimpLogEntry

@dynamic date;
@dynamic error;
@dynamic jsonData;
@dynamic xmppMessage;
@dynamic conversation;

// Synthetic properties.
@synthesize errorString = _errorString;
@synthesize info = _info;

- (NSString *) errorString {
    
    if (_errorString) { return _errorString; }

    char *errorStr = calloc(256, 1);
    
    SCLGetErrorString(self.error, 256, errorStr);
    
    NSString *errorString = [NSString.alloc initWithBytesNoCopy: errorStr 
                                                         length: strlen(errorStr) 
                                                       encoding: NSUTF8StringEncoding 
                                                   freeWhenDone: YES];
    _errorString = errorString;
    
    return errorString;
    
} // -errorString


- (NSDictionary *) info {
    
    if (_info) { return _info; }
    
    NSError *error = nil;
    NSDictionary *info = nil;
    
    info = [NSJSONSerialization JSONObjectWithData: self.jsonData options: 0 error: &error];
    
    if (error) {
        
        DDGDesc(error.userInfo);
        
        info = nil;
    }
    self.info = info;

    return info;

} // -info


- (void) setInfo: (NSDictionary *) info {
    
    NSData *jsonData = nil;
    
    if (info) {
        
        NSError *error = nil;
        
        jsonData = [NSJSONSerialization dataWithJSONObject: info options: 0 error: &error];

        if (error) {
            
            DDGDesc(error.userInfo);
            
            info = nil;
            jsonData = nil;
        }
    }
    _info = info;
    self.jsonData = jsonData;
        
} // -setInfo:


#pragma mark - NSManagedObject methods.


- (void) willTurnIntoFault {
    
    _errorString = nil;
    _info = nil;
    
} // -willTurnIntoFault

@end
