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
 
#import "AppDelegate.h"
#import "AppConstants.h"
#import "ComposeViewController.h"
#import "PKRevealController.h"
#import "XMPPJID.h"
#import "XMPPJID+AddressBook.h"
#import "STUser.h"
#import "MessageStream.h"
#import "SCAccountsWebAPIManager.h"
#import "MBProgressHUD.h"
#import "SilentTextStrings.h"
#import "MessagesViewController.h"
#import "ConversationViewController.h"
#import "STPreferences.h"

#import "STConversation.h"
 #import "STUser.h"

#import "YapCollectionsDatabase.h"


@interface composeTableItem : NSObject

@property (nonatomic, copy) NSString *nameString;
@property (nonatomic, copy) NSString *jidString;
@property (nonatomic, copy)  XMPPJID *jid;
@end

@implementation composeTableItem;
 
+ (composeTableItem *)itemWithJid:(XMPPJID *)jid
                        jidString:(NSString *)jidString
                         username:(NSString *)nameString
{
    
    composeTableItem *item = [[composeTableItem alloc] init];
    item.jid = [jid copy];
    item.nameString = [nameString copy];
    item.jidString = [jidString copy];
    return item;
}

@end;


@interface ComposeViewController ()<MBProgressHUDDelegate>
{
    BOOL            letUserSelectRow;
    BOOL            searching;
    MBProgressHUD   *HUD;
    
    YapCollectionsDatabaseConnection *backgroundConnection;
    STConversation*                 newConversation;

}

@property (nonatomic, strong) NSString        *queryQid;
@property (nonatomic, strong) XMPPJID         *selectedJid;
@property (nonatomic, strong) NSArray         *jidArray;


@end

 
@implementation ComposeViewController
   
@synthesize searchDisplayController;
@synthesize searchBar;
@synthesize allItems;
@synthesize searchResults;
@synthesize queryQid        =  _queryQid;
@synthesize selectedJid     = _selectedJid;
@synthesize jidArray        = _jidArray;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        
        
        backgroundConnection = [[STAppDelegate database] newConnection];
        newConversation = NULL;
    }
    return self;
}

- (AppDelegate *)appDelegate
{
	return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (void) reloadTableItems
{
    
    NSMutableArray *items =  [[NSMutableArray alloc] init];
    self.jidArray = [XMPPJID silentCircleJids];
    
    // filter out any conversations we already have
    
    STUser* currentUser = STAppDelegate.currentUser;
    
    if (currentUser)
    {
        MessageStream* ms = [STAppDelegate.messageStreams objectForKey:currentUser.uuid];
        NSArray* remoteJids = ms.remoteJids;
        
        for(XMPPJID* jid in self.jidArray)
        {
            NSString* jidstring = jid.bare;
            
            if( [currentUser.jid isEqualToString:jidstring]) continue;
              
            if(! [remoteJids containsObject:jidstring] )
            {
                composeTableItem * item = [composeTableItem itemWithJid:jid
                                                              jidString:jidstring
                                                               username: [jid addressBookName]];
                [items addObject:item];
            }

        }
        
    }
    
     
    NSArray *sortedItems = [items sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        composeTableItem *itemA = (composeTableItem*)a;
        composeTableItem * itemB = (composeTableItem*)b;
        
        NSString *first =  itemA.nameString? itemA.nameString: itemA.jid.user ;
        NSString *second =  itemB.nameString? itemB.nameString: itemB.jid.user ;
        return [first localizedCompare:second];
    }];
    
    
    self.allItems = sortedItems;
}

#pragma warning Add Needs reload with conversation updated notifier

