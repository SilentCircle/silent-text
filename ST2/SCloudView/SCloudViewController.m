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
#import "SCloudViewController.h"

#import "AppDelegate.h"
#import "AppConstants.h"
#import "CHTCollectionViewWaterfallCell.h"
#import "MessageFWDViewController.h"
#import "MessageStreamManager.h"
#import "OHActionSheet.h"
#import "SCloudPreviewer.h"
#import "SilentTextStrings.h"
#import "STSCloud.h"
#import "STLogging.h"
#import "STMessage.h"
#import "STPreferences.h"
#import "STUser.h"
#import "YapCollectionKey.h"
#import "YRDropdownView.h"

// Categories
#import "UIImage+maskColor.h"
#import "UIImage+Thumbnail.h"

// Libraries
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>


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

#define CELL_WIDTH 100
#define CELL_COUNT 30000
#define CELL_IDENTIFIER @"WaterfallCell"

#define kBurn (@selector(burnAction:))
#define kSend (@selector(sendAction:))


@implementation SCloudViewController
{
    YapDatabaseConnection *databaseConnection;   // Read-Only connection (for main thread)
	YapDatabaseViewMappings *mappings;

    UIPopoverController* popController;
    
    SCloudPreviewer* scp;
    
    NSCache *cellHeightCache;
    NSMutableDictionary* utiImageCache;
    
    NSDateFormatter *durationFormatter;

    UIImage*    defaultDownloadImage;
    UIImage*    defaultAudioImage;
    UIImage*    defaultVCardImage;

    UIImage*    downloadIcon;
    UIImage*    fyeoIcon;
}


- (id)initWithProperNib
{
    NSString *nibName;
    
	if (AppConstants.isIPhone)
		nibName = @"SCloudViewController_iPhone";
	else
		nibName = @"SCloudViewController_iPad";
    
    return [self initWithNibName:nibName bundle:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	DDLogAutoTrace();
	
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
        defaultAudioImage = [UIImage imageNamed: @"vmemo70"];
        defaultVCardImage = [UIImage imageNamed: @"vcard"];
        defaultDownloadImage = [UIImage imageNamed: @"download_doc"];
        
        downloadIcon =   [UIImage imageNamed: @"939-download-rectangle"];
        fyeoIcon =   [UIImage imageNamed: @"fyeo-on"];
        fyeoIcon = [fyeoIcon scaledToWidth:16];
        
        cellHeightCache = [[NSCache alloc] init];
		cellHeightCache.countLimit = 500;
        
        utiImageCache = [NSMutableDictionary dictionary];
        
        durationFormatter = [[NSDateFormatter alloc] init];
        [durationFormatter setDateFormat:@"mm:ss"];
        
//		downloadIcon  = [downloadIcon maskWithColor:[STPreferences navItemTintColor]];
    }
    return self;
}

- (void)dealloc
{
	DDLogAutoTrace();
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_collectionView removeFromSuperview];
	_collectionView = nil;
}

#pragma mark - Accessors
- (UICollectionView *)collectionView {
	if (!_collectionView) {
		CHTCollectionViewWaterfallLayout *layout = [[CHTCollectionViewWaterfallLayout alloc] init];
        
		layout.sectionInset = UIEdgeInsetsMake(9, 9, 9, 9);
		layout.delegate = self;
        
		_collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
		_collectionView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
		_collectionView.dataSource = self;
		_collectionView.delegate = self;
		_collectionView.backgroundColor = [UIColor blackColor];
		[_collectionView registerClass:[CHTCollectionViewWaterfallCell class]
		    forCellWithReuseIdentifier:CELL_IDENTIFIER];
	}
	return _collectionView;
}

#pragma mark - View Life Cycle


