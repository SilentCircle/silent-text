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
//  SCloudObject.m
//  SilentText
//

#import <MobileCoreServices/MobileCoreServices.h>

#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import "App+ApplicationDelegate.h"

 #import "AppConstants.h"
#import "StorageCipher.h"
#include <tomcrypt.h>

#include "SCloud.h"
#include "cryptowrappers.h"
#import "SCloudObject.h"

static const NSInteger kMaxSCloudSegmentSize  = ((64*1024)-80);

NSString *const kSCloudMetaData_Date      = @"DateTme";
NSString *const kSCloudMetaData_FileName   = @"FileName";
NSString *const kSCloudMetaData_MediaType = @"MediaType";
NSString *const kSCloudMetaData_Exif      = @"{Exif}";
NSString *const kSCloudMetaData_GPS       = @"{GPS}";
NSString *const kSCloudMetaData_FileSize       = @"FileSize";
NSString *const kSCloudMetaData_Duration       = @"Duration";


NSString *const kSCloudMetaData_MediaType_Segment = @"com.silentcircle.scloud.segment";
NSString *const kSCloudMetaData_Segments        =  @"Scloud_Segments";
 
static NSString *const kLocatorKey = @"locator";
static NSString *const kKeyKey = @"key";
static NSString *const kSegmentyKey = @"segment";

@interface SCloudObjectSegment : NSObject<NSCoding>

@property (nonatomic) NSUInteger item;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy)  NSString *locator;
@end



@interface eventHandlerItem : NSObject
@property (nonatomic, retain) NSOutputStream *decryptStream;
@property (nonatomic, retain) NSMutableData *metaBuffer;
@end

@implementation eventHandlerItem;
+ (eventHandlerItem *)itemWithStream:(NSOutputStream *)decryptStream metaBuffer:(NSMutableData *)metaBuffer
{
    
    eventHandlerItem *item = [[eventHandlerItem alloc] init];
    item.decryptStream = decryptStream;
    item.metaBuffer = metaBuffer;
    return item;
}

-(void)dealloc
{
    _metaBuffer = NULL;
}

@end;


@interface SCloudObject ()
{
    
    
}

@property (nonatomic, readwrite) SCloudContextRef scloud;
@property (nonatomic, retain, readwrite) NSMutableDictionary*  metaData;

@property (nonatomic, readwrite) NSData*        metaBuffer;
@property (nonatomic, retain)    NSData*        mediaData;

@property (nonatomic, retain)    NSString*      locator;
@property (nonatomic, retain)    NSString*      key;
@property (nonatomic, readwrite) NSString*      mediaType;
@property (nonatomic, readwrite) NSString*      contextString;          // this is just a nonce
 
@property (nonatomic, readwrite) NSString*          cachedFilePath;

@property (nonatomic, readwrite) NSString*          decryptedFilePath;
@property (nonatomic, readwrite) NSOutputStream*      decryptStream;

@property (nonatomic, readwrite) BOOL               foundOnCloud;
@property (nonatomic, retain)   NSURLConnection*    connection;

@property (nonatomic, readwrite) NSRange             segments;
@property (nonatomic, retain)   NSMutableArray*      segmentList;
@property (nonatomic, retain)   NSArray*        missingSegments;

@end

@implementation SCloudObject

@synthesize scloud      = _scloud;
@synthesize thumbnail  = _thumbnail;

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
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSString* dirPath = [App.sharedApp makeDirectory: kDirectoryMediaCache ];
        NSString* filePath = [dirPath stringByAppendingPathComponent: locatorString];
        
        if( filePath && [fm fileExistsAtPath:filePath])
            [fm removeItemAtPath:filePath error:nil];
       
    }
    
    
}

#pragma mark - utility

-(NSError*) errorWithSCError: (SCLError)err
{
    char        errorBuf[256];
    SCLGetErrorString(err, sizeof(errorBuf), errorBuf);
    NSMutableDictionary* details = [NSMutableDictionary dictionary];
    
    [details setValue:[NSString stringWithUTF8String:errorBuf] forKey:NSLocalizedDescriptionKey];
    
    return[NSError errorWithDomain:kSCErrorDomain code:err userInfo:details];
    
}

#pragma mark - public functions

- (id) initWithLocatorString:(NSString*) locatorString
                   keyString:(NSString*)keyString;
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
     }
    return self;
 
}
- (id) initWithLocatorString:(NSString*) locatorString ;
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
    }
    return self;
    
}


