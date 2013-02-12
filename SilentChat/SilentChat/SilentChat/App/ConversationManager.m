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
//  ConversationManager.m
//  SilentText
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "DDLog.h"

#import <CommonCrypto/CommonDigest.h>
#include "SCpubTypes.h"

#include "cryptowrappers.h"
#import "AppConstants.h"

#import "SilentTextStrings.h"
#import "ConversationManager.h"
 
#import "Missive.h"
#import "SCimpLogEntry.h"
#import "InfoEntry.h"

#import "SCAccount.h"
#import "StorageCipher.h"
#import "Preferences.h"
#import "App+Model.h"
#import "SCimpSavedState.h"

#import "Siren.h"
#import "SCloudObject.h"

#import "XMPPServer.h"
#import "XMPPJID+AddressBook.h"
#import "XMPPMessage+SilentCircle.h"
#import "XMPPDateTimeProfiles.h"

#import "XMPPIQ.h"
#import "NSManagedObjectContext+DDGManagedObjectContext.h"
#import "STSoundManager.h"

#import "GCDMulticastDelegate.h"
#import "SCloudManager.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

#define XMLNS_XMPP_TIME @"urn:xmpp:time"

@interface ConversationManager ()

@property (strong, nonatomic, readwrite) NSArray *conversations;

@property (strong, nonatomic, readwrite) NSString *pushIQid;
@property (strong, nonatomic, readwrite) NSString *timeIQid;

@property (atomic, readwrite) int totalUnread;


- (void) registerForNotifications;

@end

@implementation ConversationManager

@synthesize storageCipher = _storageCipher;
@synthesize conversations = _conversations;

@synthesize pushIQid = _pushIQid;
@synthesize timeIQid = _timeIQid;

@synthesize totalUnread = _totalUnread;
@synthesize delegate = _delegate;

#pragma mark - GCDMulticastDelegate Configuration

dispatch_queue_t conversationQueue;

GCDMulticastDelegate <ConversationManagerDelegate> *multicastDelegate;

- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
	// Asynchronous operation (if outside xmppQueue)
	
	dispatch_block_t block = ^{
		[multicastDelegate addDelegate:delegate delegateQueue:delegateQueue];
	};
	
	if (dispatch_get_current_queue() == conversationQueue)
		block();
	else
		dispatch_async(conversationQueue, block);
}

- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue
{
	// Synchronous operation
	
	dispatch_block_t block = ^{
		[multicastDelegate removeDelegate:delegate delegateQueue:delegateQueue];
	};
	
	if (dispatch_get_current_queue() == conversationQueue)
		block();
	else
		dispatch_sync(conversationQueue, block);
}

- (void)removeDelegate:(id)delegate
{
	// Synchronous operation
	
	dispatch_block_t block = ^{
		[multicastDelegate removeDelegate:delegate];
	};
	
	if (dispatch_get_current_queue() == conversationQueue)
		block();
	else
		dispatch_sync(conversationQueue, block);
}

#pragma mark - Accessor methods.


- (NSArray *) conversations {
    
    if (_conversations) { return _conversations; }
    
    NSArray *array = [App.sharedApp.moc fetchObjectsForEntity: kConversationEntity];
    
    self.conversations = array;
    
    return array;
    
} // -conversations

- (NSArray *) JIDs {
  
    NSMutableArray * jidArray = [[NSMutableArray alloc] init];
    
    for (Conversation *conversation in [self conversations]) {
        
          [jidArray addObject: [XMPPJID jidWithString: conversation.remoteJID]];
    }

    return jidArray;
}

  

#pragma mark - Initialization methods.


- (void) dealloc {
    
    dispatch_release(conversationQueue);

 	[NSNotificationCenter.defaultCenter removeObserver: self];
    
} // -dealloc


- (id) init {
    
    self = [super init];
    
    if (self) {
        
        conversationQueue = dispatch_queue_create("conversation", NULL);
        
        multicastDelegate = (GCDMulticastDelegate <ConversationManagerDelegate> *)[[GCDMulticastDelegate alloc] init];

        [self registerForNotifications];
      }
    return self;
    
} // -init

 
 
#pragma mark - Conversation Instance methods.
 
- (Conversation *) makeConversationForLocalJid: (XMPPJID *) myJid 
                                     remoteJid: (XMPPJID *) theirJid
                        inManagedObjectContext: (NSManagedObjectContext *) moc {
    
    Conversation *conversation = nil;
    
    conversation = [NSEntityDescription insertNewObjectForEntityForName: kConversationEntity
                                                 inManagedObjectContext: moc];
    conversation.delegate   = self;
    conversation.date       = NSDate.date;
    conversation.fyeo       = App.sharedApp.preferences.isFyeo;
    conversation.tracking   = App.sharedApp.preferences.isTracking;
    conversation.localJID   = myJid.bare;
    conversation.remoteJID  = theirJid.full;
    conversation.scimpKey   = StorageCipher.makeSCimpKey;
    conversation.shredAfter = App.sharedApp.preferences.shredAfter;
    conversation.notRead = 0;
 
    [moc save];
    
    DDGDesc(conversation);
  
    // update the list of conversations.
    NSArray *array = [App.sharedApp.moc fetchObjectsForEntity: kConversationEntity];
    self.conversations = array;
    
    
    return conversation;
    
} // -makeConversationForLocalJid:remoteJid:inManagedObjectContext:


- (BOOL) conversationForLocalJidExists: (XMPPJID *) myJid
                                 remoteJid: (XMPPJID *) theirJid
{
 
     NSManagedObjectContext *moc = App.sharedApp.moc;
    
    moc = NSThread.isMainThread ? moc : [moc makeConfinedChildMOC];
    
    myJid = [XMPPJID jidWithString: myJid.bare]; // We only use the bare local JID.
    
    // this sucks, core data on sqlite cant run block predicates, we have to read the whole table in.

    NSArray *allConversations = [moc fetchObjectsForEntity: kConversationEntity];
    
    NSPredicate *findBareMatchingJid = [NSPredicate predicateWithBlock: ^BOOL(id obj, NSDictionary *bind)
                                        {
                                            Conversation *con = (Conversation*) obj;
                                            
                                            XMPPJID* remoteJID = [XMPPJID jidWithString:con.remoteJID];
                                            BOOL foundJid  = ([con.localJID isEqualToString:myJid.bare]
                                                              && [ [remoteJID bare] isEqualToString:theirJid.bare]);
                                            return foundJid;
                                        }];
    
    NSArray *conversations =  [allConversations filteredArrayUsingPredicate:findBareMatchingJid];
    
    return (conversations && ([conversations count] > 0));
    
} // -conversationForLocalJidExists:



