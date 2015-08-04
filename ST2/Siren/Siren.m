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
#if !__has_feature(objc_arc)
#error Please compile this class with ARC (-fobjc-arc).
#endif

#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <SCCrypto/SCCrypto.h> 

#import "Siren.h"
#import "AppConstants.h"
#import "STLogging.h"
#import "XMPPMessage+XEP_0033.h"
#import "XMPPMessage+SilentCircle.h"



#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_WARN;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


NSString *const SirenKey_message        = @"message";

NSString *const SirenKey_shredAfter     = @"shred_after";
NSString *const SirenKey_location       = @"location";
NSString *const SirenKey_fyeo           = @"fyeo";

NSString *const SirenKey_requestBurn    = @"request_burn";
NSString *const SirenKey_requestResend  = @"request_resend";

NSString *const SirenKey_requestReceipt = @"request_receipt";
NSString *const SirenKey_receivedID     = @"received_id";
NSString *const SirenKey_receivedTime   = @"received_time";

NSString *const SirenKey_cloudKey       = @"cloud_key";
NSString *const SirenKey_cloudLocator   = @"cloud_url";
NSString *const SirenKey_mimeType       = @"mime_type";
NSString *const SirenKey_mediaType      = @"media_type";
NSString *const SirenKey_thumbnail      = @"thumbnail";
NSString *const SirenKey_preview        = @"preview";
NSString *const SirenKey_mediaDuration  = @"duration";
NSString *const SirenKey_mediaWaveform  = @"waveform";
NSString *const SirenKey_vCard          = @"vcard";

NSString *const SirenKey_signature      = @"siren_sig_v2";

NSString *const SirenKey_ping           = @"ping";
NSString *const kPingRequest            = @"PING";
NSString *const kPingResponse           = @"PONG";
NSString *const SirenKey_capabilities   = @"capabilities";

NSString *const SirenKey_multicastKey   = @"multicast_key";
NSString *const SirenKey_requestThread  = @"request_threadkey";
NSString *const SirenKey_threadName     = @"threadName";

NSString *const SirenKey_callerIdName   = @"caller_id_name";
NSString *const SirenKey_callerIdNumber = @"caller_id_number";
NSString *const SirenKey_callerIdUser   = @"caller_id_user";
NSString *const SirenKey_recordedTime   = @"recorded_time";

NSString *const SirenKey_hasGPS         = @"hasGPS";
NSString *const SirenKey_mapCoordinate  = @"isMapCoordinate";

NSString *const SirenKey_testTimestamp  = @"test_time";

static const NSUInteger kNumSirenKeys = 20;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation Siren
{
	NSMutableDictionary *_info;
	
	NSData *_jsonData;
	NSString *_json;
	
	BOOL _badData;
}

@dynamic json;
@dynamic jsonData;

// Siren JSON properties

@dynamic message;

@dynamic shredAfter;
@dynamic location;
@dynamic fyeo;

@dynamic requestBurn;
@dynamic requestResend;

@dynamic requestReceipt;
@dynamic receivedID;
@dynamic receivedTime;

@dynamic cloudKey;
@dynamic cloudLocator;
@dynamic mimeType;
@dynamic mediaType;
@dynamic thumbnail;
@dynamic preview;
@dynamic duration;
@dynamic waveform;
@dynamic vcard;

@dynamic signature;

@dynamic ping;
@dynamic capabilities;

@dynamic multicastKey;
@dynamic requestThreadKey;
@dynamic threadName;

@dynamic callerIdName;
@dynamic callerIdNumber;
@dynamic callerIdUser;
@dynamic recordedTime;

@dynamic hasGPS;
@dynamic isMapCoordinate;

@dynamic testTimestamp;

// Siren metadata

@synthesize isPlainText = isPlainText;
@synthesize requiresLocation = requiresLocation;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Static
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static NSString *const kZuluTimeFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"; // ISO 8601 time.