- (void)viewDidLoad
{
	DDLogAutoTrace();
	[super viewDidLoad];
	
	// Do any additional setup after loading the view, typically from a nib.
	[self.view addSubview:self.collectionView];
    
    self.cellWidth  = CELL_WIDTH;
  
//    self.navigationController.navigationBar.barStyle =  UIBarStyleBlack;
//    self.navigationController.navigationBar.translucent  = YES;
//	self.navigationController.navigationBar.tintColor = [STPreferences navItemTintColor];
    
//	self.collectionView.contentInset = UIEdgeInsetsMake(self.navigationController.navigationBar.frame.size.height, 0,0,0);
    
    CGSize statusbarsize = [UIApplication sharedApplication].statusBarFrame.size;
    CGFloat top = self.navigationController.navigationBar.frame.size.height + MIN(statusbarsize.height, statusbarsize.width);
    CGFloat bottom = 0;
    
    UIEdgeInsets edgeInsets = UIEdgeInsetsMake(top, 0, bottom, 0);
    self.collectionView.contentInset = edgeInsets;
    self.collectionView.scrollIndicatorInsets = edgeInsets;

//	self.view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
//	self.collectionView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
	
    self.navigationItem.leftBarButtonItem =  STAppDelegate.settingsButton;
    self.navigationItem.title = NSLocalizedString(@"All Media", @"All Media");
    
	databaseConnection = STDatabaseManager.uiDatabaseConnection;
	[self initializeMappings];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionDidUpdate:)
	                                             name:UIDatabaseConnectionDidUpdateNotification
	                                           object:STDatabaseManager];

    
    UIMenuItem *burn = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Burn", @"Burn") action:kBurn];
    UIMenuItem *send = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Send", @"Send") action:kSend];
    
    [[UIMenuController sharedMenuController]  setMenuItems:[NSArray arrayWithObjects: burn, send,nil]];

    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                  target:self
                                                  action:@selector(deleteALL:)];

}

- (void)viewDidAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewDidAppear:animated];
	
	[self updateLayout];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration {
	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation
	                                        duration:duration];
    
	[self updateLayout];
}

- (void)updateLayout {
	CHTCollectionViewWaterfallLayout *layout =
    (CHTCollectionViewWaterfallLayout *)self.collectionView.collectionViewLayout;
	layout.columnCount = self.collectionView.bounds.size.width / self.cellWidth;
	layout.itemWidth = self.cellWidth;
    
    
    CGSize statusbarsize = [UIApplication sharedApplication].statusBarFrame.size;
    CGFloat top = self.navigationController.navigationBar.frame.size.height + MIN(statusbarsize.height, statusbarsize.width);
    CGFloat bottom = 0;
 	
	UIEdgeInsets edgeInsets = UIEdgeInsetsMake(top, 0, bottom, 0);
	
    self.collectionView.contentInset = edgeInsets;
    self.collectionView.scrollIndicatorInsets = edgeInsets;
}


-(void) showViewer:(UIViewController*)controller
          fromRect:(CGRect)inRect
            inView:(UIView *)inView
        hideNavBar:(BOOL) hideNavBar
{
    if (AppConstants.isIPhone)
    {
        
        self.navigationItem.backBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back",@"Back")
                                         style:UIBarButtonItemStylePlain
                                        target:nil
                                        action:nil];
        
        [self.navigationController pushViewController:controller
                                             animated:YES];
    }
    else
    {
        if (popController.popoverVisible) {
            [popController dismissPopoverAnimated:YES];
            return;
        }
        
        UINavigationController *vccNavController = [[UINavigationController alloc] initWithRootViewController:controller];
        vccNavController.navigationBarHidden = hideNavBar;
        
        popController =  [[UIPopoverController alloc] initWithContentViewController:vccNavController];
		CGSize size = controller.view.frame.size;
		if (!hideNavBar)
			size.height += 44;
		popController.popoverContentSize = size;
        popController.delegate = self;
        
        [popController presentPopoverFromRect:inRect
                                       inView:inView
                     permittedArrowDirections:UIPopoverArrowDirectionAny
                                     animated:YES];
    }
    
}

#pragma mark- Database

- (void)initializeMappings
{
	DDLogAutoTrace();
	
    [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
		if ([transaction ext:Ext_View_Order] == nil)
		{
			// The view isn't ready yet.
			// So don't initialize the mappings yet.
			return;
		}
		
		mappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[kSCCollection_STSCloud] view:Ext_View_Order];
		[mappings updateWithTransaction:transaction];
    }];
}

- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
	NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
    
	// Get the changes as they apply to our view.
	
	if (mappings == nil)
	{
		[self initializeMappings];
		[self.collectionView reloadData];
		return;
	}
	
	NSArray *rowChanges = nil;
	
	[[databaseConnection ext:Ext_View_Order] getSectionChanges:NULL
	                                                rowChanges:&rowChanges
	                                          forNotifications:notifications
	                                              withMappings:mappings];
	
    if ([rowChanges count] == 0)
    {
        // There aren't any changes that affect our tableView
        return;
    }
    
    [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		for (YapDatabaseViewRowChange *rowChange in rowChanges)
		{
			if (rowChange.type == YapDatabaseViewChangeInsert ||
			    rowChange.type == YapDatabaseViewChangeMove   ||
			    rowChange.type == YapDatabaseViewChangeUpdate  )
			{
				NSString *key = [[transaction ext:Ext_View_Order] keyAtIndex:rowChange.finalIndex
				                                                     inGroup:kSCCollection_STSCloud];
				[cellHeightCache removeObjectForKey:key];
			}
		}
	}];
	
	// Update the collectionView, animating the changes
	
	[self.collectionView performBatchUpdates:^{
		
		for (YapDatabaseViewRowChange *rowChange in rowChanges)
		{
			switch (rowChange.type)
			{
				case YapDatabaseViewChangeDelete :
				{
					[self.collectionView deleteItemsAtIndexPaths:@[ rowChange.indexPath ] ];
					break;
				}
				case YapDatabaseViewChangeInsert :
				{
					[self.collectionView insertItemsAtIndexPaths:@[ rowChange.newIndexPath ]];
					break;
				}
				case YapDatabaseViewChangeMove :
				{
					[self.collectionView deleteItemsAtIndexPaths:@[ rowChange.indexPath ] ];
					[self.collectionView insertItemsAtIndexPaths:@[ rowChange.newIndexPath ]];
					break;
				}
				case YapDatabaseViewChangeUpdate :
				{
					[self.collectionView reloadItemsAtIndexPaths:@[ rowChange.indexPath ] ];
					break;
				}
			}
		}
		
	} completion:NULL];
}

#pragma mark- helpers


- (void)burnScloudID:(NSString *)scloudID
{
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STSCloud *scl = [transaction objectForKey:scloudID inCollection:kSCCollection_STSCloud];
		
		if (scl == nil)
		{
			DDLogWarn(@"Unable to burn Scloud - seems to be missing from the database");
			return;
		}
		
		YapDatabaseRelationshipTransaction *graph = [transaction ext:Ext_Relationship];
		YapDatabaseViewTransaction *order = [transaction ext:Ext_View_Order];
		
		NSMutableArray *edges = [[NSMutableArray alloc] init];
		
		[graph enumerateEdgesWithName:@"scloud"
		               destinationKey:scloudID
		                   collection:kSCCollection_STSCloud
		                   usingBlock:^(YapDatabaseRelationshipEdge *edge, BOOL *stop)
		{
			[edges addObject:edge];
		}];
		
		for (YapDatabaseRelationshipEdge *edge in edges)
		{
			STMessage *message = [graph sourceNodeForEdge:edge];
			
			// Delete the message
			
			[transaction removeObjectForKey:edge.sourceKey inCollection:edge.sourceCollection];
			
			// Touch the conversation.
			// We do this so the various UIViews will see that the conversation was updated.
			
			[order touchRowForKey:message.conversationId
			         inCollection:message.userId];
		}
		
		[scl removeFromCache];
		[transaction removeObjectForKey:scloudID
		                   inCollection:kSCCollection_STSCloud];
	}];
}


#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    
	popController = nil;
}


#pragma mark - MessageFWDViewController methods.

