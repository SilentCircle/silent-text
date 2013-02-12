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
//  SCBrokerRequest
//  SilentText
//

#include "SCpubTypes.h"

#import "AppConstants.h"
#import "App.h"
#import "ServiceCredential.h"
#import "StorageCipher.h"
#import <CommonCrypto/CommonDigest.h>
#import "RequestUtils.h"

#import "SCProvisoningManager.h"
#import "AsyncBrokerRequest.h"
#import "NSDate+SCDate.h"

//#define SIMULATE_BROKER

#ifdef SIMULATE_BROKER 
// ssimulate broker function
#include <tomcrypt.h>
#include "cryptowrappers.h"
#import "NSString+SCUtilities.h"

#endif

static const NSInteger kMaxRetries  = 3;

NSString *const kSCBroker_SignedURL      = @"signedURL";
 
static const NSTimeInterval kBrokerTimeoutValue  = 30.0;

@interface AsyncBrokerRequest ()
{
    
    BOOL           isExecuting;
    BOOL           isFinished;

}

@property (nonatomic, retain, readwrite) NSString   *dirPath ;
@property (nonatomic, retain, readwrite) NSDate     *shredDate ;
@property (nonatomic, retain, readwrite) NSArray     *locators ;
@property (nonatomic, assign)            NSURL       *brokerURL;
@property (nonatomic,  readwrite)       SCloudObject* scloud;

@property (nonatomic, assign) id          userObject;
@property (nonatomic)                     NSInteger         statusCode;
@property (nonatomic, retain)             NSURLConnection   *connection;
@property (nonatomic, retain)             NSMutableData*    responseData;
@property (nonatomic)                     SCBrokerOperation operation;
@property (nonatomic)                     size_t totalSize;

@property (nonatomic, retain)               NSURLRequest    *request;
@property (nonatomic)                       NSUInteger      attemps;

@end

@implementation AsyncBrokerRequest

 
#pragma mark - Class Lifecycle

-(id)initWithDelegate: (id)aDelegate
            operation:(SCBrokerOperation)operation
            brokerURL:(NSURL*)brokerURL
              scloud:(SCloudObject*) scloud
             locators:(NSArray*)locators
              dirPath:(NSString*)dirPath
            shredDate:(NSDate*)shredDate
                object:(id)anObject;
{
    self = [super init];
    if (self)
    {
        _delegate   = aDelegate;
        _brokerURL  = brokerURL;
        _scloud     = scloud;
        _operation  = operation;
        _locators   = locators;
        _dirPath    = dirPath;
        _shredDate  = shredDate;
        _userObject = anObject;
        _attemps        = 0;
        
          
        isExecuting = NO;
        isFinished  = NO;
        _totalSize = 0;
    }
    
    return self;
}

-(void)dealloc
{
    _brokerURL  = NULL;
    _delegate   = NULL;
    _locators   = NULL;
    _dirPath    = NULL;
    _shredDate  = NULL;
    _request    = NULL;

 }


#pragma warning write real broker query code here
 

-(NSData*) createBrokerRequestJSON
{
    NSMutableDictionary* brokerReqDict = [NSMutableDictionary dictionaryWithCapacity:3];
    
    NSString* shredDate = _shredDate?[_shredDate rfc3339String]:NULL;
    NSFileManager *fm = [NSFileManager defaultManager];
    
     NSString* apiString = [NSString stringWithUTF8String:[ [SCProvisoning apiKey] bytes]];
    
    [brokerReqDict setValue:apiString forKey:@"api_key"];
    
    if(_operation == kSCBrokerOperation_Upload)
    {
        [brokerReqDict setValue:@"upload" forKey:@"operation"];
    }
    else if(_operation == kSCBrokerOperation_Delete)
    {
        [brokerReqDict setValue:@"delete" forKey:@"operation"];
    }
    
    NSMutableDictionary* fileDict = [NSMutableDictionary dictionaryWithCapacity:_locators.count];
      
    for(NSString* locator in _locators)
    {
         NSDictionary* attributes =  [fm attributesOfItemAtPath:[_dirPath stringByAppendingPathComponent:locator]
                                                         error:nil];
        NSMutableDictionary* itemDict = [NSMutableDictionary dictionaryWithCapacity:2];
        
        NSNumber* fileSize = [attributes objectForKey:NSFileSize];
        _totalSize += [fileSize unsignedLongValue];
        [itemDict setValue:fileSize forKey:@"size"];
        
        if(shredDate) [itemDict setValue:shredDate forKey:@"shred_date"];
        
        [fileDict setValue:itemDict forKey:locator];
     }
    
    [brokerReqDict setValue:fileDict forKey:@"files"];
     
    NSData *data = ([NSJSONSerialization  isValidJSONObject: brokerReqDict] ?
                           [NSJSONSerialization dataWithJSONObject: brokerReqDict options: NSJSONWritingPrettyPrinted error: nil] :
                           nil);
    
    return data;
}

