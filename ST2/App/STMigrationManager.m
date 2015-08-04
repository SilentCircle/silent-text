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
//  STMigrationManager.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 3/26/14.
//

#import "STLogging.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "SCAccountsWebAPIManager.h"
#import "NSDate+SCDate.h"
#import "NSData+SCUtilities.h"
#import "STUserManager.h"
#import "AddressBookManager.h"
#import "STUser.h"
#import "STNotification.h"
#import "STMigrationManager.h"
#import "Siren.h"
#import "STConversation.h"
#import "STMessage.h"
#import "SilentTextStrings.h"
#import "OHAlertView.h"
#import "MessageStream.h"
#import <libkern/OSAtomic.h>
#import "STImage.h"
#import "STSCloud.h"

// Log levels: off, error, warn, info, verbose

#if DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@implementation STMigrationManager
{
    YapDatabaseConnection *databaseConnection;
}


static STMigrationManager *sharedInstance;

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		sharedInstance = [[STMigrationManager alloc] init];
        [sharedInstance commonInit];
  	}
}

+ (STMigrationManager *)sharedInstance
{
	return sharedInstance;
}

-(void)commonInit
{
    
    
    databaseConnection = [STDatabaseManager.database newConnection];
    databaseConnection.objectCacheLimit = 20;
    databaseConnection.metadataCacheEnabled = NO;
    databaseConnection.name = @"STMigrationManager";
    
}


- (void)migrateData:(NSDictionary *)mInfo
    completionBlock:(STMigrationManagerCompletionBlock)completion
{
    
    NSString *str_appVersion = [mInfo objectForKey:@"appVersion"];
    NSString *str_apikey = [mInfo objectForKey:@"api_key"];
    NSString *str_deviceID = [mInfo objectForKey:@"device_id"];
    NSString *str_jid = [mInfo objectForKey:@"jid"];
    NSString *str_xmpppassword = [mInfo objectForKey:@"password"];
    
    NSDictionary* allCons = [mInfo objectForKey:@"conversations"];
    
    DDLogOrange(@"version: %@  ", str_appVersion);
    DDLogOrange(@"apiKey: %@  ", str_apikey);
    DDLogOrange(@"deviceID: %@  ", str_deviceID);
    DDLogOrange(@"jid: %@  ", str_jid);
    DDLogOrange(@"passwd: %@  ", str_xmpppassword);
    
    [[STUserManager sharedInstance] activateDevice: str_deviceID
                                            apiKey: str_apikey
                                         networkID: kNetworkChoiceKeyProduction
                                   completionBlock:^(NSError *error, NSString *newUUID) {
                                       
                                       if(error)
                                       {
                                           if(completion)
                                               (completion)(error);
                                           
                                        }
                                       else
                                       {
                                           [self migrateConversations:allCons
                                                            forUserID:newUUID
                                                      completionBlock:completion];
                                           
                                       }
                                   }];
    
}


