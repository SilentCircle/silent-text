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
//  ProvisionViewController.m
//  SilentText
//

#import <Foundation/Foundation.h>

#import "AppConstants.h"

#import "App.h"


#import "SCAccount.h"
#import "ConversationManager.h"
#import "App+Model.h"
#import "SCPPServer.h"
#import "NSManagedObjectContext+DDGManagedObjectContext.h"
#import "MBProgressHUD.h"

#import "NetworkActivityIndicator.h"
 
#import "ProvisionViewController.h"
#import "SilentTextStrings.h"


#define USE_SRV_RECORDS 1

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif
 
@interface ProvisionViewController () <UITextFieldDelegate, UIGestureRecognizerDelegate, MBProgressHUDDelegate>

@property (nonatomic, strong) MBProgressHUD *HUD;
@property (nonatomic, strong) SCProvisoning *provisioning;

- (void)limitTextField:(NSNotification *)note ;
@end


@implementation ProvisionViewController


@synthesize activationCode = _activationCode;
@synthesize activateButton = _activateButton;
@synthesize signupButton = _signupButton;
@synthesize resetButton = _resetButton;
@synthesize versionLabel = _versionLabel;

@synthesize HUD = _HUD;
@synthesize provisioning = _provisioning;

#pragma mark - Accessor methods.
 
#pragma mark - Textfield customization methods.

- (void)limitTextField:(NSNotification *)note {
    int limit = 8;
    if ([self.activationCode.text length] > limit) {
        self.activationCode.text  = [self.activationCode.text substringToIndex:limit];
    }
    
    self.activateButton.enabled = ([self.activationCode.text length] == 8 );
}



- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
 
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(limitTextField:) name:@"UITextFieldTextDidChangeNotification" object:self.activationCode];
    }
    return self;
}
 

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string {
    
    for (int i = 0; i < [string length]; i++) {
        unichar c = [string characterAtIndex:i];
        if (![[NSCharacterSet alphanumericCharacterSet] characterIsMember:c]) {
            return NO;
        }
    }
 
    // Check if the added string contains lowercase characters.
    // If so, those characters are replaced by uppercase characters.
    // But this has the effect of losing the editing point
    // (only when trying to edit with lowercase characters),
    // because the text of the UITextField is modified.
    // That is why we only replace the text when this is really needed.
    NSRange lowercaseCharRange;
    lowercaseCharRange = [string rangeOfCharacterFromSet:[NSCharacterSet lowercaseLetterCharacterSet]];
    
    if (lowercaseCharRange.location != NSNotFound) {
        
        textField.text = [textField.text stringByReplacingCharactersInRange:range
                                                                 withString:[string uppercaseString]];
        return NO;
    }
 
    return YES;
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
#pragma unused(textField)
    
    return  (NO);
}


#pragma mark - Provision View.

