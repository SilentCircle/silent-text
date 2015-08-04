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
#import "PrivacyViewController.h"

#import "AppDelegate.h"
#import "AppConstants.h"
#import "BurnDelays.h"
#import "BurnDelayViewController.h"
#import "DatabaseManager.h"
#import "MBProgressHUD.h"
#import "OHActionSheet.h"
#import "OHAlertView.h"
#import "SilentTextStrings.h"
#import "SCFileManager.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "STPreferences.h"

// Categories
#import "NSDate+SCDate.h"
#import "NSNumber+Filesize.h"

// Libraries
#import <SCCrypto/SCcrypto.h> 


// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@interface PrivacyViewController ()

@property (nonatomic, weak) IBOutlet UIView *containerView;

@property (nonatomic, weak) IBOutlet UIButton *receiptsButton;
@property (nonatomic, weak) IBOutlet UIButton *notificationsButton;
@property (nonatomic, weak) IBOutlet UIButton *cipherButton;

@property (nonatomic, weak) IBOutlet UILabel *cacheUsedLabel;

@property (nonatomic, weak) IBOutlet UIView *horizontalRule1;
@property (nonatomic, weak) IBOutlet UIView *horizontalRule2;
@property (weak, nonatomic) IBOutlet UIButton *burnDelay;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *eraseCacheButton;
@property (weak, nonatomic) IBOutlet UIButton *experimentalFeaturesButton;
@property (weak, nonatomic) IBOutlet UISlider *burnSlider;
@property (weak, nonatomic) IBOutlet UILabel *burnSliderLabel;
@property (strong, nonatomic) IBOutlet UIView *burnView;
@property (weak, nonatomic) IBOutlet UIButton *burnButton;
@property (assign, nonatomic) BOOL burnStatus;

- (IBAction)toggleBurn:(id)sender;

- (IBAction)receiptsButtonTapped:(id)sender;
- (IBAction)notificationsButtonTapped:(id)sender;

- (IBAction)cipherButtonTapped:(id)sender;

- (IBAction)eraseCacheButtonTapped:(id)sender;
- (IBAction)burnDelaySelectAction:(id)sender;
- (IBAction)burnDelayDismiss:(id)sender;
- (IBAction)experimentalAction:(id)sender;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation PrivacyViewController
{
	NSDictionary *cipherChoices;
	MBProgressHUD *HUD;
	BurnDelays *burnDelays;
}

@synthesize containerView = containerView;

@synthesize receiptsButton = receiptsButton;
@synthesize notificationsButton = notificationsButton;
@synthesize cipherButton = cipherButton;
@synthesize cacheUsedLabel = cacheUsedLabel;

@synthesize horizontalRule1 = horizontalRule1;
@synthesize horizontalRule2 = horizontalRule2;

- (id)initWithProperNib
{
	return [self init];
}

- (id)init
{
	self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil];
    if (self) {
        // Custom initialization
        
        cipherChoices= @{
                         @(kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384): @"NIST/AES-128",
                         @(kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384): @"NIST/AES-256",
                         @(kSCimpCipherSuite_SKEIN_AES256_ECC384): @"SKEIN/AES-256",
                         @(kSCimpCipherSuite_SKEIN_AES256_ECC414): @"Non-NIST"};
        
 	}
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.navigationItem.title = NSLocalizedString(@"Default Privacy Options", @"Default Privacy Options");
	
    if (AppConstants.isIPhone)
    {
		
		self.navigationItem.leftBarButtonItem =
		  [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"Done")
		                                   style:UIBarButtonItemStylePlain
		                                  target:self
		                                  action:@selector(handleActionBarDone)];
    }
	self.edgesForExtendedLayout=UIRectEdgeNone;
	self.extendedLayoutIncludesOpaqueBars=NO;

    
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(prefsChanged:)
												 name:PreferencesChangedNotification
											   object:nil];

	if ([[UIScreen mainScreen] scale] > 1.0)
	{
		// On retina devices, the contentScaleFactor of 2 results in our horizontal rule
		// actually being 2 pixels high. Fix it to be only 1 pixel (0.5 points).

		NSLayoutConstraint *heightConstraint;

		heightConstraint = [self heightConstraintFor:horizontalRule1];
		heightConstraint.constant = (heightConstraint.constant / [[UIScreen mainScreen] scale]);

		[horizontalRule1 setNeedsUpdateConstraints];

		heightConstraint = [self heightConstraintFor:horizontalRule2];
		heightConstraint.constant = (heightConstraint.constant / [[UIScreen mainScreen] scale]);

		[horizontalRule2 setNeedsUpdateConstraints];
	}
    [self updateInfo];
	burnDelays = [[BurnDelays alloc] init];
	[burnDelays initializeBurnDelaysWithOff:NO];
	_burnStatus = [STPreferences defaultShouldBurn];

	[self updateBurnStatus];
}

