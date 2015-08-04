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
//  SCAccountsWebManager.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 7/8/13.
//

#import <SystemConfiguration/SystemConfiguration.h>

#import "SCWebAPIManager.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "PersonSearchResult.h"
#import "SCSRVResolver.h"
#import "SCWebSession.h"
#import "SRVManager.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "STUser.h"
#import "MessageStream.h"

// Categories
#import "NSDate+SCDate.h"
#import "NSString+SCUtilities.h"
#import "UIImage+Crop.h"



// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

NSString *const kUserInfoKey_hash                   = @"hash";                   // NSString
NSString *const kUserInfoKey_avatarUrl              = @"avatarUrl";              // NSString
NSString *const kUserInfoKey_hasPhone               = @"hasPhone";               // NSNumber (BOOL)
NSString *const kUserInfoKey_hasOCA                 = @"hasOCA";                 // NSNumber (BOOL)
NSString *const kUserInfoKey_canSendMedia           = @"canSendMedia";           // NSNumber (BOOL)
NSString *const kUserInfoKey_pubKeys                = @"pubKeys";                // NSArray
NSString *const kUserInfoKey_firstName              = @"firstName";              // NSString
NSString *const kUserInfoKey_lastName               = @"lastName";               // NSString
NSString *const kUserInfoKey_displayName            = @"displayName";            // NSString
NSString *const kUserInfoKey_email                  = @"email";                  // NSString
NSString *const kUserInfoKey_organization           = @"organization";           // NSString
NSString *const kUserInfoKey_activeDeviceID         = @"activeDeviceID";           // NSString
NSString *const kUserInfoKey_spNumbers              = @"spNumbers";              // NSArray
NSString *const kUserInfoKey_subscriptionExpireDate = @"subscriptionExpireDate"; // NSDate
NSString *const kUserInfoKey_subscriptionAutoRenews = @"subscriptionAutoRenews"; // NSNumber (BOOL)
NSString *const kUserInfoKey_handlesOwnBilling      = @"handlesOwnBilling";      // NSNumber (BOOL)



@implementation SCWebAPIManager
{
	NSMutableDictionary *opQueues;
}

static SCWebAPIManager *sharedInstance;

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		sharedInstance = [[SCWebAPIManager alloc] init];
  	}
}

+ (SCWebAPIManager *)sharedInstance
{
	return sharedInstance;
}

- (instancetype)init
{
	NSAssert(sharedInstance == nil, @"You MUST used sharedInstance singleton.");
	
	if ((self = [super init]))
	{
		opQueues = [[NSMutableDictionary alloc] init];
	}
	return self;
}
 
#pragma mark - Utility methods

- (void)addOperationToQueue:(NSOperation *)operation
               forNetworkID:(NSString *)networkID
{
	NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
	if (networkInfo)
	{
		NSOperationQueue *queue = [opQueues objectForKey:networkID];
		if (queue == nil)
        {
			queue = [[NSOperationQueue alloc] init];
			[opQueues setObject:queue forKey:networkID];
		}
        
		[queue addOperation:operation];
	}
    else
	{
		DDLogError(@"%@ - Invalid networkID(%@) !!! Dropping operation on the floor !!!", THIS_METHOD, networkID);
	}
}

- (NSArray *)keyHashArrayForNetworkID:(NSString *)networkID
{
	NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
	NSArray *hashes = [networkInfo objectForKey:@"webAPISHA256"];
	
	return hashes;
}

- (NSString *)encodeURLStringwithHost:(NSString *)host port:(NSNumber *)port
{
	NSString *urlString = !port || ([port unsignedIntValue] == 443)
	  ? [NSString stringWithFormat:@"https://%@", host]
	  : [NSString stringWithFormat:@"http://%@:%u", host, [port unsignedIntValue]];
    
	return urlString;
}

- (NSDictionary *)parseJsonResponseData:(NSData *)data error:(NSError **)errorPtr
{
	NSError *jsonError = nil;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
	
	NSError *error = nil;
	if (jsonError)
	{
		error = jsonError;
		
		// In case the WebAPI forgot to give us proper JSON.
		if (data.length > 0)
		{
			NSString *nonJsonResponse = [[NSString alloc] initWithBytes:data.bytes
			                                                     length:data.length
			                                                   encoding:NSUTF8StringEncoding];
			
			if (nonJsonResponse)
			{
				NSMutableDictionary *details = [NSMutableDictionary dictionaryWithCapacity:1];
				details[NSLocalizedDescriptionKey] = nonJsonResponse;
				
				error = [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorCannotConnectToHost userInfo:details];
			}
		}
	}
	else
	{
		NSString *error_msg = [info objectForKey:@"error_msg"];
        if (error_msg)
		{
			NSMutableDictionary *details = [NSMutableDictionary dictionaryWithCapacity:1];
			details[NSLocalizedDescriptionKey] = error_msg;
			
			error = [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorCannotConnectToHost userInfo:details];
            info = nil;
		}
	}
	
	if (errorPtr) *errorPtr = error;
	return info;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Account Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Description needed
**/
- (void)createAccountFor:(NSString *)userName
            withPassword:(NSString *)password
               networkID:(NSString *)networkID
               firstName:(NSString *)firstName
                lastName:(NSString *)lastName
                   email:(NSString *)email
         completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion
{
	NSAssert(password != nil, @"Oops");
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:4];
			 
			if (password) [dict setObject:password forKey:@"password"];
			
			if (firstName.length) [dict setObject:firstName forKey:@"first_name"];
			if (lastName.length)  [dict setObject:lastName  forKey:@"last_name"];
			if (email.length)     [dict setObject:email     forKey:@"email"];
			
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/user/%@", [userName urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"PUT";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:dict
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

/**
 * Description needed
**/
- (void)provisionCodeFor:(NSString *)userName
            withPassword:(NSString *)password
               networkID:(NSString *)networkID
         completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion
{
   
    DDLogAutoTrace();
    
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, NULL);
			}
		}
		else
		{
			NSDictionary *dict = @{
			  @"username": userName,
			  @"password": password,
			};
			
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = @"/v1/me/provisioning-code/";
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"POST";
             
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:dict
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, NULL);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