- (void)messageFWDViewController:(MessageFWDViewController *)sender
             messageFWDWithSiren:(Siren *)siren
                      recipients:(NSArray *)recipients
                           error:(NSError *)error
{
    DDLogAutoTrace();
	
	if (AppConstants.isIPhone)
	{
		[self.navigationController popViewControllerAnimated:YES];
	}
	else
	{
		if (popController.popoverVisible)
			[popController dismissPopoverAnimated:YES];
	}

	if (error)
	{
		NSError *betterError = [NSError errorWithDomain:NSOSStatusErrorDomain code:error.code userInfo:nil];
		DDLogWarn(@"Error: %@", [error description]);
		
		UIAlertView *alert =
		  [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Address Book Failed", @"Address Book Failed")
		                             message:betterError.localizedDescription
		                            delegate:nil
		                   cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
		                   otherButtonTitles:nil];
		[alert show];
	}
	else if (recipients.count == 1)
	{
		// Hoping for array of XMPPJID items.
		// Supporting NSString for now.
		
		id recipient = [recipients objectAtIndex:0];
			
		XMPPJID *recipientJID = nil;
		if ([recipient isKindOfClass:[XMPPJID class]])
			recipientJID = (XMPPJID *)recipient;
		else
			recipientJID = [XMPPJID jidWithString:(NSString *)recipient];
		
		MessageStream *messageStream = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
		[messageStream sendSiren:siren
		                   toJID:recipientJID
		                withPush:YES
		                   badge:YES
		           createMessage:YES
		              completion:^(NSString *messageId, NSString *conversationId)
		{
			// We could use this to jump to the conversation
		}];
	}
	else if (recipients.count > 1)
	{
		// Todo: Handle multiple recipients.
	}
}

- (void)messageFWDViewController:(MessageFWDViewController *)sender
             messageFWDWithSiren:(Siren *)siren
                     selectedJid:(NSString *)jidStr
                     displayName:(NSString *)displayName
                           error:(NSError *)error
{
	DDLogAutoTrace();
	
	if (AppConstants.isIPhone)
	{
		[self.navigationController popViewControllerAnimated:YES];
	}
	else
    {
		if (popController.popoverVisible)
			[popController dismissPopoverAnimated:YES];
	}
	
	
	
    if (error)
	{
		NSError *betterError = [NSError errorWithDomain:NSOSStatusErrorDomain code:error.code userInfo:nil];
		DDLogWarn(@"Error: %@", [error description]);
		
		UIAlertView *alert =
		  [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Address Book Failed", @"Address Book Failed")
		                             message:betterError.localizedDescription
		                            delegate:nil
		                   cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
		                   otherButtonTitles:nil];
		[alert show];
	}
    else
    {
		XMPPJID *jid = [XMPPJID jidWithString:jidStr];
		
		MessageStream *messageStream = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
		[messageStream sendSiren:siren
		                   toJID:jid
		                withPush:YES
		                   badge:YES
		           createMessage:YES
		              completion:^(NSString *messageId, NSString *conversationId)
		{
			// Optional
		}];
	}
}

