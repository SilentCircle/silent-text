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
//  ChatViewController.m
//  SilentChat
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#include "SCpubTypes.h"

#import "XMPPJID.h"
#import "App+Model.h"

#import "ChatViewController.h"
#import "UIViewController+SCUtilities.h"
#import "SilentTextStrings.h"

#import "ChatViewRow.h"
//#import "WEPopoverController.h"
#import "GearContentViewController.h"
#import "ChatOptionsViewController.h"
#import "SCloudViewController.h"

#import "ChatOptionsView.h"

#import "Missive.h"
#import "MissiveRow.h"

#import "SCimpLogEntry.h"
#import "InfoEntry.h"
#import "RekeyRow.h"
#import "InfoRow.h"
#import "DateRow.h"

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
#import "PasscodeViewController.h"
#import "ConversationViewController.h"
#import "STMediaController.h"
#import "NSManagedObjectContext+DDGManagedObjectContext.h"
#import "SCloudManager.h"
#import "GeoViewController.h"
#import "ChatSenderMapAnnotation.h"
#include "SCpubTypes.h"
#import "NSNumber+Filesize.h"
#import "STFwdViewController.h"
#import "MZAlertView.h"
#import "UIImage+Thumbnail.h"
#import "UIBarButtonItem+SCUtilities.h"
#import "BackgroundPickerViewController.h"

#import "SCAddressBookController.h"

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
@property (strong, nonatomic) UIImage * otherSelectedBubble;
@property (strong, nonatomic) UIImage *plainTextBubble;
@property (strong, nonatomic) NSArray * ascendingDates;
@property (strong, nonatomic) NSArray *descendingDates;

@property (strong, nonatomic) UIActionSheet     *actionSheet;

@property (nonatomic) BOOL                  shouldScrollToBottom;
@property (nonatomic) BOOL					keyboardIsActive;
@property (nonatomic) BOOL 					dontChangeKeyboardOrGrowingTextWhileSending;
@property (nonatomic) BOOL					skipFirstKeyboardNotification;
@property (nonatomic) BOOL					noKeyboardAnimation;
@property (nonatomic, strong) MBProgressHUD *HUD;

//@property (strong, nonatomic) WEPopoverController *popover;
@property (strong, nonatomic) Missive *selectedMissive;

- (ChatViewController *) registerForXMPPStreamDelegate;
- (ChatViewController *) registerForNotifications;

#define     kSendAction  (@selector(sendAction:))
- (IBAction) sendAction: (UIButton *) sender;

@end

@implementation ChatViewController


static NSString *const kBannerIcon = @"Icon-72";

const NSTimeInterval kDefaultGapInterval = 160;

//@synthesize backgroundView = _backgroundView;
//@synthesize tableView = _tableView;
//@synthesize textEntryView = _textEntryView;

@synthesize cov;

- (void) dealloc {
	
	
	[self.xmppStream removeDelegate: self];
	
	[NSNotificationCenter.defaultCenter removeObserver: self];
	
	[_conversation removeObserver: self forKeyPath: kInfoEntries];
	[_conversation removeObserver: self forKeyPath: kMissives];
	[_conversation removeObserver: self forKeyPath: kSCimpLogEntries];
	
} // -dealloc


- (void) setConversation: (Conversation *) conversation {
	
	
	if (_conversation) {
		
        [_conversation removeObserver: self forKeyPath: kInfoEntries];
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
        [conversation addObserver: self
					   forKeyPath: kInfoEntries
						  options: NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
						  context: NULL];
	}
	_conversation = conversation;
	self.rows = nil;
	//   self.sendButton.enabled = !!conversation;
	self.sendButton.enabled = [self.xmppStream isConnected];
	
} // -setConversation:


- (XMPPJID *) remoteJID {
    
 //	if (_remoteJID) { return _remoteJID; }
	
	XMPPJID *jid = [XMPPJID jidWithString: self.conversation.remoteJID];
	
//	self.remoteJID = jid;
	
	return jid;
	
} // -remoteJID


// this will tell  the XMPPModule for  SCIMP to delete the current keys.
- (void) resetKeys: (BOOL) newKeys
{
	App *app = App.sharedApp;
	
	if(newKeys)
	{
		[app.conversationManager resetScimpState:app.currentJID remoteJid: self.remoteJID];
		
		[XMPPSilentCircle  removeSecureContextForJid:self.remoteJID ];
	}
	
	[app.conversationManager sendReKeyToRemoteJID:self.remoteJID];
}


const CGFloat kBubbleInsetVertical   = 15.0f;
const CGFloat kBubbleInsetHorizontalPoint = 17.0f;
const CGFloat kBubbleInsetHorizontalFlat = 10.0f;

- (UIImage *) bubble {
	
	if (_bubble) { return _bubble; }
	
	UIEdgeInsets insets = UIEdgeInsetsMake(kBubbleInsetVertical, kBubbleInsetHorizontalFlat,
										   kBubbleInsetVertical, kBubbleInsetHorizontalPoint);
	
	UIImage *bubble = [[UIImage imageNamed: @"BubbleOrange.png"] resizableImageWithCapInsets: insets];
	
	self.bubble = bubble;
	
	return bubble;
	
} // -bubble


- (UIImage *) otherBubble {
	
	if (_otherBubble) { return _otherBubble; }
	
	UIEdgeInsets insets = UIEdgeInsetsMake(kBubbleInsetVertical, kBubbleInsetHorizontalPoint,
										   kBubbleInsetVertical, kBubbleInsetHorizontalFlat);
	
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
	
	UIEdgeInsets insets = UIEdgeInsetsMake(kBubbleInsetVertical, kBubbleInsetHorizontalFlat,
										   kBubbleInsetVertical, kBubbleInsetHorizontalPoint);
	
	UIImage *bubble = [[UIImage imageNamed: @"BubbleSelectedUser-1.png"] resizableImageWithCapInsets: insets];
	
	self.selectedBubble = bubble;
	
	return bubble;
	
} // -selectedBubble

- (UIImage *) otherSelectedBubble {
	
	if (_otherSelectedBubble) { return _otherSelectedBubble; }
	
	UIEdgeInsets insets = UIEdgeInsetsMake(kBubbleInsetVertical, kBubbleInsetHorizontalPoint,
										   kBubbleInsetVertical, kBubbleInsetHorizontalFlat);
	
	UIImage *bubble = [[UIImage imageNamed: @"BubbleSelectedOther-1.png"] resizableImageWithCapInsets: insets];
	
	self.otherSelectedBubble = bubble;
	
	return bubble;
	
} // -selectedBubble



- (UIImage *) plainTextBubble {

	if (_plainTextBubble) { return _plainTextBubble; }
	
	UIEdgeInsets insets = UIEdgeInsetsMake(kBubbleInsetVertical, kBubbleInsetHorizontalPoint,
										   kBubbleInsetVertical, kBubbleInsetHorizontalPoint);
	
	UIImage *bubble = [[UIImage imageNamed: @"BubblePlaintext.png"] resizableImageWithCapInsets: insets];
	
	self.plainTextBubble = bubble;
	
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


-(void) resendWithSiren: (Siren*) siren toJid:(XMPPJID *) remoteJid
{
	App *app = App.sharedApp;
	Siren *newSiren = [siren copy];
	uint32_t burnDelay = kShredAfterNever;
	
	newSiren.location = NULL;
	newSiren.shredAfter = burnDelay;
	newSiren.fyeo       = self.conversation.isFyeo;
	
	if(self.getBurnNoticeState)
	{
		burnDelay =  self.getBurnNoticeDelay;
		newSiren.shredAfter = burnDelay;
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
			newSiren.location   =  locString;
		}
	}
	
	XMPPMessage *xmppMessage = [newSiren chatMessageToJID: remoteJid];
	if (xmppMessage) {
		
        Missive *missive = [self insertMissiveForXMPPMessage: xmppMessage remoteJid:remoteJid];
        
  		[missive.managedObjectContext save];
		[self.xmppStream sendElement: xmppMessage];
	}
	
	
}


#pragma mark - UIView lifecycle management methods.


- (MissiveRow *) makeMissiveRowForMissive: (Missive *) missive {
	
	MissiveRow *missiveRow = MissiveRow.new;
	
	missiveRow.missive = missive;
	missiveRow.bubble = self.bubble;
	missiveRow.otherBubble = self.otherBubble;
	//    missiveRow.clockImage = self.clockImage;
	missiveRow.selectedBubble = self.selectedBubble;
	missiveRow.otherSelectedBubble = self.otherSelectedBubble;
	missiveRow.plainTextBubble = self.plainTextBubble;
	missiveRow.parentView = self.view;
	return missiveRow;
	
} // -makeMissiveRowForMissive:


- (RekeyRow *) makeRekeyRowForLogEntry: (SCimpLogEntry *) logEntry {
	
	RekeyRow *rekeyRow = RekeyRow.new;
	
	rekeyRow.logEntry = logEntry;
	
	return rekeyRow;
	
} // -makeMissiveRowForMissive:


- (InfoRow *) makeInfoRowForInfoEntry: (InfoEntry *) infoEntry {
	
	InfoRow *infoRow = InfoRow.new;
	
	infoRow.infoEntry = infoEntry;
	
	return infoRow;
	
} // -makeInfoRowForInfoEntry:




- (DateRow *) makeDateRow: (NSDate *) date {
	
	DateRow *dateRow = DateRow.new;
	
	dateRow.dateEntry = date;
	
	return dateRow;
	
} // -makeMissiveRowForMissive:



//remove date rows that are next to each other
- (NSArray *) adjacentDateRowsInRows: (NSMutableArray *) rows {
	
	DateRow *laterDateRow = nil;
	NSMutableArray *redundantRows = NSMutableArray.new;
	
	for (id<ChatViewRow> row in rows.reverseObjectEnumerator) {
		
		if (laterDateRow) {
			
			if ([row isKindOfClass: DateRow.class]) {
				
				[redundantRows addObject: row];
			}
			else {
				
				laterDateRow = nil;
			}
		}
		else {
			
			if ([row isKindOfClass: DateRow.class]) {
				
				laterDateRow = row;
			}
		}
	}
	return redundantRows;
	
} // -redundantRekeyRowsInRows:



// remove all but the last rekey row,
- (NSArray *) redundantRekeyRowsInRows: (NSMutableArray *) rows {
	
	RekeyRow *laterRekeyRow = nil;
	NSMutableArray *redundantRows = NSMutableArray.new;
	
	for (id<ChatViewRow> row in rows.reverseObjectEnumerator) {
		
		if (laterRekeyRow) {
			
			if ([row isKindOfClass: RekeyRow.class]) {
				
				[redundantRows addObject: row];
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
							self.conversation.missives.count
							+ self.conversation.scimpLogEntries.count
							+ self.conversation.infoEntries.count];
	
	for (Missive *missive in self.conversation.missives) {
		
		[rows addObject: [self makeMissiveRowForMissive: missive]];
	}
	
	for (InfoEntry *infoEntry in self.conversation.infoEntries) {
		
		[rows addObject: [self makeInfoRowForInfoEntry: infoEntry]];
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
	
	// insert the Date row between entries
	NSMutableArray *timedRows =  NSMutableArray.new;
	NSDate* lastDate = [NSDate distantPast];
	
	for (id<ChatViewRow> row in rows.objectEnumerator ) {
		
		NSTimeInterval  interval = [row.date timeIntervalSinceDate:lastDate];
		
		if(interval >  kDefaultGapInterval )
		{
			[timedRows addObject: [self makeDateRow: row.date]];
		}
		lastDate = row.date;
		[timedRows addObject: row];
	}
	
	
	self.conversation.notRead = 0;
    self.conversation.attentionFlag = NO;
    self.conversation.unseenBurnFlag = NO;
    [moc save];
	
	return timedRows;
	
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
//	UIImage *selectedOptionsBtnBackground = [[UIImage imageNamed:@"chatoptions"] stretchableImageWithLeftCapWidth:13 topCapHeight:0];
	
	UIButton *optionsButton = [UIButton buttonWithType:UIButtonTypeCustom];
	optionsButton.frame = CGRectMake(5, 9, 25, 25);
	optionsButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
	//	[optionsButton setTitle: @"▲" forState:UIControlStateNormal];
	
	[optionsButton addTarget: self action: @selector(chatOptionsPress:) forControlEvents:UIControlEventTouchUpInside];
	[optionsButton setBackgroundImage:optionsBtnBackground forState:UIControlStateNormal];
	//    [optionsButton setBackgroundImage:selectedOptionsBtnBackground forState:UIControlStateSelected];
	
	return optionsButton;
	
} // -makeOptionsButton


//- (void) updatePhoneButton
//{
//     // we are now using the JID as a phone number, so actually we they all have phone numbers.
//    
//    BOOL hasPhone = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"silentphone:"]];
//	//     [self.callButton setEnabled: hasPhone];
//}
//

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

- (UINavigationItem *) configureNavigationItem {
   
    
	UIBarButtonItem* btnClear = [[UIBarButtonItem alloc] initWithTitle:NSLS_COMMON_CLEAR_ALL
									 style:UIBarButtonItemStylePlain
									target:self
									action:@selector(clearAll:)];

#if 1
    [self.navigationItem setRightBarButtonItem: btnClear];
#else
    
    
    UIBarButtonItem* btnKey = NULL;
    
    if( BitTst(self.conversation.flags,kConversationFLag_Keyed))
    {
        UIImage* keyImage = BitTst(self.conversation.flags,kConversationFLag_KeyVerified)
        ? [UIImage imageNamed:@"key4"]
        : [UIImage imageNamed:@"key1"];
        
        btnKey =  [UIBarButtonItem  barItemWithImage:keyImage
                                                               target:NULL
                                                               action:NULL];
        [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects: btnClear, btnKey, nil]];
    }
#endif

 	return self.navigationItem;
	
} // -configureNavigationItem

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


- (void) calculateBurnTimes {
	
	NSManagedObjectContext *moc      = self.conversation.managedObjectContext;
	
#warning VINNIE speed this up
 
//	 NSPredicate *p = [NSPredicate predicateWithFormat: @"(id = %@)", self.conversation.missives];
//	 NSArray *missives = [moc fetchObjectsForEntity: kMissiveEntity predicate: p];
 
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
	
 	
} // -calculateBurnTimes


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
	
	DDGTrace();
	
	[super viewDidLoad];

// 	[self calculateBurnTimes];
	[self removeOldLogEntries];
	
	self.selectedMissive = NULL;
	self.rows = [self makeRows];
	DDGTrace();
	[self configureTextEntryView];
	
	[self configureNavigationItem];
	
	[self registerForXMPPStreamDelegate];
	[self registerForNotifications];
	
	self.shouldScrollToBottom = YES;
	
} // -viewDidLoad


- (void) viewDidUnload {
	
	//	[self setMapView:nil];
	[self setEntryContainerView:nil];
	[super viewDidUnload];
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	
  	[App.sharedApp.conversationManager  removeDelegate: self];
	
	
} // -viewDidUnload

-( void) updateEditButton
{
	
	if(self.conversation.missives.count)
	{
		
		self.navigationItem.rightBarButtonItem.enabled = YES;
		
	}
	else
	{
		if( self.isEditing)
			[self setEditing:NO  animated:YES];
		
		self.navigationItem.rightBarButtonItem.enabled = NO;
		
	}
	
}

- (void) updateBackBarButton
{
	int count= [App.sharedApp.conversationManager totalMessagesNotFrom: self.remoteJID];
	[App.sharedApp.conversationViewController  setChatViewBackButtonCount: count];
}

- (void) viewWillAppear: (BOOL) animated {
	
	App *app = App.sharedApp;
	
	if([app.addressBook needsReload])
		[app.addressBook reload];
	
	[super viewWillAppear: animated];
	
	[self updateTrackingStatus];
	
	[self.tableView reloadData];
	
	if(self.shouldScrollToBottom) [self scrollToBottom: NO];
	
	self.navigationItem.title = [XMPPJID userNameWithJIDString: self.conversation.remoteJID];
	
	//	[self hideMap];
	
	self.shouldScrollToBottom = NO;
	
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
	else
	{
		[self updateBackBarButton];
        [self configureNavigationItem];

 //           [self updateEditButton];
		
//		self.navigationItem.rightBarButtonItem =
//		[[UIBarButtonItem alloc] initWithTitle:NSLS_COMMON_CLEAR_ALL
//										 style:UIBarButtonItemStylePlain
//										target:self
//										action:@selector(clearAll:)];
//
		
		[App.sharedApp.conversationManager  removeDelegate: self];
		[App.sharedApp.conversationManager  addDelegate: self delegateQueue: dispatch_get_main_queue()];
	}
	
	[super viewDidAppear: animated];
//	if (!self.conversation) {
//		
//		[self.usernameField becomeFirstResponder];
//	}
} // -viewDidAppear:


- (void) viewWillDisappear: (BOOL) animated {
	
	[super viewWillDisappear: animated];
	
	App *app = App.sharedApp;
	[app.geoTracking stopUpdating];
	
    if (self.aiv)
		[self.aiv hide];
   
	[App.sharedApp.conversationManager  removeDelegate: self];
	[self unhideNavBar];

} // -viewWillDisappear:


- (void) viewDidDisappear: (BOOL) animated {
	
	[super viewDidDisappear: animated];

} // -viewDidDisappear:


- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) toInterfaceOrientation {
	
	return YES;
	
	//   return (toInterfaceOrientation == UIInterfaceOrientationPortrait);
	
} // -shouldAutorotateToInterfaceOrientation:

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	_noKeyboardAnimation = NO;

	DDGTrace();
}
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	DDGTrace();
	// do something before rotation
	//	[self.textView resignFirstResponder];
	if ([self.textView isFirstResponder]) {
		_skipFirstKeyboardNotification = YES;
		_noKeyboardAnimation = YES;
	}

//	DDGTrace();

  
}

//  Override inherited method to enable/disable Edit button
//
- (void)setEditing:(BOOL)editing
		  animated:(BOOL)animated
{
	[super setEditing:editing
			 animated:animated];
	
	UIBarButtonItem *editButton = [[self navigationItem] rightBarButtonItem];
	
	if(!editing)
	{
		editButton.title = @"Edit";
		editButton.style = UIBarButtonItemStyleBordered;
		
		self.navigationItem.LeftBarButtonItem = nil;
		
		self.navigationItem.hidesBackButton = NO;
		[self updateBackBarButton];
		
	}
	else
	{
		editButton.title = @"Cancel";
		editButton.style = UIBarButtonItemStyleDone;
		
		self.navigationItem.hidesBackButton = YES;
		
		self.navigationItem.LeftBarButtonItem =
		[[UIBarButtonItem alloc] initWithTitle:NSLS_COMMON_CLEAR_ALL
										 style:UIBarButtonItemStylePlain
										target:self
										action:@selector(clearAll:)];
		
		self.navigationItem.rightBarButtonItem.enabled = YES;
		
		[self.textView resignFirstResponder];
		if (self.cov)
			[self.cov hide];
	}
	
}


#pragma mark - Standard Notification Methods
#define kBecomeActive  (@selector(becomeActive:))
- (void) becomeActive: (NSNotification *) notification {
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
						 self.navigationItem.title = [XMPPJID userNameWithJIDString: self.conversation.remoteJID];
					 }];

	
	
//	[self updatePhoneButton];
}

- (void)applicationDidEnterBackground
{
//	NSLog(@"%s", __PRETTY_FUNCTION__);
	self.view.hidden = YES;
//	self.navigationItem.title =  @"";
    
    if (self.aiv)
		[self.aiv hide];

	
}
- (void)applicationWillEnterForeground
{
//	NSLog(@"%s", __PRETTY_FUNCTION__);
//	self.view.hidden = NO;
	
}

- (void)applicationWillResignActive
{
//	NSLog(@"%s", __PRETTY_FUNCTION__);
	[self.textView resignFirstResponder];
    
    if (self.aiv)
		[self.aiv hide];
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

#pragma mark - Missives and SCimpLogEntries observer methods.

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
	
	/*
	NSPredicate *p = [NSPredicate predicateWithFormat: @"%K == %@", kMissive, missive];
	
	NSArray *rows = [self.rows filteredArrayUsingPredicate: p];
	
	return rows.count ? [self.rows indexOfObject: rows.lastObject] : NSNotFound;
*/	
} // -rowIndexForMissive:


- (id<ChatViewRow>) rowEarlierThanDate: (NSDate *) date {
	
	NSPredicate *p = [NSPredicate predicateWithFormat: @"%K < %@", kDate, date];
	
	NSArray *rows = [self.rows filteredArrayUsingPredicate: p];
	
	return rows.lastObject;
	
} // -rowEarlierThanDate:


- (void) updateDateRow:(NSDate *) date
{
	id<ChatViewRow> earlierRow = [self rowEarlierThanDate: date];
	
	// was the previous row already a date row?
	if([earlierRow  isKindOfClass: DateRow.class])
	{
		DateRow* thisDateRow = earlierRow;
		NSUInteger rowIndex = [self.rows indexOfObject: earlierRow];
		NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity: 1];
		
		thisDateRow.dateEntry = [date dateByAddingTimeInterval:-.01];
		
		[indexPaths   addObject: [NSIndexPath indexPathForRow: rowIndex inSection: 0]];
		
		[self.tableView beginUpdates]; {
			
			[self.tableView reloadRowsAtIndexPaths: indexPaths
								  withRowAnimation: UITableViewRowAnimationFade];
		}
		[self.tableView endUpdates];
	}
	else
	{
		// if it's not a date row, we might need to insert one here
		
		NSTimeInterval  interval = [date  timeIntervalSinceDate:earlierRow.date];
		if(interval >  kDefaultGapInterval )
		{
			NSUInteger rowIndex = earlierRow ? [self.rows indexOfObject: earlierRow] + 1 : 0;
			
			NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity: 1];
			
			[self.rows insertObject: [self makeDateRow:[date dateByAddingTimeInterval:-.01] ] atIndex: rowIndex];
			[indexPaths   addObject: [NSIndexPath indexPathForRow: rowIndex inSection: 0]];
			
			[self.tableView beginUpdates]; {
				
				[self.tableView insertRowsAtIndexPaths: indexPaths
									  withRowAnimation: UITableViewRowAnimationFade];
			}
			[self.tableView endUpdates];
		}
	}
}


- (NSArray *) insertMissives: (NSArray *) missives {
	
	if (missives.count) {
		
		missives = [missives sortedArrayUsingDescriptors: self.ascendingDates];
		
		NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity: missives.count];
		
		for (Missive *missive in missives) {
			
			[self updateDateRow: missive.date];
			
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


- (void) deleteAdjacentDateRows {
 
    for (DateRow *dateRow in  [self adjacentDateRowsInRows: self.rows]) {
		
		NSUInteger rowIndex = [self.rows indexOfObject: dateRow];
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow: rowIndex inSection: 0];
		
		[self.rows removeObjectAtIndex: rowIndex];
		
		[self.tableView beginUpdates]; {
			
			[self.tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject: indexPath]
								  withRowAnimation: UITableViewRowAnimationFade];
		}  [self.tableView endUpdates];
	}
	
	[self.tableView reloadData];
}

- (NSArray *) adjacentInfoRowsInRows: (NSMutableArray *) rows {

#warning only pick inforows where [info objectForKey: kInfoEntryJID ] = kInfoEntryResourceChange;

	InfoRow *laterInfoRow = nil;
	NSMutableArray *redundantRows = NSMutableArray.new;
	
	for (id<ChatViewRow> row in rows.reverseObjectEnumerator) {
		if (laterInfoRow) {
			if ([row isKindOfClass: InfoRow.class]) {
				[redundantRows addObject: row];
			}
			else {
				laterInfoRow = nil;
			}
		}
		else {
			
			if ([row isKindOfClass: InfoRow.class]) {
				laterInfoRow = row;
			}
		}
	}
	return redundantRows;
	
} // -redundantInfoRowsInRows:



- (void) deleteAdjacentInfoRows {
	
	for (InfoRow *InfoRow in  [self adjacentInfoRowsInRows: self.rows]) {
		
		NSUInteger rowIndex = [self.rows indexOfObject: InfoRow];
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow: rowIndex inSection: 0];
		
		[self.rows removeObjectAtIndex: rowIndex];
		
		[self.tableView beginUpdates]; {
			
			[self.tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject: indexPath]
								  withRowAnimation: UITableViewRowAnimationFade];
		}  [self.tableView endUpdates];
	}
	
	[self.tableView reloadData];
	
}



static const CGFloat kFlameWidth = 20.0f;
static NSString *const kBurningCircle1 = @"BurningCircle_1";


#define poof
#ifdef poof
- (void) burnMissiveRow: (MissiveRow *) missiveRow withCell: (STBubbleTableViewCell *) cell {
	
	UIImageView *pv = [[UIImageView alloc] initWithFrame:CGRectZero];
	pv.contentMode = UIViewContentModeScaleAspectFit;
	NSArray	*poofImages = [NSArray arrayWithObjects:
						   [UIImage imageNamed:@"poof5"],
						   [UIImage imageNamed:@"poof4"],
						   [UIImage imageNamed:@"poof3"],
						   [UIImage imageNamed:@"poof2"],
						   [UIImage imageNamed:@"poof1"],
						   [UIImage imageNamed:@"poof0"],
						   [UIImage imageNamed:@"poof1"],
						   [UIImage imageNamed:@"poof2"],
						   [UIImage imageNamed:@"poof3"],
						   [UIImage imageNamed:@"poof4"],
						   [UIImage imageNamed:@"poof5"],
						   nil];
	pv.animationImages = poofImages;
	pv.image = [poofImages objectAtIndex:0];
	pv.contentMode = UIViewContentModeScaleAspectFit;
	//pv.frame = CGRectMake(0, 0, pv.image.size.width, pv.image.size.height);
	CGFloat width, height;
	width = cell.bubbleView.frame.size.width;
	height = cell.bubbleView.frame.size.height;
	width = width > pv.image.size.width ? width : pv.image.size.width;
	height = height > pv.image.size.height ? height : pv.image.size.height;
	//	pv.frame = CGRectMake(0, 0, cell.bubbleView.frame.size.width, cell.bubbleView.frame.size.height);
	pv.frame = CGRectMake(0, 0, width, height);
	
	pv.center = cell.bubbleView.center;
	pv.animationRepeatCount = 1;
	
	pv.image = [pv.animationImages objectAtIndex:0];
	[cell.contentView addSubview:pv];
	//pv.center = cell.bubbleView.center;
	
	pv.animationDuration = 0.5;
	pv.image = [pv.animationImages lastObject];
	[pv startAnimating];
	
	[UIView animateWithDuration:0.3
						  delay:0.25
						options:UIViewAnimationCurveEaseOut
					 animations:^{
						 cell.bubbleView.transform = CGAffineTransformScale(cell.bubbleView.transform, 0.25, 0.25);
						 cell.bubbleView.alpha = 0;
					 }
					 completion:^(BOOL finished) {
						 //					 [UIView animateWithDuration:0.2 animations:^{
						 //					 }];
						 [pv removeFromSuperview];
						 [pv stopAnimating];
						 //					 [self setNeedsLayout];
						 NSUInteger rowIndex = [self.rows indexOfObject: missiveRow];
						 NSIndexPath *indexPath = [NSIndexPath indexPathForRow: rowIndex inSection: 0];
						 
						 [self.rows removeObjectAtIndex: rowIndex];
						 
						 [self.tableView beginUpdates]; {
							 
							 [self.tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject: indexPath]
												   withRowAnimation: UITableViewRowAnimationFade];
						 }
						 [self.tableView endUpdates];
						 
						 [self removeRedundantRekeyRows];
						 [self deleteAdjacentInfoRows];
						 [self deleteAdjacentDateRows];
						 
					 }];
	
	
} // -burnMissiveRow:withCell:
#else
- (void) burnMissiveRow: (MissiveRow *) missiveRow withCell: (STBubbleTableViewCell *) cell {
		
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
						 [self deleteAdjacentInfoRows];
						 [self deleteAdjacentDateRows];
						 
						 [UIView animateWithDuration: kDefaultDuration
										  animations: ^{ burnView.alpha = 0.0f; }
										  completion: ^(BOOL finished) { [stencilView removeFromSuperview]; }];
					 }];
	
} // -burnMissiveRow:withCell:
#endif

- (void) burnMissiveRow: (MissiveRow *) missiveRow {
		
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
	
	if (missives.count) {
		
		missives = [missives sortedArrayUsingDescriptors: self.descendingDates];
		
		for (Missive *missive in missives) {
			
			NSUInteger rowIndex = [self rowIndexForMissive: missive];
			
			if (rowIndex != NSNotFound) {
				
				[App performBlock: ^{ [self burnMissiveRow: [self.rows objectAtIndex: rowIndex]]; }];
			}
		}
		[App performBlock: ^{
			[self deleteAdjacentDateRows];
			[self deleteAdjacentInfoRows];
		} afterDelay: kDefaultDuration * 5];
#warning:  VInnnie, is this the delay in deletion that you were worried about?
	}
	return missives;
	
} // -removeMissives:


- (NSArray *) insertLogEntries: (NSArray *) logEntries {
	
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
			
			}
	}
	return logEntries;
	
} // -insertLogEntries:

 
- (NSUInteger) rowIndexForLogEntry: (SCimpLogEntry *) logEntry {
	
	NSUInteger index = NSNotFound;
	
	for (id element in self.rows)
	{
		if([element  isKindOfClass: RekeyRow.class])
		{
			RekeyRow* thisRow = element;
			
			if( thisRow.logEntry == logEntry)
			{
				index  = [self.rows indexOfObject: thisRow ];
				break;
			}
		}
	}
	return index;
}

