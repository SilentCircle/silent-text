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
#import "SCloudPreviewer.h"

#import "AppDelegate.h"
#import "AppConstants.h"
#import "FYEOViewController.h"
#import "MBProgressHUD.h"
#import "QLItem.h"
#import "SCFileManager.h"
#import "SCloudManager.h"
#import "SCloudObject.h"
#import "SCloudPreviewer.h"
#import "SCloudPreviewerErrorView.h"
#import "Siren.h"
#import "STLogging.h"
#import "STMessage.h"
#import "STPreferences.h"
#import "STSCloud.h"
#import "YapCollectionKey.h"

// Categories
#import "NSURL+SCUtilities.h"
#import "UIImage+ImageEffects.h"
#import "UIImage+Thumbnail.h"

// Libraries
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <MobileCoreServices/UTCoreTypes.h>

// LEVELS: off, error, warn, info, verbose;
// FLAGS : trace
#if DEBUG && vinnie_moscaritolo
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


@implementation SCloudPreviewer
{
    QLPreviewController* pvc;
    MBProgressHUD*   HUD;
    
    YapCollectionKey*       currentIdentifier;
    
    NSMutableArray*         items;
    NSString*               currentSCloudID;
    
    SCloudPreviewerCompletionBlock  completeBlock;
    //ET 11/18/14 
    // rename to presentingVC to disambiguate from 
    // QLPreviewControllerDelegate callback parameters
//    UIViewController                *controller;
    UIViewController                *presentingVC;
    NSString                        *groupID;
    
    QLItem                          *notfoundItem;
    
    //ET 11/13/14
    __weak UIView *_hudContainerView;
    BOOL _presentationCanceled;
    //ET 11/19/14 - UNUSED: stopped to flip project switch to globalWorkspace
    NSInteger _indexofItemToPreview;
 }



- (id)init
{
	if ((self = [super init]))
	{
        
        notfoundItem = [[QLItem alloc]initWithSCloudID:@""];
        notfoundItem.url =  [NSURL fileURLWithPath: [[NSBundle mainBundle]  pathForResource:@"poof0" ofType:@"png"]];
        notfoundItem.title = [NSString stringWithFormat:@"item not downloaded"];
        //ET 11/19/14 - UNUSED: stopped to flip project switch to globalWorkspace
        _indexofItemToPreview = -1;
    }
    
    return self;
    
}

-(void) commonShutdown
{
    [[NSNotificationCenter defaultCenter]  removeObserver:self];
    
    currentIdentifier = NULL;
    
    if(HUD)
    {
        [HUD show:NO];
        [HUD removeFromSuperview];
        HUD = NULL;
    }
    
    for(QLItem* item in items)
    {
      if(item.url )
      {
          item.scloud = NULL;
          item.scl = NULL;
          [ NSFileManager.defaultManager removeItemAtURL: item.url error:NULL];

      }
    }
    
    pvc= NULL;
    items = NULL;
   
}

///////////////////////
#pragma warning  CODE TO  UPDATE THE STscloud thumbnail to hiRez

- (void)updateThumbNail:(UIImage *)image forSCloud:(STSCloud *)sclIn
{
	if (image == nil) {
		DDLogWarn(@"Method %@ invoked with nil image", THIS_METHOD);
		return;
	}
	
//    // add in duration annotation for movies
//    if( UTTypeConformsTo( (__bridge CFStringRef)sclIn.mediaType, kUTTypeMovie) )
//	{
//        NSString* duration =  [sclIn.metaData objectForKey: kSCloudMetaData_Duration]?:NULL;
//        
//        if(duration)
//        {
//            NSDateFormatter* durationFormatter = [[NSDateFormatter alloc] init] ;
//            [durationFormatter setDateFormat:@"mm:ss"];
//            
//            NSString* overlayText = [durationFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: duration.doubleValue]];
//            image = [image imageWithBadgeOverlay:[UIImage imageNamed:@"movie.png"] text:overlayText textColor:[UIColor whiteColor]];
//         }
//    }
//    
	sclIn.thumbnail = image;
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		YapDatabaseRelationshipTransaction *graph = [transaction ext:Ext_Relationship];
		
		[graph enumerateEdgesWithName:@"scloud"
		               destinationKey:sclIn.uuid
		                   collection:kSCCollection_STSCloud
		                   usingBlock:^(YapDatabaseRelationshipEdge *edge, BOOL *stop)
		{
			// edge.source represents the STMessage.
			// We could fetch the message (if we needed) like this:
			//
			// STMessage *message = [graph sourceNodeForEdge:edge];
			
			// touch the message
			[transaction touchObjectForKey:edge.sourceKey inCollection:edge.sourceCollection];
		}];
		
		// touch the scloud item
		[transaction touchObjectForKey:sclIn.uuid inCollection:kSCCollection_STSCloud];
	}];
}
    /////////////////////


