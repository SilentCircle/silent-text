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
#import "MoreMenuViewController.h"

#import "AppConstants.h"
#import "AppDelegate.h"
#import "MessageStreamManager.h"
#import "OHActionSheet.h"
#import "SCDateFormatter.h"
#import "SCloudObject.h"
#import "SCimpWrapper.h"
#import "SilentTextStrings.h"
#import "STLogging.h"
#import "STMessage.h"
#import "STDynamicHeightView.h"
#import "STSCloud.h"
#import "STUserManager.h"

// Categories
#import "CLLocation+NSDictionary.h"
#import "NSNumber+Filesize.h"

// Libraries
#import <MobileCoreServices/MobileCoreServices.h>


// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


#define kMaxButtons 4
#define kMaxLabels  5

@interface MoreMenuViewController () <MBProgressHUDDelegate>
@end


@implementation MoreMenuViewController
{
  	YapDatabaseConnection *databaseConnection;
	MBProgressHUD *HUD;

    STMessage* message;
    NSDateFormatter* dateFormatter;
    
    NSDictionary * buttons[kMaxButtons];

    NSString * labels[kMaxLabels];
    NSString * values[kMaxLabels];
	
	BOOL hasViewWillAppear;
    
    
    NSInteger viewedLabelIndex;
    NSInteger partsLabelIndex;
}

@synthesize delegate = delegate;

@synthesize isInPopover = isInPopover;

@synthesize containerView = containerView;

@synthesize infoContainerView = infoContainerView;
@synthesize buttonContainerView = buttonContainerView;

@synthesize label0 = label0;
@synthesize label1 = label1;
@synthesize label2 = label2;
@synthesize label3 = label3;
@synthesize label4 = label4;

@synthesize value0 = value0;
@synthesize value1 = value1;
@synthesize value2 = value2;
@synthesize value3 = value3;
@synthesize value4 = value4;

@synthesize button0 = button0;
@synthesize button1 = button1;
@synthesize button2 = button2;
@synthesize button3 = button3;


- (id)initWithDelegate:(id)inDelagate message:(STMessage *)inMessage
{
	if ((self = [super initWithNibName:@"MoreMenuViewController" bundle:nil]))
	{
		delegate = inDelagate;
        message = inMessage;
        

	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
 	[HUD removeFromSuperview];
	HUD = nil;
    
  }



- (void)viewDidLoad
{
	DDLogAutoTrace();
    [super viewDidLoad];
    
    // Setup database
    
    databaseConnection = STDatabaseManager.uiDatabaseConnection;

   	dateFormatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
	                                                  timeStyle:NSDateFormatterShortStyle];
 
	self.title = NSLocalizedString(@"Message Details", @"Message Details");

    //ET 01/05/14 ST-854 fix (with minor xib layout fixes) -
    // info labels obscured by nav bar
    if (self.navigationController.navigationBar.isTranslucent)
        [self setEdgesForExtendedLayout:UIRectEdgeNone];

    if (!self.isInPopover)
	{
    	self.view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
 	}
//	else {
//		self.navigationController.navigationBar.barStyle =  UIBarStyleBlack;
//		self.navigationController.navigationBar.translucent = YES;
//
//	}
    
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(databaseConnectionDidUpdate:)
												 name:UIDatabaseConnectionDidUpdateNotification
											   object:STDatabaseManager];
    
    
    [self adjustContentSize];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
    
    // If we're not being displayed in a popover,
	// then bump the containerView down so its not hidden behind the main nav bar.
	
	if (!isInPopover)
	{
		DDLogVerbose(@"Updating topConstraint - not in popover");
		
		CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
		
		CGFloat statusBarHeight = MIN(statusBarFrame.size.width, statusBarFrame.size.height);
		CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
		
		NSLayoutConstraint *constraint = [self topConstraintFor:containerView];
		constraint.constant = statusBarHeight + navBarHeight;
		
		[self.view setNeedsUpdateConstraints];
 	}
	
	hasViewWillAppear = YES;
}

