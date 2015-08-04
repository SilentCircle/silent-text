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
#import "ContactsSubViewController.h"
#import "ContactsSubViewControllerCell.h"
#import "ContactsSubViewControllerHeader.h"
#import "ConversationDetailsBaseVC.h"
#import "AppDelegate.h"
#import "AppConstants.h"
//#import "UserInfoViewController.h"
#import "AvatarManager.h"
#import "MessageStream.h"
#import "PersonSearchResult.h"
#import "UIImage+Thumbnail.h"
#import "SCWebAPIManager.h"
#import "STLocalUser.h"
#import "STPreferences.h"
#import "STUser.h"
#import "STUserManager.h"
#import "STLogging.h"
#import "AppTheme.h"
#import "OHActionSheet.h"
#import "SilentTextStrings.h"


// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

#define USE_SC_DIRECTORY_SEARCH   1
#define USE_SECTIONS_THRESHOLD   15

static const CGFloat kAvatarDiameter = 36;


@implementation ContactsSubViewController
{
	YapDatabaseConnection *databaseConnection;
	YapDatabaseViewMappings *mappings;
	
	NSString *pending_selectedUserId;
	
	NSMutableSet *checkmarkedUserIds; // For multiselection
	
	NSIndexPath *temp_selectedIndexPath;
	NSString *temp_selectedUserId;
	NSString *temp_selectedGroup;
	NSUInteger temp_selectedRow;
	
	NSString *previousSelectedUserId;
	
	AppTheme *theme;
}

@synthesize parentViewName = parentViewName;
@synthesize filteredViewName = filteredViewName;

@synthesize delegate = delegate;

@synthesize ensuresSelection = ensuresSelection;
@synthesize usesMultipleSelection = usesMultipleSelection;
@synthesize allowsDeletion = allowsDeletion;

+ (NSString *)generateRandomFilteredViewName
{
	NSString *base = @"filteredContacts_";
	NSString *uuid = [[NSUUID UUID] UUIDString];
	
	return [base stringByAppendingString:uuid];
}

- (id)initWithDatabaseViewName:(NSString *)viewName delegate:(id)inDelegate
{
	if ((self = [super initWithNibName:@"ContactsSubViewController" bundle:nil]))
	{
		parentViewName = [viewName copy];
		filteredViewName = [[self class] generateRandomFilteredViewName];
		
		delegate = inDelegate;
		
		checkmarkedUserIds = [[NSMutableSet alloc] initWithCapacity:1];
		
		[self setupContactsFilter];
	}
	return self;
}

- (void)dealloc
{
	DDLogAutoTrace();
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self teardownContactsFilter];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
	DDLogAutoTrace();
    [super viewDidLoad];
	
	self.view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
	
	self.tableView.rowHeight = 46;
	self.tableView.separatorInset = UIEdgeInsetsMake(0, (10+46+8), 0, 0); // top, left, bottom, right
	
	UINib *cellNib = [UINib nibWithNibName:@"ContactsSubViewControllerCell" bundle:nil];
	[self.tableView registerNib:cellNib forCellReuseIdentifier:@"ContactsSubViewControllerCell"];

	UINib *headerNib = [UINib nibWithNibName:@"ContactsSubViewControllerHeader" bundle:nil];
	[self.tableView registerNib:headerNib forHeaderFooterViewReuseIdentifier:@"ContactsSubViewControllerHeader"];

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
											 selector:@selector(changeTheme:)
												 name:kAppThemeChangeNotification
											   object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
	
	// Is this method improperly resetting the selection on you?
	// Here's the problem, from the docs UITableViewController (superclass):
	//
	// > When the table view is about to appear the first time it’s loaded, ...
	// > It also clears its selection (with or without animation, depending on the request) every time
	// > the table view is displayed. The UITableViewController class implements this in the superclass
	// > method viewWillAppear:. You can disable this behavior by changing the value
	// > in the clearsSelectionOnViewWillAppear property.
	//
	// On iPhone, this is typically the right thing to do.
	// But on iPad, this can wrong.
	//
	// For example, in the ContactsViewController, if we display the MoveAndScaleImageViewController full screen,
	// and then return, our superclass will clear the selection. And even if we aborted from this method,
	// we would still have a bug because the tableView would lose its selection.
	//
	// So this problem is best solved in whatever class is embedding this one.
	// Do something like the following to fix it:
	//
	// if (AppConstants.isIPad) {
	//     contactsSubViewController.clearsSelectionOnViewWillAppear = NO;
	// }
	
	if (self.ensuresSelection)
	{
		// Note: If mappings is nil then the tableView isn't ready yet
		
		if (mappings != nil)
		{
			// If nothing is yet selected, then select something
			[self ensureSelection];
		}
	}
	else
	{
		if (previousSelectedUserId) {
			NSIndexPath *prevIndexPath = [self indexPathForUserId:previousSelectedUserId];
			if (prevIndexPath) {
				ContactsSubViewControllerCell *cell = (ContactsSubViewControllerCell *)[self.tableView cellForRowAtIndexPath:prevIndexPath];
				if (cell)
					cell.expanded = NO;
			}
			previousSelectedUserId = nil;
		}
		NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
		if (selectedIndexPath)
			[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];
		if ([checkmarkedUserIds count] > 0) {
			[checkmarkedUserIds removeAllObjects];
			[self.tableView reloadData]; // only way to clear any lingering checkmarks
		}
	}
	theme = [AppTheme getThemeBySelectedKey];
}

