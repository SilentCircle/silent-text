/*
Copyright (C) 2013-2015, Silent Circle, LLC. All rights reserved.

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
#import "AsyncSCloudOp.h"
#import "SCloudObject.h"
#import "STLogging.h"


// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && vinnie_moscaritolo
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@implementation AsyncSCloudOp
{
	BOOL isExecuting;
	BOOL isFinished;
	BOOL isCancelled;
	
	NSUInteger _segmentsExpectedToRead;
	NSUInteger _segmentsRead;
	
	size_t _bytesExpectedToWrite;
	size_t _bytesWritten;
	
	NSMutableDictionary *_results;
	
	NSError *opError;
}

@synthesize delegate = _delegate;
@synthesize userObject = _userObject;

@synthesize scloud = _scloud;
@synthesize uploading = _uploading;


- (instancetype)initWithDelegate:(id)delegate
                      userObject:(id)userObject
                          scloud:(SCloudObject *)scloud
          segmentsExpectedToRead:(NSUInteger)segmentsExpectedToRead
{
	if ((self = [super init]))
	{
		_delegate = delegate;
        _scloud = scloud;
        _segmentsExpectedToRead = segmentsExpectedToRead;
        _userObject = userObject;
    }
    return self;
}

- (instancetype)initWithDelegate:(id)delegate
                      userObject:(id)userObject
                          scloud:(SCloudObject *)scloud
            bytesExpectedToWrite:(size_t)bytesExpectedToWrite
{
	if ((self = [super init]))
    {
		_delegate = delegate;
		_scloud = scloud;
		_bytesExpectedToWrite = bytesExpectedToWrite;
		_userObject = userObject;
		
		_results =  [[NSMutableDictionary alloc] init];
		_uploading = YES;
	}
	return self;
}

- (void)segmentDownloadWithError:(NSError *)error
{
    if(isCancelled)
        return;
    
    if(!_uploading)
    {
        _segmentsRead++;
        
        if(self.delegate )
        {
            if(error)
            {
                opError = error.copy;
                [self cancel];
                [self performSelectorOnMainThread:@selector(didComplete:) withObject:error waitUntilDone:NO];
            }
            else
            {
                 [self.delegate AsyncSCloudOp:self downloadProgress: (float)_segmentsRead / (float)_segmentsExpectedToRead ];
            }
        }
    }
    
   
}

- (void)reportRetry:(NSNumber *)attempts
{
    if(_uploading)
    {
        
        if(self.delegate )
        {
            [self.delegate AsyncSCloudOp:self uploadRetry:attempts  ];
        }
    }
    
}


- (void)updateProgress:(NSNumber *)bytesWritten
{
  
    if(_uploading)
    {
        _bytesWritten += [bytesWritten longValue];
        
        if(self.delegate )
        {
            [self.delegate AsyncSCloudOp:self uploadProgress: (float)_bytesWritten / (float)_bytesExpectedToWrite ];
        }
     }
     
}

-(void) didCompleteWithError:(NSError *)error  locatorString:(NSString*)locatorString
{
    if(error)
        [_results setObject: error forKey:locatorString];
    
}


#pragma mark - Overriding NSOperation Methods

-(void)start
{

    if ([self isCancelled])
    {
        return;
    }

    // Makes sure that start method always runs on the main thread.
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
     
    [self performSelectorOnMainThread:@selector(didComplete:) withObject:nil  waitUntilDone:NO];
    
    [self finish];
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

- (BOOL)isCancelled
{
	return isCancelled;
}

#pragma mark - Helper Methods

- (void)finish
{
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
	if (isExecuting) {
        isFinished = YES;
	}
	isExecuting = NO;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}


- (void)cancel
{
	for (NSOperation *child in self.dependencies)
	{
		[child cancel];
	//	[self removeDependency:child];
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isCancelled"];
    
    isCancelled = YES;
	isFinished = YES;
	isExecuting = NO;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    [self didChangeValueForKey:@"isCancelled"];
}

- (void)didComplete:(NSError *)errorIn
{
    NSError *error =  errorIn;

	if (self.delegate)
	{
		if (_uploading && [_results count])
		{
			NSString *key = [[_results allKeys] objectAtIndex:0];
			error = [_results objectForKey:key];
		}
        
		[self.delegate AsyncSCloudOp:self opDidCompleteWithError:error];
	}
}

@end

