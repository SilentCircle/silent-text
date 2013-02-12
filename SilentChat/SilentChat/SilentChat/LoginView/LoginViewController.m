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
//  LoginViewController.m
//  SilentText
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "LoginViewController.h"

#import "SCAccount.h"
#import "ConversationManager.h"
#import "App+Model.h"
#import "ServiceCredential.h"
#import "SCPPServer.h"

#import "MGLoadingView.h"
#import "NetworkActivityIndicator.h"
#import "NSManagedObjectContext+DDGManagedObjectContext.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

@interface LoginViewController ()

@property (strong, nonatomic) SCAccount *oldAccount;
@property (strong, nonatomic) NSArray   *oldConversations;
@property (nonatomic, strong) MGLoadingView *loadingView;

@end

@implementation LoginViewController

@synthesize username = _username;
@synthesize password = _password;
@synthesize loginButton = _loginButton;
@synthesize cancelButton = _cancelButton;

@synthesize oldAccount = _oldAccount;
@synthesize oldConversations = _oldConversations;
@synthesize loadingView = _loadingView;

#pragma mark - Accessor methods.


- (MGLoadingView *) loadingView {
    
    if (_loadingView) { return _loadingView; }
    
    MGLoadingView *lv = [MGLoadingView.alloc initWithView: self.view 
                                                    label: @"Logging In ..."];
    self.loadingView = lv;
    
    return lv;
    
} // -loadingView


#pragma mark - UIView lifecycle methods.


- (void) viewDidLoad {
    
    DDGTrace();
    
    [super viewDidLoad];
    
    [App.sharedApp.xmppServer disconnectAfterSending];

} // -viewDidLoad


- (void) viewWillAppear: (BOOL) animated {
    
    DDGTrace();
    
    [super viewWillAppear: animated];
    
    SCAccount *account = App.sharedApp.currentAccount;

    self.username.text = account.jid.user;
    self.password.text = account.password;
    
    [self.username becomeFirstResponder];
    
} // -viewWillAppear:


- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) interfaceOrientation {
    
    return (interfaceOrientation == UIInterfaceOrientationPortrait);

} // -shouldAutorotateToInterfaceOrientation:


#pragma mark - Action methods.


- (LoginViewController *) loginWithAccount: (SCAccount *) account {
    
    XMPPStream *xmppStream = [App.sharedApp.xmppServer changeServiceServer: account.serviceServer];
    
    [xmppStream addDelegate: self delegateQueue: dispatch_get_main_queue()];
    
    [App.sharedApp.xmppServer connect];
    
    return self;
    
} // -loginWithAccount:


- (SCAccount *) makeAccount {
    
    DDGTrace();
    
    NSManagedObjectContext *moc = App.sharedApp.moc;
    
    SCAccount *account = nil;
    
    account = [NSEntityDescription insertNewObjectForEntityForName: kSCAccountEntity 
                                            inManagedObjectContext: moc];
    
    XMPPJID *domainJID = [XMPPJID jidWithString: account.username]; // Use the default domain and resource.
    XMPPJID *  userJID = [XMPPJID jidWithUser: self.username.text 
                                       domain: domainJID.domain 
                                     resource: domainJID.resource];
    account.username = userJID.full;
    account.password = self.password.text;
    
    return account;
    
} // -makeAccount


- (BOOL) requiresANewAccount {
    
    SCAccount *currentAccount = App.sharedApp.currentAccount;
    
    if (currentAccount) {
        
        NSString *currentUsername = [[XMPPJID jidWithString: currentAccount.username] user];
        
        return ![currentUsername isEqualToString: self.username.text];
    }
    return YES;
    
} // -requiresANewAccount


- (BOOL) useNewPassword {
    
    return ![App.sharedApp.currentAccount.password isEqualToString: self.password.text];
    
} // -useNewPassword