- (void)viewDidLoad
{
    [super viewDidLoad];
    
   
    if(!newConversation)
    {
        [backgroundConnection asyncReadWriteWithBlock:^(YapCollectionsDatabaseReadWriteTransaction *transaction) {
            
            newConversation = [[STConversation alloc] initAsNewMessageWithUUID: [XMPPStream generateUUID]];
            
            [transaction setObject:newConversation
                            forKey:newConversation.uuid
                      inCollection:STAppDelegate.currentUser.uuid];
            
            
        } completionBlock:^{
            
            STAppDelegate.conversationViewController.conversationId = newConversation.uuid;
            
        }];
        
  
    }
    
  
    
    // Each view can dynamically specify the min/max width that can be revealed.
    AppDelegate * App = [self appDelegate];
    [App.revealController setMinimumWidth:260 maximumWidth:260 forViewController:App.settingsViewNavController];
 
    self.tableView.scrollEnabled = YES;
    
    self.selectedJid = NULL;
    searching = NO;
	letUserSelectRow = YES;

}

-(void) viewWillAppear: (BOOL) animated {
    
    [super viewWillAppear: animated];
    
    [self reloadTableItems];
    
    [self.tableView reloadData];

    self.navigationItem.title = NSLocalizedString(@"New Conversation", @"New Conversation");
    
    for (UIView *searchBarSubview in [self.searchBar subviews]) {
        
        if ([searchBarSubview conformsToProtocol:@protocol(UITextInputTraits)]) {
            [(UITextField *)searchBarSubview setReturnKeyType:UIReturnKeySend];
            [(UITextField *)searchBarSubview setKeyboardAppearance:UIKeyboardAppearanceAlert];
        }
    }
    
    
} // -viewWillAppear:


-( void) viewWillDisappear:(BOOL)animated
{
    [self stopActivityIndicator];
    
    self.selectedJid = NULL;
    self.jidArray = NULL;
    
       if(newConversation)
       {
           [backgroundConnection asyncReadWriteWithBlock:^(YapCollectionsDatabaseReadWriteTransaction *transaction) {
                  
               [transaction removeObjectForKey:newConversation.uuid inCollection:STAppDelegate.currentUser.uuid];
                
           } completionBlock:^{
               
               STAppDelegate.conversationViewController.conversationId = NULL;;

           }];
  
       }
}


#pragma mark  - Table view

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    NSInteger rows = 0;
    
    if ([tableView
         isEqual:self.searchDisplayController.searchResultsTableView]){
        rows = [self.searchResults count];
    }
    else{
        rows = [self.allItems count];
    }
    
    return rows;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:CellIdentifier] ;
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    /* Configure the cell. */
    if ([tableView isEqual:self.searchDisplayController.searchResultsTableView]){
        
        composeTableItem *item = [self.searchResults objectAtIndex:indexPath.row];
        
        cell.textLabel.text = item.nameString;
        cell.detailTextLabel.text =  item.jidString ;
    }
    else
    {
        composeTableItem*  item = [self.allItems objectAtIndex:indexPath.row];
        
        cell.textLabel.text = item.nameString;
        cell.detailTextLabel.text = item.jidString ;
    }
    
    return cell;
}



- (void)filterContentForSearchText:(NSString*)searchText
                             scope:(NSString*)scope
{
    
    NSPredicate *findMatchingJid = [NSPredicate predicateWithBlock: ^BOOL(id obj, NSDictionary *bind)
                                    {
                                        composeTableItem *item = (composeTableItem*) obj;
                                        
                                        BOOL foundJid =  ([[item.jid user] rangeOfString:searchText
                                                                                 options:NSLiteralSearch].length == searchText.length);
                                        BOOL foundName = ([ item.nameString rangeOfString:searchText
                                                                                  options:NSCaseInsensitiveSearch].length == searchText.length);
                                        
                                        return foundJid || foundName;
                                    }];
    
    self.searchResults = [self.allItems filteredArrayUsingPredicate:findMatchingJid];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    composeTableItem * item = [self.searchResults?self.searchResults:self.allItems objectAtIndex:indexPath.row];
    
    [self checkJIDValidity: item.jid];
    
}


