/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

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
//  GroupInfoViewController.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 3/14/14.
//

#import "GroupInfoViewController.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "STUser.h"
#import "STPublicKey.h"
#import "STPreferences.h"
#import "STConversation.h"
#import "UIImage+Thumbnail.h"
#import "NSDate+SCDate.h"
#import "SCDateFormatter.h"
#import "ConversationViewController.h"
#import "MessagesViewController.h"
 #import "AddressBookManager.h"

#import "UIImage+maskColor.h"
#import "OHActionSheet.h"
#import "STLogging.h"
#import "SilentTextStrings.h"
#import "ContactsSubViewControllerCell.h"
#import "AvatarManager.h"


// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

static NSString *const kDefaultAvatarIcon = @"silhouette.png";
static NSString *const kNonDBUserUUID = @"GroupInfoViewControllerUUID:";

#define USE_SECTIONS_THRESHOLD 7
//#define kAvatarDiameter 36
static const CGFloat kAvatarDiameter = 36;

@interface GroupInfoViewController ()

@end

@implementation GroupInfoViewController
{
	
	YapDatabaseConnection   *dbConnection;
     NSArray                *multicastUsers;
	NSArray                 *partitionedData;
    BOOL                    useSections;
    AppTheme*               theme;
    UIImage                 *_defaultAvatarImage;
    
    BOOL                    groupNameModified;

}

@synthesize delegate = delegate;
@synthesize conversationId = conversationId;

@synthesize isInPopover = isInPopover;
@synthesize isModal = isModal;

@synthesize containerView = containerView;


@synthesize userImageView = userImageView;
@synthesize displayNameLabel = displayNameLabel;
@synthesize organizationLabel = organizationLabel;
@synthesize groupTableView = groupTableView;




- (id)initWithProperNib
{
	return [self initWithNibName:@"GroupInfoViewController" bundle:nil];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        
        multicastUsers = NULL;
        
        groupNameModified = NO;
        
      }
    return self;
}

- (void)viewDidLoad
{
	DDLogAutoTrace();
    [super viewDidLoad];
    
//	if (!self.isInPopover)
//	{
//		self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
//	}
	
	if (self.isModal)
    {
		self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"")
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(doneButtonTapped:)];
    }
    
	self.navigationItem.rightBarButtonItem = NULL;
	
	// Setup database access
	
	dbConnection = STDatabaseManager.uiDatabaseConnection;
   

	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionWillUpdate:)
	                                             name:UIDatabaseConnectionWillUpdateNotification
	                                           object:STDatabaseManager];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionDidUpdate:)
	                                             name:UIDatabaseConnectionDidUpdateNotification
	                                           object:STDatabaseManager];
	
    
 	// Copying iOS on this.
	// They don't use a title, most likely because it visually distracts from the user name
	// displayed in the view controller, which should be the primary focus.
	//
	// self.title = NSLocalizedString(@"User Info", @"User Info");
   
    self.edgesForExtendedLayout=UIRectEdgeNone;
	self.extendedLayoutIncludesOpaqueBars=NO;

    groupTableView.backgroundColor =  [UIColor colorWithWhite: .95 alpha:1];
    groupTableView.rowHeight = 46;
    groupTableView.separatorInset = UIEdgeInsetsMake(0, (10+46+8), 0, 0); // top, left, bottom, right
    groupTableView.delegate = self;
    groupTableView.dataSource = self;
    groupTableView.frame = self.view.bounds;
    
    UINib *cellNib = [UINib nibWithNibName:@"ContactsSubViewControllerCell" bundle:nil];
    [groupTableView registerNib:cellNib forCellReuseIdentifier:@"ContactsSubViewControllerCell"];

    self.title = NSLocalizedString(@"Group Conversation", @"Group Conversation");
    
    userImageView.image = [self defaultMultiAvatarImage];
    theme = [AppTheme getThemeBySelectedKey];

}

