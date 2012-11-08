/*
Copyright © 2012, Silent Circle
All rights reserved.

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
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "Conversation.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

NSString *const kConversationEntity = @"Conversation";
NSString *const kDate = @"date";
NSString *const kFYEO  = @"fyeo";
NSString *const kFlags  = @"flags";
NSString *const kTracking  = @"tracking";
NSString *const kLocalJID  = @"localJID";
NSString *const kRemoteJID = @"remoteJID";
NSString *const kMissives = @"missives";
NSString *const kSCimpKey  = @"scimpKey";
NSString *const kSCPPID  = @"scppID";
NSString *const kSCimpLogEntries = @"scimpLogEntries";

@implementation Conversation

@dynamic date;
@dynamic flags;
@dynamic fyeo, isFyeo;
@dynamic tracking, isTracking;
@dynamic localJID;
@dynamic remoteJID;
@dynamic scimpKey;
@dynamic scimpState;
@dynamic scppID;
@dynamic shredAfter;
@dynamic notRead;
@dynamic viewedDate;
@dynamic missives;
@dynamic scimpLogEntries;

@synthesize delegate = _delegate;

#pragma mark - Accessor methods.


- (BOOL) isFyeo {
    
    return self.fyeo;
    
} // -isFyeo



- (BOOL) isTracking {
    
    return self.tracking;
    
} // -isTracking

- (void) setConversationState: (ConversationState) state
{
    uint16_t s = state & 0x7;
      
    self.flags = (self.flags & ~0x0700)  | s << 8;
}


- (ConversationState) conversationState
{
    ConversationState  s = (self.flags & 0x0700)  >> 8;
    
    return s;
}


- (NSData *) scimpKey {
    
    [self willAccessValueForKey: kSCimpKey];
    
    NSData *tmpValue = [self primitiveValueForKey: kSCimpKey];
    
    [self didAccessValueForKey: kSCimpKey];
    
    return [self.delegate conversation: self decryptData: tmpValue];

} // -scimpKey


- (void) setScimpKey: (NSData *) value {
    
    [self willChangeValueForKey: kSCimpKey];
    
    [self setPrimitiveValue: value ? [self.delegate conversation: self encryptData: value] : nil
                     forKey: kSCimpKey];
    
    [self didChangeValueForKey: kSCimpKey];

} // -setScimpKey:


- (NSString *) scppID {
    
    [self willAccessValueForKey: kSCPPID];
    
    NSString *tmpValue = [self primitiveValueForKey: kSCPPID];
    
    [self didAccessValueForKey: kSCPPID];
    
    if (!tmpValue) {
        
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        
        tmpValue = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
        
        CFRelease(uuid);

        [self setPrimitiveValue: tmpValue forKey: kSCPPID];
    }
    return tmpValue;
    
} // -scppID


#pragma mark - Public methods.


- (NSData *) encryptData: (NSData *) data {

    return [self.delegate conversation: self encryptData: data];

} // -encryptData:


- (NSData *) decryptData: (NSData *) data {
    
    return [self.delegate conversation: self decryptData: data];
    
} // -decryptData:


- (NSData *) encryptedDataFromString: (NSString *) string {
    
    return [self.delegate conversation: self encryptedDataFromString: string];
    
} // -encryptedDataFromString:


- (NSString *) stringFromEncryptedData: (NSData *) data {

    return [self.delegate conversation: self stringFromEncryptedData: data];

} // -stringFromEncryptedData:


- (Cryptor) encryptor {

    return ^NSData *(NSData *data) { 
        
        return [self.delegate conversation: self encryptData: data]; 
    };
    
} // -encryptor


- (Cryptor) decryptor {
    
    return ^NSData *(NSData *data) { 
        
        return [self.delegate conversation: self decryptData: data]; 
    };
    
} // -decryptor

@end
