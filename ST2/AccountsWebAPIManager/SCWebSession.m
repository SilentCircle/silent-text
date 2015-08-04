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
//  SCWebSession.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 10/28/13.
//

#import <CommonCrypto/CommonDigest.h>

#import "STLogging.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "SCWebSession.h"


#define NSLS_COMMON_CERT_FAILED                                                                       \
  NSLocalizedString(@"Certificate match error -- please update to the latest version of Silent Text", \
                    @"Certificate match error -- please update to the latest version of Silent Text")

#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)

@implementation SCWebSession
{
    NSString     * httpMethod;
    NSURL        * webURL;
    NSDictionary * webRequest;
    NSArray      * keyHashArray;
	
	SCWebSessionCompletionBlock completion;
	
	BOOL isExecuting;
	BOOL isFinished;
}

static const NSTimeInterval kTimeoutInterval = 30.0; // seconds

@synthesize localUserID = _useSelfDotSyntaxForAtomicProperty_localUserID;

- (id)initSessionTaskWithHttpMethod:(NSString *)methodIn
                                url:(NSURL *)urlIn
                       keyHashArray:(NSArray *)keyHashArrayIn
                        requestDict:(NSDictionary *)requestDictIn
                    completionBlock:(SCWebSessionCompletionBlock)completionIn
{
	if ((self = [super init]))
	{
		httpMethod    = [methodIn copy];
		webURL        = urlIn;
		webRequest    = requestDictIn;
		keyHashArray  = keyHashArrayIn;
		completion    = completionIn;
		
		isExecuting = NO;
		isFinished  = NO;
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Overriding NSOperation Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)start
{
    // Makes sure that start method always runs on the main thread.
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
	if (!webURL)
	{
		[self finish];
		return;
	}
    
	[self sessionTaskWithHttpMethod:httpMethod
	                            url:webURL
	                    requestDict:webRequest
	                completionBlock:completion];
}

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isExecuting
{
    return isExecuting;
}

- (BOOL)isFinished
{
    return isFinished;
}

- (void)finish
{
    webURL     = nil;
    webRequest = nil;
    completion = nil;
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    isExecuting = NO;
    isFinished  = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)notifyLocalUserActiveDeviceMayHaveChanged
{
	NSDictionary *userInfo = nil;
	
  	NSString *localUserID = self.localUserID;
	if (localUserID) {
		userInfo = @{ @"localUserID" : localUserID };
	}
	
	dispatch_block_t block = ^{
		
		[[NSNotificationCenter defaultCenter] postNotificationName:LocalUserActiveDeviceMayHaveChangedNotification
		                                                    object:nil
		                                                  userInfo:userInfo];
	};
	
	if ([NSThread isMainThread])
		block();
	else
		dispatch_async(dispatch_get_main_queue(), block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSURLConnectionDelegate methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSURLRequest *)createWebRequestWithURL:(NSURL *)url
                               webRequest:(NSDictionary *)dict
                               httpMethod:(NSString *)method
{
	NSMutableURLRequest *req = nil;
	NSData *requestData = nil;
    
    NSBundle *main = NSBundle.mainBundle;
    NSString *version = [main objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    NSString *build   = [main objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
    build = build?build:@"XXX";
    NSString *userAgent = [NSString stringWithFormat: @"SilentText %@ (%@)", version, build];
    
    req = [ NSMutableURLRequest requestWithURL:url];
    [req setHTTPMethod:method];
    
    req.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    req.timeoutInterval = kTimeoutInterval;
    
    if (dict && [NSJSONSerialization isValidJSONObject:dict])
    {
		requestData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:NULL];
    }
    
    [req setValue:userAgent forHTTPHeaderField:@"User-Agent"];
	[req setHTTPBody:requestData];
    
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"%ld", (unsigned long)[requestData length]] forHTTPHeaderField:@"Content-Length"];
    
    // I am not sure if this is already done for us?
    NSString *preferredLanguageCodes = [[NSLocale preferredLanguages] componentsJoinedByString:@", "];
	[req setValue:[NSString stringWithFormat:@"%@, en-us;q=0.8", preferredLanguageCodes] forHTTPHeaderField:@"Accept-Language" ];
    
    return req;
}

- (NSURLSessionConfiguration *)createWebRequestSessionConfigurationWithData:(NSData *)requestData
{
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *version = [mainBundle objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    NSString *build   = [mainBundle objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
    if (build == nil) build = @"XXX";
	
	NSString *userAgent = [NSString stringWithFormat:@"SilentText %@ (%@)", version, build];
	NSString *preferredLanguageCodes = [[NSLocale preferredLanguages] componentsJoinedByString:@", "];
    
    [sessionConfig setHTTPAdditionalHeaders:@{
	  @"Accept":           @"application/json",
      @"Content-Type":     @"application/json; charset=utf-8",
      @"User-Agent":       userAgent,
      @"Content-Length":   [NSString stringWithFormat:@"%ld",  (unsigned long)[requestData length] ],
      @"Accept-Language":  [NSString stringWithFormat:@"%@, en-us;q=0.8", preferredLanguageCodes]
	}];
    
    sessionConfig.timeoutIntervalForRequest = kTimeoutInterval;
    sessionConfig.timeoutIntervalForResource = kTimeoutInterval;
    sessionConfig.HTTPMaximumConnectionsPerHost = 1;
    sessionConfig.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
    sessionConfig.allowsCellularAccess = YES;
    
	return sessionConfig;
}


- (void)sessionTaskWithHttpMethod:(NSString *)method
                              url:(NSURL *)url
                      requestDict:(NSDictionary *)requestDictIn
                  completionBlock:(SCWebSessionCompletionBlock)completionBlock
{
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                          delegate:self
                                                     delegateQueue:nil];
    
    NSURLRequest *request = [self createWebRequestWithURL:url
                                               webRequest:requestDictIn
                                               httpMethod:method];
    
    NSURLSessionDataTask *dataTask =
	  [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
	{
		if (error)
		{
			if (error.domain == NSURLErrorDomain && error.code == kCFURLErrorUserCancelledAuthentication)
			{
				NSDictionary *details = @{ NSLocalizedDescriptionKey: NSLS_COMMON_CERT_FAILED };
				
				error = [NSError errorWithDomain:NSURLErrorDomain
											code:kCFURLErrorClientCertificateRejected
										userInfo:details];
			}
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				if (completionBlock) {
					completionBlock(error, nil);
				}
				[self finish];
			});
		}
		else
		{
			NSInteger statusCode = 0;
			
			if ([response isKindOfClass:[NSHTTPURLResponse class]])
			{
				statusCode = [(NSHTTPURLResponse *)response statusCode];
			}
			
			// Example HTTP Status Codes:
			//
			// 200 OK
			// 400 Bad Request
			// 401 Unauthorized (bad username or password)
			// 403 Forbidden
			// 404 Not Found
			// 502 Bad Gateway
			// 503 Service Unavailable
			
			if (statusCode != 200)
			{
				NSMutableDictionary *details = [NSMutableDictionary dictionaryWithCapacity:2];
				
				NSString *statusCodeStr = [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
				if (statusCodeStr)
				{
					details[NSLocalizedDescriptionKey] = statusCodeStr;
				}
				
				if (data.length > 0)
				{
					NSString *serverMsg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
					if (serverMsg)
					{
						details[@"response"] = serverMsg;
					}
				}
				
				error = [NSError errorWithDomain:NSURLErrorDomain code:statusCode userInfo:details];
				
				dispatch_async(dispatch_get_main_queue(), ^{
				
					// The WEB server is not reliable enough to use this hook.
					//
					// It appears there may be a cache in use that remains stale
					// for a bit shortly after re-authorizing a device.
					// Then end result being that we get a bunch of 403 errors from the server.
					//
				//	if (statusCode == 403) {
				//		[self notifyLocalUserActiveDeviceMayHaveChanged];
				//	}
					
					if (completionBlock) {
						completionBlock(error, NULL);
					}
					[self finish];
				});
			}
			else
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					
					if (completionBlock) {
						completionBlock(nil, data);
					}
					[self finish];
				});
			}
		}
		
	}];
	
	[dataTask resume];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSURLConnectionDelegate credential code
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
   
    NSURLCredential*  credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
    
	if (!keyHashArray || keyHashArray.count == 0)
    {
		if (completionHandler) {
			completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
		}
	}
    else
    {
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
        {
			BOOL hash_matches = NO;
            
            SecTrustRef trust = [challenge.protectionSpace serverTrust];
            SecCertificateRef certificate = SecTrustGetCertificateAtIndex(trust, 0);
            
            NSData* serverCertificateData = (__bridge_transfer NSData*)SecCertificateCopyData(certificate);
            NSData* keyHash = [STAppDelegate getPubKeyHashForCertificate: serverCertificateData];
            
            if(keyHash)
            {
                for(NSData* hashData in keyHashArray)
                {
                    if((hashData.length == keyHash.length)
                       && CMP(keyHash.bytes, hashData.bytes, hashData.length))
                    {
                        hash_matches = YES;
                        break;
                    }
                }
            }
            
			if (hash_matches)
			{
				if (completionHandler) {
					completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
				}
			}
			else
			{
				if (completionHandler) {
					completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, NULL);
				}
			}
		}
		else if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodClientCertificate])
        {
			if (completionHandler) {
				completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, NULL);
			}
		}
	}
}

@end