- (Conversation *) conversationForLocalJid: (XMPPJID *) myJid
                                 remoteJid: (XMPPJID *) theirJid 
                    inManagedObjectContext: (NSManagedObjectContext *) moc {
    
    myJid = [XMPPJID jidWithString: myJid.bare]; // We only use the bare local JID.
    
    
    // this sucks, core data on sqlite cant run block predicates, we have to read the whole table in.
    
    NSArray *allConversations = [moc fetchObjectsForEntity: kConversationEntity];
    
    NSPredicate *findBareMatchingJid = [NSPredicate predicateWithBlock: ^BOOL(id obj, NSDictionary *bind)
                                        {
                                            Conversation *con = (Conversation*) obj;
                                            
                                            XMPPJID* remoteJID = [XMPPJID jidWithString:con.remoteJID];
                                            BOOL foundJid  = ([con.localJID isEqualToString:myJid.bare]
                                                              && [ [remoteJID bare] isEqualToString:theirJid.bare]);
                                            return foundJid;
                                        }];
    
    NSArray *conversations =  [allConversations filteredArrayUsingPredicate:findBareMatchingJid];
    
    Conversation *conversation = conversations.lastObject;
    
    if (!conversation) {
        
        conversation = [self makeConversationForLocalJid: myJid remoteJid: theirJid inManagedObjectContext: moc];
        
        if(  theirJid.resource)
        {
            [self remoteJIDWillChangeforConversation:conversation oldJID:conversation.remoteJID newJID:theirJid.full];
            [moc save];
            
        }
    }
    else if(  theirJid.resource &&  ![conversation.remoteJID isEqualToString:theirJid.full])
    {
        // remote JID got updated with resource
        [self remoteJIDWillChangeforConversation:conversation oldJID:conversation.remoteJID newJID:theirJid.full];

        conversation.remoteJID = theirJid.full;
         [moc save];
     }
    
    
    conversation.delegate = self; // Ensure the conversation can connect back to us.
    
    return conversation;
    
} // -conversationForLocalJid:remoteJid:inManagedObjectContext:


