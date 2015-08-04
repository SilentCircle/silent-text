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
//  MediaAlbumPickerController
//  ST2
//
//  Created by Vinnie Moscaritolo on 9/27/13.
//
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import "ALAsset+SCUtilities.h"

#import "MediaAlbumPickerController.h"
#import "AppDelegate.h"
#import "AppConstants.h"

#import "STSCloud.h"
#import "STMessage.h"

#import "SCloudPreviewer.h"
#import "STPreferences.h"

#import "PhotoAlbumDataSource.h"
#import "ItunesDataSource.h"
#import "SCloudDataSource.h"

#import "MediaPickerPhotoAlbumLayout.h"
#import "MediaPickerAlbumPhotoCell.h"
#import "MediaPickerAlbumTitleReusableView.h"

#import "MediaPickerController.h"

#import "STLogging.h"

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

static NSString * const AlbumCellIdentifier = @"AlbumCell";
static NSString * const AlbumTitleIdentifier = @"AlbumTitle";


@implementation MediaAlbumPickerController
{
//	NSMutableArray *_cellHeights;
	
	NSMutableArray *_mediaAlbums;
	NSArray        *_mediaSources;
	
	MediaPickerPhotoAlbumLayout *_stackLayout;
}

#pragma mark View Controller Lifecycle

- (id)init
{
    self = [super init];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (id)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
    self = [super initWithCollectionViewLayout:layout];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (id)initWithProperNib
{
	return [self initWithNibName:@"MediaAlbumPickerController" bundle:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
	DDLogAutoTrace();
}

- (void)dealloc
{
	DDLogAutoTrace();
}

#pragma mark View Controller Lifecycle

- (void)viewDidLoad
{
	DDLogAutoTrace();
    [super viewDidLoad];
	
    // Create our view
    _mediaAlbums = [NSMutableArray array];
    
    _mediaSources = @[[[PhotoAlbumDataSource alloc]init],
                      [[ItunesDataSource alloc] init],
                       [[SCloudDataSource alloc] init]
                     ];
    
    // Create instances of our layouts
    [self.collectionView registerClass:[MediaPickerAlbumPhotoCell class]
            forCellWithReuseIdentifier:AlbumCellIdentifier];
    
    [self.collectionView registerClass:[MediaPickerAlbumTitleReusableView class]
            forSupplementaryViewOfKind:MediaPickerPhotoAlbumLayoutAlbumTitleKind
                   withReuseIdentifier:AlbumTitleIdentifier];
    
    
//    self.navigationController.navigationBar.barStyle =  UIBarStyleBlack;
//    self.navigationController.navigationBar.translucent  = YES;
    
    self.view.backgroundColor = [UIColor clearColor];
    
    self.navigationItem.leftBarButtonItem = STAppDelegate.settingsButton;
    self.navigationItem.title = @"Media Selector test";
    
    _stackLayout = [[MediaPickerPhotoAlbumLayout alloc] init];

    [self.collectionView setCollectionViewLayout:_stackLayout animated:NO];
    
    [self reloadAlbums];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
	
    [self handleTranslucentNavBar];
    [self setupAlbumLayout:self.interfaceOrientation];
}

- (void)viewDidAppear:(BOOL)animated
{
	DDLogAutoTrace();
    [super viewDidAppear:animated];
	
    [self handleTranslucentNavBar];
      
    // Setup Gesture Recognizers
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    [self.collectionView addGestureRecognizer:pinch];
}

#pragma mark Rotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration
{
	[self setupAlbumLayout:toInterfaceOrientation];
}

#pragma mark Utilities

-(void) setupAlbumLayout:(UIInterfaceOrientation)toInterfaceOrientation
{
    
    if([AppConstants isIPad])
    {
        _stackLayout.itemSize = CGSizeMake(200.0f, 200.0f);
        
        if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
        {
            _stackLayout.numberOfColumns = 4;
            _stackLayout.itemInsets = UIEdgeInsetsMake(22.0f, 22.0f, 13.0f, 22.0f);
            
        }
        else
        {
            _stackLayout.numberOfColumns = 3;
            _stackLayout.itemInsets = UIEdgeInsetsMake(22.0f, 22.0f, 13.0f, 22.0f);
            
        }
        
    }
    else
    {
        _stackLayout.itemSize = CGSizeMake(125.0f, 125.0f);
        
        if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
            _stackLayout.numberOfColumns = 3;
            
            // handle insets for iPhone 4 or 5
            CGFloat sideInset = [UIScreen mainScreen].preferredMode.size.width == 1136.0f ?
            45.0f : 25.0f;
            
            _stackLayout.itemInsets = UIEdgeInsetsMake(22.0f, sideInset, 13.0f, sideInset);
            
        } else {
            _stackLayout.numberOfColumns = 2;
            _stackLayout.itemInsets = UIEdgeInsetsMake(22.0f, 22.0f, 13.0f, 22.0f);
        }
        
    }
    UIEdgeInsets edgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    self.collectionView.contentInset = edgeInsets;
    self.collectionView.scrollIndicatorInsets = edgeInsets;
    
    
    [self handleTranslucentNavBar];
    
}

- (void) handleTranslucentNavBar
{
    
    
    CGSize statusbarsize = [UIApplication sharedApplication].statusBarFrame.size;
    CGFloat top = self.navigationController.navigationBar.frame.size.height + MIN(statusbarsize.height, statusbarsize.width);
    CGFloat bottom = 0;
    
    UIEdgeInsets edgeInsets = UIEdgeInsetsMake(top, 0, bottom, 0);
    self.collectionView.contentInset = edgeInsets;
    self.collectionView.scrollIndicatorInsets = edgeInsets;
	
}

#pragma mark UICollectionViewDataSource

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    NSInteger count = 0;
    
    count =  _mediaAlbums.count;
        
    return count;

}

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section;
{
    
    NSInteger count = 0;
    
    if(section < _mediaAlbums.count)
    {
        MediaAlbum* album = [_mediaAlbums objectAtIndex:section];
        count = album.items.count;
    }
    
    return count;
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
    UICollectionViewCell* cell = NULL;
    
    
    MediaPickerAlbumPhotoCell *albumCell =
    [collectionView dequeueReusableCellWithReuseIdentifier:AlbumCellIdentifier
                                              forIndexPath:indexPath];
    
    if(indexPath.section < _mediaAlbums.count)
    {
        MediaAlbum* album = [_mediaAlbums objectAtIndex:indexPath.section];
        
        if(indexPath.item < album.items.count)
        {
            MediaItem* item = [album.items objectAtIndex:indexPath.item];
            
            //              DDLogBrown(@"%2d:%2d %@ %@", indexPath.section, indexPath.item, album.name,  item.name);
            UIImage* thumbnail = item.thumbNail;
            albumCell.imageView.image =  thumbnail;
        }
    }
    
    cell = albumCell;
    
    
    
    return cell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self.collectionView deselectItemAtIndexPath:indexPath animated:NO];
    
    MediaAlbum* album = [_mediaAlbums objectAtIndex:indexPath.section];
    
    
    MediaPickerController* svc  = [[MediaPickerController alloc] initWithNibName:@"MediaPickerController" bundle:nil];
    svc.album = album;
    
    [self.navigationController pushViewController:svc animated:YES];
}


- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath;
{
     
    MediaPickerAlbumTitleReusableView *titleView =
    [collectionView dequeueReusableSupplementaryViewOfKind:kind
                                       withReuseIdentifier:AlbumTitleIdentifier
                                              forIndexPath:indexPath];
    
 
    
    MediaAlbum* album = [_mediaAlbums objectAtIndex:indexPath.section];
    
    titleView.titleLabel.text = album.name;
    
    return titleView;
}


#pragma mark UIGestureRecognizer Code

-(void)handlePinch:(UIPinchGestureRecognizer *)recognizer
{
    
 
}

#pragma mark Data Model

- (void)reloadAlbums
{
    NSUInteger maxPhotos = 4;
	dispatch_queue_t defaultQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	[_mediaAlbums removeAllObjects];
	
	for (id<MediaAlbumDataSourceDelegate> mediaSource in _mediaSources)
	{
		dispatch_async(defaultQueue, ^{ @autoreleasepool {
			
			[mediaSource loadAlbumWithPhotos:maxPhotos completion:^(NSArray *albums) {
                                      
//				dispatch_async(dispatch_get_main_queue(), ^(void) {
//					[self.collectionView reloadData];
//				});
				
			} loadedBlock:^(MediaAlbum *album) {
				
			//	DDLogMagenta(@"Load Album %@, %d Photos", album.name , album.items.count);
				
				// We must be on the main thread in order to:
				//
				// - alter the thread-unsafe mutable array (_mediaAlbums)
				// - update the UI (reloadData)
				
				dispatch_block_t block = ^{
					
					[_mediaAlbums addObject:album];
					[self.collectionView reloadData];
				};
				
				if (album.items.count > 0)
				{
					if ([NSThread isMainThread])
						block();
					else
						dispatch_async(dispatch_get_main_queue(), block);
				}
				
			} errorBlock:^(NSError *error) {
				
				DDLogMagenta(@"Error %@",error.description );
			}];
            
        }});
    }
}

@end
