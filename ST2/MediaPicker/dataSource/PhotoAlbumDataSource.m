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
//
//  PhotoAlbumDataSource.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 10/30/13.
//
#import <libkern/OSAtomic.h>

#import "PhotoAlbumDataSource.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreLocation/CoreLocation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import "ALAsset+SCUtilities.h"
#import "SCloudObject.h"
#import "NSDate+SCDate.h"
#import "STLogging.h"
#import "NSDictionary+SCDictionary.h"

// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && vinnie_moscaritolo
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@interface PhotoAlbumDataSource()
@end

@implementation PhotoAlbumDataSource

//completionBlock:(AlbumDataSourceLoadCompletionBlock)completion;

 
-(void)loadAlbumWithPhotos:(NSUInteger)photos2Load
                    completion:(MediaDataSourceLoadCompletionBlock)completionBlock
                   loadedBlock:(MediaDataSourceAlbumLoadedBlock)albumLoadedBlock
                    errorBlock:(MediaDataSourceErrorBlock)errorBlock;
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
 
    NSMutableArray *albums = [NSMutableArray array];
    
    void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) = ^(ALAssetsGroup *group, BOOL *stop) {
        
         __block int32_t  count = 0;
        
        if (group == nil) {
            
            if (completionBlock != nil) {
                (completionBlock)(albums);
            }
            return;
        }
        
        
        MediaAlbum *album = [[MediaAlbum alloc] init];
        album.mediaDataSource = self;
        album.albumID = [group valueForProperty:@"ALAssetsGroupPropertyPersistentID"];
        album.name = [group valueForProperty:@"ALAssetsGroupPropertyName"];
        album.url = [group valueForProperty:@"ALAssetsGroupPropertyURL"];
        album.posterImage = [UIImage imageWithCGImage:group.posterImage];
        album.albumType = kMediaAlbum_PhotoAlbum;
        album.numberOfItemsAvailable = group.numberOfAssets;
        
        [albums addObject:album];

        if(photos2Load > 0)
        {     [group setAssetsFilter:[ALAssetsFilter allPhotos]];
            
            @autoreleasepool {
                [group enumerateAssetsWithOptions:NSEnumerationConcurrent
                                       usingBlock:^(ALAsset *asset, NSUInteger index, BOOL *stop1) {
                                           
                       if(asset == nil && index == NSNotFound) {
                           if (albumLoadedBlock != nil) {
                               (albumLoadedBlock) (album);
                           }
                           
                           [albums addObject:album];
                       }
                       else if(OSAtomicIncrement32(&count) <= photos2Load)
                       {
                           NSMutableDictionary *metaDict = [[NSMutableDictionary alloc] init];
                           
                           ALAssetRepresentation *rep = [asset defaultRepresentation];
                           NSDictionary   *metadata  = rep.metadata;
                           
                           NSDate         *date      = NULL;
                           NSString       *filename  = NULL;
                           NSString       *duration  = NULL;
                           
                           
                           NSString       *mediaType = rep.UTI;
                           NSString       *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef) mediaType, kUTTagClassMIMEType);
       
                           
                           [metaDict setObject:mediaType forKey: kSCloudMetaData_MediaType];
                           
                           if(mimeType)
                               [metaDict setObject: mimeType forKey:kSCloudMetaData_MimeType];
                           if(metadata)
                           {
                               [metadata filterEntriesFromMetaDataTo:metaDict];
                               //							 [metaDict addEntriesFromDictionary:metadata];
                               NSString * dateTime = [[ metadata  objectForKey:@"{Exif}"] objectForKey:@"DateTimeOriginal"];
                               if(dateTime)
                                   date = [NSDate dateFromEXIF: dateTime];
                           }
                           
                           if(!date)  date = [asset valueForProperty:ALAssetPropertyDate];
                           
                           filename = rep.filename;
  
                           if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeMovie))
                           {
                                duration = [NSString stringWithFormat:@"%f", [[asset valueForProperty:ALAssetPropertyDuration] doubleValue]];
                               
                           }

                           if(date) [metaDict setObject: [date rfc3339String] forKey:kSCloudMetaData_Date];
                           if(filename) [metaDict setObject: filename forKey:kSCloudMetaData_FileName];
                           
                           MediaItem *item = [[MediaItem alloc] init];
                           item.mediaID =  [asset.defaultRepresentation.url description];
                           item.mediaType = mediaType;
                           item.metadata = metaDict;
                           item.url = asset.defaultRepresentation.url;
                           item.thumbNail = [UIImage imageWithCGImage:asset.aspectRatioThumbnail];
                           item.name = filename;
                           [album.items addObject:item];
                       }
                        else
                        {
                            *stop1 = YES;
                        }
                       
                   }];
            }
        }
        else
        {
            if (albumLoadedBlock != nil) {
                (albumLoadedBlock) (album);
            }
        }
     };
   


    // Group Enumerator Failure Block
    void (^assetGroupEnumberatorFailure)(NSError *) = ^(NSError *error) {
        
        if (errorBlock != nil) {
            (errorBlock)(error);
        }
    };

    [library enumerateGroupsWithTypes:ALAssetsGroupAlbum | ALAssetsGroupLibrary | ALAssetsGroupSavedPhotos | ALAssetsGroupPhotoStream
                           usingBlock:assetGroupEnumerator
                         failureBlock:assetGroupEnumberatorFailure];

}

-(void)loadAlbum:(MediaAlbum*)album withRangeofItems:(NSRange)range
      errorBlock:(MediaDataSourceErrorBlock)errorBlock
{
    if (errorBlock != nil) {
        (errorBlock)(NULL);
    }

}

@end
