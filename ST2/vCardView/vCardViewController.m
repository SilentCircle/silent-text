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
//
//  vCardViewController.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 10/21/13.
//

#import "vCardViewController.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "STPreferences.h"
#import "NSDictionary+vCard.h"
#import "AddressBookManager.h"
#import "AvatarManager.h"
#import "MBProgressHUD.h"
#import "SilentTextStrings.h"
#import "UIImage+Thumbnail.h"
#import "ECPhoneNumberFormatter.h"
#import "STUser.h"
#import "SCloudPreviewer.h"
#import "AppTheme.h"
#import "STLogging.h"
#import "STUserManager.h"


// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_INFO | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@interface vCardViewController ()

@property (nonatomic, strong) SCloudObject    *scloud;
@property (nonatomic, strong) NSString        *cardName;
@end

@implementation vCardViewController
{
	AppTheme *theme;
    CGFloat displayNameCenterYOffset;
	
    NSDictionary *personInfo;
	
	MBProgressHUD *HUD;
    SCloudPreviewer *scp;
}

@synthesize containerView = containerView;

@synthesize userImageView = userImageView;
@synthesize displayNameLabel = displayNameLabel;
@synthesize organizationLabel = organizationLabel;
@synthesize userNameLabel = userNameLabel;
@synthesize spPhone = spPhone;

@synthesize importABButton;
@synthesize importSCButton;
@synthesize previewButton;

- (id)initWithSCloud:(SCloudObject*)inScloud
{
	if ((self = [super initWithNibName:@"vCardViewController" bundle:nil]))
	{
		_scloud = inScloud;
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
	DDLogAutoTrace();
    [super viewDidLoad];
    
	NSData *fileData = [NSData dataWithContentsOfURL:_scloud.decryptedFileURL];
	NSArray *people = [NSDictionary peopleFromvCardData:fileData];
	personInfo = [people firstObject];
	
	// Configure UI
	
	theme = [AppTheme getThemeBySelectedKey];
	
	self.navigationItem.title = NSLocalizedString(@"Contact Info", @"Contact Info");
	
	if (AppConstants.isIPhone)
	{
		self.navigationItem.leftBarButtonItem =
		  [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"Done")
		                                   style:UIBarButtonItemStylePlain
		                                  target:self
		                                  action:@selector(doneButtonTapped:)];
	}
    
    // Search constraints.
	// Find centerY offset for displayName.
	
	NSLayoutConstraint *constraint = [self centerYConstraintFor:displayNameLabel];
	if (constraint){
		displayNameCenterYOffset = constraint.constant;
	}
	
	// Add constraint between containerView & topLayoutGuide
	
	NSLayoutConstraint *topLayoutGuideConstraint =
	  [NSLayoutConstraint constraintWithItem:containerView
	                               attribute:NSLayoutAttributeTop
	                               relatedBy:NSLayoutRelationEqual
	                                  toItem:self.topLayoutGuide
	                               attribute:NSLayoutAttributeBottom
	                              multiplier:1.0
	                                constant:0.0];
	
	[self.view removeConstraint:[self topConstraintFor:containerView]];
	[self.view addConstraint:topLayoutGuideConstraint];
	
	// Register for notifications
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(applicationDidEnterBackground:)
	                                             name:UIApplicationDidEnterBackgroundNotification
	                                           object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
	
//	NSDictionary * metaData = _scloud.metaData;
//	NSString* filename = [metaData objectForKey:kSCloudMetaData_FileName];
//	NSString* vCardName = [filename stringByDeletingPathExtension];
//    
   
	UIImage *image = [personInfo objectForKey:@"thumbNail"];
    if (image == nil)
		image = [UIImage imageNamed:@"silhouette.png"];
    
    image = [image scaledAvatarImageWithDiameter:50];
    image = [image avatarImageWithDiameter:50 usingColor:theme.appTintColor];
    
    userImageView.image = image;
    
	NSString * displayName = [personInfo objectForKey:@"compositeName"];
	NSString * userName    = [personInfo objectForKey:@"userName"];
	NSString * jidStr      = [personInfo objectForKey:@"jid"];
    
	organizationLabel.text = [personInfo objectForKey:@"organization"];

	NSString *spPhoneNumber = [personInfo objectForKey:@"phone_silent circle"];
    if (spPhoneNumber == nil)
		spPhoneNumber = [personInfo objectForKey:@"phone_silent phone"];

	if (spPhoneNumber)
    {
        ECPhoneNumberFormatter *formatter = [[ECPhoneNumberFormatter alloc] init];
        spPhone.text = [formatter stringForObjectValue:spPhoneNumber];
        [spPhone setHidden:NO];
    }
    else
	{
        [spPhone setHidden:YES];
	}
    
    if (jidStr)
    {
		XMPPJID *realJID = [XMPPJID jidWithString:jidStr];
		
        if ([realJID.domain isEqualToString:kDefaultAccountDomain]) {
            userNameLabel.text = realJID.user;
        }
		else if (realJID) {
			userNameLabel.text = [realJID bare];
		}
		else {
			userNameLabel.text = jidStr;
		}
    }
	else
	{
		userNameLabel.text = userName?:@"-none-";
	}
	
    displayNameLabel.text = (displayName.length > 0) ? displayName : userName;

	importSCButton.enabled = jidStr != NULL;
	
	if (_scloud.fyeo)
	{
		[previewButton setEnabled:NO];
		[importSCButton setEnabled:NO];
		[importABButton setEnabled:NO];
	}
	
    //
	// Update constraints
	//
	
	if ([organizationLabel.text length] > 0)
	{
		// Unhide organization label
		
		organizationLabel.hidden = NO;
		
		// Revert Y constraints to original values
		
		NSLayoutConstraint *displayNameYConstraint = [self centerYConstraintFor:displayNameLabel];
		displayNameYConstraint.constant = displayNameCenterYOffset;
		
		[containerView setNeedsUpdateConstraints];
	}
	else
	{
		// Hide organization label
		
		organizationLabel.hidden = YES;
		
		// Update Y constraint for displayName to center on userImage
		
		NSLayoutConstraint *displayNameYConstraint = [self centerYConstraintFor:displayNameLabel];
		displayNameYConstraint.constant = 0.0F;
		
		[containerView setNeedsUpdateConstraints];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillDisappear:animated];
	
	// Why ?
    _scloud = NULL;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSLayoutConstraint *)topConstraintFor:(id)item
{
	for (NSLayoutConstraint *constraint in self.view.constraints)
	{
		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeTop) ||
		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeTop))
		{
			return constraint;
		}
	}
	
	return nil;
}

