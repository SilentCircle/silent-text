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
#import "ConversationDetailsVC.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "AvatarManager.h"
#import "ConversationSecurityVC.h"
#import "GeoTracking.h"
#import <MapKit/MapKit.h>
#import "OHActionSheet.h"
#import "SCCalendar.h"
#import "SCDateFormatter.h" 
#import "SCTAvatarView.h"
#import "SCTHelpButton.h"
#import "SCTHelpManager.h"
#import "SCTTextCopyLabel.h"
#import "SilentTextStrings.h"
#import "STConversation.h"
#import "STDynamicHeightView.h"
#import "STLocalUser.h"
#import "STLogging.h"
//#import "SCimpWrapper.h"
#import "SCMapImage.h"

#import "NewGeoViewController.h"

// Categories
#import "MKMapView+SCUtilities.h"
#import "NSDate+SCDate.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG && eric_turner
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

/*
 *
 * NOTE: all string localizations for Conversations Details classes titles and Help are in 
 * ConversationsDetailsHelp.strings
 *
 */

#pragma mark - Share Location Constants
// Share Location Options enum
typedef NS_ENUM(NSInteger, SC_ShareLocationOption) 
{
    shrLoc_off = -1,    // dateForShareLocationOption returns an "Off" date value for shrLoc_off
    shrLoc_oneHour,     // actionSheet 1st option button index (NO destructiveButton)
    shrLoc_endOfDay,    // actionSheet 2nd option button index
    shrLoc_indefinitely // actionSheet 3rd option button index
};

// Share Location ActionSheet
static NSString * const kShareLoc_titleKey         = @"shareLocation-action.title";
static NSString * const kShareLoc_stopKey          = @"shareLocation-actionTitle.stop";
static NSString * const kShareLoc_oneHourKey       = @"shareLocation-actionTitle.oneHour";
static NSString * const kShareLoc_endOfDayKey      = @"shareLocation-actionTitle.endOfDay";
static NSString * const kShareLoc_indefinitelyKey  = @"shareLocation-actionTitle.indefinitely";
#define kShareLocAction_title             [SCTHelpManager stringForKey:kShareLoc_titleKey inTable:SCT_CONVERSATION_DETAILS_HELP]
#define kShareLocActionTitle_stop         [SCTHelpManager stringForKey:kShareLoc_stopKey inTable:SCT_CONVERSATION_DETAILS_HELP]
#define kShareLocActionTitle_oneHour      [SCTHelpManager stringForKey:kShareLoc_oneHourKey inTable:SCT_CONVERSATION_DETAILS_HELP]
#define kShareLocActionTitle_endOfDay     [SCTHelpManager stringForKey:kShareLoc_endOfDayKey inTable:SCT_CONVERSATION_DETAILS_HELP]
#define kShareLocActionTitle_indefinitely [SCTHelpManager stringForKey:kShareLoc_indefinitelyKey inTable:SCT_CONVERSATION_DETAILS_HELP]

// Share Location option label strings
static NSString * const kShareLocLbl_notSharingKey   = @"shareLocation-optionLabel.notSharing";
static NSString * const kShareLocLbl_indefinitelyKey = @"shareLocation-optionLabel.indefinitely";
static NSString * const kShareLocLbl_shareUntilKey   = @"shareLocation-optionLabel.shareUntil %@";
#define kShareLocation_notSharing   [SCTHelpManager stringForKey:kShareLocLbl_notSharingKey inTable:SCT_CONVERSATION_DETAILS_HELP]
#define kShareLocation_indefinitely [SCTHelpManager stringForKey:kShareLocLbl_indefinitelyKey inTable:SCT_CONVERSATION_DETAILS_HELP]
// Localized Share Until ... strDate
static NSString *shareLocationUntilString(NSString *strDate) {
    NSString *localizedString = NSLocalizedStringFromTable(kShareLocLbl_shareUntilKey, 
                                                           SCT_CONVERSATION_DETAILS_HELP, 
                                                           @"Share my location until {date/time string}");
    NSString *str = [NSString stringWithFormat:localizedString, strDate];
    return str;
}


#pragma mark - Do Not Disturb Constants
typedef NS_ENUM(NSInteger, SC_DoNotDisturbOption) 
{
    dnd_off = -1,    // dateForDoNotDisturbOption returns an "Off" date value for dnd_off
    dnd_oneHour,     // actionSheet 1st option button index (NO destructiveButton)
    dnd_eightAM,     // actionSheet 2nd option button index
    dnd_indefinitely // actionSheet 3rd option button index
};

// Do Not Disturb ActionSheet
static NSString * const kDND_titleKey         = @"dnd-action.title";
static NSString * const kDND_indefinitelyKey  = @"dnd-action.indefinitely";
static NSString * const kDND_oneHourKey       = @"dnd-action.oneHour";
static NSString * const kDND_until8amKey      = @"dnd-action.until8am";
#define kDNDAction_title             [SCTHelpManager stringForKey:kDND_titleKey inTable:SCT_CONVERSATION_DETAILS_HELP]
#define kDNDActionTitle_indefinitely [SCTHelpManager stringForKey:kDND_indefinitelyKey inTable:SCT_CONVERSATION_DETAILS_HELP]
#define kDNDActionTitle_oneHour      [SCTHelpManager stringForKey:kDND_oneHourKey inTable:SCT_CONVERSATION_DETAILS_HELP]
#define kDNDActionTitle_until8am     [SCTHelpManager stringForKey:kDND_until8amKey inTable:SCT_CONVERSATION_DETAILS_HELP]