- (void)scloudOperation:(NSNotification *)notification
{
    
    NSDictionary *userInfo = notification.userInfo;
    
    YapCollectionKey* identifier = [userInfo objectForKey:@"identifier"];
    NSString* status = [userInfo objectForKey:@"status"];
    
    if([identifier  isEqual:currentIdentifier])
    {
        if([status isEqualToString:NOTIFICATION_SCLOUD_DOWNLOAD_START])
        {
            
        }
        else if([status isEqualToString:NOTIFICATION_SCLOUD_DOWNLOAD_PROGRESS])
        {
            NSNumber* progress = [userInfo objectForKey:@"progress"];
            
            HUD.progress = progress.floatValue;
        }
        
        else if([status isEqualToString:NOTIFICATION_SCLOUD_DOWNLOAD_COMPLETE])
        {
            
        }
        
    }

 }

#pragma mark - STScloud operations
- (void) updateViewDateForItem: (QLItem*)item
{
    __block STSCloud* scl = NULL;
    
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
    [rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
        
        if(item &&  item.scl)
        {
            scl = item.scl.copy;
            scl.unCacheDate = [[NSDate date] dateByAddingTimeInterval:[STPreferences scloudCacheLifespan]];
            
            [transaction setObject:scl
                            forKey:scl.uuid
                      inCollection:kSCCollection_STSCloud];
            
        }
       
    }  completionBlock:^{
        if(scl)
            item.scl = scl;
    }];
 }

#pragma mark - display

-(void) decryptAndUpdateItem:(QLItem*)item withError:(NSError**)error
{
    [item.scloud decryptCachedFileUsingKeyString: item.scl.keyString withError:error];
   
    if(!*error)
    {
        item.url = item.scloud.decryptedFileURL? item.scloud.decryptedFileURL.fileReferenceURL:NULL;
        
        if(!item.title)
        {
            item.title = [[[item.scloud.decryptedFileURL absoluteString]lastPathComponent] stringByDeletingPathExtension];
        }
        
        // update scloud thumbnail
        if(!item.scl.thumbnail)
        {
            UIImage* image = [ item.url hiRezThumbnail];
            if(image)
            {
                [self updateThumbNail:image forSCloud:item.scl];
            }
        }
    
    }
    
}

-(void) createThumbnailPageWith:(QLItem*)item withError:(NSError**)error
{
    SCloudPreviewerErrorView * ev = [[SCloudPreviewerErrorView alloc]initWithFrame: presentingVC.view.frame ];
    
    UIImage* thumbnail = item.scl.lowRezThumbnail;
    
    ev.thumbnail.image =  thumbnail ;
    ev.pageTitle.text  = NSLocalizedString(@"Not Loaded", @"Not Loaded");
    ev.fileName.text  =  item.scl.displayname;
    ev.errorMessage.text = NSLocalizedString(@"Only the preview of this file has been downloaded. Go back to the conversation to tap and download.", @"Only the preview of this file has been downloaded. Go back to the conversation to tap and download.");
       
    NSData* pData = UIImagePNGRepresentation(ev.capture);
	
	NSString *uuid = [[NSUUID UUID] UUIDString];
	NSURL *baseURL = [[SCFileManager mediaCacheDirectoryURL] URLByAppendingPathComponent:uuid];
	NSURL *url = [baseURL URLByAppendingPathExtension:@"png"];
    
    item.title = NSLocalizedString(@"File Not Loaded", @"File Not Loaded");
    item.url = url;
    item.placeholder = YES;
    
    [pData writeToURL:url  atomically:YES];
    
    
//    *error = [STAppDelegate otherError:@"segents missing"];
    
}


