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
//  NewGroupInfoVC.m
//  ST2
//
//  Created by Eric Turner on 8/14/14.
//

#import "NewGroupInfoVC.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "STUser.h"
#import "STLocalUser.h"
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

#import "UserInfoVC.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

static NSString *const kDefaultAvatarIcon = @"silhouette.png";

#define USE_SECTIONS_THRESHOLD 7
static const CGFloat kAvatarDiameter  = 60;
static const CGFloat kCellAvatarDiameter = 36;


@interface NewGroupInfoVC () <UINavigationControllerDelegate>

@property (weak, nonatomic) id<UINavigationControllerDelegate> cachedNavDelegate;

@property (nonatomic, strong) IBOutlet UIView *containerView; // strong to support moving around
@property (nonatomic, weak) IBOutlet UIImageView *userImageView;
@property (nonatomic, weak) IBOutlet UITextField *txtConversationTitle;
@property (nonatomic, weak) IBOutlet UILabel *lblParticipants;

@property (nonatomic, weak) IBOutlet UIButton *addUser;

@property (nonatomic, weak) IBOutlet UITableView *groupTableView;

@property (nonatomic, strong) NSArray *partitionedData;
@property (nonatomic, weak, readonly) AppTheme *theme;
@property (nonatomic, strong) UIImage *defaultCellAvatarImage;
@property (nonatomic) BOOL groupNameModified;
@property (nonatomic) BOOL useSections;

@end


@implementation NewGroupInfoVC

- (instancetype)initWithProperNib
{
    return [self initWithNibName:@"NewGroupInfoVC" bundle:nil];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
//        _multiCastUsers = nil;
//        _groupNameModified = NO;
    }
    return self;
}

- (void)dealloc
{
    DDLogAutoTrace();
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - View Lifecycle
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
//    dbConnection = STDatabaseManager.uiDatabaseConnection;
    
    
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
    
    _groupTableView.backgroundColor =  [UIColor colorWithWhite: .95 alpha:1];
    _groupTableView.rowHeight = 46;
    _groupTableView.separatorInset = UIEdgeInsetsMake(0, (10+46+8), 0, 0); // top, left, bottom, right
    _groupTableView.delegate = self;
    _groupTableView.dataSource = self;
    _groupTableView.frame = self.view.bounds;
    
    UINib *cellNib = [UINib nibWithNibName:@"ContactsSubViewControllerCell" bundle:nil];
    [_groupTableView registerNib:cellNib forCellReuseIdentifier:@"ContactsSubViewControllerCell"];
    
    self.title = NSLocalizedString(@"Group Conversation", @"Group Conversation");
    
    // Use values set by initializing object
    _userImageView.image = _groupAvatarImage;
    [self updateConversationTitleView];
//    _txtConversationTitle.text = _conversationTitle;
    _lblParticipants.text = _participantsTitle;
    

//    _theme = [AppTheme getThemeBySelectedKey];
}