static const long kNumDateFormatters = 1l;
static dispatch_semaphore_t _siren_df_semaphore  = NULL;
static NSDateFormatter *    _siren_dateFormatter = nil;
static NSArray*  _siren_hashableItems = nil;

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		_siren_df_semaphore = dispatch_semaphore_create(kNumDateFormatters);
		
        // Quinn "The Eskimo" pointed me to: 
        // <https://developer.apple.com/library/ios/#qa/qa1480/_index.html>.
        // The contained advice recommends all internet time formatting to use US POSIX standards.
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier: @"en_US_POSIX"];
        
		_siren_dateFormatter = [[NSDateFormatter alloc] init];
		_siren_dateFormatter.locale = enUSPOSIXLocale;
		_siren_dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
		_siren_dateFormatter.dateFormat = kZuluTimeFormat;
		
		NSArray *_siren_hashableItems_unsorted = @[
		  SirenKey_message,
		  SirenKey_cloudKey,
		  SirenKey_cloudLocator,
		  SirenKey_fyeo,
		  SirenKey_shredAfter,
		  SirenKey_requestBurn,
		  SirenKey_requestResend,
		  SirenKey_location,
		  SirenKey_requestThread,
		  SirenKey_vCard,
		  SirenKey_thumbnail,
		  SirenKey_mediaType,
		  SirenKey_preview,
          SirenKey_callerIdName,
          SirenKey_callerIdNumber,
          SirenKey_callerIdUser,
          SirenKey_mediaWaveform
		];
		
        _siren_hashableItems = [_siren_hashableItems_unsorted sortedArrayUsingSelector:@selector(compare:)];
	});
}

#pragma mark Init

+ (instancetype)sirenWithJSON:(NSString *)json
{
	return [[[self class] alloc] initWithJSON:json];
}

+ (instancetype)sirenWithJSONData:(NSData *)jsonData
{
	return [[[self class] alloc] initWithJSONData:jsonData];
}

+ (instancetype)sirenWithPlaintext:(NSString *)plaintext
{
	return [[[self class] alloc] initWithPlaintext:plaintext];
}

- (instancetype)initWithJSONData:(NSData *)jsonData
{
	if ((self = [super init]))
	{
        if (jsonData)
		{
            NSError *error = nil;
			
			_jsonData = jsonData;
			_info = [NSJSONSerialization JSONObjectWithData:_jsonData
			                                        options:NSJSONReadingMutableContainers
			                                          error:&error];
			if (error) {
                _badData = YES;
				
				_jsonData = nil;
				_info = [NSMutableDictionary dictionaryWithCapacity:kNumSirenKeys];
			}
        }
        else
		{
            _info = [NSMutableDictionary dictionaryWithCapacity:kNumSirenKeys]; // The number of different JSON keys
        }
    }
    return self;
}

- (instancetype)initWithJSON:(NSString *)json
{
	if ([Siren mayContainJSON:json])
	{
		NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
		
		if ((self = [self initWithJSONData:data]))
		{
			_json     = json; // Assign the ivar directly; i.e. don't force a reparse of the string.
			_jsonData = nil;  // As the data actually belongs to the string, release the NSData shell.
		}
		return self;
	}
	else
	{
		return [self initWithPlaintext:json];
	}
}

- (instancetype)initWithPlaintext:(NSString *)plaintext
{
	if (plaintext == nil) {
		return [self initWithJSONData:nil];
	}
	
	// Convert to JSON, and go through designated initializer
	
	NSString *json = [NSString stringWithFormat:@"{\"%@\":\"%@\"}", SirenKey_message, plaintext];
	NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
	
	if ((self = [self initWithJSONData:data]))
	{
		isPlainText = YES;
		
		_json     = json; // Assign the ivar directly; i.e. don't force a reparse of the string.
		_jsonData = nil;  // As the data actually belongs to the string, release the NSData shell.
	}
	return self;
}