-(NSRange) calculateCachedItemRange:(NSString*)scloudID itemList:(NSArray*) itemList
{
    NSRange cachedIndexRange = {0,2};
    NSUInteger index  = 0;
    
    NSUInteger maxItems = itemList.count;
    
    for(QLItem* item in itemList)
    {
        if([item.scloudID isEqualToString:scloudID])
        {
            if(index == 0)
            {
                cachedIndexRange.location = 0;
                cachedIndexRange.length = index == maxItems-1?1:2;
            }
            else if(index == maxItems -1)
            {
                cachedIndexRange.location = index -1;
                cachedIndexRange.length = 2;
                
            }
            else
            {
                cachedIndexRange.location = index -1;
                cachedIndexRange.length = 3;
            }
            break;
        }
        
        index++;
    }
    
    return cachedIndexRange;
}

-(void) downloadItems:(NSMutableArray*)itemDictArray completionBlock:(SCloudPreviewerCompletionBlock)completionBlockIn
{
    __block NSError* dowloadError = NULL;
    
    DDLogRed(@"need to download %lu items ", (unsigned long)itemDictArray.count);
    
    HUD.mode = MBProgressHUDModeAnnularDeterminate;
    HUD.labelText = [NSString stringWithFormat:NSLocalizedString(@"downloading", @"downloading")];
    [HUD show:YES];

    
    [HUD showAnimated:YES whileExecutingBlock:^{
        
        for(NSDictionary* dict in itemDictArray)
        {
            QLItem* item =  [items objectAtIndex:[[dict objectForKey:@"index"] integerValue ]];
      
            currentIdentifier = [[YapCollectionKey alloc] initWithCollection:self.description 
                                                                         key:item.scloud.locatorString];
            
            [[SCloudManager sharedInstance] startDownloadWithScloud:item.scloud
                                                       fullDownload:YES
                                                         identifier:currentIdentifier
                                                    completionBlock:^(NSError *error, NSDictionary *infoDict)
			{
				[itemDictArray removeObject:dict];
				
				if (error && !dowloadError)
				{
					dowloadError = error.copy;
				}
			}];
        }
        
        while (itemDictArray.count)
        {
			// What ? Why ?!?
            usleep(.1);
        }
        
    } completionBlock:^{
        
        [HUD show:NO];
        
        if(completionBlockIn)  (completionBlockIn)(dowloadError);
        
    }];
}


#pragma mark - displaySCloud
/*
 
 displaySCloud  depends on Apple's QLPreviewController to display content.
 this is a tradeoff with the devil. The QLPreviewController can handle many kinds of
 data, but it is has many limitations and issues.  On IOS 6+  QuickLooks
 runs in another process using XPC (they call it remote view).
  see http://oleb.net/blog/2012/10/remote-view-controllers-in-ios-6/
 
  we can nolonger subclass it to control how the next/back buttons work.
 
 what we can do is try and precache the items it might want to see.  THis
 can be expensive, if the items are large or if they havent been downloaded yet.
 
 so what we do is to download only the item you asked for, and in the case that
 the adjecent items are already downloaded we will decypt them into the MediaCache.
 
 if you move the next/back to items that we havent decypted yet, (the item.url is NULL)
 we will decrypt if possible, else we create a error placeholder png file that 
 we show in place of the item..
 
 let me know if you have a better idea.
 - Anonymous
 */

