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
//  ChatOptionsView.m
//  GearsReplacement
//

#import "ChatOptionsView.h"
#import "ChatOptionsViewController.h"
#import <QuartzCore/QuartzCore.h>

@implementation ChatOptionsView
@synthesize burnButton;
@synthesize mapButton;
@synthesize phoneButton;
@synthesize micButton;
@synthesize addrBookButton;
@synthesize moreButton;
@synthesize cameraButton;
@synthesize delegate;
//@synthesize chatOptions;

- (id)init
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        // Initialization code
    }
    return self;
}
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/
- (void) unfurlOnView:(UIView*)view under:(UIView*)underview  atPoint:(CGPoint) point
{
	if ([self superview]) {
		[self resetFadeOut];
		return;
	}
	[self.layer setBorderColor:[[UIColor colorWithWhite: 0 alpha:0.5] CGColor]];
	[self.layer setBorderWidth:1.0f];
	// set a background color
	[self.layer setBackgroundColor:[[UIColor colorWithWhite: 0.2 alpha:0.60] CGColor]];
	// give it rounded corners
	[self.layer setCornerRadius:10.0];
	// add a little shadow to make it pop out
	[self.layer setShadowColor:[[UIColor blackColor] CGColor]];
	[self.layer setShadowOpacity:0.75];
	
	isMapOn = [delegate getIncludeLocationState];
	mapButton.selected = isMapOn;
	isBurnOn = [delegate getBurnNoticeState];
	burnButton.selected = isBurnOn;
    isPhoneOn = [delegate getPhoneState];
	phoneButton.enabled = isPhoneOn;
	phoneButton.selected = isPhoneOn;

	CGFloat height = self.frame.size.height;
	CGFloat width = view.frame.size.width;
	self.frame = CGRectMake(0,//point.x - self.frame.size.width/ 2,
							0, width, height);
//	CGFloat spacing = width / 7;
//	CGPoint center;
//	center.y = height / 2;
//	center.x = spacing * 0.5;
//	burnButton.center = center;
//	center.x = spacing * 1.5;
//	cameraButton.center = center;
//	center.x = spacing * 2.5;
//	mapButton.center = center;
//	center.x = spacing * 3.5;
//	micButton.center = center;
//	center.x = spacing * 4.5;
//	phoneButton.center = center;
//	center.x = spacing * 5.5;
//	addrBookButton.center = center;
//	center.x = spacing * 6.5;
//	moreButton.center = center;
	self.alpha = 0.0;
	self.clipsToBounds = YES;

//	[view addSubview:self];
	[view insertSubview:self belowSubview:underview];
	[UIView animateWithDuration:0.5f
					 animations:^{
						 [self setAlpha:1.0];
//						 self.frame = CGRectMake(self.frame.origin.x,
//												 point.y,
//												 width,
//												 height);
						 CGRect parentFrame = view.frame;
						 parentFrame.size.height += height;
						 parentFrame.origin.y -= height;
						 view.frame = parentFrame;
						 //			 self.center = CGPointMake(self.center.x, point.y - self.frame.size.height /2);


					 }
					 completion:^(BOOL finished) {
						 [self resetFadeOut];
						 self.clipsToBounds = NO;
//						 CGRect newFrame = [underview convertRect: self.frame fromView: view];
//						 [self removeFromSuperview];
//						 self.frame = newFrame;
//						 
//						 [underview addSubview:self];
					 }];

}

- (void) resetFadeOut
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
	[self performSelector:@selector(fadeOut) withObject:nil afterDelay:4.];

}

- (void) fadeOut
{
	CGFloat height = self.frame.size.height;
	self.clipsToBounds = YES;
	[UIView animateWithDuration:0.5f
					 animations:^{
						 [self setAlpha:0.0];
//						 self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + height, self.frame.size.width, 0);
						 CGRect parentFrame = self.superview.frame;
						 parentFrame.size.height -= height;
						 parentFrame.origin.y += height;
						 self.superview.frame = parentFrame;

					 }
					 completion:^(BOOL finished) {
						 [self removeFromSuperview];
//						 self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + height, self.frame.size.width, height);
					 }];

}
- (void) layoutSubviews {
	CGFloat width = self.frame.size.width;
	CGFloat height = self.frame.size.height;

	NSMutableArray *buttonArray = [NSMutableArray arrayWithObjects:cameraButton, micButton, addrBookButton, burnButton, mapButton, phoneButton, moreButton, nil];
	for (UIButton *button in buttonArray) {
		button.hidden = YES;
	}

	NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
	if ([currSysVer compare:@"5.9" options:NSNumericSearch] == NSOrderedAscending) {
		[buttonArray removeObject:micButton];
	}
	if (!isPhoneOn) {
		[buttonArray removeObject:phoneButton];
	}
	CGFloat spacing = width / [buttonArray count];
	CGFloat y = height/2;
	CGFloat x = 0;
	for (UIButton *button in buttonArray) {
		x += spacing * 0.5;
		button.center = CGPointMake(x, y);
		x += spacing * 0.5;
		button.hidden = NO;
	}
	
//	CGFloat spacing = width / 7;
//	CGPoint center;
//	center.y = height / 2;
//	center.x = spacing * 0.5;
//	cameraButton.center = center;
//	center.x = spacing * 1.5;
//	micButton.center = center;
//	center.x = spacing * 2.5;
//	addrBookButton.center = center;
//	center.x = spacing * 3.5;
//	burnButton.center = center;
//	center.x = spacing * 4.5;
//	mapButton.center = center;
//	center.x = spacing * 5.5;
//	phoneButton.center = center;
//	center.x = spacing * 6.5;
//	moreButton.center = center;

}
- (BOOL) isVisible
{
	return [self superview] ? YES : NO;
}

- (void) hide
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
	[self fadeOut];
}

- (IBAction)mapAction:(id)sender {
	[delegate setIncludeLocationState:!isMapOn];
	isMapOn = [delegate getIncludeLocationState];
	mapButton.selected = isMapOn;
	[self resetFadeOut];
}

- (IBAction)burnAction:(id)sender {
	isBurnOn = !isBurnOn;
	burnButton.selected = isBurnOn;
	[delegate setBurnNoticeState:isBurnOn];
	[self resetFadeOut];
}

- (IBAction)phoneAction:(id)sender {
	[delegate phoneAction:sender];
    [self resetFadeOut];

}

- (IBAction)micAction:(id)sender {
	[delegate micAction:sender];
}

- (IBAction)contactAction:(id)sender {
	[delegate contactAction:sender];
}


- (IBAction)cameraAction:(id)sender{
	[delegate cameraAction:sender];
}


- (IBAction)moreOptionsAction:(id)sender {
	if ([delegate respondsToSelector:@selector(pushChatOptionsViewController)]) {
		[delegate pushChatOptionsViewController];
	}

}
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self resetFadeOut];
}

@end