- (Conversation *) conversationForLocalJid: (XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid {
    
    NSManagedObjectContext *moc = App.sharedApp.moc;
    
    moc = NSThread.isMainThread ? moc : [moc makeConfinedChildMOC];
    
    Conversation *conversation = nil;
    
    conversation = [self conversationForLocalJid: myJid remoteJid: theirJid inManagedObjectContext: moc];
    
    return conversation;
    
} // -conversationForLocalJid:remoteJid:



  
- (NSManagedObjectContext *) deleteMissivesWithMOC: (NSManagedObjectContext *) moc myJid: (XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid
{
    Conversation *conversation = [self conversationForLocalJid: myJid remoteJid: theirJid inManagedObjectContext: moc];
    
    NSArray *missives = [conversation.missives.allObjects
                         sortedArrayUsingDescriptors:
                         [NSArray arrayWithObject:
                          [NSSortDescriptor sortDescriptorWithKey: kDate ascending: YES]]];
    
    
    for (Missive *missive in missives) {
        [moc deleteObject: missive];
    }
    
    NSArray *infoEntries = [conversation.infoEntries.allObjects
                         sortedArrayUsingDescriptors:
                         [NSArray arrayWithObject:
                          [NSSortDescriptor sortDescriptorWithKey: kDate ascending: YES]]];
    
    for (InfoEntry *infoEntry in infoEntries) {
        
        NSString* entryType = infoEntry.info?[infoEntry.info valueForKey:kInfoEntryType]:NULL;
        
        if(entryType && [entryType isEqualToString:kInfoEntryResourceChange])
            [moc deleteObject: infoEntry];
    }
     
    conversation.date       = NSDate.date;
    conversation.notRead = 0;
    
    [self deleteCachedScloudObjects: conversation];
 
    /*
    NSArray *logEntries = [conversation.scimpLogEntries.allObjects
                         sortedArrayUsingDescriptors:
                         [NSArray arrayWithObject:
                          [NSSortDescriptor sortDescriptorWithKey: kDate ascending: YES]]];
    
    
    for (SCimpLogEntry *logEntry in logEntries) {
        
//        [moc deleteObject: logEntry];
    }

  */  
    [moc save];
    
    return moc;
    
} // -shredMissivesWithMOC:


- (void) deleteMissiveFromConversation:(XMPPJID *) myJid remoteJid: (XMPPJID *) remoteJid missive:(Missive*) missive;
{
    
    Conversation *conversation  = [self conversationForLocalJid: myJid
                                                      remoteJid: remoteJid];
    
    NSManagedObjectContext *moc = conversation.managedObjectContext;
   
    
    conversation.notRead = 0;
    
    //   [self deleteCachedScloudObjects: conversation];
    
    [moc deleteObject: missive];
    [moc save];

    
}
- (void) clearConversation:(XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid
{
   
    NSManagedObjectContext *moc = [App.sharedApp.moc makeConcurrentChildMOC];
     
    [moc performBlock: ^{ [self deleteMissivesWithMOC:moc myJid:myJid remoteJid:theirJid]; }];
    
   }

-(NSArray*) missivesWithScloud:(Conversation *)conversation
{
    NSMutableArray* scloudMissives = [[NSMutableArray alloc] init];
    
    if(conversation)
    {
        NSArray *missives = [conversation.missives.allObjects
                             sortedArrayUsingDescriptors:
                             [NSArray arrayWithObject:
                              [NSSortDescriptor sortDescriptorWithKey: kDate ascending: YES]]];
        
        for (Missive *missive in missives) {
            
           if(missive && missive.siren && missive.siren.cloudLocator && missive.siren.cloudKey)
           {
               [scloudMissives addObject: missive];
               
           }
            
               
        }
    }
    
    return scloudMissives;
}



-(void) deleteCachedScloudObjects:(Conversation *)conversation
{
    NSArray * missives = [self missivesWithScloud: conversation];
    
    for (Missive *missive in missives) {
        if(missive.siren && missive.siren.cloudLocator)
        {
            [SCloudObject removeCachedFileWithLocatorString:missive.siren.cloudLocator];
            
 // if we wanted to actually delete the content on the server, this is how we would do it
// dont orget to add in the delagate callbacks
//           [App.sharedApp.scloudManager startDeleteWithDelagate:self locator:missive.siren.cloudLocator ];
         }
    }
}

- (void) resetScimpState:(XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid {
    
    Conversation *conversation = [self conversationForLocalJid: myJid remoteJid: theirJid];
    
    conversation.scimpState = NULL;   // no longer used?
    
    [self deleteState: myJid remoteJid: theirJid];
    
    conversation.conversationState = kConversationState_Init;
   
    [conversation.managedObjectContext save];
}


- (int) totalMessagesNotFrom:(XMPPJID *) remoteJid
{
    int total = 0;
    
    NSManagedObjectContext *moc = App.sharedApp.moc;
    
    moc = NSThread.isMainThread ? moc : [moc makeConfinedChildMOC];
     
    NSArray *allConversations = [moc fetchObjectsForEntity: kConversationEntity];
    
    NSPredicate *p = [NSPredicate predicateWithBlock: ^BOOL(id obj, NSDictionary *bind)
                      {
                          Conversation *con = (Conversation*) obj;
                          
                          XMPPJID* conJID = [XMPPJID jidWithString:con.remoteJID];
                          
                          BOOL foundJid  = (con.notRead  > 0
                                            && [ [conJID bare] isEqualToString:remoteJid.bare]);
                          return foundJid;
                      }];
    
    NSArray *conversations =  [allConversations filteredArrayUsingPredicate:p];
 
    for (Conversation *conversation in conversations) {
        total+= conversation.notRead;
    }
    
    return (total);
}

#pragma mark - utility methods.

- (void) remoteJIDWillChangeforConversation:(Conversation *) conversation oldJID:(NSString*)oldJID newJID:(NSString*)newJID
{
    
    DDGLog(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, newJID );

    NSMutableDictionary*  info = [NSMutableDictionary dictionaryWithCapacity: 2];

    [info setValue:kInfoEntryResourceChange forKey:kInfoEntryType];
    [info setValue:newJID forKey:kInfoEntryJID];
      
    [self insertInfoEntryForRemoteJID: [XMPPJID jidWithString:oldJID]  withInfo:info ];
    
    [multicastDelegate conversationmanager:self didUpdateRemoteJID:[XMPPJID jidWithString:newJID]];

}



- (InfoEntry *) insertInfoEntryForRemoteJID: (XMPPJID *) remoteJID withInfo: (NSDictionary *) info
{
    
    Conversation *conversation = [self conversationForLocalJid: App.sharedApp.currentJID remoteJid: remoteJID];
    
    InfoEntry *infoEntry = [NSEntityDescription insertNewObjectForEntityForName: kInfoEntryEntity
                                                         inManagedObjectContext: conversation.managedObjectContext];
    
    infoEntry.date =  NSDate.date; // [NSDate.date dateByAddingTimeInterval:App.sharedApp.serverTimeOffset ];
    infoEntry.info = info;
    infoEntry.conversation = conversation;
    
    [infoEntry.managedObjectContext save];
    
    conversation.date       = NSDate.date;
    [conversation.managedObjectContext save];
    
    return infoEntry;
    
} // -insertSCimpLogEntryForRemoteJID:withInfo:message:error:


#pragma mark - ConversationDelegate methods.


- (NSData *) conversation: (Conversation *) conversation encryptData: (NSData *) data {
    
    return data ? [self.storageCipher encryptData: data] : nil;
    
} // -conversation:encryptData:


- (NSData *) conversation: (Conversation *) conversation decryptData: (NSData *) data {
    
    return data ? [self.storageCipher decryptData: data] : nil;
    
} // -conversation:decryptData:


- (NSData *) conversation: (Conversation *) conversation encryptedDataFromString: (NSString *) string {
    
    return string ? [self.storageCipher encryptedDataFromString: string] : nil;
    
} // -conversation:encryptedDataFromString:


- (NSString *) conversation: (Conversation *) conversation stringFromEncryptedData: (NSData *)   data {
    
    return data ? [self.storageCipher stringFromEncryptedData: data] : nil;
    
} // -conversation:stringFromEncryptedData:

- (void) conversation: (Conversation *) conversation deleteAllData:localJID remoteJID:(NSString *)remoteJID
{
    
    [self deleteState:[XMPPJID jidWithString:localJID]
            remoteJid:[XMPPJID jidWithString:remoteJID]];
    
}

#pragma mark - XMPPSilentCircleStorage methods.


- (NSData *) stateKeyForLocalJid: (XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid {
    
    return [[self conversationForLocalJid: myJid remoteJid: theirJid] scimpKey];
    
} // -stateKeyForLocalJid:remoteJid:


#pragma mark - SCIMP State Instance methods.


- (SCimpSavedState *) makesScimpStateForLocalJid: (XMPPJID *) myJid
                                     remoteJid: (XMPPJID *) theirJid
                        inManagedObjectContext: (NSManagedObjectContext *) moc {
    
    SCimpSavedState *savedState = nil;
    
    savedState = [NSEntityDescription insertNewObjectForEntityForName: kSCimpSavedStateEntity
                                                                inManagedObjectContext: moc];
    savedState.localJID =  myJid.full;
    savedState.remoteJID = theirJid.full;
    savedState.state = NULL;
    
    [moc save];
    
//    DDGDesc(savedState);
    
    return savedState;
    
} // -makesScimpStateForLocalJid:remoteJid:inManagedObjectContext:


- (SCimpSavedState *) scimpStateForLocalJid: (XMPPJID *) myJid
                                 remoteJid: (XMPPJID *) theirJid
                    inManagedObjectContext: (NSManagedObjectContext *) moc {
    
    myJid = [XMPPJID jidWithString: myJid.bare]; // We only use the bare local JID.
    
    BOOL hasResource = theirJid.resource?YES:NO;
    SCimpSavedState *savedState = NULL;
      
    NSArray *allStates = [moc fetchObjectsForEntity: kSCimpSavedStateEntity];
    
    NSPredicate *findBareMatchingJid = [NSPredicate predicateWithBlock: ^BOOL(id obj, NSDictionary *bind)
                                        {
                                            Conversation *con = (Conversation*) obj;
                                            
                                            XMPPJID* remoteJID = [XMPPJID jidWithString:con.remoteJID];
                                            BOOL foundJid  = ([con.localJID isEqualToString:myJid.bare]
                                                              && [ [remoteJID bare] isEqualToString:theirJid.bare]);
                                            
                                            return foundJid;
                                        }];
    
    NSArray *savedStates =  [allStates filteredArrayUsingPredicate:findBareMatchingJid];
    
    if([savedStates count] == 0)
    {
        savedState = [self makesScimpStateForLocalJid: myJid remoteJid: theirJid inManagedObjectContext: moc];
    }
    else
    {
        for (savedState in savedStates)
        {
            XMPPJID* remoteJID = [XMPPJID jidWithString:savedState.remoteJID];
            
            if(!hasResource ) break;  // take first one;
            
            else
            {
                if([remoteJID resource])
                {
                    if( [remoteJID isEqualToJID:theirJid options: XMPPJIDCompareFull]) break;
                    
                }
                else
                {
                    savedState.remoteJID = theirJid.full;
                    [moc save];
                    break;
                    
                }
                
            }
        }
    }
    
    if(!savedState)
        savedState = [self makesScimpStateForLocalJid: myJid remoteJid: theirJid inManagedObjectContext: moc];
    
     return savedState;
    
} // -scimpStateForLocalJid:remoteJid:inManagedObjectContext:


- (SCimpSavedState *) scimpStateForLocalJid: (XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid {
    
    NSManagedObjectContext *moc = App.sharedApp.moc;
    
    moc = NSThread.isMainThread ? moc : [moc makeConfinedChildMOC];
    
    SCimpSavedState *savedState = nil;
    
    savedState = [self scimpStateForLocalJid: myJid remoteJid: theirJid inManagedObjectContext: moc];
    
    return savedState;
    
} // -scimpStateForLocalJid:


- (void) deleteState:  (XMPPJID *) myJid
           remoteJid: (XMPPJID *) theirJid
inManagedObjectContext: (NSManagedObjectContext *) moc {
  
    myJid = [XMPPJID jidWithString: myJid.bare]; // We only use the bare local JID.
        
    NSArray *allStates = [moc fetchObjectsForEntity: kSCimpSavedStateEntity];
    
    NSPredicate *findBareMatchingJid = [NSPredicate predicateWithBlock: ^BOOL(id obj, NSDictionary *bind)
                                        {
                                            Conversation *con = (Conversation*) obj;
                                            
                                            XMPPJID* remoteJID = [XMPPJID jidWithString:con.remoteJID];
                                            BOOL foundJid  = ([con.localJID isEqualToString:myJid.bare]
                                                              && [ [remoteJID bare] isEqualToString:theirJid.bare]);
                                            
                                            return foundJid;
                                        }];
    
    NSArray *deleteThese =  [allStates filteredArrayUsingPredicate:findBareMatchingJid];
     
    for (SCimpSavedState *item in deleteThese) {
        [moc deleteObject: item];
    }
}


- (void) deleteState:  (XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid {
    
    NSManagedObjectContext *moc = App.sharedApp.moc;
    
    moc = NSThread.isMainThread ? moc : [moc makeConfinedChildMOC];
    
    [self deleteState: myJid remoteJid:theirJid inManagedObjectContext: moc];
       
} // -deleteState:forLocalJid:remoteJid:



- (void) saveState: (NSData *) state forLocalJid: (XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid {
    
    Conversation *conversation = [self conversationForLocalJid: myJid remoteJid: theirJid];
    
    SCimpSavedState *savedState = [self scimpStateForLocalJid: myJid
                                                        remoteJid: theirJid
                                           inManagedObjectContext: conversation.managedObjectContext];
    savedState.remoteJID = theirJid.full;
    savedState.state = state;
    
    [savedState.managedObjectContext save];
    

} // -saveState:forLocalJid:remoteJid:


- (NSData *) restoreStateForLocalJid: (XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid {
    
    
 	SCimpSavedState *savedState = [self scimpStateForLocalJid: myJid
                                                    remoteJid: theirJid ];
    
    NSData* state = savedState.state;
 
    return state;
    
//    return [[self conversationForLocalJid: myJid remoteJid: theirJid] scimpState];

} // -restoreStateForLocalJid:remoteJid:


#pragma mark - XMPPStreamDelegate methods.

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
 
}



- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
    DDGTrace();
    DDGDesc(settings);
    
#if VALIDATE_XMPP_CERT
    
    [settings removeAllObjects];
    
    
#endif
}


- (void)xmppStreamDidSecureWithCertificate:(XMPPStream *)sender  certificateData:(NSData *)serverCertificateData
{
    DDGTrace();
     
#if VALIDATE_XMPP_CERT
    App *app = App.sharedApp;
 
    NSData* xmppCert = app.xmppCert;
    
    uint8_t hash[CC_SHA1_DIGEST_LENGTH];
    uint8_t  xmppCertHash   [CC_SHA1_DIGEST_LENGTH];

    CC_SHA1([xmppCert bytes], [xmppCert length], xmppCertHash);
    CC_SHA1([serverCertificateData bytes], [serverCertificateData length], hash);
    
    if(!CMP(hash,xmppCertHash, CC_SHA1_DIGEST_LENGTH))
    {
        [app.xmppServer disconnect ];
      
        UIAlertView *alertView = nil;
        
        alertView = [[UIAlertView alloc] initWithTitle: NSLS_COMMON_CONNECT_FAILED
                                               message: NSLS_COMMON_CERT_FAILED
                                              delegate: self
                                     cancelButtonTitle: NSLS_COMMON_OK
                                     otherButtonTitles: nil];
        [alertView show];

    }
    
#endif
    
}


- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
    
}

- (void) xmppStreamDidAuthenticate: (XMPPStream *) sender {
    
    DDGTrace();
   
    App *app = App.sharedApp;

     if(app.pushToken)
        [self sendRegisterPushToken : app.pushToken ];
   
    // we are not using server time at the moment,  so do do this.
  //  [self sendTimeRequest];
                               
//    NSError *error = nil;
//    
//    if (![self.frc performFetch: &error]) {
//        
//        DDGLog(@"Error performing fetch: %@", error);
//    }
//    [self.tableView reloadData];
    
} // -xmppStreamDidAuthenticate:


- (void) xmppStream: (XMPPStream *) sender didNotAuthenticate: (NSXMLElement *) error {
    
    DDGTrace();
    
} // -xmppStream:didNotAuthenticate:


- (XMPPIQ *) xmppStream: (XMPPStream *) sender willReceiveIQ: (XMPPIQ *) iq {
    
//    DDGDesc(iq.compactXMLString);

    return iq;
    
} // -xmppStream:willReceiveIQ:


- (XMPPMessage *) xmppStream: (XMPPStream *) sender willReceiveMessage: (XMPPMessage *) message {
    
//    DDGDesc(message.compactXMLString);
    
    return message;
    
} // -xmppStream:willReceiveMessage:


- (XMPPPresence *) xmppStream: (XMPPStream *) sender willReceivePresence: (XMPPPresence *) presence {
    
//    DDGDesc(presence.compactXMLString);
    
    return presence;
    
} // -xmppStream:willReceivePresence:


- (BOOL) xmppStream: (XMPPStream *) sender didReceiveIQ:(XMPPIQ *) iq {
    
    DDGDesc(iq.compactXMLString);
    
    
    NSString* iqID = [[iq attributeForName: kXMPPID] stringValue];
    
    if((iqID && self.pushIQid) && [iqID isEqualToString: self.pushIQid])
    {
        
        NSString* status =  [iq attributeStringValueForName:@"type"] ;
        
        if(status)
        {
            if([status isEqualToString: @"result"])
            {
//                NSLog(@"push Token accepted");
                
            }
            else if([status isEqualToString: @"error"] )
            {
 //               NSLog(@"push Token rejected");
                
            }
        }
        DDGDesc(iq);
         
    }else if((iqID && self.timeIQid) && [iqID isEqualToString: self.timeIQid])
    {
        
        NSString* status =  [iq attributeStringValueForName:@"type"] ;

        if(status)
        {
            if([status isEqualToString: @"result"])
            {
                NSXMLElement *timeElement = [iq elementForName:@"time" xmlns:XMLNS_XMPP_TIME];
                NSXMLElement *utc = [timeElement elementForName:@"utc"];
                
                NSDate *serverTime =[XMPPDateTimeProfiles parseDateTime: [utc stringValue]];
                NSTimeInterval serverTimeOffset = [serverTime timeIntervalSinceNow];
                
                DDGLog(@"serverTimeOffset = %f", serverTimeOffset);
                
                App.sharedApp.serverTimeOffset = serverTimeOffset;
            }
        }
        DDGDesc(iq);
        
    }
    
    
    
    return NO;
    
} // -xmppStream:didReceiveIQ:


- (void) xmppStream: (XMPPStream *) sender didReceiveMessage: (XMPPMessage *) xmppMessage {
    
    DDGDesc(xmppMessage.compactXMLString);
    
    if (xmppMessage.isChatMessageWithSiren || xmppMessage.isChatMessageWithBody) { // We may remove the body check later.
        
        Siren *siren = [Siren sirenWithChatMessage: xmppMessage];
        
        Conversation *conversation  = [self conversationForLocalJid: siren.to 
                                                          remoteJid: siren.from];
        NSManagedObjectContext *moc = conversation.managedObjectContext;
        
        /* Handle ping message */
        if(siren.ping)
        {
            if([siren.ping isEqualToString: kPingRequest])
            {
                Siren *siren1 = Siren.new;
                
                siren1.ping =  kPingResponse;
                siren1.conversationID = siren.conversationID;
                
                XMPPMessage *xmppRepyMessage = [siren1 chatMessageToJID: siren.from];
                
                [sender sendElement: xmppRepyMessage];
                return;
         }
            if([siren.ping isEqualToString: kPingResponse])
            {
               /* ignore the reply for now..  */
                return;
            }
        }
        else if(siren.requestResend)
        {
        /* handle a resend request - the other side could not decode this message */
            
            NSPredicate *p = [NSPredicate predicateWithFormat: @"%K == %@", kScppID, siren.requestResend];
            NSArray *missives = [moc fetchObjectsForEntity: kMissiveEntity predicate: p];
            
            if([missives count] > 0)
            {
                 for (Missive *missive in missives)
                {
                    BitSet(missive.flags,kMissiveFLag_RequestResend);
                        
//                   [missive.managedObjectContext refreshObject:missive mergeChanges:YES];
//                   [missive.managedObjectContext save];
                    
                    Conversation *con1  = missive.conversation;
                    con1.attentionFlag = YES;
                    [moc save];
                    break;
                }
             }
            return;
        }
        else if(siren.requestBurn)
        {
            /* handle a burn request - the other side redacted it */
              
            NSPredicate *p = [NSPredicate predicateWithFormat: @"%K == %@", kScppID, siren.requestBurn];
            NSArray *missives = [moc fetchObjectsForEntity: kMissiveEntity predicate: p];
            
            if([missives count] > 0)
            {
                [multicastDelegate conversationmanager:self didReceiveSirenFrom:xmppMessage.from siren:siren];
                
                for (Missive *missive in missives)
                {
                    Conversation *con1  = missive.conversation;
                  
                    XMPPJID* remoteJID = [XMPPJID jidWithString:con1.remoteJID];
                    
                    [self deleteMissiveFromConversation: App.sharedApp.currentJID
                                              remoteJid: remoteJID
                                                missive:missive];
                    break;
                }
            }
            return;
        }

        else
        {
            /* Normal message recieved */
            Missive *missive = [Missive insertMissiveForXMPPMessage: xmppMessage 
                                             inManagedObjectContext: moc 
                                                      withEncryptor: conversation.encryptor];
            conversation.date = missive.date;
            if (![conversation.scppID isEqualToString: siren.conversationID]) { conversation.scppID = siren.conversationID; }
            
            missive.conversation = conversation;
            conversation.notRead = conversation.notRead + 1;
            
            if(siren.shredAfter )
                conversation.unseenBurnFlag = YES;
 
            missive.flags = 0;
            
            conversation.conversationState =  kConversationState_Run;
            [moc save];
             
            [multicastDelegate conversationmanager:self didReceiveSirenFrom:xmppMessage.from siren:siren];
            
            [App.sharedApp.soundManager playMessageInSound];
         }
    }
        
} // -xmppStream:didReceiveMessage:


- (void) xmppStream: (XMPPStream *) sender didReceivePresence: (XMPPPresence *) presence {
    
//    DDGDesc(presence.compactXMLString);
//     DDGDesc(presence.fromStr);
//    
//    XMPPJID *from = presence.from;
//    
//    if ([sender.myJID.bare isEqualToString: from.bare]) { // if from ourself...
//        
//        // Set the title to the right name.
//        XMPPUserCoreDataStorageObject *user = [self userForJID: from];
//        
//        NSString *name = user.displayName;
//        name = name && ![name isEqualToString: kEmptyString] ? name : from.user;
//        
//        DDGDesc(user);
//        
//        self.navigationItem.title = name;
//    }
    
} // -xmppStream:didReceivePresence:


- (void) xmppStream: (XMPPStream *) sender didReceiveError: (NSXMLElement *) error {
    
//    DDGTrace();
    
} // -xmppStream:didReceiveError:


- (XMPPIQ *) xmppStream: (XMPPStream *) sender willSendIQ: (XMPPIQ *) iq {
    
//    DDGDesc(iq.compactXMLString);
//    
//    if (iq.isSetIQ) {
//        
//        NSXMLElement *bind = iq.childElement;
//        
//        if ([bind.name isEqualToString: @"bind"]) {
//            
//            for (NSXMLElement *child in bind.children) {
//                
//                [child detach];
//            }
//            NSXMLElement * resource = [NSXMLElement.alloc initWithName: kXMPPResource stringValue: sender.myJID.resource];
//            
//            [bind addChild: resource];
//            
//            DDGDesc(bind.compactXMLString);
//        }
//    }
    return iq;
    
} // -xmppStream:willSendIQ:


- (XMPPMessage *) xmppStream: (XMPPStream *) sender willSendMessage: (XMPPMessage *) message {
    
    DDGDesc(message.compactXMLString);
    
    return message;
    
} // -xmppStream:willSendMessage:


- (XMPPPresence *) xmppStream: (XMPPStream *) sender willSendPresence: (XMPPPresence *) presence {
    
//    DDGDesc(presence.compactXMLString);
    
    return presence;
    
} // -xmppStream:willSendPresence:


- (void) xmppStream: (XMPPStream *) sender didSendIQ: (XMPPIQ *) iq {
    
//    DDGDesc(iq.compactXMLString);
    
} // -xmppStream:didSendIQ:


- (void) xmppStream: (XMPPStream *) sender didSendMessage: (XMPPMessage *) xmppMessage {
    
    DDGDesc(xmppMessage.compactXMLString);
    
    NSString* messageID = [[xmppMessage attributeForName: kXMPPID] stringValue];
    
    if(messageID)
    {
        NSPredicate *p = [NSPredicate predicateWithFormat: @"%K == %@", kScppID, messageID];
        NSArray *missives = [App.sharedApp.moc fetchObjectsForEntity: kMissiveEntity predicate: p];
        
        if([missives count] > 0)
        {
            for (Missive *missive in missives)
            {
               DDGDesc(missive); 
                BitSet(missive.flags, kMissiveFLag_Sent);
                 [missive.managedObjectContext refreshObject:missive mergeChanges:YES];

                Conversation *con1  = missive.conversation;
                con1.conversationState = kConversationState_Run;
                
                [App.sharedApp.soundManager playMessageOutSound];

                break;
            }
        }
    }
    
} // -xmppStream:didSendMessage:


- (void) xmppStream: (XMPPStream *) sender didSendPresence: (XMPPPresence *) presence {
    
//    DDGDesc(presence.compactXMLString);
    
} // -xmppStream:didSendPresence:

#pragma mark - Push notification  .

- (void) sendTimeRequest
{
    
    App *app = App.sharedApp;
    XMPPStream * xmppStream = app.xmppServer.xmppStream;
    
//    <iq
//    type='get'
//    from='efine@silentcircle.org/edwin'
//    to='silentcircle.org'
//    id='time_1'>
//    <time xmlns='urn:xmpp:time'/>
//    </iq>
     
    self.timeIQid = [XMPPStream generateUUID];
    
    XMPPJID* serverJid = [XMPPJID jidWithString: app.currentAccount.accountDomain];

    NSXMLElement *query = [NSXMLElement elementWithName:@"time" xmlns:XMLNS_XMPP_TIME];
    
     XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:serverJid elementID:self.timeIQid child:query];
    
    DDGDesc(iq);
    
	[xmppStream sendElement:iq];


}
- (void)sendRegisterPushToken: (NSString *)token
{

    App *app = App.sharedApp;
    XMPPStream * xmppStream = app.xmppServer.xmppStream;

 //   <iq id='0903C434-C1A6-4649-AEC8-8AE06D77408B' to='silentcircle.com' type='set'>
 //   <push action='register'
 //   xmlns='http://silentcircle.com/protocol/push/apns'>
 //   <identity
 //   app_id='com.silentcircle.SilentText'
 //   token='325e0015046b7d25d10888e503d3248be84b9e1de4ecadda9f0a16dbfc3f6b74' />
 //   </push>
 //   </iq>
 
    self.pushIQid = [XMPPStream generateUUID];
  
    NSString* appID = app.identifier;
    XMPPJID* serverJid = [XMPPJID jidWithString: app.currentAccount.accountDomain];
      	
    NSXMLElement *push = [NSXMLElement elementWithName:@"push" xmlns:@"http://silentcircle.com/protocol/push/apns"];
    [push addAttributeWithName: @"action" stringValue: @"register"];
     
    NSXMLElement *identity = [NSXMLElement elementWithName:@"identity"];
	[identity addAttributeWithName:@"app_id" stringValue:appID];
	[identity addAttributeWithName:@"token" stringValue:token];
 //  	[identity addAttributeWithName:@"dist" stringValue:@"dev"];
    
     [push addChild:identity];

    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serverJid elementID:self.pushIQid child:push];
    
    DDGDesc(iq);
    
	[xmppStream sendElement:iq];
}


#pragma mark - context Info.

-(NSDictionary*)secureContextInfoForJid: (XMPPJID *) remoteJID
{
    App *app = App.sharedApp;
    XMPPSilentCircle * xmppSilentCircle = app.xmppSilentCircle;
    
    NSDictionary* info = [xmppSilentCircle secureContextInfoForJid: remoteJID] ;
    
	return info;
}

#pragma mark - reKey.


-(void)sendReKeyToRemoteJID: (XMPPJID *) remoteJID
{
    App *app = App.sharedApp;
    XMPPSilentCircle * xmppSilentCircle = app.xmppSilentCircle;
   
    [xmppSilentCircle rekeySecureContextForJid: remoteJID];
 }

#pragma mark - remote commands

-(void)sendPingSirenMessageToRemoteJID: (XMPPJID *) remoteJID
{
    App *app = App.sharedApp;
    XMPPStream * xmppStream = app.xmppServer.xmppStream;
    Conversation *conversation = [self conversationForLocalJid: app.currentJID remoteJid: remoteJID];
    
    Siren *siren = Siren.new;

    siren.ping =  kPingRequest;
    if(conversation)
    {
        siren.conversationID = conversation.scppID;
    }
    
    XMPPMessage *xmppMessage = [siren chatMessageToJID: remoteJID];

    [xmppStream sendElement: xmppMessage];
}


-(void)sendRequestResendMessageToRemoteJID: (XMPPJID *) remoteJID forMessage:(NSString*) messageID
{
    App *app = App.sharedApp;
    XMPPStream * xmppStream = app.xmppServer.xmppStream;
    Conversation *conversation = [self conversationForLocalJid: app.currentJID remoteJid: remoteJID];
    
    Siren *siren = Siren.new;
    
    siren.requestResend =  messageID;
    if(conversation)
    {
        siren.conversationID = conversation.scppID;
    }
    
    XMPPMessage *xmppMessage = [siren chatMessageToJID: remoteJID];
    
    [xmppStream sendElement: xmppMessage];
}


-(void)sendRequestBurnMessageToRemoteJID: (XMPPJID *) remoteJID forMessage:(NSString*) messageID
{
    App *app = App.sharedApp;
    XMPPStream * xmppStream = app.xmppServer.xmppStream;
    Conversation *conversation = [self conversationForLocalJid: app.currentJID remoteJid: remoteJID];
    
    Siren *siren = Siren.new;
    
    siren.requestBurn =  messageID;
    if(conversation)
    {
        siren.conversationID = conversation.scppID;
    }
    
    XMPPMessage *xmppMessage = [siren chatMessageToJID: remoteJID];
    
    [xmppStream sendElement: xmppMessage];
}


#pragma mark - Debugging UI.



- (UIAlertView *) presentAlertForSecretMismatch: (NSString *) SAS remoteJid:(XMPPJID*)remoteJid
{
    
    NSString *name = [remoteJid addressBookName];
    name = name && ![name isEqualToString: kEmptyString] ? name : remoteJid.user;
     
    NSString *title = [NSString stringWithFormat: NSLS_COMMON_SAS_REQUEST];
    
    NSString *messageStr = [NSString stringWithFormat: 
                            NSLS_COMMON_SAS_REQUEST_DETAIL, name, SAS];
    UIAlertView *alertView = nil;
    
    alertView = [[UIAlertView alloc] initWithTitle: title
                                           message: messageStr
                                          delegate: self
                                 cancelButtonTitle: kNoButton 
                                 otherButtonTitles: kYesButton, nil];
    [alertView show];
    
    return alertView;
    
} // -presentAlertForSecretMismatch:


#pragma mark - XMPPSilentCircleDelegate methods.


- (void) xmppSilentCircle: (XMPPSilentCircle *) sender willEstablishSecureContext: (XMPPJID *) remoteJid {
    
    DDGTrace();
    
} // -xmppSilentCircle:willEstablishSecureContext:


- (SCimpLogEntry *) insertSCimpLogEntryForRemoteJID: (XMPPJID *) remoteJID withInfo: (NSDictionary *) info {
    
    Conversation *conversation = [self conversationForLocalJid: App.sharedApp.currentJID remoteJid: remoteJID];
    
    SCimpLogEntry *scimpLogEntry = [NSEntityDescription insertNewObjectForEntityForName: kSCimpLogEntryEntity 
                                                                 inManagedObjectContext: conversation.managedObjectContext];
    
    
    scimpLogEntry.date = NSDate.date; // [NSDate.date dateByAddingTimeInterval:App.sharedApp.serverTimeOffset ];
    scimpLogEntry.info = info;
    scimpLogEntry.conversation = conversation;
    [scimpLogEntry.managedObjectContext save];
    
    conversation.date       = NSDate.date;
    [conversation.managedObjectContext save];
    
    return scimpLogEntry;
    
} // -insertSCimpLogEntryForRemoteJID:withInfo:


- (void) xmppSilentCircle: (XMPPSilentCircle *) sender didEstablishSecureContext: (XMPPJID *) remoteJid {
    
    DDGTrace();
    
    // As this is a multi-threaded, multi-observer delegate method, info should be passed as an immutable parameter.
    NSMutableDictionary* info = [[sender secureContextInfoForJid: remoteJid] mutableCopy];
    
    if (info) {
  
        [info setValue:kSCimpLogEntrySecure forKey:kSCimpLogEntryType];
        
        [self insertSCimpLogEntryForRemoteJID: remoteJid withInfo: info];

        NSNumber *number = nil;
        NSString *string = nil;
        
        SCimpCipherSuite    cipherSuite = kSCimpCipherSuite_Invalid;
        SCimpSAS            sasMethod   = kSCimpSAS_Invalid;
        uint8_t             scimpVersion = 0;
        bool secretsMatch = NO;
        bool hasSharedSecrets = NO;
        
        
        if ((number = [info valueForKey:kSCIMPInfoHasCS])) {
            hasSharedSecrets = number.boolValue;
        }
        if ((number = [info valueForKey:kSCIMPInfoCSMatch])) {
            secretsMatch = number.boolValue;
        }
        if ((number = [info valueForKey:kSCIMPInfoCipherSuite])) {
            cipherSuite = number.unsignedIntValue;
        }
        if ((number = [info valueForKey:kSCIMPInfoSASMethod])) {
            sasMethod = number.unsignedIntValue;
        }
        if ((number = [info valueForKey:kSCIMPInfoVersion])) {
            scimpVersion = number.unsignedIntValue;
        }
     
        Conversation *conversation = [self conversationForLocalJid: App.sharedApp.currentJID remoteJid: remoteJid];
        
        if(! ( hasSharedSecrets && secretsMatch))
        {
            conversation.keyVerifiedFlag = NO;
        }
        
        conversation.keyedFlag = YES;
        [conversation.managedObjectContext save];
         
        if (!hasSharedSecrets ) {
            // always accept when we have no shared secret
            [sender acceptSharedSecretForJid: remoteJid ];
        }
        
        /*
         if we find that the cached shared secret doesnt match what the other side thinks it is.
         we should then inform the user that they should verify the Short Authentication String (SAS) with the other user,
         this could be in the form of 4 nato words, 5 hex characters or 4 letters. it depends on who initiated the call.  
         */
        
        else if(hasSharedSecrets && !secretsMatch)
        {
            string = [info valueForKey:kSCIMPInfoSAS];
            
#warning VINNIE always accept SAS
//            [self presentAlertForSecretMismatch:string remoteJid:remoteJid];
            
            // this needs to be set by the alert clicked
            [sender acceptSharedSecretForJid: remoteJid];
        }
         
        [multicastDelegate conversationmanager:self didChangeState:remoteJid newState:kConversationState_Keyed];
 
    }
    
} // -xmppSilentCircle:didEstablishSecureContext


- (SCimpLogEntry *) insertSCimpLogEntryForRemoteJID: (XMPPJID *) remoteJID 
                                           withInfo: (NSDictionary *) info 
                                            message: (XMPPMessage *) message 
                                              error: (SCLError) error {
    
    Conversation *conversation = [self conversationForLocalJid: App.sharedApp.currentJID remoteJid: remoteJID];
    
    SCimpLogEntry *scimpLogEntry = [NSEntityDescription insertNewObjectForEntityForName: kSCimpLogEntryEntity 
                                                                 inManagedObjectContext: conversation.managedObjectContext];
    scimpLogEntry.date = NSDate.date; // [NSDate.date dateByAddingTimeInterval:App.sharedApp.serverTimeOffset ];
    scimpLogEntry.info = info;
    scimpLogEntry.xmppMessage = message?message.compactXMLString:nil;
    scimpLogEntry.error = error;
    scimpLogEntry.conversation = conversation;
    
    [scimpLogEntry.managedObjectContext save];
    
    conversation.date       = NSDate.date;
    [conversation.managedObjectContext save];

    
    return scimpLogEntry;
    
} // -insertSCimpLogEntryForRemoteJID:withInfo:message:error:


- (void) xmppSilentCircle: (XMPPSilentCircle *) sender protocolWarning:(XMPPJID *)remoteJid withMessage:(XMPPMessage *)message error:(SCLError)error {
    
    // As this is a multi-threaded, multi-observer delegate method, info should be passed as an immutable parameter.
    NSMutableDictionary* info = [[NSMutableDictionary alloc]init];
    
    [info setValue:kSCimpLogEntryWarning forKey:kSCimpLogEntryType];

    SCimpLogEntry *logEntry = [self insertSCimpLogEntryForRemoteJID: remoteJid
                                                           withInfo: info 
                                                            message: message 
                                                              error: error];
    
    DDGLog(@"SC ProtocolWarning %d: %@", logEntry.error, logEntry.errorString);
    
} // -xmppSilentCircle:protocolWarning:error:


- (void) xmppSilentCircle: (XMPPSilentCircle *) sender protocolError: (XMPPJID *) remoteJid withMessage:(XMPPMessage *)message error: (SCLError) error {
    
      // be careful to check message for NULL cases
     
    if(error == kSCLError_KeyNotFound && message)
    {
        NSString* messageID = [[message attributeForName: kXMPPID] stringValue];
        // check message for id,  we could not decrypt this one and might offer a resend request
        
        DDGLog(@"COULD NOT DECRYPT MESSAGE ID %@:  ", messageID);
        
        // we will rekey here and reply with a resend request
        
        [sender rekeySecureContextForJid: remoteJid];
        
        [self sendRequestResendMessageToRemoteJID:remoteJid forMessage:messageID];
    }
    
    else
    {
        // As this is a multi-threaded, multi-observer delegate method, info should be passed as an immutable parameter.
        NSMutableDictionary* info = [[sender secureContextInfoForJid: remoteJid] mutableCopy];
        
        [info setValue:kSCimpLogEntryError forKey:kSCimpLogEntryType];

        SCimpLogEntry *logEntry = [self insertSCimpLogEntryForRemoteJID: remoteJid
                                                               withInfo: info
                                                                message: message
                                                                  error: error];
        
        DDGLog(@"SC ProtocolError %d: %@", logEntry.error, logEntry.errorString);
        
      
        [XMPPSilentCircle  removeSecureContextForJid: remoteJid];
        [App.sharedApp.conversationManager resetScimpState:App.sharedApp.currentJID remoteJid:remoteJid];

    }
    
    
    
} // -xmppSilentCircle:protocolError:error:

 
- (void)xmppSilentCircle:(XMPPSilentCircle *)sender protocolDidChangeState:(XMPPJID *)remoteJID state:(SCimpState)state
{
    
    Conversation *conversation = [self conversationForLocalJid: App.sharedApp.currentJID remoteJid: remoteJID];
  
    ConversationState s = kConversationState_Init;
    
    switch(state)
    {
        default:;
        case kSCimpState_Init:      s = kConversationState_Init; break;
        case kSCimpState_Ready:     s = kConversationState_Ready; break;
        case kSCimpState_Commit:    s = kConversationState_Commit; break;
        case kSCimpState_DH2:       s = kConversationState_DH2; break;
        case kSCimpState_DH1:       s = kConversationState_DH1; break;
        case kSCimpState_Confirm:   s = kConversationState_Confirm; break;
        case kSCimpState_Error:     s = kConversationState_Error; break;
     }
    
    if(s != kConversationState_Ready && conversation.keyedFlag)
    {
        conversation.keyedFlag = NO;
        [conversation.managedObjectContext save];
    }
    
    [conversation setConversationState:s];
    [multicastDelegate conversationmanager:self didChangeState:remoteJID newState:s];

    if(s == kConversationState_Ready) return;
    
    NSMutableDictionary*  infoDict = [NSMutableDictionary dictionaryWithCapacity: 2];
    
    [infoDict setValue:kSCimpLogEntryTransition forKey:kSCimpLogEntryType];
    [infoDict setValue:[NSNumber numberWithInteger:s] forKey:kSCIMPInfoTransition];
   
    [self insertSCimpLogEntryForRemoteJID: remoteJID
                                 withInfo: infoDict
                                  message: nil
                                    error: kSCLError_NoErr];
 
        
    
 }
#pragma mark - registerNotifications methods


 
#define kMOCDidSave  (@selector(mocDidSave:))
- (void) mocDidSave: (NSNotification *) notification {
    
//    DDGTrace();
    
    NSMutableSet *all = NSMutableSet.set;
    
    NSSet *objects = [notification.userInfo valueForKey: NSInsertedObjectsKey];
    
    if (objects) { [all unionSet: objects]; }
    
    objects = [notification.userInfo valueForKey: NSUpdatedObjectsKey];
    
    if (objects) { [all unionSet: objects]; }
  
    objects = [notification.userInfo valueForKey: NSDeletedObjectsKey];
    
    if (objects) { [all unionSet: objects]; }

    for (Conversation *conversation in all) {
        
        // If any conversation is added or deleted, remove the list.
        if ([conversation isKindOfClass: Conversation.class]) {
            
            self.conversations = nil;
            
            return;
        }
    }
    
} // -mocDidSave:


- (void) registerForNotifications {
    
    DDGTrace();
    
    NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
    
 	[dnc removeObserver: self];
    
    [dnc addObserver: self 
            selector: kMOCDidSave 
                name: kMOCDidSaveNotification
              object: App.sharedApp.moc];
    
 } // -registerForNotifications



@end
