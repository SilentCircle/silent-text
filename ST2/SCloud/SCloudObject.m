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
#import "SCloudObject.h"

#import "AppConstants.h"
#import "AppDelegate.h"
#import "SCimpUtilities.h"
#import "SCFileManager.h"
#import "STLogging.h"

// Libraries
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <SCCrypto/SCcrypto.h>
#import <ZZArchive.h>
#import <ZZArchiveEntry.h>
#import <ZZConstants.h>
#import <ZZError.h>

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


static const NSInteger kMaxSCloudSegmentSize  = ((64*1024)-80);

NSString *const kSCloudMetaData_Date          = @"DateTme";
NSString *const kSCloudMetaData_FileName      = @"FileName";
NSString *const kSCloudMetaData_MediaType     = @"MediaType";
NSString *const kSCloudMetaData_MimeType      = @"MimeType";

NSString *const kSCloudMetaData_Exif          = @"{Exif}";
NSString *const kSCloudMetaData_GPS           = @"{GPS}";
NSString *const kSCloudMetaData_FileSize      = @"FileSize";
NSString *const kSCloudMetaData_Duration      = @"Duration";
NSString *const kSCloudMetaData_DisplayName   = @"DisplayName";
NSString *const kSCloudMetaData_MediaWaveform = @"Waveform";
NSString *const kSCloudMetaData_isPackage     = @"isPackage";   // identifies the directory as a IOS/OSX package file
NSString *const kSCloudMetaData_Thumbnail     = @"thumbnail";


NSString *const kSCloudMetaData_MediaType_Segment = @"com.silentcircle.scloud.segment";
NSString *const kSCloudMetaData_Segments          = @"Scloud_Segments";
NSString *const kSCloudMetaData_Segment_Number    = @"Scloud_Segment_Number";

static NSString *const kLocatorKey = @"locator";
static NSString *const kKeyKey = @"key";
static NSString *const kSegmentyKey = @"segment";

@interface SCloudObjectSegment : NSObject<NSCoding>

@property (nonatomic) NSUInteger item;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy)  NSString *locator;
@end



@interface EventHandlerItem : NSObject

@property (nonatomic, strong) NSOutputStream *decryptStream;
@property (nonatomic, strong) NSMutableData *metaBuffer;

@property (nonatomic) size_t metaDataLength;
@property (nonatomic) size_t dataLength;

@end

@implementation EventHandlerItem;

+ (instancetype)itemWithStream:(NSOutputStream *)decryptStream metaBuffer:(NSMutableData *)metaBuffer
{
    EventHandlerItem *item = [[EventHandlerItem alloc] init];
    item.decryptStream = decryptStream;
    item.metaBuffer = metaBuffer;
    item.metaDataLength = 0;
    item.dataLength = 0;
    
    return item;
}

@end


@interface SCloudObject ()

@property (nonatomic, assign, readwrite) SCloudContextRef scloud;
@property (nonatomic, strong, readwrite) NSMutableDictionary*  metaData;

@property (nonatomic, strong, readwrite) NSData * metaBuffer;
@property (nonatomic, strong, readwrite) NSData * mediaData;

@property (nonatomic, strong, readwrite) NSString * locator;
@property (nonatomic, strong, readwrite) NSString * key;
@property (nonatomic, strong, readwrite) NSString * mediaType;
@property (nonatomic, strong, readwrite) NSString * contextString;          // this is just a nonce
@property (nonatomic, strong, readwrite) ALAsset  * asset;
@property (nonatomic, strong, readwrite) NSURL    * inputURL;


@property (nonatomic, strong, readwrite) NSURL * cachedFileURL;
@property (nonatomic, strong, readwrite) NSURL * decryptedFileURL;

@property (nonatomic, strong, readwrite) NSOutputStream * decryptStream;

@property (nonatomic, assign, readwrite) BOOL foundOnCloud;
@property (nonatomic, strong, readwrite) NSURLConnection * connection;

@property (nonatomic, assign, readwrite) NSRange          segments;
@property (nonatomic, strong, readwrite) NSMutableArray * segmentList;
@property (nonatomic, strong, readwrite) NSArray        * missingSegments;

@end

#pragma mark -

@implementation SCloudObject

@synthesize scloud      = _scloud;
@synthesize thumbnail  = _thumbnail;
@synthesize userValue;
@synthesize fyeo        = fyeo;

@synthesize mediaType = _mediaType;
@dynamic cached;
@dynamic downloading;
@dynamic inCloud;

#define CHUNK_SIZE 8192

#pragma mark - 

+ (void) removeCachedFileWithLocatorString:(NSString*) locatorString
{
    if(locatorString)
    {
        NSURL* fileURL = [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent:locatorString];
        [NSFileManager.defaultManager removeItemAtURL:fileURL error:NULL];
    }
    
}

#pragma mark - public functions

- (id) initWithLocatorString:(NSString*) locatorString
                   keyString:(NSString*)keyString
                        fyeo:(BOOL)fyeoIn;

{
    if ((self = [super init]))
	{
        _locator    = locatorString;
        _scloud     = NULL;
        _key        = keyString;
        _foundOnCloud = NO;
        _connection = nil;
        _segments = NSMakeRange(0,0);
        _segmentList = [[NSMutableArray alloc] init];
        _missingSegments = NULL;
        userValue = NULL;
        fyeo = fyeoIn;
        

     }
    return self;
}

- (id)initWithLocatorString:(NSString *)locatorString
{
    if ((self = [super init]))
	{
        _locator    = locatorString;
        _scloud     = NULL;
        _key        = NULL;
        _foundOnCloud = NO;
        _connection = nil;
        _segments = NSMakeRange(0,0);
        _segmentList = [[NSMutableArray alloc] init];
        _missingSegments = NULL;
        userValue = NULL;
        fyeo = NO;
    }
    return self;
}

- (id)initWithDelegate:(id)aDelegate
                  data:(NSData *)data
              metaData:(NSDictionary *)metaData
             mediaType:(NSString *)mediaType
         contextString:(NSString *)contextString
{
    if ((self = [super init]))
	{
        _scloudDelegate = aDelegate;
        _metaData       = metaData
                    ?[NSMutableDictionary dictionaryWithDictionary: metaData]
                    :NSMutableDictionary.alloc.init;
        _mediaData      = data;
        _mediaType      = mediaType;
        _contextString  = contextString;
        _scloud         = NULL;
        _key = NULL;
        _segments = NSMakeRange(0,0);
        _segmentList = [[NSMutableArray alloc] init];
        _missingSegments = NULL;
        userValue = NULL;
        fyeo = NO;
    }
    return self;
}

- (id)initWithDelegate: (id)aDelegate
                 asset:(ALAsset*)asset
              metaData:(NSDictionary*)metaData
             mediaType:(NSString*)mediaType
         contextString:(NSString*)contextString;
{
    if ((self = [super init]))
	{
        self = [self initWithDelegate:aDelegate
                                 data:NULL
                             metaData:metaData
                            mediaType:mediaType
                        contextString:contextString];
        
        self.asset = asset;
    }
    return self;
}

- (id)initWithDelegate:(id)aDelegate
                   url:(NSURL *)inURL
              metaData:(NSDictionary *)metaData
             mediaType:(NSString *)mediaType
         contextString:(NSString *)contextString
{
    if ((self = [super init]))
	{
        self = [self initWithDelegate:aDelegate
                                 data:NULL
                             metaData:metaData
                            mediaType:mediaType
                        contextString:contextString];
        
        self.inputURL = inURL;
    }
    return self;
}


