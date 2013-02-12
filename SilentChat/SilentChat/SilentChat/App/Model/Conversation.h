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
//  Conversation.h
//  SilentText
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <SCimp.h>




enum ConversationState_
{
    kConversationState_Ready        = 0,
//    kConversationState_??           = 1,
    
    /* Initiator State */
    kConversationState_Commit      = 2,
    kConversationState_DH2         = 3,
    
    /* Responder State */
    kConversationState_DH1         = 4,
    kConversationState_Confirm     = 5,
    
    kConversationState_Run         = 6,
    kConversationState_Init        = 7,
    kConversationState_Error       = 8,
    kConversationState_Keyed       = 9,
    
    ENUM_FORCE(  ConversationState_ )
};

ENUM_TYPEDEF( ConversationState_, ConversationState );


extern NSString *const kConversationEntity;
extern NSString *const kDate;
extern NSString *const kFlags;
extern NSString *const kFYEO;
extern NSString *const kTracking;
extern NSString *const kLocalJID;
extern NSString *const kRemoteJID;
extern NSString *const kMissives;
extern NSString *const kSCPPID;
extern NSString *const kSCimpLogEntries;
extern NSString *const kInfoEntries;
extern NSString *const kNotRead;

typedef NSData *(^Cryptor)(NSData *data);

@protocol ConversationDelegate;

@class Missive;
@class Siren;

@interface Conversation : NSManagedObject

@property (strong, nonatomic) NSDate   * date;      // The time when this conversation was created or a missive was added.
@property (nonatomic)         uint16_t   flags;
@property (nonatomic) BOOL fyeo;
@property (nonatomic) BOOL tracking;
@property (strong, nonatomic) NSString *  localJID; // The Full JID.
@property (strong, nonatomic) NSString * remoteJID; // The Full JID.
@property (strong, nonatomic) NSData   * scimpKey;  // The shared key for a conversation.
@property (strong, nonatomic) NSData   * scimpState; // Deprecated  (we dont use this any more) 
@property (strong, nonatomic) NSString * scppID;
@property (nonatomic)         uint32_t shredAfter;
@property (strong, nonatomic) NSDate   * viewedDate;// The last time this conversation was viewed. Used for the message exipry timer.
@property (strong, nonatomic) NSSet    * missives;
@property (strong, nonatomic) NSSet    * scimpLogEntries;
@property (strong, nonatomic) NSSet    * infoEntries;
@property (nonatomic)         uint16_t  notRead;

@property (weak,   nonatomic) id<ConversationDelegate> delegate;

// Synthetic ivar
@property (nonatomic, readonly) BOOL isFyeo; // Add the traditional getter to the CD BOOL property.
@property (nonatomic, readonly) BOOL isTracking; // Add the traditional getter to the CD BOOL property.

@property (nonatomic) ConversationState conversationState;
 
@property (nonatomic) BOOL attentionFlag;
@property (nonatomic) BOOL burnFlag;
@property (nonatomic) BOOL unseenBurnFlag;
@property (nonatomic) BOOL keyedFlag;
@property (nonatomic) BOOL keyVerifiedFlag;


- (Siren*) findSirenFromUploads: (NSString*) locator;
- (void)   removeSirenFromUpload: (NSString*) locator;
- (void)   addSirenToUpload: (Siren*) siren;

- (NSData *) encryptData: (NSData *) data;
- (NSData *) decryptData: (NSData *) data;

- (NSData *)   encryptedDataFromString: (NSString *) string;
- (NSString *) stringFromEncryptedData: (NSData *)   data;

- (Cryptor) encryptor;
- (Cryptor) decryptor;


@end

@protocol ConversationDelegate <NSObject>

@required

- (NSData *) conversation: (Conversation *) conversation encryptData: (NSData *) data;
- (NSData *) conversation: (Conversation *) conversation decryptData: (NSData *) data;

- (NSData *)   conversation: (Conversation *) conversation encryptedDataFromString: (NSString *) string;
- (NSString *) conversation: (Conversation *) conversation stringFromEncryptedData: (NSData *)   data;

- (void) conversation: (Conversation *) conversation deleteAllData:(NSString *) localJID remoteJID:(NSString *)remoteJID;

@end

@interface Conversation (CoreDataGeneratedAccessors)

- (void)    addMissivesObject: (Missive *) value;
- (void) removeMissivesObject: (Missive *) value;
- (void)    addMissives: (NSSet *) value;
- (void) removeMissives: (NSSet *) value;

- (void)    addScimpLogEntriesObject: (Missive *) value;
- (void) removeScimpLogEntriesObject: (Missive *) value;
- (void)    addScimpLogEntries: (NSSet *) value;
- (void) removeScimpLogEntries: (NSSet *) value;

- (void)    addInfoEntriesObject: (Missive *) value;
- (void) removeInfoEntriesObject: (Missive *) value;
- (void)    addInfoEntries: (NSSet *) value;
- (void) removeInfoEntries: (NSSet *) value;

@end