-(void)viewWillAppear:(BOOL)animated
{

////
/// to disable the SC Labs.
    
//    BOOL isDebug = [AppConstants isApsEnvironmentDevelopment];
//    [_experimentalFeaturesButton setEnabled:isDebug];
//////
    
	[_activityIndicator setHidden:NO];
	[_activityIndicator startAnimating];
	[_eraseCacheButton setEnabled:NO];
    
    [self updateCacheInfo];

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait;
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
    (void)[self view];
    return self.view.frame.size;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSLayoutConstraint *)heightConstraintFor:(UIView *)item
{
	for (NSLayoutConstraint *constraint in item.constraints)
	{
		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeHeight) ||
		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeHeight))
		{
			return constraint;
		}
	}
	
	return nil;
}

//- (NSLayoutConstraint *)topConstraintFor:(id)item
//{
//	for (NSLayoutConstraint *constraint in self.view.constraints)
//	{
//		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeTop) ||
//		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeTop))
//		{
//			return constraint;
//		}
//	}
//	
//	return nil;
//}

- (void)updateCacheInfo
{
	cacheUsedLabel.text = nil;
	
	__weak PrivacyViewController *weakSelf = self;
    [SCFileManager calculateScloudCacheSizeWithCompletionBlock:^(NSError *error, NSNumber *cacheSize) {
		
	#pragma clang diagnostic push
	#pragma clang diagnostic warning "-Wimplicit-retain-self"
		
		__strong PrivacyViewController *strongSelf = weakSelf;
		if (strongSelf)
		{
			strongSelf->cacheUsedLabel.text = cacheSize.fileSizeString;
			
			[strongSelf->_activityIndicator stopAnimating];
			[strongSelf->_activityIndicator setHidden:YES];
			[strongSelf->_eraseCacheButton setEnabled:YES];
		}
		
	#pragma clang diagnostic pop
	}];
}