- (BOOL) isCached {
    
    BOOL result = NO;
    NSError* error  = NULL;
    
    NSURL *url = [self cachedFileURL];
    
    result = ([url checkResourceIsReachableAndReturnError:&error]
              && !error
              && [url isFileURL]);
    
    return result;
    
} // -isCached


- (BOOL) isDownloading {
    
    BOOL result = NO;
    NSError* error  = NULL;
    
    NSURL *url = [self cachedFileURL];
    url = [url URLByAppendingPathExtension:@"tmp"];
    
    result = ([url checkResourceIsReachableAndReturnError:&error]
              && !error
              && [url isFileURL]);
    
    return result;
    
} // -isDownloading

 
-(BOOL) isInCloud
{
    return _foundOnCloud;
}

-(uint32_t) segmentCount
{
    return (int32_t) _segments.length;
}


- (NSURL*) cachedFileURL
{
    if(!_cachedFileURL)
    {
        _cachedFileURL = [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent: self.locatorString];
    }

    return _cachedFileURL;
 }

  


- (void) dealloc
{
    [self removeDecryptedFile];
    
    if(_scloud)
        SCloudFree(_scloud);
    _scloud = NULL;
    _connection = nil;
    _key = NULL;
}


-(void) removeDecryptedFile
{
    if(_decryptedFileURL)
    {
        [[NSFileManager defaultManager]  removeItemAtURL:_decryptedFileURL error:NULL];
        _decryptedFileURL = NULL;
    }
    
}




#pragma mark - segment encryption


- (BOOL) saveSegmentToCache:(NSRange)segment
                       data:(NSData*)data
                   metaData:(NSData*)metaData
                        key:(NSString**)key
                    locator:(NSString**)locator
                      error:(NSError **)errPtr
{
    SCLError err = kSCLError_NoErr;
    NSError* error = nil;
    BOOL    result = NO;
    int     stage = 0;
    
    NSString* segKey = NULL;
    NSString* segLocator = NULL;
    
    NSURL*  fileURL = NULL;
    NSOutputStream *outStream = NULL;
    
    SCloudContextRef segRef = NULL;
    
    
    if(self.scloudDelegate)
    {
        stage = 1;
    }
    
    err = SCloudEncryptNew( (void*)[_contextString UTF8String], [_contextString length],
                           (void*)[data bytes], [data length],
                           (void*) (metaData ? [metaData bytes]: NULL), metaData? [metaData length]: 0,
                           ScloudSegmentEventHandler,(__bridge void *)self, &segRef); CKERR;
    
    err = SCloudCalculateKey(segRef, 1024); CKERR;
    
    if(self.scloudDelegate)
    {
        stage = 2;
    }
    
    {
        uint8_t * keyBLOB   = NULL;
        size_t  keyBLOBlen  = 0;
        uint8_t locatorURL[SCLOUD_LOCATOR_LEN * 2] = {0};
        size_t  locatorURLlen  = sizeof(locatorURL);
        
        err = SCloudEncryptGetKeyBLOB(segRef, &keyBLOB, &keyBLOBlen); CKERR;
        err = SCloudEncryptGetLocatorREST(segRef, locatorURL, &locatorURLlen); CKERR;
        
        segKey = [[NSString alloc] initWithBytesNoCopy: keyBLOB
                                              length: keyBLOBlen
                                            encoding: NSUTF8StringEncoding
                                        freeWhenDone: YES];
        
		segLocator = [[NSString alloc] initWithBytes: locatorURL
		                                      length: strlen((char*)locatorURL)
		                                    encoding: NSUTF8StringEncoding];
	}
    
    fileURL = [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent:segLocator isDirectory:NO];
    outStream =  [NSOutputStream outputStreamWithURL:fileURL append:NO];
    
    uint8_t outBuffer[CHUNK_SIZE] = {0};
    size_t  dataSize  = 0;
    
    stage = 3;
    
    [outStream open];
    
    for(dataSize = CHUNK_SIZE;
        IsntSCLError( ( err = SCloudEncryptNext(segRef, outBuffer, &dataSize)) );
        dataSize = CHUNK_SIZE)
    {
        
        [outStream write: outBuffer  maxLength: dataSize];
        
    }
    if(err == kSCLError_EndOfIteration) err = kSCLError_NoErr;
    
    [outStream close];
    
done:
    
    if(IsSCLError(err))
    {
        error = [SCimpUtilities errorWithSCLError:err];
    }
    else
    {
        result = YES;
        *locator = [segLocator copy];
        *key    = [segKey copy];
    }
    
    
    segLocator = NULL;
    segKey   = NULL;
    
    if(segRef)
        SCloudFree(segRef);
    
    if (errPtr) *errPtr = error;
    
    return result;
}


#pragma mark  - Scloud Event Handlers

SCLError ScloudEventHandler(SCloudContextRef ctx, SCloudEvent* event, void* uservalue)
{
    SCLError     err  = kSCLError_NoErr;
    
    SCloudObject *self = (__bridge SCloudObject *)uservalue;
    
    if(self.scloudDelegate)
    {
        switch(event->type)
        {
            case kSCloudEvent_Progress:
                 break;
                
                
            case kSCloudEvent_DecryptedData:
            {
                SCloudEventDecryptData  *d =    &event->data.decryptData;
                
                [self.decryptStream write:d->data maxLength:d->length];
                
            }
                break;
                
            case kSCloudEvent_DecryptedMetaData:
            {
                SCloudEventDecryptMetaData  *d =    &event->data.metaData;
                
                NSMutableData *data = [NSMutableData dataWithBytes: d->data length: d->length];
                
                if(!self.metaBuffer )
                    self.metaBuffer =  [NSMutableData alloc];
                
                [ ((NSMutableData*) self.metaBuffer) appendData: data];
                
            }
                break;
                
                
            case kSCloudEvent_DecryptedMetaDataComplete:
            {
                //                SCloudEventDecryptMetaData  *d =    &event->data.metaData;
                
            }
                break;
                
            default:
                break;
        }
        
    }
    
    return err;
}

SCLError ScloudSegmentEventHandler(SCloudContextRef ctx, SCloudEvent* event, void* uservalue)
{
    SCLError     err  = kSCLError_NoErr;
    
    SCloudObject *self = (__bridge SCloudObject *)uservalue;
    
    if(self.scloudDelegate)
    {
        switch(event->type)
        {
            case kSCloudEvent_Progress:
                break;
                
                   
            default:
                break;
        }
        
    }
    
    return err;
}


SCLError ScloudSegmentDecryptEventHandler(SCloudContextRef ctx, SCloudEvent* event, void* uservalue)
{
    SCLError     err  = kSCLError_NoErr;
    
    EventHandlerItem *handlerItem = (__bridge EventHandlerItem *)uservalue;
    
    switch(event->type)
    {
        case kSCloudEvent_DecryptedData:
        {
            SCloudEventDecryptData  *d =    &event->data.decryptData;
            
            [handlerItem.decryptStream write:d->data maxLength:d->length];
            
        }
            break;
 
        case kSCloudEvent_DecryptedMetaData:
        {
            SCloudEventDecryptMetaData  *d =    &event->data.metaData;
            
            NSMutableData *data = [NSMutableData dataWithBytes: d->data length: d->length];
            
            if(!handlerItem.metaBuffer )
                handlerItem.metaBuffer =  [NSMutableData alloc];
            
            [ ((NSMutableData*) handlerItem.metaBuffer) appendData: data];
            
        }
            break;

        default:
            break;
    }
    
    return err;
}


