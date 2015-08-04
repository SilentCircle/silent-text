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
//
//  SRVManager.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 11/22/13.
//

#import "SRVManager.h"
#import "SCSRVResolver.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "DDLog.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "NSDate+SCDate.h"

#include <netdb.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>

#import "STLogging.h"

typedef void (^LookupWithSRVnameCompletionBlock)(NSError *error, NSArray *srvResults);


// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@implementation SRVManager
{
	YapDatabaseConnection *databaseConnection;
	
	dispatch_queue_t resolverDelegateQueue;
	NSMutableArray *activeResolvers;
}


static SRVManager *sharedInstance;

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		sharedInstance = [[SRVManager alloc] init];
  	}
}

+ (SRVManager *)sharedInstance
{
	return sharedInstance;
}

- (id)init
{
	NSAssert(sharedInstance == nil, @"MUST use sharedInstance (class singleton)");
	
	if ((self = [super init]))
	{
		databaseConnection = [STDatabaseManager.database newConnection];
		databaseConnection.objectCacheLimit = 20;
		databaseConnection.metadataCacheEnabled = NO;
		databaseConnection.name = @"SRVManager";
		
		resolverDelegateQueue = dispatch_queue_create("broker.silentcircle.com", NULL);
		activeResolvers = [[NSMutableArray alloc] initWithCapacity:1];
	}
	return self;
}

/**
 * Lookup the srvName in the SRV database.
 * If found, returns the host info from the database record.
 * Otherwise, does an SRV lookup, updates the SRV database, and returns the results.
 * 
 * Found or not, we will now do an SRV lookup and update the SRV database whenever we are asked to do a lookup.
 * This helps keep the cache current.
**/
- (void)lookupWithSRVname:(NSString *)srvName
          completionBlock:(LookupWithSRVnameCompletionBlock)completionBlock
{
	// Remember:
	// - completion blocks should always be asynchronous
	// - completion blocks should always be invoked on the main thread (unless otherwise specified)

	if (srvName == nil)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (completionBlock) {
				completionBlock([STAppDelegate otherError:@"nil srvName parameter"], NULL);
			}
		});
		
		return;
	}
	
	
	// How often we should do a refresh
	const NSTimeInterval kDefaultSRVRecordRefresh =  60 * 60 * 3; // 3 hours
	
	__block STSRVRecord *srv = nil;
	
	[databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		// Normal lookup using the cache
		srv = [transaction objectForKey:srvName inCollection:kSCCollection_STSRVRecord];
		
	#if DEBUG && robbie_hanson
		// FOR TESTING:
		// Use this line instead to force a refetch of SRV from server everytime.
		srv = nil;
	#endif
	}
	completionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
	completionBlock:^{
        
  		if (srv && srv.srvArray.count)
		{
			// Refresh the STSRVRecord if it's been a while.
			
			if ([[srv.timeStamp dateByAddingTimeInterval:kDefaultSRVRecordRefresh] isBefore:[NSDate date]])
			{
				// Note that we don't pass in a completion here,
				// since we call completion with the DB value.
				[self startLookupWithSRVname:srvName completionBlock:NULL];
			}
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				if (completionBlock) {
 					completionBlock(NULL, srv.srvArray);
				}
			});
  		
		}
		else // if (srv == nil)
		{
			[self startLookupWithSRVname:srvName completionBlock:completionBlock];
		}
	}];
}

