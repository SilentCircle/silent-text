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
//  SCProvisoningManager.m
//  SilentText
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif


#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

#import "AppConstants.h"
#import "App.h"
#import "ServiceCredential.h"
#import "SCAccount.h"
#import "ConversationManager.h"
#import "NSManagedObjectContext+DDGManagedObjectContext.h"

#import "SCProvisoningManager.h"
#import "ServiceCredential.h"
 

static const NSTimeInterval kProvisonTimeoutValue  = 30.0;

@implementation NSString (URLEncoding)

- (NSString *) urlEncodeUsingEncoding {
    
    CFStringRef encodedString = NULL;
    
    encodedString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                            (__bridge CFStringRef)self,
                                                            NULL,
                                                            CFSTR("!*'\"();:@&=+$,/?%#[]%"),
                                                            kCFStringEncodingUTF8);
	return (__bridge_transfer NSString *)encodedString; // Equivalent to -autorelease.
    
} // -urlEncodeUsingEncoding

@end


@interface SCProvisoning ()

 

@property (nonatomic, strong) NSString *appIdentifier;

@property (nonatomic, retain) NSMutableData* responseData;

@property (nonatomic) SEL responseCallBack;

#define     kContinueActivation  (@selector(continueActivationWithAPIkey:))
#define     kCompleteActivation  (@selector(completeActivationWithData:))
 
@end

@implementation SCProvisoning

@synthesize responseData = _responseData;
@synthesize delegate = _delegate;
@synthesize appIdentifier = _appIdentifier;

static NSString *const kProvisonURL     = @"%@/provisioning/use_code/?provisioning_code=%@&device_id=%@&device_name=%@";
static NSString *const kSTinfoURL       = @"%@/provisioning/silent_text/cfg.json?api_key=%@";

#pragma mark - class methods


+ (NSData*) apiKey
{
    App *app = App.sharedApp;
  
    NSString *apiKeyIdentifier = [NSString stringWithFormat: kAPIKeyFormat, app.identifier];
    ServiceCredential *apiKey = [ServiceCredential.alloc initWithService: apiKeyIdentifier];
    
    return (apiKey.data);
}

+ (NSData*) deviceID
{
    App *app = App.sharedApp;
    
    NSString *deviceKeyIdentifier = [NSString stringWithFormat: kDeviceKeyFormat, app.identifier];
    ServiceCredential *deviceKey = [ServiceCredential.alloc initWithService: deviceKeyIdentifier];
   
    return (deviceKey.data);
}

+ (BOOL) isProvisioned
{
    return(self.apiKey && self.deviceID);
}

+ (void) resetProvisioning
{
    App *app = App.sharedApp;
 
    [app resetAccounts];
      
    NSString *apiKeyIdentifier = [NSString stringWithFormat: kAPIKeyFormat, app.identifier];
    ServiceCredential *apiKey = [ServiceCredential.alloc initWithService: apiKeyIdentifier];
    
    NSString *deviceKeyIdentifier = [NSString stringWithFormat: kDeviceKeyFormat, app.identifier];
    ServiceCredential *deviceKey = [ServiceCredential.alloc initWithService: deviceKeyIdentifier];
    
    [apiKey deleteCredential];
    [deviceKey deleteCredential];
}

#pragma mark - Provisioning

- (id)initWithDelegate:(id)aDelegate
{
    App *app = App.sharedApp;
    
	if ((self = [super init]))
	{
		self.delegate = aDelegate;
        self.appIdentifier = app.identifier;
        
    }
	return self;
}


- (NSURLRequest *)createActivationRequestUrl: (NSString*)provisioning_code
{
    NSString *deviceKeyIdentifier = [NSString stringWithFormat: kDeviceKeyFormat, self.appIdentifier];
    ServiceCredential *deviceKey = [ServiceCredential.alloc initWithService: deviceKeyIdentifier];
    
    if (!deviceKey.data)
    {
        deviceKey.data = [ [XMPPStream generateUUID] dataUsingEncoding :NSUTF8StringEncoding];
    }
    
    NSString* url = [NSString stringWithFormat:kProvisonURL,
                     kSilentCircleProvisionURL,
                     provisioning_code,
                     [[NSString alloc] initWithData:deviceKey.data encoding:NSUTF8StringEncoding],
                     [UIDevice.currentDevice.name urlEncodeUsingEncoding]] ;
    
    
    return [[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:url]
                                 cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                             timeoutInterval:kProvisonTimeoutValue ];
}