SCLError ScloudMetaDataDecryptEventHandler(SCloudContextRef ctx, SCloudEvent* event, void* uservalue)
{
    SCLError     err  = kSCLError_NoErr;
    
    EventHandlerItem *handlerItem = (__bridge EventHandlerItem *)uservalue;
    
    switch(event->type)
    {
        case kSCloudEvent_DecryptedHeader:
        {
            SCloudEventDecryptedHeaderData *d =    &event->data.header;
            
            handlerItem.metaDataLength = d->metaDataBytes;
            handlerItem.dataLength = d->dataBytes;
        }
            break;
            
        case kSCloudEvent_DecryptedMetaData:
        {
            SCloudEventDecryptMetaData  *d =    &event->data.metaData;
            
            NSMutableData *data = [NSMutableData dataWithBytes: d->data length: d->length];
            
            if(!handlerItem.metaBuffer )
                handlerItem.metaBuffer =  [NSMutableData alloc];
            
            [ ((NSMutableData*) handlerItem.metaBuffer) appendData: data];
            
        }
            break;
            
        default:
            break;
    }
    
    return err;
}

#pragma mark - file encryption


- (BOOL) saveToCacheWithError:(NSError **)errPtr
{
    BOOL    result = NO;

    if(self.asset)
    {
        result = [self saveALAssetToCacheWithError:errPtr];
    }
    else if(self.inputURL)
    {
        result = [self saveURLToCacheWithError:errPtr];
    }
    else
    {
        result = [self saveNSDataToCacheWithError:errPtr];
        
    }
    
    return result;
}


- (BOOL) saveALAssetToCacheWithError:(NSError **)errPtr
{
    BOOL    result = NO;

    ALAssetRepresentation *rep = [_asset defaultRepresentation];
  
    NSError* error = nil;
    NSInteger totalSegments = 0;
    NSString *topKey = NULL;
    NSString *topLocator = NULL;
    NSData   *topSegmentData = NULL;
    NSData   *topMetaData = NULL;
    
    Byte * buffer = (Byte*)malloc(kMaxSCloudSegmentSize);
    
    _segmentList = NULL;
    _segmentList = [[NSMutableArray alloc] init];
    
    totalSegments = rep.size  / kMaxSCloudSegmentSize;
    if( rep.size  % kMaxSCloudSegmentSize != 0) totalSegments++;
    _segments =  NSMakeRange (0,  totalSegments);

    [_metaData setObject:[NSNumber numberWithLongLong:rep.size] forKey:kSCloudMetaData_FileSize];
    
    if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingDidStart:totalSegments:)])
        [self.scloudDelegate scloudObject:self savingDidStart:_mediaType totalSegments:totalSegments ];
   
    if(totalSegments > 1)
    {
        [_metaData setObject:[NSNumber numberWithUnsignedInteger:totalSegments] forKey:kSCloudMetaData_Segments];
        
        // process each item
        for(NSInteger segNum = 0; segNum < totalSegments; segNum++)
        {
            NSString *segKey = NULL;
            NSString *segLocator = NULL;
            
            _segments.location  = segNum;
            
            NSInteger startLocation = (segNum * kMaxSCloudSegmentSize);
            NSInteger bytesLeft = startLocation + kMaxSCloudSegmentSize > rep.size? rep.size - startLocation:kMaxSCloudSegmentSize;
            
           NSUInteger bytesRead = [rep getBytes:buffer
                                     fromOffset:startLocation
                                         length:bytesLeft
                                          error:&error];
            
            NSData *dataToWrite = [NSData dataWithBytesNoCopy:buffer length:bytesRead freeWhenDone:NO];
            
            NSDictionary *metaDict = @{ kSCloudMetaData_MediaType: kSCloudMetaData_MediaType_Segment,
                                        kSCloudMetaData_Segment_Number: @(segNum)    };
            
            NSData *segMetaData = ([NSJSONSerialization  isValidJSONObject: metaDict] ?
                                   [NSJSONSerialization dataWithJSONObject: metaDict options: 0UL error: &error] :
                                   nil);

            result = [self saveSegmentToCache:_segments
                                         data:dataToWrite
                                     metaData:segMetaData
                                          key:&segKey
                                      locator:&segLocator
                                        error:&error];
            
            if(!result)    goto done;
            
            
            NSArray *entry = [NSArray arrayWithObjects:
                              [NSNumber numberWithUnsignedInteger: segNum],
                              segLocator,
                              segKey,
                              nil];
            
            [_segmentList addObject:entry];
            
            if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingProgress:)])
                [self.scloudDelegate scloudObject:self savingProgress:  (float)segNum / (float)totalSegments ];
  
        }
        
        topSegmentData = ([NSJSONSerialization  isValidJSONObject: _segmentList] ?
                          [NSJSONSerialization dataWithJSONObject: _segmentList options: 0UL error: &error] :
                          nil);
        
        
    }
    else
    {
        
        NSUInteger bytesRead = [rep getBytes:buffer
                                  fromOffset:0
                                      length:rep.size
                                       error:&error];
        
        topSegmentData = [NSData dataWithBytesNoCopy:buffer length:bytesRead freeWhenDone:NO ];
    }
    
    _segments.location = _segments.length;
    
    topMetaData = _metaData
    ? [NSJSONSerialization dataWithJSONObject:_metaData  options:0 error:&error]
    :  NULL;
    
    result = [self saveSegmentToCache:_segments
                                 data:topSegmentData
                             metaData:topMetaData
                                  key:&topKey
                              locator:&topLocator
                                error:&error];
 
    if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingProgress:)])
        [self.scloudDelegate scloudObject:self savingProgress:  1.0];
 
    if(!result)    goto done;
    
    _locator = topLocator;
    _key = topKey;
    
done:
    
    if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingDidCompleteWithError:)])
        [self.scloudDelegate scloudObject:self savingDidCompleteWithError:error ];
    
    
    if(buffer)
        free(buffer);
    
    if (result == NO)
	{
		if (errPtr)
			*errPtr = error;
	}
    
    return result;
    
}