#pragma mark - UICollectionViewDataSource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
	return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
	NSInteger count = [mappings numberOfItemsInSection:section];
    return count;

}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	CHTCollectionViewWaterfallCell *cell =
    (CHTCollectionViewWaterfallCell *)[collectionView dequeueReusableCellWithReuseIdentifier:CELL_IDENTIFIER
                                                                                forIndexPath:indexPath];

    __block STSCloud *scl = nil;
    [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		scl = [[transaction ext:Ext_View_Order] objectAtIndex:indexPath.row inGroup:kSCCollection_STSCloud];
    }];

    UIImage* thumbnail = scl.thumbnail?: scl.lowRezThumbnail;
    
    NSDictionary* metaData = scl.metaData;
    
    if(thumbnail)
    {
         if(scl.fyeo)
        {
            thumbnail = [thumbnail imageWithBadgeOverlay:fyeoIcon text:NULL textColor:[UIColor whiteColor]];
        }
        cell.image = thumbnail;
    }
    else if(scl.mediaType)
    {
          if(UTTypeConformsTo( (__bridge CFStringRef)scl.mediaType, kUTTypeAudio))
        {
            cell.image = defaultAudioImage;
            NSString* overlayText = NULL;
            
            if(metaData)
            {
                NSString* duration = [scl.metaData valueForKey:@"Duration"];
                
                if(duration)
                {
                        overlayText = [durationFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: duration.doubleValue]];
                 }
            }
            cell.image = [defaultAudioImage imageWithBadgeOverlay:NULL text:overlayText textColor:[UIColor whiteColor]];

        }

        else if(UTTypeConformsTo( (__bridge CFStringRef)scl.mediaType, kUTTypeVCard))
        {
            UIImage* cardImage = defaultVCardImage;
            UIImage* personImage =  (scl.preview)
            ? scl.preview
            : [UIImage imageNamed:@"defaultPerson"];
            
            UIGraphicsBeginImageContext(CGSizeMake(122, 94));
            [cardImage drawInRect:CGRectMake(0, 0, 122, 94)];
            [personImage drawInRect:CGRectMake(16, 15, 52, 51)];
            
            cardImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
              cell.image = cardImage;
        }
        else
        {
            
            UIImage* baseImage = [utiImageCache objectForKey:scl.mediaType];
            
            if(scl.missingSegments.count > 0)
            {
                cell.image = [baseImage imageWithBadgeOverlay:downloadIcon text:NULL textColor:[UIColor whiteColor]];
 
            }
            else
            {
                cell.image = baseImage;
            }

         }
        
    }
    else
    {
  
        
        cell.image =  defaultDownloadImage;
        
    }
    
    cell.scloudID = scl.uuid;
    cell.delegate = self;
    
	return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    __block STSCloud *scl = nil;
    [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		scl = [[transaction ext:Ext_View_Order] objectAtIndex:indexPath.row inGroup:kSCCollection_STSCloud];
    }];
    
    if(scl)
    {
        if(!scp)
        {
            scp =[[SCloudPreviewer alloc] init];
        };
        
        [scp displaySCloud:scl.uuid
                      fyeo:scl.fyeo
                 fromGroup:NULL
            withController:self //ET TEST:self.navigationController
                    inView:self.view
           completionBlock:^(NSError *error)
         {
             
             if(error)
             {
                 
                 [YRDropdownView showDropdownInView:collectionView
                                              title:NSLocalizedString(@"Unable to display", @"Unable to display")
                                             detail:error.localizedDescription
                                              image: NULL //[UIImage imageNamed:@"ignored"]
                                    backgroundImage:[UIImage imageNamed:@"bg-yellow"]
                                           animated:YES
                                          hideAfter:3];
                 
             }
             else
             {
                 DDLogBrown(@"--- Need refresh code here ---");
                 DDLogCyan(@"\ndisplaySCloud...completionBlock: self:%@\n   subviews:%@", self, self.view.subviews);
                 // refresh the view here.

             }
             
         }] ;
        
    }


}


#pragma mark - UICollectionViewWaterfallLayoutDelegate
- (CGFloat)   collectionView:(UICollectionView *)collectionView
                      layout:(CHTCollectionViewWaterfallLayout *)collectionViewLayout
    heightForItemAtIndexPath:(NSIndexPath *)indexPath

