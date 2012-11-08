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

#import "AppConstants.h"
#import "ConversationViewController.h"
#import "SilentTextStrings.h"

#import "SettingsViewController.h"

#import "ChatViewController.h"
#import "ComposeViewController.h"

#import "SCPPServer.h"
#import "App+Model.h"

#import "XMPPJID+AddressBook.h"

#import "Conversation.h"
#import "ConversationManager.h"
#import "ConversationViewTableCell.h"
#import "Missive.h"
#import "Siren.h"
#import "PasscodeViewController.h"

#import "Reachability.h"
#import "XMPPMessage+SilentCircle.h"
#import "NSManagedObjectContext+DDGManagedObjectContext.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

NSString *const kConversationCellIdentifier = @"ConversationCell";

static NSString *const kReplyIcon = @"replyarrow_flat";
static NSString *const kAttentionIcon = @"attention";
static NSString *const kGearColorIcon = @"gear_grey";

static NSString *const kKey1Icon = @"key1";
static NSString *const kKey2Icon = @"key2";
static NSString *const kKey3Icon = @"key3";
static NSString *const kKey4Icon = @"key4";

@interface ConversationViewController ()

@property (strong, nonatomic) NSFetchedResultsController *frc;
@property (strong, nonatomic) NSString *remoteJIDForAlert;

@property (nonatomic, retain) UIImage *attentionImage;
@property (nonatomic, retain) UIImage *replyImage;

@property (nonatomic, retain) UIImage *key1Image;
@property (nonatomic, retain) UIImage *key2Image;
@property (nonatomic, retain) UIImage *key3Image;
@property (nonatomic, retain) UIImage *key4Image;

@end

@implementation ConversationViewController

@synthesize tableView = _tableView;
@synthesize frc = _frc;
@synthesize remoteJIDForAlert = _remoteJIDForAlert;

@synthesize openJidOnView = _openJidOnView;

typedef enum
{
	kRightButtonState_Compose ,
	kRightButtonState_NoNetwork ,
    kRightButtonState_Connecting ,
    
} ConversationViewRightButtonState;



#pragma mark - notifications

#define kBecomeActive  (@selector(becomeActive:))
- (void) becomeActive: (NSNotification *) notification {
    
    BOOL hasNetwork = (NotReachable != [[App sharedApp].reachability currentReachabilityStatus]);
   
    [self configureRightButton: kRightButtonState_NoNetwork];

    if(![App sharedApp].passcodeManager.isLocked && hasNetwork)
        [self reconnectServer];
    
    [self.tableView reloadData];
}


#define kReachabilityChanged  (@selector(reachabilityChanged:))
- (void) reachabilityChanged: (NSNotification* )notification
{
    Reachability* curReach = [notification object];
    
    BOOL hasNetwork = (NotReachable != [curReach currentReachabilityStatus]);
    
    [self configureRightButton: kRightButtonState_NoNetwork];

    if(![App sharedApp].passcodeManager.isLocked && hasNetwork)
        [self reconnectServer];
}

#pragma mark - Conversation View methods.

- (void) dealloc {
    
    XMPPServer *xmppServer = App.sharedApp.xmppServer;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    [xmppServer.xmppStream removeDelegate: self];
    
} // -dealloc


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
       
        self.replyImage =   [UIImage imageNamed: kReplyIcon];
        self.attentionImage =   [UIImage imageNamed: kAttentionIcon];
   
        self.key1Image =   [UIImage imageNamed: kKey1Icon];
        self.key2Image =   [UIImage imageNamed: kKey2Icon];
        self.key3Image =   [UIImage imageNamed: kKey3Icon];
        self.key4Image =   [UIImage imageNamed: kKey4Icon];
        
        self.openJidOnView = NULL;
         
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        
        [nc addObserver: self
               selector:  kBecomeActive
                   name: UIApplicationDidBecomeActiveNotification
                 object: nil];
        
        [nc addObserver: self
                     selector: kReachabilityChanged
                         name: kReachabilityChangedNotification
                       object: nil];
     }
    return self;
}


