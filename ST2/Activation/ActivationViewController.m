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
//
//  ActivationViewController.m
//  Silent Phone 2
//
//  Created by Jacob Hazelgrove on 5/30/14.
//

#import "ActivationViewController.h"

#import "DRDynamicSlideShow.h"
//#import "SettingsConstants.h"
//#import "AvatarChooserViewController.h"

@interface ActivationViewController ()

@property (strong, nonatomic) IBOutlet UITextField *usernameField;
@property (strong, nonatomic) IBOutlet UITextField *passwordField;
@property (strong, nonatomic) IBOutlet UIButton *continueButton;

@property (strong, nonatomic) IBOutlet UIView *introductionView;
@property (strong, nonatomic) IBOutlet UIView *explanatoryView;
@property (strong, nonatomic) IBOutlet UIView *loginView;

@property (strong, nonatomic) NSArray *viewsForSlides;
@property (strong, nonatomic) DRDynamicSlideShow *slideShow;

- (IBAction)activate:(id)sender;

@end

@implementation ActivationViewController

- (instancetype)init {
	return [super initWithNibName:@"ActivationViewController" bundle:nil];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	
	self.slideShow = [DRDynamicSlideShow new];
	self.viewsForSlides = @[self.introductionView, self.explanatoryView, self.loginView];
	
	[self.slideShow setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
	[self.slideShow setAlpha:0];
	
	[self.view addSubview:self.slideShow];
	[self.view endEditing:YES];
	
	[self setupSlideShowSubviewsAndAnimations];
}

#pragma mark Slide Show

- (void)setupSlideShowSubviewsAndAnimations
{
    for (UIView *pageView in self.viewsForSlides) {
        CGFloat verticalOrigin = self.slideShow.frame.size.height/2-pageView.frame.size.height/2;
		
        for (UIView *subview in pageView.subviews) {
            [subview setFrame:CGRectMake(subview.frame.origin.x, verticalOrigin+subview.frame.origin.y, subview.frame.size.width, subview.frame.size.height)];
            [self.slideShow addSubview:subview onPage:pageView.tag];
        }
    }
	
#pragma mark Page 0
	
    UILabel *label11 = (UILabel *)[self.slideShow viewWithTag:11];
	
    [self.slideShow addAnimation:[DRDynamicSlideShowAnimation animationForSubview:label11 page:0 keyPath:@"center" toValue:[NSValue valueWithCGPoint:CGPointMake(label11.center.x+self.slideShow.frame.size.width, label11.center.y-self.slideShow.frame.size.height)] delay:0]];
	
    UITextView *description12 = (UITextView *)[self.slideShow viewWithTag:12];
	
    [self.slideShow addAnimation:[DRDynamicSlideShowAnimation animationForSubview:description12 page:0 keyPath:@"alpha" toValue:@0 delay:0]];
	
    [self.slideShow addAnimation:[DRDynamicSlideShowAnimation animationForSubview:description12 page:0 keyPath:@"center" toValue:[NSValue valueWithCGPoint:CGPointMake(description12.center.x+self.slideShow.frame.size.width, description12.center.y+self.slideShow.frame.size.height*2)] delay:0]];
	
#pragma mark Page 1
	
    UITextView *magicStickDescriptionTextView = (UITextView *)[self.slideShow viewWithTag:21];
	
    [self.slideShow addAnimation:[DRDynamicSlideShowAnimation animationForSubview:magicStickDescriptionTextView page:0 keyPath:@"transform" fromValue:[NSValue valueWithCGAffineTransform:CGAffineTransformMakeRotation(-0.9)] toValue:[NSValue valueWithCGAffineTransform:CGAffineTransformMakeRotation(0)] delay:0]];
	
#pragma mark Page 2
	
	[self.usernameField setReturnKeyType:UIReturnKeyNext];
	[self.usernameField addTarget:self action:@selector(moveToPasswordField:) forControlEvents:UIControlEventEditingDidEndOnExit];
	
    [self.slideShow addAnimation:[DRDynamicSlideShowAnimation animationForSubview:self.usernameField page:1 keyPath:@"alpha" fromValue:@0 toValue:@1 delay:0.75]];
	
	[self.passwordField setReturnKeyType:UIReturnKeyDone];
	[self.passwordField addTarget:self action:@selector(keyboardDismiss:) forControlEvents:UIControlEventEditingDidEndOnExit];
	
    [self.slideShow addAnimation:[DRDynamicSlideShowAnimation animationForSubview:self.passwordField page:1 keyPath:@"alpha" fromValue:@0 toValue:@1 delay:0.75]];
	
	[self.continueButton setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
	[self.continueButton setTitleColor:[UIColor lightTextColor] forState:UIControlStateDisabled];
	[self.continueButton setTitleColor:[UIColor purpleColor] forState:UIControlStateHighlighted];
	[self.continueButton setTitleColor:[UIColor greenColor] forState:UIControlStateSelected];
	
	[self.continueButton addTarget:self action:@selector(activate:) forControlEvents:UIControlEventTouchUpInside];
    [self.continueButton setCenter:CGPointMake(self.continueButton.center.x-self.slideShow.frame.size.width, self.continueButton.center.y+self.slideShow.frame.size.height)];
	
	[self.slideShow addAnimation:[DRDynamicSlideShowAnimation animationForSubview:self.continueButton page:1 keyPath:@"center" toValue:[NSValue valueWithCGPoint:CGPointMake(self.continueButton.center.x+self.slideShow.frame.size.width, self.continueButton.center.y-self.slideShow.frame.size.height)] delay:0]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
	
    [UIView animateWithDuration:0.6 delay:0.2 options:UIViewAnimationOptionCurveEaseInOut animations: ^{
        [self.slideShow setAlpha:1];
    } completion:nil];
}

- (void)moveToPasswordField:(id)sender {
	[self.passwordField becomeFirstResponder];
}

- (void)keyboardDismiss:(id)sender {
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];
}

#pragma mark TextView Delegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	if ((self.usernameField.text.length > 0) && (self.passwordField.text.length > 3)) {
		self.continueButton.enabled = YES;
	}
	
	else {
		self.continueButton.enabled = NO;
	}
	
	return YES;
}

- (IBAction)activate:(id)sender {
	[self keyboardDismiss:self];
	
//	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kHasShownFirstLaunchUI];
//	[[NSUserDefaults standardUserDefaults] synchronize];
//	
//	AvatarChooserViewController *avatarChooserViewController = [AvatarChooserViewController new];
//	avatarChooserViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
//		
////	avatarChooserViewController.avatarCreationDidEnd = ^() {
////		[self dismissViewControllerAnimated:NO completion:nil];
////	};
//	
//	[self presentViewController:avatarChooserViewController animated:NO completion:nil];
}

@end