- (BOOL) saveURLToCacheWithError:(NSError **)errPtr
{
    BOOL    result = NO;
    NSError* error = nil;
    NSInteger totalSegments = 0;
    NSString *topKey = NULL;
    NSString *topLocator = NULL;
    NSData   *topSegmentData = NULL;
    NSData   *topMetaData = NULL;
    
    NSStreamStatus status;
    NSInputStream *inStream     = NULL;
    NSNumber *fileSizeValue = nil;
    long long fileSize =  0;
    
    NSURL *urlToEncode = _inputURL;
    Byte * buffer = (Byte*)malloc(kMaxSCloudSegmentSize);
    
    BOOL createdZipFile = NO;
    NSNumber *isDirectory = @(NO);
    NSNumber *isPackage = @(NO);
 
    [_inputURL getResourceValue:&isPackage forKey:NSURLIsPackageKey error:&error];
    if([isPackage boolValue])
         [_metaData setObject: @(YES) forKey:kSCloudMetaData_isPackage];
    
    [_inputURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];
    if([isDirectory boolValue])
    {
        urlToEncode = [self compressDirectory:_inputURL error:&error];
        if(error)  goto done;
        [_metaData setObject: [[_inputURL URLByAppendingPathExtension:@"zip"]lastPathComponent]  forKey:kSCloudMetaData_FileName];
        createdZipFile = YES;
     }
    
  
    [urlToEncode getResourceValue:&fileSizeValue
                           forKey:NSURLFileSizeKey
                            error:nil];
    fileSize =  fileSizeValue.longLongValue;
    
 
    inStream =  [NSInputStream inputStreamWithURL:urlToEncode];
    [inStream open];
    status = [inStream streamStatus];
    if(status == NSStreamStatusClosed || status == NSStreamStatusError)
    {
        error = [inStream streamError]; goto done;
    }
   
    _segmentList = NULL;
    _segmentList = [[NSMutableArray alloc] init];
    
    totalSegments = fileSize  / kMaxSCloudSegmentSize;
    if( fileSize  % kMaxSCloudSegmentSize != 0) totalSegments++;
    _segments =  NSMakeRange (0,  totalSegments);
    
    [_metaData setObject:[NSNumber numberWithLongLong:fileSizeValue.longLongValue] forKey:kSCloudMetaData_FileSize];
    
    if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingDidStart:totalSegments:)])
        [self.scloudDelegate scloudObject:self savingDidStart:_mediaType totalSegments:totalSegments ];
    
    if(totalSegments > 1)
    {
        
        [_metaData setObject:[NSNumber numberWithUnsignedInteger:totalSegments] forKey:kSCloudMetaData_Segments];
        
        // process each item
        for(NSInteger segNum = 0; segNum < totalSegments; segNum++)
        {
            NSString *segKey = NULL;
            NSString *segLocator = NULL;
            
            _segments.location  = segNum;
            
            NSInteger startLocation = (segNum * kMaxSCloudSegmentSize);
            NSInteger bytesLeft = startLocation + kMaxSCloudSegmentSize > fileSize? fileSize - startLocation:kMaxSCloudSegmentSize;
            
            NSUInteger bytesRead = [inStream read:(uint8_t *)buffer maxLength:bytesLeft];
           
            NSData *dataToWrite = [NSData dataWithBytesNoCopy:buffer length:bytesRead freeWhenDone:NO];
            
            NSDictionary *metaDict = @{ kSCloudMetaData_MediaType: kSCloudMetaData_MediaType_Segment,
                                        kSCloudMetaData_Segment_Number: @(segNum)    };
     
            NSData *segMetaData = ([NSJSONSerialization  isValidJSONObject: metaDict] ?
                                   [NSJSONSerialization dataWithJSONObject: metaDict options: 0UL error: &error] :
                                   nil);

            result = [self saveSegmentToCache:_segments
                                         data:dataToWrite
                                     metaData:segMetaData
                                          key:&segKey
                                      locator:&segLocator
                                        error:&error];
            
            if(!result)    goto done;
            
            NSArray *entry = [NSArray arrayWithObjects:
                              [NSNumber numberWithUnsignedInteger: segNum],
                              segLocator,
                              segKey,
                              nil];
            
            [_segmentList addObject:entry];
            
            if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingProgress:)])
                [self.scloudDelegate scloudObject:self savingProgress:  (float)segNum / (float)totalSegments ];
            
        }
        
        topSegmentData = ([NSJSONSerialization  isValidJSONObject: _segmentList] ?
                          [NSJSONSerialization dataWithJSONObject: _segmentList options: 0UL error: &error] :
                          nil);
        
        
    }
    else
    {
        
        NSUInteger bytesRead = [inStream read:(uint8_t *)buffer maxLength:fileSize];
        
        topSegmentData = [NSData dataWithBytesNoCopy:buffer length:bytesRead freeWhenDone:NO ];
    }
    
    _segments.location = _segments.length;
    
    topMetaData = _metaData
    ? [NSJSONSerialization dataWithJSONObject:_metaData  options:0 error:&error]
    :  NULL;
    
    result = [self saveSegmentToCache:_segments
                                 data:topSegmentData
                             metaData:topMetaData
                                  key:&topKey
                              locator:&topLocator
                                error:&error];
    
    if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingProgress:)])
        [self.scloudDelegate scloudObject:self savingProgress:  1.0];
    
    if(!result)    goto done;
    
    _locator = topLocator;
    _key = topKey;
    
done:
    
    if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingDidCompleteWithError:)])
        [self.scloudDelegate scloudObject:self savingDidCompleteWithError:error ];

    if(createdZipFile)
        [NSFileManager.defaultManager removeItemAtURL:urlToEncode error:nil];
    
    if(buffer)
        free(buffer);
    
    if(inStream)
        [inStream close];
    
    if (result == NO)
	{
		if (errPtr)
			*errPtr = error;
	}
    
    return result;
}



- (BOOL) saveNSDataToCacheWithError:(NSError **)errPtr
{
    BOOL    result = NO;
    NSError* error = nil;
    NSInteger totalSegments = 0;
    NSString *topKey = NULL;
    NSString *topLocator = NULL;
    NSData   *topSegmentData = NULL;
    NSData   *topMetaData = NULL;
    
    _segmentList = NULL;
    _segmentList = [[NSMutableArray alloc] init];
 
    totalSegments = _mediaData.length  / kMaxSCloudSegmentSize;
    if( _mediaData.length  % kMaxSCloudSegmentSize != 0) totalSegments++;
    _segments =  NSMakeRange (0,  totalSegments);
  
    if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingDidStart:totalSegments:)])
        [self.scloudDelegate scloudObject:self savingDidStart:_mediaType totalSegments:totalSegments ];

    if(totalSegments > 1)
    {
            [_metaData setObject:[NSNumber numberWithUnsignedInteger:totalSegments] forKey:kSCloudMetaData_Segments];
        
        // process each item
        for(NSInteger segNum = 0; segNum < totalSegments; segNum++)
        {
            NSString *segKey = NULL;
            NSString *segLocator = NULL;
            
            _segments.location  = segNum;
            
            NSInteger startLocation = (segNum * kMaxSCloudSegmentSize);
            NSInteger bytesLeft = startLocation + kMaxSCloudSegmentSize > _mediaData.length? _mediaData.length - startLocation:kMaxSCloudSegmentSize;
            
            NSRange dataRange = NSMakeRange (startLocation , bytesLeft);
            NSData *dataToWrite = [_mediaData subdataWithRange:dataRange];
           
            NSDictionary *metaDict = @{ kSCloudMetaData_MediaType: kSCloudMetaData_MediaType_Segment,
                                        kSCloudMetaData_Segment_Number: @(segNum)    };
            
            NSData *segMetaData = ([NSJSONSerialization  isValidJSONObject: metaDict] ?
                                   [NSJSONSerialization dataWithJSONObject: metaDict options: 0UL error: &error] :
                                   nil);
  
            result = [self saveSegmentToCache:_segments
                                          data:dataToWrite
                                      metaData:segMetaData
                                           key:&segKey
                                       locator:&segLocator
                                         error:&error];
            
            if(!result)    goto done;
            
            
            NSArray *entry = [NSArray arrayWithObjects:
                            [NSNumber numberWithUnsignedInteger: segNum],
                            segLocator,
                            segKey,
                            nil];

            [_segmentList addObject:entry];
            
            if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingProgress:)])
                [self.scloudDelegate scloudObject:self savingProgress:  (float)segNum / (float)totalSegments ];

        }
         
        topSegmentData = ([NSJSONSerialization  isValidJSONObject: _segmentList] ?
                               [NSJSONSerialization dataWithJSONObject: _segmentList options: 0UL error: &error] :
                               nil);
        
        
        }
    else
    {
        topSegmentData = _mediaData;
    }
  
    _segments.location = _segments.length;

    topMetaData = _metaData
        ? [NSJSONSerialization dataWithJSONObject:_metaData  options:0 error:&error]
        :  NULL;

    result = [self saveSegmentToCache:_segments
                                 data:topSegmentData
                             metaData:topMetaData
                                  key:&topKey
                              locator:&topLocator
                                error:&error];
    
    if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingProgress:)])
        [self.scloudDelegate scloudObject:self savingProgress:  1.0];

    if(!result)    goto done;
    
    _locator = topLocator;
    _key = topKey;

