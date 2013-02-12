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
//  SCPasscodeManager.m
//  SilentText
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif



#import "AppConstants.h"
#import "App.h"
#import "ServiceCredential.h"
#import "StorageCipher.h"

#import "SCPasscodeManager.h"

#import <CommonCrypto/CommonDigest.h>

@implementation NSData (MD5String)

- (NSString*)MD5String
{
     // Create byte array of unsigned chars
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    
    // Create 16 byte MD5 hash value, store in buffer
    CC_MD5(self.bytes, self.length,  md5Buffer);
    
    // Convert MD5 value in the buffer to NSString of hex values
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x",md5Buffer[i]];
    
    return output;
}
@end

@interface SCPasscodeManager ()

#define kTimeoutPrefsVersion  0x01

typedef struct  {
    uint8_t         version;
    NSTimeInterval  delay;
} TimeoutPrefs;

@property (nonatomic, strong)  id <SCPasscodeDelegate> delegate;
@property (weak, nonatomic)   StorageCipher *storageCipher;


@property (nonatomic, strong) NSString *appIdentifier;
 
@property (nonatomic, strong)  ServiceCredential *encryptedStorageKeyCredential;
@property (nonatomic, strong)  ServiceCredential *passphraseMDCredential;
@property (nonatomic, strong)  ServiceCredential *guidPassphraseCredential;
@property (nonatomic, strong)  ServiceCredential *passphraseTimeoutCredential;
 
@property (nonatomic) BOOL hasPasscode;

@property (nonatomic) TimeoutPrefs timeout;
@property (nonatomic) NSInteger failedTries;

@property (strong, nonatomic) NSData *timeoutItem;      // TimeoutPrefs encoded

@property (nonatomic, strong)   NSDate      *lastTimeActive;
 

@end

@implementation SCPasscodeManager

@synthesize delegate = _delegate;
@synthesize encryptedStorageKeyCredential = _encryptedStorageKeyCredential;
@synthesize passphraseMDCredential = _passphraseMDCredential;
@synthesize guidPassphraseCredential = _guidPassphraseCredential;
@synthesize passphraseTimeoutCredential = _passphraseTimeoutCredential;

#pragma mark - Passcode manager

#define kStorageKeyFormat           @"%@.storageKey"
#define kGUIDPassphraseFormat       @"%@.guidPassphrase"
#define kPassphraseMetaDataFormat   @"%@.passphraseMetaData"
#define kPassphraseTimeoutFormat    @"%@.passphraseTimeout"


- (NSData *) timeoutItem {
    
    _timeout.version = kTimeoutPrefsVersion;
    NSData *item = [NSData dataWithBytes: &_timeout length: sizeof(TimeoutPrefs)];
    return item;
}

- (void) setTimeoutItem: (NSData *)timeoutItem {
    
    [timeoutItem getBytes: &_timeout length: sizeof(TimeoutPrefs)];
}


- (NSString*) guidPassphrase

{
    App *app  = App.sharedApp;
    
    // Read the guidPassphrase from the keychain.
    NSString *guidPassphraseIdentifier = [NSString stringWithFormat: kGUIDPassphraseFormat, app.identifier];
    ServiceCredential *guidPassphraseCredential = [ServiceCredential.alloc initWithService: guidPassphraseIdentifier];
    
    NSString *guidPassphrase = [NSString.alloc initWithBytes: guidPassphraseCredential.data.bytes
                                                      length: guidPassphraseCredential.data.length
                                                    encoding: NSUTF8StringEncoding];
    
    return guidPassphrase;
}
///----------------

- (void) updateStorageCipherWithPassphase: (NSString*) passPhrase storageCipher:(StorageCipher *)storageCipher
{

    // Encrypt the storage key.
    [storageCipher makePassphraseKey: passPhrase];
    
    // Save the passphrase metadata.
    self.passphraseMDCredential.data = storageCipher.passphraseItem;
    
    // update the storage key on keychain
    self.encryptedStorageKeyCredential.data = storageCipher.storageItem;
    
}

