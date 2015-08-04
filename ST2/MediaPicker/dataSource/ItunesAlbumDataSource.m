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

#import "ItunesDataSource.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreLocation/CoreLocation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import "ALAsset+SCUtilities.h"
#import "SCloudObject.h"
#import "NSDate+SCDate.h"
#import "STLogging.h"
#import "NSURL+SCUtilities.h"
#import <ImageIO/ImageIO.h>
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


@interface ItunesDataSource()
@end

@implementation ItunesDataSource


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
    
    album.name = @"iTunes";
    album.url = documents;
    album.posterImage =  [UIImage imageNamed:@"itunes-folder"];
    album.albumType = kMediaAlbum_iTunesFolder;
    
    [albums addObject:album];

    if(photos2Load > 0)
    {
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager]
                                             enumeratorAtURL:documents
                                             includingPropertiesForKeys:@[NSURLNameKey,
                                                                          NSURLIsDirectoryKey,
                                                                          NSURLCreationDateKey,
                                                                          NSURLEffectiveIconKey,
                                                                          NSURLFileResourceTypeKey
                                                                          ]
                                             options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                             | NSDirectoryEnumerationSkipsPackageDescendants
                                             | NSDirectoryEnumerationSkipsHiddenFiles
                                             
                                             errorHandler:^(NSURL *url, NSError *error) {
                                                 // Handle the error.
                                                 // Return YES if the enumeration should continue after the error.
                                                 return YES;
                                             }];
        
        
        
        for (NSURL *url in enumerator)
        {
            NSDictionary* values =  [url resourceValuesForKeys: @[NSURLNameKey,
                                                                  NSURLIsDirectoryKey,
                                                                  NSURLCreationDateKey,
                                                                  NSURLEffectiveIconKey,
                                                                  NSURLFileResourceTypeKey
                                                                  ]
                                                         error:NULL];
            
            if(![[values objectForKey:NSURLIsDirectoryKey] boolValue] )
            {
                
                //         DDLogBlue(@"--> %@ : %@", [values objectForKey:NSURLNameKey], url.mediaType);
                
                if(OSAtomicIncrement32(&count) <= photos2Load)
                {
                    
                    NSMutableDictionary* metaDict = [NSMutableDictionary dictionary];
                    
                    NSString * mediaType = url.mediaType;
                    NSString  *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef) mediaType, kUTTagClassMIMEType);
                    NSDate *date = [values objectForKey:NSURLCreationDateKey];
                    NSString *fileName = [values objectForKey:NSURLNameKey];
                    
                    [metaDict setObject:mediaType forKey: kSCloudMetaData_MediaType];
                    [metaDict setObject: fileName forKey:kSCloudMetaData_FileName];
                    
                    if(mimeType)
                        [metaDict setObject: mimeType forKey:kSCloudMetaData_MimeType];
                    
                    if(date)
                        [metaDict setObject: [date rfc3339String] forKey:kSCloudMetaData_Date];
                    
                    
                    if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeImage))
                    {
                        CGImageSourceRef  sourceRef;
                        
                        //set the cg source references to the image by passign its url path
                        sourceRef = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
                        
                        //set a dictionary with the image metadata from the source reference
                        NSDictionary* imageMeta = (__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(sourceRef,0,NULL);
                        
                        [imageMeta filterEntriesFromMetaDataTo:metaDict ];
                    }
                    
                    MediaItem *item = [[MediaItem alloc] init];
                    item.mediaID =  url.description;
                    item.mediaType = mediaType;
                    item.metadata = metaDict;
                    item.url = url.copy;
                    item.thumbNail = url.thumbNail;
                    item.name = fileName;
                    
                    [album.items addObject:item];
                    
                    if(!posterImageChosen && item.thumbNail)
                    {
                        album.posterImage = item.thumbNail;
                        posterImageChosen = YES;
                    }
                }
            }
            
        }
        
        album.numberOfItemsAvailable = count;
        
        if (albumLoadedBlock != nil) {
            (albumLoadedBlock) (album);
        }
        
        if (completionBlock != nil) {
            (completionBlock)(albums);
        }
        
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


-(void)loadAlbum:(MediaAlbum*)album withRangeofItems:(NSRange)range
      errorBlock:(MediaDataSourceErrorBlock)errorBlock
{
    if (errorBlock != nil) {
        (errorBlock)(NULL);
    }
    
}


@end
