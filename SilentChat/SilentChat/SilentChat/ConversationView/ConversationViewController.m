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
//  ConversationViewController.m
//  SilentText
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif
#import <MobileCoreServices/MobileCoreServices.h>

#import "AppConstants.h"
#import "SilentTextStrings.h"
#import "ConversationViewController.h"
#import "UIViewController+SCUtilities.h"
#import "SilentTextStrings.h"

#import "SettingsViewController.h"

#import "ChatViewController.h"
#import "ComposeViewController.h"

#import "SCPPServer.h"
#import "App+Model.h"

#import "XMPPJID+AddressBook.h"
#import "NSDate+SCDate.h"

#import "Conversation.h"
#import "ConversationManager.h"
#import "ConversationViewTableCell.h"
#import "Missive.h"
#import "SCimpLogEntry.h"
#import "NSString+SCUtilities.h"

#import "Siren.h"
#import "PasscodeViewController.h"

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
static NSString *const kBannerIcon = @"Icon-72";

static NSString *const kAvatarIcon = @"silhouette";

@interface ConversationViewController ()

@property (strong, nonatomic) NSFetchedResultsController *frc;
@property (strong, nonatomic) NSString *remoteJIDForAlert;

@property (nonatomic, retain) UIImage *attentionImage;
@property (nonatomic, retain) UIImage *replyImage;

@property (nonatomic, retain) UIImage *key1Image;
@property (nonatomic, retain) UIImage *key2Image;
@property (nonatomic, retain) UIImage *key3Image;
@property (nonatomic, retain) UIImage *key4Image;
@property (nonatomic, retain) UIImage *avatarImage;

 
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
    
    [self configureRightButton: kRightButtonState_NoNetwork];
    
    if(![App sharedApp].passcodeManager.isLocked)
        [self reconnectServer];
    
    [self.tableView reloadData];
	self.view.hidden = NO;
	[self.view setAlpha:0.0];
	[UIView animateWithDuration:0.5f
					 animations:^{
						 [self.view setAlpha:1.0];
						 //						 self.frame = CGRectMake(self.frame.origin.x,
						 //												 point.y - height,
						 //												 width,
						 //												 height);
						 //			 self.center = CGPointMake(self.center.x, point.y - self.frame.size.height /2);
						 
						 
					 }
					 completion:^(BOOL finished) {
                         self.navigationItem.title =  NSLS_COMMON_SILENT_TEXT;
 					 }];
}
#pragma mark - Standard Notification Methods
- (void)applicationDidEnterBackground
{
//	NSLog(@"%s", __PRETTY_FUNCTION__);
	self.view.hidden = YES;
}
- (void)applicationWillEnterForeground
{
//	NSLog(@"%s", __PRETTY_FUNCTION__);
//	self.view.hidden = NO;
	
}

- (void)applicationWillResignActive
{
//	NSLog(@"%s", __PRETTY_FUNCTION__);
	[UIView animateWithDuration:0.5f
					 animations:^{
						 [self.view setAlpha:0.0];
						 //						 self.frame = CGRectMake(self.frame.origin.x,
						 //												 point.y - height,
						 //												 width,
						 //												 height);
						 //			 self.center = CGPointMake(self.center.x, point.y - self.frame.size.height /2);
						 
						 
					 }
					 completion:^(BOOL finished) {
						 self.view.hidden = YES;
						 self.navigationItem.title =  @"";
					 }];
}

 
#pragma mark - Conversation View methods.

