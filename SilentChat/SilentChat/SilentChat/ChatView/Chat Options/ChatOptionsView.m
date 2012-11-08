/*
Copyright © 2012, Silent Circle
All rights reserved.

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
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "ChatOptionsView.h"
#import "ChatOptionsViewController.h"
#import <QuartzCore/QuartzCore.h>

@implementation ChatOptionsView
@synthesize burnButton;
@synthesize mapButton;
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
- (void) unfurlOnView:(UIView*)view atPoint:(CGPoint) point
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

	CGFloat height = self.frame.size.height;
	self.frame = CGRectMake(0,//point.x - self.frame.size.width/ 2,
							point.y, self.frame.size.width, 0);
	self.alpha = 0.0;
	[view addSubview:self];
	[UIView animateWithDuration:0.5f
					 animations:^{
						 [self setAlpha:1.0];
						 self.frame = CGRectMake(self.frame.origin.x,
												 point.y - height,
												 self.frame.size.width,
												 height);
						 //			 self.center = CGPointMake(self.center.x, point.y - self.frame.size.height /2);


					 }
					 completion:^(BOOL finished) {
						 [self resetFadeOut];
					 }];

}

- (void) resetFadeOut
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
	[self performSelector:@selector(fadeOut) withObject:nil afterDelay:2.];

}

- (void) fadeOut
{
	CGFloat height = self.frame.size.height;
	[UIView animateWithDuration:0.5f
					 animations:^{
						 [self setAlpha:0.0];
						 self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + height, self.frame.size.width, 0);

					 }
					 completion:^(BOOL finished) {
						 [self removeFromSuperview];
						 self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + height, self.frame.size.width, height);
					 }];

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

- (IBAction)callAction:(id)sender {
	[delegate callAction:sender];
}

- (IBAction)contactAction:(id)sender {
	[delegate contactAction:sender];
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
