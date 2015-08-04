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
#import "S3DeleteOperation.h"
#import "AppConstants.h"

static const NSInteger kMaxRetries = 3;

@implementation S3DeleteOperation
{
	BOOL isExecuting;
	BOOL isFinished;
	
	NSString *_urlString
	
	NSURLConnection *_connection;
	NSURLRequest    *_request;
	
	NSInteger _statusCode;
	NSUInteger _attempts;
}

@synthesize userObject  = _userObject;
@synthesize locatorString  =  _locatorString;

#pragma mark - Class Lifecycle

- (instancetype)initWithDelegate:(id <S3DeleteOperationDelegate>)delegate
                      userObject:(id)userObject
                   locatorString:(NSString *)locatorString
                       urlString:(NSString *)urlString
{
	if ((self = [super init]))
	{
		_delegate       = delegate;
		_userObject     = userObject;
		_locatorString  = locatorString;
		_urlString      = urlString;
	}
	return self;
}

- (NSMutableURLRequest *)createRequestUrl
{
    
    NSMutableURLRequest* request = [ NSMutableURLRequest requestWithURL:[NSURL URLWithString:_urlString]];
    [request setHTTPMethod:@"DELETE"];
    [request  setHTTPShouldUsePipelining: NO];
    
    [request setTimeoutInterval: 2000 ];
    
    [request  setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData];
    
     return request;
}


#pragma mark - Overriding NSOperation Methods

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
    
        
    [self performSelectorOnMainThread:@selector(didStart) withObject:nil waitUntilDone:NO];

    NSMutableURLRequest *request = [self createRequestUrl];

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


 
#pragma mark - NSURLConnectionDelegate Implementations

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
 
    if ([response isKindOfClass: [NSHTTPURLResponse class]]) {
        _statusCode = [(NSHTTPURLResponse*) response statusCode];
        /* HTTP Status Codes
         200 OK
         204 NO Content
         400 Bad Request
         401 Unauthorized (bad username or password)
         403 Forbidden
         404 Not Found
         502 Bad Gateway
         503 Service Unavailable
         */
    }
}

 
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
     
    if(_statusCode == 204)
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
    
    _connection = nil;
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    isExecuting = NO;
    isFinished  = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)didStart
{
	[self.delegate S3DeleteOperation:self deleteDidStart:_locatorString];
}

- (void)didComplete:(NSError *)error
{
	[self.delegate S3DeleteOperation:self deleteDidCompleteWithError:error];
}

@end
