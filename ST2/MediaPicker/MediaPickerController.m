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
//  MediaPickerController
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

#import "MediaPickerController.h"
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

#import "MediaPickerWaterfallCell.h"
#import "MediaPickerWaterfallLayout.h"

#import "STLogging.h"

// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && vinnie_moscaritolo
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


static NSString * const WaterFallCellIdentifier = @"WaterFall";


@interface MediaPickerController ()

@property (nonatomic, strong) NSMutableArray *cellHeights;
@property (nonatomic, strong) MediaPickerWaterfallLayout* layout;


@end

@implementation MediaPickerController
{
    
    NSCache *cellHeightCache;
    
    UIImage*    defaultAudioImage;
    UIImage*    defaultVCardImage;
    NSInteger   cellWidth;
    
    
 }


#pragma mark - View Controller Lifecycle


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
    
}


- (void)viewDidLoad
{
    
    [super viewDidLoad];
    // Create our view
    
    // Create instances of our layouts
    
     [self.collectionView registerClass:[MediaPickerWaterfallCell class]
            forCellWithReuseIdentifier:WaterFallCellIdentifier];
    
//    self.navigationController.navigationBar.barStyle =  UIBarStyleBlack;
//    self.navigationController.navigationBar.translucent  = YES;
    
    self.view.backgroundColor =  [UIColor clearColor];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"Back")
																			 style:UIBarButtonItemStylePlain
                                                                            target:self action:@selector(goBack)];
   self.navigationItem.title = @"";
 
    _layout = [[MediaPickerWaterfallLayout alloc] init];
    
    [self.collectionView setCollectionViewLayout:_layout animated:NO];
  
  }



-(void) setupAlbumLayout:(UIInterfaceOrientation)toInterfaceOrientation
{
    if([AppConstants isIPad])
    {
        cellWidth  = 100;
        
        if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
        {
            _layout.columnCount = 9;
            _layout.itemWidth = cellWidth;
            _layout.sectionInset = UIEdgeInsetsMake(9, 9, 9, 9);
            
        }
        else
        {
            _layout.columnCount = 7;
            _layout.itemWidth = cellWidth;
            _layout.sectionInset = UIEdgeInsetsMake(9, 9, 9, 9);
            
        }
    }
    else
    {
        cellWidth  = 80;
        
        if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
        {
            _layout.columnCount = 5;
            _layout.itemWidth = cellWidth;
            _layout.sectionInset = UIEdgeInsetsMake(9, 9, 9, 9);
            
        }
        else
        {
            _layout.columnCount = 3;
            _layout.itemWidth = cellWidth;
            _layout.sectionInset = UIEdgeInsetsMake(9, 9, 9, 9);
            
        }
        
    }
    
    _layout.delegate = self;
    UIEdgeInsets edgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    self.collectionView.contentInset = edgeInsets;
    self.collectionView.scrollIndicatorInsets = edgeInsets;
    
    [self handleTranslucentNavBar];
}


#pragma mark - View Controller Lifecycle
-(void)viewWillAppear:(BOOL)animated
{
    [self handleTranslucentNavBar];
    [self setupAlbumLayout:self.interfaceOrientation];
 }

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self handleTranslucentNavBar];
    
    self.navigationItem.title =  _album?_album.name:@"";
    
    
    // Setup Gesture Recognizers
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    [self.collectionView addGestureRecognizer:pinch];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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


- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration
{
    
    [self setupAlbumLayout:toInterfaceOrientation];
 }

#pragma mark - UICollectionViewDataSource


-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    NSInteger count   = 1;
  
    return count;

}

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section;
{
    
    NSInteger count = 0;
    
    count = _album? _album.numberOfItemsAvailable: 0;
    
    if(_album && (_album.items.count < _album.numberOfItemsAvailable))
    {
        dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            [_album.mediaDataSource loadAlbum:_album
                             withRangeofItems: NSMakeRange(_album.items.count, _album.numberOfItemsAvailable)
                                   errorBlock:^(NSError *error) {
                                       if (!error)
                                           
                                           dispatch_async(dispatch_get_main_queue(), ^(void) {
                                               [self.collectionView reloadData];
                                           });
                                   }];
            
        });
    }
    
    
    return count;
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
     MediaPickerWaterfallCell *cell =
    (MediaPickerWaterfallCell *)[collectionView dequeueReusableCellWithReuseIdentifier:WaterFallCellIdentifier
                                                                          forIndexPath:indexPath];
    
    if(_album)
    {
        if(indexPath.item < _album.items.count)
        {
            MediaItem* item = [_album.items objectAtIndex:indexPath.item];
            
            //              DDLogBrown(@"%2d:%2d %@ %@", indexPath.section, indexPath.item, album.name,  item.name);
            cell.image = item.thumbNail;
        }
    }
    
    
    return cell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self.collectionView deselectItemAtIndexPath:indexPath animated:NO];
   
    
    // do selection here..
}


-(void)goBack
{

    [self.navigationController popToRootViewControllerAnimated:YES];
    
//    self.navigationItem.leftBarButtonItem =  STAppDelegate.settingsButton;
        
    
}


#pragma mark - MediaPickerWaterfallLayoutDelagate

- (CGFloat)   collectionView:(UICollectionView *)collectionView
                      layout:(MediaPickerWaterfallLayout *)collectionViewLayout
    heightForItemAtIndexPath:(NSIndexPath *)indexPath

{
    __block float cellHeight = 40;
    
    if(_album)
    {
        if(indexPath.item < _album.items.count)
        {
            MediaItem* item = [_album.items objectAtIndex:indexPath.item];
            
            //            NSNumber *cachedCellHeight = [cellHeightCache objectForKey:scl.uuid];
            //            if (cachedCellHeight)
            //            {
            //                cellHeight = [cachedCellHeight floatValue];
            //            }
            //            else
            {
                float oldWidth = cellWidth;
                UIImage* thumbnail = item.thumbNail;
                
                if(thumbnail)
                {
                    cellHeight = thumbnail.size.height;
                    oldWidth  = thumbnail.size.width;
                }
                else
                    
                    if(item.mediaType)
                    {
                        if(UTTypeConformsTo( (__bridge CFStringRef)item.mediaType, kUTTypeAudio))
                        {
                            cellHeight = defaultAudioImage.size.height;
                            oldWidth  = defaultAudioImage.size.width;
                            
                        }
                        
                        else if(UTTypeConformsTo( (__bridge CFStringRef)item.mediaType, kUTTypeVCard))
                        {
                            cellHeight = 94.;
                            
                        }
                        
                    }
                
                float scaleFactor = cellWidth / oldWidth;
                
                cellHeight = cellHeight * scaleFactor;
                
                //                [cellHeightCache setObject:@(cellHeight) forKey:scl.uuid];
                
            }
        }

      }
    
    
    return cellHeight;
}

#pragma mark - UIGestureRecognizer Code

-(void)handlePinch:(UIPinchGestureRecognizer *)recognizer
{
    
 
};

#pragma mark - data model

@end