done:
    
    
    if ([self.scloudDelegate respondsToSelector:@selector(scloudObject:savingDidCompleteWithError:)])
        [self.scloudDelegate scloudObject:self savingDidCompleteWithError:error ];

    if (result == NO)
	{
		if (errPtr)
			*errPtr = error;
	}
    
    _mediaData = nil;
   return result;
}

 

- (NSString*) keyString
{
        SCLError err = kSCLError_NoErr;
   
    if(_scloud && !_key)
    {
         uint8_t * keyBLOB= NULL;
        size_t  keyBLOBlen  = 0;
  
      
        err = SCloudEncryptGetKeyBLOB(_scloud, &keyBLOB, &keyBLOBlen);
        
        
        if(IsntSCLError(err) && keyBLOB && keyBLOBlen > 0)
        {
            
            _key = [NSString.alloc initWithBytesNoCopy: keyBLOB
                                                         length: keyBLOBlen
                                                       encoding: NSUTF8StringEncoding
                                                   freeWhenDone: YES];
            
        }
         
    }
    return _key;
}


- (NSString*) locatorString
{
     SCLError err = kSCLError_NoErr;
    
    if(_scloud && !_locator)
        {
            uint8_t locatorURL[SCLOUD_LOCATOR_LEN * 2] = {0};
            size_t  locatorURLlen  = sizeof(locatorURL);
             
            err = SCloudEncryptGetLocatorREST(_scloud, locatorURL, &locatorURLlen);
            if(IsntSCLError(err))
            {
                _locator = [NSString.alloc initWithBytes: locatorURL
                                                   length: strlen((char*)locatorURL)
                                                 encoding: NSUTF8StringEncoding];
            
            }
        }
        
     return _locator;
}
#pragma mark - process Zip files

- (NSURL *)compressDirectory:(NSURL *)urlIn error:(NSError **)error
{
	// special case, ,rtfd is a directory, we need to zip it.
	
	NSString *uuid = [[NSUUID UUID] UUIDString];
    NSURL *archiveURL = [[SCFileManager mediaCacheDirectoryURL] URLByAppendingPathComponent:uuid];

	ZZArchive *newArchive = [ZZArchive archiveWithURL:archiveURL error:NULL];
    NSMutableArray* newEntries = [NSMutableArray array];
    
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:urlIn
	                                                         includingPropertiesForKeys:nil
	                                                                            options:0
	                                                                       errorHandler:^(NSURL *url, NSError *error)
	{
		// Handle the error.
        // Return YES if the enumeration should continue after the error.
		return NO;
	}];
    
    for (NSURL *fileURL in enumerator)
    {
         NSNumber *isDirectory = @(NO);
        
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:error];
        if(*error)
            return NULL;
        
        if([isDirectory boolValue])
        {
            [newEntries addObject:[ZZArchiveEntry archiveEntryWithDirectoryName:[fileURL lastPathComponent]]];
        }
        else
        {
                [newEntries addObject:[ZZArchiveEntry archiveEntryWithFileName:[fileURL lastPathComponent]
                                                                  compress:YES
                                                               streamBlock:^(NSOutputStream* outputStream, NSError** err)
                                   {
                                       
                                       NSData* fileData = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMappedIfSafe error:err];
                                       if(*err)
                                           return NO;
                                       
                                       const uint8_t* bytes;
                                       NSInteger bytesLeft;
                                       NSInteger bytesWritten;
                                       for (bytes = (const uint8_t*)fileData.bytes, bytesLeft = fileData.length;
                                            bytesLeft > 0;
                                            bytes += bytesWritten, bytesLeft -= bytesWritten)
                                       {
                                           bytesWritten = [outputStream write:bytes maxLength:MIN(bytesLeft, 1024)];
                                           if (bytesWritten == -1)
                                           {
                                               if (error)
                                                   *err = outputStream.streamError;
                                               return NO;
                                           }
                                       }
                                       return YES;
                                   }]];
        }

    
        
    };
    
    [newArchive updateEntries:newEntries error: error];
    
    newArchive = NULL;
    return archiveURL;
}

-(NSURL*) deCompressDirectory:(NSURL*) urlIn
{
    __block NSError             *error      = NULL;
    
    NSURL* outputUrl  = [urlIn URLByDeletingPathExtension];
    
    // special case, ,rtfd is a directory, we need to zip it.
    NSFileManager *fm  = [NSFileManager defaultManager];
    
    [fm createDirectoryAtURL:outputUrl
          withIntermediateDirectories:YES
                           attributes:nil
                                error:nil];
    
	ZZArchive *archive = [ZZArchive archiveWithURL:urlIn error:NULL];
  
    for (ZZArchiveEntry* entry in archive.entries)
    {
        NSURL* targetPath = [outputUrl URLByAppendingPathComponent:entry.fileName];
        
        if (entry.fileMode & S_IFDIR)
        {
 //           DDLogPurple(@"DeCompress Dir %@", entry.fileName);

            // check if directory bit is set
            [fm createDirectoryAtURL:targetPath
                  withIntermediateDirectories:YES
                                   attributes:nil
                               error:nil];}
        
        else
        {
            // Some archives don't have a separate entry for each directory and just
            // include the directory's name in the filename. Make sure that directory exists
            // before writing a file into it.
            [fm createDirectoryAtURL:[targetPath URLByDeletingLastPathComponent]
                  withIntermediateDirectories:YES
                                   attributes:nil
                                        error:nil];
            
//            DDLogPurple(@"DeCompress file %@", entry.fileName);

            NSData* outData = [entry newDataWithError:&error];
            if(!error)
                [ outData writeToURL:targetPath atomically:NO];
        }
    }

    archive = NULL;
    
    return outputUrl;
}



#pragma mark - File segments