/**
 * This method is queried * by our own code * when creating popover controllers.
 * It is conceptually similar to the deprecated contentSizeForViewInPopover method.
**/
- (CGSize)preferredPopoverContentSize
{
	DDLogAutoTrace();
	
	// If this method is queried before we've loaded the view, then containerView will be nil.
	// So we make sure the view is loaded first.
	(void)[self view];
	
	return containerView.frame.size;
}

// ET 10/16/14 - to prevent popover from collapsing with actionSheet
/**
 * This method is invoked automatically when the view is displayed in a popover.
 * The popover system uses this method to automatically size the popover accordingly.
 **/
- (CGSize)preferredContentSize
{
    DDLogAutoTrace();
    return [self preferredPopoverContentSize];
}


-(UILabel*) labelValueForIndex:(NSInteger)index
{
    UILabel *value = nil;
    
    switch(index)
    {
        case 0: value = value0; break;
        case 1: value = value1; break;
        case 2: value = value2; break;
        case 3: value = value3; break;
        case 4: value = value4; break;
        default: value = NULL;
    }
    return value;
    
}

-(UILabel*) labelLabelForIndex:(NSInteger)index
{
    UILabel *label = nil;
    
    switch(index)
    {
        case 0: label = label0;  break;
        case 1: label = label1; break;
        case 2: label = label2; break;
        case 3: label = label3;  break;
        case 4: label = label4;  break;
        default: label = NULL;
    }
    return label;
    
}

- (NSString *)stringForCipherSuite:(SCimpCipherSuite)cipherSuite
{
	switch (cipherSuite)
	{
        case kSCimpCipherSuite_SKEIN_AES256_ECC414          : return @"Non-NIST";
		case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384    : return @"NIST/AES-128";
		case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384 : return @"NIST/AES-256";
		case kSCimpCipherSuite_SKEIN_AES256_ECC384          : return @"SKEIN/AES-256";
		case kSCimpCipherSuite_Symmetric_AES128             : return @"AES-128";
		case kSCimpCipherSuite_Symmetric_AES256             : return @"AES-256";
		default                                             : return @"";
	}
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
	
	// Check to see if the conversation object changed
	
    
    if(message)
    {
        NSString *messageUUID   = message.uuid;
        NSString *conUUID       = message.conversationId;
        
        BOOL messageChanged = [databaseConnection hasChangeForKey:messageUUID
                                                     inCollection:conUUID
                                                  inNotifications:notifications];
        
        
        BOOL scloudChanged = [databaseConnection hasChangeForKey:message.scloudID
                                                     inCollection:kSCCollection_STSCloud
                                                  inNotifications:notifications];
        
        __block STMessage* newMessage = NULL;
        
        if(messageChanged)
        {
            [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                 newMessage = [transaction objectForKey: messageUUID inCollection:conUUID];
            }];
            
            if(newMessage)
            {
                message = newMessage;
                
                // updated the viewdate?
                UILabel* viewedValue = [self labelValueForIndex:viewedLabelIndex];
                if(viewedValue )
                {
                    viewedValue.text = message.rcvDate
                    ? [dateFormatter stringFromDate:message.rcvDate]
                    : @"---";
                    
                }
            }
            
            
            
        }
        
        if(scloudChanged)
        {
           	__block STSCloud *scl = NULL;
            
            [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                
                scl = [transaction objectForKey:message.scloudID inCollection:kSCCollection_STSCloud];
            }];
            
            NSUInteger totalSegments = scl.segments.count +1;
            NSUInteger missingSegments = scl.missingSegments.count;
            
            UILabel* viewedValue = [self labelValueForIndex:partsLabelIndex];
            if(viewedValue )
            {
                viewedValue.text = [NSString stringWithFormat:@"%d of %d",(int) missingSegments, (int) totalSegments];
            }
        }
    }
 
};


