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
#import <Foundation/Foundation.h>
#import <SCCrypto/SCcrypto.h>

@protocol SCPasscodeDelegate;

typedef enum {
    kPassPhraseSource_Unknown = 0,
	kPassPhraseSource_Keychain ,
	kPassPhraseSource_Keyboard,

    kPassPhraseSource_Recovery,             // maybe a barcode?
    kPassPhraseSource_BioMetric,            // touchID
    
} PassPhraseSource;


@interface SCPasscodeManager : NSObject

- (instancetype)initWithDelegate:(id)aDelegate;

@property (nonatomic, weak) id <SCPasscodeDelegate> delegate;

@property (nonatomic, readonly) BOOL isLocked;

@property (nonatomic, readonly) BOOL storageKeyIsAvailable;
@property (nonatomic, readonly) BOOL isConfigured;
@property (nonatomic, readonly) NSInteger failedTries;
@property (nonatomic) NSTimeInterval passcodeTimeout;

@property (nonatomic, readonly) SCKeyContextRef storageKey;

// this tests if this unlocks
- (SCKeyContextRef) unlockStorageBlobWithPassphase:(NSString*)passPhrase
                                  passPhraseSource:(PassPhraseSource)passPhraseSource
                                             error:(NSError**)errorOut;


- (BOOL) configureStorageKeyWithError:(NSError**) errorOut;

- (BOOL) unlockWithPassphrase:(NSString *)passphrase
             passPhraseSource:(PassPhraseSource)passPhraseSource
                        error:(NSError**)error;

- (BOOL) updatePassphrase: (NSString *) passphrase error:(NSError**)error;

- (BOOL) removePassphraseWithPassPhraseSource:(PassPhraseSource)passPhraseSource
                                        error:(NSError**)error;

- (void) lock;
- (void) zeroStorageKey;
-(NSArray*) keyBlobTypesAvailable;
- (BOOL) hasKeyChainPassCode;

+ (NSURL*) storageBlobURL;

+ (BOOL) hasGuidPassphrase;
 
+ (void)  resetAllKeychainInfo;    //be careful about this, only do on first run


// call these from appdelegate

- (void) applicationDidBecomeActive;
- (void) applicationWillResignActive;

 // Recovery key APIs -- still experimental
- (BOOL) updateRecoveryKey: (NSString *) passphrase
           recoveryKeyDict: (NSDictionary**) recoveryKeyDictOut
                     error:(NSError**)errorOut;

- (BOOL) removeRecoveryKeyWithError:(NSError**) errorOut;
- (NSData*)recoveryKeyBlob;
+(NSString*) createRecoveryKeyString;
- (NSDictionary*)recoveryKeyDictionary;

+(NSString*) recoveryKeyCodeFromPassCode:(NSString*)passCode recoveryKeyDict:(NSDictionary*)inRecoveryKeyDict;
+(NSDictionary*) recoveryKeyComponentsFromCode:(NSString*)recoveryCode ;
+(NSString*)  locatorCodeFromRecoveryKeyDict:(NSDictionary*)inRecoveryKeyDict;


+(BOOL) canUseBioMetricsWithError:(NSError**)errorOut;
-(BOOL) hasBioMetricKey;
-(BOOL) createBioMetricKeyBlobWithError:(NSError**)errorOut;
-(BOOL) removeBioMetricKeyWithError:(NSError**) errorOut;
-(BOOL) unlockWithBiometricKeyWithPrompt:(NSString*)prompt error:(NSError**)errorOut;
//-(BOOL) testTouchID;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol SCPasscodeDelegate <NSObject>
@optional

- (void)passcodeManagerWillLock:(SCPasscodeManager *)passcodeManager;
- (void)passcodeManagerDidLock:(SCPasscodeManager *)passcodeManager;
- (void)passcodeManagerDidUnlock:(SCPasscodeManager *)passcodeManager;

@end
