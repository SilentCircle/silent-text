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
#import "FileImportViewController.h"

#import "AddressBookManager.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "AvatarManager.h"
#import "ContactsSubViewController.h"
#import "ContactsSubViewControllerCell.h"
#import "GeoTracking.h"
#import "MBProgressHUD.h"
#import "MessageFWDViewController.h"
#import "MessageStreamManager.h"
#import "OHActionSheet.h"
#import "SCloudManager.h"
#import "SCloudObject.h"
#import "SilentTextStrings.h"
#import "STConversation.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "STPreferences.h"
#import "STSCloud.h"
#import "STUser.h"
#import "YapCollectionKey.h"

// Categories
#import "NSDate+SCDate.h"
#import "NSURL+SCUtilities.h"
#import "UIImage+Thumbnail.h"

// Libraries
#import <MobileCoreServices/MobileCoreServices.h>


// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


static const CGFloat kAvatarDiameter = 36;


#define USE_SECTIONS_THRESHOLD 8


typedef enum {
	segment_stuser = 0,
	segment_addressbook = 1,
} SegmentIndex;


@implementation FileImportViewController
{
	NSURL *_url;
	STLocalUser *sendingUser;
	
    YapDatabaseConnection *uiDatabaseConnection;
	
	ContactsSubViewController*  contactsSubViewController;
    MBProgressHUD*              HUD;
    UIImage*                    thumbnail;
    
    SegmentIndex            selectedSegment;
    
    UIView*                 scContactsView;
    
    UITableView *           abContactsView;
    NSArray                 *addressBookData;
 	NSArray                 *partitionedData;
    BOOL                    useSectionsForAB;
    AppTheme*               theme;


}

@synthesize horizontalRule = horizontalRule;


- (id)initWithURLs:(NSArray *)inURLs
{
	// FIXME: !
    
    if (self = [super initWithNibName:nil bundle:nil])
    {
        for(NSURL * url in inURLs)
		{
			DDLogBlue(@"-> %@", url.lastPathComponent);
			
		//	if (CFURLHasDirectoryPath((__bridge CFURLRef)(url))) continue;
			
			_url = url;
			break;
		}
	}
	return self;
}

- (id)initWithURL:(NSURL*)inURL
{
  	if (self = [super initWithNibName:nil bundle:nil])
    {
        _url = inURL;
  	}
	return self;
}

- (void)dealloc
{
	DDLogAutoTrace();
	[STDatabaseManager teardownFilteredContactsDBView];
}