-(void) viewWillAppear:(BOOL)animated
{
    // If we're not being displayed in a popover,
	// then bump the containerView down so its not hidden behind the main nav bar.
    
   	if (AppConstants.isIPad && !isInPopover)
    {
		DDLogVerbose(@"Updating topConstraint - not in popover");
		
		CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
		
		CGFloat statusBarHeight = MIN(statusBarFrame.size.width, statusBarFrame.size.height);
		CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
		
		NSLayoutConstraint *constraint = [self topConstraintFor:containerView];
		constraint.constant = statusBarHeight + navBarHeight;
		
		[self.view setNeedsUpdateConstraints];
	}
	

    [self refreshUsers];
 
}


- (void)viewWillDisappear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillDisappear:animated];
 }


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)databaseConnectionWillUpdate:(NSNotification *)notification
{
	// Just in case we need this method later
}

- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
	NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
	BOOL needsReload = NO;
    
    NSString *_userId = STDatabaseManager.currentUser.uuid;

    if ([dbConnection hasChangeForKey:conversationId inCollection:_userId inNotifications:notifications])
    {
       needsReload = YES;
    }
    
   if(!needsReload) for(STUser* user in multicastUsers)
   {
       if ([dbConnection hasChangeForKey:user.uuid inCollection:kSCCollection_STUsers inNotifications:notifications])
       {
           needsReload = YES;
           break;
       }
       
   }
    
    if(needsReload)
        [self refreshUsers];
 }



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Display
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (NSLayoutConstraint *)topConstraintFor:(id)item
{
	for (NSLayoutConstraint *constraint in self.view.constraints)
	{
		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeTop) ||
		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeTop))
		{
			return constraint;
		}
	}
	
	return nil;
}


- (UIImage *)defaultAvatarImage
{
	if (_defaultAvatarImage == nil) {
		_defaultAvatarImage = [[UIImage imageNamed:@"silhouette.png"] avatarImageWithDiameter:kAvatarDiameter];
	}
	
	return _defaultAvatarImage;
}

- (UIImage *)defaultMultiAvatarImage
{
    CGFloat diameter = userImageView.bounds.size.width;
    UIImage* defaultImage = [UIImage imageNamed:kDefaultAvatarIcon];
    
    UIImage*  image = [ UIImage multiAvatarImageWithFront:defaultImage back:defaultImage diameter:diameter];
    
    return image;
}