- (void)updateInfo
{
    [_experimentalFeaturesButton setTitle: [STPreferences experimentalFeatures]
     ? NSLocalizedString(@"On", "On") : NSLocalizedString(@"Off", "Off")  forState:UIControlStateNormal];
    
	
    NSDictionary *dict = [[AppConstants SilentCircleNetworkInfo] objectForKey:STDatabaseManager.currentUser.networkID];
	
	BOOL canDelayNotifications = [[dict objectForKey:@"canDelayNotifications"] boolValue];

    if(canDelayNotifications)
    {
        NSDate* notifyTime = [STPreferences notificationDate];
        
        NSTimeInterval delay = notifyTime ? [notifyTime timeIntervalSinceNow]
        : [[NSDate distantPast] timeIntervalSince1970];
        if(delay < 0)
        {
            [notificationsButton setTitle:NSLS_COMMON_OFF forState:UIControlStateNormal];
            
        }
        else if(delay > 3600*64000)   // something big
        {
            [notificationsButton setTitle:NSLS_FOREVER forState:UIControlStateNormal];
        }
        else
        {
            [notificationsButton setTitle:[NSString stringWithFormat:@"Until %@", [notifyTime whenString]]
                                 forState:UIControlStateNormal];
            
        }
      }
    else
    {
        [notificationsButton setEnabled:NO];
        [notificationsButton setTitle: NSLocalizedString(@"Off", "Off")  forState:UIControlStateDisabled];
    }
    
    

	[receiptsButton setTitle:([STPreferences defaultSendReceipts] ? NSLS_COMMON_ON : NSLS_COMMON_OFF)
	                forState:UIControlStateNormal];
    
    
	SCimpCipherSuite cipherSuite = [STPreferences scimpCipherSuite];
	NSString *selectedKey = [cipherChoices objectForKey:@(cipherSuite)];
	
	[cipherButton setTitle:selectedKey forState:UIControlStateNormal];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (void)prefsChanged:(NSNotification *)notification
{
	NSString *prefs_key = [notification.userInfo objectForKey:PreferencesChangedKey];
	
	if ([prefs_key isEqualToString:prefs_experimentalFeatures])
	{
		[self updateInfo];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)cipherButtonTapped:(id)sender
{
    NSMutableDictionary* usableCipherChoices = [NSMutableDictionary dictionary];
    
    
   // this code is here to allow you to select out of what cipherSuite you might have already , but limit you
   // to only a few choices.
    
    [usableCipherChoices setObject:[cipherChoices objectForKey:@(kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384)]
                            forKey:@(kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384)];

    [usableCipherChoices setObject:[cipherChoices objectForKey:@(kSCimpCipherSuite_SKEIN_AES256_ECC414)]
                            forKey:@(kSCimpCipherSuite_SKEIN_AES256_ECC414)];

   
    SCimpCipherSuite cipherSuite = [STPreferences scimpCipherSuite];
    if(![usableCipherChoices objectForKey:@(cipherSuite)])
        [usableCipherChoices setObject:[cipherChoices objectForKey:@(cipherSuite)]
                                forKey:@(cipherSuite)];
   
    [OHActionSheet showFromVC:self 
                       inView:self.view
                        title:@"Select Cipher Suite"
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:NULL
            otherButtonTitles:[usableCipherChoices allValues]
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                       
                             NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
                             
                             NSArray* items = [cipherChoices allKeysForObject:choice];
                             if(items && items.count)
                             {
                                 NSNumber* cipher = [items firstObject];
                                 [STPreferences setScimpCipherSuite: cipher.unsignedIntValue ];
                                 [self updateInfo];
                             }
                             
                         }];
    

}

- (void)handleActionBarDone
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)eraseCacheButtonTapped:(id)sender
{
	NSString *title = NSLocalizedString(@"Are you sure you want to erase the download cache?"
	                                    @" Some items might no longer be available from SCloud.",
	                                    @"Erase Download Cache warning");
	
	NSString *destructiveButton = NSLocalizedString( @"Erase Cache",  @"Erase Cache");
	
	[OHActionSheet showFromVC:self
	                   inView:self.view
	                    title:title
	        cancelButtonTitle:NSLS_COMMON_CANCEL
	   destructiveButtonTitle:destructiveButton
	        otherButtonTitles:nil
	               completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		if (buttonIndex == sheet.destructiveButtonIndex)
		{
			NSURL *scloudURL = [SCFileManager scloudCacheDirectoryURL];
			if (scloudURL)
			{
				__block NSError *error = nil;
				
				NSFileManager *fileManager = [NSFileManager defaultManager];
				NSArray *urls = [fileManager contentsOfDirectoryAtURL:scloudURL
				                           includingPropertiesForKeys:nil
				                                              options:0
				                                                error:&error];
				
				if (urls.count > 0)
				{
					HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
					HUD.labelText = NSLS_COMMON_ERASING;
					HUD.mode = MBProgressHUDModeAnnularDeterminate;
					
					[HUD showAnimated:YES whileExecutingBlock:^{
						
						float totalFiles = (float)urls.count;
						float deletedFiles = 0.0F;
						
						for (NSURL *fileURL in urls)
						{
							HUD.progress =  deletedFiles / totalFiles;
							
							// we should calculate this delay so the total spin time is about
							// a second no mater how many files.
							usleep(500);
							
							[fileManager removeItemAtURL:fileURL error:&error];
							deletedFiles += 1.0F;
						}
					
					} completionBlock:^{
						
						[self updateCacheInfo];
						
						UIImage *img = [UIImage imageNamed:@"37x-Checkmark.png"];
						
						HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
						HUD.customView = [[UIImageView alloc] initWithImage:img];
						HUD.mode = MBProgressHUDModeCustomView;
						HUD.labelText = NSLS_COMMON_COMPLETED;
						
						[self performSelector:@selector(removeProgress) withObject:NULL afterDelay:2.0];
					}];
				}
			}
		}
	}];
}