- (NSArray *) removeLogEntries: (NSArray *) logEntries {
	
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



- (NSUInteger) rowIndexForInfoEntry: (InfoEntry *) infoEntry {
	
	NSUInteger index = NSNotFound;
	
	for (id element in self.rows)
	{
		if([element  isKindOfClass: InfoRow.class])
		{
			InfoRow* thisRow = element;
			
			if( thisRow.infoEntry == infoEntry)
			{
				index  = [self.rows indexOfObject: thisRow ];
				break;
			}
		}
	}
	return index;
}

- (NSArray *) insertInfoEntries: (NSArray *) infoEntries {
	
	if (infoEntries.count) {
		
		infoEntries = [infoEntries sortedArrayUsingDescriptors: self.ascendingDates];
		
		NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity: infoEntries.count];
		
		for (InfoEntry *infoEntry in infoEntries) {
			
			id<ChatViewRow> earlierRow = [self rowEarlierThanDate: infoEntry.date];
			
			NSUInteger rowIndex = earlierRow ? [self.rows indexOfObject: earlierRow] + 1 : 0;
			
			[self.rows insertObject: [self makeInfoRowForInfoEntry: infoEntry] atIndex: rowIndex];
			[indexPaths   addObject: [NSIndexPath indexPathForRow: rowIndex inSection: 0]];
		}
		if (indexPaths.count) {
			
			[self.tableView beginUpdates]; {
				
				[self.tableView insertRowsAtIndexPaths: indexPaths
									  withRowAnimation: UITableViewRowAnimationFade];
			}
			[self.tableView endUpdates];
			
			[self scrollToBottom: YES];
			
		}
	}
	return infoEntries;
	
} // -insertinfoEntries:

- (NSArray *) removeInfoEntries: (NSArray *) infoEntries {
	if (infoEntries.count) {
		
		infoEntries = [infoEntries sortedArrayUsingDescriptors: self.descendingDates];
		
		NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity: infoEntries.count];
		
		for (InfoEntry *infoEntry in infoEntries) {
			
			NSUInteger rowIndex = [self rowIndexForInfoEntry: infoEntry];
			
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
	return infoEntries;
	
} // -removeinfoEntries:



- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object change: (NSDictionary *) change context: (void *) context {
	
	if (self.rows) {
		
		NSUInteger changeKind = [[change valueForKey: NSKeyValueChangeKindKey] unsignedIntegerValue];
		
		if ([keyPath isEqualToString: kMissives]) {
			
			if (changeKind == NSKeyValueChangeInsertion) {
				
				[self insertMissives: [change valueForKey: NSKeyValueChangeNewKey]];
				//				[self updateEditButton];
			}
			if (changeKind == NSKeyValueChangeRemoval) {
				
				[self removeMissives: [change valueForKey: NSKeyValueChangeOldKey]];
				
				//				[self updateEditButton];
			}
		}
		else if ([keyPath isEqualToString: kSCimpLogEntries]) {
			
			if (changeKind == NSKeyValueChangeInsertion) {
				
				[self insertLogEntries: [change valueForKey: NSKeyValueChangeNewKey]];
                
                // we might have changed the rekeys rows, we should probably clean them up 
                [self performSelector:@selector(removeRedundantRekeyRows) withObject:NULL afterDelay:0.0];

			}
			if (changeKind == NSKeyValueChangeRemoval) {
				
				[self removeLogEntries: [change valueForKey: NSKeyValueChangeOldKey]];
			}
		}
		
		else if ([keyPath isEqualToString: kInfoEntries]) {
			
			if (changeKind == NSKeyValueChangeInsertion) {
				
				[self insertInfoEntries: [change valueForKey: NSKeyValueChangeNewKey]];
			}
			if (changeKind == NSKeyValueChangeRemoval) {
				
				[self removeInfoEntries: [change valueForKey: NSKeyValueChangeOldKey]];
			}
		}
	
  	}
	
} // -observeValueForKeyPath:ofObject:change:context:


- (void)handleDataModelChange:(NSNotification *)note
{
	NSSet *updatedObjects = [[note userInfo] objectForKey:NSUpdatedObjectsKey];
	
	if(updatedObjects && [updatedObjects count] > 0)
	{
		for (NSManagedObject *obj in updatedObjects) {
			if ([obj isKindOfClass: Conversation.class])
			{
				Conversation* conversation = (Conversation*) obj;
				if((conversation == self.conversation)
				   && conversation.attentionFlag)
				{
					[self.tableView reloadData];
					
				}
				
			}
		}
	}
	// Do something in response to this
}


#pragma mark - Action Sheets


- (IBAction)clickContactActionSheet:(UIView*)view {
	
	if (self.actionSheet) {
		// do nothing
	} else
	{
		
		UIActionSheet *actionSheet = NULL;
		
		if( [self.remoteJID isInAddressBook] )
		{
			
			actionSheet = [[UIActionSheet alloc]
						   initWithTitle:NULL
						   delegate:self
						   cancelButtonTitle:NSLS_COMMON_CANCEL
						   destructiveButtonTitle:NULL
						   otherButtonTitles:NSLS_COMMON_SHOW_CONTACT, NSLS_COMMON_SEND_CONTACT, nil ];
		}
		else
		{
			actionSheet = [[UIActionSheet alloc]
						   initWithTitle:NULL
						   delegate:self
						   cancelButtonTitle:NSLS_COMMON_CANCEL
						   destructiveButtonTitle:NULL
						   otherButtonTitles:NSLS_COMMON_ADD_CONTACT,
						   NSLS_COMMON_SEND_CONTACT,  nil ];
		}
		
		[actionSheet showInView:view ];
	}
}


- (IBAction)clickCameraActionSheet:(UIView*)view {
	
	if (self.actionSheet) {
		// do nothing
	} else {
		[self.textView resignFirstResponder];
		UIActionSheet *actionSheet = [[UIActionSheet alloc]
									  initWithTitle:NULL
									  delegate:self
									  cancelButtonTitle:nil
									  destructiveButtonTitle:nil
									  otherButtonTitles: nil ];
		
		if([UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypePhotoLibrary])
			[actionSheet addButtonWithTitle:NSLS_COMMON_CHOOSE_PHOTO];
		
		if([UIImagePickerController isSourceTypeAvailable:
			UIImagePickerControllerSourceTypeCamera])
			[actionSheet addButtonWithTitle:NSLS_COMMON_TAKE_PHOTO];
	 
//        [actionSheet addButtonWithTitle:NSLS_COMMON_CHOOSE_AUDIO];

		actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:NSLS_COMMON_CANCEL];
		
		[actionSheet showInView:view ];
	}
}


- (IBAction)clickResetKeysActionSheet:(UIView*)view {
	
	if (self.actionSheet) {
		// do nothing
	} else {
		
		UIActionSheet *actionSheet = [[UIActionSheet alloc]
									  initWithTitle:NSLS_COMMON_RESET_KEYS_TEXT
									  delegate:self
									  cancelButtonTitle:NSLS_COMMON_CANCEL
									  destructiveButtonTitle:NSLS_COMMON_NEW_KEYS
									  otherButtonTitles:  NSLS_COMMON_REFRESH_KEYS, nil ];
		
		[actionSheet showInView:view ];
	}
}


- (IBAction)clickClearAllActionSheet:(UIView*)view {
	
	if (self.actionSheet) {
		// do nothing
	} else {
		
		UIActionSheet *actionSheet = [[UIActionSheet alloc]
									  initWithTitle:NULL
									  delegate:self
									  cancelButtonTitle:NSLS_COMMON_CANCEL
									  destructiveButtonTitle:NSLS_COMMON_CLEAR_CONVERSATION
									  otherButtonTitles:  nil ];
		
		[actionSheet showInView:view ];
	}
}

- (IBAction)clickResendActionSheet:(UIView*)view {
	
	if (self.actionSheet) {
		// do nothing
	} else {
		
		UIActionSheet *actionSheet = [[UIActionSheet alloc]
									  initWithTitle:NSLS_COMMON_UNABLE_TO_DECRYPT
									  delegate:self
									  cancelButtonTitle:NSLS_COMMON_CANCEL
									  destructiveButtonTitle:NSLS_COMMON_TRY_AGAIN
									  otherButtonTitles:  nil ];
		
		[actionSheet showInView:view ];
	}
}


-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	NSString *choice = [actionSheet buttonTitleAtIndex:buttonIndex];
	
	if ([choice isEqualToString:NSLS_COMMON_SHOW_CONTACT])
	{
		// create new contact
		SCAddressBookController* abc = [[SCAddressBookController alloc] init];
		[self.navigationController pushViewController: abc animated: YES];
        [abc  showContactForJID:self.remoteJID];
		
	}
    if ([choice isEqualToString:NSLS_COMMON_SEND_CONTACT])
	{
        [self.textView resignFirstResponder];
		// create new contact
		SCAddressBookController* abc = [[SCAddressBookController alloc] init];
		[self.navigationController pushViewController: abc animated: YES];
        [abc sendContactSCloudWithDelegate:self];
		
	}
	else if ([choice isEqualToString:NSLS_COMMON_ADD_CONTACT])
	{
		// create new contact
		SCAddressBookController* abc = [[SCAddressBookController alloc] init];
		[self.navigationController pushViewController: abc animated: YES];
		[abc createContactWithJID:self.remoteJID];
		
	}
	else if ([choice isEqualToString:NSLS_COMMON_CHOOSE_PHOTO])
	{
		STMediaController* cam = [[STMediaController alloc] initWithDelegate: self];
		[self.navigationController pushViewController: cam animated: YES];
		[cam pickExistingPhoto];
		
	}
	else if ([choice isEqualToString:NSLS_COMMON_TAKE_PHOTO])
	{
		STMediaController* cam = [[STMediaController alloc] initWithDelegate:self];
   		App *app = App.sharedApp;
     
        if(app.geoTracking.allowTracking
		   && app.geoTracking.isTracking
		   && self.conversation.isTracking)
		{
			// insert tracking info
			cam.location = app.geoTracking.location;
         }
        
		[self.navigationController pushViewController: cam animated: YES];
		[cam pickNewPhoto];
	}
//	else if ([choice isEqualToString:NSLS_COMMON_CHOOSE_AUDIO])
//	{
//        [self recordAudio];
//	}
  	else if ([choice isEqualToString:NSLS_COMMON_CLEAR_CONVERSATION])
	{
		App *app = App.sharedApp;
		
        [self.textView resignFirstResponder];
		if (self.cov)
			[self.cov hide];

		[app.conversationManager clearConversation:app.currentJID remoteJid: self.remoteJID];
		
		[self updateBackBarButton];
	}
	
	else if ([choice isEqualToString:NSLS_COMMON_REFRESH_KEYS])
	{
		[self resetKeys:NO];
	}
	
	else if ([choice isEqualToString:NSLS_COMMON_NEW_KEYS])
	{
		[self resetKeys:YES];
	}
	else if ([choice isEqualToString:NSLS_COMMON_TRY_AGAIN])
	{
		[self resendMessage];
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
				
		return xmppMessage;
	}
	return nil;
	
} // -xmppMessageForText:


- (Missive *) insertMissiveForXMPPMessage: (XMPPMessage *) xmppMessage remoteJid: (XMPPJID *) remoteJID
{
	
	App *app = App.sharedApp;
	Missive *missive = [Missive insertMissiveForXMPPMessage: xmppMessage
									 inManagedObjectContext: self.conversation.managedObjectContext
											  withEncryptor: self.conversation.encryptor];
    
	missive.conversation   = [app.conversationManager conversationForLocalJid: app.currentJID
                                                                    remoteJid: remoteJID];
    missive.conversation.date = missive.date;

    return missive;
	
} // -insertMissiveForXMPPMessage:

- (IBAction) sendAction: (UIButton *) sender {
	if ([_textView isFirstResponder]) {
		_dontChangeKeyboardOrGrowingTextWhileSending = YES;  // this and assoicated code is to get around a shortcoming in the Keyboard/TextInput system that doesn't let one read the text out of a text field/view, after forcing autocorrect/autocomplete to do its thing.  Maybe they figure it is too risky to accept a suggested autocomplete/correct like this, but it really is no different than other use.
		[_textView resignFirstResponder]; // this is also for accepting suggested correction/completion
	}
	XMPPMessage *xmppMessage = [self xmppMessageForText: self.textView.text];
	
	if (xmppMessage) {
		
		Missive *missive = [self insertMissiveForXMPPMessage: xmppMessage remoteJid:self.remoteJID ];
		
		[missive.managedObjectContext save];
		[self.xmppStream sendElement: xmppMessage];
	}
	if (_dontChangeKeyboardOrGrowingTextWhileSending) {
		[_textView becomeFirstResponder];	// this is also for accepting suggested correction/completion
		_dontChangeKeyboardOrGrowingTextWhileSending = NO;// this is also for accepting suggested correction/completion
	}
	self.textView.text = @"";
} // -sendAction:


- (IBAction) swipeDown: (UISwipeGestureRecognizer *) gestureRecognizer {
	
	if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
		
		[self.textView resignFirstResponder];
	}
	
} // -swipeDown:

- (IBAction) threeFingerTap: (UITapGestureRecognizer *) gestureRecognizer {
	App *delegate = (App *) [[UIApplication sharedApplication] delegate];
	//	[delegate switchBackgrounds];
	
		BackgroundPickerViewController *bpvc = [BackgroundPickerViewController.alloc initWithNibName: @"BackgroundPickerViewController" bundle: nil];
		
		[self.navigationController pushViewController: bpvc animated: YES];
		

} // -threeFingerTap:
- (IBAction) singleFingerTap: (UITapGestureRecognizer *) gestureRecognizer {
	[self unhideNavBar];
} // -singleFingerTap:

- (void) unhideNavBar
{
	if ([self.navigationController isNavigationBarHidden])
		[self.navigationController setNavigationBarHidden:NO animated:YES];
}
- (IBAction) cameraAction: (UIButton *) sender
{
	[self clickCameraActionSheet: self.view];
}


- (IBAction) contactAction: (UIButton *) sender {
	
 		[self clickContactActionSheet: self.view];
 	
} // -contactAction:

- (IBAction)micAction:(id)sender {
	[self recordAudio];
}

- (IBAction) phoneAction: (UIButton *) sender {
 	NSMutableString *phone =    [self.remoteJID.user mutableCopy];
	
	if( phone  )
	{
		
		UIApplication *app = [UIApplication sharedApplication];
  		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"silentphone:%@", phone]];
		
		[app openURL:url];
	}
	
	
} // -phoneAction:


//- (WEPopoverContainerViewProperties *) improvedContainerViewProperties {
//
//    //
//    // Copied with minor edits from the WEPopover sample app.
//    //
//	WEPopoverContainerViewProperties *props = WEPopoverContainerViewProperties.new;
//
//	NSString *bgImageName = nil;
//	CGFloat bgMargin = 0.0;
//	CGFloat bgCapSize = 0.0;
//	CGFloat contentMargin = 4.0;
//
//	bgImageName = @"popoverBg.png";
//
//	// These constants are determined by the popoverBg.png image file and are image dependent
//	bgMargin = 13; // margin width of 13 pixels on all sides popoverBg.png (62 pixels wide - 36 pixel background) / 2 == 26 / 2 == 13
//	bgCapSize = 31; // ImageSize/2  == 62 / 2 == 31 pixels
//
//	props.leftBgMargin = bgMargin;
//	props.rightBgMargin = bgMargin;
//	props.topBgMargin = bgMargin;
//	props.bottomBgMargin = bgMargin;
//	props.leftBgCapSize = bgCapSize;
//	props.topBgCapSize = bgCapSize;
//	props.bgImageName = bgImageName;
//	props.leftContentMargin = contentMargin;
//	props.rightContentMargin = contentMargin - 1; // Need to shift one pixel for border to look correct
//	props.topContentMargin = contentMargin;
//	props.bottomContentMargin = contentMargin;
//
//	props.arrowMargin = 4.0;
//
//	props.upArrowImageName = @"popoverArrowUp.png";
//	props.downArrowImageName = @"popoverArrowDown.png";
//	props.leftArrowImageName = @"popoverArrowLeft.png";
//	props.rightArrowImageName = @"popoverArrowRight.png";
//
//	return props;
//
//} // -improvedContainerViewProperties
//

- (IBAction) gearAction: (UIButton *) gearButton {
	[self pushChatOptionsViewController];
	
} // -gearAction:


- (IBAction)newOptionPress:(id)sender {
//	NSLog(@"newoptionpress");
	//
	//	if (!self.cov)
	//		[[NSBundle mainBundle] loadNibNamed:@"ChatOptionsView" owner:self options:nil];
	//	cov.delegate = self;
	//	[self.cov unfurlOnView:sender atPoint:CGPointMake(76, self.view.frame.size.height - 44)];
	
}

- (IBAction) clearAll: (UIBarButtonItem *) sender {
	
	[self clickClearAllActionSheet: self.view];
	
} // -clearAll:



-(void) resendMessage
{
	
	if(self.selectedMissive)
	{
        App* app = App.sharedApp;
        Missive* missive = self.selectedMissive;
     
//      XMPPMessage *xmppMessage = [missive.siren chatMessageToJID: self.remoteJID];
//		[self.xmppStream sendElement: xmppMessage];
 		
		// resend here
        [self resendWithSiren: missive.siren toJid:self.remoteJID];
	
   // delete the old one
        
		BitClr(missive.flags, kMissiveFLag_RequestResend);

        [app.conversationManager deleteMissiveFromConversation:app.currentJID
													 remoteJid: self.remoteJID
													   missive:missive];
        
        self.conversation.attentionFlag = NO;
		[self.conversation.managedObjectContext save];
		
		[self.tableView reloadData];
		
	}
	self.selectedMissive = NULL;
}


#pragma mark - UITextFieldDelegate methods.

//
//- (UIView *) removeUserEntryView {
//	
//	CGRect frame = self.tableView.frame;
//	
//	frame.origin       = self.userEntryView.frame.origin;
//	frame.size.height += self.userEntryView.frame.size.height;
//	
//	[UIView animateWithDuration: kDefaultDuration
//					 animations: ^{ self.userEntryView.alpha = 0.0; self.tableView.frame = frame; }
//					 completion: ^(BOOL finished) { [self.userEntryView removeFromSuperview]; }];
//	
//	return self.userEntryView;
//	
//} // -removeUserEntryView
//

- (BOOL) textFieldShouldReturn: (UITextField *) textField {
	
	XMPPJID *remoteJID = [XMPPJID jidWithUser: textField.text domain: kDefaultAccountDomain resource: nil];
	
	App *app = App.sharedApp;
	
	Conversation *conversation = [app.conversationManager conversationForLocalJid: app.currentJID
																		remoteJid: remoteJID];
	self.conversation = conversation;
	self.rows = [self makeRows];
	
	[self.tableView reloadData];
	
	self.navigationItem.title = [XMPPJID userNameWithJIDString: conversation.remoteJID];
	
	[self.textView becomeFirstResponder];
//	[self removeUserEntryView];
	
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
	CGRect frame;
	
	frame = self.entryContainerView.frame;
	frame.origin.y    += diff;
	frame.size.height -= diff;
	self.entryContainerView.frame = frame;

	frame = self.textEntryView.frame;
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
	
//	DDGTrace();
//	NSInteger testInteger = self.rows.count;
//	DDGTrace();
//	if (testInteger) {
//		testInteger -=1;
//	}
	return  self.rows.count;
	
} // -tableView:numberOfRowsInSection:


- (UITableViewCell *) cellForRow: (id<ChatViewRow>) row {
	
//	DDGTrace();
	
	UITableViewCell *cell = nil;
	
	cell = [self.tableView dequeueReusableCellWithIdentifier: row.reuseIdentifier];
	
	if (!cell) {
		
		cell = row.tableViewCell;
	}
//	DDGTrace();

	return cell;
	
} // -cellForRow:


- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath {
	
//	DDGTrace();
	
	id<ChatViewRow> row = [self.rows objectAtIndex: indexPath.row];
	
	UITableViewCell *cell = [self cellForRow: row];
	
	row.delegate = self;
//	DDGTrace();
//	NSLog(@"%s: %d",__PRETTY_FUNCTION__,indexPath.row);
	row.indexRow = indexPath.row;
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

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	if (scrollView.contentOffset.y > 20) {
		if (![self.navigationController isNavigationBarHidden])
			[self.navigationController setNavigationBarHidden:YES animated:YES];
	}
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView{
	[self unhideNavBar];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.contentOffset.y == 0) {
		[self unhideNavBar];
	}
}

#pragma mark - STFwdViewDelegate methods.
 