// Do Not Disturb option label strings
static NSString * const kDNDLbl_offKey = @"dnd-optionLabel.off";
static NSString * const kDNDLbl_indefinitelyKey = @"dnd-optionLabel.indefinitely";
static NSString * const kDNDLbl_untilTimeKey   = @"dnd-optionLabel.untilTime %@";
#define kDND_off [SCTHelpManager stringForKey:kDNDLbl_offKey inTable:SCT_CONVERSATION_DETAILS_HELP]
#define kDND_indefinitely [SCTHelpManager stringForKey:kDNDLbl_indefinitelyKey inTable:SCT_CONVERSATION_DETAILS_HELP]
// Do Not Disturb Until ... strDate
static NSString *doNotDisturbUntilString(NSString *strDate) {
    NSString *localizedString = NSLocalizedStringFromTable(kDNDLbl_untilTimeKey, 
                                                           SCT_CONVERSATION_DETAILS_HELP, 
                                                           @"Until {date/time string}");
    NSString *str = [NSString stringWithFormat:localizedString, strDate];
    return str;
}




#pragma mark - Map Class
@interface COVUserMapAnnotation : NSObject <MKAnnotation>

@property (nonatomic)         CLLocationCoordinate2D coordinate;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSDate *date;
@property  double             altitude;
@property (strong, nonatomic) UIImage *image;

@end


@implementation COVUserMapAnnotation

- (NSString *)title
{
    return _name;
}

// optional
- (NSString *)subtitle
{
    NSDateFormatter*  formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
                                                                    timeStyle:NSDateFormatterShortStyle];
    return  [formatter stringFromDate:_date] ;
}

@end;


#pragma mark - ConversationDetailsVC Class

@interface ConversationDetailsVC () <UINavigationControllerDelegate>

@property (nonatomic, weak) IBOutlet UIView *conversationInfoView;

@property (nonatomic, weak) IBOutlet UIButton *btnClearConversation;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *btnClearTopConstraint;

// Send Read Receipts
@property (nonatomic, weak) IBOutlet UILabel *lblReadReceipts;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *lblReadReceiptsTopSpaceConstraint;
@property (nonatomic, weak) IBOutlet UISegmentedControl *swReadReceipts;

- (BOOL)sendReadReceipts;
- (void)setSendReadReceipts:(BOOL)yesno;
- (IBAction)handleReadReceiptsSwitch:(UISegmentedControl *)segCon;

// Share Location
@property (nonatomic, weak) IBOutlet UITapGestureRecognizer *grTapShareLocOptions;
@property (nonatomic, weak) IBOutlet UILabel *lblShareLocation;
@property (nonatomic, weak) IBOutlet UILabel *lblShareLocOption;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *lblShareLocTopSpaceConstraint;
@property (nonatomic, weak) IBOutlet UISegmentedControl *swShareLocation;

// DND Notifications
@property (nonatomic, weak) IBOutlet UITapGestureRecognizer *grTapDNDOptions;
@property (nonatomic, weak) IBOutlet UILabel *lblDND;
@property (nonatomic, weak) IBOutlet UILabel *lblDNDSelectedOption;
@property (nonatomic, weak) IBOutlet UISegmentedControl *swDND;

- (BOOL)doNotDisturbIsOn;
- (BOOL)canDelayNotifications;
- (IBAction)handleDoNotDisturbTap:(id)sender;
- (void)presentDoNotDisturbOptions;

- (NSDate *)getNotificationTime;
- (void)setNotificationTime:(NSDate*)date;


// Clear Conversation
@property (nonatomic, weak) IBOutlet UIButton *clearButton;
- (IBAction)clearButtonAction:(id)sender;

// Map
@property (nonatomic) BOOL hasMap;
@property (nonatomic, strong) NSMutableArray  *dropPins;
@property (nonatomic, strong) IBOutlet MKMapView *mapView; // strong to support moving around

@end


@implementation ConversationDetailsVC


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init & Dealloc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Note: the viewDidLoad is called when the super intializer loads the avatarView. Therefore, configuration to
// the avatarView, e.g. showInfoButton attributes, cannot be done in viewDidLoad, but here after super returns self.
- (instancetype)initWithProperNib
{
    self = [super initWithProperNib];
    _dropPins = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    DDLogAutoTrace();
    self.navigationController.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
	DDLogAutoTrace();
    
    // Set this flag before calling super
    self.loadAvatarViewFromNib = YES;

    if (self.navigationController.navigationBar.isTranslucent)
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    // Call super to initialize and layout scrollview
    [super viewDidLoad];
    
    // Self nav title
    self.navigationItem.title = NSLocalizedString(@"Conversation Details", @"Conversation Details");
    
    // Map
    _mapView.hidden = YES;
    _mapIcon.hidden = YES;
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self 
                                                                                action:@selector(handleMapTap:)];
    singleTap.numberOfTapsRequired = 1;
    singleTap.numberOfTouchesRequired = 1;
    [_mapIcon addGestureRecognizer:singleTap];
    [_mapIcon setUserInteractionEnabled:NO];
  
    [self.avatarView showInfoButtonForClass:[self class]];
    
    if (self.conversation.isFakeStream)
        [self layoutForSystemConversation];
    else
        [self updateAllViews];
}