- (IBAction)experimentalAction:(id)sender {
    
    NSString * titleString = [NSString stringWithFormat:@"%@ %@",
                             NSLocalizedString( @"The Silent Circle Lab features for this release include:",
                                                @"The Silent Circle Lab features for this release include:"),
                              NSLocalizedString( @"Multiple User accounts, Group Messaging, Do Not Forward and Passcode recovery.", @"feature list")];

    [OHActionSheet showFromVC:self 
                       inView:self.view
                        title:titleString
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:NSLS_COMMON_TURN_OFF
            otherButtonTitles:@[NSLS_COMMON_TURN_ON]
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                       
                             NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
                             
                             if (buttonIndex == sheet.destructiveButtonIndex) {
                                 
                                 [STPreferences setExperimentalFeatures: NO];
//                                 [self updateInfo];
                             }
                             else if ([choice isEqualToString:NSLS_COMMON_TURN_ON])
                             {
                                 [STPreferences setExperimentalFeatures: YES];
                                 
                                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString( @"Activated Silent Circle Lab Features",  @"Activated Silent Circle Lab Features")
									 message: NSLocalizedString(@"You have chosen to activate experimental features in Silent Text. These features are not supported. Please use at your own risk. Silent Circle Lab features may be unavailable or removed without notice. We do not recommend using sensitive or important data in this environment.",
										@" Silent Circle Lab Features text")
									delegate:nil
						   cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
						   otherButtonTitles:nil];
[alert show];

//                                 [self updateInfo];
                             }
                         }];

}


- (IBAction)receiptsButtonTapped:(id)sender
{
    [OHActionSheet showFromVC:self 
                       inView:self.view
                        title:NSLocalizedString(@"Send Receipts", @"Send Receipts")
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:NSLS_COMMON_TURN_OFF
            otherButtonTitles:@[NSLS_COMMON_TURN_ON]
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
		
		if (buttonIndex == sheet.destructiveButtonIndex)
		{
			[STPreferences setDefaultSendReceipts:NO];
			[self updateInfo];
		}
		else if ([choice isEqualToString:NSLS_COMMON_TURN_ON])
		{
			[STPreferences setDefaultSendReceipts:YES];
			[self updateInfo];
		}
	}];
}


- (IBAction)notificationsButtonTapped:(id)sender
{
    NSDate* notifyTime = [STPreferences notificationDate];
	
    NSTimeInterval    delay = [notifyTime timeIntervalSinceNow];
    
    if(delay < 0)
    {
		[OHActionSheet showFromVC:self
		                   inView:self.view
		                    title:NSLocalizedString(@"Do Not Disturb", @"Do Not Disturb")
		        cancelButtonTitle:NSLS_COMMON_CANCEL
		   destructiveButtonTitle:NSLS_FOREVER
		        otherButtonTitles:@[NSLS_COMMON_FOR_1HR, NSLS_COMMON_UNTIL_8AM, ]
		               completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
		{
			NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
			
			if (buttonIndex == sheet.destructiveButtonIndex) {
				
				[STPreferences setNotificationDate: [NSDate distantFuture]];
				[self updateInfo];
			}
			else if ([choice isEqualToString:NSLS_COMMON_FOR_1HR])
			{
				[STPreferences setNotificationDate: [NSDate dateWithTimeIntervalSinceNow:(3600)]];
				[self updateInfo];
			}
			else if ([choice isEqualToString:NSLS_COMMON_UNTIL_8AM])
			{
				NSDate *now = [NSDate dateWithTimeIntervalSinceNow:24 * 60 * 60]; // 24h from now
				
				NSCalendar *calendar = [NSCalendar currentCalendar];
				
				NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth  | NSCalendarUnitDay |
				                       NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
				NSDateComponents *comps = [calendar components:units fromDate:now];
				
				[comps setHour:8];
				[comps setMinute:0];
				[comps setSecond:0];
				
				NSDate *tomorrow = [calendar dateFromComponents:comps];
				
				[STPreferences setNotificationDate: tomorrow];
				[self updateInfo];
			}
		}];
        
    }
    else
    {
        [OHActionSheet showFromVC:self 
                           inView:self.view
                            title:NSLocalizedString(@"Do Not Disturb", @"Do Not Disturb")
                cancelButtonTitle:NSLS_COMMON_CANCEL
           destructiveButtonTitle:NULL
                otherButtonTitles:@[NSLS_COMMON_TURN_OFF]
                       completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                                 
                                 NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
                                 
                                 if ([choice isEqualToString:NSLS_COMMON_TURN_OFF])
                                 {
                                     [STPreferences setNotificationDate: [NSDate distantPast]];
                                     [self updateInfo];
                                     
                                 }
                                 
                             }];
        
    }
}