- (void) selectedJid:(XMPPJID*) jid withSiren:(Siren *)siren
{
    [self resendWithSiren: siren toJid:jid];

}

#pragma mark - ChatViewRowDelegate methods.


// this means the user tapped the burn icon.. (show them details)


- (void) tappedForwardRow: (id<ChatViewRow>) row

{
     if ([row isKindOfClass: MissiveRow.class]) {
		
		Missive *missive = [(MissiveRow *)row missive];
		
		if(missive && missive.siren)
		{
			STFwdViewController *fvc = [STFwdViewController.alloc initWithSiren: missive.siren];
			
            fvc.delegate = self;
            fvc.prompt = @"Select a silent text user to forward to.",
		
            [self.textView resignFirstResponder];

			[self.navigationController pushViewController: fvc animated: YES];
		}
	}

  }


// this means the user asked to delete the row

- (void) tappedDeleteRow: (id<ChatViewRow>) row
{
	
	App* app = App.sharedApp;
	
	if ([row isKindOfClass: MissiveRow.class]) {
		Missive *missive = [(MissiveRow *)row missive];

        // if I sent it then I can request to redact it from their side
        if(![[[XMPPJID jidWithString:missive.toJID]bare] isEqualToString: self.conversation.localJID])
        {
            [app.conversationManager sendRequestBurnMessageToRemoteJID:self.remoteJID forMessage:missive.scppID];
        }
        
		[app.conversationManager deleteMissiveFromConversation:app.currentJID
													 remoteJid: self.remoteJID
													   missive:missive];
		
	}
	
}




- (void) tappedFailure: (id<ChatViewRow>) row
{
	if ([row isKindOfClass: MissiveRow.class]) {
		
		Missive *missive = [(MissiveRow *)row missive];
		
 		// if they clicked on error button, give them a choice, othewise resend it.
		if(missive && BitTst(missive.flags,kMissiveFLag_RequestResend))
		{
			self.selectedMissive =  missive;
			
			[self clickResendActionSheet: self.view ];
			
		}
    }
}


- (void) tappedResend: (id<ChatViewRow>) row
{
	if ([row isKindOfClass: MissiveRow.class]) {
		
		Missive *missive = [(MissiveRow *)row missive];
		
        [self resendWithSiren: missive.siren toJid:self.remoteJID];
 	}
	
}

-(void) displayNoteAtRow:(RekeyRow*)row note:(NSString*)cellString color:(UIColor*) color
{
    UITableViewCell *cell = [self cellForRow: row];
    NSUInteger rowIndex = [self.rows indexOfObject: row];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow: rowIndex inSection: 0];
    CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    CGRect rectInSuperview = [self.tableView convertRect:cellRect toView:[self.tableView superview]];
    
    UIFont *font = [UIFont boldSystemFontOfSize:14];
   
    CGRect aRect = { {0,0}, [cellString sizeWithFont:font forWidth:rectInSuperview.size.width lineBreakMode:NSLineBreakByWordWrapping]};
    aRect.size.height = aRect.size.height *2;
    aRect.origin.x = aRect.size.height / 2;
    
    UILabel *SASlabel = [[UILabel alloc] initWithFrame:aRect];
    
    SASlabel.text = cellString;
    SASlabel.textColor = [UIColor blackColor];
    SASlabel.font = font;
    SASlabel.textAlignment = UITextAlignmentCenter;
    SASlabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    SASlabel.adjustsFontSizeToFitWidth = YES;
    SASlabel.layer.cornerRadius = 5.0;
    SASlabel.backgroundColor =  color;
    
    SASlabel.center = cell.center;
    CGRect frame = SASlabel.frame;
    
    SASlabel.frame = CGRectMake(rectInSuperview.origin.x, rectInSuperview.origin.y, frame.size.width, frame.size.height);
    
    [self.view insertSubview:SASlabel belowSubview:self.textEntryView];
    
    [UIView animateWithDuration:0.25f
                     animations:^{
                         [SASlabel setAlpha:1.0];
                     }
                     completion:^(BOOL finished) {
                         [UIView animateWithDuration:0.5f
                                               delay:1.5
                                             options:0
                                          animations:^{
                                              [SASlabel setAlpha:0.0];
                                              
                                          }
                                          completion:^(BOOL finished) {
                                              [SASlabel removeFromSuperview];
                                          }];
                     }];
    
    
}


- (void) tappedCell:  (id<ChatViewRow>) row
{
  
	if ([row isKindOfClass: MissiveRow.class]) {
		
		Missive *missive = [(MissiveRow *)row missive];
		
		if(missive && missive.siren && missive.siren.cloudLocator && missive.siren.cloudKey)
		{
            SCloudViewController *svc;
            
            if([NSLayoutConstraint class])
            {
    			svc = [SCloudViewController.alloc initWithNibName: @"SCloudViewController" bundle: nil];
            }
			else
            {
    			svc = [SCloudViewController.alloc initWithNibName: @"SCloudViewControllerIOS5" bundle: nil];
            }
            
			NSArray* missives = [App.sharedApp.conversationManager missivesWithScloud: missive.conversation];
			
			svc.conversation = missive.conversation;
			svc.missives = missives;
			svc.itemIndex = [missives indexOfObject: missive];
			
			[self.textView resignFirstResponder];
			[self.navigationController pushViewController: svc animated: YES];
		}
        if(missive && missive.siren && missive.siren.vcard )
        {
            NSString* vcard = missive.siren.vcard;

            // handle vcard            
            SCAddressBookController* abc = [[SCAddressBookController alloc] init];
            [self.navigationController pushViewController: abc animated: YES];
            
            [abc  showContactForVCard:vcard];
       }
 	}
    else if ([row isKindOfClass: RekeyRow.class]) {
        
        SCimpLogEntry* logEntry = [(RekeyRow *)row logEntry];
        NSDictionary *info = logEntry.info;
        NSNumber *number = nil;
        
        NSString* logType =  [info valueForKey:kSCimpLogEntryType];
        
        if([logType isEqualToString:kSCimpLogEntrySecure])
        {

            NSString *SAS  = [info valueForKey:kSCIMPInfoSAS];
//            BOOL has_secret = [[info valueForKey:kSCIMPInfoHasCS] boolValue];
//            BOOL secrets_match = [[info valueForKey:kSCIMPInfoCSMatch] boolValue];
//            
            NSString *cellString = [NSString stringWithFormat:@" SAS: %@ ", SAS];
            
               [self displayNoteAtRow:row note:cellString color: self.conversation.keyVerifiedFlag
                                ?[UIColor greenColor]
                                :[UIColor colorWithRed:1.0 green:.8 blue:0 alpha:.8]];
        
   
        }
        if([logType isEqualToString:kSCimpLogEntryTransition])
        {
          ConversationState state = kSCimpState_Init;
             
            if ((number = [info valueForKey:kSCIMPInfoTransition])) {
                state = number.unsignedIntValue;
            }
           
            if(state == kConversationState_Commit
               || state == kConversationState_DH1
               || state == kConversationState_DH2
               || state == kConversationState_Confirm)
            {
                [self displayNoteAtRow:row note:NSLS_COMMON_KEYING_INFOMRATIONAL color:[UIColor colorWithRed:1.0 green:.8 blue:0 alpha:.8]];
  
            }
            else if(state == kConversationState_Error)
            {
                [self resetKeysNow:self.view];
            }
            
        }
        
        else if([logType isEqualToString:kSCimpLogEntryError])
        {
            [self resetKeysNow:self.view];
         }
      }
}

- (void) tappedAvatar:  (id<ChatViewRow>) row
{
	if ([row isKindOfClass: MissiveRow.class]) {
		
		Missive *missive = [(MissiveRow *)row missive];
		
		if(missive )
		{
			NSString *localJIDStr   = missive.conversation.localJID;
            XMPPJID* avatarJID = [[[XMPPJID jidWithString:missive.toJID]bare] isEqualToString: localJIDStr]
            ?self.remoteJID : [XMPPJID jidWithString: localJIDStr];
            
            SCAddressBookController* abc = [[SCAddressBookController alloc] init];
            [self.navigationController pushViewController: abc animated: YES];

  				if( [ avatarJID.bareJID isInAddressBook] )
                {
 					[abc  showContactForJID:avatarJID.bareJID];
                }
                else
                {
                    [abc createContactWithJID:avatarJID];

				}
 		}
	}
}

- (void) tappedGeo: (id<ChatViewRow>) row
{
	//	if (self.mapView.hidden) {
	Missive *missive = [(MissiveRow *)row missive];
	NSError *jsonError;
	
	NSDictionary *locInfo = [NSJSONSerialization
							 JSONObjectWithData:[missive.siren.location dataUsingEncoding:NSUTF8StringEncoding]
							 options:0 error:&jsonError];
	
	if (jsonError==nil){
		
		double latitude  =  [[locInfo valueForKey:@"latitude"]doubleValue];
		double longitude  = [[locInfo valueForKey:@"longitude"]doubleValue];
		double altitude  =  [[locInfo valueForKey:@"altitude"]doubleValue];
		CLLocationCoordinate2D theCoordinate;
		theCoordinate.latitude = latitude;
		theCoordinate.longitude = longitude;
		//			[self setMapToCoords:theCoordinate];
		[self.textView resignFirstResponder];
		GeoViewController *geovc = [GeoViewController.alloc initWithNibName: @"GeoViewController" bundle: nil];
		
		[self.navigationController pushViewController: geovc animated: YES];
		
		XMPPJID *remoteJid = [XMPPJID jidWithString: missive.conversation.remoteJID];
		XMPPJID *toJid = [XMPPJID jidWithString: missive.toJID];
		XMPPJID* ownerJid = [toJid.bare isEqualToString:remoteJid.bare]?App.sharedApp.currentJID:remoteJid;
		
		[geovc setCoord: theCoordinate withName: [XMPPJID userNameWithJIDString: [ownerJid bare]]
				andTime:missive.date andAltitude:altitude];
	}
	
	//	}
	//	else
	//		[self hideMap];
}

- (void) resignActiveTextEntryField
{
	[self.textView resignFirstResponder];
}


