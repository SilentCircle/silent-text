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
#import <CoreLocation/CoreLocation.h>


typedef enum
{
    kMediaAlbum_Invalid            = 0,
    kMediaAlbum_PhotoAlbum,
    kMediaAlbum_iTunesFolder,
    kMediaAlbum_sCloud,
}MediaAlbumType;

@class MediaAlbum;

typedef void (^MediaDataSourceLoadCompletionBlock)(NSArray *albums);
typedef void (^MediaDataSourceAlbumLoadedBlock)(MediaAlbum*  album);
typedef void (^MediaDataSourceErrorBlock)(NSError *error);

@protocol MediaAlbumDataSourceDelegate

@required

-(void)loadAlbumWithPhotos:(NSUInteger)count
                completion:(MediaDataSourceLoadCompletionBlock)completionBlock
               loadedBlock:(MediaDataSourceAlbumLoadedBlock)albumLoadedBlock
                errorBlock:(MediaDataSourceErrorBlock)errorBlock;

-(void)loadAlbum:(MediaAlbum*)album withRangeofItems:(NSRange)range
                errorBlock:(MediaDataSourceErrorBlock)errorBlock;

@end



@interface MediaItem : NSObject
@property(nonatomic, strong) NSString       *mediaID;
@property(nonatomic, strong) NSString       *mediaType;
@property(nonatomic, strong) UIImage        *thumbNail;

@property(nonatomic, strong) NSDictionary   *metadata;
@property(nonatomic, strong) NSURL          *url;
@property(nonatomic, strong) NSString       *name;

@end



@interface MediaAlbum : NSObject
@property(nonatomic)         MediaAlbumType albumType;
@property(atomic, strong)   id <MediaAlbumDataSourceDelegate> mediaDataSource;
@property(nonatomic, strong) NSString       *albumID;
@property(nonatomic, strong) NSString       *name;
@property(nonatomic, strong) NSURL          *url;
@property(nonatomic, strong) NSDate         *date;
@property(nonatomic, strong) UIImage        *posterImage;
@property(nonatomic, strong) NSMutableArray *items;
@property(nonatomic )        NSInteger      numberOfItemsAvailable;

@end

