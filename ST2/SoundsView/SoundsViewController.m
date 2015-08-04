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
//  SoundsViewController.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 10/21/13.
//

#import <SCCrypto/SCcrypto.h> 

#import "SoundsViewController.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "MBProgressHUD.h"
#import "OHActionSheet.h"
#import "SilentTextStrings.h"
#import "STPreferences.h"
#import "STLogging.h"
// Categories
#import "NSDate+SCDate.h"
#import "NSNumber+Filesize.h"



// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)

@interface SoundsViewController ()

@property (nonatomic, weak) IBOutlet UIView *containerView;

@property (weak, nonatomic) IBOutlet UISwitch *vibrateSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *sentMessageSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *incomingMessageSwitch;
@property (weak, nonatomic) IBOutlet UIView *lineView1;
@property (weak, nonatomic) IBOutlet UIView *lineView2;
@property (weak, nonatomic) IBOutlet UIView *lineView3;

- (IBAction)vibrateSwitchAction:(id)sender;
- (IBAction)sentMessageSwitchAction:(id)sender;
- (IBAction)incomingMessageSwitchAction:(id)sender;

@end

@implementation SoundsViewController
{
}

@synthesize containerView = containerView;
@synthesize vibrateSwitch = vibrateSwitch;
@synthesize sentMessageSwitch = sentMessageSwitch;
@synthesize incomingMessageSwitch = incomingMessageSwitch;


- (id)initWithProperNib
{
	return [self init];
}

- (id)init
{
	self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil];
    if (self) {
        // Custom initialization
        
        
 	}
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	self.navigationItem.title = NSLocalizedString(@"Sounds Options", @"Sounds Options");
	
    if (AppConstants.isIPhone)
    {
//		self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
//		self.navigationController.navigationBar.translucent = YES;
	//	self.navigationController.navigationBar.tintColor = [STPreferences navItemTintColor];
		
		self.navigationItem.leftBarButtonItem =
		  [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"Done")
		                                   style:UIBarButtonItemStylePlain
		                                  target:self
		                                  action:@selector(handleActionBarDone)];
    }

	self.edgesForExtendedLayout=UIRectEdgeNone;
	self.extendedLayoutIncludesOpaqueBars=NO;
	self.view.tintColor = [UIApplication sharedApplication].delegate.window.tintColor;
	[vibrateSwitch setOnTintColor:self.view.tintColor];
	[incomingMessageSwitch setOnTintColor:self.view.tintColor];
	[sentMessageSwitch setOnTintColor:self.view.tintColor];
	vibrateSwitch.on = [STPreferences soundVibrate];
	sentMessageSwitch.on = [STPreferences soundSentMessage];
	incomingMessageSwitch.on = [STPreferences soundInMessage];


	if (AppConstants.isIPhone) {
		
	}
	else {
		CGRect frame = self.view.frame;
		frame.size.height = 143;
		self.view.frame = frame;
	}
	if ([[UIScreen mainScreen] scale] > 1.0)
	{
		for (UIView *lineView in @[_lineView1, _lineView2, _lineView3]) {
			CGRect frame = lineView.frame;
			frame.size.height = 0.5;
			lineView.frame = frame;
		}
	}
//	{
//		CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
//		
//		CGFloat statusBarHeight = MIN(statusBarFrame.size.width, statusBarFrame.size.height);
//		CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
//		
//		CGFloat offset = statusBarHeight + navBarHeight;
//		
//		DDLogVerbose(@"Updating containerView.topConstraint = %f", offset);
//		
//		NSLayoutConstraint *constraint = [self topConstraintFor:containerView];
//		constraint.constant = offset;
//		
//		[self.view setNeedsUpdateConstraints];
//	}
	
    
}
- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait;
}


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

#pragma mark - Actions

- (void)handleActionBarDone
{
	[self dismissViewControllerAnimated:YES completion:nil];
}


- (IBAction)vibrateSwitchAction:(id)sender
{
	BOOL isOn = ((UISwitch *) sender).on;
	[STPreferences setSoundVibrate: isOn];
    
}

- (IBAction)sentMessageSwitchAction:(id)sender
{
	BOOL isOn = ((UISwitch *) sender).on;
	[STPreferences setSoundSentMessage: isOn];
    
}

- (IBAction)incomingMessageSwitchAction:(id)sender
{
	BOOL isOn = ((UISwitch *) sender).on;
	[STPreferences setSoundInMessage: isOn];
    
}

@end
