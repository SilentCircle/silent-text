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
#import "MessageFWDViewController.h"
#import "ContactsSubViewController.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "AddressBookManager.h"
#import "ContactsSubViewControllerCell.h"
#import "UIImage+Thumbnail.h"
#import "AvatarManager.h"
#import "AppTheme.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

#define USE_SECTIONS_THRESHOLD 8

typedef enum {
	segment_stuser = 0,
	segment_addressbook = 1,
} SegmentIndex;

//#define kAvatarDiameter 36
static const CGFloat kAvatarDiameter = 36; //ET 06/11/14


@implementation MessageFWDViewController
{
	Siren *siren;
	
	ContactsSubViewController *contactsSubViewController;
    
    UISegmentedControl      *segment;
    SegmentIndex            selectedSegment;
    
    UIView*                 scContactsView;
    
    UITableView *           abContactsView;
    NSArray                 *addressBookData;
 	NSArray                 *partitionedData;
    BOOL                    useSectionsForAB;
    AppTheme*               theme;

}

@synthesize delegate = delegate;

- (id)initWithDelegate:(id)inDelagate siren:(Siren *)inSiren
{
	if ((self = [self initWithProperNib]))
	{
		delegate = inDelagate;
        siren = inSiren;
	}
	return self;
}

- (id)initWithProperNib
{
 	return [self initWithNibName:@"MessageFWDViewController" bundle:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
        self.title = NSLocalizedString(@"Forward Message", @"Popover title");

		STLocalUser *currentUser = STDatabaseManager.currentUser;
		
        [STDatabaseManager configureFilteredContactsDBView:currentUser.networkID
                                                withUserId:currentUser.uuid];
 	}
	return self;
}

- (void)dealloc
{
	[STDatabaseManager teardownFilteredContactsDBView];
}

- (void)viewDidLoad
{
	DDLogAutoTrace();
    [super viewDidLoad];
    
    theme = [AppTheme getThemeBySelectedKey];

	self.view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
	
	
	if (AppConstants.isIPhone)
	{
		self.cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
		                                                                  target:self
		                                                                  action:@selector(cancelButtonAction:)];
		self.navigationItem.leftBarButtonItem = self.cancelButton;
	}
//	else {
//		self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
//		self.navigationController.navigationBar.translucent = YES;
//	}
    
    self.sendButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                    target:self
                                                                    action:@selector(sendButtonAction:)];
    
	self.sendButton.enabled = NO;
	self.navigationItem.rightBarButtonItem = self.sendButton;
    
    contactsSubViewController =
	  [[ContactsSubViewController alloc] initWithDatabaseViewName:Ext_View_FilteredContacts delegate:self];
	
	contactsSubViewController.allowsDeletion = NO;
	contactsSubViewController.ensuresSelection = NO;
	contactsSubViewController.checkmarkSelectedCells = YES;
	
	contactsSubViewController.view.frame = self.view.bounds;
	contactsSubViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |
	                                                  UIViewAutoresizingFlexibleHeight;
	
    scContactsView = contactsSubViewController.view;
    
	[self.view addSubview:scContactsView];
	[self addChildViewController:contactsSubViewController];
	   
    abContactsView = [[UITableView alloc]initWithFrame:self.view.bounds style:UITableViewStylePlain];
    abContactsView.backgroundColor =  [UIColor colorWithWhite: .95 alpha:1];
    abContactsView.rowHeight = 46;
	abContactsView.separatorInset = UIEdgeInsetsMake(0, (10+46+8), 0, 0); // top, left, bottom, right
    abContactsView.delegate = self;
    abContactsView.dataSource = self;
    abContactsView.frame = self.view.bounds;
    abContactsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    
    UINib *cellNib = [UINib nibWithNibName:@"ContactsSubViewControllerCell" bundle:nil];
	[abContactsView registerNib:cellNib forCellReuseIdentifier:@"ContactsSubViewControllerCell"];

    [self.view addSubview:abContactsView];
    
    segment = [[UISegmentedControl alloc] initWithItems:@[@"Silent Contacts",@"Apple"]];
    selectedSegment = segment_stuser;
    segment.selectedSegmentIndex = selectedSegment;
    
    [self reloadAddressBookData];
    if(addressBookData.count)
    {
        self.navigationItem.titleView = segment;
       
        //  correct for nav bar translucent issues
        if(self.navigationController.navigationBar.isTranslucent)
        {
            CGSize statusbarsize = AppConstants.isIPhone ? [UIApplication sharedApplication].statusBarFrame.size : CGSizeZero;
            size_t offset = self.navigationController.navigationBar.frame.size.height + MIN(statusbarsize.height, statusbarsize.width);
            CGRect  frame;
            
            frame = abContactsView.frame;
            frame.origin.y += offset;
            frame.size.height -= offset;
            abContactsView.frame = frame;
  
        }
        
        [segment addTarget:self
                    action:@selector(segmentAction:)
          forControlEvents:UIControlEventValueChanged];
     }

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
    

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)contactsSubViewControllerSelectionDidChange:(ContactsSubViewController *)sender
{
	self.sendButton.enabled = ([sender.selectedUserIds count] > 0);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)cancelButtonAction:(id)sender
{
	if ([delegate respondsToSelector:@selector(messageFWDViewController:messageFWDWithSiren:recipients:error:)])
		[delegate messageFWDViewController:self messageFWDWithSiren:NULL recipients:NULL error:NULL];
}