- (void)changeTheme:(NSNotification *)notification
{	
	NSDictionary *userInfo = notification.userInfo;
	if (userInfo)
		theme = userInfo[kNotificationUserInfoTheme];
	else
		theme = [AppTheme getThemeBySelectedKey];

	[self.tableView reloadData];
}

- (NSString *)selectedUserId
{
	if (usesMultipleSelection)
	{
		// You should be using selectedUserIds (to get all selections)
		
		return [checkmarkedUserIds anyObject];
	}
	else
	{
		NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
		return [self userIdForIndexPath:selectedIndexPath];
	}
}

// may return a PersonSearchResult or STUser
- (NSObject *)selectedUser {
	if (usesMultipleSelection)
	{
		return nil; // not supported
	}
	else
	{
		NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
		if (selectedIndexPath.section == [self numberOfMappedSections]) {
			// must be in the secondaryResults
			if (_secondaryResultsArray) {
				PersonSearchResult *person = [_secondaryResultsArray objectAtIndex:selectedIndexPath.row];
				return person;
			}
		}
		NSString *userId = [self userIdForIndexPath:selectedIndexPath];
		return [self userForUserId:userId];
	}
}

- (void)setSelectedUserId:(NSString *)userId
{
	DDLogAutoTrace();
	
	if (mappings == nil)
	{
		DDLogVerbose(@"pending_selectedUserId = %@", userId);
		pending_selectedUserId = userId;
		return;
	}
	
    NSIndexPath *indexPath = [self indexPathForUserId:userId];
	if (indexPath)
	{
		[self.tableView selectRowAtIndexPath:indexPath
		                            animated:NO
		                      scrollPosition:UITableViewScrollPositionMiddle];
		
		[self didSelectUserId:userId];
//		if ([delegate respondsToSelector:@selector(contactsSubViewControllerSelectionDidChange:)])
//			[delegate contactsSubViewControllerSelectionDidChange:self];
	}
	else
	{
		// Maintain whatever is selected
	}
}

- (NSArray *)selectedUserIds
{
	if (usesMultipleSelection)
	{
		return [checkmarkedUserIds allObjects];
	}
	else
	{
		// You should be use using selectedUserId
		
		NSString *selectedUserId = [self selectedUserId];
		if (selectedUserId)
			return @[ selectedUserId ];
		else
			return nil;
	}
}