#pragma mark - System Message Layout
// Collapse/hide infoViewH and mapImageView
- (void)layoutForSystemConversation
{
    // Collapse conversationInfoView
    NSLayoutConstraint *infoViewH = [self heightConstraintFor:_conversationInfoView];
    infoViewH.constant = 0;
    _conversationInfoView.hidden = YES;
        
    // Collapse/hide mapIcon
    NSLayoutConstraint *mapIconH = [self heightConstraintFor:_mapIcon];
    mapIconH.constant = 0;
    _mapIcon.hidden = YES;
    [_mapIcon setUserInteractionEnabled:NO];


    // Hide AvatarView info/Help button
    self.avatarView.btnHelpInfo.hidden = YES;
        
    // Reposition Clear Conversation button
    CGRect btnFrame = _btnClearConversation.frame;
    btnFrame.origin.y = self.avatarContainerView.frame.size.height + _btnClearTopConstraint.constant;
    _btnClearConversation.frame = btnFrame;
    
    // Resize contentView
    CGSize contentViewIntrinsicSize = [self.contentView intrinsicContentSize];
    [self.contentView invalidateIntrinsicContentSize];    
    CGRect contentViewFrame = self.contentView.frame;    
    contentViewFrame.size.height = contentViewIntrinsicSize.height;
    self.contentView.frame = contentViewFrame;
    [self.contentView setNeedsUpdateConstraints];
    [self.contentView layoutIfNeeded];
    
    // Resize containerView
    self.containerView.frame = contentViewFrame;
    [self.containerView setNeedsUpdateConstraints];
    [self.containerView layoutIfNeeded];

    // Resize scrollView
    CGSize scrollViewContentSize = self.scrollView.contentSize;
    scrollViewContentSize.height = contentViewFrame.size.height;    
    self.scrollView.contentSize = scrollViewContentSize;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView setNeedsUpdateConstraints];
    [self.scrollView layoutIfNeeded];

    
    // Resize rootView if in popover
    if (AppConstants.isIPhone)
        return;

    // Resize rootView
    CGRect viewFrame = self.view.frame;
    [self.view invalidateIntrinsicContentSize];
    viewFrame.size = contentViewFrame.size;
    self.view.frame = viewFrame;
    [self.view setNeedsUpdateConstraints];
    [self.view layoutIfNeeded];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
//    [self resetPopoverSizeIfNeeded];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Update Views
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Updates switches, labels text, and map.
 */
- (void)updateAllViews
{ 
    [super updateAllViews];
    
    [self updateSendReceiptsView];
    [self updateShareLocationView];
    [self updateDoNotDisturbView];
    [self updateMap];
}

/**
 * Sets the swReadReceipts to "Yes/No" per the conversation sendReceipts value.
 * If the conversation is multiCast, i.e. a group conversation, the send read receipts label and switch are hidden
 * and the top space layout constraint set to zero.
 */
- (void)updateSendReceiptsView
{
    // Read Receipts
    _swReadReceipts.selectedSegmentIndex = ([self sendReadReceipts]) ? 1 : 0;    
    if (self.conversation.isMulticast || self.conversation.isFakeStream)
    {
        _lblReadReceipts.hidden = YES;
        _swReadReceipts.hidden = YES;
        _lblReadReceiptsTopSpaceConstraint.constant = 0;
        [_lblReadReceipts setNeedsUpdateConstraints];
    }
}

/**
 * Set Share Location selected option label text and "On/Off" switch position.
 *
 * If the conversation is multiCast, i.e. a group conversation, the `lblShareLocOption` label top vertical space
 * constraint constant is set to zero to fill the space vacated by the hidden Read Receipts view elements.
 *
 * @see updateSendReceiptsView
 */
- (void)updateShareLocationView
{
    // First, check that feature is enabled/available for this network
    _lblShareLocOption.text = [self shareLocationTimeRemainingString];
    _swShareLocation.selectedSegmentIndex = ([self shareLocationIsOn]) ? 1 : 0;
    
    // If multiCast, readReceipts will be hidden (@see updateSendReceiptsView) -
    // here, we collapse the vertical space constraint to pull views up to fill the gap
    if (self.conversation.isFakeStream
        || (self.conversation.isMulticast && _lblShareLocTopSpaceConstraint.constant > 0))
    {
        _lblShareLocTopSpaceConstraint.constant = 0;
        [_lblShareLocation setNeedsUpdateConstraints];
    }
    
    if(self.conversation.isFakeStream)
    {
        _lblShareLocation.hidden = YES;
        _swShareLocation.hidden = YES;
        _lblShareLocOption.hidden = YES;
    }
}


/**
 * Set Do Not Disturb selected option label text and "On/Off" switch position.
 *
 * This feature is not currently available on the Production network; this method displays a "coming soon" message in
 * the `lblDNDSelectedOption` label. If available, the label is set with a string describing DND time remaining, or
 * "no delay".
 *
 * If the conversation is multiCast, i.e. a group conversation, the `lblDNDSelectedOption` label top vertical space
 * constraint constant is set to zero to fill the space vacated by the hidden read receipts view elements.
 *
 * @see updateSendReceiptsView
 */
- (void)updateDoNotDisturbView
{
    // First, check that feature is enabled/available for this network
    if (NO == [self canDelayNotifications])
    {
        UIColor *lightGray = [UIColor lightGrayColor];
        _lblDND.textColor = lightGray;
        _lblDNDSelectedOption.textColor = lightGray;
        _lblDNDSelectedOption.text = NSLocalizedString(@"Do Not Disturb feature coming soon!", 
                                                       @"Do Not Disturb feature coming soon!");
        _swDND.selectedSegmentIndex = 0;
        _swDND.enabled = NO;
    }
    else
    {
        _lblDNDSelectedOption.text = [self doNotDisturbTimeRemainingString];
        _swDND.selectedSegmentIndex = ([self doNotDisturbIsOn]) ? 1 : 0;
    }
    
    if(self.conversation.isFakeStream)
    {
        _lblDNDSelectedOption.hidden = YES;
        _lblDND.hidden = YES;
        _swDND.hidden = YES;
    }

}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Read Receipts Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * @return conversation sendReceipts BOOL value.
 */