- (IBAction)sendButtonAction:(id)sender
{
    if(selectedSegment  == segment_addressbook )
    {
        NSIndexPath *indexPath = [abContactsView indexPathForSelectedRow];
        
        if (indexPath == nil)
        {
            [self cancelButtonAction:sender];
            return;
        }
        
        
        ABInfoEntry  *abEntry = NULL;
        
        if(useSectionsForAB)
            abEntry =  [[partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        else
            abEntry = [addressBookData objectAtIndex:indexPath.row];
        
        if(abEntry)
        {
             if ([delegate respondsToSelector:@selector(messageFWDViewController:messageFWDWithSiren:selectedJid:displayName:error:)])
            [delegate messageFWDViewController:self messageFWDWithSiren:siren selectedJid:abEntry.jidStr displayName:abEntry.name error:NULL];
        
         }
    }
 
    else
    {
     	NSString *selectedUserId = [contactsSubViewController selectedUserId];
        if (selectedUserId == nil)
        {
            [self cancelButtonAction:sender];
            return;
        }
        else
        {
            NSMutableArray *recipients = [NSMutableArray array];
            
            YapDatabaseConnection *databaseConnection = STDatabaseManager.uiDatabaseConnection;
            [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                
                STUser *user = [transaction objectForKey:selectedUserId inCollection:kSCCollection_STUsers];
                if (user) {
                    [recipients addObject:user.jid];
                }
            }];
            
            if ([delegate respondsToSelector:@selector(messageFWDViewController:messageFWDWithSiren:recipients:error:)])
                [delegate messageFWDViewController:self messageFWDWithSiren:siren recipients:recipients error:NULL];
        }
    }

}


-(void) segmentAction:(id)sender{
    
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    selectedSegment = (SegmentIndex)(segmentedControl.selectedSegmentIndex);
    
    if(selectedSegment  == segment_addressbook )
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


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableView for abContacts
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
	XMPPJID *currentUserJID = STDatabaseManager.currentUser.jid;
	
	NSArray *abJidList = [[AddressBookManager sharedInstance] SilentCircleJidsForCurrentUser];
	
	NSMutableArray *abInfoList = [NSMutableArray arrayWithCapacity:abJidList.count];
	for (XMPPJID *jid in abJidList)
	{
		if ([jid isEqualToJID:currentUserJID options:XMPPJIDCompareBare]) {
			continue;
		}
		
        NSDictionary *abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:jid];
		if (abInfo)
		{
            NSString* displayName = [abInfo objectForKey:kABInfoKey_displayName];
            NSNumber* num = [abInfo objectForKey:kABInfoKey_abRecordID];
            
			ABInfoEntry *entry = [[ABInfoEntry alloc] initWithABRecordID:num.intValue
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
        if(useSectionsForAB)
            abEntry =  [[partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
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