//#pragma mark - WEPopoverControllerDelegate/UIPopoverControllerDelegate methods.
//
//
//- (void) popoverControllerDidDismissPopover: (WEPopoverController *) popoverController {
//
//    DDGTrace();
//
//    if ([self.popover isEqual: popoverController]) {
//
//        GearContentViewController *gcvc = (GearContentViewController *)popoverController.contentViewController;
//
//        if ([gcvc isKindOfClass: GearContentViewController.class]) {
//
//            self.conversation.fyeo = gcvc.isFyeo;
//            self.conversation.tracking = gcvc.isTracking;
//            self.conversation.shredAfter = gcvc.shredAfter;
//
//            [self updateTrackingStatus];
//
//            [self.conversation.managedObjectContext save];
//        }
//        self.popover = nil;
//    }
//
//} // -popoverControllerDidDismissPopover:
//
//
//- (BOOL) popoverControllerShouldDismissPopover: (WEPopoverController *) popoverController {
//
//    DDGTrace();
//
//    return YES;
//
//} // -popoverControllerShouldDismissPopover:
//

#pragma mark - Chat Options Delegate methods.

- (void) pushChatOptionsViewController
{
	[self.textView resignFirstResponder];
	
    ChatOptionsViewController* covc = [ChatOptionsViewController.alloc initWithNibName: @"ChatOptionsViewController" bundle: nil];
    covc.delegate = self;
 
//	[((UINavigationController *) self.parentViewController) pushViewController: covc animated: YES];
	[self.navigationController pushViewController: covc animated: YES];
	
}


- (BOOL) getPhoneState
{
    // we are now using the JID as a phone number, so actually we they all have phone numbers.
      
  	BOOL state = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"silentphone:"]];
	return(state);
	
}



- (BOOL) getBurnNoticeState;
{
     return(self.conversation.burnFlag);
	
}
- (void) setBurnNoticeState:(BOOL) state;
{
    self.conversation.burnFlag = state;
  	
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
												  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"Dismiss")
												  otherButtonTitles:nil];
		[alertView show];
		
	}
	else {
		self.conversation.tracking = state;
		[self updateTrackingStatus];
		[self.conversation.managedObjectContext save];
	}
}

#if 0
- (BOOL) isLocationInclusionPossible {
	///* MZ-  here is how you tell if the track switch is OK to enable */
	//App *app = App.sharedApp;
	//BOOL enableTrackingSwitch =  (app.geoTracking.allowTracking && app.geoTracking.isTracking);
	
	// if location is not available, then we should tell the user how to make it available.
}
#endif


- (BOOL) getFYEOState;
{
	return self.conversation.fyeo ? YES : NO;
}

- (void) setFYEOState:(BOOL) state;
{
	self.conversation.fyeo = state;
	[self.conversation.managedObjectContext save];
}

- (void) resetKeysNow:(UIView *) view;
{
	[self clickResetKeysActionSheet: view];
}

- (BOOL) getAuthenticateState
{
    return self.conversation.keyVerifiedFlag;
}

- (void) setAuthenticateState:(BOOL) state

{
    if(!self.conversation.keyedFlag) return;
    
    self.conversation.keyVerifiedFlag = state;
    
    [self.conversation.managedObjectContext save];
    
   }

- (NSDictionary*) getSecureContextInfo
{
    NSDictionary* info =  [App.sharedApp.conversationManager secureContextInfoForJid:self.remoteJID];
  
    return info;
}


- (void) chatOptionsPress:(id)sender {
	
	if ([self.cov superview]) {
		[self.cov fadeOut];
		return;
	}
	
	if (!self.cov)
		[[NSBundle mainBundle] loadNibNamed:@"ChatOptionsView" owner:self options:nil];
	cov.delegate = self;
	//	[self.cov unfurlOnView:self.view atPoint:CGPointMake(17.5, self.textEntryView.frame.origin.y)];
	[self.cov unfurlOnView:self.entryContainerView under:self.textEntryView atPoint:CGPointMake(17.5, self.textEntryView.frame.origin.y)];
}

-(void) recordAudio
{
    [self.textView resignFirstResponder];
	if (self.cov)
		[self.cov hide];
    if ([self.aiv superview]) {
		[self.aiv fadeOut];
		return;
	}
	
	if (!self.aiv)
		[[NSBundle mainBundle] loadNibNamed:@"STAudioView" owner:self options:nil];
    
	self.aiv.delegate = self;
    
  	[self.aiv unfurlOnView:self.view under:self.textEntryView atPoint:CGPointMake(17.5, self.textEntryView.frame.origin.y)];
 }


#pragma mark - map methods.
//- (void) hideMap
//{
//	self.mapView.hidden = YES;
//}
//
//- (void) setMapToCoords:(CLLocationCoordinate2D)coordinate
//{
//	
//#pragma warning Commented out  mapView for now
//	// commented out for now
//	//    self.mapView.hidden = YES;
//	//    return;
//	
//	
//	self.mapView.hidden = NO;
//	// I'd like to add a pin here on the coordinates, but how exact do we want to be in locating the sender?  Are there security concerns?  Should we also set coordinates on a dozen other values, all precaluclated around various unrestful hotspots so that we confuse any eavesdroppers?
//	// we need to warn users that sending a location to another, is secure in transit, but may not be secure once the other side maps it
//	// another scenario is to track the senders movement via a path - but tht would give us an idea where the sender would be in the future (based on direction and speed of travel.
//	[self.mapView setCenterCoordinate:coordinate animated:YES];
//	ChatSenderMapAnnotation *dropPin = [[ChatSenderMapAnnotation alloc] init];
//	dropPin.coordinate = coordinate;
//	[self.mapView addAnnotation:dropPin];
//	MKCoordinateRegion mapRegion;
//	mapRegion.center = coordinate;
//	mapRegion.span = MKCoordinateSpanMake(0.2, 0.2);
//	[self.mapView setRegion:mapRegion animated: YES];
//
//	
//}

#pragma mark - ConversationManagerDelegate methods.

- (void)conversationmanager:(ConversationManager *)sender didUpdateRemoteJID:(XMPPJID *)remoteJID
{
	_remoteJID = remoteJID;
	
}

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
			
			
		case kConversationState_Error:
			msg = NSLS_COMMON_KEYS_ERROR;
			break;
			
		case kConversationState_Ready:
		case kConversationState_Init:
		default:  ;
	}
	
	if(msg)
		[self displayMessageBannerFrom:name message:msg withIcon:App.sharedApp.bannerImage];
	
    // update the key in navigation
  //  [self configureNavigationItem];
}


- (void)conversationmanager:(ConversationManager *)sender didReceiveSirenFrom:(XMPPJID *)from siren:(Siren *)siren
{
	if([from isEqualToJID:self.remoteJID options:XMPPJIDCompareBare])
	{
		self.conversation.notRead = 0;
		return;
	}
	
	NSString *name = [from addressBookName];
	name = name && ![name isEqualToString: @""] ? name : [from user];
	
    
    if(siren.requestBurn)
    {
        [self displayMessageBannerFrom:name message:NSLS_COMMON_MESSAGE_REDACTED withIcon:[UIImage imageNamed:@"flame_btn"]];
        
    }
    else if(siren.message)
    {
        [self displayMessageBannerFrom:name message:siren.message withIcon:App.sharedApp.bannerImage];
    }
	[self updateBackBarButton];
	
}


#pragma mark - SCAddressBookController methods.
- (void) didFinishPickingWithScloud: (SCloudObject*) scloud name:(NSString*)name image:(UIImage*)image
{
    UIImage* cardImage = [UIImage imageNamed:@"vcard@2x"];   // we always use this image for alignment
    UIImage* personImage = image?image:[UIImage imageNamed:@"defaultPerson"];
    
    UIGraphicsBeginImageContext(CGSizeMake(122, 94));
    [cardImage drawInRect:CGRectMake(0, 0, 122, 94)];
    [personImage drawInRect:CGRectMake(16, 15, 52, 51)];
    
    cardImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    scloud.thumbnail = cardImage;
    
    [self didFinishPickingMediaWithScloud:scloud];
    
}

#pragma mark - STMediaController methods


- (void) mediaPickingError:(NSError *)error
{
	
	
	UIAlertView *alert = [[UIAlertView alloc]
						  initWithTitle: NSLocalizedString(@"Save failed", @"Save failed")
						  message: error.localizedDescription
						  delegate: nil
						  cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
						  otherButtonTitles:nil];
	[alert show];
	
}


- (void) didFinishPickingMediaWithScloud: (SCloudObject*) scloud
{
	App *app = App.sharedApp;
	
	[self updateTrackingStatus];

	UIImage* thumbnail = [scloud thumbnail];
	if(thumbnail)
	{
		NSData *imageData = UIImageJPEGRepresentation(thumbnail, 0.4);
		uint32_t burnDelay = kShredAfterNever;
		
		Siren *siren = Siren.new;
		siren.conversationID = self.conversation.scppID;
		siren.mediaType = scloud.mediaType;
		siren.thumbnail = imageData;
		siren.cloudKey  =  scloud.keyString;
		siren.cloudLocator =  scloud.locatorString;		
		siren.fyeo           = self.conversation.isFyeo;
		
		if(self.getBurnNoticeState)
		{
			burnDelay =  self.getBurnNoticeDelay;
			siren.shredAfter = burnDelay;
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
		
		// simulate user hitting send key
		[self performSelector:@selector(sendSCloudwithSiren:) withObject:siren afterDelay:0];
		
	}
}

-(void) sendSCloudwithSiren: (Siren*) siren
{
	App *app = App.sharedApp;
	
	if(siren && siren.cloudLocator )
	{
		SCloudObject *scloud = [SCloudObject.alloc  initWithLocatorString:siren.cloudLocator
                                                                keyString:siren.cloudKey];
		
		self.HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
		self.HUD.mode = MBProgressHUDModeIndeterminate;
		self.HUD.labelText = NSLocalizedString(@"Starting Upload…", @"Starting Upload…");
		
		[self.conversation addSirenToUpload:siren];
        [app.scloudManager startUploadWithDelagate:self
                                            scloud:scloud
                                         burnDelay:siren.shredAfter
                                             force:NO];
	}
}

#pragma mark - STAudioRecordDelegate methods


- (void)didFinishRecordingAudioWithError:(NSError *)error scloud:(SCloudObject*) scloud
{
    if(!error)
    {
        [self didFinishPickingMediaWithScloud:scloud];
    }
    else
    {
        
        
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle: NSLocalizedString(@"Recording failed",@"Recording failed")
                              message: error.localizedDescription
                              delegate: nil
                              cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                              otherButtonTitles:nil];
        [alert show];

    }
}


