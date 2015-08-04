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
#import "ChatOptionsView.h"
#import <QuartzCore/QuartzCore.h>
#import "BurnDelays.h"
#import "STPreferences.h"
#import "AppConstants.h"

@interface ChatOptionsView ()
@property (nonatomic, strong) IBOutlet UIView *buttonsView;
@property (nonatomic, strong) IBOutlet UIView *burnView;
@property (nonatomic, strong) IBOutlet UIView *fyeoView;
@property (nonatomic, weak) IBOutlet UILabel *fyeoLabel;

@property (nonatomic, strong) IBOutlet UIView *geoView;

@property (nonatomic, strong) IBOutlet UIView *cameraView;
@property (nonatomic, strong) IBOutlet UIView *phoneView;

@property (nonatomic, weak) IBOutlet UIButton *burnButton;
@property (nonatomic, weak) IBOutlet UIButton *phoneButton;
@property (nonatomic, weak) IBOutlet UIButton *cameraButton;
@property (nonatomic, weak) IBOutlet UIButton *addrBookButton;
@property (nonatomic, weak) IBOutlet UIButton *micButton;
@property (nonatomic, weak) IBOutlet UIButton *fyeoButton;

@property (nonatomic, weak) IBOutlet UISlider *burnSlider;
@property (nonatomic, weak) IBOutlet UILabel *burnLabel;
@property (weak, nonatomic) IBOutlet UIButton *burnMasterButton;

@end

@implementation ChatOptionsView
{
	BOOL isMapOn;
	BOOL isBurnOn;
	BOOL isPhoneOn;
    BOOL isCameraOn;
	BOOL isFyeoOn;
    BOOL isAudioOn;
    BOOL isPaperClipOn;
	NSUInteger burnDelayIndex;
	NSTimer *fadeOutTimer;
	NSTimeInterval fadeOutInterval;
    BOOL fadingSuspended;
	
	BOOL isShowingBurnOptions;
	BOOL burnSliderActive;
	
	BOOL isShowingGeoInfo;
	BOOL isShowingFyeoInfo;
	BOOL isShowingCameraInfo;
	BOOL isShowingPhoneInfo;
	BurnDelays *burnDelays;
//	NSDictionary *burnDelayDict;
//    
//	NSUInteger burnDelayIndex;
//	NSArray *burnDelays;
}

@synthesize delegate = delegate;

@synthesize visible;
@synthesize fadeOutTimeout = fadeOutInterval;

@synthesize buttonsView;
@synthesize burnView = burnView;
@synthesize fyeoView = fyeoView;
@synthesize geoView = geoView;
@synthesize cameraView= cameraView;
@synthesize phoneView= phoneView;


@synthesize burnButton;
@synthesize mapButton;
@synthesize phoneButton;
@synthesize micButton;
@synthesize addrBookButton;
@synthesize cameraButton;
@synthesize fyeoButton;
@synthesize paperclipButton;

@synthesize burnSlider;
@synthesize burnLabel;
@synthesize burnMasterButton;

@synthesize fyeoLabel;

#pragma mark Init

- (id)init
{
	return [self initWithFrame:CGRectZero];
}

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		[self commonInit];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]))
	{
		[self commonInit];
	}
	return self;
}

- (void)commonInit
{
    fadingSuspended = NO;
}

+(id)loadChatView
{
	NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"ChatOptionsView" owner:self options:nil];
	return nib[0];
}

- (void)showChatOptionsView
{
	visible = YES;

	CGRect chatOptionsStartFrame = self.frame;
	CGRect chatOptionsFinishFrame = self.frame;
	CGPoint origin = CGPointZero;
	CGFloat height = chatOptionsFinishFrame.size.height;
	
	chatOptionsStartFrame.origin = origin;
	chatOptionsStartFrame.size.height = 0;
	chatOptionsStartFrame.size.width = self.superview.frame.size.width;
	
	chatOptionsFinishFrame.origin.x = origin.x;
	chatOptionsFinishFrame.origin.y = origin.y - height;
	chatOptionsFinishFrame.size.height = height;
	chatOptionsFinishFrame.size.width = self.superview.frame.size.width;
	//
	//	CGRect chatOptionsStartingFrame = chatOptionsFinishFrame;
	//	chatOptionsStartingFrame.origin.y = origin.y + inputView.frame.size.height;
	//
	//	chatOptionsView.frame = chatOptionsStartingFrame;
	//
	
	//	inputView.backgroundColor = [UIColor yellowColor];
	self.frame = chatOptionsStartFrame;
	//	[self.view insertSubview:chatOptionsView belowSubview:inputView];
	
	[UIView animateWithDuration:.25f animations:^{
		
		self.frame = chatOptionsFinishFrame;
	}];
}