- (StorageCipher *) configureCipherKeys {
   
    StorageCipher *storageCipher = StorageCipher.new;
    
    NSData *keyData = self.encryptedStorageKeyCredential.data;
    
    if (!keyData || ![keyData isStorageItem]) {
  
        [storageCipher makeStorageKey];
        
        // Make a temporary GUID passphrase.
         NSString *guidPassphrase = StorageCipher.uuid;
        
        // Store it in the keychain.
        self.guidPassphraseCredential.data = [guidPassphrase dataUsingEncoding: NSUTF8StringEncoding];
        
        // update passphrase and key on keychain
        [self updateStorageCipherWithPassphase: guidPassphrase storageCipher:storageCipher];
        
        // no timeout info
        [self.passphraseTimeoutCredential deleteCredential];
        
    }
    else
    {
        // cant unlock now, ask later
        
        // get passphrase meta data from keychain
        storageCipher.passphraseItem = self.passphraseMDCredential.data;
        
        // get the passphrase timeout item
        self.timeoutItem = self.passphraseTimeoutCredential.data;
        
        // if guid passphrase, read it in and unlock
        NSData *gpData = self.guidPassphraseCredential.data;
        if(gpData && gpData.length)
        {
            NSString *guidPassphrase = [NSString.alloc initWithBytes: gpData.bytes
                                                              length: gpData.length
                                                            encoding: NSUTF8StringEncoding];
            // Decrypt the storage key.
            [storageCipher unlockWithPassphrase: guidPassphrase];
            storageCipher.storageItem = self.encryptedStorageKeyCredential.data;
        }
    }
    return storageCipher;
    
} // -configureCipherKeys


+(void) deleteKeys
{
    App *app    = App.sharedApp;

    NSString *storageKeyIdentifier = [NSString stringWithFormat: kStorageKeyFormat, app.identifier];
    ServiceCredential *encryptedStorageKeyCredential = [ServiceCredential.alloc initWithService: storageKeyIdentifier];
    [encryptedStorageKeyCredential deleteCredential];
    
    NSString *passphraseMDIdentifier = [NSString stringWithFormat: kPassphraseMetaDataFormat, app.identifier];
    ServiceCredential *passphraseMDCredential = [ServiceCredential.alloc initWithService: passphraseMDIdentifier];
    [passphraseMDCredential deleteCredential];
 
      NSString *guidPassphraseIdentifier = [NSString stringWithFormat: kGUIDPassphraseFormat, app.identifier];
    ServiceCredential *guidPassphraseCredential = [ServiceCredential.alloc initWithService: guidPassphraseIdentifier];
    [guidPassphraseCredential deleteCredential];
    
}



+ (BOOL) validityCheck
{
    BOOL OK = NO;
    
    App *app    = App.sharedApp;

    NSString *storageKeyIdentifier = [NSString stringWithFormat: kStorageKeyFormat, app.identifier];
    ServiceCredential *encryptedStorageKeyCredential = [ServiceCredential.alloc initWithService: storageKeyIdentifier];

    NSString *passphraseMDIdentifier = [NSString stringWithFormat: kPassphraseMetaDataFormat, app.identifier];
    ServiceCredential *passphraseMDCredential = [ServiceCredential.alloc initWithService: passphraseMDIdentifier];
   
    NSData *keyData = encryptedStorageKeyCredential.data;
    NSData *pMetaData = passphraseMDCredential.data;
    
    if(!keyData)
        return YES;
    
    if ( keyData && [keyData isStorageItem]  && pMetaData && [pMetaData isPassphraseItem])
        OK = YES;
     
    return OK;
}

- (id)init
{
    App *app    = App.sharedApp;
   
	if ((self = [super init]))
	{
        NSString *storageKeyIdentifier = [NSString stringWithFormat: kStorageKeyFormat, app.identifier];
        self.encryptedStorageKeyCredential = [ServiceCredential.alloc initWithService: storageKeyIdentifier];
        
        NSString *guidPassphraseIdentifier = [NSString stringWithFormat: kGUIDPassphraseFormat, app.identifier];
        self.guidPassphraseCredential = [ServiceCredential.alloc initWithService: guidPassphraseIdentifier];
        
        NSString *passphraseMDIdentifier = [NSString stringWithFormat: kPassphraseMetaDataFormat, app.identifier];
        self.passphraseMDCredential = [ServiceCredential.alloc initWithService: passphraseMDIdentifier];
  
        NSString *passPhraseTimeoutIdentifier = [NSString stringWithFormat: kPassphraseTimeoutFormat, app.identifier];
        self.passphraseTimeoutCredential = [ServiceCredential.alloc initWithService: passPhraseTimeoutIdentifier];
        
        _timeout.delay = 15.00;  // seconds, was = DBL_MAX;
        
        self.lastTimeActive = NULL;
        self.failedTries = 0;
      
        self.storageCipher = [self configureCipherKeys];
        
        [self registerForNotifications];
     }
	return self;
}