- (void) checkJIDValidity:(XMPPJID*) jid
{
	self.selectedJid = jid;
    
    if (STAppDelegate.currentUser)
    {
        MessageStream* ms = [STAppDelegate.messageStreams objectForKey:STAppDelegate.currentUser.uuid];
        [self startActivityIndicatorForJid: jid];
        
        [ms createConversationWithJid:jid
                      completionBlock:^(NSString *conversationID, NSError *error) {
                          if(conversationID)
                          {
                              
                             [STPreferences setSelectedConversationId:conversationID forUserId:STAppDelegate.currentUser.uuid];
                              
                              [STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController
                                                                    focusAfterChange: YES
                                                                          completion:^(BOOL finished) {
                                                                              
                                                                              
                                                                              
                                                                              
                                                                          }];
                              
                              
     
                          }
                          else
                          {
                              [[[UIAlertView alloc] initWithTitle:@"Can not start convesation with user"
                                                          message: error.localizedDescription
                                                        delegate:nil
                                                cancelButtonTitle:NSLS_COMMON_OK
                                                otherButtonTitles:nil] show];

                          }
                          
                          
                      }];
        
        
             [self stopActivityIndicator];
        
        
    }

    
    
}
 

- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if(letUserSelectRow)
		return indexPath;
	else
		return nil;
}


#pragma mark - UISearchDisplayController delegate methods

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller
shouldReloadTableForSearchString:(NSString *)searchString
{
    
    [self filterContentForSearchText:searchString
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
                                      objectAtIndex:[self.searchDisplayController.searchBar
                                                     selectedScopeButtonIndex]]];
    
    
    
    return YES;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller
shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    
    
    [self filterContentForSearchText:[self.searchDisplayController.searchBar text]
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
                                      objectAtIndex:searchOption]];
    
    
    return YES;
}

#pragma mark Search Bar

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    [self.searchDisplayController.searchBar sizeToFit];
    
    //   [self.searchDisplayController.searchBar setShowsCancelButton:YES animated:YES];
    
    
    return YES;
}
- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
    [self.searchDisplayController.searchBar sizeToFit];
    
    //    [self.searchDisplayController.searchBar setShowsCancelButton:NO animated:YES];
    
    letUserSelectRow = YES;
    return YES;
}

- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar {
    
 	searching = YES;
	letUserSelectRow = NO;
	self.tableView.scrollEnabled = NO;
    
}


- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText {
    
    if([searchText length] > 0) {
        
        searching = YES;
		letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
	}
	else {
		
        searching = NO;
		letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
    
}


- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar
{
    letUserSelectRow = YES;
	searching = NO;
    
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    
}


- (void) searchBarSearchButtonClicked:(UISearchBar *)theSearchBar {
    
    NSString* userName = self.searchDisplayController.searchBar.text;
    
    if(userName &&   (userName.length  > 0 ))
    {
        
         XMPPJID* jid = [XMPPJID jidWithUser:userName domain:kDefaultAccountDomain resource:nil];
        
         [self checkJIDValidity: jid];
        
    }
}


#pragma mark - API

- (IBAction)showOppositeView:(id)sender
{
    [self.revealController showViewController:self.revealController.leftViewController];
}

- (IBAction)togglePresentationMode:(id)sender
{
    if (![self.revealController isPresentationModeActive])
    {
        [self.revealController enterPresentationModeAnimated:YES
                                                  completion:NULL];
    }
    else
    {
        [self.revealController resignPresentationModeEntirely:NO
                                                     animated:YES
                                                   completion:NULL];
    }
}

#pragma mark - Autorotation

/*
 * Please get familiar with iOS 6 new rotation handling as if you were to nest this controller within a UINavigationController,
 * the UINavigationController would _NOT_ relay rotation requests to his children on its own!
 */

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}


-(void) stopActivityIndicator
{
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
 }

- (void) startActivityIndicatorForJid: (XMPPJID*) jid
{
    
    
    HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.delegate = self;
    HUD.mode = MBProgressHUDModeIndeterminate;
    HUD.labelText = [NSString stringWithFormat:NSLS_COMMON_VERIFYING_USER, [jid user]];
    
 }


#pragma mark - MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[HUD removeFromSuperview];
	HUD = nil;
}


@end