+(NSArray*)segmentsFromLocatorString:(NSString*)locatorString
                           keyString:(NSString*)keyString
                           withError:(NSError **)errPtr
{
    SCLError err = kSCLError_NoErr;
    NSError* error = nil;
    
    SCloudContextRef ref = NULL;
    NSStreamStatus status;
    
    NSInputStream  * inStream  = nil;
    NSOutputStream * outStream = nil;
    NSMutableArray * segments  = nil;
    NSMutableArray * segList   = [[NSMutableArray alloc] init];

	EventHandlerItem* handlerInfo = NULL;
    
    NSURL* inURL =  [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent:locatorString];
	
	NSString *uuid = [[NSUUID UUID] UUIDString];
	NSURL *outURL = [[SCFileManager mediaCacheDirectoryURL] URLByAppendingPathComponent:uuid];
	
	inStream =  [NSInputStream inputStreamWithURL:inURL];
	[inStream open];
    status = [inStream streamStatus];
    if(status == NSStreamStatusClosed || status == NSStreamStatusError)
    {
        error = [inStream streamError]; goto done;
    }
    
    
    outStream =  [NSOutputStream outputStreamWithURL:outURL append:NO];
    [outStream open];
    status = [outStream streamStatus];
    if(status == NSStreamStatusClosed || status == NSStreamStatusError)
    {
        error = [outStream streamError]; goto done;
    }
    
    handlerInfo =  [EventHandlerItem itemWithStream:outStream metaBuffer:NULL];
    
    err = SCloudDecryptNew((uint8_t*)[keyString UTF8String], strlen([keyString UTF8String]),
                           ScloudSegmentDecryptEventHandler,(__bridge void *)handlerInfo, &ref); CKERR;
    
    
    while([inStream hasBytesAvailable])
    {
        uint8_t buffer[CHUNK_SIZE] = {0};
        size_t  bytesRead  = 0;
        
        bytesRead = [inStream read:(uint8_t *)buffer maxLength:CHUNK_SIZE];
        err = SCloudDecryptNext(ref, buffer, bytesRead);
        
        if(IsSCLError(err) )break;
    }
    if(err == kSCLError_EndOfIteration) err = kSCLError_NoErr;
    CKERR;
    
    [inStream close]; inStream = NULL;
    [outStream close]; outStream = NULL;
    
    inStream = [NSInputStream inputStreamWithURL:outURL];
    [inStream open];
    
    if(handlerInfo.metaBuffer )
    {
        NSMutableDictionary *info = nil;
        
        info   = [NSJSONSerialization JSONObjectWithData: handlerInfo.metaBuffer
                                                 options: NSJSONReadingMutableContainers
                                                   error: &error];
        
        NSNumber* totalSegments = [info valueForKey:kSCloudMetaData_Segments];
        
        if(totalSegments &&  totalSegments.unsignedIntegerValue > 1)
        {
            segments = [NSJSONSerialization JSONObjectWithStream:inStream
                                                         options:NSJSONReadingMutableContainers
                                                           error:&error];
            if(error != NULL) goto done;
        }
    }
    
    [inStream close]; inStream = NULL;
    
    // include index
    [segList addObject:locatorString];
    
    // just return the locators
	if (segments)
	{
		for(NSArray *segment in segments) {
			[segList addObject:[segment objectAtIndex:1]];
		}
	}
	
done:
    
    [NSFileManager.defaultManager removeItemAtURL:outURL error:nil];
    
    if(inStream)
        [inStream close];
    
    if(outStream)
        [outStream close];
    
    if (errPtr)
        *errPtr = error;
    
    if(ref)
        SCloudFree(ref);
    
    return segList;
    
}


#pragma mark - File decryption


-(BOOL) decryptMetaDataUsingKeyString:(NSString*) keyString withError:(NSError **)errPtr;
{
    SCLError err = kSCLError_NoErr;
    NSError* error = nil;
    BOOL success = NO;
    
    SCloudContextRef ref = NULL;
    NSStreamStatus status;
    
     NSInputStream *inStream     = NULL;
    NSOutputStream *outStream    = NULL;
    NSMutableArray *segments  =  NULL;
    NSMutableArray *segList  =  NSMutableArray.alloc.init;
    NSMutableDictionary *info = NULL;
    NSNumber* totalSegments = NULL;
    
	EventHandlerItem* handlerInfo = NULL;
    
    NSURL* inURL =  [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent:_locator];
 
	NSString *uuid = [[NSUUID UUID] UUIDString];
	NSURL *outURL = [[SCFileManager mediaCacheDirectoryURL] URLByAppendingPathComponent:uuid];
    
    inStream =  [NSInputStream inputStreamWithURL:inURL];
    [inStream open];
    status = [inStream streamStatus];
    if(status == NSStreamStatusClosed || status == NSStreamStatusError)
    {
        error = [inStream streamError]; goto done;
    }
    
    outStream =  [NSOutputStream outputStreamWithURL:outURL append:NO];
    [outStream open];
    status = [outStream streamStatus];
    if(status == NSStreamStatusClosed || status == NSStreamStatusError)
    {
        error = [outStream streamError]; goto done;
    }
    
    handlerInfo =  [EventHandlerItem itemWithStream:outStream metaBuffer:NULL];
    
    err = SCloudDecryptNew((uint8_t*)[keyString UTF8String], strlen([keyString UTF8String]),
                           ScloudSegmentDecryptEventHandler,(__bridge void *)handlerInfo, &ref); CKERR;
    
      while([inStream hasBytesAvailable])
    {
        uint8_t buffer[CHUNK_SIZE] = {0};
        size_t  bytesRead  = 0;
        
        bytesRead = [inStream read:(uint8_t *)buffer maxLength:CHUNK_SIZE];
        err = SCloudDecryptNext(ref, buffer, bytesRead);
        
        if(IsSCLError(err) )break;
    }
    if(err == kSCLError_EndOfIteration) err = kSCLError_NoErr;
    CKERR;
    
    [inStream close]; inStream = NULL;
    [outStream close]; outStream = NULL;

    inStream = [NSInputStream inputStreamWithURL:outURL];
    [inStream open];
    
    if(handlerInfo.metaBuffer )
    {
        
        info   = [NSJSONSerialization JSONObjectWithData: handlerInfo.metaBuffer
                                                 options: NSJSONReadingMutableContainers
                                                   error: &error];
        
        totalSegments = [info valueForKey:kSCloudMetaData_Segments];
        
        if(totalSegments &&  totalSegments.unsignedIntegerValue > 1)
        {
            segments = [NSJSONSerialization JSONObjectWithStream:inStream
                                                         options:NSJSONReadingMutableContainers
                                                           error:&error];
            if(error != NULL) goto done;
        }
        
     }
  
     [inStream close]; inStream = NULL;
    
    // include index
    [segList addObject:_locator];
    
    // just return the locators
    if(segments) for(NSArray *segment in segments)
        [segList addObject:[segment objectAtIndex:1]];
    
    _metaData = info;
    _mediaType =  [info valueForKey:kSCloudMetaData_MediaType];
    
    if(![_metaData objectForKey:kSCloudMetaData_FileSize])
    {
        if(segments)
        {
            [ _metaData setObject: [NSNumber numberWithFloat:segments.count * kMaxSCloudSegmentSize ] forKey:kSCloudMetaData_FileSize];
        }
        else
        {
            [ _metaData setObject: [NSNumber numberWithLong:handlerInfo.dataLength ] forKey:kSCloudMetaData_FileSize];
   
        }
        
    }

    if(segments)
    {
        _segmentList = segments;
        _segments =  NSMakeRange (0,  totalSegments.unsignedIntegerValue);
  
    }
    success = YES;

done:
    
    
    [NSFileManager.defaultManager removeItemAtURL:outURL error:nil];
    
    if(inStream)
        [inStream close];
    
    if(outStream)
        [outStream close];
    
    if (errPtr)
        *errPtr = error;
    
    if(ref)
        SCloudFree(ref);
    
    return success;
    
}