- (id)initWithDelegate:(id)aDelegate
{
      
	if ((self = [self init]))
	{
		self.delegate = aDelegate;
    }
	return self;
}

- (void) setPasscodeTimeout:(NSTimeInterval)timeout
{
     _timeout.delay = timeout;
    
    // write it to keychain
    self.passphraseTimeoutCredential.data = self.timeoutItem;
}

- (NSTimeInterval) passcodeTimeout {
    
    return _timeout.delay;
}
  

- (BOOL) isLocked
{
    return (self.storageCipher)?self.storageCipher.isLocked: YES;
}

- (void) lock
{
    
     if(self.hasPasscode && self.storageCipher)
    {
        if(_delegate && [_delegate respondsToSelector:@selector(passcodeManagerWillLock:) ])
            [self.delegate  passcodeManagerWillLock: self];
       
        [self.storageCipher lock];
        
        if(self.delegate && [self.delegate respondsToSelector:@selector(passcodeManagerDidLock) ])
            [self.delegate  passcodeManagerDidLock: self];
        
   }
  }


- (BOOL) unlockWithPassphrase: (NSString *) passphrase error:(NSError **)error {
    
    NSError *err = NULL;
  
    BOOL ok = [self.storageCipher unlockWithPassphrase: passphrase];
    
    if(ok)
    {
        self.storageCipher.storageItem = self.encryptedStorageKeyCredential.data;
        
        if(_delegate && [_delegate respondsToSelector:@selector(passcodeManagerDidUnlock:) ])
            [self.delegate  passcodeManagerDidUnlock: self];
       
    }
    
    self.failedTries = ok?0:self.failedTries+1;
     
    if(error)
        *error = err;
    
    return  ok;
}

- (BOOL) removePassphraseWithError: (NSError **)error
{
      NSError *err = NULL;
 
     self.failedTries = 0;
    
    // Make a temporary GUID passphrase.
    NSString *guidPassphrase = StorageCipher.uuid;
    
    // Store it in the keychain.
    [self.guidPassphraseCredential deleteCredential];
    self.guidPassphraseCredential.data = [guidPassphrase dataUsingEncoding: NSUTF8StringEncoding];
    
    // update passphrase and key on keychain
    [self updateStorageCipherWithPassphase: guidPassphrase storageCipher:self.storageCipher];

    // no timeout info
    [self.passphraseTimeoutCredential deleteCredential];
    
    if(error)
        *error = err;
    
    return  TRUE;
}


- (BOOL) hasPasscode
{
    NSData *gpData = self.guidPassphraseCredential.data;
    BOOL hasGuidPass = (gpData && gpData.length);
    return  (!hasGuidPass);

}

- (BOOL) updatePassphraseKey: (NSString *) passphrase error:(NSError **)error
{ 
    BOOL updated = FALSE;
    NSError *err = NULL;
  
    if(!self.hasPasscode  || !  self.storageCipher.isLocked)
    {
         // update passphrase and key on keychain
        [self updateStorageCipherWithPassphase: passphrase storageCipher:self.storageCipher];
        
        // delete old guid passphrase if it's there
        if(self.guidPassphraseCredential.data)
            [self.guidPassphraseCredential deleteCredential];
             
        self.failedTries = 0;
        updated = YES;
        
    }
    
    if(error)
        *error = err;
    
    return updated;
}


#define kBecomeActive  (@selector(becomeActive:))
- (void) becomeActive: (NSNotification *) notification {
    
    if(self.lastTimeActive)
    {
        NSTimeInterval  sleepTime = - [self.lastTimeActive timeIntervalSinceNow];
   
        if(_timeout.delay != DBL_MAX && sleepTime > _timeout.delay)
        {
            [self lock];
             
        }
    }
    
    self.lastTimeActive = NULL;
}

#define kResignActive  (@selector(resignActive:))
- (void) resignActive: (NSNotification *) notification {
    
     self.lastTimeActive =[NSDate date];
 }

- (SCPasscodeManager *) registerForNotifications {
	
 	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	[nc removeObserver: self];
	
    [nc addObserver: self
		   selector:  kBecomeActive
			   name: UIApplicationDidBecomeActiveNotification
			 object: nil];
    
    
    [nc addObserver: self
		   selector:  kResignActive
			   name: UIApplicationWillResignActiveNotification
			 object: nil];
    
    return self;
	
} // -registerForNotifications


@end