{
	__block STSCloud *scl = nil;
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		scl = [[transaction ext:Ext_View_Order] objectAtIndex:indexPath.row inGroup:kSCCollection_STSCloud];
	}];
	
	float cellHeight = 40;
	if (scl)
	{
		NSNumber *cachedCellHeight = [cellHeightCache objectForKey:scl.uuid];
		if (cachedCellHeight)
		{
			cellHeight = [cachedCellHeight floatValue];
		}
		else
		{
			float oldWidth = CELL_WIDTH;
			UIImage* thumbnail = scl.thumbnail?: scl.lowRezThumbnail;
			
			if(thumbnail)
			{
				cellHeight = thumbnail.size.height;
				oldWidth  = thumbnail.size.width;
			}
			else if(scl.mediaType)
			{
				if(UTTypeConformsTo( (__bridge CFStringRef)scl.mediaType, kUTTypeAudio))
				{
					cellHeight = defaultAudioImage.size.height;
					oldWidth  = defaultAudioImage.size.width;
				}
				else if(UTTypeConformsTo( (__bridge CFStringRef)scl.mediaType, kUTTypeVCard))
				{
					cellHeight  = defaultVCardImage.size.height;
					oldWidth  = defaultVCardImage.size.width;
				}
				else
				{
					// stupid hack to fool UIDocumentInteractionController to give us icons for the UTI,
					//  Apple is infested with gnomes
					NSURL*fooUrl = [NSURL URLWithString:@"file://foot.dat"];
					UIDocumentInteractionController* doc = [UIDocumentInteractionController interactionControllerWithURL:fooUrl];
					doc.UTI =  scl.mediaType;
					NSArray *icons = doc.icons;
					if(icons && icons.count > 0)
					{
						thumbnail =   [[icons lastObject] copy] ;
						cellHeight = thumbnail.size.height;
						oldWidth  = thumbnail.size.width;
						
						if(![utiImageCache objectForKey:doc.UTI])
						{
							[utiImageCache setObject:thumbnail.copy forKey:doc.UTI];
						}
					}
					
					doc = NULL;
				}
			}
			
			float scaleFactor = CELL_WIDTH / oldWidth;
			cellHeight = cellHeight * scaleFactor;
			
			[cellHeightCache setObject:@(cellHeight) forKey:scl.uuid];
		}
	}
	
	return cellHeight;
}


#pragma mark - menu action methods

- (BOOL)collectionView:(UICollectionView *)collectionView
      canPerformAction:(SEL)action
    forItemAtIndexPath:(NSIndexPath *)indexPath
            withSender:(id)sender {
    
    return NO;
  
    if (action == kBurn  ||  action == kSend)
    {
        return YES;
    }
 }

- (BOOL)collectionView:(UICollectionView *)collectionView
shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView
         performAction:(SEL)action
    forItemAtIndexPath:(NSIndexPath *)indexPath
            withSender:(id)sender {
   
    if ([NSStringFromSelector(action) isEqualToString:@"copy:"]) {
        UIPasteboard *pasteBoard = [UIPasteboard pasteboardWithName:UIPasteboardNameGeneral create:NO];
        pasteBoard.persistent = YES;
 //       NSData *capturedImageData = UIImagePNGRepresentation([_capturedPhotos objectAtIndex:indexPath.row]);
//        [pasteBoard setData:capturedImageData forPasteboardType:(NSString *)kUTTypePNG];
    }

    NSLog(@"performAction");
}

#pragma mark - UIMenuController required methods
- (BOOL)canBecomeFirstResponder {
    // NOTE: The menu item will on iOS 6.0 without YES (May be optional on iOS 7.0)
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
     // The selector(s) should match your UIMenuItem selector
    
    return ( action == kBurn  || action == kSend )?YES:NO;
}


#pragma mark - Custom Action(s)


- (void)deleteALL:(id)sender
{
   NSString *BURN_ALL    = NSLocalizedString(@"Burn ALL", @"Burn ALL");
    
    //ET 03/11/15
    // ST-982: Needed the trash can barbutton item frame to present
    // popover on iPad
    UIView *bbtnView = [(UIBarButtonItem *)sender valueForKey:@"view"];
    CGRect frame = bbtnView.frame;
    [OHActionSheet showFromRect:frame 
                       sourceVC:self 
                         inView:self.navigationController.navigationBar 
                 arrowDirection:UIPopoverArrowDirectionUp
                        title:NSLocalizedString(@"Burn All Media", @"Burn All Media")
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:BURN_ALL
            otherButtonTitles:nil
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
							 
							 NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
							 
							 if ([choice isEqualToString:BURN_ALL])
							 {
								 __block    NSArray *allScloud = [NSArray array];
                                 
                                 [databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
                                     
                                     allScloud = [transaction allKeysInCollection:kSCCollection_STSCloud];
                                
                                 } completionBlock:^{
                                     
                                     for(NSString *scloudID in allScloud)
                                     {
                                         [self burnScloudID:scloudID];
                                     }

                                 }];
                                 
							 }
							 
						 }];
    
}

