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
//  SCloudSRVResolver.h
//

//  based on Robbie Hanson's XMPPSRVResolver.h
//  Originally created by Eric Chamberlain on 6/15/10.
//  Based on SRVResolver by Apple, Inc.
//  

#import <Foundation/Foundation.h>
#import <dns_sd.h>

extern NSString *const SCloudSRVResolverErrorDomain;


@interface SCloudSRVResolver : NSObject
{
	__unsafe_unretained id delegate;
	dispatch_queue_t delegateQueue;
	
	dispatch_queue_t resolverQueue;
	
	__strong NSString *srvName;
	NSTimeInterval timeout;
	
    BOOL resolveInProgress;
	
    NSMutableArray *results;
    DNSServiceRef sdRef;
	
	int sdFd;
	dispatch_source_t sdReadSource;
	dispatch_source_t timeoutTimer;
}

/**
 * The delegate & delegateQueue are mandatory.
 * The resolverQueue is optional. If NULL, it will automatically create it's own internal queue.
**/
- (id)initWithdDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq resolverQueue:(dispatch_queue_t)rq;

@property (strong, readonly) NSString *srvName;
@property (readonly) NSTimeInterval timeout;

- (void)startWithSRVName:(NSString *)aSRVName timeout:(NSTimeInterval)aTimeout;
- (void)stop;

 
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol SCloudSRVResolverDelegate

- (void)srvResolver:(SCloudSRVResolver *)sender didResolveRecords:(NSArray *)records;
- (void)srvResolver:(SCloudSRVResolver *)sender didNotResolveDueToError:(NSError *)error;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface ScloudSRVRecord : NSObject
{
	UInt16 priority;
	UInt16 weight;
	UInt16 port;
	NSString *target;
	
	NSUInteger sum;
	NSUInteger srvResultsIndex;
}

+ (ScloudSRVRecord *)recordWithPriority:(UInt16)priority weight:(UInt16)weight port:(UInt16)port target:(NSString *)target;

- (id)initWithPriority:(UInt16)priority weight:(UInt16)weight port:(UInt16)port target:(NSString *)target;

@property (nonatomic, readonly) UInt16 priority;
@property (nonatomic, readonly) UInt16 weight;
@property (nonatomic, readonly) UInt16 port;
@property (nonatomic, readonly) NSString *target;

@end
