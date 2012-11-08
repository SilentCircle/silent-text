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

#import "XMPPJID.h"
#import "NotiView.h"
#import "NSTimer+Blocks.h"

#import "ChatViewController.h"
#import "SilentTextStrings.h"

#import "ChatViewRow.h"
#import "WEPopoverController.h"
#import "GearContentViewController.h"
#import "ChatOptionsViewController.h"
#import "ChatOptionsView.h"

#import "Missive.h"
#import "MissiveRow.h"

#import "SCimpLogEntry.h"
#import "RekeyRow.h"

#import "SCPasscodeManager.h"
#import "ConversationManager.h"
#import "Conversation.h"
#import "AppConstants.h"
#import "App.h"
#import "Siren.h"
#import "StorageCipher.h"
#import "SCAccount.h"

#import "GeoTracking.h"
#import "CLLocation+NSDictionary.h"

#import "XMPPMessage+SilentCircle.h"
#import "XMPPJID+AddressBook.h"
#import "AddressBookController.h"
#import "PasscodeViewController.h"

#import "NSManagedObjectContext+DDGManagedObjectContext.h"

#include "SCpubTypes.h"

#define CLASS_DEBUG 0
#import "DDGMacros.h"

@interface ChatViewController ()

@property (strong, nonatomic) XMPPJID *remoteJID;

@property (strong, nonatomic) HPGrowingTextView *textView;
@property (strong, nonatomic) NSMutableArray *rows;
@property (strong, nonatomic) UIImage *         bubble;
@property (strong, nonatomic) UIImage *    otherBubble;

//@property (strong, nonatomic) UIImage * clockImage;

@property (strong, nonatomic) UIImage * selectedBubble;
@property (strong, nonatomic) UIImage *plainTextBubble;
@property (strong, nonatomic) NSArray * ascendingDates;
@property (strong, nonatomic) NSArray *descendingDates;

@property (strong, nonatomic) UIActionSheet     *actionSheet;
@property (strong, nonatomic) WEPopoverController *popover;
@property (nonatomic, retain) UIImage *bannerImage;

- (ChatViewController *) registerForXMPPStreamDelegate;
- (ChatViewController *) registerForNotifications;

#define     kSendAction  (@selector(sendAction:))
- (IBAction) sendAction: (UIButton *) sender;

@end

@implementation ChatViewController


static NSString *const kBannerIcon = @"Icon-72";

@synthesize backgroundView = _backgroundView;
@synthesize tableView = _tableView;
@synthesize headerView = _headerView;
@synthesize textEntryView = _textEntryView;

//@synthesize navigationItem;

@synthesize sendButton = _sendButton;
@synthesize userEntryView = _userEntryView;
@synthesize usernameField = _usernameField;
@synthesize xmppStream = _xmppStream;
@synthesize conversation = _conversation;

@synthesize contactButton = _contactButton;
@synthesize callButton = _callButton;
 
@synthesize remoteJID = _remoteJID;
@synthesize textView = _textView;
@synthesize rows = _rows;
@synthesize bubble = _bubble;
@synthesize otherBubble = _otherBubble;
@synthesize selectedBubble = _selectedBubble;
@synthesize plainTextBubble = _plainTextBubble;
@synthesize ascendingDates = _ascendingDates;
@synthesize descendingDates = _descendingDates;

@synthesize popover = _popover;
@synthesize actionSheet = _actionSheet;
@synthesize cov;

- (void) dealloc {
    
    DDGTrace();

    [self.xmppStream removeDelegate: self];
    
	[NSNotificationCenter.defaultCenter removeObserver: self];
    
    [_conversation removeObserver: self forKeyPath: kMissives];
    [_conversation removeObserver: self forKeyPath: kSCimpLogEntries];
    
} // -dealloc


- (void) setConversation: (Conversation *) conversation {
    
    DDGTrace();

    if (_conversation) {
        
        [_conversation removeObserver: self forKeyPath: kMissives];
        [_conversation removeObserver: self forKeyPath: kSCimpLogEntries];
    }
    if (conversation) {
        
        [conversation addObserver: self 
                       forKeyPath: kMissives 
                          options: NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                          context: NULL];
        [conversation addObserver: self 
                       forKeyPath: kSCimpLogEntries 
                          options: NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                          context: NULL];
    }
    _conversation = conversation;
    self.rows = nil;
 //   self.sendButton.enabled = !!conversation;
    self.sendButton.enabled = [self.xmppStream isConnected];

} // -setConversation:


- (XMPPJID *) remoteJID {
    
    if (_remoteJID) { return _remoteJID; }
    
    XMPPJID *jid = [XMPPJID jidWithString: self.conversation.remoteJID];
    
    self.remoteJID = jid;
    
    return jid;
    
} // -remoteJID


// this will tell  the XMPPModule for  SCIMP to delete the current keys.
- (void) resetKeys
{
    App *app = App.sharedApp;
 
    [app.conversationManager resetScimpState:app.currentJID remoteJid: self.remoteJID];
 
    [XMPPSilentCircle  removeSecureContextForJid:self.remoteJID ];
}


const CGFloat kBubbleInsetVertical   = 15.0f;
const CGFloat kBubbleInsetHorizontal = 24.0f;

- (UIImage *) bubble {
    
    if (_bubble) { return _bubble; }
    
    UIEdgeInsets insets = UIEdgeInsetsMake(kBubbleInsetVertical, kBubbleInsetHorizontal, 
                                           kBubbleInsetVertical, kBubbleInsetHorizontal);
    
    UIImage *bubble = [[UIImage imageNamed: @"BubbleOrange.png"] resizableImageWithCapInsets: insets];
    
    self.bubble = bubble;
    
    return bubble;
    
} // -bubble


- (UIImage *) otherBubble {
    
    if (_otherBubble) { return _otherBubble; }
    
    UIEdgeInsets insets = UIEdgeInsetsMake(kBubbleInsetVertical, kBubbleInsetHorizontal, 
                                           kBubbleInsetVertical, kBubbleInsetHorizontal);
    
    UIImage *bubble = [[UIImage imageNamed: @"BubbleYellow.png"] resizableImageWithCapInsets: insets];
    
    self.otherBubble = bubble;
    
    return bubble;
    
} // -otherBubble



//- (UIImage *) clockImage {
//    
//    if (_clockImage) { return _clockImage; }
//    
//    UIEdgeInsets insets = UIEdgeInsetsMake(kBubbleInsetVertical, kBubbleInsetHorizontal,
//                                           kBubbleInsetVertical, kBubbleInsetHorizontal);
//    
//    UIImage *clockImage = [[UIImage imageNamed: @"clock_color.png"] resizableImageWithCapInsets: insets];
//    
//    self.clockImage = clockImage;
//    
//    return clockImage;
//    
//} // -clockImage

 
- (UIImage *) selectedBubble {
    
    if (_selectedBubble) { return _selectedBubble; }
    
    UIEdgeInsets insets = UIEdgeInsetsMake(kBubbleInsetVertical, kBubbleInsetHorizontal, 
                                           kBubbleInsetVertical, kBubbleInsetHorizontal);
    
    UIImage *bubble = [[UIImage imageNamed: @"Bubble-2.png"] resizableImageWithCapInsets: insets];
    
    self.selectedBubble = bubble;
    
    return bubble;
    
} // -selectedBubble



- (UIImage *) plainTextBubble {
    
    if (_plainTextBubble) { return _plainTextBubble; }
    
    UIEdgeInsets insets = UIEdgeInsetsMake(kBubbleInsetVertical, kBubbleInsetHorizontal, 
                                           kBubbleInsetVertical, kBubbleInsetHorizontal);
    
    UIImage *bubble = [[UIImage imageNamed: @"BubblePlaintext.png"] resizableImageWithCapInsets: insets];
    
    self.selectedBubble = bubble;
    
    return bubble;
    
} // -selectedBubble


- (NSArray *) ascendingDates {
    
    if (_ascendingDates) { return _ascendingDates; }
    
    NSSortDescriptor *sd  = [NSSortDescriptor sortDescriptorWithKey: kDate ascending: YES];
    NSArray          *sda = [NSArray arrayWithObject: sd];
    
    self.ascendingDates = sda;
    
    return sda;
    
} // -ascendingDates