- (void)setSelectedUserIds:(NSArray *)newSelectedUserIds
{
	DDLogAutoTrace();
	
	if (usesMultipleSelection)
	{
		[checkmarkedUserIds removeAllObjects];
		[checkmarkedUserIds addObjectsFromArray:newSelectedUserIds];
		
		if (self.isViewLoaded)
		{
			[self.tableView reloadData];
		}
	}
	else
	{
		// You should be use using setSelectedUserId
		
		if ([newSelectedUserIds count] > 0)
		{
			[self setSelectedUserId:[newSelectedUserIds objectAtIndex:0]];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)initializeMappings
{
	DDLogAutoTrace();
	
    [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
		if ([transaction ext:filteredViewName])
		{
			NSArray *groups = [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
			
			mappings = [[YapDatabaseViewMappings alloc] initWithGroups:groups view:filteredViewName];
			mappings.isDynamicSectionForAllGroups = YES;
			
			[mappings setAutoConsolidateGroupsThreshold:USE_SECTIONS_THRESHOLD withName:@"flat"];
			
			[mappings updateWithTransaction:transaction];
			
			DDLogVerbose(@"mappings ready");
		}
		else
		{
			// The view isn't ready yet.
			// We'll try again when we get a databaseConnectionDidUpdate notification.
			
			DDLogVerbose(@"mappings not ready yet (waiting for view)");
		}
    }];
}


- (void)setSecondaryResultsArray:(NSArray *)secondaryResultsArray {
	_secondaryResultsArray = (secondaryResultsArray) ? [[NSMutableArray alloc] initWithArray:secondaryResultsArray] : nil;
	BOOL bHasResults = ((_secondaryResultsArray) && ([_secondaryResultsArray count] > 0));
	
	NSUInteger numMappedSections = [self numberOfMappedSections];
	NSIndexSet *sectionSet = [NSIndexSet indexSetWithIndex:numMappedSections];

	if ([self.tableView numberOfSections] > numMappedSections) {
		if (bHasResults)
			[self.tableView reloadSections:sectionSet withRowAnimation:UITableViewRowAnimationAutomatic];
		else
			[self.tableView deleteSections:sectionSet withRowAnimation:UITableViewRowAnimationAutomatic];
	} else if (bHasResults)
		[self.tableView insertSections:sectionSet withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (YapDatabaseViewFilteringWithObjectBlock)generateContactsFilterBlock:(NSString *)inFilterString
{
	// It's important to understand that the filterBlock will be executing on a background thread.
	// So if we have code like this within the block:
	//
	// if (ivar) // ...
	//
	// Then what we really have within the block is this:
	//
	// if (self->ivar) // ...
	//
	// Which first of all is retaining self.
	// And second of all is NOT thread-safe.
	//
	// Thus it's important that we snapshot the information we need.
	// And then operate on the snapshot'ed information within the block.
	
	NSString *filterString = [inFilterString copy];
	
	return ^BOOL (NSString *group, NSString *collection, NSString *key, id object) {
		
		if ( (!filterString) || ([filterString length] == 0) ) {
			return YES;
		}
		
		__unsafe_unretained STUser *user = (STUser *)object; // just cast, don't retain
		
		NSRange range = [user.displayName rangeOfString:filterString options:NSCaseInsensitiveSearch];
		return (range.location != NSNotFound);
	};
}

- (void)setupContactsFilter
{
	DDLogAutoTrace();
	
	NSString *filterString = nil;
	
	YapDatabaseViewFilteringWithObjectBlock filterBlock = [self generateContactsFilterBlock:filterString];
	YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withObjectBlock:filterBlock];
	
	YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
	options.isPersistent = NO;
	
	YapDatabaseFilteredView *filteredView =
	  [[YapDatabaseFilteredView alloc] initWithParentViewName:parentViewName
	                                                filtering:filtering
	                                               versionTag:filterString
	                                                  options:options];
	
	YapDatabase *database = STDatabaseManager.database;
	NSString *filteredViewNameSnapshot = filteredViewName;
	
	[database asyncRegisterExtension:filteredView withName:filteredViewName completionBlock:^(BOOL ready) {
		
		if (ready) {
			DDLogInfo(@"Filtered contacts view registered: %@", filteredViewNameSnapshot);
		}
		else {
			DDLogError(@"Error registering filtered contacts view: %@", filteredViewNameSnapshot);
		}
	}];
}

- (void)teardownContactsFilter
{
	DDLogAutoTrace();
	
	YapDatabase *database = STDatabaseManager.database;
	NSString *filteredViewNameSnapshot = filteredViewName; // protecting against block retaining self
	
	[database asyncUnregisterExtensionWithName:filteredViewName completionBlock:^{
		
		DDLogInfo(@"Filtered contacts view UNregistered: %@", filteredViewNameSnapshot);
	}];
}

- (void)filterContacts:(NSString *)inFilterString
{
	DDLogAutoTrace();
	
	NSString *filterString = [inFilterString copy]; // mutable string protection
	
	YapDatabaseViewFilteringBlock filterBlock = [self generateContactsFilterBlock:filterString];
	YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withObjectBlock:filterBlock];
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	NSString *filteredViewNameSnapshot = filteredViewName; // protecting against block retaining self
	
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		[[transaction ext:filteredViewNameSnapshot] setFiltering:filtering versionTag:filterString];
	}];
}

- (void)databaseConnectionWillUpdate:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	if (!temp_selectedIndexPath && !usesMultipleSelection)
		temp_selectedIndexPath = [self.tableView indexPathForSelectedRow];
	
	if (temp_selectedIndexPath)
	{
		temp_selectedUserId = [self userIdForIndexPath:temp_selectedIndexPath];
		
		NSString *group = nil;
		[mappings getGroup:&group index:NULL forIndexPath:temp_selectedIndexPath];
		
		temp_selectedGroup = group;
		temp_selectedRow = temp_selectedIndexPath.row;
	}
	else
	{
		temp_selectedUserId = nil;
		
		temp_selectedGroup = nil;
		temp_selectedRow = 0;
	}
}

- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
	
	// If mappings is nil then we need to setup the datasource for the tableView.
	
	if (mappings == nil)
	{
		[self initializeMappings];
		[self.tableView reloadData];
		
		if (self.ensuresSelection) {
			[self ensureSelection];
		}
		
		return;
	}
	
	// Get the changes as they apply to our view.
	
	NSArray *sectionChanges = nil;
	NSArray *rowChanges = nil;
	
	[[databaseConnection ext:filteredViewName] getSectionChanges:&sectionChanges
	                                                  rowChanges:&rowChanges
	                                            forNotifications:notifications
	                                                withMappings:mappings];
	
	if (([sectionChanges count] == 0) && ([rowChanges count] == 0))
	{
		// There aren't any changes that affect our tableView.
		// Clear all temp variables and return.
		
		temp_selectedIndexPath = nil;
		temp_selectedUserId = nil;
		temp_selectedGroup = nil;
		temp_selectedRow = 0;
		
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
				              withRowAnimation:UITableViewRowAnimationFade];
				break;
			}
			case YapDatabaseViewChangeInsert :
			{
				[self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
				              withRowAnimation:UITableViewRowAnimationFade];
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
				                      withRowAnimation:UITableViewRowAnimationFade];
				break;
			}
			case YapDatabaseViewChangeInsert :
			{
				[self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
				                      withRowAnimation:UITableViewRowAnimationFade];
				break;
			}
			case YapDatabaseViewChangeMove :
			{
				[self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
				                      withRowAnimation:UITableViewRowAnimationFade];
				[self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
				                      withRowAnimation:UITableViewRowAnimationFade];
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
	
	temp_selectedIndexPath = nil;
	[self.tableView endUpdates]; // <- invokes tableView:didEndEditingRowAtIndexPath: if was editing
	
	if (temp_selectedUserId || self.ensuresSelection)
	{
		// Try to re-select whatever was selected before.
		// If not possible, then ensure select something close to whatever was selected before.
		
		NSIndexPath *nearestIndexPath = nil;
		BOOL useFallback = NO;
		
		if (self.ensuresSelection)
		{
			nearestIndexPath = [mappings nearestIndexPathForRow:temp_selectedRow inGroup:temp_selectedGroup];
			useFallback = YES;
		}
		
		[self selectRowPreferringUserId:temp_selectedUserId
		                    orIndexPath:nearestIndexPath
		                     orFallback:useFallback
		                 scrollPosition:UITableViewScrollPositionNone];
	}
	
	// Clear all temp variables
	
	temp_selectedIndexPath = nil;
	temp_selectedUserId = nil;
	temp_selectedGroup = nil;
	temp_selectedRow = 0;
}