- (void)adjustContentSize
{
    DDLogAutoTrace();
    
    typedef enum
    {
        kSignature_None,
        kSignature_Corrupt,
        kSignature_Verified,
        kSignature_KeyNotFound
    } MessageSignature_State;
	
    Siren* siren = message.siren;
    SCloudObject* scloud = NULL;
    
    MessageSignature_State sigState = kSignature_None;
    
	//
	// Buttons
	//
	
    BOOL canclear   = YES;
    BOOL canUpload  = NO;
    BOOL canResend  = NO;
    BOOL canForward = NO;
    BOOL canReverify = NO;
	
    // these are used for finding the proper label later.
    viewedLabelIndex  = -1;
    partsLabelIndex= -1;
    
    // caclulate message signature state
    if (siren.signature)
    {
		if (message.isVerified)
		{
			sigState = kSignature_Verified;
		}
		else
		{
			BOOL keyfound = [[message.signatureInfo objectForKey:kSigInfo_keyFound] boolValue];
            
			if (keyfound)
				sigState = kSignature_Corrupt;
			else
			{
				sigState = kSignature_KeyNotFound;
				canReverify = YES;
			}
		}
        
    }
    else
        sigState = kSignature_None;
    
	if (message.isOutgoing && siren.cloudLocator)
	{
		scloud = [[SCloudObject alloc] initWithLocatorString:message.siren.cloudLocator
		                                           keyString:message.siren.cloudKey
                                                        fyeo:message.siren.fyeo];
		
		if (scloud && scloud.missingSegments.count == 0)
			canUpload = YES;
	}
    
    canResend = !(message.isStatusMessage || message.isSpecialMessage)  && message.isOutgoing;
    canForward = !(message.isStatusMessage || message.isSpecialMessage) && (message.isOutgoing || !message.siren.fyeo);

    for(int i = 0; i < kMaxButtons; i++) {
		buttons[i] = NULL;
	}
    
    int buttonIndex = 0;
    
    if(canclear)
        buttons[buttonIndex++] = @{@"title"  : NSLS_COMMON_CLEAR_MESSAGE,
                                   @"color"  : [UIColor redColor],
                                   @"action" : NSStringFromSelector(@selector(clearAction:))};
    
    if(canReverify)
        buttons[buttonIndex++] = @{@"title"  : NSLocalizedString(@"Verify Signature", "Verify Signature"),
//                                   @"color"  : [UIColor colorWithRed:0.000 green:0.500 blue:1.000 alpha:1.000],
                                   @"action" : NSStringFromSelector(@selector(reverifyAction:)) };
    
    if(canForward)
        buttons[buttonIndex++] = @{@"title"  : NSLocalizedString(@"Forward", "Forward"),
//                                   @"color"  : [UIColor colorWithRed:0.000 green:0.500 blue:1.000 alpha:1.000],
                                   @"action" : NSStringFromSelector(@selector(forwardAction:)) };
    
    if(canResend)
        buttons[buttonIndex++] = @{@"title"  : NSLocalizedString(@"Send Again", "Send Again"),
//                                   @"color"  : [UIColor colorWithRed:0.000 green:0.500 blue:1.000 alpha:1.000],
                                   @"action" : NSStringFromSelector(@selector(sendAgainAction:))};
    
    if(canUpload)
        buttons[buttonIndex++] = @{@"title"  : NSLocalizedString(@"Upload Again", "Upload Again"),
//                                   @"color"  : [UIColor colorWithRed:0.000 green:0.500 blue:1.000 alpha:1.000],
                                   @"action" : NSStringFromSelector(@selector(uploadAgainAction:))};
    
    for (int i = 0; i < kMaxButtons; i++)
    {
        UIButton* button = nil;
        switch(i)
        {
            case 0: button = button0; break;
            case 1: button = button1; break;
            case 2: button = button2; break;
            case 3: button = button3; break;
        }
        
        NSDictionary *buttonInfo = buttons[i];
        if (buttonInfo)
        {
            
            [button setTitle:[buttonInfo objectForKey:@"title"]  forState:UIControlStateNormal];
			UIColor *color = [buttonInfo objectForKey:@"color"];
            if (color)
				[button setTitleColor:color forState:UIControlStateNormal];
            [button addTarget:self action:NSSelectorFromString([buttonInfo objectForKey:@"action"])
			             forControlEvents:UIControlEventTouchUpInside];
			
            [button setHidden:NO];
		}
		else
		{
			[button setHidden:YES];
		}
	}
    
    
	//
	// Labels
	//
	
    for(int i = 0; i < kMaxLabels; i++) {
		labels[i] = NULL;
		values[i] = NULL;
	}
	
    int labelIndex = 0;
    
    if(message.isStatusMessage)
    {
        NSString* sendDate = [dateFormatter stringFromDate:message.sendDate];
        NSDictionary* statusMessage = message.statusMessage;
        
        labels[labelIndex] = NSLocalizedString(@"Date", @"Date");
        values[labelIndex++] = sendDate;

        if([statusMessage objectForKey:@"keyInfo"])
        {
            NSDictionary* keyInfo = [statusMessage objectForKey:@"keyInfo"];
            SCimpMethod scimpMethod = [[keyInfo objectForKey:kSCimpInfoMethod] unsignedIntValue];
            NSString *SAS = [keyInfo objectForKey:kSCimpInfoSAS];
            
            NSString* scimpMethodString = @"";
            
            if (scimpMethod == kSCimpMethod_DH)
                scimpMethodString = @"SCimp";
            else if (scimpMethod == kSCimpMethod_DHv2)
                scimpMethodString = @"SCimp2";
            else if(scimpMethod == kSCimpMethod_PubKey)
                scimpMethodString = NSLocalizedString( @"Public Key",  @"Public Key");
            else if(scimpMethod == kSCimpMethod_Symmetric)
                scimpMethodString = NSLocalizedString( @"Group Keys",  @"Group Keys");
            
            labels[labelIndex] = NSLocalizedString(@"Protocol", @"Protocol");
            values[labelIndex++] = scimpMethodString;

            SCimpCipherSuite cipherSuite = [[keyInfo objectForKey:kSCimpInfoCipherSuite] unsignedIntValue];
            NSString* scimpSuiteString = [self stringForCipherSuite:cipherSuite];
            
            labels[labelIndex] = NSLocalizedString(@"Cipher", @"Cipher");
            values[labelIndex++] = scimpSuiteString;
            
            labels[labelIndex] = NSLocalizedString(@"SAS", @"SAS");
            values[labelIndex++] = SAS;

        }

    }
    else if(message.isSpecialMessage)
    {
        NSString* dateString;
        
        if(message.isOutgoing)
        {
            dateString = [dateFormatter stringFromDate:message.sendDate];
        }
        else
        {
            dateString = [dateFormatter stringFromDate:message.timestamp];
            
        }
        
        labels[labelIndex] = NSLocalizedString(@"Date", @"Date");
        values[labelIndex++] = dateString;
  
          
    }
    else if(message.isOutgoing)
    {
        NSString* sendDate = [dateFormatter stringFromDate:message.sendDate];
        
        NSString* viewDate = message.rcvDate
        ? [dateFormatter stringFromDate:message.rcvDate]
        : @"---";
        
        labels[labelIndex] = NSLocalizedString(@"Sent", @"Sent");
        values[labelIndex++] = sendDate;
        
        viewedLabelIndex = labelIndex;
        
        if( UTTypeConformsTo( (__bridge CFStringRef)  siren.mediaType, kUTTypeAudio))
        {
            labels[labelIndex] =  NSLocalizedString(@"Played", @"Played");
        }
        else
        {
            labels[labelIndex] =  NSLocalizedString(@"Viewed", @"Viewed");
        }
        
        values[labelIndex++] = viewDate;
    }
    else
    {
        NSString* sendDate =  [dateFormatter stringFromDate:message.timestamp];
        
        labels[labelIndex] = NSLocalizedString(@"Sent", @"Sent");
        values[labelIndex++] = sendDate;
        
        if(sigState != kSignature_None)
        {
            labels[labelIndex] = NSLocalizedString(@"Signature", @"Signature");

            switch(sigState)
            {
               case kSignature_Corrupt:
                {
                    values[labelIndex] = NSLocalizedString(@"Invalid", @"Invalid");
                    break;
               }
                case kSignature_Verified:
                {
                    values[labelIndex] = NSLocalizedString(@"Verified", @"Verified");
                    break;
                }

                case kSignature_KeyNotFound:
                {
                    values[labelIndex] = NSLocalizedString(@"Key Not Found",@"Key Not Found");
                    break;
                }

                default:  ;
                    
            }
            labelIndex++;
        }
    }
    
    
	STSCloud *scl = [self scloudForMessage:message];
	if (scl)
    {
        NSDictionary * metaData = scl.metaData;
        
        if([metaData objectForKey:kSCloudMetaData_FileSize])
        {
            NSNumber* fileSize = [metaData objectForKey:kSCloudMetaData_FileSize] ;
            
            labels[labelIndex] = NSLocalizedString(@"Media", @"Media");
            values[labelIndex++] = [NSString stringWithFormat:@"%@: %@",
                                        [STAppDelegate stringForUTI:scl.mediaType], fileSize.fileSizeString];
        }
        
        if( UTTypeConformsTo( (__bridge CFStringRef)  scl.mediaType, kUTTypeAudio) && [metaData objectForKey:kSCloudMetaData_Duration])
        {
            NSDateFormatter* durationFormatter =  [SCDateFormatter localizedDateFormatterFromTemplate:@"mmssS"];
            NSString* durationText = [durationFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: siren.duration.doubleValue]];
            
            labels[labelIndex] = NSLocalizedString(@"Duration", @"Duration");
            values[labelIndex++] = durationText ;
        }
        else if([metaData objectForKey:kSCloudMetaData_FileName])
        {
            NSString* fileName = [metaData objectForKey:kSCloudMetaData_FileName] ;
            
            labels[labelIndex] = NSLocalizedString(@"Name", @"Name");
            values[labelIndex++] = fileName ;
        }

        
        NSUInteger totalSegments = scl.segments.count + 1;
        NSUInteger missingSegments = scl.missingSegments.count;
        
        if(missingSegments > 0)
        {
            partsLabelIndex = labelIndex;
            labels[labelIndex] = NSLocalizedString(@"Parts", @"Parts");
            values[labelIndex++] = [NSString stringWithFormat:@"%lu of %lu",
			                           (unsigned long)missingSegments, (unsigned long)totalSegments];
        }
    }
    else if(message.siren.isMapCoordinate)
    {
        labels[labelIndex] = NSLocalizedString(@"Location:", @"Location:");
        NSString* mapTitle = @"";
        
        NSError *jsonError;
        NSDictionary *locInfo = [NSJSONSerialization
                                 JSONObjectWithData:[message.siren.location dataUsingEncoding:NSUTF8StringEncoding]
                                 options:0 error:&jsonError];

        if (jsonError==nil){
             
            CLLocation* location = [[CLLocation alloc] initWithDictionary: locInfo];
            
            if(location.timestamp)
            {
                NSDateFormatter *formatter  = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterShortStyle
                                                                                timeStyle:NSDateFormatterShortStyle];
                 mapTitle =  [formatter stringFromDate:location.timestamp];
            }
          }
         values[labelIndex++] =mapTitle ;
      }
    
    
	for(int i = 0; i < kMaxLabels; i++)
	{
		UILabel *label = [self labelLabelForIndex: i];
		UILabel *value = [self labelValueForIndex: i];
       	
		NSString *labelText = labels[i];
		NSString *valueText = values[i];
		
		if (labelText || valueText)
		{
			label.text = labelText;
			value.text = valueText;
			
			[label setHidden:NO];
			[value setHidden:NO];
		}
		else
		{
			[label setHidden:YES];
			[value setHidden:YES];
        }
	}
	
	// Layout all the subviews
	//
	// Step 1:
	//   Invalidate the height of our STDynamicHeightView's.
	//   These custom UIView subclasses automatically set their intrinsic height based on non-hidden subviews.
	//   And we just toggled the hidden flag of a bunch of subviews, so make sure the layout system knows that
	//   it needs to requery for the intrinsicContentSize.
	//
	// Step 2:
	//   Mark the view as needing to recalculate constriaints.
	//
	// Step 3:
	//   Force the layout routine to run immediately.
	//   Note that we are NOT calling setNeedsLayout!
	//   We want to force the layout routine to run NOW (not later).
	//   This way the containerView.frame is properly set for us,
	//   which is needed for the code below, and for the preferredPopoverContentSize method.
	
	[infoContainerView invalidateIntrinsicContentSize];
	[buttonContainerView invalidateIntrinsicContentSize];
	
	[self.view setNeedsUpdateConstraints];
	[self.view layoutIfNeeded];

	// Adjust popover size (if needed)
	
	if (isInPopover && hasViewWillAppear)
	{
		if ([delegate respondsToSelector:@selector(moreMenuView:setPopoverContentSize:)])
			[delegate moreMenuView:self setPopoverContentSize:self.containerView.frame.size];
	}
}