- (void) dealloc {
    
    XMPPServer *xmppServer = App.sharedApp.xmppServer;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    [xmppServer.xmppStream removeDelegate: self];
    
    [App.sharedApp.conversationManager setDelegate:nil];
    

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
        self.avatarImage =  [UIImage imageNamed: kAvatarIcon];

        self.openJidOnView = NULL;
        
        [App.sharedApp.conversationManager setDelegate:self];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        
        [nc addObserver: self
               selector:  kBecomeActive
                   name: UIApplicationDidBecomeActiveNotification
                 object: nil];
		
		[nc addObserver:self
			   selector:@selector(applicationDidEnterBackground)
				   name:UIApplicationDidEnterBackgroundNotification
				 object:nil];
		
		[nc addObserver:self
			   selector:@selector(applicationWillResignActive)
				   name:UIApplicationWillResignActiveNotification
				 object:nil];
		
		[nc addObserver:self
			   selector:@selector(applicationWillEnterForeground)
				   name:UIApplicationWillEnterForegroundNotification
				 object:nil];

        
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
    
    self.navigationItem.title =  NSLS_COMMON_SILENT_TEXT;
 
    self.openJidOnView = NULL;

}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    [App.sharedApp.conversationManager  removeDelegate: self];

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
        [cvc calculateBurnTimes];
        [self.navigationController pushViewController:cvc animated:YES];
        
        self.openJidOnView = NULL;
    }

    
    [App.sharedApp.conversationManager  removeDelegate: self];
    [App.sharedApp.conversationManager  addDelegate: self delegateQueue: dispatch_get_main_queue()];
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
      
    if (xmppServer) {
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

#pragma mark - ConversationManager methods.

- (void) updatedUnreadCount:(int)count
{
    [self setChatViewBackButtonCount: count];
}


#pragma mark - ConversationManagerDelegate methods.

- (void)conversationmanager:(ConversationManager *)sender
             didChangeState:(XMPPJID *)theirJid
                   newState:(ConversationState) state
{
    NSString *name = [theirJid addressBookName];
    name = name && ![name isEqualToString: @""] ? name : [theirJid user];
    
    NSString *msg = NULL;
    
    switch (state)
    {
        case kConversationState_Commit:
        case kConversationState_DH1:
            msg = NSLS_COMMON_KEYS_ESTABLISHING;
            break;
            
        case kConversationState_DH2:
        case kConversationState_Confirm:
            msg = NSLS_COMMON_KEYS_ESTABLISHED;
            break;
            
        case kConversationState_Ready:
            msg = NSLS_COMMON_KEYS_READY;
            break;

        case kConversationState_Error:
            msg = NSLS_COMMON_KEYS_READY;
            break;

        case kConversationState_Init:
        default:  ;
    }
    
    if(msg)
        [self displayMessageBannerFrom:name message:msg withIcon:App.sharedApp.bannerImage];
    
}


- (void)conversationmanager:(ConversationManager *)sender didReceiveSirenFrom:(XMPPJID *)from siren:(Siren *)siren
{
    
    NSString *name = [from addressBookName];
    name = name && ![name isEqualToString: @""] ? name : [from user];
    
    if(siren.requestBurn)
    {
        [self displayMessageBannerFrom:name message:NSLS_COMMON_MESSAGE_REDACTED withIcon:[UIImage imageNamed:@"flame_on.png"]];
     
    }
    else if(siren.message)
    {
        [self displayMessageBannerFrom:name message:siren.message withIcon:App.sharedApp.bannerImage];
   
    }
 }


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


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    Conversation *conversation = [self conversationAtIndexPath: indexPath];
      NSString* bareJID = [[XMPPJID jidWithString: conversation.remoteJID]bare];
      BOOL useFullJID  = YES;
    
    return useFullJID?80:70;
}