- (void)hideChatOptionsView
{
	visible = NO;

	CGRect resetFrame = self.frame;
	CGRect covFinishFrame = self.frame;
	covFinishFrame.origin = CGPointZero;
	covFinishFrame.size.height = 0;
	
	[UIView animateWithDuration:0.15f animations:^{
		
		self.frame = covFinishFrame;
		
	} completion:^(BOOL finished) {
		
		[self removeFromSuperview];
		self.frame = resetFrame;
		
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Custom Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setFadeOutTimeout:(NSTimeInterval)timeout
{
	fadeOutInterval = timeout;
	[self resetFadeOutTimer];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (NSUInteger)indexForSliderValue
{
	NSUInteger count = [burnDelays.values count];
	
	float min = burnSlider.minimumValue;
	float max = burnSlider.maximumValue;
	
	float step = (max - min) / (float)count;
	
	NSUInteger result = (NSUInteger)((burnSlider.value - min) / step);
	
	if (result < count)
		return result;
	else
		return (count - 1);
}

- (float)sliderValueForIndex:(NSUInteger)index
{
	NSUInteger count = [burnDelays.values count];
	
	float min = burnSlider.minimumValue;
	float max = burnSlider.maximumValue;
	
	if (index == 0)
		return min;
	if (index == (count-1))
		return max;
	
	float step = (max - min) / (float)count;
	
	float minRangeForIndex = (min + (step * index));
	
	return minRangeForIndex + (step / 2.0);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup & Layout
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)willMoveToSuperview:(UIView *)newSuperview
{
	// set background color
	[self.layer setBackgroundColor:[[UIColor colorWithWhite:0.2 alpha:0.60] CGColor]];
	// give it rounded corners
//	[self.layer setCornerRadius:10.0];
	// add a border
	[self.layer setBorderColor:[[UIColor colorWithWhite:0 alpha:0.5] CGColor]];
	[self.layer setBorderWidth:1.0f];
	// add a little shadow to make it pop out
//	[self.layer setShadowColor:[[UIColor blackColor] CGColor]];
//	[self.layer setShadowOpacity:0.75];
	
	// Configure burnView similarly
	[burnView.layer setBackgroundColor:[[UIColor colorWithWhite:0.2 alpha:0.60] CGColor]];
	[burnView.layer setCornerRadius:10.0];
	
	// Configure geoView similarly
	[geoView.layer setBackgroundColor:[[UIColor colorWithWhite:0.2 alpha:0.60] CGColor]];
	[geoView.layer setCornerRadius:10.0];
	
	// Configure fyeoView similarly
	[fyeoView.layer setBackgroundColor:[[UIColor colorWithWhite:0.2 alpha:0.60] CGColor]];
	[fyeoView.layer setCornerRadius:10.0];
	
 	// Configure cameraView similarly
	[cameraView.layer setBackgroundColor:[[UIColor colorWithWhite:0.2 alpha:0.60] CGColor]];
	[cameraView.layer setCornerRadius:10.0];
    
   	// Configure phoneView similarly
	[phoneView.layer setBackgroundColor:[[UIColor colorWithWhite:0.2 alpha:0.60] CGColor]];
	[phoneView.layer setCornerRadius:10.0];
  
   	// Initialize UI states
	
	isMapOn = [delegate getIncludeLocationState];
	mapButton.selected = isMapOn;
	isBurnOn = [delegate getBurnNoticeState];
	burnButton.selected = isBurnOn;
    isPhoneOn = [delegate getPhoneState];
	phoneButton.enabled = YES;
	phoneButton.selected = isPhoneOn;
  
    isCameraOn = [delegate getCameraState];
 	cameraButton.enabled = YES;
	cameraButton.selected = isCameraOn;
    
    isPaperClipOn = [delegate getPaperClipState];
 	paperclipButton.enabled = isPaperClipOn;
	paperclipButton.selected = isPaperClipOn;

    isAudioOn = [delegate getAudioState];
 	micButton.enabled = isAudioOn;
	micButton.selected = isAudioOn;
    if([STPreferences experimentalFeatures])
    {
		isFyeoOn = [delegate getFYEOState];
        fyeoButton.enabled = YES;
		fyeoButton.hidden = NO;
    	fyeoButton.selected = isFyeoOn;
		fyeoLabel.text  = NSLocalizedString(@"Do not forward", @"Do not forward");
    }
    else
    {
		isFyeoOn = NO;
        fyeoButton.enabled = NO;
        fyeoButton.hidden = YES;
        fyeoLabel.text  = NSLocalizedString(@"Feature Disabled", @"Feature Disabled");
    }

//	uint32_t delay = [delegate getBurnNoticeDelay];
//	burnDelayIndex = [burnDelays indexForDelay:delay];
//	
//	burnSlider.value = [self sliderValueForIndex:burnDelayIndex];
//    [burnSlider setThumbImage:[UIImage imageNamed:@"flame_off.png"] forState:UIControlStateSelected];
//    [burnSlider setThumbImage:[UIImage imageNamed:@"flame_on.png"] forState:UIControlStateNormal];
//	burnSlider.selected = !isBurnOn;
//    burnLabel.text = [burnDelays stringForDelayIndex: burnDelayIndex];
}

- (void)didMoveToSuperview
{
	[self resetFadeOutTimer];
}

- (void)layoutSubviews
{
	CGFloat width = self.buttonsView.frame.size.width;
//	CGFloat height = self.buttonsView.frame.size.height;
	
	NSMutableArray *buttonArray;
	if([STPreferences experimentalFeatures]) {
		 buttonArray = [NSMutableArray arrayWithObjects:
                                   paperclipButton,
                                   cameraButton,
                                   micButton,
                                   addrBookButton,
                                   burnButton,
                                   mapButton,
                                   fyeoButton,
                                   phoneButton,
                                   nil];
	}
	else {
		buttonArray = [NSMutableArray arrayWithObjects:
                                   paperclipButton,
                                   cameraButton,
                                   micButton,
                                   addrBookButton,
                                   burnButton,
                                   mapButton,
                                   phoneButton,
                                   nil];
	}
	
    [addrBookButton setHidden: YES];
    [buttonArray removeObject:addrBookButton];
    
	for (UIButton *button in buttonArray) {
		button.hidden = YES;
	}

	NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
	if ([currSysVer compare:@"5.9" options:NSNumericSearch] == NSOrderedAscending) {
		[buttonArray removeObject:micButton];
	}
//	if (!isPhoneOn) {
//		[buttonArray removeObject:phoneButton];
//	}
//
//    if (!isCameraOn) {
//		[buttonArray removeObject:cameraButton];
//	}
//    
    
	CGFloat spacing = width / [buttonArray count];
//	CGFloat y = height/2;
	CGFloat x = 0;
	for (UIButton *button in buttonArray) {
		x += spacing * 0.5;
		button.center = CGPointMake(x, button.center.y);
		x += spacing * 0.5;
		button.hidden = NO;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark FadeOut Timer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)suspendFading:(BOOL)shouldSuspend
{
	fadingSuspended = shouldSuspend;
	if (fadingSuspended)
	{
		[fadeOutTimer invalidate];
	}
	else
	{
		[self fadeOutTimerFire:fadeOutTimer];
	}
}

- (void)resetFadeOutTimer
{
	[fadeOutTimer invalidate];
	
	if (self.superview != nil && !burnSliderActive)
	{
		fadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:fadeOutInterval
		                                                target:self
		                                              selector:@selector(fadeOutTimerFire:)
		                                              userInfo:nil
		                                               repeats:NO];
	}
}

- (void)fadeOutTimerFire:(NSTimer *)aTimer
{
	if (isShowingBurnOptions)
	{
		[self hideBurnOptions];
		[self resetFadeOutTimer];
	}
	else if (isShowingFyeoInfo)
	{
		[self hideFyeoInfo];
		[self resetFadeOutTimer];
	}
	else if (isShowingGeoInfo)
	{
		[self hideGeoInfo];
		[self resetFadeOutTimer];
	}
   	else if (isShowingCameraInfo)
	{
		[self hideCameraInfo];
		[self resetFadeOutTimer];
	}
   	else if (isShowingPhoneInfo)
	{
		[self hidePhoneInfo];
		[self resetFadeOutTimer];
	}
    
	 if ([delegate respondsToSelector:@selector(fadeOut:)])
	{
		[delegate fadeOut:self];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)burnAction:(id)sender
{
	if (burnDelays == nil) {
		burnDelays = [[BurnDelays alloc] init];
		[burnDelays initializeBurnDelaysWithOff:YES];
	}
	[self resetFadeOutTimer];
		
	[self hideGeoInfo];
	[self hideFyeoInfo];
    [self hideCameraInfo ];
    [self hidePhoneInfo];

	
	[self showBurnOptions];
}

- (IBAction)mapAction:(id)sender
{

// VINNIE - timed share my location
#if 1
     [self resetFadeOutTimer];

 	[delegate sendLocationAction:sender];
 
#else
    [delegate setIncludeLocationState:!isMapOn];
	
	isMapOn = [delegate getIncludeLocationState];
	mapButton.selected = isMapOn;
	
	[self hideBurnOptions];
	[self hideFyeoInfo];
    [self hideCameraInfo ];
    [self hidePhoneInfo];

    if (isMapOn)
		[self showGeoInfo];
	else
		[self hideGeoInfo];
    
#endif
    
}

- (IBAction)phoneAction:(id)sender
{
    [self hideBurnOptions];
	[self hideGeoInfo];
 	[self hideCameraInfo];
    
    if (isPhoneOn)
        [delegate phoneAction:sender];
    else
    {
        if (isShowingPhoneInfo)
            [self hidePhoneInfo];
        else
            [self showPhoneInfo];
    }
	[self resetFadeOutTimer];

 }

- (IBAction)paperclipAction:(id)sender
{
	[self resetFadeOutTimer];
	[delegate paperclipAction:sender];
}

- (IBAction)micAction:(id)sender
{
	[self resetFadeOutTimer];
	[delegate micAction:sender];
}

- (IBAction)contactAction:(id)sender
{
	[self resetFadeOutTimer];
	[delegate contactAction:sender];
}

- (IBAction)cameraAction:(id)sender
{
    [self hideBurnOptions];
	[self hideGeoInfo];
 	[self hidePhoneInfo];
    
    if (isCameraOn)
        [delegate cameraAction:sender];
    else
    {
        if (isShowingCameraInfo)
             [self hideCameraInfo];
        else
             [self showCameraInfo];
    }
	[self resetFadeOutTimer];

}

- (IBAction)fyeoAction:(id)sender
{
	[self resetFadeOutTimer];
	
	isFyeoOn = !isFyeoOn;
	fyeoButton.selected = isFyeoOn;
	
	[delegate setFYEOState:isFyeoOn];
	
	[self hideBurnOptions];
	[self hideGeoInfo];
    [self hideCameraInfo ];
    [self hidePhoneInfo];
 	
	if (isFyeoOn)
		[self showFyeoInfo];
	else
		[self hideFyeoInfo];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Burn Options
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
	// The default code
	if (CGRectContainsPoint(self.bounds, point))
		return YES;
	
	// The chatOptionsView is outside the bounds of our inputView.
	// We extend this method to include taps within this area.
	CGPoint newPoint = [self convertPoint:point fromView:self.superview];

	for (UIView *subview in self.subviews)
	{
		NSLog(@"%@: point %@, newPOint %@, frame %@", NSStringFromClass([subview class]), NSStringFromCGPoint(point), NSStringFromCGPoint(newPoint), NSStringFromCGRect(subview.frame));
		if (CGRectContainsPoint(subview.frame, newPoint))
			return YES;
	}
	return NO;
}


- (void)updateBurnSlider
{
	uint32_t delay = [delegate getBurnNoticeDelay];
	burnDelayIndex = [burnDelays indexForDelay:delay];
	
	burnSlider.value = [self sliderValueForIndex:burnDelayIndex];
	burnSlider.selected = !isBurnOn;
	burnLabel.text = [burnDelays stringForDelayIndex: burnDelayIndex];
}

- (void)showBurnOptions
{
	if (!isShowingBurnOptions)
	{
		[burnSlider setThumbImage:[UIImage imageNamed:@"flame_off.png"] forState:UIControlStateSelected];
		[burnSlider setThumbImage:[UIImage imageNamed:@"flame_on.png"] forState:UIControlStateNormal];
		[self updateBurnSlider];

		CGRect frame = self.frame;
		CGRect optionsFrame = burnView.frame;
		
		optionsFrame.origin.x = 5;
		optionsFrame.origin.y = -35;
		optionsFrame.size.width = frame.size.width - 10;
		
		frame.origin.y -= optionsFrame.size.height + 5;
		frame.size.height += optionsFrame.size.height + 5;
		
		burnView.frame = optionsFrame;
		burnView.alpha = 0.0F;
		[self addSubview:burnView];
		
		[UIView animateWithDuration:0.2 animations:^{
			
//			self.frame = frame;
			burnView.alpha = 1.0;
		}];
		
		isShowingBurnOptions = YES;
		burnMasterButton.selected = isBurnOn;
		if (!isBurnOn) {
			[self toggleBurn:burnButton];
		}
	}
}

- (void)hideBurnOptions
{
	if (isShowingBurnOptions)
	{
		CGRect frame = self.frame;
		CGRect burnFrame = burnView.frame;
		
		frame.origin.y += burnFrame.size.height + 5;
		frame.size.height -= burnFrame.size.height + 5;
		
		[UIView animateWithDuration:0.2 animations:^{
			
			self.frame = frame;
			burnView.alpha = 0.0;
			
		} completion:^(BOOL finished) {
			
			if (!isShowingBurnOptions)
				[burnView removeFromSuperview];
		}];
		
		isShowingBurnOptions = NO;
	}
}

- (void)setBurn:(BOOL) state
{
	isBurnOn = state;
	burnButton.selected = state;
	burnSlider.selected = !state;
	burnMasterButton.selected = state;
	
	[delegate setBurnNoticeState:state];
}

- (IBAction)toggleBurn:(id)sender
{
	[self resetFadeOutTimer];
    
    BOOL newState = !isBurnOn;
	[self setBurn: newState];
    
     [self updateBurnSlider];

}


- (IBAction)burnSliderChanged:(id)sender
{
	[self resetFadeOutTimer];
	
	NSUInteger index = [self indexForSliderValue];
	NSUInteger delay = 0;
	if (burnDelayIndex != index)
	{
		burnDelayIndex = index;
        
   	    burnLabel.text = [burnDelays stringForDelayIndex: burnDelayIndex];

		delay = [burnDelays delayInUIntForIndex:index];
		[delegate setBurnNoticeDelay:(uint32_t)delay];
		if (isBurnOn) {
			if (delay == 0)
				[self setBurn:NO];
		}
		else {
			if (delay != 0)
				[self setBurn:YES];
		}
	}
}

- (IBAction)burnSliderTouchDown:(id)sender
{
	burnSliderActive = YES;
	[self resetFadeOutTimer];
}

- (IBAction)burnSliderTouchUp:(id)sender
{
	burnSliderActive = NO;
	[self resetFadeOutTimer];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Geo Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (void)setMap:(BOOL) state
{
	isMapOn = state;
	mapButton.selected = state;
  	
 }

- (void)showGeoInfo
{
	if (!isShowingGeoInfo)
	{
		CGRect selfFrame = self.frame;
		CGRect geoFrame = geoView.frame;
		
		geoFrame.origin.x = 5;
		geoFrame.origin.y = -35;
		geoFrame.size.width = selfFrame.size.width - 10;
		
		selfFrame.origin.y -= geoFrame.size.height + 5;
		selfFrame.size.height += geoFrame.size.height + 5;
		
		geoView.frame = geoFrame;
		geoView.alpha = 0.0F;
		[self addSubview:geoView];
		
		[UIView animateWithDuration:0.2 animations:^{
			
//			self.frame = selfFrame;
			geoView.alpha = 1.0;
		}];
		
		isShowingGeoInfo = YES;
	}
}

- (void)hideGeoInfo
{
	if (isShowingGeoInfo)
	{
		CGRect selfFrame = self.frame;
		CGRect geoFrame = geoView.frame;
		
		selfFrame.origin.y += geoFrame.size.height + 5;
		selfFrame.size.height -= geoFrame.size.height + 5;
		
		[UIView animateWithDuration:0.2 animations:^{
			
			self.frame = selfFrame;
			geoView.alpha = 0.0;
			
		} completion:^(BOOL finished) {
			
			if (!isShowingGeoInfo)
				[geoView removeFromSuperview];
		}];
		
		isShowingGeoInfo = NO;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark FYEO Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)showFyeoInfo
{
	if (!isShowingFyeoInfo)
	{
		CGRect selfFrame = self.frame;
		CGRect fyeoFrame = fyeoView.frame;
		
		fyeoFrame.origin.x = 5;
		fyeoFrame.origin.y = -35;
		fyeoFrame.size.width = selfFrame.size.width - 10;
		
		selfFrame.origin.y -= fyeoFrame.size.height + 5;
		selfFrame.size.height += fyeoFrame.size.height + 5;
		
		fyeoView.frame = fyeoFrame;
		fyeoView.alpha = 0.0F;
		[self addSubview:fyeoView];
		
		[UIView animateWithDuration:0.2 animations:^{
			
//			self.frame = selfFrame;
			fyeoView.alpha = 1.0;
		}];
		
		isShowingFyeoInfo = YES;
	}
}

- (void)hideFyeoInfo
{
	if (isShowingFyeoInfo)
	{
		CGRect selfFrame = self.frame;
		CGRect fyeoFrame = fyeoView.frame;
		
		selfFrame.origin.y += fyeoFrame.size.height + 5;
		selfFrame.size.height -= fyeoFrame.size.height + 5;
		
		[UIView animateWithDuration:0.2 animations:^{
			
			self.frame = selfFrame;
			fyeoView.alpha = 0.0;
			
		} completion:^(BOOL finished) {
			
			if (!isShowingFyeoInfo)
				[fyeoView removeFromSuperview];
		}];
		
		isShowingFyeoInfo = NO;
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Camera Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)showCameraInfo
{
	if (!isShowingCameraInfo)
	{
		CGRect selfFrame = self.frame;
		CGRect cameraFrame = cameraView.frame;
		
		cameraFrame.origin.x = 5;
		cameraFrame.origin.y = -35;
		cameraFrame.size.width = selfFrame.size.width - 10;
		
		selfFrame.origin.y -= cameraFrame.size.height + 5;
		selfFrame.size.height += cameraFrame.size.height + 5;
		
		cameraView.frame = cameraFrame;
		cameraView.alpha = 0.0F;
		[self addSubview:cameraView];
		
		[UIView animateWithDuration:0.2 animations:^{
			
            //			self.frame = selfFrame;
			cameraView.alpha = 1.0;
		}];
		
		isShowingCameraInfo = YES;
	}
}

- (void)hideCameraInfo
{
	if (isShowingCameraInfo)
	{
		CGRect selfFrame = self.frame;
		CGRect cameraFrame = cameraView.frame;
		
		selfFrame.origin.y += cameraFrame.size.height + 5;
		selfFrame.size.height -= cameraFrame.size.height + 5;
		
		[UIView animateWithDuration:0.2 animations:^{
			
			self.frame = selfFrame;
			cameraView.alpha = 0.0;
			
		} completion:^(BOOL finished) {
			
			if (!isShowingCameraInfo)
				[cameraView removeFromSuperview];
		}];
		
		isShowingCameraInfo = NO;
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Silent Phone Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)showPhoneInfo
{
	if (!isShowingPhoneInfo)
	{
		CGRect selfFrame = self.frame;
		CGRect phoneFrame = phoneView.frame;
		
		phoneFrame.origin.x = 5;
		phoneFrame.origin.y = -35;
		phoneFrame.size.width = selfFrame.size.width - 10;
		
		selfFrame.origin.y -= phoneFrame.size.height + 5;
		selfFrame.size.height += phoneFrame.size.height + 5;
		
		phoneView.frame = phoneFrame;
		phoneView.alpha = 0.0F;
		[self addSubview:phoneView];
		
		[UIView animateWithDuration:0.2 animations:^{
			
            //			self.frame = selfFrame;
			phoneView.alpha = 1.0;
		}];
		
		isShowingCameraInfo = YES;
	}
}

- (void)hidePhoneInfo
{
	if (isShowingPhoneInfo)
	{
		CGRect selfFrame = self.frame;
		CGRect phoneFrame = phoneView.frame;
		
		selfFrame.origin.y += phoneFrame.size.height + 5;
		selfFrame.size.height -= phoneFrame.size.height + 5;
		
		[UIView animateWithDuration:0.2 animations:^{
			
			self.frame = selfFrame;
			phoneView.alpha = 0.0;
			
		} completion:^(BOOL finished) {
			
			if (!isShowingCameraInfo)
				[phoneView removeFromSuperview];
		}];
		
		isShowingCameraInfo = NO;
	}
}





@end
