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
//
//  AsyncS3uploader.m
//  SilentText
//
#import "STLogging.h"

#import "AsyncS3uploader.h"
#import "AppConstants.h"


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

static const NSInteger kMaxRetries  = 3;

@interface AsyncS3uploader()
{
    
    BOOL           isExecuting;
    BOOL           isFinished;
}

@property (nonatomic, retain, readwrite) NSString   *locatorString;
@property (nonatomic, retain) NSURL                 *fileURL;
@property (nonatomic, retain) NSString              *urlString;
@property (nonatomic, assign) id                    userObject;

@property (nonatomic, retain) NSURLConnection   *connection;
@property (nonatomic, retain) NSInputStream    *stream;
@property (nonatomic, retain) NSURLRequest    *request;

@property (nonatomic)       NSInteger  bytesWritten;
@property (nonatomic)       NSInteger  fileSize;

@property (nonatomic)       NSInteger statusCode;
@property (nonatomic)       NSUInteger attemps;
 
@end

@implementation AsyncS3uploader

@synthesize userObject  = _userObject;
@synthesize locatorString  =  _locatorString;

#pragma mark - Class Lifecycle

- (id)initWithDelegate: (id)aDelegate
         locatorString:(NSString*)locatorString
               fileURL:(NSURL*)fileURL
            urlString:(NSString*)urlString
                object:(id)anObject
{
    self = [super init];
    if (self)
    {
        _delegate       = aDelegate;
        _locatorString  = locatorString;
        _fileURL       = fileURL;
        _urlString      = urlString;
        _userObject     = anObject;
        
         _bytesWritten  = 0;
        _fileSize       = 0;
        _attemps        = 0;
        
        isExecuting = NO;
        isFinished  = NO;
    }
    
    return self;
}



-(void)dealloc
{
    _delegate       = NULL;
    _urlString      = NULL;
    _locatorString  = NULL;
    _fileURL        = NULL;
    _request        = NULL;
}

#pragma mark - Utilitiy methods
 
- (NSMutableURLRequest *)createRequestUrl
{
      
    NSMutableURLRequest* request = [ NSMutableURLRequest requestWithURL:[NSURL URLWithString:_urlString]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:kSilentStorageS3Mime forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"public-read" forHTTPHeaderField:@"x-amz-acl"];
    
    [request setValue:[NSString stringWithFormat: @"%u", _fileSize] forHTTPHeaderField: @"Content-Length"];
    
//    [request  setHTTPShouldUsePipelining: NO];
    
    [request setTimeoutInterval: 2000 ];
     
       return request;
}


#pragma mark - Overwriding NSOperation Methods
-(void)start
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
    
    
    NSError*  error = NULL;
    
    BOOL exists = ([_fileURL checkResourceIsReachableAndReturnError:&error]
                   && !error
                   && [_fileURL isFileURL]);

    if(exists)
    {
        NSNumber* number = NULL;
        
        [_fileURL getResourceValue:&number forKey:NSURLFileSizeKey error:NULL];
        _fileSize = number.integerValue;
        
        [self performSelectorOnMainThread:@selector(didStart) withObject:nil waitUntilDone:NO];
        
        _stream = [[NSInputStream alloc] initWithURL:_fileURL ] ;
        [_stream open];
        
        NSMutableURLRequest *request = [self createRequestUrl];
        [request setHTTPBodyStream:_stream];
        
        _request = request;
        
        _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self];
        if (_connection)
            return;
    }
    
    [self finish];
    
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


#pragma mark - NSURLConnectionDelegate Implementations

- (NSInputStream *) connection: (NSURLConnection *) aConnection needNewBodyStream: (NSURLRequest *) request
{
    [NSThread sleepForTimeInterval: 2];
 
    NSInputStream* fileStream = [NSInputStream inputStreamWithURL:_fileURL];
    
    if (fileStream == nil)
    {
        DDLogError(@"NSURLConnection was asked to retransmit a new body stream for a request. Returning nil will cancel the connection.");
    }
    
    return fileStream;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    
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
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
     
    _bytesWritten =  totalBytesWritten;
    
    DDLogVerbose(@"%@ %ld bytes", _locatorString, (long)bytesWritten);
    
    
    [self performSelectorOnMainThread:@selector(updateProgress:)
                           withObject:[NSNumber numberWithLong:bytesWritten ]
                        waitUntilDone:NO];
    
     
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
     
    if(_statusCode == 200)
        [self performSelectorOnMainThread:@selector(didComplete:) withObject:nil waitUntilDone:NO];
    else
    {
    NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:[NSHTTPURLResponse localizedStringForStatusCode:(NSInteger)_statusCode] forKey:NSLocalizedDescriptionKey];
    
    NSError * error =
        [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorCannotCreateFile userInfo:details];
    
    [self performSelectorOnMainThread:@selector(didComplete:) withObject:[error copy] waitUntilDone:NO];

    }
    [self finish];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    
 //   NSURLRequestNetworkServiceType service =  [[connection  currentRequest ]networkServiceType];
    if(error && _attemps++ < kMaxRetries)
    {
        _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self];
 
        if(_connection) return;
     }

    [self performSelectorOnMainThread:@selector(didComplete:) withObject:[error copy]  waitUntilDone:NO];
        
    [self finish];
  
}

#pragma mark - Helper Methods

-(void)finish
{
    
    if(_stream)
        [_stream close];
  
    _connection = nil;
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    isExecuting = NO;
    isFinished  = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

-(void)didStart
{
    if(self.delegate)
    {
        [self.delegate AsyncS3uploader:self uploadDidStart:_locatorString ];
    }
}

-(void)updateProgress:(NSNumber *)bytesWritten
{
    
    if(self.delegate)
    {
        [self.delegate AsyncS3uploader:self uploadProgress:bytesWritten];
    }
    
    
}

-(void)didComplete:(NSError *)error
{
    
    if(self.delegate)
    {
        [self.delegate AsyncS3uploader:self uploadDidCompleteWithError:error];
    }
}



@end