- (STSCloud *)scloudForMessage:(STMessage *)msg
{
	__block STSCloud* scl = nil;
	
	if(msg.scloudID)
	{
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			scl = [transaction objectForKey:message.scloudID inCollection:kSCCollection_STSCloud];
		}];
	}
	
	return scl;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Constraints
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSLayoutConstraint *)topConstraintFor:(UIView *)item
{
	for (NSLayoutConstraint *constraint in item.superview.constraints)
	{
		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeTop) ||
		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeTop))
		{
			return constraint;
		}
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)reverifyAction:(id)sender
{
	DDLogAutoTrace();
	
	HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	HUD.delegate = self;
	HUD.mode = MBProgressHUDModeIndeterminate;
	HUD.labelText = NSLocalizedString(@"Verifying…", @"Verifying...");
	
	STLocalUser *currentUser = STDatabaseManager.currentUser;
	MessageStream *ms = [MessageStreamManager messageStreamForUser:currentUser];
	
	NSString *_messageId = message.uuid;                // snapshot for long running operation
	NSString *_conversationId = message.conversationId; // snapshot for long running operation
	
	__weak typeof(self) weakSelf = self;
	[ms reverifySignatureForMessage:message completionBlock:^(NSError *error) {
		
		__strong typeof(self) strongSelf = weakSelf;
		
		if ([strongSelf->message.uuid           isEqualToString:_messageId] &&
			[strongSelf->message.conversationId isEqualToString:_conversationId])
		{
			[strongSelf reverifyActionCompleteWithError:error];
		}
	}];
}