- (NSLayoutConstraint *)centerYConstraintFor:(id)item
{
	for (NSLayoutConstraint *constraint in containerView.constraints)
	{
		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeCenterY) ||
		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeCenterY))
		{
			return constraint;
		}
	}
	
	return nil;
}

- (void)removeHUDAfterDelay:(NSTimeInterval)delay
{
	__weak MBProgressHUD *prevHUD = HUD;
	__weak vCardViewController *weakSelf = self;
	
	dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
	dispatch_after(when, dispatch_get_main_queue(), ^{
	#pragma clang diagnostic push
	#pragma clang diagnostic warning "-Wimplicit-retain-self"
		
		__strong vCardViewController *strongSelf = weakSelf;
		if (strongSelf && (prevHUD == strongSelf->HUD))
		{
			[strongSelf->HUD removeFromSuperview];
			strongSelf->HUD = nil;
		}
		
	#pragma clang diagnostic pop
	});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	if ([self.delegate respondsToSelector:@selector(vCardViewController:needsHidePopoverAnimated:)]) {
		[self.delegate vCardViewController:self needsHidePopoverAnimated:NO];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)doneButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
	[self.navigationController popViewControllerAnimated:YES];
}

/*ET 02/03/15
 * ST-916 DEPRECATED - remove shared vCard and calendar preview feature;
 * preview workflow will be re-written */
- (IBAction)previewButtonTapped:(id)sender
{
    NSAssert(false, @"THIS METHOD HAS BEEN DEPRECATED at line %d",__LINE__);
    return;
	
	if ([self.delegate respondsToSelector:@selector(vCardViewController:previewVCard:)]) {
        [self.delegate vCardViewController:self previewVCard:_scloud];
    }
}

- (IBAction)importABButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
    NSData *vCard =  [personInfo objectForKey:@"vCard"];
 
    HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText =  NSLocalizedString(@"Updating AddressBook", @"Updating AddressBook title");
    HUD.mode = MBProgressHUDModeIndeterminate;

	[HUD show:YES];
	
	[[AddressBookManager sharedInstance] addvCardToAddressBook:vCard completion:^(BOOL success) {
		
		NSAssert([NSThread isMainThread],
		         @"CompletionBlocks are expected to be on the main thread (unless explicitly stated otherwise)");
		
		if (success)
        {
			HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
			
			HUD.labelText = NSLS_COMMON_COMPLETED;
			HUD.mode = MBProgressHUDModeCustomView;
			
			[HUD show:YES];
			[self removeHUDAfterDelay:2.0];
        }
        else
        {
			HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"attention"]];
			HUD.labelText = NSLocalizedString(@"Import Failed",@"Import Failed");
			HUD.mode = MBProgressHUDModeCustomView;
			
			[HUD show:YES];
			[self removeHUDAfterDelay:3.0];
		}
		
	}];
}

- (IBAction)importSCButtonTapped:(id)sender
{
	DDLogAutoTrace();
    
    HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText =  NSLocalizedString(@"Updating Silent Contacts", @"Updating Silent Contacts");
    HUD.mode = MBProgressHUDModeIndeterminate;
    
    [HUD show:YES];
    
	[[STUserManager sharedInstance] importSTUserFromDictionary:personInfo
	                                           completionBlock:^(NSError *error, NSString *uuid)
	{
		NSAssert([NSThread isMainThread],
		        @"CompletionBlocks should always be on the main thread (unless explicitly stated otherwise)");
		
		if (error)
		{
			HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"attention"]];
			HUD.labelText = NSLocalizedString(@"Import Failed",@"Import Failed");
			HUD.mode = MBProgressHUDModeCustomView;
			
			[HUD show:YES];
			[self removeHUDAfterDelay:3.0];
		}
		else
		{
			HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
			
			HUD.labelText = NSLS_COMMON_COMPLETED;
			HUD.mode = MBProgressHUDModeCustomView;
			
			[HUD show:YES];
			[self removeHUDAfterDelay:2.0];
		}
	}];
}

@end