- (void)refreshUsers 
{
    __block STConversation *conversation = nil;
    __block id fetch_multiAvatar_front = nil;
	__block id fetch_multiAvatar_back = nil;
	__block NSMutableArray *users = [NSMutableArray array];
   
    NSString *_userId = STDatabaseManager.currentUser.uuid;
    NSString * networkID = STDatabaseManager.currentUser.networkID;
    
    [users addObject: STDatabaseManager.currentUser];

    [dbConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        conversation  = [transaction objectForKey:conversationId inCollection:_userId];
          
        for (NSString *jidStr in conversation.multicastJids)
        {
            STUser *user = [[DatabaseManager sharedInstance] findUserWithJidStr:jidStr
                                                                    transaction:transaction];
            if (user)
            {
                if (fetch_multiAvatar_front == nil)
                    fetch_multiAvatar_front = user.uuid;
                else if (fetch_multiAvatar_back == nil)
                    fetch_multiAvatar_back = user.uuid;
            }
            else
            {
                // if the mc user is not in our database, create a pseduo one, and check for AB entry
                
                NSString* fakeUserUUID = [NSString stringWithFormat:@"%@%@", kNonDBUserUUID, jidStr];
                
				XMPPJID *realJID = [XMPPJID jidWithString:jidStr];
				
				NSAssert(realJID != nil,
						 @"STUser MUST have a valid JID. To use 'fake' JIDs, you MUST use a fake domain.");
				
                user = [[STUser alloc] initWithUUID:fakeUserUUID
                                          networkID:networkID
                                                jid:realJID];
                
                NSDictionary *abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:realJID];
                if (abInfo)
                {
                    NSNumber *abRecordID = [abInfo valueForKey:kABInfoKey_abRecordID];
                    
                    user.ab_firstName     = [abInfo objectForKey:kABInfoKey_firstName];
                    user.ab_lastName      = [abInfo objectForKey:kABInfoKey_lastName];
                    user.ab_compositeName = [abInfo objectForKey:kABInfoKey_compositeName];
                    user.ab_organization  = [abInfo objectForKey:kABInfoKey_organization];
                    user.ab_notes         = [abInfo objectForKey:kABInfoKey_notes];
                    user.abRecordID = [abRecordID intValue];
                     
                    if (fetch_multiAvatar_front == nil)
                        fetch_multiAvatar_front = abRecordID;
                    else if (fetch_multiAvatar_back == nil)
                        fetch_multiAvatar_back = abRecordID;
                }
            }
            
            [users addObject:user];
        }
        
    }completionBlock:^{
        
        displayNameLabel.text   = conversation.title?:  NULL;
        organizationLabel.text  = [NSString stringWithFormat:NSLocalizedString(@"%d recipients", @"%d recipients"),
                                   conversation.multicastJids.count ];
        

        multicastUsers   = users;
        
        if (multicastUsers.count < USE_SECTIONS_THRESHOLD)
            useSections = NO;
        else
            useSections = YES;
        
        partitionedData = [self partitionObjects:multicastUsers collationStringSelector: @selector(displayName) ];

        [groupTableView reloadData];

        CGFloat diameter = userImageView.bounds.size.width;

		[[AvatarManager sharedInstance] fetchMultiAvatarForFront:fetch_multiAvatar_front
		                                                    back:fetch_multiAvatar_back
		                                            withDiameter:diameter
		                                                   theme:theme
		                                                   usage:kAvatarUsage_None
		                                         completionBlock:^(UIImage *multiAvatar)
		{
			userImageView.image = multiAvatar;
		}];
		
	}];
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableView for groupTableView
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
    NSInteger sectionCount = 1;
    
      if (useSections)
        sectionCount  = [[[UILocalizedIndexedCollation currentCollation] sectionTitles] count];
   	
    return sectionCount;
    
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    NSInteger rowCount = 0;
    
           if (useSections)
            rowCount = [[partitionedData objectAtIndex:section] count];
        else
            rowCount = [multicastUsers count];
   
    return rowCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"ContactsSubViewControllerCell";
	ContactsSubViewControllerCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	
 	cell.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	STUser *user = nil;
    
    if(useSections)
        user =  [[partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    else
        user = [multicastUsers objectAtIndex:indexPath.row];
    
   	NSString *userId = user.uuid;
	if (![cell.userId isEqualToString:userId])
	{
		cell.userId = userId;
		cell.avatarImageView.image = [self defaultAvatarImage];
	}
	
	BOOL isNonDBUSer = NO;
    NSRange range = [user.uuid rangeOfString:kNonDBUserUUID];
    if (range.location != NSNotFound)
        isNonDBUSer = YES;
  
	if (isNonDBUSer)
	{
		UIImage *cachedAvatar = [[AvatarManager sharedInstance] cachedAvatarForUserId:user.uuid
		                                                                 withDiameter:kAvatarDiameter
		                                                                        theme:theme
		                                                                        usage:kAvatarUsage_None];
		if (cachedAvatar) {
			cell.avatarImageView.image = cachedAvatar;
		}
		else if (cell.avatarImageView.image == nil) {
            cell.avatarImageView.image = [self defaultAvatarImage];
		}
		
		[[AvatarManager sharedInstance] fetchAvatarForABRecordID:user.abRecordID
		                                            withDiameter:kAvatarDiameter
		                                                   theme:theme
		                                                   usage:kAvatarUsage_None
		                                         completionBlock:^(UIImage *avatar)
		{
			// Make sure the cell is still being used for the conversationId.
			// During scrolling, the cell may have been recycled.
			if (avatar)
				cell.avatarImageView.image = avatar;
			else
				cell.avatarImageView.image = [self defaultAvatarImage];
		}];
	}
	else
	{
		UIImage *cachedAvatar = [[AvatarManager sharedInstance] cachedAvatarForUserId:user.uuid
		                                                                 withDiameter:kAvatarDiameter
		                                                                        theme:theme
		                                                                        usage:kAvatarUsage_None];
		if (cachedAvatar) {
			cell.avatarImageView.image = cachedAvatar;
        }
		else if (cell.avatarImageView.image == nil) {
            cell.avatarImageView.image = [self defaultAvatarImage];
		}
		
		[[AvatarManager sharedInstance] fetchAvatarForUserId:user.uuid
		                                        withDiameter:kAvatarDiameter
		                                               theme:theme
		                                               usage:kAvatarUsage_None
		                                     completionBlock:^(UIImage *avatar)
		{
			// Make sure the cell is still being used for the conversationId.
			// During scrolling, the cell may have been recycled.
			if (avatar)
				cell.avatarImageView.image = avatar;
			else
				cell.avatarImageView.image = [self defaultAvatarImage];
		}];
	}
	
	cell.nameLabel.text = user.displayName;
	
	if ([user.uuid isEqualToString:STDatabaseManager.currentUser.uuid])
		cell.meLabel.text = NSLocalizedString(@"me", @"Short designator for contacts");
	else
		cell.meLabel.text = nil;
	
	return cell;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)sender
{
    if (useSections)
        return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
    else
        return nil;
 }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    
    if( useSections)
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


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL canEdit = NO;
    
    STUser* user = NULL;
    
    if(useSections)
        user =  [[partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    else
        user = [multicastUsers objectAtIndex:indexPath.row];
    
 
    if(![user.uuid isEqualToString:STDatabaseManager.currentUser.uuid])
        canEdit = YES;
 
    return canEdit;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Textfield customization methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if (textField == displayNameLabel)
    {
        if(!groupNameModified)
        {
            groupNameModified = YES;
            
            //          if (AppConstants.isIPhone)
            {
                // On iPhone, we wrap the view in a scrollView.
                // Because the view gets obstructed by the keyboard due to the small screen real estate.
                
                self.navigationItem.rightBarButtonItem =
                [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", @"")
                                                 style:UIBarButtonItemStylePlain
                                                target:self
                                                action:@selector(handleActionBarSave)];
                
                
                
            }
            
        }
    }
    
   return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string
{
    BOOL result = YES;
    
    if (textField == displayNameLabel)
    {
        if(!groupNameModified)
        {
            groupNameModified = YES;

  //          if (AppConstants.isIPhone)
            {
                // On iPhone, we wrap the view in a scrollView.
                // Because the view gets obstructed by the keyboard due to the small screen real estate.
                
                self.navigationItem.rightBarButtonItem =
                [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", @"")
                                                 style:UIBarButtonItemStylePlain
                                                target:self
                                                action:@selector(handleActionBarSave)];
                
                
                
            }

        }
    }
  	
    return result;
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
#pragma unused(textField)
    
    return (NO);
}

- (void)handleActionBarSave
{
    
    if ([delegate respondsToSelector:@selector(groupInfoViewController:updateConversationName:)])
	{
          [delegate groupInfoViewController:self  updateConversationName:displayNameLabel.text  ];
	}
    
    groupNameModified = NO;
    self.navigationItem.rightBarButtonItem = NULL;
 }

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)addUserButtonHit:(id)sender
{
    // adding user is not supported yet
    
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle: @"Adding Recipient"
                          message:  NSLS_COMMON_COMING_SOON_FEATURE
                          delegate: nil
                          cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                          otherButtonTitles:nil];
    [alert show];
}


- (void) tableView: (UITableView *) tableView
commitEditingStyle: (UITableViewCellEditingStyle) editingStyle
 forRowAtIndexPath: (NSIndexPath *) indexPath {
    
    STUser* user = NULL;
    if(useSections)
        user =  [[partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    else
        user = [multicastUsers objectAtIndex:indexPath.row];
    
    
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        // deleteing user is not supported yet
        
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle: @"Removing Recipient"
                              message:  NSLS_COMMON_COMING_SOON_FEATURE
                              delegate: nil
                              cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                              otherButtonTitles:nil];
        
        [alert show];
  
    }
    
};


- (void)tableView:(UITableView *)sender didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([delegate respondsToSelector:@selector(groupInfoViewController:displayInfoForUserJid:)])
	{
        STUser* user = NULL;
        
        if(useSections)
            user =  [[partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        else
            user = [multicastUsers objectAtIndex:indexPath.row];
        
		[delegate groupInfoViewController:self  displayInfoForUserJid:[user.jid bare]];
	}
}

@end