- (void)reverifyActionCompleteWithError:(NSError *)error
{
	if (error)
	{
		HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"attention"]];
		HUD.mode = MBProgressHUDModeCustomView;
		HUD.labelText = error.localizedDescription;
		
		[HUD show:NO];
		[HUD hide:YES afterDelay:3.0];
		[self adjustContentSize];
	}
	else
	{
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			message = [transaction objectForKey:message.uuid inCollection:message.conversationId];
		}];
		
		HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark"]];
		HUD.mode = MBProgressHUDModeCustomView;
		HUD.labelText =  NSLocalizedString(@"Verified", @"Verified");
		
		[HUD show:NO];
		[HUD hide:YES afterDelay:3.0];
		[self adjustContentSize];
	}
}

- (IBAction)sendAgainAction:(id)sender
{
    if ([delegate respondsToSelector:@selector(moreMenuView:sendAgainButton:)])
		[delegate moreMenuView:self sendAgainButton:message];

}
- (IBAction)uploadAgainAction:(id)sender
{
    if ([delegate respondsToSelector:@selector(moreMenuView:uploadAgainButton:)])
		[delegate moreMenuView:self uploadAgainButton:message];
  
}
- (IBAction)clearAction:(id)sender
{
    [OHActionSheet showFromVC:self 
                       inView:self.view
                        title:NULL
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:NSLS_COMMON_CLEAR_MESSAGE
            otherButtonTitles:nil
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
							 
							 NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
							 
							 if ([choice isEqualToString:NSLS_COMMON_CLEAR_MESSAGE])
							 {
								 
                                 if ([delegate respondsToSelector:@selector(moreMenuView:clearButton:)])
                                     [delegate moreMenuView:self clearButton:message];
							 }
							 
						 }];

  
}
- (IBAction)forwardAction:(id)sender
{
    if(AppConstants.isIPad)
    {
        if ([delegate respondsToSelector:@selector(moreMenuView:needsHidePopoverAnimated:)]) {
            [delegate moreMenuView:self needsHidePopoverAnimated:NO];
        }
    }
    
    if ([delegate respondsToSelector:@selector(moreMenuView:forwardButton:)])
		[delegate moreMenuView:self forwardButton:message];
    
}


#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[HUD removeFromSuperview];
	HUD = nil;
}


@end