- (IBAction)  loginAction: (UIButton *)  loginButton {
    
    DDGTrace();
    
    App *app = App.sharedApp;
    
    if (self.requiresANewAccount) {
        
        if (app.currentAccount) {
            
            // Save the old account and conversations.
            self.oldAccount = app.currentAccount;
            self.oldConversations = app.conversationManager.conversations;
        }
        SCAccount *account = [self makeAccount];
        
        [app.moc save]; // Force the AccountID to become permanent before using it as the current account.
        
        [app useNewAccount: account];
        
        [self loginWithAccount: account];
    }
    else if (self.useNewPassword) {
        
        app.currentAccount.password = self.password.text;

        [self loginWithAccount: app.currentAccount];
    }
    else {
        
        [self loginWithAccount: app.currentAccount];
    }
    [app.moc save];
        
} // -loginAction:


- (IBAction) cancelAction: (UIButton *) cancelButton {
    
    DDGTrace();

    App *app = App.sharedApp;

    if (self.oldAccount && ![self.oldAccount isEqualToAccount: app.currentAccount]) {
        
        [app.moc deleteObject: app.currentAccount];
        
        [app useNewAccount: self.oldAccount];
        
        [app.moc save];
    }
    if (app.currentAccount) {
        
        [app.xmppServer connect];
    }
    [self dismissViewControllerAnimated: YES completion: NULL];

} // -cancelAction:


#pragma mark - XMPPStreamDelegate methods.


- (void) xmppStreamWillConnect: (XMPPStream *) xmppStream {
    
    DDGTrace();
    
    [NetworkActivityIndicator.sharedNetworkActivityIndicator startNetworkActivityIndicator];
    
    MGLoadingView *lv = self.loadingView;
    
    [self.view addSubview: lv];
    
    [lv.activityIndicatorView startAnimating];
    [lv fadeIn];
    
    self.username.enabled     = NO;
    self.password.enabled     = NO;
    self.loginButton.enabled  = NO;
    self.cancelButton.enabled = NO;
    
    [self.username resignFirstResponder];
    [self.password resignFirstResponder];
    
} // -xmppStreamWillConnect:


- (LoginViewController *) deleteOldAccount {
    
    if (self.oldAccount) {
        
        NSManagedObjectContext *moc = self.oldAccount.managedObjectContext;
        
        for (Conversation *conversation in self.oldConversations) {
            
            [moc deleteObject: conversation];
        }
        [moc deleteObject: self.oldAccount];
        
        [moc save];
    }
    return self;
    
} // -deleteOldAccount


- (void) xmppStreamDidAuthenticate: (XMPPStream *) xmppStream {
    
    DDGTrace();
    
    [xmppStream removeDelegate: self];
    
    [NetworkActivityIndicator.sharedNetworkActivityIndicator stopNetworkActivityIndicator];

    [self.loadingView.activityIndicatorView stopAnimating];
    [self.loadingView fadeOut];
    
    [self deleteOldAccount];
    
    [self dismissViewControllerAnimated: YES completion: NULL];
    
} // -xmppStreamDidAuthenticate:


- (void) showLoginFailureAlert {
    
    UIAlertView *av = [[UIAlertView alloc] initWithTitle: @"Login" 
                                                 message: @"The server did not accept either your username or your password. Please try again." 
                                                delegate: nil 
                                       cancelButtonTitle: nil 
                                       otherButtonTitles: kOKButton, nil];
    [av show];
    
} // -showLoginFailureAlert


- (void) xmppStream: (XMPPStream *) xmppStream didNotAuthenticate: (NSXMLElement *) error {
    
    DDGTrace();
    
    [xmppStream removeDelegate: self];
    
    [NetworkActivityIndicator.sharedNetworkActivityIndicator stopNetworkActivityIndicator];

    [self.loadingView.activityIndicatorView stopAnimating];
    [self.loadingView fadeOut];
    
    self.username.enabled     = YES;
    self.password.enabled     = YES;
    self.loginButton.enabled  = YES;
    self.cancelButton.enabled = YES;

    [self showLoginFailureAlert];
    
} // -xmppStream:didNotAuthenticate:

@end
