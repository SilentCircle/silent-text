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
#import "S3DownloadOperation.h"

#import "AppConstants.h"
#import "AppDelegate.h"
#import "SCFileManager.h"
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


static const NSInteger kMaxRetries  = 3;

@implementation S3DownloadOperation
{
	BOOL isExecuting;
	BOOL isFinished;
	BOOL isCancelled;
	
	size_t  _bytesRead;
	size_t  _fileSize;
	
	NSURL           *_tempFileURL;
	NSURLConnection *_connection;
	NSOutputStream  *_stream;
	NSURLRequest    *_request;
	
	NSInteger _statusCode;
	NSUInteger _attemps;
}

@synthesize delegate = _delegate;
@synthesize userObject = _userObject;

@synthesize scloud = _scloud;
@synthesize locatorString = _locatorString;


#pragma mark - Class Lifecycle

- (instancetype)initWithDelegate:(id <S3DownloadOperationDelegate>)delegate
                      userObject:(id)userObject
                          scloud:(SCloudObject *)scloud
                   locatorString:(NSString *)locatorString
{
	if ((self = [super init]))
	{
		_delegate = delegate;
        _userObject = userObject;
		
		_scloud = scloud;
		_locatorString = locatorString;
    }
    return self;
}

#pragma mark - Overriding NSOperation Methods

- (void)start
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

//    DDLogPurple(@"%@ start", self.locatorString);
    [self willChangeValueForKey:@"isExecuting"];
    isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
 
    // no locator string indicates top locator
    if(!_locatorString)
        _locatorString = _scloud.locatorString;
    
    
    NSURL* fileURL = [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent:_locatorString];
    
    _tempFileURL = [fileURL URLByAppendingPathExtension:@"tmp"];
    
    _stream = [[NSOutputStream alloc] initWithURL:_tempFileURL append:NO] ;
    [_stream open];
    
    NSString *urlString = [NSString stringWithFormat:@"https://s3.amazonaws.com/%@/%@",
                           kSilentStorageS3Bucket, _locatorString];

    NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                              cachePolicy:NSURLRequestReloadIgnoringCacheData
                                          timeoutInterval:60.0];
    
    _request = request;
    
    _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self];
    if (_connection == nil)
    {
        [self finish];
        return;
    }    
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


-(BOOL)isCancelled
{
    return isCancelled;
}



#pragma mark - NSURLConnection Implementations

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
 
    if ([self isCancelled])
        return;
   
    if ([response isKindOfClass: [NSHTTPURLResponse class]]) {
        _statusCode = [(NSHTTPURLResponse*) response statusCode];
        /* HTTP Status Codes
         200 OK
         400 Bad Request
         401 Unauthorized (bad username or password)
         403 Forbidden
         404 Not Found
         502 Bad Gateway
         503 Service Unavailable
         */
    }

    _bytesRead = 0;
    _fileSize =  [response expectedContentLength] ;
    
    [self performSelectorOnMainThread:@selector(didStart) withObject:nil waitUntilDone:NO];
 }


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if ([self isCancelled])
        return;

    if(connection != _connection)  {
        return;
        }
    
    
    _bytesRead +=  [data length];
    
    if(data && [data length])
        [_stream write:[data bytes] maxLength:[data length]];

    
    [self performSelectorOnMainThread:@selector(updateProgress:)
                       withObject:[NSNumber numberWithFloat: ((float)_bytesRead/(float)_fileSize) ]
                        waitUntilDone:NO];

}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if ([self isCancelled])
        return;
  
    if(connection != _connection)  {
        return;
    }

    if(_statusCode == 200)
        [self performSelectorOnMainThread:@selector(didComplete:) withObject:nil waitUntilDone:NO];
    else
    {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        
        if(_statusCode == 403)
        {
            [details setValue: NSLocalizedString(@"SCloud file does not exist, please contact the sender ", @"SCloud file does not exist, please contact the sender")
                       forKey: NSLocalizedDescriptionKey];
        }
        else
        {
            [details setValue:[NSHTTPURLResponse localizedStringForStatusCode:(NSInteger)_statusCode] forKey:NSLocalizedDescriptionKey];
        }
        NSError * error =
        [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorFileDoesNotExist userInfo:details];
        
        [self performSelectorOnMainThread:@selector(didComplete:) withObject:[error copy] waitUntilDone:NO];
        
    }
    [self finish];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if(error && _attemps++ < kMaxRetries)
    {
        _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self];
        
        if(_connection) return;
    }
   
    [self performSelectorOnMainThread:@selector(didComplete:) withObject:[error copy]  waitUntilDone:NO];

	[self finish];
}



#pragma mark - Helper Methods

-(void) cancel
{
    if(_connection)
        [_connection cancel ];
    
    if(_stream)
        [_stream close];
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isCancelled"];
    [self willChangeValueForKey:@"isFinished"];
    
    isCancelled = YES;
    isFinished = YES;
    isExecuting = NO;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isCancelled"];
    [self willChangeValueForKey:@"isFinished"];
    
//    DDLogOrange(@"%@ canceled", self.locatorString);
    
}



-(void)finish
{
     NSError* error = NULL;
    
    if(_stream)
        [_stream close];
    
    if(_statusCode == 200)
    {
       if( _tempFileURL)
       {
           BOOL exists = ([_tempFileURL checkResourceIsReachableAndReturnError:&error]
                          && !error
                          && [_tempFileURL isFileURL]);
           if(exists)
           {
               NSURL* newURL = [_tempFileURL URLByDeletingPathExtension];
               
               [NSFileManager.defaultManager removeItemAtURL:newURL error:NULL];
               [NSFileManager.defaultManager moveItemAtURL:_tempFileURL toURL:newURL error:&error];
           }
           
       }
       }
    else
    {
        [NSFileManager.defaultManager removeItemAtURL:_tempFileURL error:&error];
    }
    
    
     _connection = nil;
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];

    isExecuting = NO;
    isFinished  = YES;

    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];

//    DDLogPurple(@"%@ finish", self.locatorString);
}

- (void)didStart
{
	[self.delegate S3DownloadOperation:self
	                  downloadDidStart:_locatorString
	                          fileSize:@(_fileSize)
	                        statusCode:_statusCode];
}

- (void)updateProgress:(NSNumber *)theProgress
{
	[self.delegate S3DownloadOperation:self downloadProgress:[theProgress floatValue]];
}

- (void)didComplete:(NSError *)error
{
	[self.delegate S3DownloadOperation:self downloadDidCompleteWithError:error];
}

@end