- (void)viewDidLoad
{
	DDLogAutoTrace();
    [super viewDidLoad];
    
    theme = [AppTheme getThemeBySelectedKey];

    uiDatabaseConnection = STDatabaseManager.uiDatabaseConnection;
    
//    self.navigationController.navigationBar.barStyle =  UIBarStyleBlack;
//	self.navigationController.navigationBar.translucent = YES;
	self.navigationItem.title = NSLocalizedString(@"Send File", @"Send File title");
	
    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                  target:self
                                                  action:@selector(cancelButtonTapped:)];
	
    self.sendButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
													  target:self
													  action:@selector(sendButtonAction:)];
     
	self.sendButton.enabled = NO;
	self.navigationItem.rightBarButtonItem = self.sendButton;
	
	self.view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];

    sendingUser = STDatabaseManager.currentUser;
	
	[_sendingUserButton setTitle:[self nameForUser:sendingUser] forState:UIControlStateNormal];
	
	[STDatabaseManager configureFilteredContactsDBView:sendingUser.networkID
	                                        withUserId:sendingUser.uuid];

	NSString *stTitle = NSLocalizedString(@"Silent Contacts", @"Segment title");
	NSString *abTitle = NSLocalizedString(@"Apple", @"Segment title");
	
	[self.contactSelectSegment setTitle:stTitle forSegmentAtIndex:segment_stuser];
	[self.contactSelectSegment setTitle:abTitle forSegmentAtIndex:segment_addressbook];
    
	self.segmentsContainer.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    
    [self reloadAddressBookData];
    
    [self.contactSelectSegment addTarget:self
                                  action:@selector(segmentAction:)
                        forControlEvents:UIControlEventValueChanged];
    
    if(addressBookData.count == 0)
    {
        NSLayoutConstraint *heightConstraint = [self heightConstraintFor:self.segmentsContainer];
		heightConstraint.constant = 0;
 		[self.segmentsContainer setNeedsUpdateConstraints];
     }
    
	contactsSubViewController =
	  [[ContactsSubViewController alloc] initWithDatabaseViewName:Ext_View_FilteredContacts delegate:self];
	
	contactsSubViewController.allowsDeletion = NO;
	contactsSubViewController.ensuresSelection = NO;
	//contactsSubViewController.usesMultipleSelection = YES;
	contactsSubViewController.checkmarkSelectedCells = YES;
	
	contactsSubViewController.view.frame = self.contactsContainer.bounds;
	contactsSubViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |
	                                                  UIViewAutoresizingFlexibleHeight;
	
    scContactsView = contactsSubViewController.view;
    
	[self.contactsContainer addSubview:scContactsView];
	[self addChildViewController:contactsSubViewController];
    
    abContactsView = [[UITableView alloc]initWithFrame:self.view.bounds style:UITableViewStylePlain];
    abContactsView.backgroundColor =  [UIColor colorWithWhite: .95 alpha:1];
    abContactsView.rowHeight = 46;
	abContactsView.separatorInset = UIEdgeInsetsMake(0, (10+46+8), 0, 0); // top, left, bottom, right
    abContactsView.frame = self.contactsContainer.bounds;
    abContactsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    abContactsView.delegate = self;
    abContactsView.dataSource = self;
    
    UINib *cellNib = [UINib nibWithNibName:@"ContactsSubViewControllerCell" bundle:nil];
	[abContactsView registerNib:cellNib forCellReuseIdentifier:@"ContactsSubViewControllerCell"];
    
    [self.contactsContainer addSubview:abContactsView];
    
    
    if(selectedSegment  == segment_addressbook )
    {
        
        [scContactsView setHidden:YES];
        [abContactsView setHidden:NO];
    }
    else
    {
        [scContactsView setHidden:NO];
        [abContactsView setHidden:YES];
        
    }
 
    thumbnail = [_url thumbNail];
    
    _inputImage.image = thumbnail;
    
    NSMutableAttributedString *promptText = [[NSMutableAttributedString alloc]
                                             initWithString: NSLocalizedString(@"File: ",   @"File: ")
                                            attributes: @{NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]  }];
    
    NSMutableAttributedString *filetext = [[NSMutableAttributedString alloc]
                                        initWithString: [[_url path] lastPathComponent]
                                           attributes: @{NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleBody]   }];
    
    [promptText appendAttributedString:filetext];
    _promptLabel.attributedText = promptText;
   
    if ([[UIScreen mainScreen] scale] > 1.0)
	{
		// On retina devices, the contentScaleFactor of 2 results in our horizontal rule
		// actually being 2 pixels high. Fix it to be only 1 pixel (0.5 points).
		
		NSLayoutConstraint *heightConstraint = [self heightConstraintFor:horizontalRule];
		heightConstraint.constant = (heightConstraint.constant / [[UIScreen mainScreen] scale]);
		
		[horizontalRule setNeedsUpdateConstraints];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	DDLogAutoTrace();
	
     if(_url)
    {
        NSFileManager *fm  = NSFileManager.new;
        [fm removeItemAtURL: _url error: NULL];
   
    }
}

- (NSLayoutConstraint *)heightConstraintFor:(UIView *)item
{
	for (NSLayoutConstraint *constraint in item.constraints)
	{
		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeHeight) ||
		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeHeight))
		{
			return constraint;
		}
	}
	
	return nil;
}

- (void)updatedSendingUser:(STLocalUser *)newSendingUser
{
	DDLogAutoTrace();
	
	if (sendingUser != newSendingUser)
	{
		sendingUser = newSendingUser;
		if (sendingUser)
		{
			[STDatabaseManager reconfigureFilteredContactsDBView:sendingUser.networkID
			                                          withUserId:sendingUser.uuid];
			
			[_sendingUserButton setTitle:[self nameForUser:sendingUser] forState:UIControlStateNormal];
		}
		else
		{
			NSString *none = NSLocalizedString(@"<NONE>",
			  @"Placeholder for sendingUserButton when there is not a set account to send from");
			
			[_sendingUserButton setTitle:none forState:UIControlStateNormal];
		}
		
		[self reloadAddressBookData];
		[abContactsView reloadData];
	}
}