/**
 * Performs a PUT to /v1/me/device/[deviceID]/.
 *
 * Passes an activationCode as credentials.
 * This essentially registers the given deviceID (if needed),
 * and allows the server to setup the proper database entries for the deviceID.
 *
 * The server returns an API key which is tied to the username/deviceID combo.
 *
 * @param deviceName
 *   User supplied field (e.g. "My iPhone 6")
 *
 * @param deviceID
 *   The deviceID MUST be the same as the JID.resource to be used for this account.
 *   The deviceID should NOT change (for this user on this device),
 *   unless the user logs out and we delete scimp context items from persistent storage.
 *
 * @param networkID
 *   One of the constants from AppConstants.h (e.g. kNetworkID_Production)
**/
- (void)provisionWithCode:(NSString *)activationCode
               deviceName:(NSString *)deviceName
                 deviceID:(NSString *)deviceID
                networkID:(NSString *)networkID
          completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion
{
	DDLogAutoTrace();
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSDictionary *dict = @{
			  @"provisioning_code": activationCode,
			  @"device_name"      : deviceName,
			  @"app"              : @"silent_text",
			  @"device_class"     : @"ios",
			};
			
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/device/%@/", [deviceID urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"PUT";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:dict
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

/**
 * Performs a PUT to /v1/me/device/<deviceID>/.
 *
 * Passes the username & password as credentials.
 * This essentially registers the given deviceID (if needed),
 * and allows the server to setup the proper database entries for the deviceID.
 *
 * The server returns an API key which is tied to the username/deviceID combo.
 *
 * @param deviceName
 *   User supplied field (e.g. "My iPhone 6")
 *
 * @param deviceID
 *   The deviceID MUST be the same as the JID.resource to be used for this account.
 *   The deviceID should NOT change (for this user on this device),
 *   unless the user logs out and we delete scimp context items from persistent storage.
 *
 * @param networkID
 *   One of the constants from AppConstants.h (e.g. kNetworkID_Production)
**/
- (void)provisionWithUsername:(NSString *)username
                     password:(NSString *)password
                   deviceName:(NSString *)deviceName
                     deviceID:(NSString *)deviceID
                    networkID:(NSString *)networkID
              completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion
{
	DDLogAutoTrace();
    
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			DDLogError(@"SRVManager error: brokerForNetworkID - %@", srvError);
			
			if (completion) {
				completion(srvError, NULL);
			}
		}
		else
		{
			NSDictionary *dict = @{
			  @"username"    : username,
			  @"password"    : password,
			  @"device_name" : deviceName,
			  @"app"         : @"silent_text",
			  @"device_class": @"ios"
			};
			
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/device/%@/", [deviceID urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"PUT";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:dict
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, NULL);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
		
	}];
}

/**
 * Performs a DELETE to /v1/me/device/<deviceID>/?api_key=<key>
 * 
 * - unregisters the deviceID
 * - de-activates the apiKey
 * - deletes the associated pushToken
**/
- (void)deprovisionLocalUser:(STLocalUser *)inLocalUser
             completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion
{
    DDLogTrace(@"deprovisionUser:%@ completionBlock:",  [inLocalUser.jid bare]);
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// (Another option would be to copy/snapshot the user.)
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *deviceID    = inLocalUser.deviceID;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	if (apiKey == nil)
		apiKey = inLocalUser.oldApiKey;
	
    [[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, NULL);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/device/%@/?api_key=%@",
			                       [deviceID urlEncodedString],
			                       [apiKey urlEncodedString]];
			 
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"DELETE";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:nil
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

/**
 * Performs a PUT to /v1/me/device/<deviceID>/active?api_key=<key>
 * 
 * This makes the given deviceID the active_st_device.
**/
- (void)markActiveDeviceID:(NSString *)deviceID
                    apiKey:(NSString *)apiKey
                 networkID:(NSString *)networkID
           completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion
{
	DDLogAutoTrace();
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/device/%@/active?api_key=%@",
			                      [deviceID urlEncodedString],
			                      [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"PUT";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:NULL
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					// Example JSON: {
					//   changed = 0;
					//   result = success;
					// }
				
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
				
			}];
			
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

/**
 * Performs a GET to /v1/me/device/<deviceID>/?api_key=<key>
 * 
 *
**/
- (void)getConfigForDeviceID:(NSString *)deviceID
                      apiKey:(NSString *)apiKey
                   networkID:(NSString *)networkID
             completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion
{
	DDLogAutoTrace();
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/device/%@/?api_key=%@",
			                      [deviceID urlEncodedString],
			                      [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"GET";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:NULL
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
				
			}];
			
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
		
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public Keys
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)uploadPublicKeyWithLocator:(NSString *)locator
                   publicKeyString:(NSString *)keyString
                      forLocalUser:(STLocalUser *)inLocalUser
                   completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion

{
    DDLogAutoTrace();
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need 2 fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	NSData *keyData = [keyString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *keyDict = [NSJSONSerialization JSONObjectWithData:keyData options:0 error:NULL];
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/pubkey/%@/?api_key=%@",
			                      [locator urlEncodedBase64SafeString],
			                      [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"PUT";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:keyDict
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}



- (void)removePublicKeyWithLocator:(NSString *)locator
                      forLocalUser:(STLocalUser *)inLocalUser
                   completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion
{
	DDLogTrace(@"removePublicKeyWithLocator:%@ forLocalUser:%@ completionBlock:", locator, [inLocalUser.jid bare]);
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need 2 fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/pubkey/%@/?api_key=%@",
			                      [locator urlEncodedBase64SafeString],
			                      [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"DELETE";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:nil
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

- (void)getKeyWithLocator:(NSString *)locator
             forLocalUser:(STLocalUser *)inLocalUser
          completionBlock:(void (^)(NSError *error, NSDictionary *jsonDict))completion
{
	DDLogTrace(@"getKeyWithLocator:%@ forLocalUser:%@ completionBlock:", locator, [inLocalUser.jid bare]);
	
	if (inLocalUser == nil) return;
	if (inLocalUser.isRemote)
	{
		NSAssert(NO, @"%@ - passed non-local user", THIS_METHOD);
		return;
	}
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need 2 fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/pubkey/%@/?api_key=%@",
			                      [locator urlEncodedBase64SafeString],
			                      [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"GET";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:nil
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Fetching User Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Fetches info specific for a localUser (such as subscription information).
 *
 * @param localUser
 *   The localUser with which to fetch info about from the server.
 *
 * @param completion
 *   Will be invoked when the HTTP request completes.
 *   The corresponding jsonDict is raw JSON.
 *   You should use the parseLocalUserInfoResult method to perform standard parsing on the raw JSON dict.
 *
 * @see parseLocalUserInfoResult
**/
- (void)getLocalUserInfo:(STLocalUser *)inLocalUser
         completionBlock:(void (^)(NSError *error, NSDictionary *jsonDict))completion
{
	DDLogTrace(@"getLocalUserInfo: %@", inLocalUser.jid);
	
	NSAssert(inLocalUser.isLocal, @"Attempting to fetch localUserInfo for non-local user.");
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need 2 fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.networkID;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/?api_key=%@", [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"GET";
             
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:NULL
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

/**
 * Standard parsing of the JSON response from getLocalUserInfo:completion:
 * Use me, instead of copy-n-pasting code.
 * 
 * The returned dictionary has the following defined keys:
 *
 * - kUserInfoKey_avatarUrl               => NSString
 * - kUserInfoKey_hasPhone                => NSNumber (BOOL)
 * - kUserInfoKey_hasOCA                  => NSNumber (BOOL)
 * - kUserInfoKey_canSendMedia            => NSNumber (BOOL)
 * - kUserInfoKey_firstName               => NSString
 * - kUserInfoKey_lastName                => NSString
 * - kUserInfoKey_displayName             => NSString
 * - kUserInfoKey_email                   => NSString
 * - kUserInfoKey_spNumbers               => NSArray
 * - kUserInfoKey_subscriptionExpireDate  => NSDate
 * - kUserInfoKey_subscriptionAutoRenews  => NSNumber (BOOL)
 * - kUserInfoKey_handlesOwnBilling       => NSNumber (BOOL)
**/
- (NSDictionary *)parseLocalUserInfoResult:(NSDictionary *)jsonDict
{
	if (jsonDict == nil) return nil;
	
	BOOL hasPhone = NO;
	BOOL hasOCA = NO;
	BOOL canSendMedia = NO;
	
	// WEB-1092 : note that avatar_url could be a null value
	NSString *avatarUrl = [jsonDict valueForKey:@"avatar_url"];
	
	if ([avatarUrl isKindOfClass:[NSNull class]])
		avatarUrl = nil;
	
	if (![avatarUrl isKindOfClass:[NSString class]])
		avatarUrl = nil;
	
#if WEB_1092_BUG
	if ([avatarUrl hasPrefix:@"/static/"])
		avatarUrl = nil;
#endif
	
	NSDictionary *permissions = [jsonDict valueForKey:@"permissions"];
	if (permissions && [permissions isKindOfClass:[NSDictionary class]])
	{
		id value;
		
		value = [permissions objectForKey:@"silent_phone"];
		if ([value isKindOfClass:[NSNumber class]])
			hasPhone = [value boolValue];
		else if (value)
			DDLogWarn(@"%@ - Invalid 'silent_phone' value. Class = %@", THIS_METHOD, [value class]);
		
		value = [permissions objectForKey:@"has_oca"];
		if ([value isKindOfClass:[NSNumber class]])
			hasOCA = [value boolValue];
		else
			DDLogWarn(@"%@ - Invalid 'has_oca' value. Class = %@", THIS_METHOD, [value class]);
		
		value = [permissions objectForKey:@"can_send_media"];
		if ([value isKindOfClass:[NSNumber class]])
			canSendMedia = [value boolValue];
		else
			DDLogWarn(@"%@ - Invalid 'can_send_media' value. Class = %@", THIS_METHOD, [value class]);
	}
	
	NSString *hash           = [jsonDict objectForKey:@"hash"];
	NSString *firstName      = [jsonDict objectForKey:@"first_name"];
	NSString *lastName       = [jsonDict objectForKey:@"last_name"];
	NSString *displayName    = [jsonDict objectForKey:@"display_name"];
	NSString *email          = [jsonDict objectForKey:@"email"];
	NSString *activeDeviceID = [jsonDict objectForKey:@"active_st_device"];
	
	NSArray *spNumbers = nil;
	NSString *organization = nil;
	
	NSDictionary *details = [jsonDict objectForKey:@"details"];
	if (details && [details isKindOfClass:[NSDictionary class]])
	{
		NSDictionary *spInfo = [details objectForKey:@"silent_phone"];
		if(spInfo)
		{
			spNumbers = [spInfo objectForKey:@"numbers"];
		}
		organization = [details objectForKey:@"organization"];
	}
	
	NSDate *subscriptionExpireDate = nil;
	BOOL subscriptionAutoRenews = NO;
	BOOL handlesOwnBilling = NO;
	
	NSDictionary *subscription = [jsonDict objectForKey:@"subscription"];
	if (subscription)
	{
		NSString *expires = [subscription objectForKey:@"expires"];
		if ([expires isKindOfClass:[NSString class]])
		{
			subscriptionExpireDate = [NSDate dateFromRfc3339String:expires];
			
			// WEB-1078 : the server actually expires people the next day
			subscriptionExpireDate = [subscriptionExpireDate dateByAddingTimeInterval:(60 * 60 * 24)];
		}
		
		subscriptionAutoRenews = [[subscription objectForKey:@"autorenew"] boolValue];
		handlesOwnBilling = [[subscription objectForKey:@"handles_own_billing"] boolValue];
	}
	
	// Sanity checks
	
	if (hash && ![hash isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'hash' value. Class = %@", THIS_METHOD, [hash class]);
		hash = nil;
	}
	
	if (firstName && ![firstName isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'first_name' value. Class = %@", THIS_METHOD, [firstName class]);
		firstName = nil;
	}
	
	if (lastName && ![lastName isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'last_name' value. Class = %@", THIS_METHOD, [lastName class]);
		lastName = nil;
	}
	
	if (displayName && ![displayName isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'display_name' value. Class = %@", THIS_METHOD, [displayName class]);
		displayName = nil;
	}
	
	if (email && ![email isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'email' value. Class = %@", THIS_METHOD, [email class]);
		email = nil;
	}
	
	if (activeDeviceID && ![activeDeviceID isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'activeDeviceID' value. Class = %@", THIS_METHOD, [activeDeviceID class]);
		activeDeviceID = nil;
	}
	
	if (organization && ![organization isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'organization' value. Class = %@", THIS_METHOD, [organization class]);
		organization = nil;
	}

	NSMutableDictionary *parsedDict = [NSMutableDictionary dictionaryWithCapacity:12];
	
	if (avatarUrl) parsedDict[kUserInfoKey_avatarUrl] = avatarUrl;
	
	parsedDict[kUserInfoKey_hasPhone]     = @(hasPhone);
	parsedDict[kUserInfoKey_hasOCA]       = @(hasOCA);
	parsedDict[kUserInfoKey_canSendMedia] = @(canSendMedia);
	
	if (hash)           parsedDict[kUserInfoKey_hash] = hash;
	if (firstName)      parsedDict[kUserInfoKey_firstName] = firstName;
	if (lastName)       parsedDict[kUserInfoKey_lastName] = lastName;
	if (displayName)    parsedDict[kUserInfoKey_displayName] = displayName;
	if (email)          parsedDict[kUserInfoKey_email] = email;
	if (activeDeviceID) parsedDict[kUserInfoKey_activeDeviceID] = activeDeviceID;
	if (organization)   parsedDict[kUserInfoKey_organization] = organization;
	if (spNumbers)      parsedDict[kUserInfoKey_spNumbers] = spNumbers;
	
	if (subscriptionExpireDate)
		parsedDict[kUserInfoKey_subscriptionExpireDate] = subscriptionExpireDate;
	
	parsedDict[kUserInfoKey_subscriptionAutoRenews] = @(subscriptionAutoRenews);
	parsedDict[kUserInfoKey_handlesOwnBilling] = @(handlesOwnBilling);
	
	return parsedDict;
}

/**
 * Fetches info about the given JID, which may be for either a localUser or remoteUser.
 *
 * @param remoteJID
 *   The user to fetch info about.
 *
 * @param localUser
 *   A localUser that is typically associated with the remoteJID.
 *   The localUser paramater is needed for it's networkID & apiKey.
 *
 * @param completion
 *   Will be invoked when the HTTP request completes.
 *   The corresponding infoDict is raw JSON.
 *   You should use the parseUserInfoResult method to perform standard parsing on the raw JSON dict.
 *
 * @see parseUserInfoResult
**/
- (void)getUserInfo:(XMPPJID *)userJID
       forLocalUser:(STLocalUser *)inLocalUser
    completionBlock:(void (^)(NSError *error, NSDictionary *jsonDict))completion;
{
	DDLogTrace(@"getUserInfo:%@ forLocalUser:%@, completionBlock:", userJID, [inLocalUser.jid bare]);
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need a few fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/user/%@/?api_key=%@",
			                      [userJID.user urlEncodedString],
			                      [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"GET";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:NULL
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, NULL);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

/**
 * Standard parsing of the JSON response from getUserInfo:::
 * Use me, instead of copy-n-pasting code.
 *
 * The returned dictionary has the following defined keys:
 *
 * - kUserInfoKey_hash          => NSString
 * - kUserInfoKey_avatarUrl     => NSString
 * - kUserInfoKey_hasPhone      => NSNumber (BOOL)
 * - kUserInfoKey_hasOCA        => NSNumber (BOOL)
 * - kUserInfoKey_canSendMedia  => NSNumber (BOOL)
 * - kUserInfoKey_pubKeys       => NSArray
 * - kUserInfoKey_firstName     => NSString
 * - kUserInfoKey_lastName      => NSString
 * - kUserInfoKey_displayName   => NSString
 * - kUserInfoKey_activeDevice  => NSString
 * - kUserInfoKey_organization  => NSString
**/
- (NSDictionary *)parseUserInfoResult:(NSDictionary *)jsonDict
{
	if (jsonDict == nil) return nil;
	
	BOOL hasPhone = NO;
	BOOL hasOCA = NO;
	BOOL canSendMedia = NO;
	
	// WEB-1092 : note that avatar_url could be a null value
	NSString *avatarUrl = [jsonDict valueForKey:@"avatar_url"];
	
	if ([avatarUrl isKindOfClass:[NSNull class]])
		avatarUrl = nil;
	
	if (![avatarUrl isKindOfClass:[NSString class]])
 		avatarUrl = nil;
 	
#if WEB_1092_BUG
    if ([avatarUrl hasPrefix:@"/static/"])
		avatarUrl = nil;
#endif
	
	NSDictionary *permissions = [jsonDict objectForKey:@"permissions"];
	if (permissions && [permissions isKindOfClass:[NSDictionary class]])
	{
		id value;
		
		value = [permissions objectForKey:@"silent_phone"];
		if ([value isKindOfClass:[NSNumber class]])
			hasPhone = [value boolValue];
		else if (value)
			DDLogWarn(@"%@ - Invalid 'silent_phone' value. Class = %@", THIS_METHOD, [value class]);
		
		value = [permissions objectForKey:@"has_oca"];
		if ([value isKindOfClass:[NSNumber class]])
			hasOCA = [value boolValue];
		else
			DDLogWarn(@"%@ - Invalid 'has_oca' value. Class = %@", THIS_METHOD, [value class]);
		
		value = [permissions objectForKey:@"can_send_media"];
		if ([value isKindOfClass:[NSNumber class]])
			canSendMedia = [value boolValue];
		else
			DDLogWarn(@"%@ - Invalid 'can_send_media' value. Class = %@", THIS_METHOD, [value class]);
	}
	
	NSArray *pubKeys = [jsonDict objectForKey:@"keys"];
	
	NSString *hash           = [jsonDict objectForKey:@"hash"];
	NSString *firstName      = [jsonDict objectForKey:@"first_name"];
	NSString *lastName       = [jsonDict objectForKey:@"last_name"];
	NSString *displayName    = [jsonDict objectForKey:@"display_name"];
	NSString *activeDeviceID = [jsonDict objectForKey:@"active_st_device"];
	
	NSString *organization = nil;
	
	NSDictionary *details = [jsonDict objectForKey:@"details"];
	if (details && [details isKindOfClass:[NSDictionary class]])
	{
		organization = [details objectForKey:@"organization"];
	}

	// Sanity checks
	
	if (pubKeys && ![pubKeys isKindOfClass:[NSArray class]])
	{
		DDLogWarn(@"%@ - Invalid 'keys' value. Class = %@", THIS_METHOD, [pubKeys class]);
		pubKeys = nil;
	}
	
	if (hash && ![hash isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'hash' value. Class = %@", THIS_METHOD, [hash class]);
		hash = nil;
	}
	
	if (firstName && ![firstName isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'first_name' value. Class = %@", THIS_METHOD, [firstName class]);
		firstName = nil;
	}
	
	if (lastName && ![lastName isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'last_name' value. Class = %@", THIS_METHOD, [lastName class]);
		lastName = nil;
	}
	
	if (displayName && ![displayName isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'display_name' value. Class = %@", THIS_METHOD, [displayName class]);
		displayName = nil;
	}
	
	if (activeDeviceID && ![activeDeviceID isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'activeDeviceID' value. Class = %@", THIS_METHOD, [activeDeviceID class]);
		activeDeviceID = nil;
	}
	
	if (organization && ![organization isKindOfClass:[NSString class]])
	{
		DDLogWarn(@"%@ - Invalid 'organization' value. Class = %@", THIS_METHOD, [organization class]);
		organization = nil;
	}

	NSMutableDictionary *parsedDict = [NSMutableDictionary dictionaryWithCapacity:8];
	
	if (avatarUrl) parsedDict[kUserInfoKey_avatarUrl] = avatarUrl;
	
	parsedDict[kUserInfoKey_hasPhone]     = @(hasPhone);
	parsedDict[kUserInfoKey_hasOCA]       = @(hasOCA);
	parsedDict[kUserInfoKey_canSendMedia] = @(canSendMedia);
	
	if (pubKeys)        parsedDict[kUserInfoKey_pubKeys] = pubKeys;
	if (hash)           parsedDict[kUserInfoKey_hash] = hash;
	if (firstName)      parsedDict[kUserInfoKey_firstName] = firstName;
	if (lastName)       parsedDict[kUserInfoKey_lastName] = lastName;
	if (displayName)    parsedDict[kUserInfoKey_displayName] = displayName;
	if (activeDeviceID) parsedDict[kUserInfoKey_activeDeviceID] = activeDeviceID;
	if (organization)   parsedDict[kUserInfoKey_organization] = organization;
	
	return parsedDict;
}

/**
 * This method seems to only be used for fetching a user's web_avatar.
 * So should it not be called downloadAvatarForUser ?
**/
- (void)getDataForNetworkID:(NSString *)inNetworkID
                  urlString:(NSString *)inRelativeUrlPath
       completionBlock:(void (^)(NSError *error, NSData *data))completion
{
	DDLogTrace(@"getDataForNetworkID: %@ urlString: %@", inNetworkID, inRelativeUrlPath);

	NSString *networkID = [inNetworkID copy];             // mutable string protection
	NSString *relativeUrlPath = [inRelativeUrlPath copy]; // mutable string protection
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, NULL);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlString = [urlBase stringByAppendingString:relativeUrlPath];
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:@"GET"
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:NULL
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (completion) {
					completion(webError, data);
				}
			}];
			
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
		
	}];
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Updating LocalUser Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Documentation needed...
**/
- (void)updateInfoForLocalUser:(STLocalUser *)inLocalUser
               completionBlock:(void (^)(NSError *error, NSDictionary *jsonDict))completion
{
    DDLogTrace(@"updateInfoForLocalUser:%@ completionBlock:", [inLocalUser.jid bare]);
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need a few fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	NSDictionary *dict = @{
	  @"first_name" : (inLocalUser.firstName.length > 0) ? inLocalUser.firstName : [NSNull null],
	  @"last_name"  : (inLocalUser.lastName.length > 0)  ? inLocalUser.lastName  : [NSNull null]
	};
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, NULL);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/?api_key=%@", [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"PUT";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:dict
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, NULL);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}


- (void)uploadAvatarForLocalUser:(STLocalUser *)inLocalUser
                           image:(UIImage *)image
                 completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion
{
    DDLogTrace(@"uploadAvatarForLocalUser:%@ image:completionBlock:", [inLocalUser.jid bare]);
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need a few fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/avatar/?api_key=%@",
			                      [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = image ? @"POST" : @"DELETE";
			
			NSDictionary *dict = nil;
			if (image)
			{
				CGSize frame = {500, 500};
				UIImage *scaledImage = image;
				
				if ((scaledImage.size.height > frame.height) || (scaledImage.size.width > frame.width))
				{
					scaledImage = [image imageByScalingAndCroppingForSize:frame];
				}
				
				NSData *jpegData = UIImageJPEGRepresentation(scaledImage, 1.0);
				NSString *imageString = [jpegData base64EncodedStringWithOptions:0];
				
				dict  = @{
				  @"image": imageString,
				};
			}
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:dict
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Push Tokens
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)registerApplicationPushToken:(NSString *)pushToken
                        forLocalUser:(STLocalUser *)inLocalUser
                        useDebugCert:(BOOL)useDebugCert
                     completionBlock:(void (^)(NSError *error, NSDictionary *jsonDict))completion
{
	DDLogTrace(@"setApplicationPushToken:%@ forLocalUser:%@ useDebugCert:%@ completionBlock",
	           pushToken, inLocalUser.jid, (useDebugCert ? @"YES" : @"NO"));
	
	if (inLocalUser == nil) return;
	if (inLocalUser.isRemote)
	{
		NSAssert(NO, @"Attempting to fetch localUserInfo for non-local user.");
		return;
	}
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need a few fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *deviceID    = inLocalUser.deviceID;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *bundleID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
			
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/device/%@/application/%@/?api_key=%@",
			                      [deviceID urlEncodedString],
			                      [bundleID urlEncodedString],
			                      [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"PUT";
			
			NSDictionary *dict = @{
			  @"service": @"apns",
			  @"token": pushToken,
			  @"dist": (useDebugCert ? @"dev" : @"prod")
			};
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:dict
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
			#if 0 // Debugging
				
				if (webError)
				{
					NSString *msg = [NSString stringWithFormat:@"PushToken registration failed: %@", webError];
					[MessageStream sendInfoMessage:msg toUser:localUserID];
				}
				else
				{
					NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
					NSString *msg = [NSString stringWithFormat:
					   @"PushToken registration succeeded: %@\ninfo: %@", response, dict];
					[MessageStream sendInfoMessage:msg toUser:localUserID];
				}
				
			#endif
				
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}


- (void)unregisterApplicationPushTokenForLocalUser:(STLocalUser *)inLocalUser
                                   completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion
{
	DDLogTrace(@"unregisterApplicationPushTokenForLocalUser:%@ completionBlock:", [inLocalUser.jid bare]);
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need a few fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *deviceID    = inLocalUser.deviceID;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	if (apiKey == nil)
		apiKey = inLocalUser.oldApiKey;
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *bundleID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
			
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/me/device/%@/application/%@/?api_key=%@",
			                      [deviceID urlEncodedString],
			                      [bundleID urlEncodedString],
			                      [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"DELETE";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:nil
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Reporting Problems
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)postFeedbackForLocalUser:(STLocalUser *)inLocalUser
                  withReportInfo:(NSDictionary *)reportInfo
                 completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion
{
	DDLogAutoTrace();
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need a few fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	if (networkID == nil)
		networkID = kNetworkID_Production;
	
	if (apiKey == nil)
		apiKey = inLocalUser.oldApiKey;
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/feedback/?api_key=%@",
			                      [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"POST";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:reportInfo
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Broker
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * What is this method for ???
**/
- (void)brokerUploadRequestForLocalUser:(STLocalUser *)inLocalUser
                                reqDict:(NSDictionary *)reqDict
                        completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completionBlock
{
	DDLogAutoTrace();
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need a few fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *networkID   = inLocalUser.networkID;
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completionBlock) {
				completionBlock(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = @"/broker/";
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			NSString *urlMethod = @"POST";
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:urlMethod
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:reqDict
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					DDLogError(@"Web API error: %@ %@ :\n%@", urlMethod, urlString, webError);
					
					if (completionBlock) {
						completionBlock(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completionBlock) {
						completionBlock(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - payment
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/*
-(void) loadProductsForUser:(STUser *)user
			completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion {
	
    DDLogVerbose(@"SCWebRequest loadProductsForUser %@" , user.userName);
	
    NSString* lowerCaseUser = [user.userName lowercaseString];
    
    [[SRVManager sharedInstance] brokerForNetworkID:user.networkID
                                    completionBlock:^(NSError *error, NSString *host, NSString *hostIP, NSNumber *port)
     {
         if(error) {
             if(completion)
                 (completion)(error, NULL);
         }
         else {
             
             NSString*  urlString = [self encodeURLStringwithHost:host port:port];
			 
             urlString = [urlString stringByAppendingString:
                          [NSString stringWithFormat:@"/v1/products/%@/?api_key=%@",
                           [lowerCaseUser urlEncodeString:NSASCIIStringEncoding] ,
                           [user.apiKey urlEncodeString:NSASCIIStringEncoding] ]];
			 
             SCWebSession * operation = [SCWebSession.alloc
                                         initSessionTaskWithHttpMethod: @"GET"
                                         url: [NSURL URLWithString:urlString]
                                         keyHashArray:[self hashsForNetworkID: user.networkID]
                                         requestDict: NULL
                                         completionBlock:^(NSError *error, NSData *data) {
                                             
                                             if(error)
                                             {
                                                 if(completion)
                                                     (completion)(error, NULL);
                                             }
                                             else
                                             {
                                                 [self processJSONresponseData:data
                                                               completionBlock:^(NSError *error, NSDictionary *infoDict)
                                                  {
                                                      if(completion)
                                                          (completion)(error, infoDict);
                                                  }];
                                             }
                                         }];
             
             [self addOperationToQueue:operation forNetworkID:user.networkID];
         }
     }];
}

*/

- (void)recordPaymentReceipt:(NSString *)receipt
                     forUser:(STUser *)user
             completionBlock:(void (^)(NSError *error, NSDictionary *jsonDict))completion
{
	DDLogTrace(@"recordPaymentReceipt:(%lu bytes) forUser:%@ completionBlock:",
	             (unsigned long)[receipt length], user.jid);
	
	NSString *username = user.jid.user;
	
	[[SRVManager sharedInstance] brokerForNetworkID:user.networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/user/%@/purchase/appstore/",
			                      [username urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			
			NSDictionary *dict = @{
			  @"receipt": receipt,
			};
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:@"POST"
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:user.networkID]
			                                          requestDict:dict
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			[self addOperationToQueue:operation forNetworkID:user.networkID];
		}
	}];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - other
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setBlacklist:(NSDictionary *)blackList
        forLocalUser:(STLocalUser *)inLocalUser
     completionBlock:(void (^)(NSError *error, NSDictionary *jsonDict))completion
{
	DDLogAutoTrace();
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need a few fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	{
		if (srvError)
		{
			if (completion) {
				completion(srvError, nil);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/mute/?api_key=%@",
			                      [apiKey urlEncodedString]];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			
			SCWebSession *operation =
			  [[SCWebSession alloc] initSessionTaskWithHttpMethod:@"POST"
			                                                  url:[NSURL URLWithString:urlString]
			                                         keyHashArray:[self keyHashArrayForNetworkID:networkID]
			                                          requestDict:blackList
			                                      completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					if (completion) {
						completion(jsonError, jsonDict);
					}
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - SC Directory
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)searchUsers:(NSString *)searchS
	   forLocalUser:(STLocalUser *)inLocalUser
              limit:(int)limit
	completionBlock:(void (^)(NSError *error, NSArray *peopleList))completion {
	
//	DDLogVerbose(@"SCWebRequest searchUsers %@ %@", localUser.jid, searchS);
	if ([searchS length] < 2) {
		// The server does not accept 1-character queries.
		// And completionBlocks should ALWAYS be invoked asynchronously.
		dispatch_async(dispatch_get_main_queue(), ^{
			completion(nil, nil);
		});
		return;
	}
	
	// Snapshot just the information we need.
	// We do this because the broker request is asynchronous.
	//
	// Another option would be to copy/snapshot the user,
	// but since we only need a few fields, this route is just as easy (and retains less memory).
	//
	NSString *localUserID = inLocalUser.uuid;
	NSString *networkID   = inLocalUser.networkID;
	NSString *apiKey      = inLocalUser.apiKey;
	
	
	[[SRVManager sharedInstance] brokerForNetworkID:networkID completionBlock:
	    ^(NSError *srvError, NSString *host, NSString *hostIP, NSNumber *port)
	 {
		if (srvError)
		{
			if (completion) {
				completion(srvError, NULL);
			}
		}
		else
		{
			NSString *urlBase = [self encodeURLStringwithHost:host port:port];
			NSString *urlPath = [NSString stringWithFormat:@"/v1/people/?api_key=%@&terms=%@",
			                      [apiKey urlEncodedString],
			                      [searchS urlEncodedString]];
			
			// lock search down to my organization only:
			urlPath = [urlPath stringByAppendingString:@"&org_only=1"];
			if (limit > 0)
				urlPath = [urlPath stringByAppendingFormat:@"&max=%d", limit];
			
			NSString *urlString = [urlBase stringByAppendingString:urlPath];
			 
			SCWebSession *operation =
			 [[SCWebSession alloc] initSessionTaskWithHttpMethod:@"GET"
															 url:[NSURL URLWithString:urlString]
													keyHashArray:[self keyHashArrayForNetworkID:networkID]
													 requestDict:NULL
												 completionBlock:^(NSError *webError, NSData *data)
			{
				if (webError)
				{
					if (completion) {
						completion(webError, nil);
					}
				}
				else
				{
					NSError *jsonError = nil;
					NSDictionary *jsonDict = [self parseJsonResponseData:data error:&jsonError];
					
					NSArray *peopleList = nil;
					if (!jsonError) {
						NSString *result = [jsonDict objectForKey:@"result"];
						if ([@"success" isEqualToString:result]) {
							peopleList = [jsonDict objectForKey:@"people"];
						}
					}
					
					// sample:
					// "result": "success"
					//	"people": {
					//    "full_name" = "carl bentley";
					//    jid = "cb87@silentcircle.com";
					//    numbers =     (
					//				   "+442036954607"
					//				   );
					//    username = cb87;
					//	}
					NSMutableArray *resultList = nil;
					if (peopleList) {
						resultList = [NSMutableArray arrayWithCapacity:[peopleList count]];
						for (NSDictionary *personD in peopleList) {
							PersonSearchResult *person = [[PersonSearchResult alloc] initWithDict:personD];
							[resultList addObject:person];
						}
					}
					
					if (completion) {
						completion(jsonError, resultList);
					}
				
				}
			}];
			
			operation.localUserID = localUserID;
			[self addOperationToQueue:operation forNetworkID:networkID];
		}
	}];
}

@end
