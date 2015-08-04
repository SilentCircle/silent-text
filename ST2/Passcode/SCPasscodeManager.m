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
#import "SCPasscodeManager.h"

#import "AppConstants.h"
#import "AppDelegate.h"
#import "SCimpUtilities.h"
#import "STLogging.h"

@import LocalAuthentication;

#if !__has_feature(objc_arc)
#error Please compile this class with ARC (-fobjc-arc).
#endif

#define kGUIDPassphraseFormat      @"%@.guidPassphrase"
#define kBioMetricPassphraseFormat @"%@.biometricPassphrase"
#define kPassphraseTimeoutFormat   @"%@.passphraseTimeoutObject"


// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


#pragma mark - STtimeoutPrefs

@interface STtimeoutPrefs : NSObject <NSCoding>

@property (nonatomic) NSTimeInterval  delay;
@end

@implementation STtimeoutPrefs 

@synthesize delay;


static NSString *const kPassPhraseSourceKey_keychain   = @"keychain";
static NSString *const kPassPhraseSourceKey_keyboard   = @"keyboard";
static NSString *const kPassPhraseSourceKey_recovery   = @"recovery";
static NSString *const kPassPhraseSourceKey_biometric  = @"biometric";
static NSString *const kPassPhraseSourceKey_unknown    = @"unknown";
static NSString *const kPassPhraseSourceKey            = @"passPhraseSource";


-(NSString*) passphraseTimeoutdentifier
{
    return [NSString stringWithFormat: kPassphraseTimeoutFormat, STAppDelegate.identifier];
}

- (id)init
{
    self = [super init];
    
    if (self != nil)
    {
        NSString* pt =  [self getDelayData];
        if(pt)
        {
			NSData *serialized = [[NSData alloc] initWithBase64EncodedString:pt options:0];
            
            self = [NSKeyedUnarchiver unarchiveObjectWithData:serialized];
        }
        else
        {
            [self setDelay: DBL_MAX];
        }
    }
    
    return self;
}



- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
        int32_t version = [decoder decodeInt32ForKey:@"version"];
        
        if (version == 1)
		{
            delay = [decoder decodeDoubleForKey:@"delay"];
                 
        }
   	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt32:1 forKey:@"version"];
     [coder encodeDouble:delay forKey:@"delay"];
}


-(NSString*) getDelayData
{
    NSString* hexResult = NULL;
    
    // Read the guidPassphrase from the keychain.
    NSDictionary *query = @{ (__bridge id)kSecAttrService            : [self passphraseTimeoutdentifier],
                                    (__bridge id)kSecAttrAccount            : @"",
                                    (__bridge id)kSecReturnData             : @YES,
                                    (__bridge id)(kSecMatchLimit)           :(__bridge id) kSecMatchLimitOne,
                                    (__bridge id)(kSecClass)                :(__bridge id) kSecClassGenericPassword,
                                    (__bridge id)(kSecAttrSynchronizable)   :(__bridge id) kSecAttrSynchronizableAny
                                    };
    
    CFTypeRef delayData = NULL;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &delayData);
    
    if (status == errSecSuccess)
    {
        
        hexResult = [[NSString alloc] initWithData:(__bridge_transfer NSData *)delayData encoding:NSUTF8StringEncoding];
    }
    
    return hexResult;
    
}

-(void) setDelay:(NSTimeInterval)delayIn
{
    delay = delayIn;
    
    NSDictionary *deleteQuery = @{ (__bridge id)kSecAttrService            : [self passphraseTimeoutdentifier],
                             (__bridge id)kSecAttrAccount            : @"",
                             (__bridge id)(kSecClass)                :(__bridge id) kSecClassGenericPassword,
                             (__bridge id)(kSecAttrSynchronizable)   :(__bridge id) kSecAttrSynchronizableAny
                             };
    
 	OSStatus status = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    
    NSData *serialized = [NSKeyedArchiver archivedDataWithRootObject:self];
    
//    NSData* delayData = [[serialized base64Encoded] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *delayData = [serialized base64EncodedDataWithOptions:0];
    
    NSDictionary *query = @{ (__bridge id)kSecAttrService            : [self passphraseTimeoutdentifier],
                             (__bridge id)kSecAttrAccount            : @"",
                             (__bridge id)(kSecValueData)            : delayData,
                             (__bridge id)(kSecClass)                :(__bridge id) kSecClassGenericPassword,
                             (__bridge id)(kSecAttrSynchronizable)   :(__bridge id) kSecAttrSynchronizableAny,
                             (__bridge id)(kSecAttrAccessible)       :(__bridge id) kSecAttrAccessibleAfterFirstUnlock,
                             };
    
    status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    
 }

-(NSTimeInterval) delay
{
    
    return delay;
}

@end

#pragma mark - SCPasscodeManager

@interface SCPasscodeManager ()

@property (nonatomic)           SCKeyContextRef  storageKey;
 
@property (nonatomic, strong)   STtimeoutPrefs* timeout;
@property (nonatomic)           NSInteger       failedTries;

@property (nonatomic, strong)   NSDate      *lastTimeActive;
@property (nonatomic)           BOOL        isConfigured;

@end

@implementation SCPasscodeManager
{
	BOOL unlocked;
}

@synthesize delegate = _useDotSyntax_delegate;
@synthesize storageKey;
@synthesize isConfigured = _isConfigured;

#pragma mark Init & Dealloc