- (void)displaySCloud:(NSString *)scloudID
                 fyeo:(BOOL)fyeo
            fromGroup:(NSString *)groupIn
       withController:(UIViewController *)InController
               inView:(UIView *)inView
      completionBlock:(SCloudPreviewerCompletionBlock)completionIn
{
    completeBlock = completionIn;
    groupID = groupIn;
    presentingVC = InController;
    currentSCloudID = scloudID;
    
    
    DDLogRed(@"Display %@ ", scloudID);
    
    HUD = [[MBProgressHUD alloc] initWithView:inView];
    [inView addSubview:HUD];
    HUD.delegate = self;
    
	__block  NSArray* sclList =  [NSArray array];
    __block NSError * error;
    __block BOOL hasFYEO = fyeo;
    __block NSUInteger indexofItemToPreview;
    
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
         YapDatabaseConnection *roDatabaseConnection = STDatabaseManager.roDatabaseConnection;
        [roDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction*transaction){
            
            if(groupIn)
            {
                
                NSMutableSet* sclSet = [NSMutableSet set];
                
                // always insure that the ScloudID that we were asked to display is in the set of items previewed.
                // Vin 4/20/15
                [sclSet addObject:scloudID];
                
                NSUInteger count = [[transaction ext:Ext_View_HasScloud] numberOfItemsInGroup:groupID];
                
                for(NSUInteger index = 0; index < count; index++)
                {
                    STMessage* msg =  [[transaction ext:Ext_View_HasScloud] objectAtIndex:index inGroup:groupID];
                   	NSAssert(msg != nil, @"Database returned nil item for view");
                    
                    // since we handle some of these media kinds ourselves, exclude them from the preview
                    NSString* mediaType = msg.siren.mediaType;
                    if( UTTypeConformsTo( (__bridge CFStringRef)mediaType, kUTTypeAudio)
                        || UTTypeConformsTo( (__bridge CFStringRef)mediaType, kUTTypeVCard)
                       || UTTypeConformsTo( (__bridge CFStringRef)mediaType, (__bridge CFStringRef)@"public.calendar-event"))
                        continue;
                        
                    [sclSet addObject:msg.scloudID];
                }
                sclList = sclSet.allObjects;
            }
            else
            {
                sclList = @[scloudID];
            }
            
            items = [@[] mutableCopy];
            
            for(NSString* sclID in sclList)
            {
                __block STSCloud *scl = NULL;
                
                scl = [transaction objectForKey:sclID inCollection:kSCCollection_STSCloud];
                
                if(!scl)
                {
                    if([scloudID isEqualToString:sclID])
                    {
                        error = [STAppDelegate otherError:@"scloud object not found"];
                        break;
                    }
                }
                else
                {
                    if( scl.isFyeo)
                    {
                        if( ![scloudID isEqualToString:sclID]) continue;
                        
                        hasFYEO = YES;
                    }
                    
                    SCloudObject* scloud = [[SCloudObject alloc]  initWithLocatorString:scl.uuid
                                                                              keyString:scl.keyString
                                                                                   fyeo:scl.fyeo];
                    if(scloud)
                    {
                        scloud.scloudDelegate  = self;
                        
                        QLItem* item = [[QLItem alloc]initWithSCloudID:sclID];
                        item.scl = scl;
                        item.scloud = scloud;
                        
                        NSString* displayName =  [scl.metaData objectForKey:kSCloudMetaData_DisplayName];
                        
                        if(!displayName)
                        {
                            displayName = [scl.metaData objectForKey:kSCloudMetaData_FileName];
                            if(displayName)
                                displayName = [displayName stringByDeletingPathExtension];
                        }
                        
                        if(displayName)
                            item.title = displayName;
                        
                        [items addObject:item];
                        
                    }
                    
                }
                
            }
            
        }];
        
        if(error)
        {
			if (completeBlock) {
				completeBlock(error);
				completeBlock = NULL; // release block to prevent retain cycle
			}
            return;
        }
        
        if(!items.count)
        {
			if (completeBlock) {
				completeBlock([STAppDelegate otherError:@"No items in database"]);
				completeBlock = NULL; // release block to prevent retain cycle
			}
            return;
        }
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(scloudOperation:)
                                                     name:NOTIFICATION_SCLOUD_OPERATION
                                                   object:nil];
        
        
        pvc = [[QLPreviewController alloc] init];
        
        pvc.dataSource = self;
        pvc.delegate   = self;
        
        
        // precache items for preview controller
        NSRange cachedIndexRange = [self calculateCachedItemRange:scloudID itemList:items];
        
        NSMutableArray* indexOfItemsNeedingDownload = [NSMutableArray array];
        
        for(NSUInteger index = cachedIndexRange.location;
            index < cachedIndexRange.location + cachedIndexRange.length;
            ++index)
        {
            QLItem* item =  [items objectAtIndex:index];
            
            if([item.scloudID isEqualToString:currentSCloudID])
            {
                indexofItemToPreview = index;
                
            }
            
            if ( [item.scloudID isEqualToString:currentSCloudID]  // only download what you asked for explicitly
                && (item.scl.missingSegments.count > 0))
            {
                NSUInteger  fileSize = item.scl && item.scl.metaData && [item.scl.metaData objectForKey:kSCloudMetaData_FileSize]
                ? [[item.scl.metaData objectForKey:kSCloudMetaData_FileSize] unsignedIntegerValue ]
                :0;
                
                [indexOfItemsNeedingDownload addObject: @{ @"uuid":item.scloudID,
                                                           @"bytes":@(fileSize),
                                                           @"index":@(index)}];
            }
            else
            {
                [self decryptAndUpdateItem:item withError:&error];
            }
            
        }
        
        if(indexOfItemsNeedingDownload.count > 0)
        {
            
            [self downloadItems:indexOfItemsNeedingDownload
                completionBlock:^(NSError *dowloadError) {
                    dispatch_async(dispatch_get_main_queue(), ^{

                    if(dowloadError)
                    {
						[self commonShutdown];
						
						if (completeBlock) {
							completeBlock(dowloadError);
							completeBlock = NULL; // release block to prevent retain cycle
						}
                    }
                    else
                    {
                        pvc.currentPreviewItemIndex = indexofItemToPreview;

						if (hasFYEO)
							[self displayWithFYEOviewer:pvc];
						else
                        {
							[presentingVC presentViewController:pvc animated:YES completion:NULL];
                            _hudContainerView = inView;
                        }                        
                    }
                     });
                }];
            
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                pvc.currentPreviewItemIndex = indexofItemToPreview;

                if(hasFYEO) 
                    [self displayWithFYEOviewer:pvc];
                else
                {
                    [presentingVC presentViewController:pvc animated:YES completion:NULL];
                    _hudContainerView = inView;
                }
            });
        }
        
    });
}