- (NSIndexPath *)indexPathForUserId:(NSString *)userId
{
	if (userId == nil) return nil;
	
	__block NSString *group = nil;
	__block NSUInteger index = 0;
	
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		// Ask the view where this particular key is.
		// It will tell use the group and index (within the group) for the collection/key tuple.
		
		[[transaction ext:filteredViewName] getGroup:&group
		                                       index:&index
		                                      forKey:userId
		                                inCollection:kSCCollection_STUsers];
	}];
	
	if (group == nil) {
		__block NSIndexPath *indexPath = nil;
		if (_secondaryResultsArray) {
			[_secondaryResultsArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
				PersonSearchResult *person = (PersonSearchResult *)obj;
				if ([userId isEqualToString:person.jid]) {
					indexPath = [NSIndexPath indexPathForRow:idx inSection:[self numberOfMappedSections]];
					*stop = YES;
				}
			}];
		}
		return indexPath;
	}
	
	return [mappings indexPathForIndex:index inGroup:group];
}

- (NSString *)userIdForIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath == nil)
		return nil;

	if (indexPath.section == [self numberOfMappedSections]) {
		// must be in the secondaryResults
		if (_secondaryResultsArray) {
			PersonSearchResult *person = [_secondaryResultsArray objectAtIndex:indexPath.row];
			if (person)
				return person.jid;
		}
	} else {
		NSString *group = nil;
		NSUInteger index = 0;
		
		[mappings getGroup:&group index:&index forIndexPath:indexPath];
		
		__block NSString *userId = nil;
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			userId = [[transaction ext:filteredViewName] keyAtIndex:index inGroup:group];
		}];
		
		return userId;
	}
	
	return nil;
}

- (void)didSelectUserId:(NSString *)userId
{
	if (![userId isEqualToString:previousSelectedUserId])
	{
		previousSelectedUserId = userId;
		if ([delegate respondsToSelector:@selector(contactsSubViewControllerSelectionDidChange:)])
			[delegate contactsSubViewControllerSelectionDidChange:self];

		if (!usesMultipleSelection) {
			[checkmarkedUserIds removeAllObjects];
			[checkmarkedUserIds addObject:userId];
		}
	}
}

/**
 * This method intelligently selects something.
 *
 * @param preferredUserId (optional)
 *   If the userId exists in the tableView, it will be selected.
 *
 * @param preferredIndexPath (optional)
 *   If the preferredUserId wasn't available, the preferredIndexPath will act as a backup.
 *   It will be selected if the given indexPath is valid.
 *
 * @param useFallback
 *   If both the preferredUserId & preferredIndexPath fail,
 *   then setting useFallback to YES will select the first item in the tableView.
 *
 * @param scrollPosition
 *   Whether and how to scroll to the selected row.
 **/
- (void)selectRowPreferringUserId:(NSString *)preferredUserId
                      orIndexPath:(NSIndexPath *)preferredIndexPath
                       orFallback:(BOOL)useFallback
                   scrollPosition:(UITableViewScrollPosition)scrollPosition
{
	if (mappings == nil)    return; // nothing to select
	if ([mappings isEmpty]) return; // nothing to select
	
	// First try to select the preferredUserId
	
	if (preferredUserId)
	{
		NSIndexPath *indexPath = [self indexPathForUserId:preferredUserId];
		if (indexPath)
		{
			[self.tableView selectRowAtIndexPath:indexPath
			                            animated:NO
			                      scrollPosition:scrollPosition];
			
			[self didSelectUserId:preferredUserId];
			return;
		}
	}
	
	// If that doesn't work, try the preferredIndexPath.
	// This is likely the previous location of the preferredUserId or something close to it.
	// So if the user is deleted, we re-select something right next to it.
	
	if (preferredIndexPath)
	{
		if (preferredIndexPath.section < [mappings numberOfSections] &&
		    preferredIndexPath.row < [mappings numberOfItemsInSection:preferredIndexPath.section])
		{
			[self.tableView selectRowAtIndexPath:preferredIndexPath
			                            animated:NO
			                      scrollPosition:UITableViewScrollPositionMiddle];
			
			[self didSelectUserId:[self userIdForIndexPath:preferredIndexPath]];
			return;
		}
	}
	
	if (useFallback)
	{
		// Fallback to selecting the first row
		
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
		[self.tableView selectRowAtIndexPath:indexPath
		                            animated:NO
		                      scrollPosition:UITableViewScrollPositionMiddle];
        
		[self didSelectUserId:[self userIdForIndexPath:indexPath]];
	}
}