#pragma mark - SCloudManagerDelegate methods
- (void)SCloudBrokerDidCompleteWithError:(NSError *)error scloud:(SCloudObject*) scloud
{
     if(error)
	{
        [self SCloudUploadDidCompleteWithError: error scloud:scloud];
        
    }
  
}

- (void)SCloudUploadDidStart:(SCloudObject*) scloud
{
    _HUD.mode = MBProgressHUDModeIndeterminate;

}

- (void)SCloudUploading:(SCloudObject*) scloud totalBytes:(NSNumber*)totalBytes
{
	// TODO: NSLocalizedString
    _HUD.labelText =  [NSString stringWithFormat:@"Uploading %@ file…", [totalBytes fileSizeString]];
    
    _HUD.mode = MBProgressHUDModeDeterminate;

}

- (void)SCloudUploadProgress:(float)progress scloud:(SCloudObject*) scloud
{
//    NSLog(@"Progess %0.2f", progress);
	
	_HUD.progress = progress;
	
}

-(void) removeProgress
{
	
	[self.HUD removeFromSuperview];
	self.HUD = nil;
	
}

- (void)SCloudUploadDidCompleteWithError:(NSError *)error scloud:(SCloudObject*) scloud
{
	if(error)
	{
		[self removeProgress];
        
        Siren *siren = [self.conversation findSirenFromUploads:scloud.locatorString];
        
		MZAlertView *alert = [[MZAlertView alloc]
							  initWithTitle: NSLocalizedString(@"Upload failed",@"Upload failed")
							  message: error.localizedDescription
							  delegate: self
							  cancelButtonTitle:NSLocalizedString(@"Cancel",@"Cancel")
							  otherButtonTitles:NSLocalizedString(@"Try Again",@"Try Again"), NSLocalizedString(@"Send Anyways",@"Send Anyways"), nil];
 
		[alert show];
		
        [alert setActionBlock: ^(NSInteger buttonPressed, NSString *alertText){
            switch(buttonPressed)
            {
                case 1:
                {
                    App *app = App.sharedApp;
                    
                    [app.scloudManager startUploadWithDelagate:self
                                                        scloud:scloud
                                                     burnDelay:siren.shredAfter
                                                         force:NO];

                }
   
                 break;
                    
                case 2:
                {
                    if(siren)
                    {
                        XMPPMessage *xmppMessage = [siren chatMessageToJID: self.remoteJID];
                        if (xmppMessage) {
                            
                            Missive *missive = [self insertMissiveForXMPPMessage: xmppMessage remoteJid:self.remoteJID];
                            
                            [missive.managedObjectContext save];
                            [self.xmppStream sendElement: xmppMessage];
                        }
                    }

                }
                    break;
                    
                default:
                    [self.conversation removeSirenFromUpload:scloud.locatorString];

            }
                
        }];
        [alert show];

	}
	else
	{
		
		_HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
		_HUD.mode = MBProgressHUDModeCustomView;
		_HUD.labelText = NSLocalizedString(@"Completed",@"Completed");
		
		[self performSelector:@selector(removeProgress) withObject:NULL afterDelay:2.0];
		
		Siren *siren = [self.conversation findSirenFromUploads:scloud.locatorString];
		if(siren)
		{
			XMPPMessage *xmppMessage = [siren chatMessageToJID: self.remoteJID];
			
			if (xmppMessage) {
				
				Missive *missive = [self insertMissiveForXMPPMessage: xmppMessage remoteJid:self.remoteJID];
				
				[missive.managedObjectContext save];
				[self.xmppStream sendElement: xmppMessage];
			}
		}
        
        [self.conversation removeSirenFromUpload:scloud.locatorString];

	}

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



#pragma mark - Local Notifcation.


#pragma mark - Registration methods.


- (ChatViewController *) registerForXMPPStreamDelegate {
	
//	DDGTrace();
	
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
	[self scrollToBottom: YES];
	
	//
	//    [self logKeyboardNotification: notification];
//	[self.cov fadeOut];
	
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
	if (_skipFirstKeyboardNotification)
		_skipFirstKeyboardNotification = NO;

	//
	//    [self logKeyboardNotification: notification];
//	[self.cov fadeOut];
	
} // -keyboardWillHide:


#define kKeyboardDidHide  (@selector(keyboardDidHide:))
- (void) keyboardDidHide: (NSNotification *) notification {
	DDGTrace();
	//
	//    [self logKeyboardNotification: notification];
	
} // -keyboardDidHide:


#define kKeyboardWillChangeFrame  (@selector(keyboardWillChangeFrame:))
- (void) keyboardWillChangeFrame: (NSNotification *) notification {
	if (_skipFirstKeyboardNotification)
		return;
	if (_dontChangeKeyboardOrGrowingTextWhileSending) {
		return;	// this is for accepting suggested correction/completion
	}
	if (![self.textView isFirstResponder] && !_keyboardIsActive)		// write this like this:  if (!([self.textView isFirstResponder] || _keyboardIsActive))  more understandable?
		return;
	
	_keyboardIsActive = !_keyboardIsActive;
	
	

//    [UIView animateWithDuration:duration animations:^{
//        self.backgroundView.frame = frame;
//    }];
	NSDictionary *userInfo = notification.userInfo;
	UIViewAnimationCurve curve = [[userInfo valueForKey: UIKeyboardAnimationCurveUserInfoKey] integerValue];
	NSTimeInterval duration = [[userInfo valueForKey: UIKeyboardAnimationDurationUserInfoKey] doubleValue];
//    CGRect endFrame;
//    [[userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue:&endFrame];
	CGRect endRect = [[userInfo valueForKey: UIKeyboardFrameEndUserInfoKey]   CGRectValue];
	CGRect beginRect = [[userInfo valueForKey: UIKeyboardFrameBeginUserInfoKey] CGRectValue];

//	NSLog(@"begin rect: %@ end rect: %@", NSStringFromCGRect(beginRect), NSStringFromCGRect(endRect));
//    endFrame = [self.view convertRect:endFrame fromView:nil];
	endRect = [self.backgroundView convertRect: endRect fromView: nil];
	beginRect = [self.backgroundView convertRect: beginRect fromView: nil];
//	NSLog(@"begin rect: %@ end rect: %@", NSStringFromCGRect(beginRect), NSStringFromCGRect(endRect));

    float y = (endRect.origin.y > self.view.bounds.size.height ? self.view.bounds.size.height : endRect.origin.y);

	CGRect frame = self.backgroundView.frame;
	
	frame.size.height = y;
	if (_noKeyboardAnimation) {
		self.backgroundView.frame = frame;
	}
	else {
		[UIView animateWithDuration: duration
							  delay: 0.0
							options: curve // << kAnimationOptionCurveShift
						 animations: ^{ self.backgroundView.frame = frame; }
						 completion: ^(BOOL finished){  }];
	}
//	[self logKeyboardNotification: notification];
//
//	NSDictionary *userInfo = notification.userInfo;
//	
//	CGRect beginRect = [[userInfo valueForKey: UIKeyboardFrameBeginUserInfoKey] CGRectValue];
//	CGRect endRect = [[userInfo valueForKey: UIKeyboardFrameEndUserInfoKey]   CGRectValue];
//	UIViewAnimationCurve curve = [[userInfo valueForKey: UIKeyboardAnimationCurveUserInfoKey] integerValue];
//	NSTimeInterval duration = [[userInfo valueForKey: UIKeyboardAnimationDurationUserInfoKey] doubleValue];
//	
//	App *app = App.sharedApp;
////	NSLog(@"begin rect: %@ end rect: %@", NSStringFromCGRect(beginRect), NSStringFromCGRect(endRect));
////	beginRect = [app.window convertRect: beginRect fromWindow: nil]; // Convert from the screen to the window.
////	endRect = [app.window convertRect: endRect fromWindow: nil]; // Convert from the screen to the window.
////	NSLog(@"begin rect: %@ end rect: %@", NSStringFromCGRect(beginRect), NSStringFromCGRect(endRect));
////	beginRect = [app.window convertRect: beginRect fromWindow: app.window]; // Convert from the screen to the window.
////	endRect = [app.window convertRect: endRect fromWindow: app.window]; // Convert from the screen to the window.
//	NSLog(@"begin rect: %@ end rect: %@", NSStringFromCGRect(beginRect), NSStringFromCGRect(endRect));
//	beginRect = [self.backgroundView convertRect: beginRect fromView: nil];
//	endRect = [self.backgroundView convertRect: endRect fromView: nil];
//	NSLog(@"begin rect: %@ end rect: %@", NSStringFromCGRect(beginRect), NSStringFromCGRect(endRect));
//	
//	//DDGDesc(NSStringFromCGRect(beginRect));
//	
//	
//	CGRect frame = self.backgroundView.frame;
//	
//	frame.size.height += beginRect.origin.y > endRect.origin.y ? -endRect.size.height : endRect.size.height;
//	
//	const NSInteger kAnimationOptionCurveShift = 16; // Magic number copied out of the UIView headers.
//	
//	[UIView animateWithDuration: duration
//						  delay: 0.0
//						options: curve << kAnimationOptionCurveShift
//					 animations: ^{ self.backgroundView.frame = frame; }
//					 completion: ^(BOOL finished){ [self scrollToBottom: YES]; }];
	
} // -keyboardWillChangeFrame:


#define kKeyboardDidChangeFrame  (@selector(keyboardDidChangeFrame:))
- (void) keyboardDidChangeFrame: (NSNotification *) notification {
	
	//    DDGTrace();
	
	//    [self logKeyboardNotification: notification];
	
} // -keyboardDidChangeFrame:


- (ChatViewController *) registerForNotifications {
	
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	[nc removeObserver: self];
	
	[nc addObserver: self
		   selector:@selector(handleDataModelChange:)
			   name:NSManagedObjectContextObjectsDidChangeNotification
			 object:self.conversation.managedObjectContext];
	
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
