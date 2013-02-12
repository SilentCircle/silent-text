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
//  SCloudObject.h
//  SilentText
//

#import <Foundation/Foundation.h>

extern NSString *const kSCloudMetaData_Date;
extern NSString *const kSCloudMetaData_MediaType;
extern NSString *const kSCloudMetaData_Exif;
extern NSString *const kSCloudMetaData_GPS;
extern NSString *const kSCloudMetaData_FileName;
extern NSString *const kSCloudMetaData_FileSize;
extern NSString *const kSCloudMetaData_Duration;
 
extern NSString *const kSCloudMetaData_MediaType_Segment;
extern NSString *const kSCloudMetaData_Segments;
  
@protocol SCloudObjectDelegate;

@interface SCloudObject : NSObject

@property (nonatomic, readonly) NSString* mediaType;
@property (nonatomic, retain)   UIImage* thumbnail;
@property (nonatomic, readonly) NSString* locatorString;

@property (nonatomic, readonly) NSString* cachedFilePath;
@property (nonatomic, readonly) NSString* decryptedFilePath;

@property (nonatomic, retain, readonly) NSData* mediaData;
@property (nonatomic, retain, readonly) NSMutableDictionary*  metaData;

@property (nonatomic,assign)    id <SCloudObjectDelegate> scloudDelegate;


@property (getter = isCached, readonly)         BOOL cached;
@property (getter = isDownloading, readonly)    BOOL downloading;
@property (getter = isInCloud, readonly)        BOOL inCloud;

- (id)initWithDelegate: (id)aDelegate
                  data:(NSData*)data
              metaData:(NSDictionary*)metaData
             mediaType:(NSString*)mediaType
         contextString:(NSString*)contextString;

- (id) initWithLocatorString:(NSString*) locatorString
                   keyString:(NSString*)keyString;

- (id) initWithLocatorString:(NSString*) locatorString ;

- (NSString*) keyString;
 
- (BOOL) saveToCacheWithError:(NSError **)error;
- (BOOL) decryptCachedFileUsingKeyString: (NSString*) keyString withError:(NSError **)errPtr;

+ (void) removeCachedFileWithLocatorString:(NSString*) locatorString;

- (void) refresh;  // used to update if item is in cloud

+(NSArray*)segmentsFromLocatorString:(NSString*)locatorString
                            keyString:(NSString*)keyString
                            withError:(NSError **)errPtr;

-(NSArray*) missingSegments;
-(uint32_t) segmentCount;

 @end

@protocol SCloudObjectDelegate <NSObject>

@optional

- (void)scloudObject:(SCloudObject *)sender calculatingKeysDidStart:(NSString*) mediaType;
- (void)scloudObject:(SCloudObject *)sender calculatingKeysProgress:(float) progress ;
- (void)scloudObject:(SCloudObject *)sender calculatingKeysDidCompleteWithError:(NSError *)error;

- (void)scloudObject:(SCloudObject *)sender encryptingDidStart:(NSString*) mediaType;
- (void)scloudObject:(SCloudObject *)sender encryptingProgress:(float) progress ;
- (void)scloudObject:(SCloudObject *)sender encryptingDidCompleteWithError:(NSError *)error;


- (void)scloudObject:(SCloudObject *)sender decryptingDidStart:(BOOL) foo;
- (void)scloudObject:(SCloudObject *)sender decryptingProgress:(float) progress ;
- (void)scloudObject:(SCloudObject *)sender decryptingDidCompleteWithError:(NSError *)error;

- (void)scloudObject:(SCloudObject *)sender updatedInfo:(NSError *)error;

@end
