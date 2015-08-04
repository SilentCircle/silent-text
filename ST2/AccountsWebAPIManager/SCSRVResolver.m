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
//  SCSRVResolver.h
//
//  Originally created by Eric Chamberlain on 6/15/10.
//  Based on SRVResolver by Apple, Inc.
//

#import "SCSRVResolver.h"
#import "XMPPLogging.h"

#include <dns_util.h>
#include <stdlib.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

/**
 * Does ARC support support GCD objects?
 * It does if the minimum deployment target is iOS 6+ or Mac OS X 10.8+
**/
#if TARGET_OS_IPHONE

  // Compiling for iOS

  #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 // iOS 6.0 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else                                         // iOS 5.X or earlier
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1
  #endif

#else

  // Compiling for Mac OS X

  #if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080     // Mac OS X 10.8 or later
    #define NEEDS_DISPATCH_RETAIN_RELEASE 0
  #else
    #define NEEDS_DISPATCH_RETAIN_RELEASE 1     // Mac OS X 10.7 or earlier
  #endif

#endif

NSString *const SCSRVResolverErrorDomain = @"SCSRVResolverErrorDomain";

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SCSRVRecord ()

@property(nonatomic, assign) NSUInteger srvResultsIndex;
@property(nonatomic, assign) NSUInteger sum;

- (NSComparisonResult)compareByPriority:(SCSRVRecord *)aRecord;

@end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation SCSRVResolver

- (id)initWithDelegate:(id)aDelegate delegateQueue:(dispatch_queue_t)dq resolverQueue:(dispatch_queue_t)rq
{
	NSParameterAssert(aDelegate != nil);
	NSParameterAssert(dq != NULL);
	
	if ((self = [super init]))
	{
		XMPPLogTrace();
		
		delegate = aDelegate;
		delegateQueue = dq;
		
		#if NEEDS_DISPATCH_RETAIN_RELEASE
		dispatch_retain(delegateQueue);
		#endif
		
		if (rq)
		{
			resolverQueue = rq;
			#if NEEDS_DISPATCH_RETAIN_RELEASE
			dispatch_retain(resolverQueue);
			#endif
		}
		else
		{
			resolverQueue = dispatch_queue_create("SCSRVResolver", NULL);
		}
		
		resolverQueueTag = &resolverQueueTag;
		dispatch_queue_set_specific(resolverQueue, resolverQueueTag, resolverQueueTag, NULL);
		
		results = [[NSMutableArray alloc] initWithCapacity:2];
	}
	return self;
}