- (NSFetchedResultsController *) makeFetchedResultsController {
    
    DDGTrace();
    
    NSFetchedResultsController *frc = nil;
    
    if (App.sharedApp.xmppServer) {
        
        NSManagedObjectContext *moc = App.sharedApp.moc;
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName: kConversationEntity];
        
        request.sortDescriptors = [NSArray arrayWithObject: [NSSortDescriptor.alloc initWithKey: kDate ascending: NO]];
        
        frc = [NSFetchedResultsController.alloc initWithFetchRequest: request
                                                managedObjectContext: moc
                                                  sectionNameKeyPath: nil
                                                           cacheName: nil];
        frc.delegate = self;
        
        NSError *error = nil;
        
        if (![frc performFetch: &error]) {
            
            DDGLog(@"Error performing fetch: %@", error);
        }
    }
	return frc;
    
} // -makeFetchedResultsController


#pragma mark - View methods.



- (UINavigationItem *) configureRightButton: (ConversationViewRightButtonState)state
{
    
    switch(state)
    {
        case kRightButtonState_Compose:
        {
            self.navigationItem.rightBarButtonItem =
                                            [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem: UIBarButtonSystemItemCompose
                                             target: self
                                             action:@selector(composeItem:)];
                                            
            self.navigationItem.rightBarButtonItem.enabled = YES;
        }
        break;
            
        case kRightButtonState_NoNetwork:
        {
            self.navigationItem.rightBarButtonItem =
                                            [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem: UIBarButtonSystemItemCompose
                                             target: self
                                             action:@selector(composeItem:)];
           
            self.navigationItem.rightBarButtonItem.enabled = NO;
        }
        break;
            
        case kRightButtonState_Connecting:
        {
            UIActivityIndicatorView *aiv =
                                    [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            UIBarButtonItem *activityButtonItem = [[UIBarButtonItem alloc] initWithCustomView:aiv];
            [aiv startAnimating];
            
            self.navigationItem.rightBarButtonItem = activityButtonItem;
        }
        break;
            
    }
 
   return self.navigationItem;
 }
 

- (UINavigationItem *) configureNavigationItem
{
    // setup the gear button
    UIImage *gearImage = [UIImage imageNamed:kGearColorIcon];
    UIButton *gearButton = [UIButton buttonWithType:UIButtonTypeCustom];
    gearButton.frame = CGRectMake(0.0, 0.0, 24 , 24 );
    [gearButton setImage:gearImage forState:UIControlStateNormal];
    
    UIBarButtonItem *gearButtonItem = [UIBarButtonItem.alloc initWithCustomView:gearButton];
    [gearButton addTarget:self action:@selector(showSettings:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = gearButtonItem;
     
     [self configureRightButton: kRightButtonState_NoNetwork];
     return self.navigationItem;
    
} // -configureNavigationItem





- (void)viewDidLoad
{
    [super viewDidLoad];
    [self configureNavigationItem];
    
 //   self.navigationItem.title =  NSLS_COMMON_SILENT_TEXT;
 
    self.openJidOnView = NULL;

}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    // openJidOnView will be set to a jid if the compose screen selected a new person.
    if(self.openJidOnView)
    {
        App *app = App.sharedApp;
        
        ChatViewController *cvc = [ChatViewController.alloc initWithNibName: nil bundle: nil];
        
        cvc.xmppStream = app.xmppServer.xmppStream;
        cvc.conversation = [app.conversationManager
                            conversationForLocalJid: cvc.xmppStream.myJID
                            remoteJid: self.openJidOnView];
        
        [self.navigationController pushViewController:cvc animated:YES];
        
        self.openJidOnView = NULL;
    }
}

-(void) viewWillAppear: (BOOL) animated {
    
    DDGTrace();
    
    [super viewWillAppear: animated];
     
     if(![App sharedApp].passcodeManager.isLocked)
         [self reconnectServer];
    
    if (self.frc) {
        
        NSError *error = nil;
        
        if (![self.frc performFetch: &error]) {
            
            DDGLog(@"Error performing fetch: %@", error);
        }
    }
    else {
        
        self.frc = [self makeFetchedResultsController];
    }
  
    [self.tableView reloadData];
         
} // -viewWillAppear:


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
//    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark - Utility methods.

-(void) reconnectServer
{
    XMPPServer *xmppServer = App.sharedApp.xmppServer;
    BOOL hasNetwork = (NotReachable != [[App sharedApp].reachability currentReachabilityStatus]);
    
    if (xmppServer && hasNetwork) {
        // Ensure we are only called by the multicast delegate once.
        [xmppServer.xmppStream removeDelegate: self];
        [xmppServer.xmppStream    addDelegate: self delegateQueue: dispatch_get_main_queue()];
        
        [App performBlock: ^{ [xmppServer connect]; }];
    }
    
}

- (Conversation *) conversationAtIndexPath: (NSIndexPath *) indexPath {
    
    Conversation *conversation = [self.frc objectAtIndexPath: indexPath];

    conversation.delegate = App.sharedApp.conversationManager; // Connect up encryption services.

    return conversation;
    
} // -conversationAtIndexPath:



#pragma mark - IBAction methods.
 
- (IBAction) composeItem: (UIBarButtonItem *) sender {
    
    DDGTrace();
    
    App *app = App.sharedApp;
    ComposeViewController *cvc = [ComposeViewController.alloc initWithNibName: @"ComposeViewController" bundle: nil];
    
    cvc.xmppStream = app.xmppServer.xmppStream;
    
    [self.navigationController pushViewController: cvc animated: YES];
  
      
} // -composeItem:



- (IBAction) showSettings: (UIButton *) sender {
    
    DDGTrace();
 
    
    QRootElement *details = [SettingsViewController createSettingsForm];
  
    QuickDialogController *svc = [QuickDialogController controllerForRoot:details];
 
    [self.navigationController pushViewController: svc animated: YES];
        
} // -showSettings:


#pragma mark - UITableViewDataSource methods.


// Customize the number of sections in the table view.
- (NSInteger) numberOfSectionsInTableView: (UITableView *) tableView {
    
//    DDGTrace();
     
    App *app = App.sharedApp;
    
    if( app.passcodeManager.isLocked)
    {
        
        PasscodeViewController *pvc = [PasscodeViewController.alloc
                                       initWithNibName:nil
                                       bundle: nil
                                       mode: PasscodeViewControllerModeVerify];
        
        UINavigationController *navigation =
        [[UINavigationController alloc] initWithRootViewController:pvc];
        
        [self presentModalViewController:navigation animated:NO];
        return 0;
    }
    else
        return  self.frc.sections.count;
    
 //   return app.passcodeManager.isLocked? 0: self.frc.sections.count;
    
} // -numberOfSectionsInTableView:


- (NSInteger) tableView: (UITableView *) tableView numberOfRowsInSection: (NSInteger) section {
    
//    DDGTrace();
    
    id<NSFetchedResultsSectionInfo> sectionInfo = [self.frc.sections objectAtIndex: section];
    
    return [sectionInfo numberOfObjects];
    
} // -tableView:numberOfRowsInSection: 


- (UITableViewCell *) configureCell: (ConversationViewTableCell *) cell atIndexPath: (NSIndexPath *) indexPath {
 
    //    DDGTrace();
  
    BOOL  wasReply = NO;
    Conversation *conversation = [self conversationAtIndexPath: indexPath];
   
    cell.subTitleString = @"";
    cell.leftBadgeImage = NULL;
  
    if (conversation.missives.count)
    {
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:kDate  ascending:NO];
        NSArray *missives = [conversation.missives.allObjects
                             sortedArrayUsingDescriptors: [NSArray arrayWithObject:sortDescriptor]];
        
        Missive* missive = [missives objectAtIndex:0];
        Siren * siren = missive.siren;
        
        cell.subTitleString = siren.message;
        wasReply = [conversation.remoteJID isEqualToString: missive.toJID];
    }
    
    cell.avatar  = [XMPPJID userAvatarWithJIDString: conversation.remoteJID];
    cell.titleString = [XMPPJID userNameWithJIDString: conversation.remoteJID];
    cell.date = conversation.date;

    if(conversation.flags & (1 << kConversationFLag_Attention))
    {
        cell.leftBadgeImage = self.attentionImage;
        cell.badgeString = NULL;
        
    }
    else if(conversation.conversationState != kConversationState_Run)
    {
        cell.badgeString = NULL;
        
        switch (conversation.conversationState)
        {
            case kConversationState_Commit:    cell.leftBadgeImage = self.key2Image; break;
            case kConversationState_DH1:       cell.leftBadgeImage = self.key2Image; break;
                
            case kConversationState_DH2:       cell.leftBadgeImage = self.key3Image; break;
            case kConversationState_Confirm:   cell.leftBadgeImage = self.key3Image; break;
                
            case kConversationState_Ready:     cell.leftBadgeImage = self.key4Image; break;
                
            case kConversationState_Init:      cell.leftBadgeImage = self.key1Image; break;
    
                
            default:                        cell.leftBadgeImage = self.attentionImage; break;
         }
     }
    else if(wasReply)
    {
        cell.leftBadgeImage = self.replyImage;
        cell.badgeString = NULL;
   }
    else if(conversation.notRead > 0)
    {
        
        cell.badgeString = [NSNumberFormatter
                            localizedStringFromNumber:[NSNumber numberWithInt:conversation.notRead]
                            numberStyle:NSNumberFormatterNoStyle];
        
 //        cell.badgeString = [NSString stringWithFormat:@"%d", conversation.notRead] ;
    }
    else
    {
        cell.badgeString = NULL;
    }
 
    return cell;
    
} // -configureCell:atIndexPath:


// Customize the appearance of table view cells.
- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath {
    
//    DDGTrace();
     ConversationViewTableCell *cell = (ConversationViewTableCell *)[tableView dequeueReusableCellWithIdentifier:kConversationCellIdentifier];
   
    if (cell == nil) {
        cell = [[ConversationViewTableCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kConversationCellIdentifier];
      }
    
    return [self configureCell: cell atIndexPath: indexPath];
    
} // -tableView:cellForRowAtIndexPath:


- (void) tableView: (UITableView *) tableView 
commitEditingStyle: (UITableViewCellEditingStyle) editingStyle 
 forRowAtIndexPath: (NSIndexPath *) indexPath {
    
    DDGDesc([self conversationAtIndexPath: indexPath]);
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
 
        Conversation *conversation = [self conversationAtIndexPath: indexPath];
   
        // delete the current SCIMP object also.
        [XMPPSilentCircle  removeSecureContextForJid:
                    [XMPPJID jidWithString: conversation.remoteJID]];
        
         [conversation.managedObjectContext deleteObject: conversation];
        
         [conversation.managedObjectContext save];
    }
    
} // -tableView:commitEditingStyle:forRowAtIndexPath:


#pragma mark - UITableViewDelegate methods.

- (void) setChatViewBackButtonCount:(UInt16)count
{
	if ( self.navigationItem.backBarButtonItem) {
		NSString	*backTitle,
					*backString = NSLocalizedString(@"Back",nil);
		if (count)
			backTitle = [NSString stringWithFormat:@"%@ (%d)", backString, count];
		else
			backTitle = backString;
		self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:backTitle
												 
																				 style:UIBarButtonItemStyleBordered
												 
																				target:nil
												 
																				action:nil];

	}
}