- (NSArray *) descendingDates {
    
    if (_descendingDates) { return _descendingDates; }
    
    NSSortDescriptor *sd  = [NSSortDescriptor sortDescriptorWithKey: kDate ascending: NO];
    NSArray          *sda = [NSArray arrayWithObject: sd];
    
    self.descendingDates = sda;
    
    return sda;
    
} // -descendingDates


#pragma mark - UIView lifecycle management methods.


- (MissiveRow *) makeMissiveRowForMissive: (Missive *) missive {
    
    MissiveRow *missiveRow = MissiveRow.new;
    
    missiveRow.missive = missive;
    missiveRow.bubble = self.bubble;
    missiveRow.otherBubble = self.otherBubble;
	//    missiveRow.clockImage = self.clockImage;
    missiveRow.selectedBubble = self.selectedBubble;
    missiveRow.plainTextBubble = self.plainTextBubble;
    
    return missiveRow;
    
} // -makeMissiveRowForMissive:


- (RekeyRow *) makeRekeyRowForLogEntry: (SCimpLogEntry *) logEntry {
    
    RekeyRow *rekeyRow = RekeyRow.new;
    
    rekeyRow.logEntry = logEntry;
    
    return rekeyRow;
    
} // -makeMissiveRowForMissive:


- (NSArray *) redundantRekeyRowsInRows: (NSMutableArray *) rows {
    
    RekeyRow *laterRekeyRow = nil;
    NSMutableArray *redundantRows = NSMutableArray.new;
    
    for (id<ChatViewRow> row in rows.reverseObjectEnumerator) {
        
        if (laterRekeyRow) {
            
            if ([row isKindOfClass: RekeyRow.class]) {
                
                [redundantRows addObject: row];
            }
            else {
                
                laterRekeyRow = nil;
            }
        }
        else {
            
            if ([row isKindOfClass: RekeyRow.class]) {
                
                laterRekeyRow = row;
            }
        }
    }
    return redundantRows;
    
} // -redundantRekeyRowsInRows:


- (NSMutableArray *) makeRows {
    
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity: 
                            self.conversation.missives.count + self.conversation.scimpLogEntries.count];
    
    for (Missive *missive in self.conversation.missives) {
        
        [rows addObject: [self makeMissiveRowForMissive: missive]]; 
    }
    for (SCimpLogEntry *logEntry in self.conversation.scimpLogEntries) {
        
//       if (logEntry.error == kSCLError_NoErr)
        {
            
            [rows addObject: [self makeRekeyRowForLogEntry: logEntry]];
        }
    }
    [rows sortUsingDescriptors: self.ascendingDates];
    
    NSManagedObjectContext *moc = self.conversation.managedObjectContext;
    
  for (RekeyRow *rekeyRow in [self redundantRekeyRowsInRows: rows]) {
        
        [moc deleteObject: rekeyRow.logEntry];
        [rows removeObject: rekeyRow];
    }
    
    self.conversation.notRead = 0;
    self.conversation.flags &= ~(1 << kConversationFLag_Attention);
    
#warning VINNIE fix this
/* 
 core data will crash with
 2012-09-27 17:33:32.823 SilentText[7371:c07] *** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[Conversation flags]: unrecognized selector sent to instance 0x85c4380'

 on the first one.
 
 */
 //   self.conversation.flags &= ~kConversationFLag_Attention;
    
     [moc save];
    
    return rows;
    
} // -makeRows


- (UIImageView *) makeBackgroundImageView {
    
    // Create the background view.
    UIImage *rawBackground = [UIImage imageNamed:@"MessageEntryBackground.png"];
    UIImage *background = [rawBackground stretchableImageWithLeftCapWidth:13 topCapHeight:22];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:background];
    imageView.frame = CGRectMake(0, 0, self.textEntryView.frame.size.width, self.textEntryView.frame.size.height);
    imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    return imageView;
    
} // -makeBackgroundImageView


- (HPGrowingTextView *) makeTextView {
    
    // Create the growing text view.
    HPGrowingTextView *textView = nil;
    
	textView = [HPGrowingTextView.alloc initWithFrame:CGRectMake(36, 3, 210, 40)];
    
    textView.contentInset = UIEdgeInsetsMake(0, 5, 0, 5);
	textView.minNumberOfLines = 1;
	textView.maxNumberOfLines = 6;
	textView.returnKeyType = UIReturnKeyDefault;
	textView.font = [UIFont systemFontOfSize:15.0f];
	textView.delegate = self;
    textView.scrollIndicatorInsets = UIEdgeInsetsMake(5, 0, 5, 0);
    textView.backgroundColor = UIColor.whiteColor;
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    // textView.text = @"test\n\ntest";
	// textView.animateHeightChange = NO; //turns off animation
    
    return textView;
    
} // -makeTextView


- (UIImageView *) makeEntryImageView {
    
    // Add the frame around the textView.
    UIImage *rawEntryBackground = [UIImage imageNamed:@"MessageEntryInputField.png"];
    UIImage *entryBackground = [rawEntryBackground stretchableImageWithLeftCapWidth:13 topCapHeight:22];
    UIImageView *entryImageView = [[UIImageView alloc] initWithImage:entryBackground];
    entryImageView.frame = CGRectMake(35, 0, 218, 40);
    entryImageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    return entryImageView;
    
} // -makeEntryImageView


- (UIButton *) makeSendButton {
    
    // Make the send button.
    UIImage *sendBtnBackground = [[UIImage imageNamed:@"MessageEntrySendButton.png"] stretchableImageWithLeftCapWidth:13 topCapHeight:0];
    UIImage *selectedSendBtnBackground = [[UIImage imageNamed:@"MessageEntrySendButton.png"] stretchableImageWithLeftCapWidth:13 topCapHeight:0];
    
	UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
	sendButton.frame = CGRectMake(self.textEntryView.frame.size.width - 69, 8, 63, 27);
    sendButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
	[sendButton setTitle: NSLS_COMMON_SEND forState:UIControlStateNormal];
    
    [sendButton setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.4] forState:UIControlStateNormal];
    sendButton.titleLabel.shadowOffset = CGSizeMake (0.0, -1.0);
    sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:18.0f];
    
    [sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[sendButton addTarget: self action: kSendAction forControlEvents:UIControlEventTouchUpInside];
    [sendButton setBackgroundImage:sendBtnBackground forState:UIControlStateNormal];
    [sendButton setBackgroundImage:selectedSendBtnBackground forState:UIControlStateSelected];
    
    return sendButton;
    
} // -makeSendButton
- (UIButton *) makeOptionsButton {
    
    // Make the options button.
    UIImage *optionsBtnBackground = [[UIImage imageNamed:@"chatoptions"] stretchableImageWithLeftCapWidth:13 topCapHeight:0];
    UIImage *selectedOptionsBtnBackground = [[UIImage imageNamed:@"chatoptions"] stretchableImageWithLeftCapWidth:13 topCapHeight:0];
    
	UIButton *optionsButton = [UIButton buttonWithType:UIButtonTypeCustom];
	optionsButton.frame = CGRectMake(5, 9, 25, 25);
    optionsButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
//	[optionsButton setTitle: @"▲" forState:UIControlStateNormal];
    
	[optionsButton addTarget: self action: @selector(chatOptionsPress:) forControlEvents:UIControlEventTouchUpInside];
    [optionsButton setBackgroundImage:optionsBtnBackground forState:UIControlStateNormal];
	//    [optionsButton setBackgroundImage:selectedOptionsBtnBackground forState:UIControlStateSelected];
    
    return optionsButton;
    
} // -makeOptionsButton

 
- (void) updatePhoneButton
{
    NSString*  spNumber = [self.remoteJID silentPhoneNumber];
    BOOL hasPhone = (spNumber == nil || [spNumber isEqualToString:@""])?NO:YES;
    [self.callButton setEnabled: hasPhone];
}