-(void) viewWillAppear:(BOOL)animated
{
    // If we're not being displayed in a popover,
    // then bump the containerView down so its not hidden behind the main nav bar.
    
   	if (AppConstants.isIPad && !_isInPopover)
    {
        DDLogVerbose(@"Updating topConstraint - not in popover");
        
        CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
        
        CGFloat statusBarHeight = MIN(statusBarFrame.size.width, statusBarFrame.size.height);
        CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
        
        NSLayoutConstraint *constraint = [self topConstraintFor:_containerView];
        constraint.constant = statusBarHeight + navBarHeight;
        
        [self.view setNeedsUpdateConstraints];
    }
    
    
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    DDLogAutoTrace();
    [super viewWillDisappear:animated];
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Methods
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateAllViews
{
    [self updateAvatarView];
    [self updateConversationTitleView];
}

- (void)updateAvatarView
{
	// Why is this commented out?
	// Seems like a good idea to set a default image while the async fetch is doing its work...
	//
	// -RH, 29 Oct, 2014
	//
//	if (_userImageView.image == nil)
//		_userImageView.image = [[AvatarManager sharedInstance] defaultMultiAvatarImageWithDiameter:kAvatarDiameter];
    
    [[AvatarManager sharedInstance] fetchMultiAvatarForUsers:self.multiCastUsers 
                                                withDiameter:kAvatarDiameter 
                                                       theme:self.theme 
                                                       usage:kAvatarUsage_None 
                                             completionBlock:^(UIImage *multiAvatar)
	{
		UIImage *img = nil;
		if (multiAvatar)
			img = multiAvatar;
		else
			img = [[AvatarManager sharedInstance] defaultMultiAvatarImageWithDiameter:kAvatarDiameter];
		
		_userImageView.image = img;
	}];
}

/**
 * @return Text for `txtConversationTitle` conversation title for group conversation; "Group Conversation", otherwise.
 */
- (void)updateConversationTitleView
{
    _txtConversationTitle.placeholder = NSLocalizedString(@"change conversation title", @"change conversation title");
    
    NSString *text = nil;
    NSCharacterSet *charSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    if ([[_conversation.title stringByTrimmingCharactersInSet:charSet] length] > 0)
    {
        text = _conversation.title;
    }
    
    _txtConversationTitle.text = text;
}

/**
 * @return Text for `lblOrganizationName`: group conversation user names, or user userName.
 */
- (void)updateParticipantsView
{
    NSUInteger selfUser = 1;
    NSString *str = [NSString stringWithFormat:@"%lu participants", (unsigned long)self.multiCastUsers.count + selfUser];
    NSString *title = NSLocalizedString(str, @"{number of conversation} participants");
    _lblParticipants.text = title;
}


// Moved from SCTAvatarView
- (NSString *)titleForUserName
{
//    NSString *userName = nil;
//    if (self.conversation.isMulticast)
//    {
//        UIFont *titleFont = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];        
//        NSMutableParagraphStyle *titleStyle = [[NSMutableParagraphStyle alloc] init];
//        titleStyle.lineBreakMode = NSLineBreakByTruncatingTail;
//        titleStyle.alignment = NSTextAlignmentLeft;
//        
//        NSDictionary* titleAttributes = @{ NSFontAttributeName: titleFont,
//                                           NSParagraphStyleAttributeName: titleStyle };
//        
//        userName = [STUser displayNameForUsers:self.multiCastUsers
//                                      maxWidth:_lblUserName.frame.size.width
//                                textAttributes:titleAttributes];
//    }
//    else
//    {
//        NSString *remoteJidStr = self.conversation.remoteJid;
//        userName = [NSString substringToString:@"/" inString:remoteJidStr];
//    }
//    return userName;
//    return self.user.userName;
    
    return nil;
}


#pragma mark - UIViewController Methods
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
    
    if ([STDatabaseManager.uiDatabaseConnection hasChangeForKey:_conversation.uuid 
                                                   inCollection:_userId 
                                                inNotifications:notifications])
    {
        needsReload = YES;
    }
    
//    if(!needsReload) for (STUser* user in _multiCastUsers)
    if(!needsReload) for (STUser* user in _multiCastUsers)
    {
        if ([STDatabaseManager.uiDatabaseConnection hasChangeForKey:user.uuid 
                                                       inCollection:kSCCollection_STUsers 
                                                    inNotifications:notifications])
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

- (UIImage *)defaultCellAvatarImage
{
    if (_defaultCellAvatarImage == nil) {
        _defaultCellAvatarImage = [[UIImage imageNamed:@"silhouette.png"] avatarImageWithDiameter:kCellAvatarDiameter];
    }
    
    return _defaultCellAvatarImage;
}


- (void)refreshUsers
{
    __block STConversation *conversation = nil;
    __block id fetch_multiAvatar_front = nil;
    __block id fetch_multiAvatar_back = nil;
    __block NSMutableArray* users = [NSMutableArray array];
    
    NSString *aUserId = STDatabaseManager.currentUser.uuid;
    NSString *networkID = STDatabaseManager.currentUser.networkID;
    NSString *convoID = _conversation.uuid;
    
    [users addObject: STDatabaseManager.currentUser];
    
    [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        conversation  = [transaction objectForKey:convoID inCollection:aUserId];
        
        for (XMPPJID *jid in conversation.multicastJidSet)
        {
            STUser *user = [[DatabaseManager sharedInstance] findUserWithJID:jid transaction:transaction];
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
				
                user = [[STUser alloc] initWithUUID:nil
                                          networkID:networkID
                                                jid:jid];
                
                NSDictionary *abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:jid];
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
                
        if (_multiCastUsers.count < USE_SECTIONS_THRESHOLD)
            _useSections = NO;
        else
            _useSections = YES;
        
        _partitionedData = [self partitionObjects:_multiCastUsers collationStringSelector: @selector(displayName) ];
        
        [_groupTableView reloadData];
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
    
    if (_useSections)
        sectionCount  = [[[UILocalizedIndexedCollation currentCollation] sectionTitles] count];
   	
    return sectionCount;
    
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    NSInteger rowCount = 0;
    
    if (_useSections)
        rowCount = [[_partitionedData objectAtIndex:section] count];
    else
        rowCount = [_multiCastUsers count];
    
    return rowCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"ContactsSubViewControllerCell";
    ContactsSubViewControllerCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    cell.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    STUser *user = nil;
    
    if(_useSections)
        user =  [[_partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    else
        user = [_multiCastUsers objectAtIndex:indexPath.row];
    
   	NSString *userId = user.uuid;
    if (![cell.userId isEqualToString:userId])
    {
        cell.userId = userId;
        cell.avatarImageView.image = [self defaultCellAvatarImage];
    }
    
    if (user.isTempUser)
    {
		ABRecordID abRecordID = user ? user.abRecordID : kABRecordInvalidID;
		
		UIImage *cachedAvatar = [[AvatarManager sharedInstance] cachedAvatarForABRecordID:abRecordID
		                                                                     withDiameter:kCellAvatarDiameter
		                                                                            theme:self.theme
		                                                                            usage:kAvatarUsage_None
		                                                                  defaultFallback:NO];
		if (cachedAvatar) {
			cell.avatarImageView.image = cachedAvatar;
		}
		else if (cell.avatarImageView.image == nil) {
			cell.avatarImageView.image = [self defaultCellAvatarImage];
		}
        
        [[AvatarManager sharedInstance] fetchAvatarForABRecordID:abRecordID
                                                    withDiameter:kCellAvatarDiameter
                                                           theme:self.theme
                                                           usage:kAvatarUsage_None
                                                 completionBlock:^(UIImage *avatar)
         {
             // Make sure the cell is still being used for the conversationId.
             // During scrolling, the cell may have been recycled.
             if (avatar)
                 cell.avatarImageView.image = avatar;
             else
                 cell.avatarImageView.image = [self defaultCellAvatarImage];
         }];
    }
    else
    {
        UIImage *cachedAvatar = [[AvatarManager sharedInstance] cachedAvatarForUserId:user.uuid
                                                                         withDiameter:kCellAvatarDiameter
                                                                                theme:self.theme
                                                                                usage:kAvatarUsage_None
		                                                              defaultFallback:NO];
		if (cachedAvatar) {
			cell.avatarImageView.image = cachedAvatar;
		}
		else if (cell.avatarImageView.image == nil) {
			cell.avatarImageView.image = [self defaultCellAvatarImage];
		}
        
        [[AvatarManager sharedInstance] fetchAvatarForUserId:user.uuid
                                                withDiameter:kCellAvatarDiameter
                                                       theme:self.theme
                                                       usage:kAvatarUsage_None
                                             completionBlock:^(UIImage *avatar)
         {
             // Make sure the cell is still being used for the conversationId.
             // During scrolling, the cell may have been recycled.
             if (avatar)
                 cell.avatarImageView.image = avatar;
             else
                 cell.avatarImageView.image = [self defaultCellAvatarImage];
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
    if (_useSections)
        return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
    else
        return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    
    if (_useSections)
    {
        NSInteger rowCount = [[_partitionedData objectAtIndex:section] count];
        
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
    
    if (_useSections)
        user =  [[_partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    else
        user = [_multiCastUsers objectAtIndex:indexPath.row];
    
    
    if(![user.uuid isEqualToString:STDatabaseManager.currentUser.uuid])
        canEdit = YES;
    
    return canEdit;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Textfield customization methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if (textField == _txtConversationTitle)
    {
        if(!_groupNameModified)
        {
            _groupNameModified = YES;
            
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
    
    if (textField == _txtConversationTitle)
    {
        if (!_groupNameModified)
        {
            _groupNameModified = YES;
            
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
    
    if ([_delegate respondsToSelector:@selector(groupInfoViewController:updateConversationName:)])
    {
        [_delegate groupInfoViewController:self  updateConversationName:_txtConversationTitle.text  ];
    }
    
    _groupNameModified = NO;
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
 forRowAtIndexPath: (NSIndexPath *) indexPath 
{
    
    STUser* user = NULL;
    if (_useSections)
        user =  [[_partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    else
        user = [_multiCastUsers objectAtIndex:indexPath.row];
    
    
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
    STUser *user = nil;
    if(_useSections)
        user =  [[_partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    else
        user = [_multiCastUsers objectAtIndex:indexPath.row];

    
    if (self.navigationController.delegate != self)
    {
        self.cachedNavDelegate = self.navigationController.delegate;
        self.navigationController.delegate = self;
    }

    UserInfoVC *vc = [[UserInfoVC alloc] initWithUser:user];
    vc.presentingController = _presentingController;
    vc.conversation = _conversation;
    [self.navigationController pushViewController:vc animated:YES];
    
}

#pragma mark NavigationControllerDelegate Methods

- (void)navigationController:(UINavigationController *)navigationController 
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (viewController == self)
    {
        navigationController.delegate = _cachedNavDelegate;
    }
}



@end