- (void)cancelPresentation {
    _presentationCanceled = YES;
}

-(void) displayWithFYEOviewer: (QLPreviewController *)previewController
{
    FYEOViewController * ev = [[FYEOViewController alloc] initWithDelegate:self
                                                                   qlItems:items];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:ev];
    
    [presentingVC presentViewController:navigationController animated:YES completion:NULL];
    
    CGSize statusBarSize = [UIApplication sharedApplication].statusBarFrame.size;
    CGFloat statusBarHeight = MIN(statusBarSize.height, statusBarSize.width);
    
    CGFloat navBarHeight = navigationController.navigationBar.frame.size.height;
    
    CGFloat offset = statusBarHeight + navBarHeight;

    //set the frame from the parent view
    CGFloat w= ev.view.frame.size.width;
    CGFloat h= ev.view.frame.size.height - offset;
    pvc.view.frame = CGRectMake(0, offset,w, h);
    
    [ev.view  addSubview:previewController.view];
    
    [previewController reloadData];
    [[previewController view]setNeedsLayout];
    [[previewController view ]setNeedsDisplay];
    [previewController refreshCurrentPreviewItem];
  }



#pragma mark -
#pragma mark SCloudObjectDelegate methods

- (void)scloudObject:(SCloudObject *)sender decryptingDidStart:(BOOL) foo
{
    
    HUD.mode = MBProgressHUDModeAnnularDeterminate;
    HUD.labelText = [NSString stringWithFormat:NSLocalizedString(@"decrypting", @"decrypting")];
    [HUD show:YES];

 	SCloudObject* s = sender;
 
 	DDLogMagenta(@"Decrypting %@", s.locatorString);
}

- (void)scloudObject:(SCloudObject *)sender decryptingProgress:(float) progress
{
//	SCloudObject* s = sender;
	
	HUD.progress = progress;
	
//	DDLogMagenta(@"Progress %@  %f" , s.locatorString, progress);
}

- (void)scloudObject:(SCloudObject *)sender decryptingDidCompleteWithError:(NSError *)error
{
 	SCloudObject* s = sender;
 
 	DDLogMagenta(@"Decrypting %@ complete", s.locatorString);
    
    DDLogMagenta(@"\n\\n\n --------- NOW LAUNCH THE PREVIEW CONTROLLER ------------- \n\n\n");
    
    [HUD show:NO];

}


#pragma mark - QLPreviewControllerDelegate

/*---------------------------------------------------------------------------
 *
 *--------------------------------------------------------------------------*/
- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller
{
	return items.count;
}

/*!
 * @abstract Invoked before the preview controller is closed.
 */
- (void)previewControllerWillDismiss:(QLPreviewController *)controller 
{
    DDLogOrange(@"%s called",__PRETTY_FUNCTION__);

    if (_hudContainerView)
    {
        // Make invisible. The calling VC completion block (MessagesVC) removes the subviews.
        //TEST - leave visible while testing layout in MessagesVC
        UIView *view = (_hudContainerView.superview) ? _hudContainerView.superview : _hudContainerView;
        view.alpha = 0.0f;
    }
}


/*---------------------------------------------------------------------------
 *
 *--------------------------------------------------------------------------*/
- (void)previewControllerDidDismiss:(QLPreviewController *)controller
{
    [self commonShutdown];
    
	if (completeBlock) {
		completeBlock(NULL);
		completeBlock = NULL; // release block to prevent retain cycle
	}
}


