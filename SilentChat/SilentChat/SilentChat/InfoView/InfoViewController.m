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
//  InfoViewController.m
//  SilentChat
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "InfoViewController.h"

#import "LicensesViewController.h"
#import "LoginViewController.h"

#import "SCAccount.h"
#import "App.h"

#import "UIDevice+TTDevice.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

@interface InfoViewController ()
@end

@implementation InfoViewController

@synthesize feedbackButton = _feedbackButton;
@synthesize username = _username;
@synthesize versionLabel = _versionLabel;
@synthesize scimpVersionLabel = _scimpVersionLabel;



- (void) viewDidLoad {
	
	DDGTrace();
    
    [super viewDidLoad];
    
    App *app = App.sharedApp;
    
    char scimp_version_string[32];
    SCimpGetVersionString(sizeof(scimp_version_string) , scimp_version_string);
    
    self.versionLabel.text =  [NSString stringWithFormat: @"Silent Text: %@", app.fullVersion];
    self.scimpVersionLabel.text = [NSString stringWithFormat: @"SCimp: v%s", scimp_version_string];
    self.username.text = [[XMPPJID jidWithString: app.currentAccount.username] user];
	self.feedbackButton.enabled = MFMailComposeViewController.canSendMail;
    
} // -viewDidLoad


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark - MFMailComposeViewControllerDelegate Methods


- (void) showAlert: (NSString *) message {
	
	static NSString *const kOK        = @"OK";
	static NSString *const kMailError = @"There was a problem with your mail.";
	
	UIAlertView *av = [[UIAlertView alloc] initWithTitle: kMailError 
                                                 message: message 
                                                delegate: self 
                                       cancelButtonTitle: nil 
                                       otherButtonTitles: kOK, nil];
	[av show];
	
} // showAlert


// Dismisses the email composition interface when users tap Cancel or Send. Proceeds to update the message field with the result of the operation.
- (void) mailComposeController: (MFMailComposeViewController*) controller 
		   didFinishWithResult: (MFMailComposeResult) result 
						 error: (NSError*) error {
	
	static NSString *const kFailedSave = @"It was not saved.";
	static NSString *const kFailedSend = @"It was not sent.";
	
	// Notifies users about errors associated with the interface
	switch (result) {
			
		case MFMailComposeResultCancelled:
			
			DDGDesc(@"Result: canceled");
			break;
			
		case MFMailComposeResultSaved:
			
			DDGDesc(@"Result: saved");
			break;
			
		case MFMailComposeResultSent:
			
			DDGDesc(@"Result: sent");
			break;
			
		case MFMailComposeResultFailed:
			
			DDGDesc(@"Result: failed");
			
			if ([[error domain] isEqualToString: MFMailComposeErrorDomain]) {
				
				if ([error code] == MFMailComposeErrorCodeSaveFailed) {
					
					[self showAlert: kFailedSave];
				} 
				else if ([error code] == MFMailComposeErrorCodeSendFailed) {
					
					[self showAlert: kFailedSend];
				}
			}
			break;
			
		default:
			
			DDGDesc(@"Result: Who knows what happened?");
			break;
	}
    [self.navigationController popViewControllerAnimated: YES];
	
} // -mailComposeController:didFinishWithResult:error:


#pragma mark - IBAction methods.


- (IBAction) changeUser:  (UIButton *) sender {
	
	DDGTrace();
	
    LoginViewController *lvc = [[LoginViewController alloc] 
                                initWithNibName: @"LoginViewController" 
                                bundle: nil];
    // Present the login view and pop ourselves off. 
    // One less tap to get to the new account.
    [self.navigationController presentViewController: lvc 
                                            animated: YES 
                                          completion: ^{ [self.navigationController popViewControllerAnimated: NO]; }];

} // -changeUser:


- (IBAction) emailFeedback: (UIButton *) feedbackButton {
	
	DDGTrace();
	
	static NSString *const kThankYou = @"Thank you for using Silent Text™.\n\n";
	static NSString *const kHearYou  = 
	@"We want to hear about your experiences with and provide support for Silent Text on your ";
    
	DDGTrace();

	MFMailComposeViewController *mailer = MFMailComposeViewController.new;
	mailer.mailComposeDelegate = self;
	mailer.navigationBar.barStyle = UIBarStyleBlack;
    
	[mailer setToRecipients: [NSArray arrayWithObject: @" <Support@SilentCircle.com>"]];
	[mailer setSubject:      @"Feedback to the Silent Text team..."];
    
	// Fill out the email body text
	NSString *emailBody = [NSString stringWithFormat: @"%@%@%@ (iOS v%@).\n\n\n\n\n\n\n\n",
                           kThankYou, kHearYou, 
                           [[UIDevice currentDevice] machineNameLong],
                           [[UIDevice currentDevice] systemVersion]];
    
	[mailer setMessageBody: emailBody isHTML: NO];
	
    [self.navigationController pushViewController: mailer.viewControllers.lastObject animated: YES];
	
} // -emailFeedback:


- (IBAction) legalNotices:  (UIButton *) sender {
	
	DDGTrace();
	
	LicensesViewController *lvc = [LicensesViewController.alloc initWithNibName: @"LicensesViewController" bundle: nil];
    
	[self.navigationController pushViewController: lvc animated: YES];
	
} // -legalNotices:

@end