- (NSURLRequest *)createSTRequestUrl:(NSString *)key
{
    
    NSString* url = [NSString stringWithFormat:kSTinfoURL, kSilentCircleProvisionURL, key] ;
    
    return [[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:url]
                                 cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                             timeoutInterval:kProvisonTimeoutValue ];

}


- (void)presentAlertWithError:(NSError *)error {

  [self.delegate  provisioningError: error];
    
}

- (void)completeActivationWithData:(NSData *)data {
    NSError *jsonError;
    NSDictionary *info = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    if (jsonError==nil){
        
        NSString *string = nil;
        
        if ((string = [info valueForKey:@"error_msg"])) {
            
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:string forKey:NSLocalizedDescriptionKey];
            
            NSError * error =
            [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorCannotConnectToHost userInfo:details];
            
            [self.delegate  provisioningError: error];
        }
        else
        {
            [self.delegate  provisionCompletedWithInfo: info];
        }
    }
    
}



-(void)loadInfoWithAPIKey: (NSString*)key {
    NSURLRequest *request = [self createSTRequestUrl: key];
     
    self.responseData = NULL;
    self.responseCallBack = kCompleteActivation;
    
    [NSURLConnection connectionWithRequest:request delegate:self];
      
}

- (void)continueActivationWithAPIkey:(NSData *)data {
    
    NSError *jsonError;
    
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    if (jsonError==nil){
        
        NSString* apiKeyString  =  [responseDict valueForKey:@"api_key"];
        NSString* error_msg     =  [responseDict valueForKey:@"error_msg"];
        
        if(apiKeyString)
        {
            App *app = App.sharedApp;
            NSString *apiKeyIdentifier = [NSString stringWithFormat: kAPIKeyFormat, app.identifier];
            ServiceCredential *apiKey = [ServiceCredential.alloc initWithService: apiKeyIdentifier];
            
            apiKey.data = [ apiKeyString dataUsingEncoding :NSUTF8StringEncoding];
            
            [self loadInfoWithAPIKey: apiKeyString];
            
        }
        if(error_msg)
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:error_msg forKey:NSLocalizedDescriptionKey];
            
            NSError * error =
                [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorCannotConnectToHost userInfo:details];
            
             [self.delegate  provisioningError: error];
        }
    }
    else
    {
        
        [self.delegate  provisioningError: jsonError];
          
    }
    
   
}

- (void) startActivationProcessWithCodeString: (NSString*) code
{
    NSURLRequest *request = [self createActivationRequestUrl: code];

    self.responseData = NULL;
    self.responseCallBack = kContinueActivation;

    [NSURLConnection connectionWithRequest:request delegate:self];
    
  }

#pragma mark - NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *) theResponse
{
	self.responseData = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  [self.responseData appendData:data];
}

 
 
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if( self.responseCallBack == kContinueActivation)
    {
        [self performSelector:@selector(continueActivationWithAPIkey:)  withObject:self.responseData];
    }
    else if( self.responseCallBack == kCompleteActivation)
    {
        [self performSelector:@selector(completeActivationWithData:)  withObject:self.responseData];
    
    }
    else
    {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
         
        [details setValue:[NSString stringWithFormat:@"Internal Error: %s (%d)", __PRETTY_FUNCTION__, __LINE__]
                   forKey:NSLocalizedDescriptionKey];
        
        NSError * error =  [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorUnknown userInfo:details];
        
        [self.delegate  provisioningError: error];
     }
 }


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    
    if(error.domain == NSURLErrorDomain && error.code == kCFURLErrorUserCancelledAuthentication)
    {
         NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:NSLS_COMMON_CERT_FAILED forKey:NSLocalizedDescriptionKey];
        
        error = [NSError errorWithDomain:NSURLErrorDomain code:kCFURLErrorClientCertificateRejected userInfo:details];
    }
      
    [self.delegate provisioningError: error];
   
    self.responseData = NULL;
    self.responseCallBack = NULL;
   
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

@end