- (id)init
{
	if ((self = [super init]))
	{
		DDLogAutoTrace();
		
		_timeout = [[STtimeoutPrefs alloc] init];
		
		self.lastTimeActive = NULL;
		self.failedTries = 0;
		unlocked = NO;
		
		self.isConfigured = NO;
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

- (void)dealloc
{
	DDLogAutoTrace();
	
	if (SCKeyContextRefIsValid(storageKey)) {
        SCKeyFree(storageKey);
		storageKey = kInvalidSCKeyContextRef;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Class methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSURL *)storageBlobURL
{
    NSString *const storageBlobName = @"silentText.pbkdf2";

    NSURL *baseURL = [NSFileManager.new URLForDirectory: NSApplicationSupportDirectory
                                               inDomain: NSUserDomainMask
                                      appropriateForURL: nil
                                                 create: YES
                                                  error: NULL];
    NSURL* url = [baseURL URLByAppendingPathComponent:storageBlobName isDirectory:NO];
  
    return url;
    
}


+ (void) resetAllKeychainInfo     //be careful about this, only do on first run
{
    
    [SCPasscodeManager deleteGuidPassphraseWithError: NULL];
    
}

+ (BOOL) hasGuidPassphrase
{
    BOOL result = NO;
    
    NSString *guidPassphraseIdentifier = [NSString stringWithFormat: kGUIDPassphraseFormat, STAppDelegate.identifier];
    
    NSDictionary *query = @{ (__bridge id)kSecAttrService        :  guidPassphraseIdentifier,
                             (__bridge id)kSecReturnAttributes   :  @YES,
                             (__bridge id)kSecClass              : (__bridge id) kSecClassGenericPassword,
                             (__bridge id)(kSecAttrSynchronizable):(__bridge id) kSecAttrSynchronizableAny
                             };
    
    CFTypeRef queryResult = NULL;
    
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &queryResult);
    if (status == errSecSuccess)
    {
        result = YES;
    }
    else
    {
        if (queryResult) CFRelease(queryResult);
    }
    
    return result;
    
}

#pragma mark - Keychain interface

+(NSString*) guidPassphraseIdentifier
{
    return [NSString stringWithFormat: kGUIDPassphraseFormat, STAppDelegate.identifier];
}




+ (NSError *)errorWithCode:(OSStatus) code {
	NSString *message = nil;
	switch (code) {
		case errSecSuccess: return nil;
            
 		case errSecUnimplemented: {
			message = @"errSecUnimplemented";
			break;
		}
		case errSecParam: {
			message = @"errSecParam";
			break;
		}
		case errSecAllocate: {
			message = @"errSecAllocate";
			break;
		}
		case errSecNotAvailable: {
			message = @"errSecNotAvailable";
			break;
		}
		case errSecDuplicateItem: {
			message = @"errSecDuplicateItem";
			break;
		}
		case errSecItemNotFound: {
			message = @"errSecItemNotFound";
			break;
		}
		case errSecInteractionNotAllowed: {
			message = @"errSecInteractionNotAllowed";
			break;
		}
		case errSecDecode: {
			message = @"errSecDecode";
			break;
		}
		case errSecAuthFailed: {
			message = @"errSecAuthFailed";
			break;
		}
		default: {
			message = [NSString stringWithFormat: @"errSec Code %d", (int)code];
		}
   	}
    
	NSDictionary *userInfo = nil;
	if (message) {
		userInfo = @{ NSLocalizedDescriptionKey : message };
	}
	return [NSError errorWithDomain:NSOSStatusErrorDomain code:code userInfo:userInfo];
}


// guard code to correct any mismatched keychain permissions

-(void) correctKeychainPermissions
{
    NSString *guidPassphraseIdentifier = [NSString stringWithFormat: kGUIDPassphraseFormat, STAppDelegate.identifier];
    
    NSDictionary *query = @{ (__bridge id)kSecAttrService        :  guidPassphraseIdentifier,
                                    (__bridge id)kSecReturnAttributes   :  @YES,
                                    (__bridge id)kSecClass              : (__bridge id) kSecClassGenericPassword,
                                    (__bridge id)(kSecAttrSynchronizable):(__bridge id) kSecAttrSynchronizableAny
                                    };
    
    CFTypeRef result = NULL;
    
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecSuccess)
    {
       NSDictionary *attrDict =  (__bridge_transfer NSMutableDictionary *)result;
        
        id AttrAccessible = [attrDict objectForKey: (__bridge id) kSecAttrAccessible];
        if(! [AttrAccessible isEqual: (__bridge id)  kSecAttrAccessibleAfterFirstUnlock])
        {
            DDLogRed(@"Correcting keychain Attributes");
     
            // Read the guidPassphrase from the keychain.
            NSDictionary *pwQuery = @{ (__bridge id)kSecAttrService            : [SCPasscodeManager guidPassphraseIdentifier],
                                            (__bridge id)kSecAttrAccount            : @"",
                                            (__bridge id)kSecReturnData             : @YES,
                                            (__bridge id)(kSecMatchLimit)           :(__bridge id) kSecMatchLimitOne,
                                            (__bridge id)(kSecClass)                :(__bridge id) kSecClassGenericPassword,
                                            (__bridge id)(kSecAttrSynchronizable)   :(__bridge id) kSecAttrSynchronizableAny
                                       };
            
            CFTypeRef guidPassphraseData = NULL;
            status = SecItemCopyMatching((__bridge CFDictionaryRef)pwQuery, &guidPassphraseData);

            if(status == errSecSuccess)
            {
                NSDictionary *updateQuery = @{ (__bridge id)kSecAttrService        :  guidPassphraseIdentifier,
                                               (__bridge id)kSecClass              : (__bridge id) kSecClassGenericPassword,
                                               (__bridge id)(kSecAttrSynchronizable):(__bridge id) kSecAttrSynchronizableAny
                                               };
                

                NSDictionary *updatedAttributes = @{ (__bridge id)(kSecAttrAccessible) :(__bridge id) kSecAttrAccessibleAfterFirstUnlock,
                                                     (__bridge id)(kSecValueData)      :(__bridge id)guidPassphraseData   };
                
                status = SecItemUpdate((__bridge CFDictionaryRef)updateQuery, (__bridge CFDictionaryRef) updatedAttributes);
  
            }
          }
     }
    else
    {
        if (result) CFRelease(result);
    }
}


//------------

#pragma mark - guidPassphrase interface

- (NSString*) guidPassphraseWithError: (NSError**)errorOut

{
    NSString* gp = nil;
   
    [self correctKeychainPermissions];
    
    // Read the guidPassphrase from the keychain.
    NSDictionary *query = @{ (__bridge id)kSecAttrService            : [SCPasscodeManager guidPassphraseIdentifier],
                                    (__bridge id)kSecAttrAccount            : @"",
                                    (__bridge id)kSecReturnData             : @YES,
                                    (__bridge id)(kSecMatchLimit)           :(__bridge id) kSecMatchLimitOne,
                                    (__bridge id)(kSecClass)                :(__bridge id) kSecClassGenericPassword,
                                    (__bridge id)(kSecAttrSynchronizable)   :(__bridge id) kSecAttrSynchronizableAny
                                    };
    
    CFTypeRef passwordData = NULL;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &passwordData);
    
    if (status == errSecSuccess)
    {
        gp = [[NSString alloc] initWithData:(__bridge_transfer NSData *)passwordData encoding:NSUTF8StringEncoding];
    }
    
    if(!gp && (status != errSecItemNotFound))
    {
        if(errorOut)
        {
            *errorOut = [SCPasscodeManager errorWithCode:status];
        }
    }
    
    return gp;
}


-(BOOL)  makeGuidPassphraseWithError: (NSError**)errorOut
{
    BOOL        success = FALSE;
    char*       newPassPhrase = NULL;
  
   // try deleting old one first
    [SCPasscodeManager deleteGuidPassphraseWithError: NULL ];
    
    if(IsntSCLError(RNG_GetPassPhrase(128, &newPassPhrase)))
    {
        NSData*     guidPassphraseData = [NSData dataWithBytesNoCopy:newPassPhrase length:strlen(newPassPhrase) freeWhenDone:YES];
        
        NSDictionary *query = @{ (__bridge id)kSecAttrService            : [SCPasscodeManager guidPassphraseIdentifier],
                                        (__bridge id)kSecAttrAccount            : @"",
                                        (__bridge id)(kSecValueData)            : guidPassphraseData,
                                        (__bridge id)(kSecClass)                :(__bridge id) kSecClassGenericPassword,
                                        (__bridge id)(kSecAttrSynchronizable)   :(__bridge id) kSecAttrSynchronizableAny,
                                        (__bridge id)(kSecAttrAccessible)       :(__bridge id) kSecAttrAccessibleAfterFirstUnlock,
                                         };
        
       	OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);

        if( status == errSecSuccess )
        {
            success = YES;
        }
        else
        {
            if(errorOut)
            {
                *errorOut = [SCPasscodeManager errorWithCode:status];
            }
        }
     }
     return success;
}


+(BOOL)  deleteGuidPassphraseWithError:(NSError**)errorOut
{
    BOOL success = NO;
    
    NSDictionary *query = @{ (__bridge id)kSecAttrService            : [SCPasscodeManager guidPassphraseIdentifier],
                                     (__bridge id)kSecAttrAccount            : @"",
                                     (__bridge id)(kSecClass)                :(__bridge id) kSecClassGenericPassword,
                                     (__bridge id)(kSecAttrSynchronizable)   :(__bridge id) kSecAttrSynchronizableAny
                                    };
    
 	OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    
    if( status == errSecSuccess )
    {
        success = YES;
    }
    else
    {
        if(errorOut)
        {
            *errorOut = [SCPasscodeManager errorWithCode:status];
        }
    }

    return success;
}

#pragma mark - bioPassphrase interface

+(BOOL) canUseBioMetricsWithError:(NSError**)errorOut
{
    BOOL    result = NO;
    NSError *error = NULL;
 
    if(AppConstants.isIOS8OrLater)
    {
        LAContext *context = [[LAContext alloc] init];
        
        // test if we can evaluate the policy, this test will tell us if Touch ID is available and enrolled
        if(context)
        {
            result = [context canEvaluatePolicy: LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];
        }
     }
    
    if(error && errorOut)
    {
        *errorOut = error.copy;
    }

    return result;
}