- (void)dealloc
{
	XMPPLogTrace();
	
    [self stop];
	
	#if NEEDS_DISPATCH_RETAIN_RELEASE
	if (resolverQueue)
		dispatch_release(resolverQueue);
	#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@dynamic srvName;
@dynamic timeout;
@dynamic userObject;

- (id)userObject
{
	__block id result = nil;
	
	dispatch_block_t block = ^{
		result =  userObject?[userObject copy]:NULL;
	};
	
	if (dispatch_get_specific(resolverQueueTag))
		block();
	else
		dispatch_sync(resolverQueue, block);
	
	return result;
}

- (NSString *)srvName
{
	__block NSString *result = nil;
	
	dispatch_block_t block = ^{
		result = [srvName copy];
	};
	
	if (dispatch_get_specific(resolverQueueTag))
		block();
	else
		dispatch_sync(resolverQueue, block);
	
	return result;
}

- (NSTimeInterval)timeout
{
	__block NSTimeInterval result = 0.0;
	
	dispatch_block_t block = ^{
		result = timeout;
	};
	
	if (dispatch_get_specific(resolverQueueTag))
		block();
	else
		dispatch_sync(resolverQueue, block);
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)sortResults
{
	NSAssert(dispatch_get_specific(resolverQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	// Sort results
	NSMutableArray *sortedResults = [NSMutableArray arrayWithCapacity:[results count]];
	
	// Sort the list by priority (lowest number first)
	[results sortUsingSelector:@selector(compareByPriority:)];
	
	/* From RFC 2782
	 * 
	 * For each distinct priority level
	 * While there are still elements left at this priority level
	 * 
	 * Select an element as specified above, in the
	 * description of Weight in "The format of the SRV
	 * RR" Section, and move it to the tail of the new
	 * list.
	 * 
	 * The following algorithm SHOULD be used to order
	 * the SRV RRs of the same priority:
	 */
	
	NSUInteger srvResultsCount;
	
	while ([results count] > 0)
	{
		srvResultsCount = [results count];
		
		if (srvResultsCount == 1)
		{
			SCSRVRecord *srvRecord = [results objectAtIndex:0];
			
			[sortedResults addObject:srvRecord];
			[results removeObjectAtIndex:0];
		}
		else // (srvResultsCount > 1)
		{
			// more than two records so we need to sort
			
			/* To select a target to be contacted next, arrange all SRV RRs
			 * (that have not been ordered yet) in any order, except that all
			 * those with weight 0 are placed at the beginning of the list.
			 * 
			 * Compute the sum of the weights of those RRs, and with each RR
			 * associate the running sum in the selected order.
			 */
			
			NSUInteger runningSum = 0;
			NSMutableArray *samePriorityRecords = [NSMutableArray arrayWithCapacity:srvResultsCount];
			
			SCSRVRecord *srvRecord = [results objectAtIndex:0];
			
			NSUInteger initialPriority = srvRecord.priority;
			NSUInteger index = 0;
			
			do
			{
				if (srvRecord.weight == 0)
				{
					// add to front of array
					[samePriorityRecords insertObject:srvRecord atIndex:0];
					
					srvRecord.srvResultsIndex = index;
					srvRecord.sum = 0;
				}
				else
				{
					// add to end of array and update the running sum
					[samePriorityRecords addObject:srvRecord];
					
					runningSum += srvRecord.weight;
					
					srvRecord.srvResultsIndex = index;
					srvRecord.sum = runningSum;
				}
				
				if (++index < srvResultsCount)
				{
					srvRecord = [results objectAtIndex:index];
				}
				else
				{
					srvRecord = nil;
				}
				
			} while(srvRecord && (srvRecord.priority == initialPriority));
			
			/* Then choose a uniform random number between 0 and the sum computed
			 * (inclusive), and select the RR whose running sum value is the
			 * first in the selected order which is greater than or equal to
			 * the random number selected.
			 */
			
			NSUInteger randomIndex = arc4random() % (runningSum + 1);
			
			for (srvRecord in samePriorityRecords)
			{
				if (srvRecord.sum >= randomIndex)
				{
					/* The target host specified in the
					 * selected SRV RR is the next one to be contacted by the client.
					 * Remove this SRV RR from the set of the unordered SRV RRs and
					 * apply the described algorithm to the unordered SRV RRs to select
					 * the next target host.  Continue the ordering process until there
					 * are no unordered SRV RRs.  This process is repeated for each
					 * Priority.
					 */
					
					[sortedResults addObject:srvRecord];
					[results removeObjectAtIndex:srvRecord.srvResultsIndex];
					
					break;
				}
			}
		}
	}
	
	results = sortedResults;
	
	XMPPLogVerbose(@"%@: Sorted results:\n%@", THIS_FILE, results);
}

- (void)succeed
{
	NSAssert(dispatch_get_specific(resolverQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace();
	
	[self sortResults];
	
	id theDelegate = delegate;
	NSArray *records = [results copy];
	
	dispatch_async(delegateQueue, ^{ @autoreleasepool {
		
		SEL selector = @selector(srvResolver:didResolveRecords:);
		
		if ([theDelegate respondsToSelector:selector])
		{
			[theDelegate srvResolver:self didResolveRecords:records];
		}
		else
		{
			XMPPLogWarn(@"%@: delegate doesn't implement %@", THIS_FILE, NSStringFromSelector(selector));
		}
		
	}});
	
	[self stop];
}

- (void)failWithError:(NSError *)error
{
	NSAssert(dispatch_get_specific(resolverQueueTag), @"Invoked on incorrect queue");
	
	XMPPLogTrace2(@"%@: %@ %@", THIS_FILE, THIS_METHOD, error);
	
	id theDelegate = delegate;
	
    if (delegateQueue != NULL)
	{
		dispatch_async(delegateQueue, ^{ @autoreleasepool {
			
			SEL selector = @selector(srvResolver:didNotResolveDueToError:);
			
			if ([theDelegate respondsToSelector:selector])
			{
				[theDelegate srvResolver:self didNotResolveDueToError:error];
			}
			else
			{
				XMPPLogWarn(@"%@: delegate doesn't implement %@", THIS_FILE, NSStringFromSelector(selector));
			}
			
		}});
	}
	
	[self stop];
}

- (void)failWithDNSError:(DNSServiceErrorType)sdErr
{
	XMPPLogTrace2(@"%@: %@ %i", THIS_FILE, THIS_METHOD, (int)sdErr);
	
	[self failWithError:[NSError errorWithDomain:SCSRVResolverErrorDomain code:sdErr userInfo:nil]];
}

- (SCSRVRecord *)processRecord:(const void *)rdata length:(uint16_t)rdlen
{
	XMPPLogTrace();
	
	// Note: This method is almost entirely from Apple's sample code.
	// 
	// Otherwise there would be a lot more comments and explanation...
	
	if (rdata == NULL)
	{
		XMPPLogWarn(@"%@: %@ - rdata == NULL", THIS_FILE, THIS_METHOD);
		return nil;
	}
	
	// Rather than write a whole bunch of icky parsing code, I just synthesise
	// a resource record and use <dns_util.h>.
	
	SCSRVRecord *result = nil;
	
	NSMutableData *         rrData;
	dns_resource_record_t * rr;
	uint8_t                 u8;   // 1 byte
	uint16_t                u16;  // 2 bytes
	uint32_t                u32;  // 4 bytes
	
	rrData = [NSMutableData dataWithCapacity:(1 + 2 + 2 + 4 + 2 + rdlen)];
	
	u8 = 0;
	[rrData appendBytes:&u8 length:sizeof(u8)];
	u16 = htons(kDNSServiceType_SRV);
	[rrData appendBytes:&u16 length:sizeof(u16)];
	u16 = htons(kDNSServiceClass_IN);
	[rrData appendBytes:&u16 length:sizeof(u16)];
	u32 = htonl(666);
	[rrData appendBytes:&u32 length:sizeof(u32)];
	u16 = htons(rdlen);
	[rrData appendBytes:&u16 length:sizeof(u16)];
	[rrData appendBytes:rdata length:rdlen];
	
	// Parse the record.
	
	rr = dns_parse_resource_record([rrData bytes], (uint32_t) [rrData length]);
    if (rr != NULL)
	{
        NSString *host;
        
        host = [NSString stringWithCString:rr->data.SRV->target encoding:NSASCIIStringEncoding];
        if (host != nil)
		{
			UInt16 priority = rr->data.SRV->priority;
			UInt16 weight   = rr->data.SRV->weight;
			UInt16 port     = rr->data.SRV->port;
			
			result = [SCSRVRecord recordWithPriority:priority weight:weight port:port host:host];
        }
		
        dns_free_resource_record(rr);
    }
	
	return result;
}

static void QueryRecordCallback(DNSServiceRef       sdRef,
                                DNSServiceFlags     flags,
                                uint32_t            interfaceIndex,
                                DNSServiceErrorType errorCode,
                                const char *        fullname,
                                uint16_t            rrtype,
                                uint16_t            rrclass,
                                uint16_t            rdlen,
                                const void *        rdata,
                                uint32_t            ttl,
                                void *              context)
{
	// Called when we get a response to our query.  
	// It does some preliminary work, but the bulk of the interesting stuff 
	// is done in the processRecord:length: method.
	
    SCSRVResolver *resolver = (__bridge SCSRVResolver *)context;
	
	NSCAssert(dispatch_get_specific(resolver->resolverQueueTag), @"Invoked on incorrect queue");
    
	XMPPLogCTrace();
	
	if (!(flags & kDNSServiceFlagsAdd))
	{
		// If the kDNSServiceFlagsAdd flag is not set, the domain information is not valid.
		return;
    }

    if (errorCode == kDNSServiceErr_NoError &&
        rrtype == kDNSServiceType_SRV)
    {
        SCSRVRecord *record = [resolver processRecord:rdata length:rdlen];
        if (record)
        {
            [resolver->results addObject:record];
        }

        if ( ! (flags & kDNSServiceFlagsMoreComing) )
        {
            [resolver succeed];
        }    
    }
    else
    {
        [resolver failWithDNSError:errorCode];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)startWithSRVName:(NSString *)aSRVName timeout:(NSTimeInterval)aTimeout userObject:(id)aUserObject
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (resolveInProgress)
		{
			return;
		}
		
		XMPPLogTrace2(@"%@: startWithSRVName:%@ timeout:%f", THIS_FILE, aSRVName, aTimeout);
		
		// Save parameters
		
 		srvName = [aSRVName copy];
		
		timeout = aTimeout;
        
        userObject = aUserObject?[aUserObject copy]:NULL;
        
		
		// Check parameters
		
		const char *srvNameCStr = [srvName cStringUsingEncoding:NSASCIIStringEncoding];
		if (srvNameCStr == NULL)
		{
			[self failWithDNSError:kDNSServiceErr_BadParam];
			return;
			
		}
		
		// Create DNS Service
		
		DNSServiceErrorType sdErr;
		sdErr = DNSServiceQueryRecord(&sdRef,                              // Pointer to unitialized DNSServiceRef
		                              kDNSServiceFlagsReturnIntermediates, // Flags
		                              kDNSServiceInterfaceIndexAny,        // Interface index
		                              srvNameCStr,                         // Full domain name
		                              kDNSServiceType_SRV,                 // rrtype
		                              kDNSServiceClass_IN,                 // rrclass
		                              QueryRecordCallback,                 // Callback method
		                              (__bridge void *)self);              // Context pointer
		
		if (sdErr != kDNSServiceErr_NoError)
		{
			[self failWithDNSError:sdErr];
			return;
		}
		
		// Extract unix socket (so we can poll for events)
		
		sdFd = DNSServiceRefSockFD(sdRef);
		if (sdFd < 0)
		{
			// Todo...
		}
		
		// Create GCD read source for sd file descriptor
		
		sdReadSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, sdFd, 0, resolverQueue);
		
		dispatch_source_set_event_handler(sdReadSource, ^{ @autoreleasepool {
			
			XMPPLogVerbose(@"%@: sdReadSource_eventHandler", THIS_FILE);
			
			// There is data to be read on the socket (or an error occurred).
			// 
			// Invoking DNSServiceProcessResult will invoke our QueryRecordCallback,
			// the callback we set when we created the sdRef.
			
			DNSServiceErrorType dnsErr = DNSServiceProcessResult(sdRef);
			if (dnsErr != kDNSServiceErr_NoError)
			{
				[self failWithDNSError:dnsErr];
			}
			
		}});
		
		#if NEEDS_DISPATCH_RETAIN_RELEASE
		dispatch_source_t theSdReadSource = sdReadSource;
		#endif
		DNSServiceRef theSdRef = sdRef;
		
		dispatch_source_set_cancel_handler(sdReadSource, ^{ @autoreleasepool {
			
			XMPPLogVerbose(@"%@: sdReadSource_cancelHandler", THIS_FILE);
			
			#if NEEDS_DISPATCH_RETAIN_RELEASE
			dispatch_release(theSdReadSource);
			#endif
			DNSServiceRefDeallocate(theSdRef);
			
		}});
		
		dispatch_resume(sdReadSource);
		
		// Create timer (if requested timeout > 0)
		
		if (timeout > 0.0)
		{
			timeoutTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, resolverQueue);
			
			dispatch_source_set_event_handler(timeoutTimer, ^{ @autoreleasepool {
				
				NSString *errMsg = @"Operation timed out";
				NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
				
				NSError *err = [NSError errorWithDomain:SCSRVResolverErrorDomain code:0 userInfo:userInfo];
				
				[self failWithError:err];
				
			}});
			
			dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (timeout * NSEC_PER_SEC));
			
			dispatch_source_set_timer(timeoutTimer, tt, DISPATCH_TIME_FOREVER, 0);
			dispatch_resume(timeoutTimer);
		}
		
		resolveInProgress = YES;
	}};
	
	if (dispatch_get_specific(resolverQueueTag))
		block();
	else
		dispatch_async(resolverQueue, block);
}