- (void)ensureSelection
{
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	if (selectedIndexPath == nil)
	{
		// A pending_selectedUserId will be set if setSelectedUserId was invoked,
		// but we were unable to complete the task because the tableView wasn't ready yet.
		
		NSString *userId = pending_selectedUserId;
		pending_selectedUserId = nil;
		
		[self selectRowPreferringUserId:userId
		                    orIndexPath:nil
		                     orFallback:YES
		                 scrollPosition:UITableViewScrollPositionMiddle];
	}
}

- (UIColor *)colorForNetworkID:(NSString*)networkID
{
	NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
	UIColor *color = [networkInfo objectForKey:@"displayColor"];
	
	return color;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableView
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSInteger)numberOfMappedSections {
	return (NSInteger)[mappings numberOfSections];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
	NSInteger numSections = [self numberOfMappedSections];
	if ([_secondaryResultsArray count] > 0)
		numSections++;
	return numSections;
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
	if (section < [self numberOfMappedSections])
		return [mappings numberOfItemsInSection:section];

	return [_secondaryResultsArray count];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)sender
{
	if ([mappings numberOfItemsInAllGroups] < USE_SECTIONS_THRESHOLD)
	{
		// Don't display sections
		return nil;
	}
	else
	{
		return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if ([mappings numberOfItemsInAllGroups] < USE_SECTIONS_THRESHOLD)
	{
		// Don't display sections
		return nil;
	}
	else
	{
		if (section < [self numberOfMappedSections]) {
			// The given section represents a visible section.
			// We need to get the title out of all possible sections.
			
			NSString *group = [[mappings visibleGroups] objectAtIndex:section];
			NSInteger originalSection = [[mappings allGroups] indexOfObject:group];
			
			return [[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:originalSection];
		}
		return nil;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if (section < [self numberOfMappedSections])
		return 0;
	
	return [ContactsSubViewControllerHeader cellHeight];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if (section < [self numberOfMappedSections])
			return nil; // no header view for mapped sections
	
	NSString *cellIdentifier = @"ContactsSubViewControllerHeader";
	ContactsSubViewControllerHeader *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:cellIdentifier];
	headerView.backgroundColor = [UIColor redColor];
	headerView.titleLabel.text = STDatabaseManager.currentUser.organization;
	return headerView;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
	if (index < [self numberOfMappedSections]) {
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
	
	return 0; // TODO: support for _secondaryResultsArray
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *cellIdentifier = @"ContactsSubViewControllerCell";
	ContactsSubViewControllerCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	cell.delegate = self;

	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	
	ContactsSubViewControllerCell *subCell = (ContactsSubViewControllerCell *)cell;
	subCell.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
	
	if (indexPath.section < [self numberOfMappedSections])
	{
		__block STUser *user = nil;
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			user = [[transaction ext:filteredViewName] objectAtIndexPath:indexPath withMappings:mappings];
		}];
		
		UIColor *contactColor = [self colorForNetworkID:user.networkID];
		subCell.nameLabel.textColor = contactColor ? contactColor : [UIColor blackColor];
		
		subCell.nameLabel.text = user.displayName;
		
		if (user.isRemote)
			subCell.meLabel.text = nil;
		else
			subCell.meLabel.text = NSLocalizedString(@"me", @"Short designator for contacts");
		subCell.jid = nil; // this kind of subcell uses userId, not jid
		
		subCell.isSavedToSilentContacts = user.isSavedToSilentContacts;
		subCell.expanded = (  (_expandsSelectedContact)
		                   && (user.isRemote)
		                   && ([user.uuid isEqualToString:previousSelectedUserId]) );

		if ( (_checkmarkSelectedCells) && ([checkmarkedUserIds containsObject:user.uuid]) )
			subCell.accessoryType = UITableViewCellAccessoryCheckmark;
		else
			subCell.accessoryType = UITableViewCellAccessoryNone;
		
		if (!subCell.avatarImageView.image || ![subCell.userId isEqualToString:user.uuid])
		{
			UIImage *cachedAvatar =
			  [[AvatarManager sharedInstance] cachedAvatarForUser:user
			                                         withDiameter:kAvatarDiameter
			                                                theme:theme
			                                                usage:kAvatarUsage_None
			                                      defaultFallback:YES];
			
			subCell.avatarImageView.image = cachedAvatar;
			subCell.userId = user.uuid;
			subCell.abRecordID = kABRecordInvalidID;
			subCell.avatarUrl = nil;
		}
		
		NSString *userIdSnapshot = user.uuid;
		
		[[AvatarManager sharedInstance] fetchAvatarForUser:user
		                                      withDiameter:kAvatarDiameter
		                                             theme:theme
		                                             usage:kAvatarUsage_None
		                                   completionBlock:^(UIImage *avatar)
		{
			// Make sure the cell is still being used for the same user.
			// During scrolling, the cell may have been recycled.
			if ([subCell.userId isEqualToString:userIdSnapshot])
			{
				subCell.avatarImageView.image = avatar;
			}
		}];
	}
	else
	{
		subCell.nameLabel.textColor = [UIColor blackColor];
		subCell.meLabel.text = nil;
		subCell.userId = nil; // this kind of cell uses jid, not userId

		PersonSearchResult *person = [_secondaryResultsArray objectAtIndex:indexPath.row];
		if (person) {
			subCell.nameLabel.text = person.fullName;
			subCell.jid = person.jid;
		} else {
			subCell.nameLabel.text = @"";
			subCell.jid = nil;
		}
		
		subCell.isSavedToSilentContacts = NO;
		subCell.expanded = ( (_expandsSelectedContact) && ([person.jid isEqualToString:previousSelectedUserId]) );
		
		if ( (_checkmarkSelectedCells) && (!subCell.expanded) && ([checkmarkedUserIds containsObject:person.jid]) )
			subCell.accessoryType = UITableViewCellAccessoryCheckmark;
		else
			subCell.accessoryType = UITableViewCellAccessoryNone;

		STLocalUser *currentUser = STDatabaseManager.currentUser;
		UIImage *downloadedAvatar = nil;
		
		if (person.avatarURL && ![subCell.avatarUrl isEqualToString:person.avatarURL])
		{
			downloadedAvatar =
			  [[AvatarManager sharedInstance] cachedAvatarForURL:person.avatarURL
			                                           networkID:currentUser.networkID
			                                        withDiameter:kAvatarDiameter
			                                               theme:theme
			                                               usage:kAvatarUsage_None
			                                     defaultFallback:NO];
			
			subCell.avatarImageView.image = downloadedAvatar;
			subCell.abRecordID = kABRecordInvalidID;
			subCell.avatarUrl = person.avatarURL;
		}
		
		if (!subCell.avatarImageView.image)
		{
			subCell.avatarImageView.image = [[AvatarManager sharedInstance] defaultAvatarWithDiameter:kAvatarDiameter];
		}
		
		if (person.avatarURL && !downloadedAvatar)
		{
			// Important:
			//
			// We should ONLY ever download the avatar (from the server) if it wasn't cached.
			// Otherwise we're just wasting bandwidth.
			
			NSString *avatarUrlSnapshot = [person.avatarURL copy];
			
			[[AvatarManager sharedInstance] downloadAvatarForURL:person.avatarURL
			                                           networkID:currentUser.networkID
			                                        withDiameter:kAvatarDiameter
			                                               theme:theme
			                                               usage:kAvatarUsage_None
			                                     completionBlock:^(UIImage *avatar)
			{
				// Make sure the cell is still being used for the same person.
				// During scrolling, the cell may have been recycled.
				if ([subCell.avatarUrl isEqualToString:avatarUrlSnapshot])
				{
					subCell.avatarImageView.image = avatar;
				}
			}];
		}
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {

	if (previousSelectedUserId) {
		NSString *userId = [self userIdForIndexPath:indexPath];
		if ([userId isEqualToString:previousSelectedUserId]) {
			STUser *user = [self userForUserId:userId];
			BOOL bShowExpanded = ( (_expandsSelectedContact) && ( (user == nil) || (user.isRemote) ) );
			return [ContactsSubViewControllerCell cellHeightExpanded:bShowExpanded];
		}
	}
	return [ContactsSubViewControllerCell cellHeightExpanded:NO];
}

- (void)tableView:(UITableView *)sender didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	DDLogAutoTrace();
	
	NSString *userId = [self userIdForIndexPath:indexPath];
	
	if (userId == nil)
	{
		DDLogWarn(@"%@ - Missing userId for indexPath(%@)", THIS_METHOD, indexPath);
		return;
	}
	
	ContactsSubViewControllerCell *cell =
	    (ContactsSubViewControllerCell *)[self.tableView cellForRowAtIndexPath:indexPath];
	
	if (usesMultipleSelection)
	{
		if ([checkmarkedUserIds containsObject:userId])
		{
			[checkmarkedUserIds removeObject:userId];
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		else
		{
			[checkmarkedUserIds addObject:userId];
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		}
		
		[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
		
		if ([delegate respondsToSelector:@selector(contactsSubViewControllerSelectionDidChange:)])
			[delegate contactsSubViewControllerSelectionDidChange:self];
	}
	else
	{
		if (![userId isEqualToString:previousSelectedUserId])
		{
			NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
			if (previousSelectedUserId)
			{
				NSIndexPath *prevCellPath = [self indexPathForUserId:previousSelectedUserId];
				if (prevCellPath)
					indexPaths = [indexPaths arrayByAddingObject:prevCellPath];
			}

			STUser *user = [self userForUserId:userId];
			if ( (AppConstants.isIPad) || (!_expandsSelectedContact) || (user) ) {
				[self didSelectUserId:userId];
			} else {
				if (![userId isEqualToString:previousSelectedUserId])
					previousSelectedUserId = userId;
			}
			
			[self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
			// reload causes selection to get dropped
			if ( (self.ensuresSelection) || (!_expandsSelectedContact) )
				[self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
		}
		else if (!self.ensuresSelection)
		{
			[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
		}
	}
}

- (BOOL)tableView:(UITableView *)sender canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section < [self numberOfMappedSections]) {
		// Allows user.isRemote if allowsDeletion is true
		return (allowsDeletion && [self allowsDeleteAtIndexPath:indexPath]);
	}
	return NO;
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
	DDLogAutoTrace();
	
	// After the tableView goes into editing mode, it seems to deselect any selected rows.
	// We want to reselect the rows when editing ends (either by the user cancelling or committing an edit).
	// So we store whatever was selected here.
	
	temp_selectedIndexPath = [self.tableView indexPathForSelectedRow];
}

- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
	DDLogAutoTrace();
	
	// Reselect whatever was selected before editing mode started.
	//
	// Note: If the user commits the edit (deletes the row),
	// then this method is called during [self.tableView endUpdates].
	
	if (temp_selectedIndexPath)
	{
		[self.tableView selectRowAtIndexPath:temp_selectedIndexPath
		                            animated:NO
		                      scrollPosition:UITableViewScrollPositionNone];
		
		temp_selectedIndexPath = nil;
	}
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)sender editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	DDLogAutoTrace();
	
	return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)sender commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
                                         forRowAtIndexPath:(NSIndexPath *)indexPath
{
	DDLogAutoTrace();
	
	if (editingStyle != UITableViewCellEditingStyleDelete) {
		return;
	}
	
	UITableViewCell *pressedCell = [self.tableView cellForRowAtIndexPath:indexPath];
	
	CGRect cellRect = pressedCell.frame;
	// width == the first third of the cell frame, where the contact name is displayed/retracted
	// origin.x == the first third of the cell frame; popover covers the cell Delete button
	
	CGFloat width = CGRectGetMaxX(cellRect);
	cellRect.size.width = width / 3;
	cellRect.origin.x   = width / 3;
	
	dispatch_async(dispatch_get_main_queue(), ^{

		NSString *deleteContactButtonTitle = NSLocalizedString(@"Delete Contact", @"Delete Contact");
		
//		if (AppConstants.isIPad && AppConstants.isIOS8OrLater)
//		{
//			UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
//			                                                            message:nil
//			                                                     preferredStyle:UIAlertControllerStyleActionSheet];
//
//			NSString *title = NSLocalizedString(@"Delete Contact", @"Delete Contact");
//
//			[ac addAction:[UIAlertAction actionWithTitle:title
//			                                       style:UIAlertActionStyleDestructive
//			                                     handler:^(UIAlertAction *action)
//			{
//				NSString *userId = [self userIdForIndexPath:indexPath];
//				if (userId)
//				{
//					[STDatabaseManager asyncUnSaveRemoteUser:userId completionBlock:NULL];
//				}
//			}]];
//
//			[ac addAction:[UIAlertAction actionWithTitle:NSLS_COMMON_CANCEL
//			                                       style:UIAlertActionStyleCancel
//			                                     handler:^(UIAlertAction *action)
//			{
//				// End editing of tableViewCell
//				[sender setEditing:NO animated:YES];
//			}]];
//
//			ac.modalPresentationStyle = UIModalPresentationPopover;
//			UIPopoverPresentationController *ppc = ac.popoverPresentationController;
//			ppc.permittedArrowDirections = UIPopoverArrowDirectionAny;
//			ppc.sourceView = self.view;
//			ppc.sourceRect = cellRect;
//
//			[self presentViewController:ac animated:YES completion:nil];
//		}
//		else
//		{
			[OHActionSheet showFromRect:cellRect
			                   sourceVC:self
			                     inView:self.view
			             arrowDirection:UIPopoverArrowDirectionLeft
			                      title:nil
			          cancelButtonTitle:NSLS_COMMON_CANCEL
			     destructiveButtonTitle:deleteContactButtonTitle
			          otherButtonTitles:nil
			                 completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
			{
				if (buttonIndex == sheet.destructiveButtonIndex)
				{
					NSString *userId = [self userIdForIndexPath:indexPath];
					if (userId)
					{
						[STDatabaseManager asyncUnSaveRemoteUser:userId completionBlock:NULL];
					}
				}
				else
				{
					// Dismiss the Swipe-to-Delete button
					[sender setEditing:NO animated:YES];
				}
			}];
//		}
		
	}); // end dispatch_async
}

#pragma mark - Allows Delete

- (BOOL)allowsDeleteAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *userId = [self userIdForIndexPath:indexPath];
    STUser *user = [self userForUserId:userId];
    return (user && user.isRemote);
}

- (STUser *)userForUserId:(NSString *)userId
{
    __block STUser *user = nil;
    [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        user = [transaction objectForKey:userId inCollection:kSCCollection_STUsers];
    }];
    
    return user;
}

#pragma mark - ContactsSubViewControllerCellDelegate
- (void)contactsCellChatTapped:(ContactsSubViewControllerCell *)cell {
	STUser *user = [self userForUserId:cell.userId];
	if ( (!user) && ([cell.jid length] > 0) ) {
		// support for remote contacts
		// looks like a SC Directory person result, grab the JID from the cell
		XMPPJID *jid = [XMPPJID jidWithString:cell.jid];
		user = [[STUser alloc] initWithUUID:nil // Yes, nil because this is a temp user (user.isTempUser)
								  networkID:STDatabaseManager.currentUser.networkID
										jid:jid];
	}
	
	NSString *conversationId = [MessageStream conversationIDForLocalJid:STDatabaseManager.currentUser.jid remoteJid:user.jid];
	[STPreferences setSelectedConversationId:conversationId forUserId:STDatabaseManager.currentUser.uuid];
	[ConversationDetailsBaseVC popToConversation:conversationId];
}

- (void)contactsCellPhoneTapped:(ContactsSubViewControllerCell *)cell {
//	DDLogAutoTrace();
	// NOTE: this is copied from UserInfoVC

	STUser *user = [self userForUserId:cell.userId];
	if ( (!user) && ([cell.jid length] > 0) ) {
		// support for remote contacts
		// looks like a SC Directory person result, grab the JID from the cell
		XMPPJID *jid = [XMPPJID jidWithString:cell.jid];
		user = [[STUser alloc] initWithUUID:nil // Yes, nil because this is a temp user (user.isTempUser)
								  networkID:STDatabaseManager.currentUser.networkID
										jid:jid];
	}
	if (!user)
		return;

	XMPPJID *userJid = user.jid;
	if (userJid)
	{
		UIApplication *app = [UIApplication sharedApplication];
		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"silentphone:%@", userJid.user]];
		[app openURL:url];
	}
}