+(NSString*) bioPassphraseIdentifier
{
    return [NSString stringWithFormat: kBioMetricPassphraseFormat, STAppDelegate.identifier];
}

- (BOOL) hasBioPassphraseWithError: (NSError**)errorOut

{
    BOOL result = NO;
    [self correctKeychainPermissions];
    
    // Read the guidPassphrase from the keychain.
    NSDictionary *query = @{ (__bridge id)kSecAttrService            : [SCPasscodeManager bioPassphraseIdentifier],
                             (__bridge id)kSecAttrAccount            : @"",
                             (__bridge id)kSecReturnData             : @NO,
                             (__bridge id)(kSecMatchLimit)           :(__bridge id) kSecMatchLimitOne,
                             (__bridge id)(kSecClass)                :(__bridge id) kSecClassGenericPassword,
                             (__bridge id)(kSecAttrSynchronizable)   :(__bridge id) kSecAttrSynchronizableAny,
                             (__bridge id)kSecUseNoAuthenticationUI  : @YES,
                             };
    
      OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
    
    if (status == errSecSuccess || status == errSecInteractionNotAllowed)   // we asked for no interaction here.
    {
        result = YES;
        
    }
    else
    {
        if(errorOut)
        {
            *errorOut = [SCPasscodeManager errorWithCode:status];
        }
    }
    
    return result;
}
- (NSString*) authenticateBioPassPhraseWithPrompt:(NSString*)prompt  error:(NSError**)errorOut

{
    NSString* gp = nil;
    
    [self correctKeychainPermissions];
    
    // Read the guidPassphrase from the keychain.
    NSMutableDictionary *query = @{ (__bridge id)kSecAttrService     : [SCPasscodeManager bioPassphraseIdentifier],
                             (__bridge id)kSecAttrAccount            : @"",
                             (__bridge id)kSecReturnData             : @YES,
                             (__bridge id)(kSecMatchLimit)           :(__bridge id) kSecMatchLimitOne,
                             (__bridge id)(kSecClass)                :(__bridge id) kSecClassGenericPassword,
                             (__bridge id)(kSecAttrSynchronizable)   :(__bridge id) kSecAttrSynchronizableAny
                             }.mutableCopy;
    
    if(prompt)
    {
        [query setObject:prompt forKey: (__bridge id)kSecUseOperationPrompt];
    }
    
    CFTypeRef passwordData = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &passwordData);
    
    if (status == errSecSuccess)
    {
        gp = [[NSString alloc] initWithData:(__bridge_transfer NSData *)passwordData encoding:NSUTF8StringEncoding];
    }
    
    if(!gp && (status != errSecItemNotFound))
    {
        if(errorOut)
        {
            *errorOut = [SCPasscodeManager errorWithCode:status];
        }
    }
    
    return gp;
}


-(NSData*) makeBioPassphraseWithError: (NSError**)errorOut
{
    BOOL        success = FALSE;
    char*       newPassPhrase = NULL;
    NSData*     bioPassphraseData = NULL;
    
    // try deleting old one first
    [SCPasscodeManager deleteBioPassphraseWithError: NULL ];
    
    if(IsntSCLError(RNG_GetPassPhrase(128, &newPassPhrase)))
    {
        CFErrorRef sacError = NULL;
        // Should be the secret invalidated when passcode is removed? If not then use kSecAttrAccessibleWhenUnlocked
        SecAccessControlRef sacObject = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                    kSecAccessControlUserPresence, &sacError);
        if(sacError)
        {
            if(errorOut)
            {
                 *errorOut =  (__bridge NSError *)sacError;
            }
            
        }
        else
        {
            bioPassphraseData = [NSData dataWithBytesNoCopy:newPassPhrase length:strlen(newPassPhrase) freeWhenDone:YES];
            

            NSDictionary *query = @{ (__bridge id)kSecAttrService            : [SCPasscodeManager bioPassphraseIdentifier],
                                     (__bridge id)kSecAttrAccount            : @"",
                                     (__bridge id)(kSecValueData)            : bioPassphraseData,
                                     (__bridge id)(kSecClass)                :(__bridge id) kSecClassGenericPassword,
                                     (__bridge id)kSecUseNoAuthenticationUI: @YES,
                                     (__bridge id)kSecAttrAccessControl: (__bridge_transfer id)sacObject
                                     
                                     };
            
            OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
            
            if( status == errSecSuccess )
            {
                success = YES;
            }
            else
            {
                if(errorOut)
                {
                    *errorOut = [SCPasscodeManager errorWithCode:status];
                }
            }

        }
        
    }
    
    return bioPassphraseData;
}


+(BOOL)  deleteBioPassphraseWithError:(NSError**)errorOut
{
    BOOL success = NO;
    
    NSDictionary *query = @{ (__bridge id)kSecAttrService            : [SCPasscodeManager bioPassphraseIdentifier],
                             (__bridge id)kSecAttrAccount            : @"",
                             (__bridge id)(kSecClass)                :(__bridge id) kSecClassGenericPassword,
                             (__bridge id)(kSecAttrSynchronizable)   :(__bridge id) kSecAttrSynchronizableAny
                             };
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    
    if( status == errSecSuccess )
    {
        success = YES;
    }
    else
    {
        if(errorOut)
        {
            *errorOut = [SCPasscodeManager errorWithCode:status];
        }
    }
    
    return success;
}

#pragma mark - storageBlob interface

-(PassPhraseSource) passPhraseSourceForKey:(SCKeyContextRef)pKey
{
    PassPhraseSource  result = kPassPhraseSource_Unknown;
    uint8_t* keyData = NULL;
    size_t  keyDataLen = 0;
    
    if(IsntSCLError(SCKeyGetAllocatedProperty(pKey, kPassPhraseSourceKey.UTF8String, NULL,  (void*)&keyData ,  &keyDataLen))
       && keyData && keyDataLen > 0)
    {
        NSData* data = [NSData dataWithBytes:keyData length:keyDataLen];
        const NSString* passPhraseSourceString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        if([passPhraseSourceString isEqualToString:kPassPhraseSourceKey_keyboard ])
        {
            result = kPassPhraseSource_Keyboard;
        }
        else if([passPhraseSourceString isEqualToString:kPassPhraseSourceKey_keychain ])
        {
            result  = kPassPhraseSource_Keychain;
        }
    }
    
    return result;
    
}

// FIXME: !
/* 
 -- this isnt pretty, but I need to keep the pbkdf2 SCKey packet in the proper order 
 for the SCKeyDeserialize() code to work properly.. among other things it expects the 
 "kdf" key to ne there before the "encrypted" key...  in retrospect I should have named 
 "encrypted" something else.  
 
 the problem is that you can not predict the order that NSDictionary  NSJSONSerialization 
 will put things into.  so for now since this isn't exported but simply a way for me to
 feed SCKeyDeserialize() from a blob,  this will work.
 
 --- Vinnie
  */

-(NSString*) pbkDF2fromDict:(NSDictionary*)dict
{
    if(!dict)
        return NULL;
   
    NSInteger version = 2;
    NSString* keySuite = [dict objectForKey:@"keySuite"];
    NSString* salt = [dict objectForKey:@"salt"];
    NSInteger rounds = [[dict objectForKey:@"rounds"] integerValue];
    NSString* keyHash = [dict objectForKey:@"keyHash"];
    NSString* encrypted = [dict objectForKey:@"encrypted"];
    NSString* locator = [dict objectForKey:@"locator"];
    NSString* iv = [dict objectForKey:@"iv"];;
    NSString* passPhraseSource = [dict objectForKey:@"passPhraseSource"];
    
    
    NSString* passPhraseSourceLine = passPhraseSource
                                    ? [NSString stringWithFormat: @",\n\t\"passPhraseSource\": \"%@\"\n", passPhraseSource]
                                    : @"\n";
    
    NSString* str = [NSString stringWithFormat:
                   @" {\n"
                   "\t\"version\": %d,\n"
                   "\t\"keySuite\": \"%@\",\n"
                   "\t\"kdf\": \"pbkdf2\", \n"
                   "\t\"salt\": \"%@\",\n"
                   "\t\"rounds\": %d,\n"
                   "\t\"keyHash\": \"%@\",\n"
                   "\t\"encrypted\": \"%@\",\n"
                   "\t\"locator\": \"%@\",\n"
                   "\t\"iv\": \"%@\""
                   "%@"
                   "}\n",
                   (int)version,
                   keySuite,
                   salt, (int)rounds, keyHash, encrypted, locator, iv ,passPhraseSourceLine];
    
    return str;
}

