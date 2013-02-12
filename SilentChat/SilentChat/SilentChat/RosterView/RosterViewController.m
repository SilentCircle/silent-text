/*
Copyright © 2012-2013, Silent Circle, LLC.  All rights reserved.

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
//  RosterViewController.m
//  SilentChat
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "RosterViewController.h"

#import "InfoViewController.h"
#import "ChatViewController.h"

#import "RosterManager.h"

#import "SCAccount.h"
#import "SCPPServer.h"
#import "ConversationManager.h"
#import "App.h"

#import "Siren.h"

#import "ServiceCredential.h"
#import "ServiceServer.h"

#import "SCPPStanzaConstants.h"
#import "XMPPMessage+SilentCircle.h"

#import "XMPPvCardAvatarModule.h"
#import "XMPPUserCoreDataStorageObject.h"

#import "NSManagedObjectContext+DDGManagedObjectContext.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

@interface RosterViewController ()

@property (strong, nonatomic) NSFetchedResultsController *frc;
@property (strong, nonatomic) id<XMPPUser> xmppUserForAlert;

@end

@implementation RosterViewController

@synthesize tableView = _tableView;
@synthesize autoPop = _autoPop;
@synthesize frc = _frc;
@synthesize xmppUserForAlert = _xmppUserForAlert;

- (void) dealloc {
    
    XMPPServer *xmppServer = App.sharedApp.xmppServer;
    
    [xmppServer.xmppStream removeDelegate: self];
    
} // -dealloc


NSString *const kJIDBare = @"jid.bare";

- (XMPPUserCoreDataStorageObject *) userForJID: (XMPPJID *) jid {
    
    if (jid) {
        
        NSManagedObjectContext *moc = App.sharedApp.xmppServer.mocRoster;
        
        NSPredicate *p = [NSPredicate predicateWithFormat: @"%K == %@", kJIDBare, jid.bare];
        
        NSArray *users = nil;
        
        users = [moc fetchObjectsForEntity: @"XMPPUserCoreDataStorageObject"];
        users = [users filteredArrayUsingPredicate: p];
        
        NSString *resource = jid.resource;
        
        // Find the user with the right resource.
        for (XMPPUserCoreDataStorageObject *user in users) {
            
            if ([user.primaryResource.jid.resource isEqualToString: resource]) {
                
                return user;
            }
        }  
        return users.lastObject;
    }
    return nil;
    
} // -userForJID:


NSString *const kJIDStr = @"jidStr";

- (NSFetchedResultsController *) makeFetchedResultsController {
    
    DDGTrace();
    
    NSFetchedResultsController *frc = nil;
    
    if (App.sharedApp.xmppServer) {
        
        NSManagedObjectContext *moc = App.sharedApp.xmppServer.mocRoster;
        
        NSFetchRequest *request = NSFetchRequest.new;
        
        request.entity = [NSEntityDescription entityForName: @"XMPPUserCoreDataStorageObject"
                                     inManagedObjectContext: moc];
        
        NSSortDescriptor *sd1 = [NSSortDescriptor.alloc initWithKey: @"sectionNum"  ascending: YES];
        NSSortDescriptor *sd2 = [NSSortDescriptor.alloc initWithKey: @"displayName" ascending: YES];
        
        request.sortDescriptors = [NSArray arrayWithObjects:sd1, sd2, nil];
        request.fetchBatchSize = 10;
        request.predicate = [NSPredicate predicateWithFormat: @"%K != %@", kJIDStr, App.sharedApp.xmppServer.myJID.bare];
        
        frc = [NSFetchedResultsController.alloc initWithFetchRequest: request
                                                managedObjectContext: moc
                                                  sectionNameKeyPath: @"sectionNum"
                                                           cacheName: nil];
        frc.delegate = self;
        
        NSError *error = nil;
        
        if (![frc performFetch: &error]) {
            
            DDGLog(@"Error performing fetch: %@", error);
        }
    }
	return frc;
    
} // -makeFetchedResultsController


- (void) viewDidLoad {
    
    DDGTrace();
    
    [super viewDidLoad];
    
} // -viewDidLoad


- (void) viewDidUnload {
    
    DDGTrace();
    
    [super viewDidUnload];

} // -viewDidUnload


- (void) viewWillAppear: (BOOL) animated {
    
    DDGTrace();
    
    [super viewWillAppear: animated];

    XMPPServer *xmppServer = App.sharedApp.xmppServer;
    
    if (xmppServer) {
        
        // Ensure we are only called by the multicast delegate once.
        [xmppServer.xmppStream removeDelegate: self];
        [xmppServer.xmppStream    addDelegate: self delegateQueue: dispatch_get_main_queue()];
        
        [App performBlock: ^{ [xmppServer connect]; }];
    }
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


- (void) viewDidAppear: (BOOL) animated {
    
    DDGTrace();
    
    [super viewDidAppear: animated];
    
    self.navigationItem.title = [RosterManager displayNameForJID: App.sharedApp.currentAccount.jid.full];
    
} // -viewDidAppear:


- (void) viewWillDisappear: (BOOL) animated {
    
    DDGTrace();
    
	[super viewWillDisappear: animated];
    
} // -viewWillDisappear:


- (void) viewDidDisappear: (BOOL) animated {
    
    DDGTrace();
    
	[super viewDidDisappear: animated];
    
} // -viewDidDisappear:


- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) toInterfaceOrientation {
    
    return (toInterfaceOrientation == UIInterfaceOrientationPortrait);

} // -shouldAutorotateToInterfaceOrientation:


#pragma mark - Instance methods.


- (IBAction) composeItem: (UIBarButtonItem *) sender {
    
    DDGTrace();
    
} // -composeItem:


- (IBAction) showInfo: (UIButton *) sender {
    
    DDGTrace();
    
    InfoViewController *ivc = [[InfoViewController alloc] 
                               initWithNibName: @"InfoViewController" 
                               bundle: nil];
    [self.navigationController pushViewController: ivc animated: YES];
    
} // -showInfo:


#pragma mark - UITableViewDataSource methods.


// Customize the number of sections in the table view.
- (NSInteger) numberOfSectionsInTableView: (UITableView *) tableView {
    
    DDGTrace();
    
    return self.frc.sections.count;
    
} // -numberOfSectionsInTableView:


- (NSInteger) tableView: (UITableView *) tableView numberOfRowsInSection: (NSInteger) section {
    
    DDGTrace();
    
    id<NSFetchedResultsSectionInfo> sectionInfo = [self.frc.sections objectAtIndex: section];
    
    return [sectionInfo numberOfObjects];
    
} // -tableView:numberOfRowsInSection: 


NSString *const kAvailable = @"Available";
NSString *const kAway = @"Away";
NSString *const kOffline = @"Offline";

- (NSString *) tableView: (UITableView *) sender titleForHeaderInSection: (NSInteger) sectionIndex {
    
	NSArray *sections = self.frc.sections;
	
	if (sectionIndex < sections.count) {
        
		id<NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex: sectionIndex];
        
		int section = sectionInfo.name.intValue;
        
		switch (section) {
                
			case 0  : return kAvailable;
			case 1  : return kAway;
			default : return kOffline;
		}
	}
	return kEmptyString;
}

- (UIImage *) photoForUser: (XMPPUserCoreDataStorageObject *) user {
    
	// Our xmppRosterStorage will cache photos as they arrive from the xmppvCardAvatarModule.
	// We only need to ask the avatar module for a photo, if the roster doesn't have it.
	
	if (user.photo) {
        
		return user.photo;
	} 
	else {
        
		NSData *photoData = [App.sharedApp.xmppServer.xmppvCardAvatarModule photoDataForJID: user.jid];
        
        return photoData ? [UIImage imageWithData: photoData] : [UIImage imageNamed: @"defaultPerson"];
	}

} // -photoForUser:


- (BOOL) sectionIsAvailableForIndexPath: (NSIndexPath *) indexPath {
    
    NSArray *sections = self.frc.sections;
    
    id<NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex: indexPath.section];
    
    int section = sectionInfo.name.intValue;
    
    switch (section) {
            
        case 0  : return YES;
        default : return NO;
    }
    
} // -sectionIsAvailableForIndexPath:


- (UITableViewCell *) configureCell: (UITableViewCell *) cell atIndexPath: (NSIndexPath *) indexPath {
    
    DDGTrace();
    
    XMPPUserCoreDataStorageObject *user = [self.frc objectAtIndexPath: indexPath];
    
	cell.textLabel.text  = [RosterManager displayNameForJID: user.jidStr];
    cell.imageView.image = [self photoForUser: user];

    cell.textLabel.textColor = UIColor.blackColor;
    cell.selectionStyle  = UITableViewCellSelectionStyleBlue;

    if (![self sectionIsAvailableForIndexPath: indexPath]) {
        
        cell.textLabel.textColor = UIColor.grayColor;
        cell.selectionStyle      = UITableViewCellSelectionStyleNone;
    }
    return cell;
    
} // -configureCell:atIndexPath:


// Customize the appearance of table view cells.
- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath {
    
    DDGTrace();
    
    static NSString *CellIdentifier = @"RosterCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier];
    
    if (!cell) {
        
        cell = [UITableViewCell.alloc initWithStyle: UITableViewCellStyleDefault 
                                    reuseIdentifier: CellIdentifier];
    }
    return [self configureCell: cell atIndexPath: indexPath];
    
} // -tableView:cellForRowAtIndexPath:


//- (void) tableView: (UITableView *) tableView 
//commitEditingStyle: (UITableViewCellEditingStyle) editingStyle 
// forRowAtIndexPath: (NSIndexPath *) indexPath {
//    
//    if (editingStyle == UITableViewCellEditingStyleDelete) {
//        
//        PunchItem *punchItem = (PunchItem *)[self.frc objectAtIndexPath: indexPath];
//        
//        [punchItem.managedObjectContext deleteObject: punchItem];
//    }
//    
//} // -tableView:commitEditingStyle:forRowAtIndexPath:


#pragma mark - UITableViewDelegate methods.


- (void) tableView: (UITableView *) tableView didSelectRowAtIndexPath: (NSIndexPath *) indexPath {
    
    DDGTrace();
    
    App *app = App.sharedApp;
    
    ChatViewController *cvc = [ChatViewController.alloc initWithNibName: @"ChatViewController" bundle: nil];
    
    cvc.xmppStream = app.xmppServer.xmppStream;
    cvc.conversation = [app.conversationManager conversationForLocalJid: cvc.xmppStream.myJID 
                                                              remoteJid: [[[self.frc objectAtIndexPath: indexPath] primaryResource ] jid]];

    // Save the navController to allow the push to use it after the autoPop clears it.
    // <http://stackoverflow.com/questions/410471/how-can-i-pop-a-view-from-a-uinavigationcontroller-and-replace-it-with-another-i>
    //
    UINavigationController *navController = self.navigationController; 

    if (self.isAutoPop) {
        
        // Remove ourselves from the stack as we bring on the conversation.
        [navController popViewControllerAnimated: NO];
    }
    [navController pushViewController: cvc animated: YES];
    
} // -tableView:didSelectRowAtIndexPath:


- (NSIndexPath *) tableView: (UITableView *) tableView willSelectRowAtIndexPath: (NSIndexPath *) indexPath {
    
    return [self sectionIsAvailableForIndexPath: indexPath] ? indexPath : nil;
    
} // -tableView:willSelectRowAtIndexPath:


#pragma mark - NSFetchedResultsControllerDelegate methods.


- (void) controllerDidChangeContent: (NSFetchedResultsController *) controller {
    
    DDGTrace();
    
	[self.tableView reloadData];

} // -controllerDidChangeContent:


#pragma mark - UINavigationControllerDelegate methods.


- (void)navigationController: (UINavigationController *) navigationController 
      willShowViewController: (UIViewController *) viewController 
                    animated: (BOOL) animated {
    
    DDGTrace();
    
    if (![viewController isEqual: self]) {
        
        self.navigationItem.title = @"Roster";
        
        if ([viewController isKindOfClass: InfoViewController.class]) {
            
            // Could change the account. Turn off the stream.
            [App.sharedApp.xmppServer disconnectAfterSending];
        }
    }
    if ([viewController conformsToProtocol: @protocol(UINavigationControllerDelegate)]) {
        
        navigationController.delegate = (id<UINavigationControllerDelegate>)viewController;
    }
    
} // -navigationController:willShowViewController:animated:


- (void) navigationController: (UINavigationController *) navigationController 
        didShowViewController: (UIViewController *) viewController 
                     animated: (BOOL) animated {
    
    DDGTrace();
    
    if ([viewController isEqual: self]) {
        
        self.frc = [self makeFetchedResultsController];
        
        // Turn the stream back on.
        [App performBlock: ^{ [App.sharedApp.xmppServer connect]; }];
    }
    
} // -navigationController:didShowViewController:animated:


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
    
} // -xmppStream:didNotAuthenticate:


- (BOOL) xmppStream: (XMPPStream *) sender didReceiveIQ:(XMPPIQ *) iq {
    
//    DDGTrace();
    
    return NO;
    
} // -xmppStream:didReceiveIQ:


- (void) alertView: (UIAlertView *) alertView clickedButtonAtIndex: (NSInteger) buttonIndex {
    
    NSString *buttonTitle = [alertView buttonTitleAtIndex: buttonIndex];
    
    DDGDesc(buttonTitle);
    
    if ([buttonTitle isEqualToString: kYesButton]) {
        
        App *app = App.sharedApp;
        
        ChatViewController *cvc = [ChatViewController.alloc initWithNibName: @"ChatViewController" bundle: nil];
        
        cvc.xmppStream = app.xmppServer.xmppStream;
        cvc.conversation = [app.conversationManager conversationForLocalJid: cvc.xmppStream.myJID 
                                                                  remoteJid: self.xmppUserForAlert.primaryResource.jid];
        [self.navigationController pushViewController: cvc animated: YES];
    }
    else if ([buttonTitle isEqualToString: kNoButton]) {
    }
    self.xmppUserForAlert = nil;
    
} // -alertView:didDismissWithButtonIndex:


- (UIAlertView *) presentAlertForMessage: (XMPPMessage *) message {
    
    DDGTrace();
    
    Siren *siren = [Siren sirenWithChatMessage: message];
    
    self.xmppUserForAlert = [self userForJID: siren.from];
    
    XMPPJID *jid = siren.from;
    
    NSString *name  = [RosterManager displayNameForJID: jid.full];
    NSString *title = [NSString stringWithFormat: @"Message from: %@.", name];
    NSString *messageStr = [NSString stringWithFormat: 
                            @"It is: %@; Would you like to start a conversation with them?", 
                            siren.message];
    UIAlertView *alertView = nil;
    
    alertView = [[UIAlertView alloc] initWithTitle: title
                                           message: messageStr
                                          delegate: self
                                 cancelButtonTitle: kNoButton 
                                 otherButtonTitles: kYesButton, nil];
    [alertView show];
    
    return alertView;
    
} // -presentAlertForMessage:


- (void) xmppStream: (XMPPStream *) sender didReceiveMessage: (XMPPMessage *) message {
    
    DDGDesc(message.compactXMLString);
    
    if (message.isChatMessageWithBody) {
        
//        if ([self.navigationController.topViewController isEqual: self]) {
//            
//            [self presentAlertForMessage: message];
//        }
    }
    
} // -xmppStream:didReceiveMessage:


- (void) xmppStream: (XMPPStream *) sender didReceivePresence: (XMPPPresence *) presence {
    
//    DDGTrace();
    
    XMPPJID *from = presence.from;
    
    if ([sender.myJID.bare isEqualToString: from.bare]) { // if from ourself...
        
        self.navigationItem.title = [RosterManager displayNameForJID: from.full];
    }
    
} // -xmppStream:didReceivePresence:


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
