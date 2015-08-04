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
//  SCAddressbookPicker.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 9/25/13.
//
#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "SCContactBookPicker.h"
#import "SCContactBookPickerCell.h"
#import "AddressBookManager.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "AvatarManager.h"
#import "MBProgressHUD.h"
#import "SCloudObject.h"
#import "SilentTextStrings.h"
#import "Siren.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "STPreferences.h"
#import "STUser.h"
#import "STUserManager.h"

// Categories
#import "UIImage+Thumbnail.h"


// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


#define USE_SECTIONS_THRESHOLD 15
//#define kAvatarDiameter 36
static const CGFloat kAvatarDiameter = 36; //ET 06/11/14

typedef enum {
	segment_stuser = 0,
	segment_addressbook = 1,
} SegmentIndex;



@implementation SCContactBookPicker
{
    YapDatabaseConnection *databaseConnection;
	YapDatabaseViewMappings *mappings;
    
    NSArray             *addressBookData;
 	NSArray             *partitionedData;
    BOOL                useSectionsForAB;
    
	NSString *temp_selectedUserId;
    
    SegmentIndex selectedSegment;

	MBProgressHUD *HUD;
    AppTheme* theme;
}

@synthesize delegate = delegate;
@synthesize isInPopover = isInPopover;
@synthesize needsThumbNail = needsThumbNail;

- (id)initWithDelegate:(id)aDelegate
{
	if ((self = [self initWithProperNib]))
	{
		delegate = aDelegate;
	}
	return self;
}

- (id)initWithProperNib
{
	return [self initWithNibName:@"SCContactBookPicker" bundle:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		// Custom init (if needed)
	}
	return self;
}

- (void)dealloc
{
	DDLogAutoTrace();
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
 }

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handleTranslucentNavBar
{
	DDLogAutoTrace();
	
	CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
	
	CGFloat statusBarHeight = MIN(statusBarFrame.size.width, statusBarFrame.size.height);
	CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
	
	CGFloat topOffset = statusBarHeight + navBarHeight;
	self.tableView.contentInset = UIEdgeInsetsMake(topOffset, 0, 0, 0);
}

- (void)viewDidLoad
{
	DDLogAutoTrace();
    [super viewDidLoad];
   
    theme = [AppTheme getThemeBySelectedKey];
   
    if (AppConstants.isIPhone)
    {
        
        _cancelButton = [[UIBarButtonItem alloc]
                          initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                          target:self
                          action:@selector(cancelButtonAction:)];
        
        self.navigationItem.leftBarButtonItem = _cancelButton;
	}
    
    _sendButton =
	  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
	                                                target:self
	                                                action:@selector(sendButtonAction:)];
	
	self.navigationItem.rightBarButtonItem = _sendButton;
	
	_segment = [[UISegmentedControl alloc] initWithItems:@[@"Silent Contacts",@"Apple"]];
	self.navigationItem.titleView = _segment;
	
	[_segment addTarget:self
	             action:@selector(segmentAction:)
	   forControlEvents:UIControlEventValueChanged];
	
//	self.navigationItem.title = @"Send Contact";
        

    selectedSegment = segment_stuser;
    _segment.selectedSegmentIndex = selectedSegment;

