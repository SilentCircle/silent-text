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


#import "GearContentViewController.h"

#import "AppConstants.h"
#import "App.h"
#import "GeoTracking.h"

@interface GearContentViewController ()
@end

@implementation GearContentViewController

@synthesize fyeoSwitch = _fyeoSwitch;
@synthesize burnTime = _burnTime;
@synthesize burnSwitch = _burnSwitch;
@synthesize trackingSwitch = _trackingSwitch;

@synthesize tracking = _tracking;
@synthesize fyeo = _fyeo;
@synthesize shredAfter = _shredAfter;

#pragma mark - Accessor methods.

- (BOOL) isFyeo {
    
    _fyeo = self.fyeoSwitch ? self.fyeoSwitch.isOn : _fyeo; 
    
    return _fyeo;
    
} // -isFyeo


- (BOOL) fyeo {
    
    return self.isFyeo;
    
} // -fyeo


- (void) setFyeo: (BOOL) fyeo {

    _fyeo = fyeo;
    self.fyeoSwitch.on = fyeo;
    
} // -setFyeo:


- (BOOL) isTracking {
    
    _tracking = self.trackingSwitch ? self.trackingSwitch.isOn : _tracking;
    
    return _tracking;
    
} // -isTracking


- (BOOL) tracking {
    
    return self.isTracking;
    
} // -tracking


- (void) setTracking: (BOOL) tracking {
    
    _tracking = tracking;
    self.trackingSwitch.on = tracking;
    
} // -setTracking:




- (uint32_t) shredAfter {
    
    if (self.burnTime) {
        
        
        NSTimeInterval burnafter =   self.burnTime.countDownDuration;
        
        
        _shredAfter =    self.burnSwitch.isOn?  burnafter  : kShredAfterNever;
     }

    
    return _shredAfter;
    
} // -shredAfter


- (void) setShredAfter: (uint32_t) shredAfter {

    _shredAfter = shredAfter;
    
    if( shredAfter == kShredAfterNever)
    {
        self.burnSwitch.on = NO;
        self.burnTime.enabled = NO;
        self.burnTime.hidden = YES;
        self.burnTime.countDownDuration = 0;
     }
    else
    {
        self.burnSwitch.on = YES;
        self.burnTime.enabled = YES;
        self.burnTime.hidden = NO;
        self.burnTime.countDownDuration = shredAfter ;
        
    }
       
        
 } // -setShredAfter:


-(IBAction)burnTimeAction:(id)sender
{
    self.burnSwitch.on =  self.burnTime.countDownDuration > 0;
     
}

-(IBAction)burnSwitchAction:(id)sender
{
	float duration = sender ? 0.25 : 0.0;
    if(! self.burnSwitch.isOn)
    {
 		[UIView animateWithDuration:duration
							  delay:0
							options:UIViewAnimationOptionAllowUserInteraction
						 animations:^{
							 self.burnTime.alpha = 0.0;
						 }
						 completion:^(BOOL finished) {
							 self.burnTime.enabled = NO;
							 self.burnTime.hidden = YES;
							 self.burnTime.countDownDuration = 0;
							 [UIView animateWithDuration:duration
												   delay:0
												 options:UIViewAnimationOptionAllowUserInteraction
											  animations:^{
												  CGRect rect = self.view.frame;
												  rect.size.height = 349 - 228;
												  self.view.frame = rect;
											  }
											  completion:NULL];
 						 }];
	}
    else
    {
		[UIView animateWithDuration:duration
							  delay:0
							options:UIViewAnimationOptionAllowUserInteraction
						 animations:^{
							 CGRect rect = self.view.frame;
							 rect.size.height = 349;
							 self.view.frame = rect;
						 }
						 completion:^(BOOL finished) {
							 self.burnTime.hidden = NO;
							 self.burnTime.alpha = 0;
							 [UIView animateWithDuration:duration
												   delay:0
												 options:UIViewAnimationOptionAllowUserInteraction
											  animations:^{
												  self.burnTime.alpha = 1.0;
											  }
											  completion:^(BOOL finished) {
												  self.burnTime.enabled = YES;
											  }];
						 }];
    }
    
//    self.burnTime.enable = self.burnSwitch.isOn;
}


- (void) viewDidLoad {
    
    [super viewDidLoad];

    // Load the UI state by reassigning the value to the setter.
    self.fyeo = _fyeo;
    self.shredAfter = _shredAfter;
    self.tracking = _tracking;
    
    
} // -viewDidLoad

- (void) viewWillAppear:(BOOL)animated
{
    /* MZ-  here is how you tell if the track switch is OK to enable */
    App *app = App.sharedApp;
    BOOL enableTrackingSwitch =  (app.geoTracking.allowTracking && app.geoTracking.isTracking);
   
	[super viewWillAppear:animated];
	[self burnSwitchAction:nil];

}

@end