/*!
 * @abstract Invoked when the preview controller is about to be presented full screen or dismissed from full screen,
 * to provide a zoom effect.
 * @discussion Return the origin of the zoom. It should be relative to view, or screen based if view is not set. 
 * The controller will fade in/out if the rect is CGRectZero.
 */
- (CGRect)previewController:(QLPreviewController *)controller frameForPreviewItem:(id <QLPreviewItem>)item 
               inSourceView:(UIView **)view
{
    DDLogOrange(@"%s called",__PRETTY_FUNCTION__);
//    __block QLItem *previewItem = NULL; // orig - ??
    QLItem *previewItem = (QLItem *)item;
    
    CGRect frame = CGRectZero; // controller fades in/out
    
    UIImage* thumbnail = previewItem.scl.thumbnail;
    if (thumbnail)
    {
        //orig
//        return CGRectMake(0, 0, thumbnail.size.width, thumbnail.size.height);
        
        if (AppConstants.isIOS8OrLater && _hudContainerView) {
            UIView *superview = (_hudContainerView.superview) ? _hudContainerView.superview : _hudContainerView;
            //ET 11/18/14 (arrrrgh...)
            // Racking my brains why the frame doesn't convert properly after rotation,
            // even though the constraints applied in MessagesVC are positioning the _hudContainerView properly.
            // Turns out SWRevealController does not re-layout its subviews for rotation, in this case the 
            // "newView" containing the spinnerView/_hudContainerView. This is configured in MessagesVC, 
            // added to the window.rootVC on iPad.
            frame = [presentingVC.view convertRect:_hudContainerView.frame fromView:superview];
        }
        else {
            CGSize size = thumbnail.size;
            CGPoint vcenter = self.view.center;
            CGPoint origin = (CGPoint){ .x = vcenter.x - (size.width / 2), .y = vcenter.y - (size.height / 2) };
            frame = (CGRect){ origin, thumbnail.size };
        }
    }

    DDLogOrange(@"%s RETURN frame:%@",__PRETTY_FUNCTION__,NSStringFromCGRect(CGRectZero));
    //return (CGRect){ self.view.center, CGSizeZero };
    return frame; 
}

/*!
 * @abstract Invoked when the preview controller is about to be presented full screen or dismissed from full screen, to provide a smooth transition when zooming.
 * @param contentRect The rect within the image that actually represents the content of the document. For example, for icons the actual rect is generally smaller than the icon itself.
 * @discussion Return an image the controller will crossfade with when zooming. You can specify the actual "document" content rect in the image in contentRect.
 */
- (UIImage *)previewController:(QLPreviewController *)controller transitionImageForPreviewItem:(id <QLPreviewItem>)item contentRect:(CGRect *)contentRect
{
    __block QLItem *previewItem = NULL;
    
    return previewItem.scl.thumbnail;
}


- (id <QLPreviewItem>)previewController: (QLPreviewController *)controller previewItemAtIndex:(NSInteger)index
{
    __block NSError * error;
    __block QLItem *previewItem = NULL;
    
    QLItem* item = [items objectAtIndex:index];
    DDLogMagenta(@"previewItemAtIndex %d  %@  ", (int)index, item.scloudID);
    
    if(item)
    {
        if(!item.url)
        {
            if(item.scl.missingSegments.count  > 0)
            {
                
                [self createThumbnailPageWith:item withError:&error];
                
            }
            else
            {
                [self decryptAndUpdateItem:item withError:&error];
                [self updateViewDateForItem:item];
            }
        }
        else
        {
            [self updateViewDateForItem:item];
        }
        
        if(!error)
        {
            previewItem = item;
        }
    }
    
    if(!previewItem)
    {
        
        previewItem = notfoundItem;
    }
 
    
    return previewItem;
    
}



/*!
 * @abstract Invoked by the preview controller before trying to open an URL tapped in the preview.
 * @result Returns NO to prevent the preview controller from calling -[UIApplication openURL:] on url.
 * @discussion If not implemented, defaults is YES.
 */
- (BOOL)previewController:(QLPreviewController *)controller shouldOpenURL:(NSURL *)url forPreviewItem:(id <QLPreviewItem>)item
{
    return YES;
}

#pragma mark - FYEOViewControllerDelegate methods

- (void)fyeoViewControllerWillDismiss:(FYEOViewController *)sender
{
    [self commonShutdown];
    
    if (completeBlock) {
		completeBlock(NULL);
		completeBlock = NULL; // release block to prevent retain cycle
	}
}



#pragma mark - MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[HUD removeFromSuperview];
 	HUD = nil;
}


@end
