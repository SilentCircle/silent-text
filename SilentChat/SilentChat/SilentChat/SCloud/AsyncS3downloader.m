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

#import "App+ApplicationDelegate.h"
#import "SCloudObject.h"
#import "AsyncS3downloader.h"
#import "AppConstants.h"

static const NSInteger kMaxRetries  = 3;

@interface AsyncS3downloader()
{
    
    BOOL           isExecuting;
    BOOL           isFinished;
}



@property (nonatomic, retain, readwrite) SCloudObject  *scloud;
@property (nonatomic, retain, readwrite) NSString       *locatorString;
@property (nonatomic, retain) NSString          *tempFilePath;
@property (nonatomic, retain) NSURLConnection   *connection;
@property (nonatomic, retain) NSOutputStream    *stream;
@property (nonatomic, retain) NSURLRequest    *request;
@property (nonatomic, assign) id                userObject;

 
@property (nonatomic)       size_t  bytesRead;
@property (nonatomic)       size_t  fileSize;

@property (nonatomic)       NSInteger statusCode;
@property (nonatomic)       NSUInteger attemps;

@end

@implementation AsyncS3downloader

@synthesize userObject  = _userObject;
@synthesize locatorString  =  _locatorString;

#pragma mark - Class Lifecycle

- (id)initWithDelegate: (id)aDelegate  scloud:(SCloudObject*) scloud locatorString:(NSString*)locatorString object:(id)anObject
{
    self = [super init];
    if (self)
    {
        
        _delegate       = aDelegate;
        _locatorString    = locatorString;
        _scloud           = scloud;
        _userObject     = anObject;
        _stream         = NULL;
        _bytesRead      = 0;
        _fileSize       = 0;
        _attemps        = 0;
        
        
        isExecuting = NO;
        isFinished  = NO;
    }
    
    return self;
}
     
 
 
-(void)dealloc
{
    _stream         = NULL;
    _delegate       = NULL;
    _locatorString  = NULL;
     _request        = NULL;

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
 
    // no locator string indicates top locator
    if(!_locatorString)
        _locatorString = _scloud.locatorString;
        
    NSString* dirPath = [App.sharedApp makeDirectory: kDirectoryMediaCache ];
    NSString*  filePath = [dirPath stringByAppendingPathComponent: _locatorString];
     
    _tempFilePath = [filePath stringByAppendingPathExtension:@"tmp"];
    
    [[NSFileManager defaultManager] createFileAtPath:_tempFilePath contents:nil attributes:nil];

    _stream = [[NSOutputStream alloc] initToFileAtPath:_tempFilePath append:NO] ;
    [_stream open];
    
    NSString *urlString = [NSString stringWithFormat:@"https://s3.amazonaws.com/%@/%@",
                           kSilentStorageS3Bucket, _locatorString];

    NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
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


#pragma mark - NSURLConnection Implementations

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

    _bytesRead = 0;
    _fileSize =  [response expectedContentLength] ;
     
    if(_fileSize == NSURLResponseUnknownLength)
    {
    // length is indeterminate?
    }
    
    [self performSelectorOnMainThread:@selector(didStart) withObject:nil waitUntilDone:NO];

    
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    _bytesRead +=  [data length];
    
    if(data && [data length])
        [_stream write:[data bytes] maxLength:[data length]];

    
    [self performSelectorOnMainThread:@selector(updateProgress:)
                       withObject:[NSNumber numberWithFloat: ((float)_bytesRead/(float)_fileSize) ]
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
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError* error = NULL;
    
    if(_stream)
        [_stream close];
    
    if(_statusCode == 200)
    {
       if( _tempFilePath && [fm fileExistsAtPath:_tempFilePath])
       {
           NSString* newPath = [_tempFilePath stringByDeletingPathExtension];
           if([fm fileExistsAtPath:newPath])
           {
                [fm removeItemAtPath:newPath error:nil];
           }
           
          [fm moveItemAtPath:_tempFilePath toPath:[_tempFilePath stringByDeletingPathExtension] error:&error];
       }
        
    }
    else
    {
         if( _tempFilePath && [fm fileExistsAtPath:_tempFilePath])
            [fm removeItemAtPath:_tempFilePath error:nil];
     }
    
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
        [self.delegate AsyncS3downloader:self downloadDidStart:_locatorString
                                fileSize:[NSNumber numberWithLongLong:_fileSize]
                              statusCode:_statusCode];
    }
 }

-(void)updateProgress:(NSNumber *)theProgress
{
      
    if(self.delegate)
    {
        [self.delegate AsyncS3downloader:self downloadProgress:[theProgress floatValue]];
    }
    

}

-(void)didComplete:(NSError *)error
{
    
    if(self.delegate)
    {
        [self.delegate AsyncS3downloader:self downloadDidCompleteWithError:error];
    }
}
 


@end