- (void)removeProgress
{
	[HUD removeFromSuperview];
	HUD = nil;
}



- (IBAction)burnDelaySelectAction:(id) sender
{
	NSUInteger burnValue = [STPreferences defaultBurnTime];
	NSUInteger burnDelayIndex = [burnDelays indexForDelay:burnValue];
	_burnButton.selected = _burnStatus;
	_burnSlider.value = [self sliderValueForIndex:burnDelayIndex];
	[_burnSlider setThumbImage:[UIImage imageNamed:@"flame_on.png"] forState:UIControlStateNormal];
	_burnSlider.selected = YES;
	_burnSliderLabel.text = [burnDelays stringForDelayIndex: burnDelayIndex];
	
	CGRect frame = self.view.frame;
	frame.origin = CGPointZero;
	_burnView.frame = frame;
	//		_burnView.center = self.view.center;
	_burnView.alpha = 0.0F;
	[self.view addSubview:_burnView];
	
	[UIView animateWithDuration:0.2 animations:^{
		
		//			self.frame = frame;
		_burnView.alpha = 1.0;
	}];
	
}

- (IBAction)burnDelayDismiss:(id)sender {
	
	[UIView animateWithDuration:0.2 animations:^{
		
		_burnView.alpha = 0.0;
	}
	 completion:^(BOOL finished) {
		 [_burnView removeFromSuperview];
//		 [self updateBurnStatus];
	 }];

}

- (IBAction)toggleBurn:(id)sender {
	_burnStatus = !_burnStatus;
	[STPreferences setDefaultShouldBurn:_burnStatus];
	_burnButton.selected = _burnStatus;
    
    [self updateBurnStatus];
}

- (IBAction)burnSliderChanged:(id)sender
{
	static NSUInteger burnDelayIndex = 0;
	NSUInteger index = [self indexForSliderValue];
	if (burnDelayIndex != index)
	{
		burnDelayIndex = index;
        
   	    _burnSliderLabel.text = [burnDelays stringForDelayIndex: burnDelayIndex];
		
		[STPreferences setDefaultBurnTime:(uint32_t) [burnDelays delayInUIntForIndex:index]];
        
        [self updateBurnStatus];
 	}
    
}


- (void)updateBurnStatus
{
	NSUInteger burnValue = [STPreferences defaultBurnTime];
	NSString *burnString = _burnStatus ? [NSString stringWithFormat:@"%@ (%@)", NSLocalizedString(@"On", "On"), [burnDelays stringForDelay:burnValue]] : NSLocalizedString(@"Off", "Off");
	_burnButton.selected = _burnStatus;
	[_burnDelay setTitle:burnString forState:UIControlStateNormal];
}



- (NSUInteger)indexForSliderValue
{
	NSUInteger count = [burnDelays.values count];
	
	float min = _burnSlider.minimumValue;
	float max = _burnSlider.maximumValue;
	
	float step = (max - min) / (float)count;
	
	NSUInteger result = (NSUInteger)((_burnSlider.value - min) / step);
	
	if (result < count)
		return result;
	else
		return (count - 1);
}

- (float)sliderValueForIndex:(NSUInteger)index
{
	NSUInteger count = [burnDelays.values count];
	
	float min = _burnSlider.minimumValue;
	float max = _burnSlider.maximumValue;
	
	if (index == 0)
		return min;
	if (index == (count-1))
		return max;
	
	float step = (max - min) / (float)count;
	
	float minRangeForIndex = (min + (step * index));
	
	return minRangeForIndex + (step / 2.0);
}


@end