- (BOOL)startTrackingForRecipient:(NSString *)recipientJid
{
	DDLogAutoTrace();
	
	XMPPJID *localJid = sendingUser.jid;
	XMPPJID *remoteJid = [XMPPJID jidWithString:recipientJid];
	
	NSString *conversationId = [MessageStream conversationIDForLocalJid:localJid remoteJid:remoteJid];
	
	__block STConversation *conversation = nil;
	[uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		conversation = [transaction objectForKey:conversationId inCollection:sendingUser.uuid];
	}];
	
	BOOL willTrack = NO;
	if (conversation && conversation.tracking)
	{
		willTrack = [[GeoTracking sharedInstance] beginTracking];
	}
	
	return willTrack;
}

- (void)sendFile
{
	DDLogAutoTrace();
	
    __block NSString           *mediaType  = NULL;
    __block NSString            *mimeType   = NULL;
	__block NSMutableDictionary *mediaInfo  = NULL;
	
	NSString *recipientJid = nil;
    
	if (selectedSegment == segment_addressbook)
	{
		NSIndexPath *indexPath = [abContactsView indexPathForSelectedRow];
		if (indexPath == nil)
		{
			[self cancelButtonTapped:nil];
			return;
		}
		
		ABInfoEntry *abEntry = nil;
		if (useSectionsForAB)
			abEntry = [[partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
		else
			abEntry = [addressBookData objectAtIndex:indexPath.row];
		
		recipientJid = abEntry.jidStr;
    }
    else
    {
        NSString *selectedUserId = [contactsSubViewController selectedUserId];
		if (selectedUserId == nil)
		{
			[self cancelButtonTapped:nil];
			return;
        }
		
		__block STUser *recipient = nil;
		[uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			recipient = [transaction objectForKey:selectedUserId inCollection:kSCCollection_STUsers];
		}];
		
		recipientJid = [recipient.jid full];
	}
	
	BOOL willTrack = [self startTrackingForRecipient:recipientJid];
	self.sendButton.enabled = NO;
    
    [_url getResourceValue:&mediaType forKey:NSURLTypeIdentifierKey error:NULL];
    
    NSString *theUTI = (__bridge_transfer NSString *) UTTypeCreatePreferredIdentifierForTag( kUTTagClassFilenameExtension,  (__bridge CFStringRef) _url.pathExtension, NULL);
    mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef) theUTI, kUTTagClassMIMEType);

	NSString *localizedName = nil;
	[_url getResourceValue:&localizedName forKey:NSURLLocalizedNameKey error:NULL];
	
	NSDate *mediaDate = nil;
	[_url getResourceValue:&mediaDate forKey:NSURLCreationDateKey error:NULL];
	
	mediaInfo = @{
                  kSCloudMetaData_MediaType:  mediaType,
                  kSCloudMetaData_FileName: localizedName ,
 //                  kSCloudMetaData_Duration: duration,
//                  kSCloudMetaData_FileSize: [NSNumber numberWithUnsignedInteger:theData.length],
                  kSCloudMetaData_Date:     [mediaDate rfc3339String]
				  }. mutableCopy;
  	
    if(mimeType)
        [mediaInfo setObject:mimeType forKey:kSCloudMetaData_MimeType];
    
	__block SCloudObject *scloud =
	  [[SCloudObject alloc] initWithDelegate:self
	                                     url:_url
	                                metaData:mediaInfo
	                               mediaType:mediaType
	                           contextString:[sendingUser.jid full]];
	
	scloud.thumbnail = thumbnail;
	
	HUD = [[MBProgressHUD alloc] initWithView:self.view];
	HUD.mode = MBProgressHUDModeAnnularDeterminate;
	HUD.labelText = [NSString stringWithFormat:NSLS_COMMON_PREPARING, [[_url path] lastPathComponent]];
	
	__block NSError *error = nil;
	
	[self.view addSubview:HUD];
	[HUD showAnimated:YES whileExecutingBlock:^{
		
		[scloud saveToCacheWithError:&error];
		
		[[NSFileManager defaultManager] removeItemAtURL:_url error:NULL];
		_url = NULL;
		
		if (willTrack)
		{
			CLLocation *currentLocation = [[GeoTracking sharedInstance] currentLocation];
			if (!currentLocation)
			{
				HUD.mode = MBProgressHUDModeIndeterminate;
				HUD.labelText = NSLocalizedString(@"Waiting for GPS", @"Waiting for GPS");
			}
			
			while(!currentLocation)
			{
				currentLocation = [[GeoTracking sharedInstance] currentLocation];
			}
		}
		
	} completionBlock:^{
		
		NSAssert([NSThread isMainThread], @"Doing UI stuff here. Expecting to be on the main thread");
		
		[HUD removeFromSuperview];
		
		// upload this puppy!
		
		if (error)
		{
			NSString *title = NSLocalizedString(@"File Import Failed", @"Error message");
			
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
			                                                message:error.localizedDescription
			                                               delegate:nil
			                                      cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
			                                      otherButtonTitles:nil];
			[alert show];
			
            //ST-1001: SWRevealController v2.3 update
//			[STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController animated:YES];
            [STAppDelegate.revealController pushFrontViewController:STAppDelegate.mainViewController animated:YES];
            
			scloud = NULL;
		}
		else
		{
			Siren *siren = [Siren new];
			siren.mediaType    = mediaType;
			siren.mimeType     = mimeType;
			siren.cloudKey     = scloud.keyString;
			siren.cloudLocator = scloud.locatorString;
			siren.thumbnail    = UIImageJPEGRepresentation(scloud.thumbnail, 0.4);
			
			// SET fyeo burn and location from conversation.
			
			[self didFinishImportWithSiren:siren recipients:@[ recipientJid ]];
		}
	}];
}