- (BOOL)sendReadReceipts
{
	return self.conversation.sendReceipts;
}

/**
 * Updates the database conversation instance with the given BOOL.
 *
 * @param yesno `YES` to enable conversation Send Read Receipts; `NO` to disable.
 */
- (void)setSendReadReceipts:(BOOL)yesno
{
	if ([self sendReadReceipts] != yesno)
	{		
        // Update local conversation object (temporary)
		self.conversation = [self.conversation copy];
		self.conversation.sendReceipts = yesno;
		
		NSString *convoId = self.conversation.uuid;
		NSString *aUserId = self.conversation.userId;
		
		YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
		[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
			STConversation *updatedConversation = [transaction objectForKey:convoId inCollection:aUserId];
			
			updatedConversation = [updatedConversation copy];
			updatedConversation.sendReceipts = yesno;
			
			[transaction setObject:updatedConversation
							forKey:updatedConversation.uuid
					  inCollection:updatedConversation.userId];
		}];
	}
}

/**
 * Handles taps on the Read Receipts switch, with call to setSendReadReceipts.
 *
 * @param segCon The swReadReceipts segmentedControl "switch", configured in IB.
 * @see setSendReadReceipts
 */
- (IBAction)handleReadReceiptsSwitch:(UISegmentedControl *)segCon
{
    [self setSendReadReceipts: (segCon.selectedSegmentIndex == 1) ? YES : NO];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Share Location
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Handles a user tap event to conditionally present Share Location feature options.
 *
 * The Share Location options actionSheet is presented when the `swShareLocation` switch "On" segment is tapped. Note
 * that `swShareLocation` is an instance of `SCTTapDetectSegmentedControl` which fires the UIControlEventTouchDownRepeat
 * control event when a selected segment is tapped again. Additionally, if Share Location is on, a tap on the 
 * `lblShareLocOption` label, which displays the currently selected time interval, also fires this method. 
 * So if the user does not intuit tapping the "selected option" label, tapping the "On" switch will again present the 
 * display options actionSheet.
 *
 * This method may be fired from:
 * - the `grTapShareLocOptions` tap gesture recognizer on `lblShareLocOption` label, configured in IB, and
 * - the `swShareLocation`, an instance of `SCTTapDetectSegmentedControl`, configured in IB. This UISegmentedControl
 *   subclass fires for both UIControlEventValueChanged and UIControlEventTouchDownRepeat UIControlEvents.
 *
 * @param sender The tap gesture recognizer or UISegmentedControl fired by a user tap.
 */
- (IBAction)handleShareLocationTap:(id)sender
{
    BOOL shareLocIsOn = self.conversation.tracking;
    BOOL switchIsOff = (_swShareLocation.selectedSegmentIndex == 0);
    // If switch "NO" tapped from "YES", turn off
    if (sender == _swShareLocation && shareLocIsOn && switchIsOff)
    {
        [self setConversationTrackingUntil:[self dateForShareLocationOption:shrLoc_off]];
        [self updateShareLocationView];
    }
    // grTapShareLoc tap gesture sender, or repeated "On" switch tap
    else if (!switchIsOff)
    {
        [self presentShareLocationOptions];
    }
}

/**
 * Presents actionSheet/Popover with Share Location options and handles actionSheet selection.
 *
 * The completion handler of the presented `OHActionSheet` calls to update the conversation trackUntil with a
 * date for the selected option, if not Canceled.
 *
 * Discussion: the actionSheet button indexes correlate to SC_ShareLocationOption enum values. In the `OHActionSheet` 
 * completion handler, `dateForShareLocationOption:` returns a date for the selected button index. If the
 * actionSheet is not Canceled by the user, the conversation trackUntil property is updated with this date.
 *
 * ## IMPORTANT
 *
 * The shareLocation actionSheet is configured with no destructiveButton. Originally, it was implemented with a
 * "Stop sharing my location" destructiveButton which is now deprecated because it's redundant. The "Off/On" 
 * segmentedControl "switch" allow the feature to turned off without the actionSheet. What's important is that the 
 * SC_ShareLocationOption enum defines values to correlate with the actionSheet button indexes.
 *
 * So if is decided that the actionSheet should be modified to add a destructiveButton, be aware that the 
 * destructiveButtonIndex will be 0, and the enum values will be off by one.
 *
 * Note: `updateShareLocationView` is invoked in the completion handler in all cases. This handles the case in which the
 * `swShareLocation` segmentedControl is "Off", then tapped "On", then the actionSheet Canceled. The update method will
 * reset the control to "Off".
 */
- (void)presentShareLocationOptions
{
    // ET 10/16/14 OHActionSheet update
    [OHActionSheet showFromVC:self
                       inView:self.view
                        title:kShareLocAction_title
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:nil
            otherButtonTitles: @[kShareLocActionTitle_oneHour,
                                kShareLocActionTitle_endOfDay,
                                kShareLocActionTitle_indefinitely]
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
     {
         if (sheet.cancelButtonIndex != buttonIndex)
         {
             NSDate *trackUntilDate = [self dateForShareLocationOption:(SC_ShareLocationOption)buttonIndex];
             [self setConversationTrackingUntil:trackUntilDate];
         }
         
         // see documentation Note above
         [self updateShareLocationView];
     }];
}

/**
 * Sets the local conversation trackUntil property and updates the database conversation object.
 *
 * ET Note: this implementation is different from Vinnie's in MessagesViewController in that there is no 
 * if (self.conversation.tracking != [endDate isAfter:[NSDate date]) condition. Here, the local conversation and 
 * database objects are updated with the endDate value. beginTracking and stopTracking of the GeoTracking singleton is
 * updated in each invocation.
 *
 * 07/26/14 NOTE: As of this first implementation, the trackingUntil date is not persisted in the database. While the 
 * app is running, a user selected Share Location option date value persists even when changing between users and 
 * conversations. However, once the app is completely shut down and restarted, the trackUntil date is always nil.
 *
 * @param endDate The date value with which to update the conversation trackUntil property.
 */
- (void)setConversationTrackingUntil:(NSDate *)endDate
{
    // Update local conversation object (temporary)
    self.conversation = [self.conversation copy];        
    self.conversation.trackUntil = endDate;
        
    if ([endDate isAfter:[NSDate date]])
            [[GeoTracking sharedInstance] beginTracking];
		else
            [[GeoTracking sharedInstance] stopTracking];
        
    NSString *convoId = self.conversation.uuid;
    NSString *aUserId = self.conversation.userId;
    
    YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
    [rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        // Update conversation object in database (non-temporary)
        STConversation *updatedConversation = [transaction objectForKey:convoId inCollection:aUserId];
        
        updatedConversation = [updatedConversation copy];
        
        updatedConversation.trackUntil = endDate;
        
        [transaction setObject:updatedConversation
                        forKey:updatedConversation.uuid
                  inCollection:updatedConversation.userId];
    }];
}

