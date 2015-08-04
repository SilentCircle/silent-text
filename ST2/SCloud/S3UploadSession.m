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
//  S3UploadSession.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 1/7/14.
//

#import "S3UploadSession.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "STLogging.h"
#import "DDXML.h"
#import "NSXMLElement+XMPP.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG && vinnie_moscaritolo
  static const int ddLogLevel = LOG_LEVEL_INFO; // | LOG_FLAG_TRACE;
#elif DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_WARN; // | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_WARN;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


static const NSInteger kMaxRetries = 3;

@implementation S3UploadSession
{
    BOOL isExecuting;
    BOOL isFinished;
    
	NSURL                  * _fileURL;
	NSMutableURLRequest    * _urlRequest;
	NSURLSessionUploadTask * _uploadTask;
	
    NSUInteger attempts;
	
	NSInteger statusCode;
	NSString *statusCodeString;
}

@synthesize delegate = _delegate;
@synthesize userObject = _userObject;

@synthesize locatorString = _locatorString;

#pragma mark - Class Lifecycle

- (instancetype)initWithDelegate:(id)delegate
                      userObject:(id)userObject
                   locatorString:(NSString *)locatorString
                         fileURL:(NSURL *)fileURL
                       urlString:(NSString *)urlString
{
	if ((self = [super init]))
	{
		_delegate = delegate;
		_userObject = userObject;
		
		_locatorString = locatorString;
		_fileURL       = fileURL;
		_urlRequest    = [self createRequestWithString:urlString fileURL:fileURL];
	}
	return self;
}

- (NSMutableURLRequest *)createRequestWithString:(NSString *)URLString fileURL:(NSURL*)fileURLIn
{
    NSMutableURLRequest*    request = NULL;
    NSError*                error = NULL;
    
    
    BOOL exists = ([fileURLIn checkResourceIsReachableAndReturnError:&error]
                   && !error
                   && [fileURLIn isFileURL]);
    
    if(exists)
    {
        NSNumber *number = nil;
        NSInteger fileSize = 0;
        
        [fileURLIn getResourceValue:&number forKey:NSURLFileSizeKey error:NULL];
        fileSize = number.integerValue;
        
        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
        [request setHTTPMethod:@"PUT"];
        [request setValue:kSilentStorageS3Mime forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"public-read" forHTTPHeaderField:@"x-amz-acl"];
        
		NSString *contentLength = [NSString stringWithFormat: @"%lu", (unsigned long)fileSize];
        [request setValue:contentLength forHTTPHeaderField: @"Content-Length"];
        [request setTimeoutInterval: 2000 ];
	}
	
	return request;
}

#pragma mark - Overriding NSOperation Methods

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
    
	if (!_urlRequest)
	{
		[self finish];
	}
    else
	{
		[self startUpload];
	}
}


- (void)startUpload
{
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                          delegate:self
                                                     delegateQueue:nil];
    
    statusCodeString = NULL;
    statusCode = 0;
    
    /* Completion handler blocks are not supported in background sessions. Use a delegate instead */
    
    _uploadTask = [session uploadTaskWithRequest:_urlRequest fromFile:_fileURL];
    
    [_uploadTask resume];
    
     DDLogPurple( @"STARTING SESSION: %@", _locatorString);
}

-(BOOL)isConcurrent
{
    return YES;
}

-(BOOL)isExecuting
{
    return isExecuting;
}

-(BOOL)isFinished
{
    return isFinished;
}

#pragma mark - NSURLSession delegate

/* Sent periodically to notify the delegate of upload progress.  This
 * information is also available as properties of the task.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                        didSendBodyData:(int64_t)bytesSent
                        totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
   
     DDLogPurple( @"totalBytesSent: %lld", bytesSent);
    
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithUnsignedLongLong:bytesSent ]
                        waitUntilDone:NO];
    

}


/* AWS uploads can return error status */

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    DDXMLDocument *doc = [[DDXMLDocument alloc] initWithData:data options:0 error:NULL];
    statusCodeString = [[[doc rootElement] elementForName:@"Code"] stringValue];
    
}


- (void)URLSession:(NSURLSession *)session  task:(NSURLSessionTask *)task
                            didCompleteWithError:(NSError *)error
{
    NSError* currentError = nil;
    
    if (error == nil)
    {
        if ([task.response isKindOfClass: [NSHTTPURLResponse class]])
        {
            statusCode = [(NSHTTPURLResponse*) task.response statusCode];
            
            if(statusCode == 200)
            {
                DDLogPurple( @"SESSION COMPLETE: %@", _locatorString);
            }
            else
            {
                DDLogRed( @"SESSION ERROR: %@ - %d %@", _locatorString, (int)statusCode, statusCodeString);
                
                if( [statusCodeString isEqualToString:@"RequestTimeout"])
                {
                    currentError = [STAppDelegate otherError: NSLocalizedString(@"Upload timeout", @"Upload timeout")];
                }
             }
        }
    }
    else
    {
        currentError = error;
    }
    
    if(currentError && attempts++ < kMaxRetries)
    {
        
        DDLogRed( @"SESSION RETRY: %@", _locatorString);
        
        [self performSelectorOnMainThread:@selector(uploadRetry:)
                               withObject:[NSNumber numberWithInteger:attempts]
                            waitUntilDone:NO];

        [self startUpload];
        return;
    }
    
    [self performSelectorOnMainThread:@selector(didComplete:) withObject:currentError  waitUntilDone:NO];
    
    [self finish];
}


- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    DDLogPurple(@"URLSessionDidFinishEventsForBackgroundURLSession");
    
}

#pragma mark - Helper Methods

- (void)finish
{
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    isExecuting = NO;
    isFinished  = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)didStart
{
	if (self.delegate)
	{
		[self.delegate S3UploadSession:self uploadDidStart:_locatorString ];
	}
}

-(void)updateProgress:(NSNumber *)bytesWritten
{
    
    if(self.delegate)
    {
        [self.delegate S3UploadSession:self uploadProgress:bytesWritten];
    }
    
    
}

-(void)didComplete:(NSError *)error
{
    
    if(self.delegate)
    {
        [self.delegate S3UploadSession:self uploadDidCompleteWithError:error];
    }
    
}

-(void)uploadRetry:(NSNumber *)numberofTries
{
    
    if(self.delegate)
    {
        [self.delegate S3UploadSession:self uploadRetry:numberofTries];
    }
    
    
}

@end