-(NSURLRequest *)createBrokerRequestUrl
{
    NSMutableURLRequest* request    = NULL;
     
    NSBundle *main = NSBundle.mainBundle;
    NSString *version = [main objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    NSString *build   = [main objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
    NSString *userAgent = [NSString stringWithFormat: @"SilentText %@ (%@)", version, build];
    
     request = [ NSMutableURLRequest requestWithURL:_brokerURL];
    [request setHTTPMethod:@"POST"];
    
     request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    request.timeoutInterval = kBrokerTimeoutValue;
      
    NSData *requestData = [self createBrokerRequestJSON  ];
    
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];

    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%d", [requestData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody: requestData];
    
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
    
    NSURLRequest * request = [self createBrokerRequestUrl];
    
    _request = request;
    
    _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self];
    
    if (_connection == nil)
    {
        [self finish];
        return;
    }
    
    [self performSelectorOnMainThread:@selector(didStart) withObject:nil waitUntilDone:NO];
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


-(void)finish
{
    _connection = nil;
    _responseData = NULL;

    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    isExecuting = NO;
    isFinished  = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}



#pragma mark - NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *) response
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
       
	_responseData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_responseData appendData:data];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    
    if(_statusCode == 200)
    {
//        NSString *requestStr = connection.originalRequest.URL.absoluteString;
//        NSDictionary *dict = [requestStr URLQueryParameters];
 //       NSString    *requestID = [dict valueForKey:@"request_id"];
        
        [self completeBrokerRequestWithData:self.responseData ];
        
    }
    else
    {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        NSString* error_message = _responseData && (_responseData.length > 0)
        ?   [NSString stringWithUTF8String:_responseData.bytes]
        :  [NSHTTPURLResponse localizedStringForStatusCode:(NSInteger)_statusCode];
        
        [details setValue:[NSString stringWithFormat:NSLS_COMMON_PROVISION_ERROR_DETAIL,error_message ]
                   forKey:NSLocalizedDescriptionKey];
        
        NSError * error =
            [NSError errorWithDomain:kSCErrorDomain code:kCFURLErrorCannotConnectToHost userInfo:details];
        
        [self performSelectorOnMainThread:@selector(didCompleteWithError:) withObject:error waitUntilDone:NO];

    }
    [self finish];
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
//    NSString *requestStr = connection.originalRequest.URL.absoluteString;
//    NSDictionary *dict = [requestStr URLQueryParameters];
    
     
    if(error.domain == NSURLErrorDomain && error.code == kCFURLErrorUserCancelledAuthentication)
    {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:NSLS_COMMON_CERT_FAILED forKey:NSLocalizedDescriptionKey];
        
        error = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorClientCertificateRejected userInfo:details];
    }
    else  if(error && _attemps++ < kMaxRetries)
    {
        _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self];
        
        if(_connection) return;
    }
     else  if(error)
     {
          NSMutableDictionary* details = [NSMutableDictionary dictionary];
         [details setValue:[NSString stringWithFormat:NSLS_COMMON_PROVISION_ERROR_DETAIL,  error.localizedDescription] forKey:NSLocalizedDescriptionKey];
         
          error = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorCannotConnectToHost userInfo:details];
         
     }
    
    [self performSelectorOnMainThread:@selector(didCompleteWithError:) withObject:error waitUntilDone:NO];

    [self finish];
}


#pragma mark - Helpers methods

- (void)completeBrokerRequestWithError:( NSError*)error
{
    
};

- (void)completeBrokerRequestWithData:(NSData *)data 
{
    NSError *jsonError;
    
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
     if (jsonError==nil){
        
        NSString *string = nil;
        
        if ((string = [info valueForKey:@"error_msg"])) {
            
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:string forKey:NSLocalizedDescriptionKey];
            
            NSError * error =
            [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorCannotConnectToHost userInfo:details];
            [self performSelectorOnMainThread:@selector(didCompleteWithError:) withObject:error waitUntilDone:NO];
        }
        else
        {
            __block NSMutableDictionary *brokerInfo = [NSMutableDictionary dictionaryWithCapacity:info.count];
             
            [info enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
                
                NSString* signedURL =  [obj valueForKey:@"url"];
                    
                [brokerInfo setValue:signedURL forKey: key];
            }];
                    
            [self performSelectorOnMainThread:@selector(didCompleteWithInfo:) withObject:brokerInfo waitUntilDone:NO];
        }
    }else
    {
        [self performSelectorOnMainThread:@selector(didCompleteWithError:) withObject:jsonError waitUntilDone:NO];

    }
    
}

#pragma mark - AsyncBrokerRequestDelegate callbacks

-(void)didCompleteWithInfo:(NSDictionary *)info
{
    
    if(self.delegate)
    {
        [self.delegate AsyncBrokerRequest:self operationCompletedWithWithError:nil
                                operation:_operation
                               totalBytes:_totalSize
                                     info:info];
    }
}


-(void)didCompleteWithError:(NSError *)error
{
    
    if(self.delegate)
    {
        [self.delegate AsyncBrokerRequest:self operationCompletedWithWithError:error
                                operation:_operation
                               totalBytes:0
                                   info:nil];
        
    }
}