#pragma mark Share Location Accessors

/**
 * Returns a date corresponding to a Share Location option.
 *
 * The `presentShareLocationOptions` actionSheet completion handler updates the conversation trackUntil property
 * with a date returned from this method for a user actionSheet button selection.
 *
 * @param option An SC_ShareLocationOption enum identifier.
 * @return A date value for the given option
 * @see presentDoNotDisturbOptions
 */
- (NSDate *)dateForShareLocationOption:(SC_ShareLocationOption)option
{
    NSDate *date = nil;
    switch (option) {
        
        case shrLoc_off:    // -1 the "Off" date value
            date = [NSDate distantPast];
            break;
            
        case shrLoc_oneHour:
            date = [[NSDate date] dateByAddingTimeInterval:60*60];
            break;
        
        case shrLoc_endOfDay:
            date = [[NSDate date] endOfDay];
            break;
            
        case shrLoc_indefinitely:
            date = [NSDate distantFuture];
            break;
            
        default:
            date = [NSDate distantPast]; 
            break;
    }
    return date;
}

/**
 * @return A string for `lblShareLocationOption` text, used by the `updateShareLocationView` method.
 */
- (NSString *)shareLocationTimeRemainingString
{
    NSString *title = kShareLocation_notSharing;
    if ([self shareLocationIsOn])
    {
        if ([self.conversation.trackUntil isEqualToDate:[NSDate distantFuture]])
        {
            title = kShareLocation_indefinitely;
        }
        else
        {
            title = shareLocationUntilString([self.conversation.trackUntil whenString]);
        }
    }
    return title;
}

- (BOOL)shareLocationIsOn
{
    return ([self.conversation.trackUntil isAfter:[NSDate date]]);
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark - DND Notifications
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark DND Actions

/**
 * Handles a user tap event to conditionally present Do Not Disturb feature options.
 *
 * The DND options actionSheet is presented when the `swDND` "On" segment is tapped. Note that the `swDND` is 
 * an instance of `SCTTapDetectSegmentedControl` which fires the UIControlEventTouchDownRepeat control event when a 
 * selected segment is tapped again. Additionally, if DND is already active, a tap on the `lblDNDSelectedOption` label,
 * which displays the currently selected time interval, also fires this method. 
 * So if the user does not intuit tapping the "selected option" label, tapping the "On" switch will again present the 
 * display options actionSheet.
 *
 * This method may be fired from:
 * - the `grTapDNDOptions` tap gesture recognizer on `lblDNDSelectedOption` label, configured in IB, and
 * - the `swDND`, an instance of `SCTTapDetectSegmentedControl`, configured in IB. This UISegmentedControl
 *   subclass fires for both UIControlEventValueChanged and UIControlEventTouchDownRepeat UIControlEvents.
 *
 * @param sender The tap gesture recognizer or UISegmentedControl fired by a user tap.
 */
- (IBAction)handleDoNotDisturbTap:(id)sender
{
    BOOL dndIsOn = [self doNotDisturbIsOn];
    BOOL switchIsOff = (_swDND.selectedSegmentIndex == 0);
    // If switch "NO" tapped from "YES", turn off
    if (sender == _swDND && dndIsOn && switchIsOff)
    {
        [self setNotificationTime:[self dateForDoNotDisturbOption:dnd_off]];
        [self updateDoNotDisturbView];
    }
    // grTapDNDOptions tap gesture sender, or repeated "On" switch tap
    else if (!switchIsOff)
    {
        [self presentDoNotDisturbOptions];
    }
}

/**
 * Presents actionSheet/Popover with Do Not Disturb options and handles actionSheet selection.
 *
 * The completion handler of the presented `OHActionSheet` calls to update the conversation notificationDate with a
 * date for the selected option, if not Canceled.
 *
 * Discussion: the actionSheet button indexes correlate to SC_DoNotDisturbOption enum values. In the `OHActionSheet` 
 * completion handler, `dateForDoNotDisturbOption:` returns a date for the selected button index. If the
 * actionSheet is not Canceled by the user, the conversation notificationDate property is updated with this date.
 *
 * Note: `updateDoNotDisturbView` is invoked in the completion handler in all cases. This handles the case in which the
 * `swDND` segmentedControl is "Off", then tapped "On", then the actionSheet Canceled. The update method will reset
 * the control to "Off".
 */
- (void)presentDoNotDisturbOptions
{
    // ET 10/16/14 OHActionSheet update
    [OHActionSheet showFromVC:self 
                       inView:self.view
                        title:kDNDAction_title
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:nil
            otherButtonTitles:@[kDNDActionTitle_oneHour, kDNDActionTitle_until8am, kDNDActionTitle_indefinitely]
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                       
                       if (buttonIndex != sheet.cancelButtonIndex)
                       {
                           NSDate *notificationDate = [self dateForDoNotDisturbOption:(SC_DoNotDisturbOption)buttonIndex];
                           [self setNotificationTime:notificationDate];
                       }
                       
                       // see documentation Note above
                       [self updateDoNotDisturbView];
                   }];
}

