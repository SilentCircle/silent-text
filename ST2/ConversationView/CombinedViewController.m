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
//  CombinedViewController.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 5/22/13.
//
#import "AppDelegate.h"

#import "CombinedViewController.h"
#import "ConversationViewController.h"
#import "MessagesViewController.h"
#import "PKRevealController.h"
#import "ComposeViewController.h"
#import "ConversationInfoViewController.h"
#import "SilentTextStrings.h"
#import "SettingsViewController.h"
#import "STUser.h"

@interface CombinedViewController ()

@end

@implementation CombinedViewController

@synthesize leftView = leftView;
@synthesize rightView = rightView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    AppDelegate * App = [self appDelegate];

    UIImage *revealImagePortrait = [UIImage imageNamed:@"reveal_menu_icon_portrait"];
    UIImage *revealImageLandscape = [UIImage imageNamed:@"reveal_menu_icon_landscape"];
  
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(usersUpdated:)
                                                 name:NOTIFICATION_USERS_UPDATED
                                               object:nil];

    if (conversationViewController == nil) {
		conversationViewController = [[self appDelegate] conversationViewController];
 	}
    
    conversationViewController.view.frame = leftView.bounds;
    [leftView addSubview:  conversationViewController.view];
    [conversationViewController didMoveToParentViewController:self];
    [self addChildViewController:conversationViewController];
    conversationViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleHeight;
    
      
	if (messagesViewController == nil) {
		messagesViewController = [[self appDelegate] messagesViewController];
  	}
     
    conversationViewController.messagesViewController = messagesViewController;
   
    messagesViewController.view.frame = rightView.bounds;
    [rightView addSubview:  messagesViewController.view];
    [messagesViewController didMoveToParentViewController:self];
    [self addChildViewController:messagesViewController];
    
    messagesViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleHeight;
  
    UIBarButtonItem *composeButton         = [[UIBarButtonItem alloc]
                                              initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                              target:self
                                              action:@selector(showComposeView:)];

    UIBarButtonItem *settingsButton   =       [[UIBarButtonItem alloc] initWithImage:revealImagePortrait
                                                               landscapeImagePhone:revealImageLandscape
                                                                               style: UIBarButtonItemStylePlain
                                                                              target: self
                                                                              action: @selector(showSettingsView:)];

    self.navigationItem.leftBarButtonItems = [NSArray arrayWithObjects: settingsButton,  composeButton, nil];
    

    self.navigationItem.rightBarButtonItem = App.conversationInfoButton;
    
     
    self.title = App.currentUser.jid;
    
}



- (void)usersUpdated:(NSNotification *)notification
{
    
    NSString *userID = [notification.userInfo objectForKey:@"userID"];
    
    AppDelegate * App = [self appDelegate];
   self.title = App.currentUser.jid;

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (AppDelegate *)appDelegate
{
	return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}
#pragma mark - PKRevealController actions

- (void)showSettingsView:(id)sender
{
    AppDelegate * App = [self appDelegate];
    
    [self.navigationController.revealController setLeftViewController:App.settingsViewNavController];
    
    if (self.navigationController.revealController.focusedController == self.navigationController.revealController.leftViewController)
    {
        [self.navigationController.revealController showViewController:self.navigationController.revealController.frontViewController];
    }
    else
    {
        [self.navigationController.revealController showViewController:self.navigationController.revealController.leftViewController];
    }
}

- (void)showRightView:(id)sender
{
    if (self.navigationController.revealController.focusedController == self.navigationController.revealController.rightViewController)
    {
        [self.navigationController.revealController showViewController:self.navigationController.revealController.frontViewController];
    }
    else
    {
        [self.navigationController.revealController showViewController:self.navigationController.revealController.rightViewController];
    }
}



- (void)showComposeView:(id)sender
{
    AppDelegate * App = [self appDelegate];

    [self.navigationController.revealController setLeftViewController:App.composeViewNavController];
    
    if (self.navigationController.revealController.focusedController == self.navigationController.revealController.leftViewController)
    {
        [self.navigationController.revealController showViewController:self.navigationController.revealController.frontViewController];
    }
    else
    {
        [self.navigationController.revealController showViewController:self.navigationController.revealController.leftViewController];
    }

  }

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [messagesViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [conversationViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];

}

@end
