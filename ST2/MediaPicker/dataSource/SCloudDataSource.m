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

#import "SCloudDataSource.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreLocation/CoreLocation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import "ALAsset+SCUtilities.h"
#import "SCloudObject.h"
#import "NSDate+SCDate.h"
#import "STLogging.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "NSURL+SCUtilities.h"
#import <ImageIO/ImageIO.h>
#import "NSDictionary+SCDictionary.h"

#import "STSCloud.h"


// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && vinnie_moscaritolo
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@interface SCloudDataSource()
@end

@implementation SCloudDataSource


-(void)loadAlbumWithPhotos:(NSUInteger)photos2Load
                    completion:(MediaDataSourceLoadCompletionBlock)completionBlock
                   loadedBlock:(MediaDataSourceAlbumLoadedBlock)albumLoadedBlock
                    errorBlock:(MediaDataSourceErrorBlock)errorBlock;
{
    __block int32_t  count = 0;
    __block BOOL  posterImageChosen = NO;;
    
    NSMutableArray *albums = [NSMutableArray array];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSURL* documents = [NSURL fileURLWithPath:[paths objectAtIndex:0] ];
    
    MediaAlbum *album = [[MediaAlbum alloc] init];
    album.albumID = documents.fileReferenceURL.description;
    album.mediaDataSource = self;
    album.name = @"SCloud";
    album.url = documents;
    //ST-982 - New branding
    // NOTE: this image is more than twice as big as previously
    album.posterImage = [UIImage imageNamed:@"sclogo-inapp-medium"]; //[UIImage imageNamed:@"scloud-folder"];
    album.albumType = kMediaAlbum_sCloud;
    
    [albums addObject:album];
    
    if(photos2Load > 0)
    {
        YapDatabaseConnection *bgDatabaseConnection = STDatabaseManager.roDatabaseConnection;
        [bgDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
            
            album.numberOfItemsAvailable = [transaction numberOfKeysInCollection: kSCCollection_STSCloud];
            
            [transaction enumerateKeysAndObjectsInCollection:kSCCollection_STSCloud
                                                  usingBlock:^(NSString *scloudID, id object, BOOL *stop)
             {
                 
                 STSCloud* scl = [transaction objectForKey:scloudID inCollection:kSCCollection_STSCloud];
                 if(scl.thumbnail || scl.lowRezThumbnail)
                 {
                     if(OSAtomicIncrement32(&count) <= photos2Load)
                     {
                          MediaItem *item = [[MediaItem alloc] init];
                         item.mediaID =  scloudID;
                         item.mediaType = scl.mediaType;
                         item.metadata = scl.metaData;
                         item.url = NULL;
                         item.thumbNail = scl.thumbnail?scl.thumbnail:scl.lowRezThumbnail;
                         item.name = [scl.metaData objectForKey:kSCloudMetaData_FileName];
                         
                         [album.items addObject:item];
                         
                         if(!posterImageChosen && item.thumbNail)
                         {
                             album.posterImage = item.thumbNail;
                             posterImageChosen = YES;
                         }
                         
                     }
                     else
                     {
                         *stop = YES;
                     }
 
                 }
                }];
            
        }completionBlock:^{
            
            if (albumLoadedBlock != nil) {
                (albumLoadedBlock) (album);
            }
            
            if (completionBlock != nil) {
                (completionBlock)(albums);
            }
        }];
        
    }
    else
    {
        
        if (albumLoadedBlock != nil) {
            (albumLoadedBlock) (album);
        }
        
        if (completionBlock != nil) {
            (completionBlock)(albums);
        }
        
    }
    
    
}

-(BOOL)foundMediaID:(NSString*)mediaID inAlbum:(MediaAlbum*)album
{
    BOOL found = NO;
    
    for(MediaItem* item in album.items)
    {
        if([item.mediaID isEqualToString:mediaID])
        {
            found = YES;
            break;
        }
    }
    return  found;
    
}

-(void)loadAlbum:(MediaAlbum*)album withRangeofItems:(NSRange)range
      errorBlock:(MediaDataSourceErrorBlock)errorBlock
{
	YapDatabaseConnection *bgDatabaseConnection = STDatabaseManager.roDatabaseConnection;
    [bgDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        album.numberOfItemsAvailable = [transaction numberOfKeysInCollection: kSCCollection_STSCloud];
        
        [transaction enumerateKeysAndObjectsInCollection:kSCCollection_STSCloud
                                              usingBlock:^(NSString *scloudID, id object, BOOL *stop)
         {
             
             STSCloud* scl = [transaction objectForKey:scloudID inCollection:kSCCollection_STSCloud];
             if(scl.thumbnail || scl.lowRezThumbnail)
             {
                  if(![self foundMediaID:scloudID inAlbum:album])
                    {
                        
                     MediaItem *item = [[MediaItem alloc] init];
                     item.mediaID =  scloudID;
                     item.mediaType = scl.mediaType;
                     item.metadata = scl.metaData;
                     item.url = NULL;
                     item.thumbNail = scl.thumbnail?scl.thumbnail:scl.lowRezThumbnail;
                     item.name = [scl.metaData objectForKey:kSCloudMetaData_FileName];
                     
                     [album.items addObject:item];
                       
                 }
               }
         }];
        
        if (errorBlock != nil) {
            (errorBlock)(NULL);
        }

    }];
     
}


@end
