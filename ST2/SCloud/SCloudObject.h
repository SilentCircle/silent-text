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
@class ALAsset;


extern NSString *const kSCloudMetaData_Date;
extern NSString *const kSCloudMetaData_MediaType;
extern NSString *const kSCloudMetaData_MimeType;
extern NSString *const kSCloudMetaData_Exif;
extern NSString *const kSCloudMetaData_GPS;
extern NSString *const kSCloudMetaData_FileName;
extern NSString *const kSCloudMetaData_FileSize;
extern NSString *const kSCloudMetaData_Duration;
extern NSString *const kSCloudMetaData_MediaWaveform;
extern NSString *const kSCloudMetaData_isPackage;           // the item is an OSX/IOS package

extern NSString *const kSCloudMetaData_DisplayName;
extern NSString *const kSCloudMetaData_Thumbnail;

extern NSString *const kSCloudMetaData_MediaType_Segment;
extern NSString *const kSCloudMetaData_Segments;
extern NSString *const kSCloudMetaData_Segment_Number;

@protocol SCloudObjectDelegate;


@interface SCloudObject : NSObject

- (id)initWithDelegate:(id)aDelegate
                  data:(NSData *)data
              metaData:(NSDictionary *)metaData
             mediaType:(NSString *)mediaType
         contextString:(NSString *)contextString;

- (id)initWithDelegate:(id)aDelegate
                 asset:(ALAsset *)asset
              metaData:(NSDictionary *)metaData
             mediaType:(NSString *)mediaType
         contextString:(NSString *)contextString;

- (id)initWithDelegate:(id)aDelegate
                   url:(NSURL *)url
              metaData:(NSDictionary *)metaData
             mediaType:(NSString *)mediaType
         contextString:(NSString *)contextString;

- (id)initWithLocatorString:(NSString *)locatorString
                  keyString:(NSString *)keyString
                       fyeo:(BOOL)fyeo;                 // this is just a flag, doenst change behavior of object

- (id)initWithLocatorString:(NSString *)locatorString;

@property (nonatomic, weak, readwrite) id <SCloudObjectDelegate> scloudDelegate;
@property (nonatomic, weak, readwrite) id  userValue;

@property (nonatomic, strong, readonly) NSString * mediaType;
@property (nonatomic, strong, readonly) NSString * locatorString;
@property (nonatomic, assign, readonly) BOOL       fyeo;

@property (nonatomic, strong, readonly) NSURL* cachedFilePathURL;
@property (nonatomic, strong, readonly) NSURL* decryptedFileURL;

@property (nonatomic, strong, readonly) NSData              * mediaData;
@property (nonatomic, strong, readonly) NSMutableDictionary * metaData;
@property (nonatomic, strong, readonly) NSMutableArray      * segmentList;

@property (nonatomic, strong, readwrite) UIImage* thumbnail;

@property (readonly, getter = isCached)      BOOL cached;
@property (readonly, getter = isDownloading) BOOL downloading;
@property (readonly, getter = isInCloud)     BOOL inCloud;

- (NSString *)keyString;
 
- (BOOL) saveToCacheWithError:(NSError **)error;
- (BOOL) decryptCachedFileUsingKeyString: (NSString*) keyString withError:(NSError **)errPtr;

- (BOOL) decryptMetaDataUsingKeyString:(NSString*) keyString withError:(NSError **)errPtr;

- (void) removeDecryptedFile;


- (void) refresh;  // used to update if item is in cloud

+(NSArray*)segmentsFromLocatorString:(NSString*)locatorString
                            keyString:(NSString*)keyString
                            withError:(NSError **)errPtr;

-(NSArray*) missingSegments;
-(uint32_t) segmentCount;

@end

#pragma mark -

@protocol SCloudObjectDelegate <NSObject>
@optional

- (void)scloudObject:(SCloudObject *)sender savingDidStart:(NSString*) mediaType totalSegments:(NSInteger)totalSegments;
- (void)scloudObject:(SCloudObject *)sender savingProgress:(float) progress ;
- (void)scloudObject:(SCloudObject *)sender savingDidCompleteWithError:(NSError *)error;


- (void)scloudObject:(SCloudObject *)sender decryptingDidStart:(BOOL) foo;
- (void)scloudObject:(SCloudObject *)sender decryptingProgress:(float) progress ;
- (void)scloudObject:(SCloudObject *)sender decryptingDidCompleteWithError:(NSError *)error;

- (void)scloudObject:(SCloudObject *)sender updatedInfo:(NSError *)error;

@end