// iOS 7.0 custom delegate method for the Cell to pass back a method for what custom button in the UIMenuController was pressed
- (void)burnAction:(id)sender forCell:(CHTCollectionViewWaterfallCell *)cell {
    
    NSLog(@"burnAction action on iOS 7.0 for %@", cell.scloudID);

     
    NSString* scloudID = cell.scloudID;
    
    if(scloudID)
    {
        [self burnScloudID:scloudID];
        
    }
    
}


- (void)burnAction:(UIMenuController*)menuController {
    
    NSLog(@"burnAction action! %@", menuController);
}

// iOS 7.0 custom delegate method for the Cell to pass back a method for what custom button in the UIMenuController was pressed
- (void)sendAction:(id)sender forCell:(CHTCollectionViewWaterfallCell *)cell
{
    
    if(!cell.scloudID) return;
    
    NSLog(@"sendAction action on iOS 7.0 for %@", cell.scloudID);
    
    __block STSCloud* scl = nil;
    
    [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        scl = [transaction objectForKey:cell.scloudID inCollection:kSCCollection_STSCloud];
        
    }];
    
    if(scl)
    {
        NSDictionary*   metaData = scl.metaData;
        Siren* siren = Siren.new;
        siren.cloudLocator   = scl.uuid;
        siren.cloudKey       = scl.keyString;
        siren.mediaType      = scl.mediaType;
        
        if(UTTypeConformsTo( (__bridge CFStringRef)scl.mediaType, kUTTypeAudio))
        {
            //               siren.message = [metaData objectForKey: kSCloudMetaData_FileName]?:NULL;
            
            siren.mimeType =  [metaData objectForKey: kSCloudMetaData_MimeType]?:NULL;
            siren.duration =  [metaData objectForKey: kSCloudMetaData_Duration]?:NULL;
            
        }
        else if(UTTypeConformsTo( (__bridge CFStringRef)scl.mediaType, kUTTypeVCard))
        {
            if(scl.preview)
                siren.preview = UIImageJPEGRepresentation(scl.preview, 1.0);
            
            siren.mimeType      = kMimeType_vCard;
            
        }
        else
        {
            UIImage* thumbnail = cell.image;
            
            if(thumbnail.size.height  > thumbnail.size.width)
                thumbnail = (thumbnail.size.height > 150)? [thumbnail scaledToHeight:150]: thumbnail;
            else
                thumbnail = (thumbnail.size.width > 150)? [thumbnail scaledToWidth:150]: thumbnail;
            
            siren.thumbnail       = UIImageJPEGRepresentation(thumbnail, 0.1);
            
            siren.message = [metaData objectForKey: kSCloudMetaData_FileName]?:NULL;
            siren.mimeType =  [metaData objectForKey: kSCloudMetaData_MimeType]?:NULL;
            siren.duration =  [metaData objectForKey: kSCloudMetaData_Duration]?:NULL;
            
        }
        
        
        MessageFWDViewController* mfc = [[MessageFWDViewController alloc] initWithDelegate:self
                                                                                     siren:siren ];
        
        mfc.title = NSLocalizedString(@"Send File", @"Send File Popover title");
        
        [self showViewer: mfc
                fromRect:cell.contentView.frame
                  inView:cell.contentView
              hideNavBar:NO];
        
    }
}

- (void)sendAction:(UIMenuController*)menuController {
    
    NSLog(@"sendAction action! %@", menuController);
}

- (BOOL)canBurn:(id)sender forCell:(CHTCollectionViewWaterfallCell *)cell
{
    return YES;
    
}

- (BOOL)canSend:(id)sender forCell:(CHTCollectionViewWaterfallCell *)cell
{
    NSString* scloudID = cell.scloudID;
    __block BOOL result = NO;
    
    if(scloudID)
    {
        __block STSCloud *scl = nil;
        
        [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            
            scl = [transaction objectForKey:cell.scloudID inCollection:kSCCollection_STSCloud];
            
            if(scl)
                result = !scl.fyeo;
        }];
        
        
    }
    return result;
}


@end