- (UIView *) configureHeaderView {

    if (self.headerView == nil) {
        [[NSBundle mainBundle] loadNibNamed:@"ChatViewRowHeader"
                                      owner:self
                                    options:nil];
        
        self.tableView.tableHeaderView = self.headerView;
        
     }
   
    CGSize screenSize = [[UIScreen mainScreen] applicationFrame].size;
    
    [self.contactButton setTitle:
     [self.remoteJID isInAddressBook]?NSLS_COMMON_CONTACT:NSLS_COMMON_ADD_CONTACT
                        forState:UIControlStateNormal];
// 	self.contactButton.frame = CGRectMake((screenSize.width / 2) + 10, 10, (screenSize.width / 2) - 20, 35);
//	self.contactButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
 
    [self.callButton setTitle: NSLS_COMMON_SILENT_PHONE forState:UIControlStateNormal];
    [self.callButton setTitle: NSLS_COMMON_SILENT_PHONE forState:UIControlStateDisabled];
     
//  	self.callButton.frame = CGRectMake(10, 10, (screenSize.width / 2) - 10, 35);
//    self.callButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    
    [self updatePhoneButton];
    
     return self.headerView;
}

- (UIView *) configureTextEntryView {
    
    UIView *textEntryView = self.textEntryView;
    
    [textEntryView addSubview: [self makeBackgroundImageView]];

    self.textView   = [self makeTextView];
    self.sendButton = [self makeSendButton];
    self.optionsButton = [self makeOptionsButton];
	
    
 //   self.sendButton.enabled = !!self.conversation; // Only send messages when the conversation is valid.
    self.sendButton.enabled = [self.xmppStream isConnected];

	[textEntryView addSubview: self.optionsButton];
    [textEntryView addSubview: self.textView];
    [textEntryView addSubview: [self makeEntryImageView]];
    [textEntryView addSubview: self.sendButton];

    return textEntryView;
    
} // -configureTextEntryView:

#if no_gear_button
- (UINavigationItem *) configureNavigationItem {
    
    // Initialize the UIButton
    UIImage *buttonImage = [UIImage imageNamed:@"clock_color"];
    UIButton *aButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [aButton setImage:buttonImage forState:UIControlStateNormal];
    aButton.frame = CGRectMake(0.0, 0.0, 24 , 24 );

    // Initialize the UIBarButtonItem

    UIBarButtonItem *gearButton = [UIBarButtonItem.alloc initWithCustomView:aButton];
 
    // Set the Target and Action for aButton
    [aButton addTarget:self action:@selector(gearAction:) forControlEvents:UIControlEventTouchUpInside];

      
    self.navigationItem.rightBarButtonItem = gearButton;
    
    return self.navigationItem;
    
} // -configureNavigationItem
#endif

- (ChatViewController *) scrollToBottom: (BOOL) animated {
    
    if (self.rows.count) {
        
        NSIndexPath *indexPath = nil;
        
        indexPath = [NSIndexPath indexPathForRow: self.rows.count - 1 inSection: 0];
        
        [self.tableView scrollToRowAtIndexPath: indexPath 
                              atScrollPosition: UITableViewScrollPositionBottom 
                                      animated: animated];
    }
    return self;

} // -scrollToBottom:


- (NSSet *) viewMissives {
    
    NSManagedObjectContext *moc      = self.conversation.managedObjectContext;
 
#warning VINNIE speed this up
/*
     NSPredicate *p = [NSPredicate predicateWithFormat: @"(id = %@)", self.conversation.missives];
     NSArray *missives = [moc fetchObjectsForEntity: kMissiveEntity predicate: p];
*/
    NSSet                  *missives = self.conversation.missives; // ???: Test performance. May need a fetch here.
   NSDate                 *now      = NSDate.date;
    
    for (Missive *missive in missives) {
        
        [missive viewedOnDate: now];
        
        NSDate *shredDate = missive.shredDate;
        
        if ([[shredDate earlierDate: now] isEqualToDate: shredDate]) {
            
            [moc deleteObject: missive];
        }
    }
   self.conversation.viewedDate = now;
    
    // the save is done later by view missives
 //   [moc save];

    return self.conversation.missives;
    
} // -viewMissives


- (NSSet *) removeOldLogEntries {
    
    NSArray *missives = [self.conversation.missives.allObjects sortedArrayUsingDescriptors: self.ascendingDates];
    
    if (missives.count) {
        
        NSDate *earliestDate = [[[missives objectAtIndex: 0] date] dateByAddingTimeInterval: -60.0];
        
        NSPredicate *p = [NSPredicate predicateWithFormat: @"%K <= %@", kDate, earliestDate];
        
        NSSet *logEntries = [self.conversation.scimpLogEntries filteredSetUsingPredicate: p];
        
        NSManagedObjectContext *moc = self.conversation.managedObjectContext;
        
        for (SCimpLogEntry *logEntry in logEntries) {
            
            [moc deleteObject: logEntry];
        }
        [moc save];
    }
    return self.conversation.scimpLogEntries;
    
} // -removeOldLogEntries

- (void) updateTrackingStatus
{
    App *app = App.sharedApp;
    
    if( self.conversation.isTracking
        &&  app.geoTracking.allowTracking
        && app.geoTracking.isTracking )
    {
        [app.geoTracking startUpdating];
    }
    else
    {
        [app.geoTracking stopUpdating];
    }
    
}

- (void) viewDidLoad {
    
//    DDGTrace();
    
    [super viewDidLoad];
 
    [self viewMissives];
    [self removeOldLogEntries];
    
    self.rows = [self makeRows];
  
    self.bannerImage =   [UIImage imageNamed: kBannerIcon];
 
    [self configureHeaderView];
    [self configureTextEntryView];
	// options are handled differently now
    //[self configureNavigationItem];
    
    [self registerForXMPPStreamDelegate];
    [self registerForNotifications];

} // -viewDidLoad


- (void) viewDidUnload {
    
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;

 } // -viewDidUnload


- (void) viewWillAppear: (BOOL) animated {
    
    DDGTrace();

    App *app = App.sharedApp;
 
    if([app.addressBook needsReload])
        [app.addressBook reload];
       
    [super viewWillAppear: animated];
 
    [self updateTrackingStatus];

    [self.tableView reloadData];
    
    [self scrollToBottom: NO];
  
    self.navigationItem.title = [XMPPJID userNameWithJIDString: self.conversation.remoteJID];
      
    [self configureHeaderView];
 
    
} // -viewWillAppear:


- (void) viewDidAppear: (BOOL) animated {
    
    DDGTrace();
   
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
    }
    

    
    [super viewDidAppear: animated];
    
    if (!self.conversation) {
        
        [self.usernameField becomeFirstResponder];
    }
    
} // -viewDidAppear:


- (void) viewWillDisappear: (BOOL) animated {
    
    DDGTrace();
    
	[super viewWillDisappear: animated];
  
    App *app = App.sharedApp;
    [app.geoTracking stopUpdating];
    

} // -viewWillDisappear:


- (void) viewDidDisappear: (BOOL) animated {
    
    DDGTrace();
    
	[super viewDidDisappear: animated];
    
} // -viewDidDisappear:


- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) toInterfaceOrientation {
    
     return YES;

 //   return (toInterfaceOrientation == UIInterfaceOrientationPortrait);
    
} // -shouldAutorotateToInterfaceOrientation:

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	// do something before rotation
	[self.textView resignFirstResponder];
	if (self.cov)
		[self.cov hide];

}
#pragma mark - Standard Notification Methods
- (void)applicationDidEnterBackground
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	self.view.hidden = YES;
}
- (void)applicationWillEnterForeground
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	self.view.hidden = NO;

}

- (void)applicationWillResignActive
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	[self.textView resignFirstResponder];
	self.view.hidden = YES;
}

#pragma mark - Missives and SCimpLogEntries observer methods.

#warning VINNIE REVIEW THIS
- (NSUInteger) rowIndexForMissive: (Missive *) missive {
    
    NSUInteger index = NSNotFound;
  
    for (id element in self.rows)
    {
      if([element  isKindOfClass: MissiveRow.class])
      {
          MissiveRow* thisMissive = element;
          
          if( thisMissive.missive == missive)
          {
              index  = [self.rows indexOfObject: thisMissive ];
              break;
           }
        }
     }
    return index;
    
    
    NSPredicate *p = [NSPredicate predicateWithFormat: @"%K == %@", kMissive, missive];
    
    NSArray *rows = [self.rows filteredArrayUsingPredicate: p];
    
    return rows.count ? [self.rows indexOfObject: rows.lastObject] : NSNotFound;
    
} // -rowIndexForMissive:


- (id<ChatViewRow>) rowEarlierThanDate: (NSDate *) date {
    
    NSPredicate *p = [NSPredicate predicateWithFormat: @"%K < %@", kDate, date];
    
    NSArray *rows = [self.rows filteredArrayUsingPredicate: p];
    
    return rows.lastObject;
    
} // -rowEarlierThanDate:


- (NSArray *) insertMissives: (NSArray *) missives {
    
    DDGDesc(missives);
    
    if (missives.count) {
        
        missives = [missives sortedArrayUsingDescriptors: self.ascendingDates];
        
        NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity: missives.count];
        
        for (Missive *missive in missives) {
            
            id<ChatViewRow> earlierRow = [self rowEarlierThanDate: missive.date];
            
            NSUInteger rowIndex = earlierRow ? [self.rows indexOfObject: earlierRow] + 1 : 0;
            
            [self.rows insertObject: [self makeMissiveRowForMissive: missive] atIndex: rowIndex];
            [indexPaths   addObject: [NSIndexPath indexPathForRow: rowIndex inSection: 0]];

            [missive viewedOnDate: NSDate.date];
        }
        [self.tableView beginUpdates]; {
            
            [self.tableView insertRowsAtIndexPaths: indexPaths 
                                  withRowAnimation: UITableViewRowAnimationFade];
        }
        [self.tableView endUpdates];
        
        [self scrollToBottom: YES];
    }
    return missives;
    
} // -insertMissives:


- (void) removeRedundantRekeyRows {
    
    NSManagedObjectContext *moc = self.conversation.managedObjectContext;
        
    for (RekeyRow *rekeyRow in [self redundantRekeyRowsInRows: self.rows]) {
        
        [moc deleteObject: rekeyRow.logEntry];
    }
    [moc save];
        
} // -removeRedundantRekeyRows
        
            
static const CGFloat kFlameWidth = 20.0f;
static NSString *const kBurningCircle1 = @"BurningCircle_1";
            
- (void) burnMissiveRow: (MissiveRow *) missiveRow withCell: (STBubbleTableViewCell *) cell {
    
    DDGTrace();
    
    // Make the stencilView.
    UIView *stencilView = [UIView.alloc initWithFrame: cell.bubbleView.frame];
    
    stencilView.backgroundColor = UIColor.clearColor;
    stencilView.clipsToBounds = YES;
    
    [cell.bubbleView.superview addSubview: stencilView];
    
    // Make the burnView.
    UIImageView *burnView = [UIImageView.alloc initWithImage: [UIImage imageNamed: kBurningCircle1]];
    
    CGRect bounds = stencilView.bounds;
    
    bounds.size.width  += 2 * kFlameWidth;
    bounds.size.height += 2 * kFlameWidth;
    
    burnView.bounds = bounds;
    
    [stencilView addSubview: burnView];
    
    burnView.center = CGPointMake(stencilView.bounds.size.width  / 2.0f, 
                                  stencilView.bounds.size.height / 2.0f);
    burnView.alpha = 0.0f;
    burnView.transform = CGAffineTransformMakeScale(0.1f, 0.1f);

    // Animate the burnView and then delete the row.
    [UIView animateWithDuration: kDefaultDuration * 4
                     animations: ^{ burnView.alpha = 1.0f; burnView.transform = CGAffineTransformIdentity; }
                     completion: ^(BOOL finished) {
                         
                         NSUInteger rowIndex = [self.rows indexOfObject: missiveRow];
                         NSIndexPath *indexPath = [NSIndexPath indexPathForRow: rowIndex inSection: 0];
                
                         [self.rows removeObjectAtIndex: rowIndex];
                         
                         [self.tableView beginUpdates]; {
                             
                             [self.tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject: indexPath] 
                                                   withRowAnimation: UITableViewRowAnimationFade];
            }
                         [self.tableView endUpdates];
                         
                         [self removeRedundantRekeyRows];

                         [UIView animateWithDuration: kDefaultDuration 
                                          animations: ^{ burnView.alpha = 0.0f; } 
                                          completion: ^(BOOL finished) { [stencilView removeFromSuperview]; }];
                     }];

} // -burnMissiveRow:withCell:


- (void) burnMissiveRow: (MissiveRow *) missiveRow {
    
    DDGTrace();
    
    NSUInteger rowIndex = [self.rows indexOfObject: missiveRow];
    
    if (rowIndex != NSNotFound) {
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow: rowIndex inSection: 0];
        
        STBubbleTableViewCell *cell = nil;
        
        cell = (STBubbleTableViewCell *)[self.tableView cellForRowAtIndexPath: indexPath];

        if (cell) {
            
            [self burnMissiveRow: missiveRow withCell: cell];
        }
        else {
            
            [self.rows removeObjectAtIndex: rowIndex];
            
        [self.tableView beginUpdates]; {
            
                [self.tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject: indexPath] 
                                  withRowAnimation: UITableViewRowAnimationFade];
        }
        [self.tableView endUpdates];
            
            [self removeRedundantRekeyRows];
        }
    }
                
} // -burnMissiveRow:


- (NSArray *) removeMissives: (NSArray *) missives {
    
    DDGDesc(missives);
        
    if (missives.count) {
        
        missives = [missives sortedArrayUsingDescriptors: self.descendingDates];
        
        for (Missive *missive in missives) {
            
            NSUInteger rowIndex = [self rowIndexForMissive: missive];
            
            if (rowIndex != NSNotFound) {
                
                [App performBlock: ^{ [self burnMissiveRow: [self.rows objectAtIndex: rowIndex]]; }];
            }
        }
    }
    return missives;
    
} // -removeMissives:


- (NSArray *) insertLogEntries: (NSArray *) logEntries {
    
    DDGDesc(logEntries);
    
    if (logEntries.count) {
        
        logEntries = [logEntries sortedArrayUsingDescriptors: self.ascendingDates];
        
        NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity: logEntries.count];
        
        for (SCimpLogEntry *logEntry in logEntries) {
            
  //          if (logEntry.error == kSCLError_NoErr)
            {
                
                id<ChatViewRow> earlierRow = [self rowEarlierThanDate: logEntry.date];
                
                NSUInteger rowIndex = earlierRow ? [self.rows indexOfObject: earlierRow] + 1 : 0;
                
                [self.rows insertObject: [self makeRekeyRowForLogEntry: logEntry] atIndex: rowIndex];
                [indexPaths   addObject: [NSIndexPath indexPathForRow: rowIndex inSection: 0]];
            }
        }
        if (indexPaths.count) {
            
            [self.tableView beginUpdates]; {
                
                [self.tableView insertRowsAtIndexPaths: indexPaths 
                                      withRowAnimation: UITableViewRowAnimationFade];
            }
            [self.tableView endUpdates];

            [self scrollToBottom: YES];

            // Remove now redundant RekeyRows.
                for (RekeyRow *rekeyRow in [self redundantRekeyRowsInRows: self.rows]) {
    
                [rekeyRow.logEntry.managedObjectContext deleteObject: rekeyRow.logEntry];
            }
        }
    }
    return logEntries;
    
} // -insertLogEntries:


- (NSUInteger) rowIndexForLogEntry: (SCimpLogEntry *) logEntry {
    
    NSPredicate *p = [NSPredicate predicateWithFormat: @"%K == %@", kLogEntry, logEntry];
    
    NSArray *rows = [self.rows filteredArrayUsingPredicate: p];
    
    return rows.count ? [self.rows indexOfObject: rows.lastObject] : NSNotFound;
    
} // -rowIndexForLogEntry:


- (NSArray *) removeLogEntries: (NSArray *) logEntries {
    
    DDGDesc(logEntries);
    
    if (logEntries.count) {
        
        logEntries = [logEntries sortedArrayUsingDescriptors: self.descendingDates];
        
        NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity: logEntries.count];
        
        for (SCimpLogEntry *logEntry in logEntries) {
            
            NSUInteger rowIndex = [self rowIndexForLogEntry: logEntry];
            
            if (rowIndex != NSNotFound) {
                
                [self.rows removeObjectAtIndex: rowIndex];
                [indexPaths addObject: [NSIndexPath indexPathForRow: rowIndex inSection: 0]];
            }
        }
        if (indexPaths.count) {
            
            [self.tableView beginUpdates]; {
                
                [self.tableView deleteRowsAtIndexPaths: indexPaths 
                                      withRowAnimation: UITableViewRowAnimationFade];
            }
            [self.tableView endUpdates];
        }
    }
    return logEntries;
    
} // -removeLogEntries:


- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object change: (NSDictionary *) change context: (void *) context {
    
    DDGTrace();
    
    if (self.rows) {
        
    NSUInteger changeKind = [[change valueForKey: NSKeyValueChangeKindKey] unsignedIntegerValue];
    
        if ([keyPath isEqualToString: kMissives]) {
            
    if (changeKind == NSKeyValueChangeInsertion) {
        
        [self insertMissives: [change valueForKey: NSKeyValueChangeNewKey]];
    }
    if (changeKind == NSKeyValueChangeRemoval) {
        
        [self removeMissives: [change valueForKey: NSKeyValueChangeOldKey]];
    }
        }
        else if ([keyPath isEqualToString: kSCimpLogEntries]) {
            
            if (changeKind == NSKeyValueChangeInsertion) {
                
                [self insertLogEntries: [change valueForKey: NSKeyValueChangeNewKey]];
            }
            if (changeKind == NSKeyValueChangeRemoval) {
                
                [self removeLogEntries: [change valueForKey: NSKeyValueChangeOldKey]];
            }
        }
        [self.conversation.managedObjectContext save];
    }
    
} // -observeValueForKeyPath:ofObject:change:context:


#pragma mark - Action Sheets


#define kCreateTitle @"Create New Contact"
#define kAddTitle @"Add to Existing Contact"

- (IBAction)clickContactActionSheet:(UIView*)view {
    
    if (self.actionSheet) {
        // do nothing
    } else {

#warning Fix Add to existing Contact
        UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                      initWithTitle:NULL
                                      delegate:self
                                      cancelButtonTitle:NSLS_COMMON_CANCEL
                                      destructiveButtonTitle:NULL
                                      otherButtonTitles:kCreateTitle,  /* kAddTitle,  */ nil ];
        
        [actionSheet showInView:view ];
    }
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *choice = [actionSheet buttonTitleAtIndex:buttonIndex];
    AddressBookController* abc = [[AddressBookController alloc] init];
    
    if ([choice isEqualToString:kCreateTitle])
    {
        // create new contact
        [self.navigationController pushViewController: abc animated: YES];
        [abc createContactWithJID:self.remoteJID];
        
    } else if ([choice isEqualToString:kAddTitle])
    {
        // add to existing contact
        [self.navigationController pushViewController: abc animated: YES];
        [abc addJIDToContact:self.remoteJID];
    }
}


#pragma mark - IBAction methods


- (BOOL) isValidText: (NSString *) text {
    
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    NSArray *substrings = [text componentsSeparatedByCharactersInSet: whitespace];
    
    for (NSString *string in substrings) {
        
        if (string.length) { 
            
            return YES; 
        }
    }
    return NO;
    
} // -isValidText:


- (XMPPMessage *) xmppMessageForText: (NSString *) text {
    
    App *app = App.sharedApp;
    
    if ([self isValidText: text]) {
        
        Siren *siren = Siren.new;
        
        siren.message = text;
        siren.conversationID = self.conversation.scppID;
        siren.fyeo           = self.conversation.isFyeo;
        
        if(self.getBurnNoticeState)
        {
            siren.shredAfter =  self.getBurnNoticeDelay;
        }
         
        if(app.geoTracking.allowTracking
           && app.geoTracking.isTracking
           && self.conversation.isTracking)
        {
// insert tracking info
            CLLocation* location = app.geoTracking.location;
            if(location)
            {
                NSString* locString = [location JSONString];
                siren.location   =  locString;
            }
        }

        XMPPMessage *xmppMessage = [siren chatMessageToJID: self.remoteJID];
        
        DDGDesc(xmppMessage.compactXMLString);
        
        return xmppMessage;
    }
    return nil;
        
} // -xmppMessageForText:


- (Missive *) insertMissiveForXMPPMessage: (XMPPMessage *) xmppMessage {
    
    Missive *missive = [Missive insertMissiveForXMPPMessage: xmppMessage 
                                     inManagedObjectContext: self.conversation.managedObjectContext 
                                              withEncryptor: self.conversation.encryptor];
    self.conversation.date = missive.date;
    missive.conversation   = self.conversation; // Trigger the insert into the table view.

    return missive;
    
} // -insertMissiveForXMPPMessage:


- (IBAction) sendAction: (UIButton *) sender {
    
    XMPPMessage *xmppMessage = [self xmppMessageForText: self.textView.text];
    
    if (xmppMessage) {
        
        Missive *missive = [self insertMissiveForXMPPMessage: xmppMessage];
        
        [missive.managedObjectContext save];
        [self.xmppStream sendElement: xmppMessage];
    }
    self.textView.text = nil;
    
} // -sendAction:


- (IBAction) swipeDown: (UISwipeGestureRecognizer *) gestureRecognizer {
	
    DDGTrace();
	
	if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        
        [self.textView resignFirstResponder];
	}
    
} // -longPress:


- (IBAction) contactAction: (UIButton *) sender {
  
    if( [self.remoteJID isInAddressBook] ){
       
         AddressBookController* abc = [[AddressBookController alloc] init];
        [self.navigationController pushViewController: abc animated: YES];
        
        [abc  showContactForJID:self.remoteJID];
    }
    else
    {
        [self clickContactActionSheet: self.view];
    }


     
} // -contactAction:


- (IBAction) callAction: (UIButton *) sender {
  
    NSMutableString *phone =  [[self.remoteJID silentPhoneNumber] mutableCopy]; ;
    
     if( phone  )
     {
         
         UIApplication *app = [UIApplication sharedApplication];
         
           
         [phone replaceOccurrencesOfString:@" "
                                withString:@""
                                   options:NSLiteralSearch
                                     range:NSMakeRange(0, [phone length])];
         [phone replaceOccurrencesOfString:@"("
                                withString:@""
                                   options:NSLiteralSearch
                                     range:NSMakeRange(0, [phone length])];
         [phone replaceOccurrencesOfString:@")"
                                withString:@""
                                   options:NSLiteralSearch
                                     range:NSMakeRange(0, [phone length])];
         
         NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"silentphone:%@", phone]];
         
         [app openURL:url];
      }
     
    
} // -callAction:


- (WEPopoverContainerViewProperties *) improvedContainerViewProperties {
	
    //
    // Copied with minor edits from the WEPopover sample app.
    //
	WEPopoverContainerViewProperties *props = WEPopoverContainerViewProperties.new;
    
	NSString *bgImageName = nil;
	CGFloat bgMargin = 0.0;
	CGFloat bgCapSize = 0.0;
	CGFloat contentMargin = 4.0;
	
	bgImageName = @"popoverBg.png";
	
	// These constants are determined by the popoverBg.png image file and are image dependent
	bgMargin = 13; // margin width of 13 pixels on all sides popoverBg.png (62 pixels wide - 36 pixel background) / 2 == 26 / 2 == 13 
	bgCapSize = 31; // ImageSize/2  == 62 / 2 == 31 pixels
	
	props.leftBgMargin = bgMargin;
	props.rightBgMargin = bgMargin;
	props.topBgMargin = bgMargin;
	props.bottomBgMargin = bgMargin;
	props.leftBgCapSize = bgCapSize;
	props.topBgCapSize = bgCapSize;
	props.bgImageName = bgImageName;
	props.leftContentMargin = contentMargin;
	props.rightContentMargin = contentMargin - 1; // Need to shift one pixel for border to look correct
	props.topContentMargin = contentMargin; 
	props.bottomContentMargin = contentMargin;
	
	props.arrowMargin = 4.0;
	
	props.upArrowImageName = @"popoverArrowUp.png";
	props.downArrowImageName = @"popoverArrowDown.png";
	props.leftArrowImageName = @"popoverArrowLeft.png";
	props.rightArrowImageName = @"popoverArrowRight.png";

	return props;
    
} // -improvedContainerViewProperties



 - (IBAction) gearAction: (UIButton *) gearButton {
      DDGTrace();
#if oldway
    if (!self.popover) {
        
        GearContentViewController *gcvc = [GearContentViewController.alloc initWithNibName: nil bundle: nil];
        
        gcvc.fyeo = self.conversation.isFyeo;
        gcvc.tracking = self.conversation.isTracking;
        gcvc.shredAfter = self.conversation.shredAfter;
        
        self.popover = [WEPopoverController.alloc initWithContentViewController: gcvc];
        
        self.popover.delegate = self;
        self.popover.containerViewProperties = self.improvedContainerViewProperties;
		self.popover.passthroughViews = [NSArray arrayWithObject: self.navigationController.navigationBar];
        self.popover.popoverContentSize = gcvc.view.bounds.size;
       
         [self.textView resignFirstResponder];
        
         UIView *v = self.backgroundView;
        CGRect rect = [gearButton frame ];
		rect.origin.y -= 40;

        [self.popover presentPopoverFromRect: rect
                                      inView: v
                             permittedArrowDirections: UIPopoverArrowDirectionAny 
                                             animated: YES];

    }
    else {
        
        [self.popover dismissPopoverAnimated: YES];
        [self popoverControllerDidDismissPopover: self.popover]; // Go get the data out of the popover.
        
        self.popover = nil;
    }
#else
	 [self pushChatOptionsViewController];

#endif
} // -gearAction:


- (IBAction)newOptionPress:(id)sender {
	NSLog(@"newoptionpress");
//	
//	if (!self.cov)
//		[[NSBundle mainBundle] loadNibNamed:@"ChatOptionsView" owner:self options:nil];
//	cov.delegate = self;
//	[self.cov unfurlOnView:sender atPoint:CGPointMake(76, self.view.frame.size.height - 44)];
	
}

#pragma mark - UITextFieldDelegate methods.


- (UIView *) removeUserEntryView {
    
    CGRect frame = self.tableView.frame;
    
    frame.origin       = self.userEntryView.frame.origin;
    frame.size.height += self.userEntryView.frame.size.height;
    
    [UIView animateWithDuration: kDefaultDuration 
                     animations: ^{ self.userEntryView.alpha = 0.0; self.tableView.frame = frame; } 
                     completion: ^(BOOL finished) { [self.userEntryView removeFromSuperview]; }];

    return self.userEntryView;

} // -removeUserEntryView


- (BOOL) textFieldShouldReturn: (UITextField *) textField {
    
    DDGTrace();
    
    XMPPJID *remoteJID = [XMPPJID jidWithUser: textField.text domain: kDefaultAccountDomain resource: nil];
     
    App *app = App.sharedApp;
    
    Conversation *conversation = [app.conversationManager conversationForLocalJid: app.currentJID 
                                                                        remoteJid: remoteJID];
    self.conversation = conversation;
    self.rows = [self makeRows];

    [self.tableView reloadData];
    
    self.navigationItem.title = [XMPPJID userNameWithJIDString: conversation.remoteJID];
    
    [self.textView becomeFirstResponder];
    [self removeUserEntryView];
    
    return NO;
    
} // -textFieldShouldReturn:


#pragma mark - HPGrowingTextViewDelegate methods.


- (BOOL) growingTextViewShouldBeginEditing: (HPGrowingTextView *) growingTextView {
    
 //   DDGTrace();
    
    return YES;
    
} // -growingTextViewShouldBeginEditing:


- (BOOL) growingTextViewShouldEndEditing: (HPGrowingTextView *) growingTextView {
    
 //   DDGTrace();
    
    return YES;
    
} // -growingTextViewShouldEndEditing:


- (void) growingTextViewDidBeginEditing: (HPGrowingTextView *) growingTextView {
    
//    DDGTrace();
    
} // -growingTextViewDidBeginEditing:


- (void) growingTextViewDidEndEditing: (HPGrowingTextView *) growingTextView {
    
//    DDGTrace();
    
} // -growingTextViewDidEndEditing:


- (BOOL) growingTextView: (HPGrowingTextView *) growingTextView shouldChangeTextInRange: (NSRange) range replacementText: (NSString *) text {
    
//    DDGTrace();
    
    return YES;
    
} // -growingTextView:shouldChangeTextInRange:replacementText:


- (void) growingTextViewDidChange: (HPGrowingTextView *) growingTextView {
    
//    DDGTrace();
    
} // -growingTextViewDidChange:


- (void) growingTextView: (HPGrowingTextView *) growingTextView willChangeHeight: (float) height {
    
 //   DDGTrace();
    
    CGFloat diff = (growingTextView.frame.size.height - height);
    
    CGRect frame = self.textEntryView.frame;
    
    frame.origin.y    += diff;
    frame.size.height -= diff;
    
    self.textEntryView.frame = frame;
    
    frame = self.tableView.frame;

    frame.size.height += diff;
    
    self.tableView.frame = frame;
    
    [self scrollToBottom: YES];
    
} // -growingTextView:willChangeHeight:


- (void) growingTextView: (HPGrowingTextView *) growingTextView didChangeHeight: (float) height {
    
//    DDGTrace();
    
} // -growingTextView:didChangeHeight:


- (void) growingTextViewDidChangeSelection: (HPGrowingTextView *) growingTextView {
    
 //   DDGTrace();
    
} // -growingTextViewDidChangeSelection:


- (BOOL) growingTextViewShouldReturn: (HPGrowingTextView *) growingTextView {
    
//    DDGTrace();
    
    return YES;
    
} // -growingTextViewShouldReturn:


#pragma mark - UITableViewDataSource methods.


- (NSInteger) tableView: (UITableView *) tableView numberOfRowsInSection: (NSInteger) section {
    
//    DDGTrace();
 
    return  self.rows.count;
    
} // -tableView:numberOfRowsInSection:


- (UITableViewCell *) cellForRow: (id<ChatViewRow>) row {
    
//    DDGTrace();
    
    UITableViewCell *cell = nil;
    
    cell = [self.tableView dequeueReusableCellWithIdentifier: row.reuseIdentifier];
    
    if (!cell) {
        
        cell = row.tableViewCell;
    }
    return cell;
    
} // -cellForRow:


- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath {
    
//    DDGTrace();
    
    id<ChatViewRow> row = [self.rows objectAtIndex: indexPath.row];

    UITableViewCell *cell = [self cellForRow: row];
    
    return [row configureCell: cell];
    
} // -tableView:cellForRowAtIndexPath:


- (BOOL) tableView: (UITableView *) tableView canEditRowAtIndexPath: (NSIndexPath *) indexPath {
    
//    DDGDesc(indexPath);
//    DDGDesc([self.rows objectAtIndex: indexPath.row]);
    
    return NO;
//    return [[self.rows objectAtIndex: indexPath.row] isKindOfClass: MissiveRow.class];
    
} // -tableView:canEditRowAtIndexPath:


- (UITableViewCellEditingStyle) tableView: (UITableView *) tableView editingStyleForRowAtIndexPath: (NSIndexPath *) indexPath {

//    DDGTrace();

    return UITableViewCellEditingStyleNone;
    
} // -tableView:editingStyleForRowAtIndexPath:


- (void) tableView: (UITableView *) tableView 
commitEditingStyle: (UITableViewCellEditingStyle) editingStyle 
 forRowAtIndexPath: (NSIndexPath *) indexPath {
    
 //   DDGTrace();
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        id<ChatViewRow> row = [self.rows objectAtIndex: indexPath.row];
        
        if ([row isKindOfClass: MissiveRow.class]) {
            
            Missive *missive = [(MissiveRow *)row missive];
        
            [missive.managedObjectContext deleteObject: missive];
            [missive.managedObjectContext save];
        }
    }
    
} // -tableView:commitEditingStyle:forRowAtIndexPath:


#pragma mark - UITableViewDelegate methods.


- (CGFloat) tableView: (UITableView *) tableView heightForRowAtIndexPath: (NSIndexPath *) indexPath {
    
    id<ChatViewRow> row = [self.rows objectAtIndex: indexPath.row];
    
//    DDGDesc(row);

    return row.height;
    
} // -tableView:heightForRowAtIndexPath:


- (NSIndexPath *) tableView: (UITableView *) tableView willSelectRowAtIndexPath: (NSIndexPath *) indexPath {
    
    return nil;
    
} // -tableView:willSelectRowAtIndexPath:


//- (void) tableView: (UITableView *) tableView didSelectRowAtIndexPath: (NSIndexPath *) indexPath {
//} // -tableView:didSelectRowAtIndexPath:


#pragma mark - WEPopoverControllerDelegate/UIPopoverControllerDelegate methods.


- (void) popoverControllerDidDismissPopover: (WEPopoverController *) popoverController {

    DDGTrace();
    
    if ([self.popover isEqual: popoverController]) {
        
        GearContentViewController *gcvc = (GearContentViewController *)popoverController.contentViewController;
        
        if ([gcvc isKindOfClass: GearContentViewController.class]) {
            
            self.conversation.fyeo = gcvc.isFyeo;
            self.conversation.tracking = gcvc.isTracking;
            self.conversation.shredAfter = gcvc.shredAfter;
            
            [self updateTrackingStatus];
              
            [self.conversation.managedObjectContext save];
        }
        self.popover = nil;
    }

} // -popoverControllerDidDismissPopover:


- (BOOL) popoverControllerShouldDismissPopover: (WEPopoverController *) popoverController {
    
    DDGTrace();
    
    return YES;
    
} // -popoverControllerShouldDismissPopover:


#pragma mark - Chat Options Delegate methods.

- (void) pushChatOptionsViewController
{
	[self.textView resignFirstResponder];

	ChatOptionsViewController *covc = [ChatOptionsViewController.alloc initWithNibName: @"ChatOptionsViewController" bundle: nil];
    covc.delegate = self;
	[((UINavigationController *) self.parentViewController) pushViewController: covc animated: YES];
	
}


- (BOOL) getBurnNoticeState;
{
    BOOL state = self.conversation.flags & (1 << kConversationFLag_Burn) ? YES : NO;
	return(state);
    
}
- (void) setBurnNoticeState:(BOOL) state;
{
    if(state)
        self.conversation.flags |= 1 << kConversationFLag_Burn;
    else
        self.conversation.flags &= ~(1 << kConversationFLag_Burn) ;
    
	if ((state == YES) && (self.conversation.shredAfter == 0))
		self.conversation.shredAfter = 3600;	// set the delay to 60 minutes if it is zero and the user has selected burn notice
   	[self.conversation.managedObjectContext save];
}

- (UInt32) getBurnNoticeDelay;
{
	return self.conversation.shredAfter;
}

- (void) setBurnNoticeDelay:(UInt32) delay;
{
	self.conversation.shredAfter = delay;
	[self.conversation.managedObjectContext save];
}

- (BOOL) getIncludeLocationState;
{
	return self.conversation.tracking ? YES : NO;
}

- (void) setIncludeLocationState:(BOOL) state;
{
	App *app = App.sharedApp;
	if (state && !(app.geoTracking.allowTracking && app.geoTracking.isTracking)) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Location not available.",@"Location not available.")
															message: NSLocalizedString(@"Location tracking must be turned on before it can be utilized in a message.", @"Location tracking must be turned on before it can be utilized in a message.")
														   delegate:nil
												  cancelButtonTitle:@"Dismiss"
												  otherButtonTitles:nil];
		[alertView show];
		
	}
	else {
		self.conversation.tracking = state;
		[self updateTrackingStatus];
		[self.conversation.managedObjectContext save];
	}
}
- (BOOL) isLocationInclusionPossible {
///* MZ-  here is how you tell if the track switch is OK to enable */
//App *app = App.sharedApp;
//BOOL enableTrackingSwitch =  (app.geoTracking.allowTracking && app.geoTracking.isTracking);

	// if location is not available, then we should tell the user how to make it available.  
}

- (BOOL) getFYEOState;
{
	return self.conversation.fyeo ? YES : NO;
}

- (void) setFYEOState:(BOOL) state;
{
	self.conversation.fyeo = state;
	[self.conversation.managedObjectContext save];
}

- (void) resetKeysNow;
{
	[self resetKeys];
}

- (void) chatOptionsPress:(id)sender {
	
	if ([self.cov superview]) {
		[self.cov fadeOut];
		return;
	}
	
	if (!self.cov)
		[[NSBundle mainBundle] loadNibNamed:@"ChatOptionsView" owner:self options:nil];
	cov.delegate = self;
	[self.cov unfurlOnView:self.view atPoint:CGPointMake(17.5, self.textEntryView.frame.origin.y)];
}


#pragma mark - XMPPStreamDelegate methods.

- (void) xmppStream: (XMPPStream *) sender didReceivePresence: (XMPPPresence *) presence {
    
    //    DDGTrace();
    DDGDesc(presence.fromStr);
    
    XMPPJID *from = presence.from;
    
    if ([sender.myJID.bare isEqualToString: from.bare]) { // if from ourself...
     
        self.sendButton.enabled = YES;
    
    }
    
} // -xmppStream:didReceivePresence:


- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
     self.sendButton.enabled = NO;
}


- (void) xmppStream: (XMPPStream *) sender didReceiveMessage: (XMPPMessage *) xmppMessage {
    
    DDGDesc(xmppMessage.compactXMLString);
    
    XMPPJID *to = xmppMessage.to;
    
    if ([sender.myJID.bare isEqualToString: to.bare]){
    
     if (xmppMessage.isChatMessageWithSiren || xmppMessage.isChatMessageWithBody) { // We may remove the body check later.
        
        Siren *siren = [Siren sirenWithChatMessage: xmppMessage];
        
        if(siren.ping || siren.requestResend)
        {
            return;
        }
        else
        {
            XMPPJID *from = xmppMessage.from;
                 
            if([from isEqualToJID:self.remoteJID options:XMPPJIDCompareBare])
                return;
             
            NSString *name = [from addressBookName];
            name = name && ![name isEqualToString: @""] ? name : [from user];
           
            NSString *msg = siren.message;
            
            [self displayMessageBannerFrom:name message:msg];
        }
    }
    }
    
} // -xmppStream:didReceiveMessage:


//- (BOOL) xmppStream: (XMPPStream *) sender didReceiveIQ:(XMPPIQ *) iq {
//    
////    DDGTrace();
//    
//    return NO;
//    
//} // -xmppStream:didReceiveIQ:
//
 //
//- (void) xmppStream: (XMPPStream *) sender didReceivePresence: (XMPPPresence *) presence {
//    
////    DDGTrace();
//    
//} // -xmppStream:didReceivePresence:
//
//
//- (void) xmppStream: (XMPPStream *) sender didReceiveError: (NSXMLElement *) error {
//    
////    DDGTrace();
//    
//} // -xmppStream:didReceiveError:
//
//
//- (XMPPIQ *) xmppStream: (XMPPStream *) sender willSendIQ: (XMPPIQ *) iq {
//    
////    DDGTrace();
//    
//    return iq;
//    
//} // -xmppStream:willSendIQ:
//
//
//- (XMPPMessage *) xmppStream: (XMPPStream *) sender willSendMessage: (XMPPMessage *) message {
//    
////    DDGTrace();
//    
//    return message;
//    
//} // -xmppStream:willSendMessage:
//
//
//- (XMPPPresence *) xmppStream: (XMPPStream *) sender willSendPresence: (XMPPPresence *) presence {
//    
////    DDGTrace();
//    
//    return presence;
//    
//} // -xmppStream:willSendPresence:
//
//
//- (void) xmppStream: (XMPPStream *) sender didSendIQ: (XMPPIQ *) iq {
//    
////    DDGTrace();
//    
//} // -xmppStream:didSendIQ:
//
//
//- (void) xmppStream: (XMPPStream *) sender didSendMessage: (XMPPMessage *) message {
//    
////    DDGTrace();
//    
//} // -xmppStream:didSendMessage:
//
//
//- (void) xmppStream: (XMPPStream *) sender didSendPresence: (XMPPPresence *) presence {
//    
////    DDGTrace();
//    
//} // -xmppStream:didSendPresence:


#pragma mark - Local Notifcation.

- (UIColor *)randomColor {
    CGFloat r = arc4random()%255;
    CGFloat g = arc4random()%255;
    CGFloat b = arc4random()%255;
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0];
}
- (CGFloat) viewWidth {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGFloat width = self.view.frame.size.width;
    if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft) {
        width = self.view.frame.size.height;
    }
    return width;
}


- (void)displayMessageBannerFrom:(NSString*)from  message:(NSString*) message
{
    CGFloat offset = 20.0;
  
    NotiView *nv = [[NotiView alloc] initWithTitle:from
                                            detail:message
                                            icon:self.bannerImage];
    [nv setWidth:320.0];
    [nv setColor:[self randomColor]];
     
    CGRect f = nv.frame;
    f.origin.x = [self viewWidth] - f.size.width;
    f.origin.y = -f.size.height;
    nv.frame = f;
    
    [App.sharedApp.window addSubview:nv];
    
    [UIView animateWithDuration:0.4 animations:^{
        nv.frame = CGRectOffset(nv.frame, 0.0, f.size.height+offset);
    } completion:^(BOOL finished) {
        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:NO block:^(NSTimer *timer) {
            [UIView animateWithDuration:0.4 animations:^{
                nv.frame = CGRectOffset(nv.frame, f.size.width+offset, 0.0);
            } completion:^(BOOL finished) {
                [nv removeFromSuperview];
            }];
        }];
    }];

}


#pragma mark - Registration methods.


- (ChatViewController *) registerForXMPPStreamDelegate {
    
    DDGTrace();
    
    [self.xmppStream removeDelegate: self];
    [self.xmppStream    addDelegate: self delegateQueue: dispatch_get_main_queue()];
    
    return self;
    
} // -registerForXMPPDelegate


- (ChatViewController *) logKeyboardNotification: (NSNotification *) notification {
    
    NSValue  *value  = nil;
    NSNumber *number = nil;
    NSDictionary *userInfo = notification.userInfo;
    
    if ((value = [userInfo valueForKey: UIKeyboardFrameBeginUserInfoKey])) { 
        
        DDGLog(@"Beginning Frame: %@.", NSStringFromCGRect(value.CGRectValue)); 
    }
    if ((value = [userInfo valueForKey: UIKeyboardFrameEndUserInfoKey])) { 
        
        DDGLog(@"Ending Frame: %@.", NSStringFromCGRect(value.CGRectValue)); 
    }
    if ((number = [userInfo valueForKey: UIKeyboardAnimationCurveUserInfoKey])) { 
        
        DDGLog(@"Animation Curve: %@.", number.stringValue); 
    }
    if ((number = [userInfo valueForKey: UIKeyboardAnimationDurationUserInfoKey])) { 
        
        DDGLog(@"Duration: %@.", number.stringValue); 
    }
    return self;
    
} // -logKeyboardNotification:


#define kKeyboardWillShow  (@selector(keyboardWillShow:))
- (void) keyboardWillShow: (NSNotification *) notification {
    
    DDGTrace();
//    
//    [self logKeyboardNotification: notification];
	[self.cov fadeOut];

} // -keyboardWillShow:


#define kKeyboardDidShow  (@selector(keyboardDidShow:))
- (void) keyboardDidShow: (NSNotification *) notification {
    
    DDGTrace();
//    
//    [self logKeyboardNotification: notification];
    
} // -keyboardDidShow:


#define kKeyboardWillHide  (@selector(keyboardWillHide:))
- (void) keyboardWillHide: (NSNotification *) notification {
    
    DDGTrace();
//    
//    [self logKeyboardNotification: notification];
	[self.cov fadeOut];

} // -keyboardWillHide:


#define kKeyboardDidHide  (@selector(keyboardDidHide:))
- (void) keyboardDidHide: (NSNotification *) notification {
    
    DDGTrace();
//    
//    [self logKeyboardNotification: notification];
    
} // -keyboardDidHide:


#define kKeyboardWillChangeFrame  (@selector(keyboardWillChangeFrame:))
- (void) keyboardWillChangeFrame: (NSNotification *) notification {
    
    DDGTrace();
    
    [self logKeyboardNotification: notification];
    
    NSDictionary *userInfo = notification.userInfo;
    
    CGRect beginRect = [[userInfo valueForKey: UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGRect   endRect = [[userInfo valueForKey: UIKeyboardFrameEndUserInfoKey]   CGRectValue];
    UIViewAnimationCurve curve = [[userInfo valueForKey: UIKeyboardAnimationCurveUserInfoKey] integerValue];
    NSTimeInterval duration = [[userInfo valueForKey: UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    App *app = App.sharedApp;
    
    beginRect = [app.window convertRect: beginRect fromWindow: nil]; // Convert from the screen to the window.
    beginRect = [self.backgroundView convertRect: beginRect fromView: app.window];
    
    DDGDesc(NSStringFromCGRect(beginRect));
    
    endRect = [app.window convertRect: endRect fromWindow: nil]; // Convert from the screen to the window.
    endRect = [self.backgroundView convertRect: endRect fromView: app.window];
    
    CGRect frame = self.backgroundView.frame;
    
    frame.size.height += beginRect.origin.y > endRect.origin.y ? -endRect.size.height : endRect.size.height;
    
    const NSInteger kAnimationOptionCurveShift = 16; // Magic number copied out of the UIView headers.
    
    [UIView animateWithDuration: duration 
                          delay: 0.0 
                        options: curve << kAnimationOptionCurveShift
                     animations: ^{ self.backgroundView.frame = frame; } 
                     completion: ^(BOOL finished){ [self scrollToBottom: YES]; }];
    
} // -keyboardWillChangeFrame:


#define kKeyboardDidChangeFrame  (@selector(keyboardDidChangeFrame:))
- (void) keyboardDidChangeFrame: (NSNotification *) notification {
    
//    DDGTrace();
    
//    [self logKeyboardNotification: notification];
    
} // -keyboardDidChangeFrame:

#define kBecomeActive  (@selector(becomeActive:))
- (void) becomeActive: (NSNotification *) notification {
    
     
    self.navigationItem.title =  [XMPPJID userNameWithJIDString: self.conversation.remoteJID];
      
    [self updatePhoneButton];
}

- (ChatViewController *) registerForNotifications {
	
	DDGTrace();
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	[nc removeObserver: self];
	
	[nc addObserver: self 
		   selector:  kKeyboardWillShow 
			   name: UIKeyboardWillShowNotification 
			 object: nil];
    
	[nc addObserver: self 
		   selector:  kKeyboardDidShow 
			   name: UIKeyboardDidShowNotification 
			 object: nil];
    
	[nc addObserver: self 
		   selector:  kKeyboardWillHide
			   name: UIKeyboardWillHideNotification
			 object: nil];
    
	[nc addObserver: self 
		   selector:  kKeyboardDidHide
			   name: UIKeyboardDidHideNotification 
			 object: nil];
	
	[nc addObserver: self 
		   selector:  kKeyboardDidChangeFrame 
			   name: UIKeyboardDidChangeFrameNotification 
			 object: nil];
    
	[nc addObserver: self 
		   selector:  kKeyboardWillChangeFrame
			   name: UIKeyboardWillChangeFrameNotification 
			 object: nil];
   
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
	//	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
//	[nc addObserver:self
//											 selector:@selector(orientationChanged:)
//												 name:UIDeviceOrientationDidChangeNotification
//											   object:nil];
//	[nc addObserver:self
//											 selector:@selector(settingsChanged:)
//												 name:NSUserDefaultsDidChangeNotification
//											   object:nil];
    return self;
	
} // -registerForNotifications

@end
