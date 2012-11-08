/*
Copyright © 2012, Silent Circle
All rights reserved.

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
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#define CLASS_DEBUG 1
#import "DDGMacros.h"

#import "SilentTextStrings.h"
#import "App.h"
#import "App+Model.h"

#import "Siren.h"

#import "XMPPServer.h"
#import "SCAccount.h"

#import "XMPPMessage+SilentCircle.h"
#import "XMPPIQ.h"
#import "NSManagedObjectContext+DDGManagedObjectContext.h"
#import "ConversationManager.h"
#import "ConversationViewController.h"

#import "ComposeViewController.h"
#import "ChatViewController.h"
#import "XMPPJID.h"
#import "XMPPJID+AddressBook.h"

#import <AddressBook/AddressBook.h>
#import "MGLoadingView.h"
#import "NetworkActivityIndicator.h"

@interface composeTableItem : NSObject  

@property (nonatomic, copy) NSString *nameString;
@property (nonatomic, copy)  XMPPJID *jid;
@end

@implementation composeTableItem;
  
@synthesize nameString = _nameString;
@synthesize jid = _jid;

+ (composeTableItem *)itemWithJid:(XMPPJID *)jid username:(NSString *)nameString
{
     
    composeTableItem *item = [[composeTableItem alloc] init];
    item.jid = [jid copy];
    item.nameString = [nameString copy];
    return item;
}
 
@end;




@interface ComposeViewController ()
{
    BOOL        letUserSelectRow;
    BOOL            searching;
    
}

 
@property (nonatomic, strong) MGLoadingView *loadingView;
@property (nonatomic, strong) NSString        *queryQid;
@property (nonatomic, strong) XMPPJID         *selectedJid;
@property (nonatomic, strong) NSArray         *jidArray;
 

@end

@implementation ComposeViewController
 
@synthesize xmppStream = _xmppStream;

@synthesize searchDisplayController;
@synthesize searchBar;
@synthesize allItems;
@synthesize searchResults;
@synthesize loadingView     = _loadingView;
@synthesize queryQid        =  _queryQid;
@synthesize selectedJid     = _selectedJid;
@synthesize jidArray        = _jidArray;

#pragma mark - loadingView

- (MGLoadingView *) loadingView {
    
    if (_loadingView) { return _loadingView; }
    
    MGLoadingView *lv = [MGLoadingView.alloc initWithView: self.view
                                                    label: NSLS_COMMON_VERIFYING];
    self.loadingView = lv;
    
    return lv;
    
} // -loadingView

- (void) startActivityIndicatorForJid: (XMPPJID*) jid
{
    
    [NetworkActivityIndicator.sharedNetworkActivityIndicator startNetworkActivityIndicator];
    
    MGLoadingView *lv = self.loadingView;
    lv.label.text = [NSString stringWithFormat:NSLS_COMMON_VERIFYING_USER, [jid user]];
    
    [self.view addSubview: lv];
    
    [lv.activityIndicatorView startAnimating];
    [lv fadeIn];
    
    self.searchBar.hidden = YES;
     
    [self.searchBar resignFirstResponder];
    
}

- (void) stopActivityIndicator
{
    self.searchBar.hidden = NO;

    [NetworkActivityIndicator.sharedNetworkActivityIndicator stopNetworkActivityIndicator];
    
    if(self.loadingView)
    {
        [self.loadingView.activityIndicatorView stopAnimating];
        [self.loadingView fadeOut];
    }
}

#pragma mark - Compose view


-(ComposeViewController *) registerForXMPPStreamDelegate {
    
    DDGTrace();
    
    [self.xmppStream removeDelegate: self];
    [self.xmppStream    addDelegate: self delegateQueue: dispatch_get_main_queue()];
    
    return self;
    
} // -registerForXMPPDelegate


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    App *app = App.sharedApp;

    [super viewDidLoad];
    
    [self registerForXMPPStreamDelegate];
    
    // [self.tableView reloadData];
    self.tableView.scrollEnabled = YES;
      
    NSMutableArray *items =  [[NSMutableArray alloc] init];
  
    self.jidArray = [XMPPJID silentCircleJids];
  
    // filter out any conversations we already have
    
    for(XMPPJID* jid in self.jidArray)
    {
        if(! [app.conversationManager conversationForLocalJidExists: app.currentJID remoteJid: jid] )
        {
            composeTableItem * item = [composeTableItem itemWithJid: jid username: [jid addressBookName]];
            [items addObject:item];
         }
           
     }
     
    self.allItems = items;
    [self.tableView reloadData];

    self.selectedJid = NULL;
    searching = NO;
	letUserSelectRow = YES;

}

- (void)viewDidUnload
{
    [super viewDidUnload];
     
 }

-(void) viewWillAppear: (BOOL) animated {
 
    [super viewWillAppear: animated];
    
    self.navigationItem.title = NSLocalizedString(@"Enter Contact", @"Enter Contact");
    
    for (UIView *searchBarSubview in [self.searchBar subviews]) {
        
        if ([searchBarSubview conformsToProtocol:@protocol(UITextInputTraits)]) {
            [(UITextField *)searchBarSubview setReturnKeyType:UIReturnKeySend];
            [(UITextField *)searchBarSubview setKeyboardAppearance:UIKeyboardAppearanceAlert];
        }
    }
   
      
} // -viewWillAppear:

// Since this view is only for searching give the UISearchBar
// focus right away
- (void)viewDidAppear:(BOOL)animated {
 
//    [self.searchBar becomeFirstResponder];
    [super viewDidAppear:animated];
}



-( void) viewWillDisappear:(BOOL)animated
{
    [self stopActivityIndicator];
    
    self.selectedJid = NULL;
    self.jidArray = NULL;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}



- (void) dealloc {
    
    [self.xmppStream removeDelegate: self];
    
} // -dealloc




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
        cell.detailTextLabel.text = [item.jid bare];
    }
    else
    {
        composeTableItem*  item = [self.allItems objectAtIndex:indexPath.row];
        
        cell.textLabel.text = item.nameString;
        cell.detailTextLabel.text = [item.jid bare];
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

#pragma mark - XMPPStream  methods

- (void) createConversationForJid: (XMPPJID*) jid
{
     App *app = App.sharedApp;
     ConversationViewController *cvc =  app.conversationViewController;
     cvc.openJidOnView = jid;
     
    [app.conversationManager sendPingSirenMessageToRemoteJID: jid];
    
    [self.navigationController popToRootViewControllerAnimated:NO];

    
}

- (void) checkJIDValidity:(XMPPJID*) jid
{
    self.selectedJid = jid;
    [self startActivityIndicatorForJid: jid];
    [self sendQueryForUser: jid];
    
}

- (void)sendQueryForUser: (XMPPJID*) jid
{
    
    App *app = App.sharedApp;
    XMPPStream * xmppStream = app.xmppServer.xmppStream;
    
//    <iq to='silentcircle.com' id='consolec9a19f0' type='get'>
//    <query xmlns='http://silentcircle.com/protocol/privacy#privs'
//    jid='daphne@silentcircle.com'/>
//   </iq>
   
    self.queryQid = [XMPPStream generateUUID];
    
    XMPPJID* serverJid = [XMPPJID jidWithString: app.currentAccount.accountDomain];
    
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"http://silentcircle.com/protocol/privacy#privs"];
      
   [query addAttributeWithName:@"jid" stringValue:[jid bare]];

    XMPPIQ *iq = [XMPPIQ iqWithType:@"get" to:serverJid elementID:self.queryQid child:query];
    
    DDGDesc(iq);
    
	[xmppStream sendElement:iq];
}


- (XMPPIQ *) xmppStream: (XMPPStream *) sender willReceiveIQ: (XMPPIQ *) iq {
    
         DDGDesc(iq.compactXMLString);
     
    NSString* iqID = [[iq attributeForName: kXMPPID] stringValue];
    
    NSXMLElement* privs =  [iq elementForName:@"privs" xmlns:@"http://silentcircle.com/protocol/privacy#privs"]; 
    NSXMLElement* presence =  privs?[privs elementForName:@"presence"]:NULL;
    
    if((iqID && self.queryQid) && [iqID isEqualToString: self.queryQid])
    {
        [self stopActivityIndicator];
        
        NSString* status =  [iq attributeStringValueForName:@"type"] ;
        
        if(status)
        {
            if([status isEqualToString: @"result"] && privs && presence)
            {
                [self createConversationForJid: self.selectedJid];
             }
            else 
            {
                
                [[[UIAlertView alloc] initWithTitle:NSLS_COMMON_INVALID_USER
                                            message:
                                        [NSString stringWithFormat:NSLS_COMMON_INVALID_USER_DETAIL,[self.selectedJid user]]
                                           delegate:nil cancelButtonTitle:NSLS_COMMON_OK otherButtonTitles:nil] show];               
            }
        }
        

    }
    
    return iq;
    
} // -xmppStream:willReceiveIQ:



@end