/**
 * Starts the SRV lookup process.
 * Delegate methods are invoked when comlete.
**/
- (void)startLookupWithSRVname:(NSString *)srvName
               completionBlock:(LookupWithSRVnameCompletionBlock)completionBlock
{
	SCSRVResolver *resolver = [[SCSRVResolver alloc] initWithDelegate:self
	                                                     delegateQueue:resolverDelegateQueue
	                                                     resolverQueue:NULL];
	
//	DDLogGreen(@"startLookupWithSRVname : %@", srvName);
	
	[activeResolvers addObject:resolver];
    [resolver startWithSRVName:srvName timeout:30.0 userObject:completionBlock];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utility methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//- (NSString *)lookupHostIPAddress:(NSString *)host
//{
//    if(!host)
//        return NULL;
//    
//	// From Apple's documentation: "Resolving DNS Hostnames"
//	//
//	// gethostbyname - Returns a single IPv4 address for a given hostname.
//	// This function is discouraged for new development because it is limited to IPv4 addresses.
//	
//    // Ask the unix subsytem to query the DNS
//    struct hostent *remoteHostEnt = gethostbyname(host.UTF8String);
//    
//    // Get address info from host entry
//    struct in_addr *remoteInAddr = (struct in_addr *) remoteHostEnt->h_addr_list[0];
//    
//    // Convert numeric addr to ASCII string
//    char *sRemoteInAddr = inet_ntoa(*remoteInAddr);
//    
//    // hostIP
//    NSString* hostIP = [NSString stringWithUTF8String:sRemoteInAddr];
//    return hostIP;
//}

- (void)clearSRVCacheForSRVName:(NSString *)srvName
{
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		[transaction removeObjectForKey:srvName inCollection:kSCCollection_STSRVRecord];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SCSRVResolver Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * SCSRVResolver delegate callback.
 * This method is invoked on our resolverDelegateQueue.
**/
- (void)srvResolver:(SCSRVResolver *)sender didResolveRecords:(NSArray *)srvResults
{
	LookupWithSRVnameCompletionBlock completionBlock = (LookupWithSRVnameCompletionBlock)sender.userObject;

	if (srvResults.count)
    {
		STSRVRecord *srv = [[STSRVRecord alloc] initWithSRVName:sender.srvName srvArray:srvResults];
		
        // Async update database.
        // Note: no reason to delay delegate until data hits the disk.
        [databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
            // should we do an optimization here and try and rmember the host IP address for the prefered host

            [transaction setObject:srv
                            forKey:srv.srvName
                      inCollection:kSCCollection_STSRVRecord];
        }];
        
 
            // Remember:
            // - completion blocks should always be asynchronous
            // - completion blocks should always be invoked on the main thread (unless otherwise specified)
            dispatch_async(dispatch_get_main_queue(), ^{
                
                if (completionBlock) {
                    completionBlock(NULL, srvResults);
                }
            });
            
 
    }
    else // if (srvRecord == nil)
    {
		// Remember:
		// - completion blocks should always be asynchronous
		// - completion blocks should always be invoked on the main thread (unless otherwise specified)
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (completionBlock) {
				completionBlock([STAppDelegate otherError:@"internal error"], NULL);
			}
		});
    }
    
    
	// Remove from activeResolvers array.
	// No need to retain any longer.
	[activeResolvers removeObjectIdenticalTo:sender];
}


- (void)srvResolver:(SCSRVResolver *)sender didNotResolveDueToError:(NSError *)error
{
	LookupWithSRVnameCompletionBlock completionBlock = (LookupWithSRVnameCompletionBlock)sender.userObject;
	
	// Remember:
	// - completion blocks should always be asynchronous
	// - completion blocks should always be invoked on the main thread (unless otherwise specified)
	dispatch_async(dispatch_get_main_queue(), ^{

		if (completionBlock) {
			completionBlock(error, NULL);
		}
	});
	
	// Async update database.
	// Note: no reason to delay delegate until data hits the disk.
	
	NSString *srvName = sender.srvName;
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		[transaction removeObjectForKey:srvName inCollection:kSCCollection_STSRVRecord];
	}];
	
	// Remove from activeResolvers array.
	// No need to retain any longer.
	[activeResolvers removeObjectIdenticalTo:sender];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)brokerForNetworkID:(NSString *)networkID
           completionBlock:(SRVManagerCompletionBlock)completionBlock
{
	NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
	
	if (networkInfo == nil)
	{
		// Remember:
		// - completion blocks should always be asynchronous
		// - completion blocks should always be invoked on the main thread (unless otherwise specified)
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if(completionBlock) {
				completionBlock([STAppDelegate otherError:@"internal error"], NULL, NULL, 0);
			}
		});
		
		return;
	}
	
	NSString * srvName    = [networkInfo objectForKey:@"brokerSRV"]; // These should be constants
	NSString * brokerURL  = [networkInfo objectForKey:@"brokerURL"];
	NSNumber * brokerPort = [networkInfo objectForKey:@"brokerPort"];
	
	if (srvName)
	{
		[self lookupWithSRVname:srvName
		        completionBlock:^(NSError *error, NSArray *srvResults)
         {
			NSAssert([NSThread isMainThread], @"CompletionBlocks are expected to be invoked on the main thread");

           if (completionBlock)
			{
				if (!error) {
                    
                    if(srvResults.count)
                    {
                        SCSRVRecord* srvRecord = [srvResults firstObject];

                        NSString *host = srvRecord.host;
                        UInt16    port = srvRecord.port;
                        
                        completionBlock(NULL, host, NULL, @(port));
                        
                    }
                    else
                    {
                        completionBlock([STAppDelegate otherError:@"SRV returned no results"],
                                         NULL, NULL, NULL);
                        
                    }
                    
                }
				else if (brokerURL) {
					completionBlock(NULL, brokerURL, NULL, brokerPort);
				}
				else {
					completionBlock(error, NULL, NULL, NULL);
				}
			}
		}];
	}
	else if (brokerURL)
	{
		// Remember:
		// - completion blocks should always be asynchronous
		// - completion blocks should always be invoked on the main thread (unless otherwise specified)
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (completionBlock) {
				completionBlock(NULL, brokerURL, NULL, brokerPort);
			}
		});
	}
	else
	{
		// Remember:
		// - completion blocks should always be asynchronous
		// - completion blocks should always be invoked on the main thread (unless otherwise specified)
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (completionBlock) {
				completionBlock([STAppDelegate otherError:@"internal error"], NULL, NULL, NULL);
			}
		});
	}
}