- (void)didFinishImportWithSiren:(Siren* )siren recipients:(NSArray *)recpients
{
	if (!siren || recpients.count == 0) return;
	
	NSAssert([NSThread isMainThread], @"Doing UI stuff here. Expecting to be on the main thread");
	{
        //ST-1001: SWRevealController v2.3 update
//        [STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController animated:YES];
		[STAppDelegate.revealController pushFrontViewController:STAppDelegate.mainViewController animated:YES];
	}
	
	if (recpients.count == 1)
	{
		// Hoping for array of XMPPJID instances.
		// Supporting NSString for now.
		
		id recipient = [recpients objectAtIndex:0];
		XMPPJID *recipientJID = nil;
		if ([recipient isKindOfClass:[XMPPJID class]])
			recipientJID = (XMPPJID *)recipient;
		else
			recipientJID = [XMPPJID jidWithString:(NSString *)recipient];
		
		MessageStream *ms = [MessageStreamManager messageStreamForUser:sendingUser];

		[ms sendScloudWithSiren:siren toJID:recipientJID completion:NULL];
    }
	else
	{
		// Todo: Handle multiple ?
	}
}


#pragma mark - Actions

- (IBAction)userChangedTapped:(id)sender
{
	DDLogAutoTrace();
	
    NSMutableDictionary *nameToIdDict = [NSMutableDictionary dictionary];
    
    [uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		[[transaction ext:Ext_View_LocalContacts] enumerateKeysAndObjectsInGroup:@"" usingBlock:
		    ^(NSString *collection, NSString *key, STUser *localUser, NSUInteger index, BOOL *stop)
		{
			NSString *userName = [self nameForUser:localUser];
			NSString *userId = localUser.uuid;
			
			[nameToIdDict setObject:userId forKey:userName];
		}];
	}];
	
	NSString *title = NSLocalizedString(@"Select sending user", @"FileImport prompt");
	
    //ET 10/16/14 OHActionSheet update
    // The fileInfoContainer view contains the sendingUserButton (sender) - see xib
    CGRect frame = [_fileInfoContainer convertRect:[(UIButton *)sender frame] toView:self.view];
    [OHActionSheet showFromRect:frame
                       sourceVC:self 
                         inView:self.view
                 arrowDirection:UIPopoverArrowDirectionAny
                          title:title
              cancelButtonTitle:NSLS_COMMON_CANCEL
       	destructiveButtonTitle:NULL
              otherButtonTitles:[nameToIdDict allKeys]
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                         NSString *userName = [sheet buttonTitleAtIndex:buttonIndex];
                         NSString *userId = [nameToIdDict objectForKey:userName];
                         
                         __block STUser *newSendingUser = nil;
                         [uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                             
                             newSendingUser = [transaction objectForKey:userId inCollection:kSCCollection_STUsers];
                         }];
						 
						 if (newSendingUser.isLocal)
						 {
							[self updatedSendingUser:(STLocalUser *)newSendingUser];
						 }
                     }];
}