- (instancetype)init
{
	return [self initWithJSONData:nil];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCopying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	Siren *copy = [super copyWithZone:zone];
	copy->_info = [_info mutableCopy];
	copy->_json = [_json copy];
	copy->_jsonData = [_jsonData copy];
	copy->_badData = _badData;
	
	copy->isPlainText = isPlainText;
	copy->requiresLocation = requiresLocation;
	
	return copy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utility Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (BOOL)mayContainJSON:(NSString *)inJson
{
	inJson = [inJson stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
    if (inJson.length > 2) { // There must be something in between the [] or {}.
        
        unichar firstChar = [inJson characterAtIndex: 0];
        unichar  lastChar = [inJson characterAtIndex: inJson.length - 1];
        
        return (firstChar == '{' && lastChar == '}') || (firstChar == '[' && lastChar == ']');
    }
	else {
		return NO;
	}
}

- (NSString *)localKeyForJsonKey:(NSString *)jsonKey
{
	static NSDictionary *mapping = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		mapping = @{
		  SirenKey_message        : @"message",
		  
		  SirenKey_shredAfter     : @"shredAfter",
		  SirenKey_location       : @"location",
		  SirenKey_fyeo           : @"fyeo",
		  
		  SirenKey_requestBurn    : @"requestBurn",
		  SirenKey_requestResend  : @"requestResend",
		  
		  SirenKey_requestReceipt : @"requestReceipt",
		  SirenKey_receivedID     : @"receivedID",
		  SirenKey_receivedTime   : @"receivedTime",
		
		  SirenKey_cloudKey       : @"cloudKey",
		  SirenKey_cloudLocator   : @"cloudLocator",
		  SirenKey_mimeType       : @"mimeType",
		  SirenKey_mediaType      : @"mediaType",
		  SirenKey_thumbnail      : @"thumbnail",
		  SirenKey_preview        : @"preview",
		  SirenKey_mediaDuration  : @"duration",
		  SirenKey_mediaWaveform  : @"waveform",
		  SirenKey_vCard          : @"vcard",
		  
		  SirenKey_signature      : @"signature",
		  
		  SirenKey_ping           : @"ping",
		  SirenKey_capabilities   : @"capabilities",
		  
		  SirenKey_multicastKey   : @"multicastKey",
		  SirenKey_requestThread  : @"requestThread",
		  SirenKey_threadName     : @"threadName",
		  
		  SirenKey_callerIdName   : @"callerIdName",
		  SirenKey_callerIdNumber : @"callerIdNumber",
		  SirenKey_callerIdUser   : @"callerIdUser",
		  SirenKey_recordedTime   : @"recordedTime",
		  
		  SirenKey_hasGPS         : @"hasGPS",
		  SirenKey_mapCoordinate  : @"mapCoordinate",
		  
		  SirenKey_testTimestamp  : @"testTimestamp",
		};
	});
	
	return [mapping objectForKey:jsonKey];
}

- (id)jsonValueForJsonKey:(NSString *)jsonKey expectedClass:(Class)expectedClass
{
	id value = [_info objectForKey:jsonKey];
	
	return [value isKindOfClass:expectedClass] ? value : nil;
}

- (void)setJsonValue:(id)jsonValue forJsonKey:(NSString *)jsonKey
{
	NSString *localKey = [self localKeyForJsonKey:jsonKey];
	NSAssert(localKey != nil, @"Missing mapping for jsonKey: %@", jsonKey);
	
	[self willChangeValueForKey:localKey];
	{
		_json     = nil;
		_jsonData = nil;
		
		[_info setValue:jsonValue forKey:jsonKey];
	}
	[self didChangeValueForKey:localKey];
}

- (NSDate *)dateFromZuluString:(NSString *)zuluString
{
	NSDate *date = nil;
	if (zuluString)
	{
		dispatch_semaphore_wait(_siren_df_semaphore, DISPATCH_TIME_FOREVER); {
		
			date = [_siren_dateFormatter dateFromString:zuluString];
		}
		dispatch_semaphore_signal(_siren_df_semaphore);
	}
	
	return date;
}

- (NSString *)zuluStringFromDate:(NSDate *)date
{
	NSString *zuluString = nil;
	if (date)
	{
		dispatch_semaphore_wait(_siren_df_semaphore, DISPATCH_TIME_FOREVER); {
			
			zuluString = [_siren_dateFormatter stringFromDate:date];
		}
		dispatch_semaphore_signal(_siren_df_semaphore);
	}
	
	return zuluString;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark JSON Accessors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)json
{
    if (_json == nil)
	{
		NSData *jsonData = self.jsonData; // MUST go through getter
		
		_json = [[NSString alloc] initWithBytes:[jsonData bytes]
		                                 length:[jsonData length]
		                               encoding:NSUTF8StringEncoding];
	}
	return _json;
}