- (id)initWithDelegate: (id)aDelegate
                  data:(NSData*)data
              metaData:(NSDictionary*)metaData
             mediaType:(NSString*)mediaType
         contextString:(NSString*)contextString
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
    }
    
    return self;
    
}


- (BOOL) isCached {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self cachedFilePath]];
      
} // -isCached


- (BOOL) isDownloading {
    return [[NSFileManager defaultManager]
            fileExistsAtPath: [[self cachedFilePath]stringByAppendingPathExtension:@"tmp"]];
    
} // -isDownloading

 
-(BOOL) isInCloud
{
    return _foundOnCloud;
}

-(uint32_t) segmentCount
{
    return _segments.length;
}


- (NSString*) cachedFilePath
{
    
    if(!_cachedFilePath)
    {
        NSString* dirPath = [App.sharedApp makeDirectory: kDirectoryMediaCache ];
        NSString* fileName = [self locatorString];
        NSString*  filePath = [dirPath stringByAppendingPathComponent: fileName];
        
        _cachedFilePath =  filePath;
    }

    return _cachedFilePath;
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
    if(_decryptedFilePath)
    {
        [[NSFileManager defaultManager] removeItemAtPath:_decryptedFilePath error:nil];
        _decryptedFilePath = NULL;
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
    NSString*  filePath = NULL;
    NSOutputStream *outStream = NULL;
    
    SCloudContextRef segRef = NULL;
    
    
    App *app = App.sharedApp;
    NSString* dirPath = [app makeDirectory: kDirectoryMediaCache ];
    
    if(self.scloudDelegate)
    {
        stage = 1;
        [self calculatingSegmentKeysDidStart:segment mediaType:self.mediaType];
    }
    
    err = SCloudEncryptNew( (void*)[_contextString UTF8String], [_contextString length],
                           (void*)[data bytes], [data length],
                           (void*) (metaData ? [metaData bytes]: NULL), metaData? [metaData length]: 0,
                           ScloudSegmentEventHandler,(__bridge void *)self, &segRef); CKERR;
    
    err = SCloudCalculateKey(segRef, 1024); CKERR;
    
    if(self.scloudDelegate)
    {
        stage = 2;
        [self calculatingSegmentKeysDidCompleteWithError:segment error:error];
    }
    
    {
        uint8_t * keyBLOB   = NULL;
        size_t  keyBLOBlen  = 0;
        uint8_t locatorURL[SCLOUD_LOCATOR_LEN * 2] = {0};
        size_t  locatorURLlen  = sizeof(locatorURL);
        
        err = SCloudEncryptGetKeyBLOB(segRef, &keyBLOB, &keyBLOBlen); CKERR;
        err = SCloudEncryptGetLocatorREST(segRef, locatorURL, &locatorURLlen); CKERR;
        
        segKey = [NSString.alloc initWithBytesNoCopy: keyBLOB
                                              length: keyBLOBlen
                                            encoding: NSUTF8StringEncoding
                                        freeWhenDone: YES];
        
        segLocator = [NSString.alloc initWithBytes: locatorURL
                                            length: strlen((char*)locatorURL)
                                          encoding: NSUTF8StringEncoding];
    }
    
    
    filePath = [dirPath stringByAppendingPathComponent: segLocator];
    
    [NSFileManager.defaultManager createFileAtPath:filePath contents:nil attributes:nil];
    
    outStream =  [NSOutputStream outputStreamToFileAtPath: filePath append:NO];
    
    uint8_t outBuffer[CHUNK_SIZE] = {0};
    size_t  dataSize  = 0;
    
    stage = 3;
    [self encryptingSegmentDidStart:segment mediaType:self.mediaType];
    
    [outStream open];
    
    for(dataSize = CHUNK_SIZE;
        IsntSCLError( ( err = SCloudEncryptNext(segRef, outBuffer, &dataSize)) );
        dataSize = CHUNK_SIZE)
    {
        
        [outStream write: outBuffer  maxLength: dataSize];
        [self encryptingSegmentProgress:segment progress:(float)0];
        
    }
    if(err == kSCLError_EndOfIteration) err = kSCLError_NoErr;
    
    [outStream close];
    
done:
    
    if(IsSCLError(err))
    {
        error = [self errorWithSCError:err] ;
    }
    else
    {
        result = YES;
        *locator = [segLocator copy];
        *key    = [segKey copy];
    }
    
    if(stage == 1)
    {
        [self calculatingSegmentKeysDidCompleteWithError:segment error:error];
        
    }
    else if(stage == 3)
    {
        [self encryptingSegmentDidCompleteWithError:segment error:error];
    }
    
    segLocator = NULL;
    segKey   = NULL;
    
    if(segRef)
        SCloudFree(segRef);
    
    if (errPtr) *errPtr = error;
    
    return result;
}


- (void)calculatingSegmentKeysDidStart:(NSRange)segment mediaType:(NSString*) mediaType
{
    if(_segments.location == 0 && self.scloudDelegate)
    {
        [self.scloudDelegate scloudObject:self calculatingKeysDidStart:self.mediaType];
    }
    
}

- (void)calculatingSegmentKeysProgress:(float) progress
{
     if(self.scloudDelegate)
     {
         size_t maximum  = (_segments.length * kMaxSCloudSegmentSize);
         size_t current =  (size_t)(progress * kMaxSCloudSegmentSize) + (_segments.location * kMaxSCloudSegmentSize);
         
         float percent = (float)current / (float)maximum;
         
         [self.scloudDelegate scloudObject:self calculatingKeysProgress: percent];
    }
    
}

- (void)calculatingSegmentKeysDidCompleteWithError:(NSRange)segment error:(NSError *)error
{
    if(_segments.location == _segments.length - 1 &&  self.scloudDelegate)
    {
        [self.scloudDelegate scloudObject:self calculatingKeysDidCompleteWithError: error];
    }
}

- (void)encryptingSegmentDidStart:(NSRange)segment mediaType:(NSString*) mediaType
{
    if(segment.location == 0 && self.scloudDelegate)
    {
        [self.scloudDelegate scloudObject:self encryptingDidStart:self.mediaType];
    }
  
}
- (void)encryptingSegmentProgress:(NSRange)segment progress:(float) progress
{
    
    if(self.scloudDelegate)
    {
        size_t maximum  = (segment.length * kMaxSCloudSegmentSize);
        size_t current =  (size_t)(progress * kMaxSCloudSegmentSize) + (segment.location * kMaxSCloudSegmentSize);
        
        float percent = (float)current / (float)maximum;
        
        [self.scloudDelegate scloudObject:self encryptingProgress:percent];
     }

}
- (void)encryptingSegmentDidCompleteWithError:(NSRange)segment error:(NSError *)error
{
    if(segment.location == segment.length - 1 &&  self.scloudDelegate)
    {
        [self.scloudDelegate scloudObject:self encryptingDidCompleteWithError: error];
    }
   
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
                [self.scloudDelegate scloudObject:self calculatingKeysProgress: (float)event->data.progress.bytesProcessed / event->data.progress.bytesTotal];
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
                [self calculatingSegmentKeysProgress: (float)event->data.progress.bytesProcessed / event->data.progress.bytesTotal];
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
    
    eventHandlerItem *handlerItem = (__bridge eventHandlerItem *)uservalue;
    
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





#pragma mark - file encryption

- (BOOL) saveToCacheWithError:(NSError **)errPtr
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
  
    if(totalSegments > 1)
    {
        NSMutableDictionary *metaDict = [[NSMutableDictionary alloc] init];
        [metaDict setObject:kSCloudMetaData_MediaType_Segment forKey: kSCloudMetaData_MediaType];

        NSData *segMetaData = ([NSJSONSerialization  isValidJSONObject: metaDict] ?
                        [NSJSONSerialization dataWithJSONObject: metaDict options: 0UL error: &error] :
                        nil);
        
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
    if(!result)    goto done;
    
    _locator = topLocator;
    _key = topKey;

done:
    
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


#pragma mark - File segments


+(NSArray*)segmentsFromLocatorString:(NSString*)locatorString
                           keyString:(NSString*)keyString
                           withError:(NSError **)errPtr
{
    SCLError err = kSCLError_NoErr;
    NSError* error = nil;
    
    SCloudContextRef ref = NULL;
    NSStreamStatus status;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSInputStream *inStream     = NULL;
    NSOutputStream *outStream    = NULL;
    NSMutableArray *segments  =  NULL;
    NSMutableArray *segList  =  NSMutableArray.alloc.init;
     
     eventHandlerItem* handlerInfo = NULL;
    
    NSString* inPath = [[App.sharedApp makeDirectory: kDirectoryMediaCache ]
                        stringByAppendingPathComponent: locatorString];
    
    NSString* outPath  = [[App.sharedApp makeDirectory: kDirectorySCloudCache ]
                          stringByAppendingPathComponent: [StorageCipher uuid]];
    
    [fm createFileAtPath:outPath
                contents:nil
              attributes: [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                                      forKey:NSFileProtectionKey]];
    
    inStream =  [NSInputStream inputStreamWithFileAtPath: inPath];
    [inStream open];
    status = [inStream streamStatus];
    if(status == NSStreamStatusClosed || status == NSStreamStatusError)
    {
        error = [inStream streamError]; goto done;
    }
    
    
    outStream =  [NSOutputStream outputStreamToFileAtPath: outPath append:NO];
    [outStream open];
    status = [outStream streamStatus];
    if(status == NSStreamStatusClosed || status == NSStreamStatusError)
    {
        error = [outStream streamError]; goto done;
    }
    
    handlerInfo =  [eventHandlerItem itemWithStream:outStream metaBuffer:NULL];
 
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
    
    inStream = [NSInputStream inputStreamWithFileAtPath:outPath];
    [inStream open];
    
    if(handlerInfo.metaBuffer )
    {
        NSMutableDictionary *info = nil;
        
        info   = [NSJSONSerialization JSONObjectWithData: handlerInfo.metaBuffer
                                                 options: NSJSONReadingMutableContainers
                                                   error: &error];
        
        NSNumber* totalSegments = [info valueForKey:kSCloudMetaData_Segments];
        
        if(totalSegments &&  totalSegments.unsignedIntegerValue > 0)
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
    if(segments) for(NSArray *segment in segments)
        [segList addObject:[segment objectAtIndex:1]];
     
done:
    
    [fm removeItemAtPath:outPath error:nil];
    
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


- (NSString*) postProcessFileName
{
    // Apple's previews are very picky about file names.   we either name it as it was sent or add an extension to them.
    
    NSString    *newPath  = NULL;
  
    NSString* nativeFileName = [self.metaData valueForKey:kSCloudMetaData_FileName];
    
    if(nativeFileName)
    {
        newPath =  [[_decryptedFilePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:nativeFileName];
    }
    else
    {
        newPath = _decryptedFilePath;
    }
    
    NSString * extension = [newPath pathExtension];
    
    if(!extension || [extension isEqualToString:@""])
    {
        if ([self.mediaType isEqualToString:(NSString *)kUTTypeImage])
        {
            newPath = [_decryptedFilePath stringByAppendingPathExtension: @"jpg"];
        }
        else if ([self.mediaType isEqualToString:(NSString *)kUTTypeMovie])
        {
            newPath = [_decryptedFilePath stringByAppendingPathExtension: @"m4v"];
        }
        else if ([self.mediaType isEqualToString:(NSString *)kUTTypePDF])
        {
            newPath = [_decryptedFilePath stringByAppendingPathExtension: @"pdf"];
        }
        else if ([self.mediaType isEqualToString:(NSString *)kUTTypeVCard])
        {
            newPath = [_decryptedFilePath stringByAppendingPathExtension: @"vcf"];
        }
     }
 

    if(newPath)
    {
        [[NSFileManager defaultManager] moveItemAtPath:_decryptedFilePath toPath:newPath error:nil];
    }
    
    return newPath;
    
}

- (BOOL)decryptSegmentToFile: (NSString*) filePath segmentInfo:(NSArray*)segInfo withError:(NSError **)errPtr
{
    SCLError err = kSCLError_NoErr;
    BOOL result = NO;
    NSError* error = NULL;
    
    NSInputStream *inStream = NULL;
    NSOutputStream *outStream = NULL;
    SCloudContextRef ref = NULL;
    NSStreamStatus status;
    eventHandlerItem* handlerInfo = NULL;
    
    NSString *segLocator = [segInfo objectAtIndex:1];
    NSString *segKey = [segInfo objectAtIndex:2];
    
    NSString* dirPath = [App.sharedApp makeDirectory: kDirectoryMediaCache ];
    NSString*  inPath = [dirPath stringByAppendingPathComponent: segLocator];

    inStream =  [NSInputStream inputStreamWithFileAtPath: inPath];
    [inStream open];
    status = [inStream streamStatus];
    if(status == NSStreamStatusClosed || status == NSStreamStatusError)
    {
        error = [inStream streamError]; goto done;
    }

    outStream =  [NSOutputStream outputStreamToFileAtPath: filePath append:YES];
    [outStream open];
    status = [outStream streamStatus];
    if(status == NSStreamStatusClosed || status == NSStreamStatusError)
    {
        error = [outStream streamError]; goto done;
    }
  
    handlerInfo =  [eventHandlerItem itemWithStream:outStream metaBuffer:NULL];
    
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
    NSFileManager *fm = [NSFileManager defaultManager];
    NSInputStream *inStream = NULL;
    NSMutableArray *needSegs  = [[NSMutableArray alloc] init];
    NSString* dirPath = [App.sharedApp makeDirectory: kDirectoryMediaCache ];
   
    if(![self isCached]) return NO;
    
    [self removeDecryptedFile];
    _mediaData = NULL;
    _metaBuffer = NULL;
    _metaData   = NULL;
    _segmentList = NULL;
    _segments = NSMakeRange(0,00);
      
    NSDictionary* attributes =  [fm attributesOfItemAtPath:self.cachedFilePath error:nil];
    fileSize =  [[attributes objectForKey:NSFileSize] longLongValue];
    float totalBytesRead = 0;
    
    err = SCloudDecryptNew((uint8_t*)[keyString UTF8String], strlen([keyString UTF8String]),
                           ScloudEventHandler,(__bridge void *)self, &_scloud); CKERR;
    
    
    inStream =  [NSInputStream inputStreamWithFileAtPath: self.cachedFilePath];
    [inStream open];
    
    _decryptedFilePath = [[App.sharedApp makeDirectory: kDirectorySCloudCache ]
                          stringByAppendingPathComponent: [StorageCipher uuid]];
    
    [fm createFileAtPath:_decryptedFilePath
                contents:nil
              attributes: [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                                      forKey:NSFileProtectionKey]];
    
    _decryptStream =  [NSOutputStream outputStreamToFileAtPath: _decryptedFilePath append:NO];
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
            NSInputStream *inStream = [NSInputStream inputStreamWithFileAtPath:_decryptedFilePath];
            [inStream open];
            NSMutableArray *segments = [NSJSONSerialization JSONObjectWithStream:inStream
                                                                         options:NSJSONReadingMutableContainers
                                                                           error:&error];
            if(error != NULL) goto done;
            _segmentList = [segments copy];
            
            [inStream close];
            [fm removeItemAtPath:_decryptedFilePath error:nil];
             
            [segments sortUsingComparator:^(id obj1, id obj2) {
                return [[obj1 objectAtIndex:0] compare:[obj2 objectAtIndex:0]];
            }];
            
            for(NSArray * segment in segments)
            {
                NSString*  inPath = [dirPath stringByAppendingPathComponent: [segment objectAtIndex:1]];
                
                if(![[NSFileManager defaultManager] fileExistsAtPath:inPath])
                {
                    [needSegs addObject:[segment objectAtIndex:1]];
                }
                
                if([needSegs count] == 0
                   && ![self decryptSegmentToFile:_decryptedFilePath segmentInfo:segment withError:&error])
                 goto done;
            }
            
            if([needSegs count] > 0)
            {
                error = [self errorWithSCError:kSCLError_ResourceUnavailable];
                goto done;
            } 
            
            NSDictionary* attributes =  [fm attributesOfItemAtPath:_decryptedFilePath error:nil];
            fileSize =  [[attributes objectForKey:NSFileSize] longLongValue];
        }
        
        // post process the top file
        NSMutableDictionary* meta1 = [NSMutableDictionary dictionaryWithDictionary:self.metaData];
        
        [meta1 setObject: [NSNumber numberWithFloat:fileSize] forKey:kSCloudMetaData_FileSize];
        self.metaData = meta1;
        
        _decryptedFilePath =  [self postProcessFileName];
     }
    
done:
    
    if([needSegs count] > 0)
    {
        _missingSegments = [needSegs copy];
    }
        

    error = IsSCLError(err)?[self errorWithSCError:err]:error ;
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
    NSString* dirPath = [App.sharedApp makeDirectory: kDirectoryMediaCache ];
    
    for(NSString * segment in _missingSegments)
    {
          NSString*  segPath = [dirPath stringByAppendingPathComponent: segment];
        
        if(![[NSFileManager defaultManager] fileExistsAtPath:segPath])
        {
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