- (void)xmppForNetworkID:(NSString *)networkID
         completionBlock:(SRVManagerArrayCompletionBlock)completionBlock
{
	NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
	
	if (networkInfo == nil)
	{
		// Remember:
		// - completion blocks should always be asynchronous
		// - completion blocks should always be invoked on the main thread (unless otherwise specified)
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (completionBlock) {
				completionBlock([STAppDelegate otherError:@"internal error"], NULL);
			}
		});
		
        return;
    }
	
    SCSRVRecord* defaultXMPPrecord  = NULL;
    NSString * srvName  = [networkInfo objectForKey:@"xmppSRV"]; // These should be constants
    
    NSString * xmppURL  = [networkInfo objectForKey:@"xmppURL"];
    NSNumber * xmppPort = [networkInfo objectForKey:@"xmppPort"];
    
	
    if(xmppURL)
    {
        defaultXMPPrecord  = [[SCSRVRecord alloc] initWithPriority:9999
                                                            weight:1
                                                              port:xmppPort?xmppPort.integerValue:443
                                                              host:xmppURL];
    }
    
 	if (srvName)
	{
		[self lookupWithSRVname:srvName
		        completionBlock:^(NSError *error, NSArray *srvResults)
         {
			NSAssert([NSThread isMainThread], @"CompletionBlocks are expected to be invoked on the main thread");
			
  			if (completionBlock)
			{
				if (!error)
                {
                    if(srvResults.count)
                    {
                         completionBlock(NULL, srvResults);
                        
                    }
                    else
                    {
                        completionBlock([STAppDelegate otherError:@"SRV returned no results"],  NULL );
                        
                    }
 
				}
                else if(xmppURL)
                {
					completionBlock(NULL,  @[defaultXMPPrecord]);
				}
				else {
					completionBlock(error, NULL);
				}
			}
		}];
	}
	else if(defaultXMPPrecord)
	{
		// Remember:
		// - completion blocks should always be asynchronous
		// - completion blocks should always be invoked on the main thread (unless otherwise specified)
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (completionBlock) {
				completionBlock(NULL, @[defaultXMPPrecord]);
			}
		});
	}
	else
	{
		// Remember:
		// - completion blocks should always be asynchronous
		// - completion blocks should always be invoked on the main thread (unless otherwise specified)
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (completionBlock) {
				completionBlock([STAppDelegate otherError:@"internal error"], NULL);
			}
		});
	}
}

- (void)clearBrokerSRVCacheForNetworkID:(NSString *)networkID
{
	NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
    
	if (networkInfo)
	{
        NSString *srvName = [networkInfo objectForKey:@"brokerSRV"]; // This should be a constant
		
		[self clearSRVCacheForSRVName:srvName];
    }
}

- (void)clearXmppSRVCacheForNetworkID:(NSString *)networkID
{
	NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
	
	if (networkInfo)
    {
		NSString *srvName = [networkInfo objectForKey:@"xmppSRV"]; // This should be a constant
		
		[self clearSRVCacheForSRVName:srvName];
	}
}

@end