- (NSData *)jsonData
{
	if (_jsonData == nil)
	{
		NSDictionary *info = [_info copy];
		
		if ([NSJSONSerialization isValidJSONObject:info])
		{
			NSError *error = nil;
			NSData *data = [NSJSONSerialization dataWithJSONObject:info options:0UL error:&error];
			
			if (error) {
				_badData = YES;
			}
			
			_jsonData = data;
			_json = nil;
		}
	}
    return _jsonData;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Siren JSON properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark message
- (NSString *)message
{
	return [self jsonValueForJsonKey:SirenKey_message expectedClass:[NSString class]];
}
- (void)setMessage:(NSString *)message
{
	[self setJsonValue:message forJsonKey:SirenKey_message];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark shredAfter
- (uint32_t)shredAfter
{
	NSNumber *timeInterval = [self jsonValueForJsonKey:SirenKey_shredAfter expectedClass:[NSNumber class]];
	return timeInterval ? [timeInterval unsignedIntValue] : 0;
}
- (void)setShredAfter:(uint32_t)shredAfter
{
	if (shredAfter > 0)
		[self setJsonValue:@(shredAfter) forJsonKey:SirenKey_shredAfter];
	else
		[self setJsonValue:nil forJsonKey:SirenKey_shredAfter];
}

#pragma mark location
- (NSString *)location
{
	return [self jsonValueForJsonKey:SirenKey_location expectedClass:[NSString class]];
}
- (void)setLocation:(NSString *)location
{
	[self setJsonValue:location forJsonKey:SirenKey_location];
}

#pragma mark fyeo
- (BOOL)fyeo
{
	NSNumber *value = [self jsonValueForJsonKey:SirenKey_fyeo expectedClass:[NSNumber class]];
	return value ? [value boolValue] : NO;
}
- (void)setFyeo:(BOOL)fyeo
{
	[self setJsonValue:@(fyeo) forJsonKey:SirenKey_fyeo];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark requestBurn
- (NSString *)requestBurn
{
	return [self jsonValueForJsonKey:SirenKey_requestBurn expectedClass:[NSString class]];
}

- (void)setRequestBurn:(NSString *)requestBurn
{
	[self setJsonValue:requestBurn forJsonKey:SirenKey_requestBurn];
}

#pragma mark requestResend
- (NSString *)requestResend
{
	return [self jsonValueForJsonKey:SirenKey_requestResend expectedClass:[NSString class]];
}

- (void)setRequestResend:(NSString *)requestResend
{
	[self setJsonValue:requestResend forJsonKey:SirenKey_requestResend];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark requestReceipt
- (BOOL)requestReceipt
{
	NSNumber *value = [self jsonValueForJsonKey:SirenKey_requestReceipt expectedClass:[NSNumber class]];
	return value ? [value boolValue] : NO;
}
- (void)setRequestReceipt:(BOOL)requestReceipt
{
	[self setJsonValue:@(requestReceipt) forJsonKey:SirenKey_requestReceipt];
}

#pragma mark receivedID
- (NSString *)receivedID
{
	return [self jsonValueForJsonKey:SirenKey_receivedID expectedClass:[NSString class]];
}
- (void)setReceivedID:(NSString *)receivedID
{
	[self setJsonValue:receivedID forJsonKey:SirenKey_receivedID];
}

#pragma mark receivedTime
- (NSDate *)receivedTime
{
	NSString *string = [self jsonValueForJsonKey:SirenKey_receivedTime expectedClass:[NSString class]];
	return [self dateFromZuluString:string];
}
- (void)setReceivedTime:(NSDate *)date
{
	NSString *string = [self zuluStringFromDate:date];
	[self setJsonValue:string forJsonKey:SirenKey_receivedTime];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark cloudKey
- (NSString *)cloudKey
{
	return [self jsonValueForJsonKey:SirenKey_cloudKey expectedClass:[NSString class]];
}
- (void)setCloudKey:(NSString *)cloudKey
{
	[self setJsonValue:cloudKey forJsonKey:SirenKey_cloudKey];
}

#pragma mark cloudLocator
- (NSString *)cloudLocator
{
	return [self jsonValueForJsonKey:SirenKey_cloudLocator expectedClass:[NSString class]];
}
- (void)setCloudLocator:(NSString *)cloudLocator
{
	[self setJsonValue:cloudLocator forJsonKey:SirenKey_cloudLocator];
}

#pragma mark mimeType
- (NSString *)mimeType
{
	return [self jsonValueForJsonKey:SirenKey_mimeType expectedClass:[NSString class]];
}
- (void)setMimeType:(NSString *)inMimeType
{
	NSString *mimeType = [inMimeType copy];
	[self setJsonValue:mimeType forJsonKey:SirenKey_mimeType];
}

#pragma mark mediaType
- (NSString *)mediaType
{
	return [self jsonValueForJsonKey:SirenKey_mediaType expectedClass:[NSString class]];
}
- (void)setMediaType:(NSString *)mediaType
{
	[self setJsonValue:mediaType forJsonKey:SirenKey_mediaType];
}

#pragma mark thumbnail
- (NSData *)thumbnail
{
	NSString *thumbnailString = [self jsonValueForJsonKey:SirenKey_thumbnail expectedClass:[NSString class]];
	if (thumbnailString)
		return [[NSData alloc] initWithBase64EncodedString:thumbnailString options:0];
	else
		return nil;
}
- (void)setThumbnail:(NSData *)thumbnail
{
	NSString *thumbnailString = [thumbnail base64EncodedStringWithOptions:0];
	[self setJsonValue:thumbnailString forJsonKey:SirenKey_thumbnail];
}

#pragma mark preview
- (NSData *)preview
{
	NSString *previewString = [self jsonValueForJsonKey:SirenKey_preview expectedClass:[NSString class]];
	if (previewString)
		return [[NSData alloc] initWithBase64EncodedString:previewString options:0];
	else
		return nil;
}
- (void)setPreview:(NSData *)preview
{
	NSString *previewString = [preview base64EncodedStringWithOptions:0];
	[self setJsonValue:previewString forJsonKey:SirenKey_preview];
}

#pragma mark duration
- (NSString *)duration
{
	return [self jsonValueForJsonKey:SirenKey_mediaDuration expectedClass:[NSString class]];
}
- (void)setDuration:(NSString *)duration
{
	[self setJsonValue:duration forJsonKey:SirenKey_mediaDuration];
}

#pragma mark waveform
- (NSData *)waveform
{
	NSString *waveformString = [self jsonValueForJsonKey:SirenKey_mediaWaveform expectedClass:[NSString class]];
	if (waveformString)
		return [[NSData alloc] initWithBase64EncodedString:waveformString options:0];
	else
		return nil;
}
- (void)setWaveform:(NSData *)waveform
{
	NSString *waveformString = [waveform base64EncodedStringWithOptions:0];
	[self setJsonValue:waveformString forJsonKey:SirenKey_mediaWaveform];
}

#pragma mark vcard
- (NSString *)vcard
{
	return [self jsonValueForJsonKey:SirenKey_vCard expectedClass:[NSString class]];
}
- (void)setVcard:(NSString *)vCard
{
	[self setJsonValue:vCard forJsonKey:SirenKey_vCard];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark signature
- (NSString *)signature
{
	return [self jsonValueForJsonKey:SirenKey_signature expectedClass:[NSString class]];
}
- (void)setSignature:(NSString *)signature
{
	[self setJsonValue:signature forJsonKey:SirenKey_signature];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark ping
- (NSString *)ping
{
	return [self jsonValueForJsonKey:SirenKey_ping expectedClass:[NSString class]];
}
- (void)setPing:(NSString *)ping
{
	[self setJsonValue:ping forJsonKey:SirenKey_ping];
}

#pragma mark capabilities
- (NSString *)capabilities
{
	return [self jsonValueForJsonKey:SirenKey_capabilities expectedClass:[NSString class]];
}
- (void)setCapabilities:(NSString *)capabilities
{
	[self setJsonValue:capabilities forJsonKey:SirenKey_capabilities];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark multicastKey
- (NSString *)multicastKey
{
	return [self jsonValueForJsonKey:SirenKey_multicastKey expectedClass:[NSString class]];
}
- (void)setMulticastKey:(NSString *)multicastKey
{
	[self setJsonValue:multicastKey forJsonKey:SirenKey_multicastKey];
}

#pragma mark reqeustThreadKey
- (NSString *)requestThreadKey
{
	return [self jsonValueForJsonKey:SirenKey_requestThread expectedClass:[NSString class]];
}
- (void)setRequestThreadKey:(NSString *)requestThreadKey
{
	[self setJsonValue:requestThreadKey forJsonKey:SirenKey_requestThread];
}

#pragma mark threadName
- (NSString *)threadName
{
	return [self jsonValueForJsonKey:SirenKey_threadName expectedClass:[NSString class]];
}
- (void)setThreadName:(NSString *)threadName
{
	[self setJsonValue:threadName forJsonKey:SirenKey_threadName];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark callerIdName
- (NSString *)callerIdName
{
	return [self jsonValueForJsonKey:SirenKey_callerIdName expectedClass:[NSString class]];
}
- (void)setCallerIdName:(NSString *)callerIdName
{
	[self setJsonValue:callerIdName forJsonKey:SirenKey_callerIdName];
}

#pragma mark callerIdNumber
- (NSString *)callerIdNumber
{
	return [self jsonValueForJsonKey:SirenKey_callerIdNumber expectedClass:[NSString class]];
}
- (void)setCallerIdNumber:(NSString *)callerIdNumber
{
	[self setJsonValue:callerIdNumber forJsonKey:SirenKey_callerIdNumber];
}

#pragma mark callerIdUser
- (NSString *)callerIdUser
{
	return [self jsonValueForJsonKey:SirenKey_callerIdUser expectedClass:[NSString class]];
}
- (void)setCallerIdUser:(NSString *)callerIdUser
{
	[self setJsonValue:callerIdUser forJsonKey:SirenKey_callerIdUser];
}

#pragma mark recordedTime
- (NSDate *)recordedTime
{
	NSString *string = [self jsonValueForJsonKey:SirenKey_recordedTime expectedClass:[NSString class]];
	return [self dateFromZuluString:string];
}
- (void)setRecordedTime:(NSDate *)date
{
	NSString *string = [self zuluStringFromDate:date];
	[self setJsonValue:string forJsonKey:SirenKey_recordedTime];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark hasGPS
- (BOOL)hasGPS
{
	NSNumber *number = [self jsonValueForJsonKey:SirenKey_hasGPS expectedClass:[NSNumber class]];
	return number ? [number boolValue] : NO;
}
- (void)setHasGPS:(BOOL)hasGPS
{
	[self setJsonValue:@(hasGPS) forJsonKey:SirenKey_hasGPS];
}

#pragma mark isMapCoordinate
- (BOOL)isMapCoordinate
{
	NSNumber *number = [self jsonValueForJsonKey:SirenKey_mapCoordinate expectedClass:[NSNumber class]];
	if ([number boolValue])
		return YES;
	else
		return (self.location && self.message.length == 0 && !self.mediaType);
}
- (void)setIsMapCoordinate:(BOOL)isMapCoordinate
{
	[self setJsonValue:@(isMapCoordinate) forJsonKey:SirenKey_mapCoordinate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark testTimestamp
- (NSDate *)testTimestamp
{
	NSString *string = [self jsonValueForJsonKey:SirenKey_testTimestamp expectedClass:[NSString class]];
	return [self dateFromZuluString:string];
}
- (void)setTestTimestamp:(NSDate *)date
{
	NSString *string = [self zuluStringFromDate:date];
	[self setJsonValue:string forJsonKey:SirenKey_testTimestamp];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Convienience Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isValid
{
	return !_badData;
}

- (BOOL)isPDF
{
	if (UTTypeConformsTo((__bridge CFStringRef)self.mediaType, kUTTypePDF)
	    || [self.mimeType isEqualToString:@"application/pdf"])
	{
		return YES;
	}
	else return NO;
}

- (BOOL)isVoicemail
{
	if (UTTypeConformsTo((__bridge CFStringRef)self.mediaType, kUTTypeAudio)
	    && (self.callerIdNumber || self.callerIdUser))
	{
		return YES;
	}
	else return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Instance methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSData *)sigSHA256Hash
{
	uint8_t hashBytes[32];
	SCLError err = Siren_ComputeHash(kHASH_Algorithm_SHA256, self.json.UTF8String, hashBytes, true);
	
	if (err == kSCLError_NoErr) {
		return [NSData dataWithBytes:hashBytes length:32];
	}
	else {
		return nil;
	}
}

- (NSString *)description
{
	return [_info description];
}

@end