- (void)viewDidLoad
{
    [super viewDidLoad];
   
    NSBundle *main = NSBundle.mainBundle;
    NSString *version = [main objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    NSString *build   = [main objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
    NSString *appVersion = [NSString stringWithFormat: @"%@: %@ (%@)", NSLS_COMMON_VERSION, version, build];

    self.versionLabel.text =  appVersion;

    self.provisioning = [[SCProvisoning alloc] initWithDelegate: self];
    
    [self.signupButton      setTitle: NSLS_COMMON_SIGN_UP forState:UIControlStateNormal];
    [self.activateButton    setTitle: NSLS_COMMON_ACTIVATE forState:UIControlStateNormal];
    
    self.activateButton.enabled     = NO;
    
    [App.sharedApp.xmppServer disconnectAfterSending];
    
    [App.sharedApp resetAccounts];

    if([SCProvisoning isProvisioned])
    {
        UIImage *buttonImage = [UIImage imageNamed:@"BurningCircle_1.png"];
        [self.resetButton setImage:buttonImage forState:UIControlStateNormal];
        self.resetButton.enabled = YES;
        self.resetButton.hidden = NO;
     }
 }

- (void)viewDidUnload
{
    [super viewDidUnload];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait;
}



- (void) stopActivityIndicator
{
    [NetworkActivityIndicator.sharedNetworkActivityIndicator stopNetworkActivityIndicator];
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
     
    self.activationCode.enabled     = YES;
    self.activateButton.enabled  = YES;
    self.signupButton.enabled = YES;
}

- (void) startActivityIndicator
{
    
    [NetworkActivityIndicator.sharedNetworkActivityIndicator startNetworkActivityIndicator];
    
    
    self.HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.HUD.delegate = self;
    self.HUD.mode = MBProgressHUDModeIndeterminate;
    self.HUD.labelText = NSLS_COMMON_ACTIVATING;
      
    self.activationCode.enabled     = NO;
    self.activateButton.enabled  = NO;
    self.signupButton.enabled = NO;
    
    [self.activationCode resignFirstResponder];
}


#pragma mark - accounts

- (ProvisionViewController *) loginWithAccount: (SCAccount *) account {
    
    XMPPStream *xmppStream = [App.sharedApp.xmppServer changeAccount: account];
    
    [xmppStream addDelegate: self delegateQueue: dispatch_get_main_queue()];
    
    [App.sharedApp.xmppServer connect];
    
    return self;
    
} // -loginWithAccount:



- (SCAccount *) makeAccountwithInfo: (NSDictionary*) info {
  
    NSString *string = nil;
    
    NSString *  username = nil;
    NSString*   password = nil;
    
      if ((string = [info valueForKey:@"username"])) {
        username = string;
    }
    if ((string = [info valueForKey:@"password"])) {
        password = string;
    }
     
    NSManagedObjectContext *moc = App.sharedApp.moc;
    
    SCAccount *account = nil;
    
    account = [NSEntityDescription insertNewObjectForEntityForName: kSCAccountEntity
                                            inManagedObjectContext: moc];
    
    account.username = username;
    account.password = password;
    account.serverDomain = NULL;
    account.serverPort =  0;

    return account;
    
} // -makeAccount



#pragma mark - Provisioning


- (void) provisioningError:(NSError *)error
{
    [self stopActivityIndicator];
    
     [[[UIAlertView alloc] initWithTitle:NSLS_COMMON_PROVISION_ERROR
                                message:
        ( ![error.domain isEqualToString: kSCErrorDomain]
         ? error.localizedDescription
         : [NSString stringWithFormat:NSLS_COMMON_PROVISION_ERROR_DETAIL,
                                          error.localizedDescription])
                               delegate:nil
                      cancelButtonTitle:NSLS_COMMON_OK
                      otherButtonTitles:nil] show];
}

- (void) provisionCompletedWithInfo: (NSDictionary*) info
{
    self.HUD.labelText = NSLS_COMMON_LOGGING_IN;
    
    App *app = App.sharedApp;
    SCAccount *account = [self makeAccountwithInfo: info];
    
    [app.moc save];
    [app useNewAccount: account];
    [self loginWithAccount: account];

}
 

#pragma mark - UI Actions

 - (IBAction) swipeDown: (UISwipeGestureRecognizer *) gestureRecognizer {
	
	if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        
        [self.activationCode resignFirstResponder];
	}

}

- (IBAction)  activateAction: (UIButton *)  activateButton
{
    [self startActivityIndicator];
    
    [self.provisioning startActivationProcessWithCodeString:  self.activationCode.text];
}

- (IBAction) signupAction: (UIButton *) signupButton
{
     UIApplication *app = [UIApplication sharedApplication];
  
    NSURL *url = [NSURL URLWithString: kSilentCircleSignupURL];    
    
   [app openURL:url];
     
}

- (IBAction) resetItem: (UIBarButtonItem *) sender
{
    [SCProvisoning resetProvisioning];
 
    self.resetButton.enabled = NO;
    self.resetButton.hidden = YES;
}


#pragma mark - XMPPStreamDelegate methods.


- (void) xmppStreamWillConnect: (XMPPStream *) xmppStream {
    
     
} // -xmppStreamWillConnect:

 
- (void)xmppStreamDidDisconnect:(XMPPStream *)xmppStream withError:(NSError *)error
{
 
    [xmppStream removeDelegate: self];
    
    [NetworkActivityIndicator.sharedNetworkActivityIndicator stopNetworkActivityIndicator];
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    self.activationCode.enabled = YES;
    self.activateButton.enabled = YES;
    self.signupButton.enabled   = YES;
    
    [self showLoginFailureAlert:error];
    

}


- (void) xmppStreamDidAuthenticate: (XMPPStream *) xmppStream {
 
    [xmppStream removeDelegate: self];
    
    [NetworkActivityIndicator.sharedNetworkActivityIndicator stopNetworkActivityIndicator];
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
   
//    [self deleteOldAccount];
    
    [self dismissViewControllerAnimated: YES completion: NULL];
    
    [[[UIAlertView alloc] initWithTitle:@"Welcome to Silent Circle"
                                message:@"start texting!"
                               delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    
    
} // -xmppStreamDidAuthenticate:


- (void) showLoginFailureAlert:(NSError *)error{
    
    UIAlertView *av = [[UIAlertView alloc] initWithTitle: @"Login"
                                                 message: error
                                                    ? error.localizedDescription
                                                    : @"The server did not accept either your username or your password. Please try again."
                                                delegate: nil
                                       cancelButtonTitle: nil
                                       otherButtonTitles: @"OK", nil];
    [av show];
    
} // -showLoginFailureAlert


- (void) xmppStream: (XMPPStream *) xmppStream didNotAuthenticate: (NSXMLElement *) error {
        
    [xmppStream removeDelegate: self];
    
     [NetworkActivityIndicator.sharedNetworkActivityIndicator stopNetworkActivityIndicator];
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
 
    self.activationCode.enabled = YES;
    self.activateButton.enabled = YES;
    self.signupButton.enabled   = YES;
    
    [self showLoginFailureAlert:NULL];
    
} // -xmppStream:didNotAuthenticate:

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UITextFieldTextDidChangeNotification" object:self.activationCode];
}


#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[self.HUD removeFromSuperview];
	self.HUD = nil;
}


@end