/**
 * Sets the conversation notificationDate property with the given date value.
 *
 * The `presentDoNotDisturbOptions` method presents an `OHActionSheet` with Do Not Disturb options buttons.
 *
 * @param date The date to set conversation.notificationDate
 * @see dateForDoNotDisturbOption:
 * @see presentDoNotDisturbOptions
 */
- (void)setNotificationTime:(NSDate *)date
{
	if (! self.conversation.notificationDate || ![self.conversation.notificationDate isEqualToDate:date])
	{   
        self.conversation = [self.conversation copy];
		self.conversation.notificationDate = date;
		
		NSString *convoId = self.conversation.uuid;
		NSString *aUserId = self.conversation.userId;
		
		YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
		[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
			STConversation *updatedConversation = [transaction objectForKey:convoId inCollection:aUserId];
			
			updatedConversation = [updatedConversation copy];
			updatedConversation.notificationDate = date;
			
			[transaction setObject:updatedConversation
							forKey:updatedConversation.uuid
					  inCollection:updatedConversation.userId];
			
		}completionBlock:^{
			[STAppDelegate updatedNotficationPrefsForUserID:aUserId];
		}];
	}
}

#pragma mark DND Accessors

/**
 * @return The STConversation notificationDate property value.
 */
- (NSDate *)getNotificationTime
{
	return self.conversation.notificationDate;
}

/**
 * @return `YES` if the Do Not Disturb feature is enabled on the current user network; `NO`, otherwise.
 */
- (BOOL)canDelayNotifications
{
	NSDictionary *dict = [[AppConstants SilentCircleNetworkInfo] objectForKey:STDatabaseManager.currentUser.networkID];
	BOOL canDelayNotifications = [[dict objectForKey:@"canDelayNotifications"] boolValue];
	return canDelayNotifications;
}

/**
 * @return A string for `lblDNDSelectedOption` text, used by the `updateDoNotDisturbView` method.
 */
- (NSString *)doNotDisturbTimeRemainingString
{
    NSString *title = kDND_off;
    NSDate *untilDate = self.conversation.notificationDate;
    if ([untilDate isEqual:[NSDate distantFuture]])
    {
        title = kDND_indefinitely;
    }
    else if ([untilDate isAfter:[NSDate date]])
    {
        title = doNotDisturbUntilString([self.getNotificationTime whenString]);
    }
    
    return title;
}

/**
 * Returns a date corresponding to a Do Not Disturb option.
 *
 * The `presentDoNotDisturbOptions` actionSheet completion handler updates the conversation notificationDate property
 * with a date returned from this method for a user actionSheet button selection.
 *
 * @param option An SC_DoNotDisturbOption enum identifier.
 * @return A date value for the given option.
 * @see presentDoNotDisturbOptions
 */
- (NSDate *)dateForDoNotDisturbOption:(SC_DoNotDisturbOption)option
{
    NSDate *date = nil;
    switch (option) {
            
        case dnd_off:  // -1 the "Off" date value
            date = [NSDate distantPast];
            break;
            
        case dnd_oneHour:
            date = [NSDate dateWithTimeIntervalSinceNow:(3600)];
            break;
            
        case dnd_eightAM:
        {
            NSDate *now = [NSDate dateWithTimeIntervalSinceNow:24 * 60 * 60]; // 24h from now
            
            NSCalendarUnit units =
			  NSCalendarUnitYear   |
			  NSCalendarUnitMonth  |
			  NSCalendarUnitDay    |
			  NSCalendarUnitHour   |
			  NSCalendarUnitMinute |
			  NSCalendarUnitSecond ;
            
            NSCalendar *calendar = [SCCalendar cachedAutoupdatingCurrentCalendar];
            NSDateComponents *comps = [calendar components:units fromDate:now];
            
            [comps setHour:8];
            [comps setMinute:0];
            [comps setSecond:0];
            
            NSDate *tomorrow = [calendar dateFromComponents:comps];
            date = tomorrow;
        }
            break;
            
        case dnd_indefinitely:
            date = [NSDate distantFuture];
            break;
    }
    return date;
}

/**
 * Returns `YES` if the current user network supports the Do Not Disturb feature, and if time remains between the
 * current time and a user-selected DND option.
 *
 * @return `YES` for an active Do Not Disturb option, on a supported network; `NO` otherwise.
 * @see notificationTimeInterval
 * @see canDelayNotifications
 */
// Used by updateDoNotDisturbView to set the swDND index
- (BOOL)doNotDisturbIsOn
{
    BOOL canDelay = [self canDelayNotifications];
//    NSTimeInterval delay = [self notificationTimeInterval];
//    /* values are:
//     * - before now for On
//     * - distantPast for off
//     * - time > now for delay
//     *
//     * delay < 0 == dnd_off
//     * delay > 3600*64000 == something big, dnd_indefinitely
//     */
//    BOOL dndIsOn = (delay > 0 && delay < 3600*64000);
    BOOL dndIsOn = [self.conversation.notificationDate isAfter:[NSDate date]]; // revised from calculating delay 07/27/14
    return (canDelay && dndIsOn);
}