- (IBAction)sendButtonAction:(id)sender
{
	DDLogAutoTrace();
	
	[self sendFile];
}

- (IBAction)cancelButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
    //ST-1001: SWRevealController v2.3 update
//	[STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController animated:YES];
    [STAppDelegate.revealController pushFrontViewController:STAppDelegate.mainViewController animated:YES];
}

- (void)segmentAction:(id)sender
{
	DDLogAutoTrace();
	
	UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
	selectedSegment = (SegmentIndex)(segmentedControl.selectedSegmentIndex);
	
	if (selectedSegment  == segment_addressbook)
	{
        [scContactsView setHidden:YES];
        [abContactsView setHidden:NO];
        [self reloadAddressBookData];
        [abContactsView reloadData];
    }
    else
    {
        [scContactsView setHidden:NO];
        [abContactsView setHidden:YES];
    }
	
	self.sendButton.enabled = NO;
}


#pragma mark - Utility

- (NSString *)nameForUser:(STUser *)user
{
	DDLogAutoTrace();
	
	if ([user.networkID isEqualToString:kNetworkID_Production])
	{
		return [user.jid user];
	}
	else
	{
		return [user.jid bare];
	}
}

- (void)removeProgress
{
	DDLogAutoTrace();
	
	[HUD removeFromSuperview];
	HUD = nil;
}

#pragma mark -  ContactsSubViewController methods

- (void)contactsSubViewControllerSelectionDidChange:(ContactsSubViewController *)sender
{
	self.sendButton.enabled = ([sender.selectedUserIds count] > 0);
}

#pragma mark -  SCloudObjectDelegate methods

- (void)scloudObject:(SCloudObject *)sender savingDidStart:(NSString*) mediaType totalSegments:(NSInteger)totalSegments
{
	DDLogAutoTrace();
	
    HUD.labelText = NSLocalizedString(@"Encrypting", @"HUD text");
   	HUD.mode = MBProgressHUDModeAnnularDeterminate;
}

- (void)scloudObject:(SCloudObject *)sender savingProgress:(float) progress
{
	DDLogAutoTrace();
	
  	HUD.progress = progress;
}