//	[_segment setImage:[UIImage imageNamed:@"seg_silent.png"] forSegmentAtIndex:segment_stuser];
//	[_segment setImage:[UIImage imageNamed:@"seg_contacts.png"] forSegmentAtIndex:segment_addressbook];
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = [UIColor lightGrayColor];
    self.tableView.opaque = NO;
    self.tableView.showsHorizontalScrollIndicator = NO;
    self.tableView.showsVerticalScrollIndicator = YES;
 
	UIColor *bgColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    self.view.backgroundColor = bgColor;
    self.tableView.backgroundColor = bgColor;
    
	// correct for nav bar translucent issues
	if (!isInPopover && self.navigationController.navigationBar.isTranslucent)
	{
		[self handleTranslucentNavBar];
	}

    self.sendButton.enabled = NO;
   
    databaseConnection = STDatabaseManager.uiDatabaseConnection;
	[self initializeMappings];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionWillUpdate:)
	                                             name:UIDatabaseConnectionWillUpdateNotification
	                                           object:STDatabaseManager];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionDidUpdate:)
	                                             name:UIDatabaseConnectionDidUpdateNotification
	                                           object:STDatabaseManager];

  
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(addressBookDidUpdate:)
                                                 name:NOTIFICATION_ADDRESSBOOK_UPDATED
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
	
	if (AppConstants.isIPhone)
	{
		[self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:NO];
	}
	else
	{
		// If nothing is yet selected, then select something
		[self ensureSelectedRow];
	}
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration
{
	DDLogAutoTrace();
	
	CGFloat top = self.navigationController.navigationBar.frame.size.height;
	CGFloat bottom = 0;
	
	UIEdgeInsets edgeInsets = UIEdgeInsetsMake(top, 0, bottom, 0);
	
	self.tableView.contentInset = edgeInsets;
	self.tableView.scrollIndicatorInsets = edgeInsets;
}

- (NSString *)selectedUserId
{
	NSString *userId = nil;
	
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	if (selectedIndexPath)
	{
		userId = [self userIdForIndexPath:selectedIndexPath];
	}
	
	return userId;
}

- (void)setSelectedUserId:(NSString *)userId
{
    NSIndexPath *indexPath = [self indexPathForUserId:userId];
	if (indexPath)
	{
		[self.tableView selectRowAtIndexPath:indexPath
		                            animated:NO
		                      scrollPosition:UITableViewScrollPositionMiddle];
		
		[self didSelectUserId:userId];
	}
	else
	{
		// Maintain whatever is selected
	}
}


-(void) segmentAction:(id)sender{
    
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    selectedSegment = (SegmentIndex)(segmentedControl.selectedSegmentIndex);
    
    if(selectedSegment  == segment_addressbook )
    {
        [self reloadAddressBookData];
    }
    
    [_tableView reloadData];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addressBookDidUpdate:(NSNotification *)notification
{
    if(selectedSegment  == segment_addressbook )
    {
        [self reloadAddressBookData];
    }
    
    [_tableView reloadSectionIndexTitles];
    [_tableView reloadData];
}

- (void)initializeMappings
{
    [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
		if ([transaction ext:Ext_View_SavedContacts])
		{
			NSArray *groups = [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
			
			mappings = [[YapDatabaseViewMappings alloc] initWithGroups:groups view:Ext_View_SavedContacts];
			mappings.isDynamicSectionForAllGroups = YES;
			
			[mappings updateWithTransaction:transaction];
		}
		else
		{
			// The view isn't ready yet.
			// We'll try again when we get a databaseConnectionDidUpdate notification.
		}
    }];
}

- (void)databaseConnectionWillUpdate:(NSNotification *)notification
{
	temp_selectedUserId = [self userIdForIndexPath:[self.tableView indexPathForSelectedRow]];
}

- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
	NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
	
	// If mappings is nil then we need to setup the datasource for the tableView.
	
	if (mappings == nil)
	{
		[self initializeMappings];
		[self.tableView reloadData];
		
		if (AppConstants.isIPad)
		{
			[self ensureSelectedRow];
		}
		return;
	}
	
	// Get the changes as they apply to our view.
	
	NSArray *sectionChanges = nil;
	NSArray *rowChanges = nil;
	
	[[databaseConnection ext:Ext_View_SavedContacts] getSectionChanges:&sectionChanges
	                                                        rowChanges:&rowChanges
	                                                  forNotifications:notifications
	                                                      withMappings:mappings];
	
	if ([sectionChanges count] == 0 && [rowChanges count] == 0)
	{
		// There aren't any changes that affect our tableView
		return;
	}
	
	// Update the tableView, animating the changes
	
	[self.tableView beginUpdates];
	
	for (YapDatabaseViewSectionChange *sectionChange in sectionChanges)
	{
		switch (sectionChange.type)
		{
			case YapDatabaseViewChangeDelete :
			{
				[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
				              withRowAnimation:UITableViewRowAnimationAutomatic];
				break;
			}
			case YapDatabaseViewChangeInsert :
			{
				[self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
				              withRowAnimation:UITableViewRowAnimationAutomatic];
				break;
			}
			default : break;
		}
	}
	
	for (YapDatabaseViewRowChange *rowChange in rowChanges)
	{
		switch (rowChange.type)
		{
			case YapDatabaseViewChangeDelete :
			{
				[self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
				                      withRowAnimation:UITableViewRowAnimationAutomatic];
				break;
			}
			case YapDatabaseViewChangeInsert :
			{
				[self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
				                      withRowAnimation:UITableViewRowAnimationAutomatic];
				break;
			}
			case YapDatabaseViewChangeMove :
			{
				[self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
				                      withRowAnimation:UITableViewRowAnimationAutomatic];
				[self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
				                      withRowAnimation:UITableViewRowAnimationAutomatic];
				break;
			}
			case YapDatabaseViewChangeUpdate :
			{
				[self.tableView reloadRowsAtIndexPaths:@[ rowChange.indexPath ]
				                      withRowAnimation:UITableViewRowAnimationNone];
				break;
			}
		}
	}
	
	[self.tableView endUpdates];
	
	// And try to re-select whatever was selected before
	
	NSIndexPath *indexPath = [self indexPathForUserId:temp_selectedUserId];
	if (indexPath)
	{
		[self.tableView selectRowAtIndexPath:indexPath
		                            animated:NO
		                      scrollPosition:UITableViewScrollPositionNone];
	}
}