- (UITableViewCell *) configureCell: (ConversationViewTableCell *) cell atIndexPath: (NSIndexPath *) indexPath {
 
    //    DDGTrace();
  
    BOOL  wasReply = NO;
    BOOL  useMissive = NO;
    
    Conversation *conversation = [self conversationAtIndexPath: indexPath];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:kDate  ascending:NO];
    
    Missive* lastMissive = nil;
    SCimpLogEntry *lastLogEntry = nil;
    
    XMPPJID* remoteJID = [XMPPJID jidWithString: conversation.remoteJID];
    
	cell.accessoryType = UITableViewCellAccessoryNone;
    cell.subTitleString = @"";
    cell.leftBadgeImage = NULL;
    cell.subTitleColor = UIColor.whiteColor;
    cell.isStatus  = NO;
    
    if (conversation.missives.count)
    {
        NSArray *missives = [conversation.missives.allObjects
                             sortedArrayUsingDescriptors: [NSArray arrayWithObject:sortDescriptor]];
        
        lastMissive = [missives objectAtIndex:0];
     }
    
    if (conversation.scimpLogEntries.count)
    {
        NSArray *logEntries = [conversation.scimpLogEntries.allObjects
                               sortedArrayUsingDescriptors: [NSArray arrayWithObject:sortDescriptor]];
        
        lastLogEntry = [logEntries objectAtIndex:0];
    }
    
    if(lastMissive && lastLogEntry)
        useMissive = [lastMissive.date isBefore: lastLogEntry.date];
    else
        useMissive = lastMissive? YES:NO;
    
     if(useMissive)
    {
        Siren * siren = lastMissive.siren;
     
        if(!siren.isValid)
        {
            cell.subTitleString = @"<Decryption Error>";
            cell.subTitleColor = UIColor.redColor;
            cell.isStatus = YES;
        }
        else if(siren.message)
        {
            cell.subTitleString =  siren.message;
        }
        else if(siren.mediaType)
        {
            cell.subTitleColor = UIColor.lightGrayColor;
            cell.isStatus = YES;

            cell.subTitleString = [NSString stringWithFormat:@"%@", [siren.mediaType UTIname]];
        }
        
        wasReply = [conversation.remoteJID isEqualToString: lastMissive.toJID];
    }
    else if(lastLogEntry)
    {
        NSDictionary *info = lastLogEntry.info;
        NSString *logType =  [info valueForKey:kSCimpLogEntryType];
        cell.isStatus = YES;
        cell.subTitleColor = UIColor.grayColor;

        if([logType isEqualToString:kSCimpLogEntryTransition])
        {
            
            ConversationState state = kSCimpState_Init;
            NSString *msg = nil;
            NSNumber *number = nil;
            
            if ((number = [info valueForKey:kSCIMPInfoTransition])) {
                state = number.unsignedIntValue;
            }
            
            switch (state)
            {
                case kConversationState_Commit:
                case kConversationState_DH1:
                    msg = NSLS_COMMON_KEYS_ESTABLISHING;
                    break;
                    
                case kConversationState_DH2:
                case kConversationState_Confirm:
                     msg = NSLS_COMMON_KEYS_ESTABLISHED;
                    break;
                    
                case kConversationState_Ready:
                     msg = NSLS_COMMON_KEYS_READY;
                    break;
                     
                default:  ;
                    cell.subTitleColor = UIColor.redColor;
                    msg = NSLS_COMMON_KEYS_ERROR;
                    break;
            }
            
            cell.subTitleString = [NSString stringWithFormat: @"%@",  msg];
        }
        else if([logType isEqualToString:kSCimpLogEntrySecure])
        {
            cell.subTitleString = NSLS_COMMON_KEYS_READY;
         }
        else if([logType isEqualToString:kSCimpLogEntryWarning])
        {
            cell.subTitleString =
            [NSString stringWithFormat: @"Error: %d - %@", lastLogEntry.error,lastLogEntry.errorString];
        }
        else if([logType isEqualToString:kSCimpLogEntryError])
        {
            cell.subTitleString =
            [NSString stringWithFormat: @"Warning: %d - %@", lastLogEntry.error,lastLogEntry.errorString];
         }
    }
      
    UIImage* userAvatar =  [XMPPJID userAvatarWithJIDString: conversation.remoteJID];
    if(!userAvatar) userAvatar = self.avatarImage;
    
    cell.avatar  = userAvatar;
    cell.titleString = [XMPPJID userNameWithJIDString: conversation.remoteJID];
    
    BOOL useFullJID  = YES;
    
    cell.addressString  = useFullJID? remoteJID.resource:NULL;
    
    cell.date = conversation.date;

    if(conversation.attentionFlag)
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
                
            default:                           cell.leftBadgeImage = self.attentionImage; break;
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
        
        cell.badgeColor = conversation.unseenBurnFlag ? [UIColor redColor]:[UIColor darkGrayColor];
        
        
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
        
        [App.sharedApp.conversationManager deleteCachedScloudObjects: conversation];
        
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
    [cvc calculateBurnTimes];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back",nil)
	 
                                     style:UIBarButtonItemStyleBordered
	 
                                    target:nil
	 
                                    action:nil];

    [self.navigationController pushViewController: cvc animated: YES];
    [self setChatViewBackButtonCount:0];
    
    [App.sharedApp.conversationManager  removeDelegate: self];
    
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