- (void) tableView: (UITableView *) tableView didSelectRowAtIndexPath: (NSIndexPath *) indexPath {
    
//    DDGTrace();
    
    Conversation *conversation = [self conversationAtIndexPath: indexPath];
    
    ChatViewController *cvc = [ChatViewController.alloc initWithNibName: nil bundle: nil];
    
    cvc.xmppStream   = App.sharedApp.xmppServer.xmppStream;
    cvc.conversation = conversation;
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back",nil)
	 
                                     style:UIBarButtonItemStyleBordered
	 
                                    target:nil
	 
                                    action:nil];

    [self.navigationController pushViewController: cvc animated: YES];
    [self setChatViewBackButtonCount:0];
} // -tableView:didSelectRowAtIndexPath:


#pragma mark - NSFetchedResultsControllerDelegate methods.


- (void) controllerWillChangeContent: (NSFetchedResultsController *) controller {
    
    [self.tableView beginUpdates];
    
} // -controllerWillChangeContent:


- (void) controller: (NSFetchedResultsController *) controller 
   didChangeSection: (id <NSFetchedResultsSectionInfo>) sectionInfo
            atIndex: (NSUInteger) sectionIndex 
      forChangeType: (NSFetchedResultsChangeType) type {
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            
            [self.tableView insertSections: [NSIndexSet indexSetWithIndex: sectionIndex] withRowAnimation: UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            
            [self.tableView deleteSections: [NSIndexSet indexSetWithIndex: sectionIndex] withRowAnimation: UITableViewRowAnimationFade];
            break;
    }

} // -controller:didChangeSection:atIndex:forChangeType:


- (void) controller: (NSFetchedResultsController *) controller 
    didChangeObject: (id) anObject
        atIndexPath: (NSIndexPath *) indexPath 
      forChangeType: (NSFetchedResultsChangeType) type
       newIndexPath: (NSIndexPath *) newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            
            [tableView insertRowsAtIndexPaths: [NSArray arrayWithObject: newIndexPath] withRowAnimation: UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            
            [tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject: indexPath] withRowAnimation: UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            
            [self configureCell: (ConversationViewTableCell *)[tableView cellForRowAtIndexPath: indexPath] atIndexPath: indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            
            [tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject:    indexPath] withRowAnimation: UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths: [NSArray arrayWithObject: newIndexPath] withRowAnimation: UITableViewRowAnimationFade];
            break;
    }

} // -controller:didChangeObject:atIndexPath:forChangeType:newIndexPath:


- (void) controllerDidChangeContent: (NSFetchedResultsController *) controller {
    
    [self.tableView endUpdates];
    
} // -controllerDidChangeContent:


#pragma mark - XMPPStreamDelegate methods.


- (void) xmppStreamDidAuthenticate: (XMPPStream *) sender {
    
    DDGTrace();
    
    NSError *error = nil;
    
    if (![self.frc performFetch: &error]) {
        
        DDGLog(@"Error performing fetch: %@", error);
    }
    [self.tableView reloadData];
    
} // -xmppStreamDidAuthenticate:


- (void) xmppStream: (XMPPStream *) sender didNotAuthenticate: (NSXMLElement *) error {
    
    DDGTrace();

    [self configureRightButton: kRightButtonState_NoNetwork];
    
    [sender disconnect];

    [[[UIAlertView alloc]
      initWithTitle:NSLS_COMMON_CONNECT_FAILED
      message:NSLS_COMMON_NOT_AUTHORIZED
      delegate:nil
      cancelButtonTitle:NSLS_COMMON_OK
      otherButtonTitles:nil] show];

} // -xmppStream:didNotAuthenticate:


- (BOOL) xmppStream: (XMPPStream *) sender didReceiveIQ:(XMPPIQ *) iq {
    
//    DDGTrace();
    
    return NO;
    
} // -xmppStream:didReceiveIQ:




- (void) xmppStream: (XMPPStream *) sender didReceiveMessage: (XMPPMessage *) message {

    
} // -xmppStream:didReceiveMessage:


- (void) xmppStream: (XMPPStream *) sender didReceivePresence: (XMPPPresence *) presence {
    
    //    DDGTrace();
    DDGDesc(presence.fromStr);
    
    XMPPJID *from = presence.from;
   
    if ([sender.myJID.bare isEqualToString: from.bare]) { // if from ourself...
        
        [self configureRightButton: kRightButtonState_Compose];
    }
    
} // -xmppStream:didReceivePresence:



- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    [self configureRightButton: kRightButtonState_NoNetwork];
     
    if(error)
        [[[UIAlertView alloc]
          initWithTitle:NSLS_COMMON_CONNECT_FAILED
          message:error.localizedDescription
          delegate:nil
          cancelButtonTitle:NSLS_COMMON_OK
          otherButtonTitles:nil] show];
}


- (void)xmppStreamWillConnect:(XMPPStream *)sender
{
    [self configureRightButton: kRightButtonState_Connecting];
 };

- (void) xmppStream: (XMPPStream *) sender didReceiveError: (NSXMLElement *) error {
    
    //    DDGTrace();
    
} // -xmppStream:didReceiveError:


- (XMPPIQ *) xmppStream: (XMPPStream *) sender willSendIQ: (XMPPIQ *) iq {
    
    //    DDGTrace();
    
    return iq;
    
} // -xmppStream:willSendIQ:


- (XMPPMessage *) xmppStream: (XMPPStream *) sender willSendMessage: (XMPPMessage *) message {
    
    //    DDGTrace();
    
    return message;
    
} // -xmppStream:willSendMessage:


- (XMPPPresence *) xmppStream: (XMPPStream *) sender willSendPresence: (XMPPPresence *) presence {
    
    DDGTrace();
    
    return presence;
    
} // -xmppStream:willSendPresence:


- (void) xmppStream: (XMPPStream *) sender didSendIQ: (XMPPIQ *) iq {
    
    //    DDGTrace();
    
} // -xmppStream:didSendIQ:


- (void) xmppStream: (XMPPStream *) sender didSendMessage: (XMPPMessage *) message {
    
    //    DDGTrace();
    
} // -xmppStream:didSendMessage:


- (void) xmppStream: (XMPPStream *) sender didSendPresence: (XMPPPresence *) presence {
    
    DDGTrace();
    
} // -xmppStream:didSendPresence:

@end