-(NSArray*) pbkDF2KeysWithError:(NSError**)errorOut

{
    NSError*            error = NULL;
    
    NSURL *storageBlobURL = [SCPasscodeManager storageBlobURL];
  
    NSData* storageBlob = [NSData dataWithContentsOfURL:storageBlobURL
                                                    options:0
                                               error:&error];

     NSArray* blobs = NULL;
    if(!error)
    {
        id blobData = [NSJSONSerialization JSONObjectWithData:storageBlob options:0 error:&error    ];
        
        if(!error && blobData)
        {
            if([blobData isKindOfClass: [NSArray class]])
                blobs = blobData;
            else if ([blobData isKindOfClass: [NSDictionary class]])
                blobs = @[blobData];
        }
        else
        {
            error = [SCimpUtilities errorWithSCLError:kSCLError_CorruptData];
            
        }
        
    }

    if(error && errorOut)
    {
        *errorOut = error.copy;
    }
 
    return blobs;
}

/* 
 
 what has changed here from previous version is that we can specify what kind of
 passphrase source, sucn as the keychain or keyboard we want to use to unlock this with.
 we can also try multiple keys till we get them correct 
 
 */

- (SCKeyContextRef) unlockStorageBlobWithPassphase:(NSString*)passPhrase
                               passPhraseSource:(PassPhraseSource)passPhraseSource
                                             error:(NSError**)errorOut
{
    SCLError            err = kSCLError_NoErr;
    SCKeyContextRef     pKey = kInvalidSCKeyContextRef;
    SCKeyContextRef     sKey = kInvalidSCKeyContextRef;
    NSError*            error = NULL;
    NSString*  lookingForSource = NULL;
    
    NSArray* blobs = [self pbkDF2KeysWithError:&error];
    if(error) goto done;

    switch (passPhraseSource)
    {
        case kPassPhraseSource_Keyboard:
            lookingForSource = kPassPhraseSourceKey_keyboard;
            break;
            
        case kPassPhraseSource_Keychain:
            lookingForSource = kPassPhraseSourceKey_keychain;
            break;
          
        case kPassPhraseSource_Recovery:
            lookingForSource = kPassPhraseSourceKey_recovery;
            break;

        case kPassPhraseSource_BioMetric:
            lookingForSource = kPassPhraseSourceKey_biometric;
            break;
 
        default:
            lookingForSource = kPassPhraseSourceKey_unknown;
            break;
    }
    
    // walk through the blobs tryng to find a match
   	for(NSDictionary *keyDict in  blobs)
    {
        NSString* source = [keyDict objectForKey:kPassPhraseSourceKey];
        
        if(!source
           || [source  isEqualToString:kPassPhraseSourceKey_unknown]
           || [source isEqualToString: lookingForSource])
        {
            
            NSString* str = [self pbkDF2fromDict:keyDict];
            
            // attempt to deserialize this
            if(pKey) SCKeyFree(pKey), pKey = NULL;
            err = SCKeyDeserialize((uint8_t*) str.UTF8String,  str.length, &pKey); CKERR;
            
            // attemp to unlock passphrase key and make a SKey
            err = SCKeyDecryptFromPassPhrase(pKey,(uint8_t*) passPhrase.UTF8String, passPhrase.length, &sKey );
            
            // Anything but wrong passphrase, we stop trying
            if(err != kSCLError_BadIntegrity) break;
         }
    }

done:
    if(IsSCLError(err))
    {
        *errorOut = [SCimpUtilities errorWithSCLError:err];
    }
    
    if(error && errorOut)
    {
        *errorOut = error.copy;
    }
    
    if(pKey) SCKeyFree(pKey), pKey = NULL;
    
    return sKey;
}