- (void)stop
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		XMPPLogTrace();
		
		delegate = nil;
		if (delegateQueue)
		{
			#if NEEDS_DISPATCH_RETAIN_RELEASE
			dispatch_release(delegateQueue);
			#endif
			delegateQueue = NULL;
		}
		
		[results removeAllObjects];
		
		if (sdReadSource)
		{
			// Cancel the readSource.
			// It will be released from within the cancel handler.
			dispatch_source_cancel(sdReadSource);
			sdReadSource = NULL;
			sdFd = -1;
			
			// The sdRef will be deallocated from within the cancel handler too.
			sdRef = NULL;
		}
		
		if (timeoutTimer)
		{
			dispatch_source_cancel(timeoutTimer);
			#if NEEDS_DISPATCH_RETAIN_RELEASE
			dispatch_release(timeoutTimer);
			#endif
			timeoutTimer = NULL;
		}
		
		resolveInProgress = NO;
	}};
	
	if (dispatch_get_specific(resolverQueueTag))
		block();
	else
		dispatch_sync(resolverQueue, block);
}
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation SCSRVRecord

@synthesize priority;
@synthesize weight;
@synthesize port;
@synthesize host;
@synthesize hostIP;

@synthesize sum;
@synthesize srvResultsIndex;


+ (SCSRVRecord *)recordWithPriority:(UInt16)p1 weight:(UInt16)w port:(UInt16)p2 host:(NSString *)t
{
	return [[SCSRVRecord alloc] initWithPriority:p1 weight:w port:p2 host:t];
}