- (void)scloudObject:(SCloudObject *)sender savingDidCompleteWithError:(NSError *)error
{
	DDLogAutoTrace();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableView for abContacts
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-(NSArray *)partitionObjects:(NSArray *)array collationStringSelector:(SEL)selector

{
    UILocalizedIndexedCollation *collation = [UILocalizedIndexedCollation currentCollation];
    
    NSInteger sectionCount = [[collation sectionTitles] count];
    NSMutableArray *unsortedSections = [NSMutableArray arrayWithCapacity:sectionCount];
    
    //create an array to hold the data for each section
    for(int i = 0; i <sectionCount; i++)
    {
        [unsortedSections addObject:[NSMutableArray array]];
    }
    
    //put each object into a section
    for (id object in array)
    {
        NSInteger index = [collation sectionForObject:object collationStringSelector:selector];
        [[unsortedSections objectAtIndex:index] addObject:object];
    }
    
    NSMutableArray *sections = [NSMutableArray array];
    
    //sort each section
    for (NSMutableArray *section in unsortedSections)
    {
        //        if(section.count)
        [sections addObject:[collation sortedArrayFromArray:section collationStringSelector:selector]];
    }
    
    return sections;
}

- (void)reloadAddressBookData
{
	XMPPJID *currentUserJID = STDatabaseManager.currentUser.jid;
    
	NSArray *abJidList = [[AddressBookManager sharedInstance] SilentCircleJidsForCurrentUser];
	
	NSMutableArray *abInfoList = [NSMutableArray arrayWithCapacity:abJidList.count];
	for (XMPPJID *jid in abJidList)
	{
		if ([jid isEqualToJID:currentUserJID options:XMPPJIDCompareBare]) {
			continue;
		}

		NSDictionary* abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:jid];
		if (abInfo)
		{
            NSString* displayName = [abInfo objectForKey:kABInfoKey_displayName];
            NSNumber* num = [abInfo objectForKey:kABInfoKey_abRecordID];
            
			ABInfoEntry *entry  = [[ABInfoEntry alloc] initWithABRecordID:num.intValue
			                                                         name:displayName
			                                                       jidStr:[jid bare]];
			[abInfoList addObject: entry];
        }
    }
    addressBookData = abInfoList;
    
    if (addressBookData.count < USE_SECTIONS_THRESHOLD)
		useSectionsForAB = NO;
	else
		useSectionsForAB = YES;
    
    partitionedData = [self partitionObjects:addressBookData collationStringSelector: @selector(name) ];
    
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
    NSInteger sectionCount = 1;
    
    if (selectedSegment == segment_addressbook)
    {
        if (useSectionsForAB)
            sectionCount  = [[[UILocalizedIndexedCollation currentCollation] sectionTitles] count];
    }
  	
    return sectionCount;
    
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    NSInteger rowCount = 0;
    
    if (selectedSegment == segment_addressbook)
    {
        if (useSectionsForAB)
            rowCount = [[partitionedData objectAtIndex:section] count];
        else
            rowCount = [addressBookData count];
    }
	
    return rowCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *cellIdentifier = @"ContactsSubViewControllerCell";
	
	ContactsSubViewControllerCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	cell.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	ABRecordID fetch_avatar_abRecordId = kABRecordInvalidID;
	
	if (selectedSegment == segment_addressbook)
	{
		ABInfoEntry *abEntry = NULL;
		if (useSectionsForAB)
			abEntry = [[partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
		else
			abEntry = [addressBookData objectAtIndex:indexPath.row];
		
		cell.nameLabel.text = abEntry.name;
		
		fetch_avatar_abRecordId = abEntry.abRecordID;
	}
	
	cell.meLabel.text = NULL; //NSLocalizedString(@"me", @"Short designator for contacts");
    
    UIImage *cachedAvatar = [[AvatarManager sharedInstance] cachedAvatarForABRecordID:fetch_avatar_abRecordId
	                                                                     withDiameter:kAvatarDiameter
	                                                                            theme:theme
	                                                                            usage:kAvatarUsage_None
	                                                                  defaultFallback:YES];
	cell.avatarImageView.image  = cachedAvatar;
	cell.abRecordID = fetch_avatar_abRecordId;
	
	if (fetch_avatar_abRecordId != kABRecordInvalidID)
	{
		[[AvatarManager sharedInstance] fetchAvatarForABRecordID:fetch_avatar_abRecordId
		                                            withDiameter:kAvatarDiameter
		                                                   theme:theme
		                                                   usage:kAvatarUsage_None
		                                         completionBlock:^(UIImage *avatar)
		{
			// Make sure the cell is still being used for the userId.
			// During scrolling, the cell may have been recycled.
			if (cell.abRecordID == fetch_avatar_abRecordId)
			{
				cell.avatarImageView.image = avatar;
			}
		}];
	}

	return cell;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)sender
{
    if (selectedSegment == segment_addressbook)
	{
		if (useSectionsForAB)
			return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
		else
			return nil;
	}
	else
	{
		return nil;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    
    if((selectedSegment == segment_addressbook) &&  useSectionsForAB)
    {
        NSInteger rowCount = [[partitionedData objectAtIndex:section] count];
        
        return rowCount?[[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:section] : nil;
        
    }
	else
	{
		return nil;
	}
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [[UILocalizedIndexedCollation currentCollation] sectionForSectionIndexTitleAtIndex:index];
}

- (void)tableView:(UITableView *)sender didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.sendButton.enabled = YES;
    
}
@end