- (NSIndexPath *)indexPathForUserId:(NSString *)userId
{
	if (userId == nil) return nil;
	
	__block NSIndexPath *indexPath = nil;
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		indexPath = [[transaction ext:Ext_View_SavedContacts] indexPathForKey:userId
		                                                         inCollection:kSCCollection_STUsers
		                                                         withMappings:mappings];
	}];
	
	return indexPath;
}

- (NSString *)userIdForIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath == nil) return nil;
	
	__block NSString *userId = nil;
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		[[transaction ext:Ext_View_SavedContacts] getKey:&userId
		                                      collection:NULL
		                                     atIndexPath:indexPath
		                                    withMappings:mappings];
	}];
	
	return userId;
}

- (void)didSelectUserId:(NSString *)userId
{
	DDLogAutoTrace();
	
	if (userId)
		self.sendButton.enabled = YES;
	else
		self.sendButton.enabled = NO;
}

- (void)ensureSelectedRow
{
	DDLogAutoTrace();
	
	// If nothing is yet selected, then select something
    
	NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
	
	if (indexPath != nil) return;   // something already selected
	
	if (mappings == nil)    return; // nothing to select
	if ([mappings isEmpty]) return; // nothing to select
	
	// Try to re-select whoever was selected last time
	
	NSString *userId = [STPreferences lastSelectedContactUserId];
	if (userId)
	{
		indexPath = [self indexPathForUserId:userId];
		if (indexPath)
		{
			[self.tableView selectRowAtIndexPath:indexPath
			                            animated:NO
			                      scrollPosition:UITableViewScrollPositionMiddle];
			
			[self didSelectUserId:userId];
		}
	}
	
	// Otherwise just select the first item
	
	if (indexPath == nil)
	{
		indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
		
		[self.tableView selectRowAtIndexPath:indexPath
		                            animated:NO
		                      scrollPosition:UITableViewScrollPositionMiddle];
		
		[self didSelectUserId:[self userIdForIndexPath:indexPath]];
	}
}
#pragma AddressBook functions

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
	DDLogAutoTrace();
	
	addressBookData = [[AddressBookManager sharedInstance] allEntries];
    
    if (addressBookData.count < USE_SECTIONS_THRESHOLD)
		useSectionsForAB = NO;
	else
		useSectionsForAB = YES;

    partitionedData = [self partitionObjects:addressBookData collationStringSelector:@selector(name)];
}