// we need to help the IOS7 previewer

-(NSArray*) allowableExtensionsForMediaType:(NSString*)mediaType
{
    NSArray * extension = NULL;
    
    NSArray* ignoreThese = @[@"com.adobe.photoshop-image" ];
    
    if( [ignoreThese containsObject:mediaType] )
         return NULL;
    
    if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeGIF))
    {
        extension = @[@"GIF"];
    }
    else if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypePNG))
    {
        extension = @[@"png"];
    }
    else if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeImage))
    {
        extension = @[@"jpg", @"GIF"];
    }
    else if (UTTypeConformsTo( (__bridge CFStringRef)  _mediaType, kUTTypeMovie))
    {
        extension = @[@"m4v",@"mp4",@"mov"];
    }
    else if ((UTTypeConformsTo( (__bridge CFStringRef)  _mediaType, kUTTypePDF)))
    {
        extension = @[@"pdf"];
    }
    else   if ([_mediaType isEqualToString:(NSString *)kUTTypeVCard])
    {
        extension = @[@"vcf"];
    }
    else if ((UTTypeConformsTo( (__bridge CFStringRef)  _mediaType,  (__bridge CFStringRef) @"com.apple.ical.ics" )))
    {
        extension = @[@"ics"];
    }
 
    
    
    
    return extension;
}


- (NSURL*) postProcessFileName
{
    // Apple's previews are very picky about file names.   we either name it as it was sent or add an extension to them.
    
    NSURL    *newURL  = NULL;
    
    NSString* nativeFileName = [self.metaData valueForKey:kSCloudMetaData_FileName];
    BOOL isPackage = [[self.metaData valueForKey:kSCloudMetaData_isPackage] boolValue];;
    
    if(nativeFileName)
    {
        NSString* nativeFileExtension = nativeFileName.pathExtension;
        if(nativeFileExtension)
            newURL =  [_decryptedFileURL  URLByAppendingPathExtension:nativeFileExtension];
    }
    else
    {
        newURL = _decryptedFileURL;
    }
   
    
    NSString * existingExtension = [newURL pathExtension];
    NSArray*   allowableExtensions = [self allowableExtensionsForMediaType:_mediaType];
    NSString*  useExtension = NULL;
    
    if(existingExtension)
    {
        for(NSString *newExt in allowableExtensions)
        {
           if([existingExtension caseInsensitiveCompare:newExt] == NSOrderedSame)
           {
               useExtension = existingExtension;
               break;
           }
        }
        
    }
   
    if(!useExtension && allowableExtensions)
    {
         newURL = [newURL URLByAppendingPathExtension:[allowableExtensions firstObject]];
    }

    
//    
//    if(!existingExtension ||
//       ( newExtension &&  ([existingExtension caseInsensitiveCompare:newExtension] != NSOrderedSame)))
//    {
//        /* special case for GIFs gebnerated by ST 1.X  they should call it  MediaType = "com.compuserve.gif"; */
//        if([existingExtension isEqualToString:@"GIF"]
//           && (UTTypeConformsTo( (__bridge CFStringRef)  _mediaType, kUTTypeImage)));
//        else
//            newURL = [newURL URLByAppendingPathExtension:newExtension];
//    }
    
    
    if(newURL)
    {
        [ NSFileManager.defaultManager  removeItemAtURL:newURL error:NULL];
         
        [ NSFileManager.defaultManager  moveItemAtURL:_decryptedFileURL toURL:newURL error:NULL];
    }
    
 /*  
  if we have a package file, then we will eplicitly unzip it and treat it as if it were one file.
  if not we leep it as zip file, we habdle the rtfd and pages extensions as packages for backward compatibility,
  before we started tagging such files with kSCloudMetaData_isPackage tag 
  */
  
    if( isPackage
            || UTTypeEqual((__bridge CFStringRef)  _mediaType, kUTTypeRTFD)
            || UTTypeEqual((__bridge CFStringRef)  _mediaType, (__bridge CFStringRef)@"com.apple.iwork.pages.pages")
        )
     {
        NSURL* decompressedURL = [self deCompressDirectory:newURL];
        [ NSFileManager.defaultManager  removeItemAtURL:newURL error:NULL];
        newURL = decompressedURL;
    }

    return newURL;
    
}

- (BOOL)decryptSegmentToURL:(NSURL*)outURL segmentInfo:(NSArray*)segInfo withError:(NSError **)errPtr
{
    SCLError err = kSCLError_NoErr;
    BOOL result = NO;
    NSError* error = NULL;
    
    NSInputStream *inStream = NULL;
    NSOutputStream *outStream = NULL;
    SCloudContextRef ref = NULL;
    NSStreamStatus status;
    EventHandlerItem* handlerInfo = NULL;
    
    NSString *segLocator = [segInfo objectAtIndex:1];
    NSString *segKey = [segInfo objectAtIndex:2];
    
    NSURL* inURL = [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent:segLocator];
 
    inStream =  [NSInputStream inputStreamWithURL:inURL];
    [inStream open];
    status = [inStream streamStatus];
    if(status == NSStreamStatusClosed || status == NSStreamStatusError)
    {
        error = [inStream streamError]; goto done;
    }

    outStream =  [NSOutputStream outputStreamWithURL:outURL append:YES];
    [outStream open];
    status = [outStream streamStatus];
    if(status == NSStreamStatusClosed || status == NSStreamStatusError)
    {
        error = [outStream streamError]; goto done;
    }
  
    handlerInfo =  [EventHandlerItem itemWithStream:outStream metaBuffer:NULL];
    
    err = SCloudDecryptNew((uint8_t*)[segKey UTF8String], strlen([segKey UTF8String]),
                           ScloudSegmentDecryptEventHandler,(__bridge void *)handlerInfo, &ref); CKERR;
     
      
    while([inStream hasBytesAvailable])
    {
        uint8_t buffer[CHUNK_SIZE] = {0};
        size_t  bytesRead  = 0;
        
        bytesRead = [inStream read:(uint8_t *)buffer maxLength:CHUNK_SIZE];
        err = SCloudDecryptNext(ref, buffer, bytesRead);
          
        if(IsSCLError(err) )break;
    }
    if(err == kSCLError_EndOfIteration) err = kSCLError_NoErr;
    CKERR;
    
    [inStream close];
    [_decryptStream close];

    result = YES;
    
done:
    
    
    if (errPtr)
        *errPtr = error;
    
    if(ref)
        SCloudFree(ref);

    return result;
}