/**
 * Returns as a time interval the difference between the conversation notificationDate and the current time, if 
 * notificationDate is not nil, and if nil, the time interval from now into the distant future.
 *
 * The return value of this method is used by the doNotDisturbIsOn method to evaluate whether time remains for a
 * Do Not Disturb option setting.
 *
 * @return A time interval with which to evaluate remaining time of a Do Not Disturb option setting.
 * @see doNotDisturbIsOn
 */
- (NSTimeInterval)notificationTimeInterval
{
    NSDate *date = self.getNotificationTime;
    // from original
//    NSTimeInterval delay = (date) ? [date timeIntervalSinceNow] : [[NSDate distantPast] timeIntervalSince1970];
    NSTimeInterval delay = [date timeIntervalSinceNow];
    return delay;
}


#pragma mark NavigationControllerDelegate Methods

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (viewController == self)
    {
        navigationController.delegate = self.cachedNavDelegate;
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Clear Messages Handler
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Messages the delegate "clear conversation" callback.
 *
 * The delegate instance should be the MessagesViewController.
 *
 * @param sender The "Clear Conversation" button
 * @see ConversationDetailsDelegate
 * @see MessagesViewController
 */
- (IBAction)clearButtonAction:(id)sender
{
	DDLogAutoTrace();
	
	// RH - 18 Sept, 2014
	//
	// At this point, we need to present an action sheet.
	// This is not the job of the delegate.
	// This is our job. And if the user doesn't cancel the operation,
	// then we can invoke the delegate method.
	//
	// In other words, we still have UI work to do that's specific to this view.
	// So this viewController should handle it. Not the delegate.
	//
//	if ([self.delegate respondsToSelector:@selector(conversationDetailsVC:clearConversationNowFromView:)]) {
//		[self.delegate conversationDetailsVC:self clearConversationNowFromView:_clearButton];
//	}
	
	NSString *title = NSLocalizedString(@"Erase all entries in this conversation?",
	                                    @"Action sheet message for \"Clear Conversation\" button");
	
//	if (AppConstants.isIOS8OrLater)
//	{
//		UIAlertController *alertController =
//		  [UIAlertController alertControllerWithTitle:title
//		                                      message:nil
//		                               preferredStyle:UIAlertControllerStyleActionSheet];
//		
//		[alertController addAction:[UIAlertAction actionWithTitle:NSLS_COMMON_CLEAR_CONVERSATION
//		                                                    style:UIAlertActionStyleDestructive
//		                                                  handler:^(UIAlertAction *action)
//		{
//			[self.delegate clearConversationAndDismiss:self];
//		}]];
//		
//		[alertController addAction:[UIAlertAction actionWithTitle:NSLS_COMMON_CANCEL
//		                                                    style:UIAlertActionStyleCancel
//		                                                  handler:^(UIAlertAction *action)
//		{
//			// Cancel: nothing to do
//		}]];
//	
//		[self presentViewController:alertController animated:YES completion:nil];
//	}
//	else // iOS 7
//	{
        // ET 10/16/14 OHActionSheet update
		[OHActionSheet showFromVC:self
		                   inView:self.view
		                    title:title
		        cancelButtonTitle:NSLS_COMMON_CANCEL
		   destructiveButtonTitle:NSLS_COMMON_CLEAR_CONVERSATION
		        otherButtonTitles:nil
		               completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
		{            
            if (sheet.destructiveButtonIndex == buttonIndex)
			{
				[self.delegate clearConversationAndDismiss:self];
			}
		}];
//	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Map Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)handleMapTap:(UITapGestureRecognizer *)gr
{
    // Do something - like push a map VC onto the nav stack
    
    
    [self.delegate getParticpantsLocationsWithCompletionBlock:^(NSError *error, NSArray *locations)
     {
 
         NSMutableArray* pins = [ NSMutableArray  array];
         
         NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
                                                                        timeStyle:NSDateFormatterShortStyle];
         
    
         for(NSDictionary *item in locations)
         {
             NSString*   displayName = [item objectForKey:@"displayName" ];
             CLLocation* location    = [item objectForKey:@"location" ];
             UIImage*    avatar      = [item objectForKey:@"avatar" ];
 //            BOOL       isMe         = [[item objectForKey:@"isMe"] boolValue];
             
            SCMapPin* pin  = [[SCMapPin alloc] initWithLocation: location
                                                               title: displayName
                                                            subTitle: [formatter stringFromDate:location.timestamp]
                                                               image: avatar
                                                                uuid: NULL] ;
                 
             [pins addObject:pin];
  
             
         };

         if(pins.count)
         {
       
             NewGeoViewController *geovc = [NewGeoViewController.alloc initWithNibName:@"NewGeoViewController" bundle:nil];
             geovc.mapPins = pins;
       
             [self.navigationController pushViewController:geovc animated:YES];
          }
         
     }];
    
    
    
}

- (void) updateMap
{
    //... make call to Vinnie's map image generator
    //... unhide and upate icon imageView with return image, if any
   
    [self.delegate getParticpantsLocationsWithCompletionBlock:^(NSError *error, NSArray *locations)
    {
        if(locations.count > 1)
        {
            _hasMap = YES;
        }
        else  if(locations.count == 1)
        {
            BOOL justMe  = [[[locations firstObject] objectForKey:@"isMe"] boolValue];
            
            _hasMap  = !justMe;
        }
          
        NSMutableArray* pins = [ NSMutableArray  array];
        
        if(_hasMap)
        {
            for(NSDictionary *item in locations)
            {
                NSString*   displayName = [item objectForKey:@"displayName" ];
//                NSDate*     timeStamp   = [item objectForKey:@"timeStamp" ];
                CLLocation* location    = [item objectForKey:@"location" ];
                UIImage*    avatar      = [item objectForKey:@"avatar" ];
                
                
                SCMapPin* pin  = [[SCMapPin alloc] initWithLocation: location
                                                              title: displayName
                                                           subTitle: @""
                                                              image: avatar
                                                               uuid: NULL] ;

                [pins addObject:pin];
            };
            
            if(pins.count)
            {
                [SCMapImage mapImageWithPins:pins
                                    withSize:_mapIcon.frame.size
                                     mapName:@"Click for detailed map"          // give this map a name?
                         withCompletionBlock:^(UIImage *image, NSError *error) {
                             
                             
                             if(image)
                             {
                                 _mapIcon.layer.cornerRadius = 8.0;
                                 _mapIcon.clipsToBounds = YES;
                                 _mapIcon.image = [image copy];
                                 _mapIcon.alpha = 0;
                                 _mapIcon.hidden = NO;
                                 _mapIcon.transform = CGAffineTransformMakeScale(0,0);
                                 [_mapIcon setUserInteractionEnabled:YES];

                                 [UIView animateWithDuration:0.35
                                                       delay:0 
                                      usingSpringWithDamping:0.65 
                                       initialSpringVelocity:0 
                                                     options:UIViewAnimationOptionCurveEaseOut
                                                  animations:^{
                                                      _mapIcon.alpha = 1;
                                                      _mapIcon.transform = CGAffineTransformIdentity;
                                                  } 
                                                  completion:^(BOOL finished) {
                                                      
                                                      DDLogCyan(@"self.containterViewFrame AFTER map:%@",
                                                                NSStringFromCGRect(self.containerView.frame));
                                                      
                                                      [self resetPopoverSizeIfNeeded];
                                                      
                                                  }]; // end animation block
                                 
                             } // end if image
                             
                         }]; // end SCMapImage completionBlock
                
            } // end if pins.count
            
        } // end if _hasMap

    }]; // getParticpantsLocationsWithCompletionBlock:
}


#pragma mark mapKit delegate

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapViewIn
{
//    [mapViewIn addAnnotation:dropPin];
//    [mapViewIn selectAnnotation:dropPin animated:YES];
}



- (MKAnnotationView *)mapView:(MKMapView *)mapViewIn viewForAnnotation:(id<MKAnnotation>)annotation {
    MKAnnotationView *annotationView = [mapViewIn dequeueReusableAnnotationViewWithIdentifier:@"MapVC"];
    if (!annotationView) {
        annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"MapVC"];
        annotationView.canShowCallout = NO;
        
        COVUserMapAnnotation* dropPin = annotation;
        annotationView.image = dropPin.image;
        
		//        annotationView.leftCalloutAccessoryView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
  //      annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        // could put a rightCalloutAccessoryView here
    } else {
        annotationView.annotation = annotation;
		//       [(UIImageView *)annotationView.leftCalloutAccessoryView setImage:nil];
    }
	
    return annotationView;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
// 	
//	NSString *coordString = [NSString stringWithFormat:@"%@: %f\r%@: %f\r%@: %g",
//							 NSLocalizedString(@"Latitude",@"Latitude"), dropPin.coordinate.latitude,
//							 NSLocalizedString(@"Longitude",@"Longitude"), dropPin.coordinate.longitude,
//							 NSLocalizedString(@"Altitude",@"Altitude"), dropPin.altitude];
//    
//    [OHAlertView showAlertWithTitle:NSLocalizedString(@"Coordinates",@"Coordinates")
//                            message:NULL
//                       cancelButton:NSLocalizedString(@"Done",@"Done")
//                       otherButtons:@[NSLocalizedString(@"Open in Maps",@"Open in Maps"), NSLocalizedString(@"Copy",@"Copy")]
//                      buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex) {
//                          
//                          switch(buttonIndex)
//                          {
//                              case 1:
//                              {
//                                  MKPlacemark *theLocation = [[MKPlacemark alloc] initWithCoordinate:dropPin.coordinate addressDictionary:nil];
//                                  MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:theLocation];
//                                  
//                                  if ([mapItem respondsToSelector:@selector(openInMapsWithLaunchOptions:)]) {
//                                      [mapItem setName:dropPin.name];
//                                      
//                                      [mapItem openInMapsWithLaunchOptions:nil];
//                                  }
//                                  else {
//                                      NSString *latlong = [NSString stringWithFormat: @"%f,%f", dropPin.coordinate.latitude, dropPin.coordinate.longitude];
//                                      NSString *url = [NSString stringWithFormat: @"http://maps.google.com/maps?ll=%@",
//                                                       [latlong stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
//                                      [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
//                                      
//                                  }
//                              }
//                                  break;
//                                  
//                              case 2:
//                              {
//                                  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
//                                  NSMutableDictionary *items = [NSMutableDictionary dictionaryWithCapacity:1];
//                                  NSString *copiedString = [NSString stringWithFormat:@"%@ %@:\r%@", NSLocalizedString(@"Location of", @"Location of"), dropPin.name, coordString];
//                                  [items setValue:copiedString forKey:(NSString *)kUTTypeUTF8PlainText];
//                                  pasteboard.items = [NSArray arrayWithObject:items];
//                                  
//                              }
//                                  break;
//                                  
//                              default:
//                                  break;
//                          }
//                          
//                      }];
//    
}

@end