- (UIColor *)colorForNetworkID:(NSString *)networkID
{
	DDLogAutoTrace();
    
    NSDictionary* networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
    UIColor* color = [networkInfo objectForKey:@"displayColor"];
    
    return  color;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableView
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
	NSInteger sectionCount;
	
	if (selectedSegment == segment_stuser)
	{
		sectionCount = [mappings numberOfSections];
	}
	else
	{
		if (useSectionsForAB)
			sectionCount = [[[UILocalizedIndexedCollation currentCollation] sectionTitles] count];
		else
			sectionCount = 1;
	}
	
	return sectionCount;
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
	NSInteger rowCount;
	
	if (selectedSegment == segment_stuser)
    {
        rowCount =  [mappings numberOfItemsInSection:section];
    }
    else
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
	NSString *cellIdentifier = NSStringFromClass([self class]);
    
	SCContactBookPickerCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil)
	{
		cell = [[SCContactBookPickerCell alloc] initWithStyle:UITableViewCellStyleDefault
		                                      reuseIdentifier:cellIdentifier];
		
		cell.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
		cell.textLabel.font = [UIFont systemFontOfSize:16];
	}
	
    STUser *fetch_avatar_user = nil;
    ABRecordID fetch_avatar_abRecordId = kABRecordInvalidID;
	
	UIColor *contactColor = nil;
	
	if (selectedSegment == segment_stuser)
    {
		__block STUser *user = nil;
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			user = [[transaction ext:Ext_View_SavedContacts] objectAtIndexPath:indexPath withMappings:mappings];
		}];
		
		cell.textLabel.text = user.displayName;
		contactColor = [self colorForNetworkID:user.networkID];
		
		fetch_avatar_user = user;
	}
	else
	{
		ABEntry *abEntry = NULL;
		if (useSectionsForAB)
			abEntry = [[partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
		else
			abEntry = [addressBookData objectAtIndex:indexPath.row];
		
		cell.textLabel.text = abEntry.name;
		
		fetch_avatar_abRecordId = abEntry.abRecordID;
	}
	
	cell.textLabel.textColor = contactColor;
   	
    if (fetch_avatar_user)
    {
		if (!cell.imageView.image || ![cell.userId isEqualToString:fetch_avatar_user.uuid])
		{
			UIImage *cachedAvatar =
			  [[AvatarManager sharedInstance] cachedAvatarForUser:fetch_avatar_user
			                                         withDiameter:kAvatarDiameter
			                                                theme:theme
			                                                usage:kAvatarUsage_None
			                                      defaultFallback:YES];
			
			cell.imageView.image = cachedAvatar;
			cell.userId = fetch_avatar_user.uuid;
			cell.abRecordID = kABRecordInvalidID;
		}
		
		NSString *userIdSnapshot = fetch_avatar_user.uuid;
		
		[[AvatarManager sharedInstance] fetchAvatarForUser:fetch_avatar_user
		                                      withDiameter:kAvatarDiameter
		                                             theme:theme
		                                             usage:kAvatarUsage_None
		                                   completionBlock:^(UIImage *avatar)
		{
			// Make sure the cell is still being used for the userId.
			// During scrolling, the cell may have been recycled.
			if ([cell.userId isEqualToString:userIdSnapshot])
			{
				cell.imageView.image = avatar;
			}
		}];
	}
	else
	{
		if (!cell.imageView.image || cell.abRecordID != fetch_avatar_abRecordId)
		{
			UIImage *cachedAvatar =
			  [[AvatarManager sharedInstance] cachedAvatarForABRecordID:fetch_avatar_abRecordId
			                                               withDiameter:kAvatarDiameter
			                                                      theme:theme
			                                                      usage:kAvatarUsage_None
			                                            defaultFallback:YES];
			
			cell.imageView.image = cachedAvatar;
			cell.userId = nil;
			cell.abRecordID = fetch_avatar_abRecordId;
		}
		
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
					cell.imageView.image = avatar;
				}
			}];
		}
	}
	
	return cell;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)sender
{
	if (selectedSegment == segment_stuser)
	{
		if ([mappings isUsingConsolidatedGroup])
			return nil;
		else
			return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
	}
	else if (selectedSegment == segment_addressbook)
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
	if (selectedSegment == segment_stuser)
	{
		if ([mappings isUsingConsolidatedGroup])
		{
			return nil;
		}
		else
		{
			NSString *group = [[mappings visibleGroups] objectAtIndex:section];
			NSInteger originalSection = [[mappings allGroups] indexOfObject:group];
			
			return [[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:originalSection];
		}
	}
    else if ((selectedSegment == segment_addressbook) && useSectionsForAB)
    {
        NSInteger rowCount = [[partitionedData objectAtIndex:section] count];
        
		if (rowCount > 0)
			return [[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:section];
		else
			return nil;
    }
	else
	{
		return nil;
	}
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
	NSArray *allGroups = [mappings allGroups];
	NSArray *visibleGroups = [mappings visibleGroups];
	
	NSUInteger lastVisibleSection = 0;
	NSUInteger visibleSection = 0;
	
	for (NSString *visibleGroup in visibleGroups)
	{
		NSUInteger originalSection = [allGroups indexOfObject:visibleGroup];
		
		if (originalSection == index)
		{
			return visibleSection;
		}
		else if (originalSection > index)
		{
			return lastVisibleSection;
		}
		
		lastVisibleSection = visibleSection;
		visibleSection++;
	}
	
	return lastVisibleSection;
}

- (void)tableView:(UITableView *)sender didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	DDLogAutoTrace();
	
    if (selectedSegment == segment_stuser)
    {
        if (indexPath)
        {
            NSString *userId = [self userIdForIndexPath:indexPath];
            if (userId)
            {
                [self didSelectUserId:userId];
                [STPreferences setLastSelectedContactUserId:userId];
            }
        }
        else
		{
			self.sendButton.enabled = NO;
		}
    }
    else
	{
		self.sendButton.enabled = YES;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)sendButtonAction:(id)sender
{
	DDLogAutoTrace();
	
	NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
	if (indexPath == nil)
	{
		[self cancelButtonAction:sender];
		return;
	}
	
    if ([delegate respondsToSelector:@selector(scAddressBookPicker:didFinishPickingWithSiren:error:)])
    {
        
        __block NSData* vcardData = NULL;
        NSString* displayName = NULL;
        NSString* fileName = NULL;
        UIImage *image = NULL;
        
        
        if(selectedSegment == segment_stuser)
        {
            __block STUser *user = nil;
            
            NSString *userID = [self userIdForIndexPath:indexPath];
            if (userID)
            {
                [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                    
                    user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
                    
                    if(user)
                    {
                        NSString* vcard =  [[STUserManager sharedInstance] vcardForUser:user withTransaction:transaction];
                        vcardData = [vcard dataUsingEncoding:NSUTF8StringEncoding];
                     }
                 }];
                
				image = [[AvatarManager sharedInstance] imageForUser:user];
                
                fileName = user.jid.user;
                displayName = user.displayName;
            }
        }
        else
        {
            ABEntry *abEntry =  NULL;
            
            if(useSectionsForAB)
                abEntry =  [[partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
            else
                abEntry = [addressBookData objectAtIndex:indexPath.row];

            
            vcardData = [[AddressBookManager sharedInstance] vCardDataForABRecordID:abEntry.abRecordID];
            
            image = [[AddressBookManager sharedInstance] imageForABRecordID:abEntry.abRecordID];
            fileName = abEntry.name;
            displayName = abEntry.name;
            
        }
        
        
        if(vcardData && displayName && fileName)
        {
            NSData *previewData = nil;
            if (image)
            {
                // reduce the image thumbnail for a smaller preview
                
                UIImage *cardImage = nil;
                
                UIGraphicsBeginImageContext(CGSizeMake(60, 60));
                [image drawInRect:CGRectMake(0, 0, 60, 60)];
                cardImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                
                previewData = UIImageJPEGRepresentation(cardImage, 1.0);
            }
            
            /* always ensure that the filname has a vcf extension */
            if (fileName) {
                if(![fileName pathExtension] || ![[fileName pathExtension] isEqualToString:@"vcf"])
                    fileName = [fileName stringByAppendingPathExtension:@"vcf"];
            }
            
            NSDictionary *metaData = @{
                                       kSCloudMetaData_MediaType   : (__bridge NSString *)kUTTypeVCard,
                                       kSCloudMetaData_FileName    : fileName,
                                       kSCloudMetaData_DisplayName : displayName,
                                       kSCloudMetaData_FileSize    : [NSNumber numberWithUnsignedInteger:vcardData.length],
                                       };
            
            SCloudObject *scloud = nil;
            scloud = [[SCloudObject alloc] initWithDelegate:self
                                                       data:vcardData
                                                   metaData:metaData
                                                  mediaType:(__bridge NSString *)kUTTypeVCard
                                              contextString:[STDatabaseManager.currentUser.jid full]];
            
            HUD = [[MBProgressHUD alloc] initWithView:self.view];
            HUD.mode = MBProgressHUDModeAnnularDeterminate;
            HUD.labelText = [NSString stringWithFormat:NSLS_COMMON_PREPARING, NSLS_COMMON_CONTACT];
            
            [self.view addSubview:HUD];
            
            __block NSError *error = nil;
            
            [HUD showAnimated:YES whileExecutingBlock:^{
                
                [scloud saveToCacheWithError:&error];
                
            } completionBlock:^{
                
                [HUD removeFromSuperview];
                
                Siren *siren = nil;
                if (!error)
                {
                    siren = Siren.new;
                    siren.mediaType     = (__bridge NSString*) kUTTypeVCard;
                    siren.mimeType      = kMimeType_vCard;
                    siren.cloudKey      = scloud.keyString;
                    siren.cloudLocator  = scloud.locatorString;
     
                    // added this code for ST 1.X compatibiity, we need a thumbnail for that version
                    
                    if(needsThumbNail)
                    {
                        UIImage* cardImage = [UIImage imageNamed:@"vcard@2x"];   // we always use this image for alignment
                        UIImage* personImage = image?image:[UIImage imageNamed:@"defaultPerson"];
                        
                        UIGraphicsBeginImageContext(CGSizeMake(122, 94));
                        [cardImage drawInRect:CGRectMake(0, 0, 122, 94)];
                        [personImage drawInRect:CGRectMake(16, 15, 52, 51)];
                        
                        cardImage = UIGraphicsGetImageFromCurrentImageContext();
                        UIGraphicsEndImageContext();
                        
                        siren.thumbnail = UIImageJPEGRepresentation(cardImage, 1.0);
                    }
                    else
                    {
                        if (previewData)
                            siren.preview = previewData;

                    }
                    

                }
                
                [delegate scAddressBookPicker:self didFinishPickingWithSiren:siren error:error];
            }];
		}
    }
}

- (IBAction)cancelButtonAction:(id)sender
{
	DDLogAutoTrace();
	
    if ([delegate respondsToSelector:@selector(scAddressBookPicker:didFinishPickingWithSiren:error:)])
        [delegate scAddressBookPicker: self  didFinishPickingWithSiren:NULL error:NULL];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SCloudObject
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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


@end