- (BOOL) updateStorageBlobWithPassphase: (NSString*) passPhrase
                             storageKey:(SCKeyContextRef)sKey
                       passPhraseSource:(PassPhraseSource)passPhraseSource
                                  error:(NSError**)errorOut
{
    NSError*            error = NULL;
    SCLError            err = kSCLError_NoErr;
    SCKeyContextRef     pKey = kInvalidSCKeyContextRef;
    NSString*           newKeyBlobString   = NULL;
    NSArray*            blobs = NULL;
  
    uint8_t*            keyData = NULL;
    size_t              keyDataLen = 0;
    BOOL                success = FALSE;
    NSString*           passPhraseSourceString = kPassPhraseSourceKey_unknown;
 
    NSURL *storageBlobURL = [SCPasscodeManager storageBlobURL];
    BOOL fileExists = [storageBlobURL checkResourceIsReachableAndReturnError:NULL];
 
    NSString *newBlobString = @"";
    BOOL isKeychainOrKeyboard = NO;
    
    // read in the existing entries
    if(fileExists)
    {
        blobs = [self pbkDF2KeysWithError:&error];
         if(error) goto done;
    }
    
    // create a new pbkdf2 entry for the storage key
    {
    
        // Encrypt the storage key and extract metaData
        err = SCKeyEncryptToPassPhrase(sKey, (const uint8_t*)passPhrase.UTF8String, passPhrase.length, &pKey); CKERR;
        
        switch (passPhraseSource)
        {
            case kPassPhraseSource_Keyboard:
                passPhraseSourceString = kPassPhraseSourceKey_keyboard;
                isKeychainOrKeyboard = YES;
                break;
     
            case kPassPhraseSource_Keychain:
                passPhraseSourceString = kPassPhraseSourceKey_keychain;
                isKeychainOrKeyboard = YES;
                 break;
  
            case kPassPhraseSource_Recovery:
                passPhraseSourceString = kPassPhraseSourceKey_recovery;
                isKeychainOrKeyboard = NO;
                break;
                
            case kPassPhraseSource_BioMetric:
                passPhraseSourceString = kPassPhraseSourceKey_biometric;
                isKeychainOrKeyboard = NO;
                break;

            default:
                break;
        }
        
        err = SCKeySetProperty (pKey, kPassPhraseSourceKey.UTF8String, SCKeyPropertyType_UTF8String,
                                    (void*)passPhraseSourceString.UTF8String, passPhraseSourceString.length); CKERR;
        
        err = SCKeySerialize(pKey, &keyData, &keyDataLen); CKERR;
        
        newKeyBlobString = [[NSString alloc]initWithBytesNoCopy:keyData length:keyDataLen encoding:NSUTF8StringEncoding freeWhenDone:YES];
    }
    
    
    // filter out the same kind of passPhraseSource in the existing file  as we are updating
    {
        NSMutableArray *tempBlobs = @[].mutableCopy;
        
        for(NSDictionary* blob in blobs)
        {
            NSString* blobSource = [blob objectForKey:@"passPhraseSource"];
            
            // is it the same as we are replacing?
             if([blobSource isEqualToString:passPhraseSourceString]) continue;
            
            // if the new one if KB or KC, punt those kinds too.
            if(isKeychainOrKeyboard
               && ([blobSource isEqualToString:kPassPhraseSourceKey_keyboard]
                    || [blobSource isEqualToString:kPassPhraseSourceKey_keychain]))
                continue;
            
            // old style PBKDF2 files didnt have a passphrase source.
            if(isKeychainOrKeyboard && !blobSource)
                continue;
            
            [tempBlobs addObject:blob];
        }
        
        blobs = tempBlobs;
    }
  
    // create the new storage blob with the new key and old material
    {
        BOOL hasMoreMultipleKeys = blobs.count > 0;
      
        if(hasMoreMultipleKeys)
        {
            newBlobString =[newBlobString stringByAppendingString:@"[\n" ];
        }
        
        newBlobString = [newBlobString stringByAppendingString:newKeyBlobString];
        
        if(hasMoreMultipleKeys)
        {
             for(NSDictionary* blob in blobs)
            {
                newBlobString =[newBlobString stringByAppendingFormat:@",\n%@", [self pbkDF2fromDict:blob]];
            }
            
            newBlobString =[newBlobString stringByAppendingString:@"]\n" ];
         }
     }
    
    [newBlobString writeToURL:storageBlobURL
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                         error:&error];
   
    
done:
    
    if(IsSCLError(err))
    {
        error = [SCimpUtilities errorWithSCLError:err];
    }

    if(error)
    {
        if(errorOut)
        {
            *errorOut = error;
        }
    }
    else
    {
        success = YES;
     }

    return success;

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Passcode manager
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define STORAGEKEY_LEN 32

- (BOOL)configureStorageKeyWithError:(NSError **)errorOut
{
	// Is this method thread-safe ?
	// Does it need to be ?
	//
	// If yes, then add proper thread-safe locks.
	// If no, then add a proper assert.
	
    
    SCLError        err = kSCLError_NoErr;
    SCKeyContextRef sKey = kInvalidSCKeyContextRef;
    NSError         *error  = NULL;
    BOOL            result = NO;
    
    NSURL *storageBlobURL = [SCPasscodeManager storageBlobURL];
    BOOL fileExists = [storageBlobURL checkResourceIsReachableAndReturnError:NULL];
    
    // have we set one up yet?
    if(!fileExists)
    {
        // we use the UUID only as a nonce, it should be unique but doesnt have to be secure
        uint8_t    uuid[STORAGEKEY_LEN];
        err = RNG_GetBytes(uuid,sizeof(uuid)); CKERR;
        
        // generate a 128 bit storage key and a 128 bit IV
        uint8_t    IV[16];
        err = RNG_GetBytes(IV,sizeof(IV)); CKERR;
        
        err = SCKeyNew(kSCKeySuite_AES128, uuid, sizeof(uuid), &sKey); CKERR;
        err = SCKeySetProperty (sKey, kSCKeyProp_IV, SCKeyPropertyType_Binary,  IV   , sizeof(IV) ); CKERR;
        
        //uf we are going to hose the storage key, we might as well clear the keychain.
        [SCPasscodeManager deleteGuidPassphraseWithError:NULL];
        
        // Make a temporary GUID passphrase, Store it in the keychain.
        if( [self makeGuidPassphraseWithError:&error])
        {
            // update passphrase and key on keychain
            [self  updateStorageBlobWithPassphase:[self guidPassphraseWithError:&error]
                                       storageKey:sKey
                                 passPhraseSource:kPassPhraseSource_Keychain
                                            error:&error];
            
            // no timeout info
            //        [self.passphraseTimeoutCredential deleteCredential];
            
            _isConfigured = YES;
            unlocked = YES;
            result = YES;
        }
        
    }
    else
    {
        // verify file
        [self pbkDF2KeysWithError:&error];
        if(error) goto done;
        
        // if guid passphrase, read it in and unlock
        NSString* gp = [self guidPassphraseWithError:&error];
        
        if(gp && gp.length)
        {
            
            sKey = [self unlockStorageBlobWithPassphase:gp
                                    passPhraseSource:kPassPhraseSource_Keychain
                                                  error:&error ];
            
            if(!error)
            {
                unlocked = YES;
                _isConfigured = YES;
                result = YES;

            }
            else
            {
                // this is a bad case, we specified a GUID passphrase, but it didnt work.
                
                if([error.domain isEqualToString:kSCErrorDomain]
                   && error.code == kSCLError_BadIntegrity)
                {
                     // we ill have to unlock it later.
                    _isConfigured = YES;
                    error = NULL;
                }
                else
                {
                    DDLogRed(@"failed to unlock GUIDpasshrase - %@", error.localizedDescription);
                 }
            }
            
        }
        else
        {
        if(!error)
            _isConfigured = YES;

            // we ill have to unlock it later.
        }
    }
         // get the passphrase timeout item
        //        self.timeoutItem = self.passphraseTimeoutCredential.data;
done:
   
    if(errorOut)
    {
        *errorOut = error;
    }

    self.storageKey = sKey;
    
    return result;
    
} // -configureCipherKeys

- (void) setPasscodeTimeout:(NSTimeInterval)timeout
{
    _timeout.delay = timeout;
    
    // write it to keychain
//    self.passphraseTimeoutCredential.data = self.timeoutItem;
}

- (NSTimeInterval) passcodeTimeout {
    
    return _timeout.delay;
}



- (BOOL)storageKeyIsAvailable
{
    return SCKeyContextRefIsValid(storageKey);
}

- (BOOL)isLocked
{
	// Is this method thread-safe ?
	// Does it need to be ?
	//
	// If yes, then add proper locks.
	// If no, then add proper assert.
	
    return (SCKeyContextRefIsValid(storageKey) && unlocked) ? NO : YES;
}

- (void)zeroStorageKey
{
	// Is this method thread-safe ?
	// Does it need to be ?
	//
	// If yes, then add proper locks.
	// If no, then add proper assert.
    
    if(SCKeyContextRefIsValid(storageKey))
    {
        SCKeyFree(storageKey); storageKey = NULL;
    }
    
    unlocked = NO;
}

- (void)lock
{
	DDLogAutoTrace();
	NSAssert([NSThread isMainThread], @"Method NOT thread-safe !");
	
	{
		__strong id <SCPasscodeDelegate> delegate = self.delegate;
		if ([delegate respondsToSelector:@selector(passcodeManagerWillLock:)]) {
			[delegate passcodeManagerWillLock:self];
		}
	}
	
    unlocked = NO;

	{
		__strong id <SCPasscodeDelegate> delegate = self.delegate;
		if ([delegate respondsToSelector:@selector(passcodeManagerDidLock)]) {
			[delegate passcodeManagerDidLock:self];
		}
	}
}


- (BOOL) unlockWithPassphrase:(NSString *)passphrase
             passPhraseSource:(PassPhraseSource)passPhraseSourceIn
                        error:(NSError **)errorOut
{
	DDLogAutoTrace();
	NSAssert([NSThread isMainThread], @"Method NOT thread-safe !");

    BOOL result = NO;
    
	SCKeyContextRef sKey = NULL;
	sKey = [self unlockStorageBlobWithPassphase:passphrase
	                           passPhraseSource:passPhraseSourceIn
	                                      error:errorOut];
    if(sKey)
    {
        if(!storageKey)
		{
			storageKey = sKey;
		}
		
		unlocked = YES;
		result = YES;

		__strong id <SCPasscodeDelegate> delegate = self.delegate;
		if ([delegate respondsToSelector:@selector(passcodeManagerDidUnlock:)]) {
			[delegate passcodeManagerDidUnlock:self];
		}
	}
    
    self.failedTries = SCKeyContextRefIsValid(sKey)?0:self.failedTries+1;
	
	return result;
}

- (BOOL) removePassphraseWithPassPhraseSource:(PassPhraseSource)passPhraseSource
                                        error:(NSError**)errorOut
{
    BOOL ok     = NO;
    NSError     *error = NULL;
    
    self.failedTries = 0;
    
      if(storageKey)
      {
          
          if(passPhraseSource == kPassPhraseSource_Keyboard)
          {
              // Make a temporary GUID passphrase, Store it in the keychain.
              if( [self makeGuidPassphraseWithError:&error])
              {
                  // update passphrase and key on keychain
                  ok =  [self  updateStorageBlobWithPassphase:[self guidPassphraseWithError:&error]
                                                   storageKey:storageKey
                                             passPhraseSource:kPassPhraseSource_Keychain
                                                        error:&error];
                  
              }
   
          }
          else
          {
              // we dot handle removal of anything but non- keyboard yet
              error = [SCimpUtilities errorWithSCLError:kSCLError_LazyProgrammer];
          }
          
       }
    
    
    if(errorOut)
        *errorOut = error;

  
    return  ok;
}


- (BOOL) hasKeyChainPassCode
{
    NSArray* blobTypes = [self keyBlobTypesAvailable];
    
    BOOL hasKeyChainBlob = [blobTypes containsObject:@(kPassPhraseSource_Keychain)];
    BOOL hasUnknownBlob = [blobTypes containsObject:@(kPassPhraseSource_Unknown)];
    BOOL hasGuidPassphrase = [SCPasscodeManager hasGuidPassphrase];
    
    return  hasGuidPassphrase && (hasKeyChainBlob ||hasUnknownBlob);
}


- (BOOL) updatePassphrase: (NSString *) passphrase error:(NSError**)error
{
    BOOL ok     = NO;
    
    NSString* gp = [self guidPassphraseWithError: error];
   
    if(storageKey)
    {
        if(gp)
        {
            [SCPasscodeManager deleteGuidPassphraseWithError: NULL];
        }
        
        // update passphrase and key on keychain
        ok = [self  updateStorageBlobWithPassphase:passphrase
                                        storageKey:storageKey
                                  passPhraseSource:kPassPhraseSource_Keyboard
                                             error:error];
        
        self.failedTries = 0;
      }
       
      return ok;
}

#pragma mark - storageBlob interface


// format the recovery key imto something usuable.
- (NSData*)recoveryKeyBlob
{
    NSData      *result = NULL;
    
    NSDictionary* dict = [self recoveryKeyDictionary ];
    if(dict)
    {
        NSString* str = [self pbkDF2fromDict:dict];
        result = [str dataUsingEncoding:NSUTF8StringEncoding];
     }
    
    return result;

}

 - (NSDictionary*)recoveryKeyDictionary
{
    NSError     *error = NULL;
    NSDictionary      *result = NULL;
    
    NSArray* blobs = [self pbkDF2KeysWithError:&error];
  
    if(!error)
    {
        // walk through the blobs tryng to find a match
        for(NSDictionary *keyDict in  blobs)
        {
            NSString* source = [keyDict objectForKey:kPassPhraseSourceKey];
            
            if( [source  isEqualToString:kPassPhraseSourceKey_recovery])
            {
                result = keyDict.copy;
                 break;
            }
        }
   
    }
    return result;
}

- (BOOL) removeRecoveryKeyWithError:(NSError**) errorOut
{
    NSError     *error = NULL;
    BOOL ok     = NO;
    
    while(storageKey)
    {
        NSURL *storageBlobURL = [SCPasscodeManager storageBlobURL];
        NSString *newBlobString = @"";
        
        // read in the existing entries
        NSArray* blobs = [self pbkDF2KeysWithError:&error];
        if(error || !blobs) break;
        
        // filter out the same kind of passPhraseSource in the existing file  as we are updating
        {
            NSMutableArray *tempBlobs = @[].mutableCopy;
            
            for(NSDictionary* blob in blobs)
            {
                NSString* blobSource = [blob objectForKey:@"passPhraseSource"];
                
                // is it the same as we are replacing?
                if([blobSource isEqualToString:kPassPhraseSourceKey_recovery]) continue;
                
                [tempBlobs addObject:blob];
            }
            
            blobs = tempBlobs;
        }
        
        // dont allow delete of only key
         if(!blobs.count) break;
           
        // create the new storage blob with the new key and old material
        
        NSUInteger count = blobs.count;
        
        if(count == 1)
        {
            newBlobString = [self pbkDF2fromDict:[blobs firstObject]];
 
        }
        else
        {
            newBlobString =[newBlobString stringByAppendingString:@"[\n" ];
            
            for(NSDictionary* blob in blobs)
            {
                newBlobString =[newBlobString stringByAppendingString: [self pbkDF2fromDict:blob]];
                
                if(--count)
                    newBlobString =[newBlobString stringByAppendingString:@",\n"];

            }
            newBlobString =[newBlobString stringByAppendingString:@"]\n" ];
            
        }
        
        [newBlobString writeToURL:storageBlobURL
                       atomically:YES
                         encoding:NSUTF8StringEncoding
                            error:&error];
         break;
    }
    
    return ok;
 
}


- (BOOL) updateRecoveryKey: (NSString *) passphrase
           recoveryKeyDict: (NSDictionary**) recoveryKeyDictOut
                     error:(NSError**)errorOut
{
 
        NSError     *error = NULL;
        BOOL ok     = NO;
    
    if(storageKey)
    {
        
        // update passphrase and key on keychain
        ok = [self  updateStorageBlobWithPassphase:passphrase
                                        storageKey:storageKey
                                  passPhraseSource:kPassPhraseSource_Recovery
                                             error:&error];
        
        if(ok && !error && recoveryKeyDictOut)
        {
            *recoveryKeyDictOut = [self recoveryKeyDictionary ];
        }
      }
    
    
    if(error && errorOut)
    {
        *errorOut = error.copy;
    }
    
    return ok;
}

-(NSArray*) keyBlobTypesAvailable
{
    NSError     *error = NULL;
    NSMutableArray* results = @[].mutableCopy;
   
    NSURL *storageBlobURL = [SCPasscodeManager storageBlobURL];
      BOOL fileExists = [storageBlobURL checkResourceIsReachableAndReturnError:NULL];

    // read in the existing entries
    if(fileExists)
    {
        NSArray* blobs = [self pbkDF2KeysWithError:&error];
      
        for(NSDictionary *keyDict in  blobs)
        {
            NSString* source = [keyDict objectForKey:kPassPhraseSourceKey];
            
            if([source  isEqualToString:kPassPhraseSourceKey_keychain])
            {
                [results addObject:@(kPassPhraseSource_Keychain)];
            }
            else if([source  isEqualToString:kPassPhraseSourceKey_keyboard])
            {
                [results addObject:@(kPassPhraseSource_Keyboard)];
            }
            else if([source  isEqualToString:kPassPhraseSourceKey_recovery])
            {
                [results addObject:@(kPassPhraseSource_Recovery)];
            }
            else if([source  isEqualToString:kPassPhraseSourceKey_biometric])
            {
                [results addObject:@(kPassPhraseSource_BioMetric)];
            }
             else
                 [results addObject:@(kPassPhraseSource_Unknown)];
        }
        
    }
    

    return results;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Biometric key
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

 - (BOOL)hasBioMetricKey
{
    
    NSError         *error = NULL;
    NSDictionary    *dict = NULL;
    BOOL            result = NO;
    
    NSArray* blobs = [self pbkDF2KeysWithError:&error];
    
     if(!error)
    {
        // walk through the blobs tryng to find a match
        for(NSDictionary *keyDict in  blobs)
        {
            NSString* source = [keyDict objectForKey:kPassPhraseSourceKey];
            
            if( [source  isEqualToString:kPassPhraseSourceKey_biometric])
            {
                dict = keyDict.copy;
                break;
            }
        }
    }

    if(dict)
    {
        result = [self hasBioPassphraseWithError:&error];
    }
    
    return result;
    
}

-(BOOL) createBioMetricKeyBlobWithError:(NSError**)errorOut

{
    
    NSError     *error = NULL;
    BOOL       ok    = NO;
    
    if(storageKey)
    {
        NSData* bioPassphraseData  = [self makeBioPassphraseWithError:&error];
        
        if(bioPassphraseData)
        {
            ok = [self  updateStorageBlobWithPassphase:[NSString stringWithUTF8String:[bioPassphraseData bytes]]
                                            storageKey:storageKey
                                      passPhraseSource:kPassPhraseSource_BioMetric
                                                 error:&error];
        }
    }
    
    
    if(error && errorOut)
    {
        *errorOut = error.copy;
    }
    
    return ok;
}

- (BOOL) removeBioMetricKeyWithError:(NSError**) errorOut
{
    NSError     *error = NULL;
    BOOL ok     = NO;
    
    while(storageKey)
    {
        NSURL *storageBlobURL = [SCPasscodeManager storageBlobURL];
        NSString *newBlobString = @"";
        
        // read in the existing entries
        NSArray* blobs = [self pbkDF2KeysWithError:&error];
        if(error || !blobs) break;
        
        // filter out the same kind of passPhraseSource in the existing file  as we are updating
        {
            NSMutableArray *tempBlobs = @[].mutableCopy;
            
            for(NSDictionary* blob in blobs)
            {
                NSString* blobSource = [blob objectForKey:@"passPhraseSource"];
                
                // is it the same as we are replacing?
                if([blobSource isEqualToString:kPassPhraseSourceKey_biometric]) continue;
                
                [tempBlobs addObject:blob];
            }
            
            blobs = tempBlobs;
        }
        
        // dont allow delete of only key
        if(!blobs.count) break;
        
        // create the new storage blob with the new key and old material
        
        NSUInteger count = blobs.count;
        
        if(count == 1)
        {
            newBlobString = [self pbkDF2fromDict:[blobs firstObject]];
            
        }
        else
        {
            newBlobString =[newBlobString stringByAppendingString:@"[\n" ];
            
            for(NSDictionary* blob in blobs)
            {
                newBlobString =[newBlobString stringByAppendingString: [self pbkDF2fromDict:blob]];
                
                if(--count)
                    newBlobString =[newBlobString stringByAppendingString:@",\n"];
                
            }
            newBlobString =[newBlobString stringByAppendingString:@"]\n" ];
            
        }
        
        [newBlobString writeToURL:storageBlobURL
                       atomically:YES
                         encoding:NSUTF8StringEncoding
                            error:&error];
        break;
    }
    
    
    [SCPasscodeManager deleteBioPassphraseWithError:NULL];
    
    if(error && errorOut)
    {
        *errorOut = error.copy;
    }

    return ok;
    
}

-(BOOL) unlockWithBiometricKeyWithPrompt:(NSString*)prompt  error:(NSError**)errorOut
{
    BOOL ok     = NO;
    NSError     *error = NULL;

    
    NSString* bioPassPhrase = [self authenticateBioPassPhraseWithPrompt: prompt
                                                                  error: &error];
    
    if(bioPassPhrase)
    {
  
        [STAppDelegate.passcodeManager unlockWithPassphrase: bioPassPhrase
                                           passPhraseSource: kPassPhraseSource_BioMetric                                                      error: &error];
        
        if(!error)
            ok = YES;
    }
    
    if(error && errorOut)
    {
        *errorOut = error.copy;
    }
    
    return ok;

}


//-(BOOL) testTouchID
//{
//    LAContext *context = [[LAContext alloc] init];
//    NSError *error = nil;
//    
//    context.localizedFallbackTitle = @"";
//    
//    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
//                             error:&error])
//    {
//        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
//                localizedReason:NSLocalizedString(@"Unlock Silent Text", nil)
//                          reply:^(BOOL success, NSError *evaluateError) {
//                              if (success)
//                              {
//                                   DDLogRed(@"TouchID OK");
//                              
//                              
//                              } else
//                              {
//                                  DDLogRed(@"TouchID fail: %@", evaluateError.localizedDescription);
//                                  
//                              }
//                          }];
//    }
//    else
//    {
//       DDLogRed(@"TouchID cant eval: %@", error.localizedDescription);
//    }
//    
//    return YES;
//}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Recovery Key
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+(NSString*) createRecoveryKeyString
{
    CFUUIDBytes recoveryKey;
    RNG_GetBytes(&recoveryKey,sizeof(recoveryKey));
    CFUUIDRef uuid = CFUUIDCreateFromUUIDBytes(NULL, recoveryKey);
    NSString* result = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
	CFRelease(uuid);
    
    return  result;
}


+(NSString*) recoveryKeyCodeFromPassCode:(NSString*)passCode recoveryKeyDict:(NSDictionary*)inRecoveryKeyDict
{
    NSString* codeString = NULL;
    
    if(passCode && inRecoveryKeyDict)
    {
        NSString* keyHash = [ inRecoveryKeyDict objectForKey:@"keyHash"];
        
        codeString = [NSString stringWithFormat:@"silenttext:%@:%@", keyHash, passCode];

    }
    
    return codeString;
}


+(NSDictionary*) recoveryKeyComponentsFromCode:(NSString*)recoveryCode
{
    NSDictionary* result = NULL;
    
    if(recoveryCode)
    {
        NSArray* parts = [recoveryCode componentsSeparatedByString:@":"];
        
        if( parts.count >= 3
           && [[parts objectAtIndex:0] isEqualToString:@"silenttext" ])
        {
            NSString* keyHash = [parts objectAtIndex:1];
            NSString* passCode = [parts objectAtIndex:2];
            
            result = @{@"keyHash": keyHash,
                       @"passCode": passCode };
 
        }
        
       }
    

    
    return result;
    
}

/* These 2-syllable words are no longer than 9 characters. */
static char pgpWordListEven[256][10] =
{
    "aardvark",
    "absurd",
    "accrue",
    "acme",
    "adrift",
    "adult",
    "afflict",
    "ahead",
    "aimless",
    "Algol",
    "allow",
    "alone",
    "ammo",
    "ancient",
    "apple",
    "artist",
    "assume",
    "Athens",
    "atlas",
    "Aztec",
    "baboon",
    "backfield",
    "backward",
    "banjo",
    "beaming",
    "bedlamp",
    "beehive",
    "beeswax",
    "befriend",
    "Belfast",
    "berserk",
    "billiard",
    "bison",
    "blackjack",
    "blockade",
    "blowtorch",
    "bluebird",
    "bombast",
    "bookshelf",
    "brackish",
    "breadline",
    "breakup",
    "brickyard",
    "briefcase",
    "Burbank",
    "button",
    "buzzard",
    "cement",
    "chairlift",
    "chatter",
    "checkup",
    "chisel",
    "choking",
    "chopper",
    "Christmas",
    "clamshell",
    "classic",
    "classroom",
    "cleanup",
    "clockwork",
    "cobra",
    "commence",
    "concert",
    "cowbell",
    "crackdown",
    "cranky",
    "crowfoot",
    "crucial",
    "crumpled",
    "crusade",
    "cubic",
    "dashboard",
    "deadbolt",
    "deckhand",
    "dogsled",
    "dragnet",
    "drainage",
    "dreadful",
    "drifter",
    "dropper",
    "drumbeat",
    "drunken",
    "Dupont",
    "dwelling",
    "eating",
    "edict",
    "egghead",
    "eightball",
    "endorse",
    "endow",
    "enlist",
    "erase",
    "escape",
    "exceed",
    "eyeglass",
    "eyetooth",
    "facial",
    "fallout",
    "flagpole",
    "flatfoot",
    "flytrap",
    "fracture",
    "framework",
    "freedom",
    "frighten",
    "gazelle",
    "Geiger",
    "glitter",
    "glucose",
    "goggles",
    "goldfish",
    "gremlin",
    "guidance",
    "hamlet",
    "highchair",
    "hockey",
    "indoors",
    "indulge",
    "inverse",
    "involve",
    "island",
    "jawbone",
    "keyboard",
    "kickoff",
    "kiwi",
    "klaxon",
    "locale",
    "lockup",
    "merit",
    "minnow",
    "miser",
    "Mohawk",
    "mural",
    "music",
    "necklace",
    "Neptune",
    "newborn",
    "nightbird",
    "Oakland",
    "obtuse",
    "offload",
    "optic",
    "orca",
    "payday",
    "peachy",
    "pheasant",
    "physique",
    "playhouse",
    "Pluto",
    "preclude",
    "prefer",
    "preshrunk",
    "printer",
    "prowler",
    "pupil",
    "puppy",
    "python",
    "quadrant",
    "quiver",
    "quota",
    "ragtime",
    "ratchet",
    "rebirth",
    "reform",
    "regain",
    "reindeer",
    "rematch",
    "repay",
    "retouch",
    "revenge",
    "reward",
    "rhythm",
    "ribcage",
    "ringbolt",
    "robust",
    "rocker",
    "ruffled",
    "sailboat",
    "sawdust",
    "scallion",
    "scenic",
    "scorecard",
    "Scotland",
    "seabird",
    "select",
    "sentence",
    "shadow",
    "shamrock",
    "showgirl",
    "skullcap",
    "skydive",
    "slingshot",
    "slowdown",
    "snapline",
    "snapshot",
    "snowcap",
    "snowslide",
    "solo",
    "southward",
    "soybean",
    "spaniel",
    "spearhead",
    "spellbind",
    "spheroid",
    "spigot",
    "spindle",
    "spyglass",
    "stagehand",
    "stagnate",
    "stairway",
    "standard",
    "stapler",
    "steamship",
    "sterling",
    "stockman",
    "stopwatch",
    "stormy",
    "sugar",
    "surmount",
    "suspense",
    "sweatband",
    "swelter",
    "tactics",
    "talon",
    "tapeworm",
    "tempest",
    "tiger",
    "tissue",
    "tonic",
    "topmost",
    "tracker",
    "transit",
    "trauma",
    "treadmill",
    "Trojan",
    "trouble",
    "tumor",
    "tunnel",
    "tycoon",
    "uncut",
    "unearth",
    "unwind",
    "uproot",
    "upset",
    "upshot",
    "vapor",
    "village",
    "virus",
    "Vulcan",
    "waffle",
    "wallet",
    "watchword",
    "wayside",
    "willow",
    "woodlark",
    "Zulu"
};


/* These 3-syllable words are no longer than 11 characters. */
static char pgpWordListOdd[256][12] =
{
    "adroitness",
    "adviser",
    "aftermath",
    "aggregate",
    "alkali",
    "almighty",
    "amulet",
    "amusement",
    "antenna",
    "applicant",
    "Apollo",
    "armistice",
    "article",
    "asteroid",
    "Atlantic",
    "atmosphere",
    "autopsy",
    "Babylon",
    "backwater",
    "barbecue",
    "belowground",
    "bifocals",
    "bodyguard",
    "bookseller",
    "borderline",
    "bottomless",
    "Bradbury",
    "bravado",
    "Brazilian",
    "breakaway",
    "Burlington",
    "businessman",
    "butterfat",
    "Camelot",
    "candidate",
    "cannonball",
    "Capricorn",
    "caravan",
    "caretaker",
    "celebrate",
    "cellulose",
    "certify",
    "chambermaid",
    "Cherokee",
    "Chicago",
    "clergyman",
    "coherence",
    "combustion",
    "commando",
    "company",
    "component",
    "concurrent",
    "confidence",
    "conformist",
    "congregate",
    "consensus",
    "consulting",
    "corporate",
    "corrosion",
    "councilman",
    "crossover",
    "crucifix",
    "cumbersome",
    "customer",
    "Dakota",
    "decadence",
    "December",
    "decimal",
    "designing",
    "detector",
    "detergent",
    "determine",
    "dictator",
    "dinosaur",
    "direction",
    "disable",
    "disbelief",
    "disruptive",
    "distortion",
    "document",
    "embezzle",
    "enchanting",
    "enrollment",
    "enterprise",
    "equation",
    "equipment",
    "escapade",
    "Eskimo",
    "everyday",
    "examine",
    "existence",
    "exodus",
    "fascinate",
    "filament",
    "finicky",
    "forever",
    "fortitude",
    "frequency",
    "gadgetry",
    "Galveston",
    "getaway",
    "glossary",
    "gossamer",
    "graduate",
    "gravity",
    "guitarist",
    "hamburger",
    "Hamilton",
    "handiwork",
    "hazardous",
    "headwaters",
    "hemisphere",
    "hesitate",
    "hideaway",
    "holiness",
    "hurricane",
    "hydraulic",
    "impartial",
    "impetus",
    "inception",
    "indigo",
    "inertia",
    "infancy",
    "inferno",
    "informant",
    "insincere",
    "insurgent",
    "integrate",
    "intention",
    "inventive",
    "Istanbul",
    "Jamaica",
    "Jupiter",
    "leprosy",
    "letterhead",
    "liberty",
    "maritime",
    "matchmaker",
    "maverick",
    "Medusa",
    "megaton",
    "microscope",
    "microwave",
    "midsummer",
    "millionaire",
    "miracle",
    "misnomer",
    "molasses",
    "molecule",
    "Montana",
    "monument",
    "mosquito",
    "narrative",
    "nebula",
    "newsletter",
    "Norwegian",
    "October",
    "Ohio",
    "onlooker",
    "opulent",
    "Orlando",
    "outfielder",
    "Pacific",
    "pandemic",
    "Pandora",
    "paperweight",
    "paragon",
    "paragraph",
    "paramount",
    "passenger",
    "pedigree",
    "Pegasus",
    "penetrate",
    "perceptive",
    "performance",
    "pharmacy",
    "phonetic",
    "photograph",
    "pioneer",
    "pocketful",
    "politeness",
    "positive",
    "potato",
    "processor",
    "provincial",
    "proximate",
    "puberty",
    "publisher",
    "pyramid",
    "quantity",
    "racketeer",
    "rebellion",
    "recipe",
    "recover",
    "repellent",
    "replica",
    "reproduce",
    "resistor",
    "responsive",
    "retraction",
    "retrieval",
    "retrospect",
    "revenue",
    "revival",
    "revolver",
    "sandalwood",
    "sardonic",
    "Saturday",
    "savagery",
    "scavenger",
    "sensation",
    "sociable",
    "souvenir",
    "specialist",
    "speculate",
    "stethoscope",
    "stupendous",
    "supportive",
    "surrender",
    "suspicious",
    "sympathy",
    "tambourine",
    "telephone",
    "therapist",
    "tobacco",
    "tolerance",
    "tomorrow",
    "torpedo",
    "tradition",
    "travesty",
    "trombonist",
    "truncated",
    "typewriter",
    "ultimate",
    "undaunted",
    "underfoot",
    "unicorn",
    "unify",
    "universe",
    "unravel",
    "upcoming",
    "vacancy",
    "vagabond",
    "vertigo",
    "Virginia",
    "visitor",
    "vocalist",
    "voyager",
    "warranty",
    "Waterloo",
    "whimsical",
    "Wichita",
    "Wilmington",
    "Wyoming",
    "yesteryear",
    "Yucatan"
};

+(NSString*)  locatorCodeFromRecoveryKeyDict:(NSDictionary*)inRecoveryKeyDict
{
    
    NSString* keyHash = [ inRecoveryKeyDict objectForKey:@"keyHash"];

     NSUInteger shortHash = keyHash.hash;
    
    NSString*  locatorCode =  [NSString stringWithFormat:@"%s %s",
                               pgpWordListOdd[(shortHash >>8)&0xFF],
                               pgpWordListEven[(shortHash)&0xFF] ];

    return locatorCode;
}


#pragma mark - application state



- (void) applicationDidBecomeActive
{
    
    if(self.lastTimeActive)
    {
        NSTimeInterval  sleepTime = - [self.lastTimeActive timeIntervalSinceNow];
        
        if(_timeout.delay != DBL_MAX
           && sleepTime > _timeout.delay
           && ![self hasKeyChainPassCode])
        {
            [self lock];
            
        }
    }
    
    self.lastTimeActive = NULL;
}

 - (void) applicationWillResignActive
{
    
    self.lastTimeActive =[NSDate date];
}
 
@end