-(void)didStart
{
    if(self.delegate)
    {
        [self.delegate AsyncBrokerRequest:self operationDidStart:_operation   ];
    }
}


#pragma mark - NSURLConnectionDelegate credential code

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust] || [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodDefault];
}


-(void)connection:(NSURLConnection *)connection
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
    {
        App *app = App.sharedApp;
        
        NSData* provisonCert = app.provisonCert ;
        
        uint8_t hash[CC_SHA1_DIGEST_LENGTH];
        uint8_t  provisonCertHash [CC_SHA1_DIGEST_LENGTH];
        
        SecTrustRef trust = [challenge.protectionSpace serverTrust];
        
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(trust, 0);
        
        NSData* serverCertificateData = (__bridge_transfer NSData*)SecCertificateCopyData(certificate);
        
        CC_SHA1([provisonCert bytes], [provisonCert length], provisonCertHash);
        CC_SHA1([serverCertificateData bytes], [serverCertificateData length], hash);
        
        if(CMP(hash,provisonCertHash, CC_SHA1_DIGEST_LENGTH))
        {
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
            
        }
        else
        {
            [[challenge sender] cancelAuthenticationChallenge:challenge];
        }
        
        
    }
}

#ifdef SIMULATE_BROKER
#pragma mark - ssimulate broker function


static NSString *S3key =  @"EGQztvi3en0g966QPHrk3pMaWKM7t27DXx/lPN0G";
static NSString *s3ID = @"AKIAJN4TGNBFQ4T762KQ";

- (NSString*) caclS3HMAC: (NSString*)keyString  signString:(NSString*) signString
{
 	NSString            *outString  = NULL;
    SCLError			err			= CRYPT_OK;
    MAC_ContextRef     hmac = kInvalidMAC_ContextRef;
    
    size_t				hashSize, resultLen;
    uint8_t              hmacBuf[64];
    
    char                HMACstr[64];
    size_t              hmacLen = sizeof(HMACstr);
    
    err  = MAC_Init(kMAC_Algorithm_HMAC, kHASH_Algorithm_SHA1, [keyString UTF8String], [keyString length],  &hmac); CKERR;
    
    err = MAC_HashSize(hmac,  &hashSize);CKERR;
    
    err  = MAC_Update( hmac,  [signString UTF8String],   [signString length]);CKERR;
    
    resultLen = hashSize;
    err  = MAC_Final( hmac, hmacBuf, &resultLen);CKERR;
    err = base64_encode(hmacBuf,resultLen, (uint8_t*)HMACstr,  &hmacLen); CKERR
    
    outString = [[NSString stringWithUTF8String:HMACstr ] urlEncodeString:NSASCIIStringEncoding];
    
done:
    
    if(!IsNull(hmac))
        MAC_Free(hmac);
    
    return outString;
}


- (NSString*) brokerUploadURLStringforLocator: (NSString*) locatorString
{
    NSString *urlString = NULL;
    
    NSString *resourceString = [NSString stringWithFormat:@"%@/%@", kSilentStorageS3Bucket, locatorString];
    
    NSDate *date = [NSDate date];
    NSTimeInterval expireTime = [date timeIntervalSince1970] + 300;
    NSString *expireString = [NSString stringWithFormat:@"%.0f",expireTime];
    
    NSString *signString = [NSString stringWithFormat:@"PUT\n\n%@\n%@\nx-amz-acl:public-read\n/%@",
                            kSilentStorageS3Mime, expireString,resourceString ];
    
    NSString *sigString = [self  caclS3HMAC:S3key signString:signString];
    
    urlString = [NSString stringWithFormat:@"https://s3.amazonaws.com/%@/%@?AWSAccessKeyId=%@&Expires=%@&Signature=%@",
                 kSilentStorageS3Bucket, locatorString, s3ID, expireString, sigString  ];
    
    return urlString;
}

- (NSString*) brokerDeleteURLStringforLocator: (NSString*) locatorString
{
    NSString *urlString = NULL;
    
    NSString *resourceString = [NSString stringWithFormat:@"%@/%@", kSilentStorageS3Bucket, locatorString];
    
    
    NSDate *date = [NSDate date];
    NSTimeInterval expireTime = [date timeIntervalSince1970] + 300;
    NSString *expireString = [NSString stringWithFormat:@"%.0f",expireTime];
    
    NSString *signString = [NSString stringWithFormat:@"DELETE\n\n\n%@\n/%@",
                            expireString,resourceString ];
    
    
    NSString *sigString = [self  caclS3HMAC:S3key signString:signString];
    
    urlString = [NSString stringWithFormat:@"https://s3.amazonaws.com/%@/%@?AWSAccessKeyId=%@&Expires=%@&Signature=%@",
                 kSilentStorageS3Bucket, locatorString, s3ID, expireString, sigString  ];
    
    
    return urlString;
}

#endif


@end