- (BOOL)decryptCachedFileUsingKeyString: (NSString*) keyString withError:(NSError **)errPtr
{
    SCLError err = kSCLError_NoErr;
    NSError* error = nil;
    BOOL    result = NO;
    float   fileSize = 0;
    NSNumber* number;
    
     NSInputStream *inStream = NULL;
    NSMutableArray *needSegs  = [[NSMutableArray alloc] init];
	
	NSString *uuid = [[NSUUID UUID] UUIDString];
    
    if(![self isCached]) return NO;
    
    [self removeDecryptedFile];
    _mediaData = NULL;
    _metaBuffer = NULL;
    _metaData   = NULL;
    _segmentList = NULL;
    _segments = NSMakeRange(0,00);
      
    
    [_cachedFileURL getResourceValue:&number forKey:NSURLFileSizeKey error:&error];
    if(error)
    {
        *errPtr = error.copy;
        return NO;
    }
    fileSize = number.floatValue;
    
     float totalBytesRead = 0;
    
    err = SCloudDecryptNew((uint8_t*)[keyString UTF8String], strlen([keyString UTF8String]),
                           ScloudEventHandler,(__bridge void *)self, &_scloud); CKERR;
    
    inStream =  [NSInputStream inputStreamWithURL:_cachedFileURL ];
    [inStream open];
	
	_decryptedFileURL = [[SCFileManager mediaCacheDirectoryURL] URLByAppendingPathComponent:uuid];
    
    _decryptStream =  [NSOutputStream outputStreamWithURL:_decryptedFileURL append:NO];
    
    [_decryptStream open];
    
    if(self.scloudDelegate)
    {
        [self.scloudDelegate scloudObject:self decryptingDidStart:YES];
    }
    
    while([inStream hasBytesAvailable])
    {
        uint8_t buffer[CHUNK_SIZE] = {0};
        size_t  bytesRead  = 0;
        
        bytesRead = [inStream read:(uint8_t *)buffer maxLength:CHUNK_SIZE];
        err = SCloudDecryptNext(_scloud, buffer, bytesRead);
        totalBytesRead += bytesRead;
        
        if(self.scloudDelegate)
        {
            [self.scloudDelegate scloudObject:self decryptingProgress: (float)totalBytesRead / fileSize];
        }
        
        if(IsSCLError(err) )break;
    }
    if(err == kSCLError_EndOfIteration) err = kSCLError_NoErr;
    CKERR;
    
    [inStream close];
    [_decryptStream close];
    
    if(self.metaBuffer)
    {
        NSMutableDictionary *info = nil;
        
        info   = [NSJSONSerialization JSONObjectWithData: self.metaBuffer
                                                 options: NSJSONReadingMutableContainers
                                                   error: &error];
        if(error != NULL) goto done;
        
        self.metaData = info;
        self.mediaType =  [self.metaData valueForKey:kSCloudMetaData_MediaType];
        
        NSNumber* segments = [self.metaData valueForKey:kSCloudMetaData_Segments];
        
        _segments = NSMakeRange(0,[segments unsignedIntValue]);
       if(segments && [segments unsignedIntValue] > 1)
        {
            NSNumber* number = NULL;
            
            NSInputStream *inStream = [NSInputStream inputStreamWithURL:_decryptedFileURL];
            [inStream open];
            NSMutableArray *segments = [NSJSONSerialization JSONObjectWithStream:inStream
                                                                         options:NSJSONReadingMutableContainers
                                                                           error:&error];
            if(error != NULL) goto done;
            _segmentList = [segments copy];
            
            [inStream close];
            
            [NSFileManager.defaultManager removeItemAtURL:_decryptedFileURL error:NULL];
 
            [segments sortUsingComparator:^(id obj1, id obj2) {
                return [[obj1 objectAtIndex:0] compare:[obj2 objectAtIndex:0]];
            }];
            
            for(NSArray * segment in segments)
            {
                NSError * err = NULL;
                
                NSURL* inURL = [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent:[segment objectAtIndex:1]];
                
                BOOL isFile = ([inURL checkResourceIsReachableAndReturnError:&err]
                              && !err
                              && [inURL isFileURL]);
                if(!isFile)
                {
                    [needSegs addObject:[segment objectAtIndex:1]];
                }
                
                if([needSegs count] == 0
                   && ![self decryptSegmentToURL:_decryptedFileURL segmentInfo:segment withError:&error])
                 goto done;
            }
            
            if([needSegs count] > 0)
            {
                error = [SCimpUtilities errorWithSCLError:kSCLError_ResourceUnavailable];
                goto done;
            } 
            
            
            [_decryptedFileURL getResourceValue:&number forKey:NSURLFileSizeKey error:NULL];
           
            fileSize = number.longLongValue;

        }
        
        // post process the top file
        
        if(![self.metaData objectForKey:kSCloudMetaData_FileSize])
        {
            NSMutableDictionary* meta1 = [NSMutableDictionary dictionaryWithDictionary:self.metaData];
            
            [meta1 setObject: [NSNumber numberWithFloat:fileSize] forKey:kSCloudMetaData_FileSize];
            self.metaData = meta1;
        }
        
        DDLogOrange(@"Decrypted %@ - %@", [self.metaData objectForKey:kSCloudMetaData_FileName],
                 [[self.metaData objectForKey:kSCloudMetaData_isPackage] boolValue]? @"isPackage":@"" );
        
        _decryptedFileURL =  [self postProcessFileName];
     }
    
done:
    
    if([needSegs count] > 0)
    {
        _missingSegments = [needSegs copy];
    }
        

    error = IsSCLError(err)?[SCimpUtilities errorWithSCLError:err]:error ;
    if(error)
    {
        [self removeDecryptedFile];
    }
    else
    {
        result = YES;
    }
    
    if (errPtr) *errPtr = error;
 
    if(self.scloudDelegate)
    {
        [self.scloudDelegate scloudObject:self decryptingDidCompleteWithError: error];
    }
    
    return result;
}


-(NSArray*) missingSegments
{
    NSMutableArray *needSegs  =  NSMutableArray.alloc.init ;
	NSURL* baseURL = [SCFileManager scloudCacheDirectoryURL];
    
    for(NSString * segment in _missingSegments)
    {
        NSError*  error = NULL;
        NSURL *url = [baseURL URLByAppendingPathComponent:segment isDirectory:NO];
        
        BOOL exists = ([url checkResourceIsReachableAndReturnError:&error]
                  && !error
                  && [url isFileURL]);

        if(!exists){
            [needSegs addObject:segment];
        }
    }
    
    _missingSegments = needSegs;
    return _missingSegments;
}



- (void) refresh
{
    NSString *url = [NSString stringWithFormat:@"https://s3.amazonaws.com/%@/%@",
                     kSilentStorageS3Bucket, _locator];
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:10.0];
    [request setHTTPMethod:@"HEAD"];
    
    NSHTTPURLResponse* response = nil;
    NSError* error = nil;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    _connection = [[NSURLConnection alloc] initWithRequest:request
                                                  delegate:self];

}


#pragma mark - NSURLConnection Implementations

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    
    if ([response isKindOfClass: [NSHTTPURLResponse class]]) {
        self.foundOnCloud  =  [(NSHTTPURLResponse*) response statusCode] == 200 ;
       
    }
    
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    _connection = NULL;
    
    if(self.scloudDelegate && [self.scloudDelegate respondsToSelector:@selector(scloudObject:updatedInfo:)])
    {
        [self.scloudDelegate scloudObject:self updatedInfo: NULL];
    }

}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if(self.scloudDelegate && [self.scloudDelegate respondsToSelector:@selector(scloudObject:updatedInfo:)])
    {
        [self.scloudDelegate scloudObject:self updatedInfo: NULL];
    }

    _connection = NULL;

}


@end