- (id)initWithPriority:(UInt16)p1 weight:(UInt16)w port:(UInt16)p2 host:(NSString *)t
{
	if ((self = [super init]))
	{
		priority = p1;
		weight   = w;
		port     = p2;
		host   = [t copy];
		
		sum = 0;
		srvResultsIndex = 0;
	}
	return self;
}


- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@:%p host(%@) port(%hu) priority(%hu) weight(%hu)>",
			NSStringFromClass([self class]), self, host, port, priority, weight];
}

- (NSComparisonResult)compareByPriority:(SCSRVRecord *)aRecord
{
	UInt16 mPriority = self.priority;
	UInt16 aPriority = aRecord.priority;
	
	if (mPriority < aPriority)
		return NSOrderedAscending;
	
	if (mPriority > aPriority)
		return NSOrderedDescending;
	
	return NSOrderedSame;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
        priority    = [decoder decodeIntForKey:@"priority"];
        weight      = [decoder decodeIntForKey:@"weight"];
        port        = [decoder decodeIntForKey:@"port"];
        host        = [decoder decodeObjectForKey:@"host"];
        hostIP        = [decoder decodeObjectForKey:@"hostIP"];
    	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:priority forKey:@"priority"];
    [coder encodeInt:weight forKey:@"weight"];
    [coder encodeInt:port forKey:@"port"];
    [coder encodeObject:host forKey:@"host"];
    [coder encodeObject:hostIP forKey:@"hostIP"];
    
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	SCSRVRecord* copy = [[[self class] alloc] init];
	
	copy->priority = priority;
 	copy->weight = weight;
 	copy->port = port;
 	copy->host = host;
 	copy->hostIP = hostIP;
  	return copy;
}




@end
