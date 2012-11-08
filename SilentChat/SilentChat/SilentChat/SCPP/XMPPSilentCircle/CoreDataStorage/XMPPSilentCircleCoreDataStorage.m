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


#import "XMPPSilentCircleCoreDataStorage.h"
#import "XMPPSilentCircleStateCoreDataStorageObject.h"
#import "XMPPSilentCircleStateKeyCoreDataStorageObject.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPLogging.h"

#import <Security/SecRandom.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif


@implementation XMPPSilentCircleCoreDataStorage

static XMPPSilentCircleCoreDataStorage *sharedInstance;

+ (XMPPSilentCircleCoreDataStorage *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[XMPPSilentCircleCoreDataStorage alloc] initWithDatabaseFilename:nil];
	});
	
	return sharedInstance;
}

- (NSString *)stateKeyEntityName
{
	return @"XMPPSilentCircleStateKeyCoreDataStorageObject";
}

- (NSString *)stateEntityName
{
	return @"XMPPSilentCircleStateCoreDataStorageObject";
}

/**
 * In order to save and restore state, a key is used to encrypt the saved state,
 * and later used to decrypt saved state in order to restore it.
 * 
 * If a key exists for this combination of JIDs, it should be returned.
 * Otherwise, a new key is to be generated, stored for this combination of JIDs, and then returned.
**/
- (NSData *)stateKeyForLocalJid:(XMPPJID *)localJid remoteJid:(XMPPJID *)remoteJid
{
	XMPPLogTrace();
	
	NSString *localJidStr = [localJid full];
	NSString *remoteJidStr = [remoteJid full];
	
	__block NSData *stateKey = nil;
	
	[self executeBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		NSString *entityName = [self stateKeyEntityName];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
		
		NSPredicate *predicate =
		    [NSPredicate predicateWithFormat:@"localJidStr == %@ AND remoteJidStr == %@", localJidStr, remoteJidStr];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setFetchLimit:1];
		
		NSError *error = nil;
		NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
		
		if (results == nil)
		{
			XMPPLogError(@"%@: Fetch error: %@", THIS_FILE, error);
		}
		
		XMPPSilentCircleStateKeyCoreDataStorageObject *stateKeyEntry = [results lastObject];
		
		if (stateKeyEntry == nil)
		{
			// Generate a random key, and add entry to the database
			
			uint8_t key[64] = {0};
			size_t  keyLen  = 64;
			
			SecRandomCopyBytes(kSecRandomDefault, keyLen, key);
			
			stateKeyEntry = [NSEntityDescription insertNewObjectForEntityForName:entityName
			                                              inManagedObjectContext:moc];
			
			stateKeyEntry.localJidStr = localJidStr;
			stateKeyEntry.remoteJidStr = remoteJidStr;
			stateKeyEntry.stateKey = [NSData dataWithBytes:key length:keyLen];
		}
		
		stateKey = stateKeyEntry.stateKey;
	}];
	
	return stateKey;
}

/**
 * Instructs the storage protocol to save session state data.
 * This is data coming from SCimpSaveState.
**/
- (void)saveState:(NSData *)state forLocalJid:(XMPPJID *)localJid remoteJid:(XMPPJID *)remoteJid
{
	XMPPLogTrace();
	
	NSString *localJidStr = [localJid full];
	NSString *remoteJidStr = [remoteJid full];
	
	[self scheduleBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		NSString *entityName = [self stateEntityName];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
		
		NSPredicate *predicate =
		    [NSPredicate predicateWithFormat:@"localJidStr == %@ AND remoteJidStr == %@", localJidStr, remoteJidStr];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setFetchLimit:1];
		
		NSError *error = nil;
		NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
		
		if (results == nil)
		{
			XMPPLogError(@"%@: Fetch error: %@", THIS_FILE, error);
		}
		
		XMPPSilentCircleStateCoreDataStorageObject *stateEntry = [results lastObject];
		
		if (stateEntry)
		{
			stateEntry.state = state;
		}
		else
		{
			stateEntry = [NSEntityDescription insertNewObjectForEntityForName:entityName
			                                           inManagedObjectContext:moc];
			
			stateEntry.localJidStr = localJidStr;
			stateEntry.remoteJidStr = remoteJidStr;
			stateEntry.state = state;
		}
	}];
}

/**
 * Instructs the storage protocol to retrieve previously saved state data.
 * This is data going to SCimpRestoreState.
**/
- (NSData *)restoreStateForLocalJid:(XMPPJID *)localJid remoteJid:(XMPPJID *)remoteJid
{
	XMPPLogTrace();
	
	NSString *localJidStr = [localJid full];
	NSString *remoteJidStr = [remoteJid full];
	
	__block NSData *state = nil;
	
	[self executeBlock:^{
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		NSString *entityName = [self stateEntityName];
		
		NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
		
		NSPredicate *predicate =
		    [NSPredicate predicateWithFormat:@"localJidStr == %@ AND remoteJidStr == %@", localJidStr, remoteJidStr];
		
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:entity];
		[fetchRequest setPredicate:predicate];
		[fetchRequest setFetchLimit:1];
		
		NSError *error = nil;
		NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
		
		if (results == nil)
		{
			XMPPLogError(@"%@: Fetch error: %@", THIS_FILE, error);
		}
		
		XMPPSilentCircleStateCoreDataStorageObject *stateEntry = [results lastObject];
		
		state = stateEntry.state;
	}];
	
	return state;
}

@end
