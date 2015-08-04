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
//  BurnDelayViewController.m
//  ST2
//
//  Created by mahboud on 3/20/14.
//

#import "BurnDelayViewController.h"
#import "BurnDelays.h"

@interface BurnDelayViewController ()
@property (weak, nonatomic) IBOutlet UIPickerView *picker;
@property (strong, nonatomic) BurnDelays *burnDelays;

@end

@implementation BurnDelayViewController

- (id) init
{
	self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil];
	if (self != nil) {
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	self.burnDelays = [[BurnDelays alloc] init];
						
	[_burnDelays initializeBurnDelaysWithOff:NO];

	
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
	return 1;
}
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
	switch (component) {
		case 0:
			return [_burnDelays.values count];
			break;
			
		default:
			break;
	}
	return 0;
}
//- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
//{
//	UILabel *labelView;
//	if (view == nil) {
//		labelView = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 20)];
//		labelView.textAlignment = NSTextAlignmentCenter;
//		labelView.backgroundColor = [UIColor clearColor];
//		labelView.font = [UIFont boldSystemFontOfSize:18];
//	}
//	else
//		labelView = (UILabel *) view;
//	switch (component) {
//		case 0:
//			labelView.text = [_pickerDict objectForKey:[_sortedKeysList objectAtIndex:row]];
//			break;
//			
//		default:
//			break;
//	}
//	return labelView;
//	
//}


- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	switch (component) {
		case 0:
			return [_burnDelays stringForDelayIndex:row];
			break;
			
		default:
			break;
	}
	return nil;
}

@end