- (void)migrateConversations:(NSDictionary *)conDict
                   forUserID:(NSString*) userID
             completionBlock:(STMigrationManagerCompletionBlock)completion
{
    
	__block NSError *error = nil;
    
    [databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
		STUser *user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
		MessageStream *ms = [STAppDelegate messageStreamForUser:user];

        [conDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            
            NSDictionary* conInfo = obj;
            XMPPJID* remoteJID = [XMPPJID jidWithString:[conInfo objectForKey:@"remoteJID"]];
            NSString* remote = remoteJID.bare;
            NSString* local = user.jid;
            
            // create the conversations using new conversation ID
            NSString* conversationId = [ms conversationIDForRemoteJid:remoteJID.bareJID
                                                             localJid:[XMPPJID jidWithString:user.jid]];
            
            
            STConversation* conversation = [[STConversation alloc] initWithUUID:conversationId
                                                                         userId:userID
                                                                      remoteJid:remoteJID.bare
                                                                       localJid:user.jid  ];
            
            uint32_t shredAfter = [[conInfo objectForKey:@"shredAfter"] unsignedShortValue];
            BOOL tracking =[[conInfo objectForKey:@"tracking"] boolValue];
            
            conversation.shredAfter = shredAfter;
            conversation.shouldBurn = shredAfter == kShredAfterNever?NO:YES;
            
            conversation.trackUntil  =  tracking? [NSDate distantFuture]:  [NSDate distantPast];
            
            [transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:conversation.userId];
            
            // walk all the messsages and import those
            NSDictionary* messages = [conInfo objectForKey:@"messages"];
            
            [messages enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                
                NSString* messageID = key;
                NSDictionary* msgInfo = obj;
                
                NSString* recipient = [msgInfo objectForKey:@"to"];
                NSRange range = [recipient rangeOfString:@"/"];
                if (range.location != NSNotFound)
                    recipient = [recipient substringToIndex:range.location];
                
                NSDate* msgDate = [NSDate dateFromRfc3339String:[msgInfo objectForKey:@"date"]];
                NSDate* shredDate = NULL;
                
                BOOL needsReSend =[[msgInfo objectForKey:@"needsReSend"] boolValue];
                
                if([msgInfo objectForKey:@"shredDate"])
                {
                    shredDate = [NSDate dateFromRfc3339String:[msgInfo objectForKey:@"shredDate"]];
                }
                
                NSString* sirenString =[msgInfo objectForKey:@"siren"];
                NSData*  jsonData = [NSData dataFromBase64EncodedString:sirenString];
                
                Siren *inSiren = [Siren sirenWithJSONData: jsonData];
                
                if(inSiren)
                {
                    STImage        *thumbnail = nil;
                    UIImage        *thumbnailImage = nil;
                    Siren          *siren = NULL;
                    
                    if(inSiren.thumbnail)
                    {
                        thumbnailImage = [UIImage imageWithData:inSiren.thumbnail];
                        thumbnail = [[STImage alloc] initWithImage:thumbnailImage
                                                         parentKey:messageID
                                                        collection:conversationId];
                        
                        // Note: The thumbnail, when added to the database, will create a graph edge pointing to the message
                        // with a nodeDeleteRule so that the thumbnail is automatically deleted when the message is deleted.
                        
                        siren = inSiren.copy;
                        siren.thumbnail = NULL;
                    }
                    else
                    {
                        siren = inSiren.copy;
                    }
     
                    
                    BOOL isOutgoing = [recipient isEqualToString:remoteJID.bare];
                    
                    DDLogOrange(@"Msg: %@ MSG: %@", messageID, siren.message? siren.message : siren.cloudLocator );
                    
                    STMessage * message = [[STMessage alloc] initWithUUID:messageID
                                                           conversationId:conversationId
                                                                   userId:userID
                                                                     from:isOutgoing?local:remote
                                                                       to:isOutgoing?remote:local
                                                                withSiren:siren
                                                                timestamp:msgDate
                                                               isVerified:YES
                                                               isOutgoing:isOutgoing
                                                             hasThumbnail:thumbnail!= nil];
                    message = message.copy;
                    message.needsReSend = needsReSend;
                    
                    // ST1 did not have a concept of tracking which message actually got viewed.
                    message.isRead = YES;
                    
                    if(isOutgoing)
                    {
                        message.sendDate = msgDate;
                    }
                    else
                    {
                        message.rcvDate = msgDate;
                    }
                    
                    
                    //              message.sendDate = [NSDate date];
                    
                    
                    // does this message have a scloud componenent
                    if (message.siren.cloudLocator && message.siren.cloudKey)
                    {
                        STSCloud *scl = [transaction objectForKey:siren.cloudLocator inCollection:kSCCollection_STSCloud];
                        if(scl == nil)
                        {
                            message.needsDownload = YES;
							
							[ms downloadSCloudForMessage:message withThumbnail:thumbnailImage completionBlock:NULL];
                        }
                        else
                        {
                            // Create a relationship between the STMessage and STSCloud object.
                            //
                            // YDB_DeleteDestinationIfAllSourcesDeleted:
                            //   When the every last message that points to this particular STSCloud has been deleted,
                            //   then the database will automatically delete this STSCloud object.
                            //
                            // Further, the STSCloud object uses the YapDatabaseRelationshipNode protocol so that
                            // when the STSCloud object is deleted, the database automatically deletes the folder
                            // where it stores all its segments.
                            
                            YapDatabaseRelationshipEdge *edge =
                            [YapDatabaseRelationshipEdge edgeWithName:@"scloud"
                                                            sourceKey:message.uuid
                                                           collection:message.conversationId
                                                       destinationKey:siren.cloudLocator
                                                           collection:kSCCollection_STSCloud
                                                      nodeDeleteRules:YDB_DeleteDestinationIfAllSourcesDeleted];
                            
                            [[transaction ext:Ext_Relationship] addEdge:edge];
                        }
                    }
                    
                    [transaction setObject:message
                                    forKey:message.uuid
                              inCollection:message.conversationId];
                    
                    if(thumbnail)
                    {
                        [transaction setObject:thumbnail
                                        forKey:thumbnail.parentKey
                                  inCollection:kSCCollection_STImage_Message];
                    }
                }
                
            }];
            
        }];
        
    } completionBlock:^{
        
        if(completion)
            (completion)(error);
        
    }];
}

@end