- (void)contactsCellAddContactTapped:(ContactsSubViewControllerCell *)cell {
	// NOTE: this is similar to UserInfoVC
	STUser *user = (cell.userId) ? [self userForUserId:cell.userId] : nil;
	if ( (!user) && (cell.jid) )
	{
		// support for remote contacts
		// looks like a SC Directory person result, grab the JID from the cell
		XMPPJID *jid = [XMPPJID jidWithString:cell.jid];
		user = [[STUser alloc] initWithUUID:nil // Yes, nil because this is a temp user (user.isTempUser)
								  networkID:STDatabaseManager.currentUser.networkID
										jid:jid];
		
		NSDictionary *abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:jid];
		if (abInfo)
		{
			NSNumber *abRecordID = [abInfo valueForKey:kABInfoKey_abRecordID];
			user.abRecordID = [abRecordID intValue];
			user.isAutomaticallyLinkedToAB = YES;
		}
	}
	
	if (user.isTempUser)
	{
		// Add the user to the database.
		//
		// Note: The user.nextWebRefresh will trigger an automatic refresh via the DatabaseActionManager.
		
		[[STUserManager sharedInstance] addNewUser:user
		                               withPubKeys:nil
		                           completionBlock:^(NSString *userID)
		{
			DDLogPink(@"Added New userID: %@", userID);
					
			YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
			[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
				
				STUser *userSnapshot = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
				userSnapshot = [userSnapshot copy];
				userSnapshot.isSavedToSilentContacts = YES;
				[transaction setObject:userSnapshot forKey:userSnapshot.uuid inCollection:kSCCollection_STUsers];
			}];
		}];
	}
	else if (!user.isSavedToSilentContacts)
	{
		YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
		[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
			STUser *userSnapshot = [transaction objectForKey:user.uuid inCollection:kSCCollection_STUsers];
			userSnapshot = [userSnapshot copy];
			userSnapshot.isSavedToSilentContacts = YES;
			[transaction setObject:userSnapshot forKey:userSnapshot.uuid inCollection:kSCCollection_STUsers];
		}];
	}
}

- (void)contactsCellInfoTapped:(ContactsSubViewControllerCell *)cell {
	// make sure the cell is properly selected
	NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
	[self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
	previousSelectedUserId = [self userIdForIndexPath:indexPath];
	if ([delegate respondsToSelector:@selector(contactsSubViewControllerSelectionDidChange:)])
		[delegate contactsSubViewControllerSelectionDidChange:self];
}

#pragma mark - UISearchBarDelegate
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	[self filterContacts:searchText];
#if USE_SC_DIRECTORY_SEARCH
	[[SCWebAPIManager sharedInstance] searchUsers:searchText forLocalUser:STDatabaseManager.currentUser limit:50 completionBlock:^(NSError *error, NSArray *peopleList)
		{
			if (!error)
				self.secondaryResultsArray = [[NSMutableArray alloc] initWithArray:peopleList];
		}];
#endif /* USE_SC_DIRECTORY_SEARCH */
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	
}
//- (void)searchBarBookmarkButtonClicked:(UISearchBar *)searchBar;

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	
}

@end
