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
//  AudioPlaybackView.m
//  ST2
//
//  Created by mahboud on 11/19/13.
//

#import "AudioPlaybackView.h"
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import "AppTheme.h"
#import "AppConstants.h"

#import "STLogging.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)



@implementation AudioPlaybackView
{
 	__weak IBOutlet UILabel *audioLabel;
	__weak IBOutlet UIView *levelBar;
  
    IBOutlet UIToolbar *toolBar; // So... this one's not weak because ???
    
    UIBarButtonItem *saveItem;
    UIBarButtonItem *playItem;
    UIBarButtonItem *pauseItem;

	CADisplayLink *_updateTimer;
	AVAudioSession *audioSession;
    AppTheme       *theme;
}

static SCloudObject *   savedScloud;
static CGRect           savedRect;
static UIView *         savedView;

 AVAudioPlayer *      player;




- (id)init
{
    // Initialization code
	NSArray *nibArray = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:self options:nil];
	self = [nibArray firstObject];
    
    self.layer.borderColor = UIColor.whiteColor.CGColor;
    self.layer.borderWidth = 2.0;
    self.layer.cornerRadius = 10.0;
	
    audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [audioSession setActive: YES error:nil];
	
	//		AVAudioSessionRouteDescription *route = [audioSession currentRoute];
    [self setSpeakerMode:NO];
    
    UIDevice *device = [UIDevice currentDevice];
    device.proximityMonitoringEnabled = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNewProximityState)
                                                 name:UIDeviceProximityStateDidChangeNotification
                                               object:nil];
    
    
    saveItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                             target:self
                                                             action:@selector(shareItemHit)];
    
    playItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                             target:self
                                                             action:@selector(playItemHit)];
    
    pauseItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause
                                                              target:self
                                                              action:@selector(pauseItemHit)];
    
    
	return self;
}

- (void)dealloc
{
	[player stop];
	[self stopTimer];
	
	UIDevice *device = [UIDevice currentDevice];
	device.proximityMonitoringEnabled = NO;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	savedScloud = nil;
	savedView = nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)playScloud:(SCloudObject *)scloud fromRect:(CGRect)inRect inView:(UIView *)inView
{
	DDLogAutoTrace();
	
	NSAssert([NSThread isMainThread], @"Not thread safe !");
	
	NSError *error;
	if (![scloud.locatorString isEqualToString:savedScloud.locatorString])
	{
		savedScloud = scloud;
		if (player.isPlaying) {
			[player stop];
		}
#warning ST-841: Audio message originated on BP does not play (3gpp format)
		player = [[AVAudioPlayer alloc] initWithContentsOfURL:scloud.decryptedFileURL error:&error];
 	}
	
    savedView = inView;
    savedRect = inRect;
    
    theme = [AppTheme getThemeBySelectedKey];
    
    audioLabel.textColor = theme.appTintColor;
    levelBar.backgroundColor = theme.appTintColor;
    
    [self syncPlayPauseButtons];
    [self syncSaveButtonWithScloud:scloud];
    
	if (player) {
		player.delegate = self;
		[self updateSoundStatus];
	}
}

- (void)play
{
	player.meteringEnabled = YES;
	[self startTimer];
	[player play];
	[self syncPlayPauseButtons];
}

- (void)pause
{
	[player pause];
	[self syncPlayPauseButtons];
}

- (void)stop
{
	[player stop];
	[self syncPlayPauseButtons];
}

- (BOOL)isPlaying
{
	return player.isPlaying;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UI Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * If the media is playing, show the stop button; otherwise, show the play button.
**/
- (void)syncPlayPauseButtons
{
	if ([self isPlaying])
	{
		[self showPauseButton];
	}
	else
	{
		[self showPlayButton];
	}
}

/**
 * Show the stop button in the movie player controller.
**/
- (void)showPauseButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
    [toolbarItems replaceObjectAtIndex:2 withObject:pauseItem];
    toolBar.items = toolbarItems;
}

/**
 * Show the play button in the movie player controller.
**/
- (void)showPlayButton
{
	NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
	[toolbarItems replaceObjectAtIndex:2 withObject:playItem];
	toolBar.items = toolbarItems;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Uncategorized
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////









- (BOOL) setSpeakerMode:(BOOL) speaker {
	
	BOOL ok;
	NSError *err = 0;
	
	ok = [audioSession overrideOutputAudioPort:
		  !speaker ? AVAudioSessionPortOverrideSpeaker : AVAudioSessionPortOverrideNone error:&err];
	return ok;
}


- (void)onNewProximityState
{
//	BOOL b = UIAccessibilityIsVoiceOverRunning();
//	NSLog(@"UIAccessibilityIsVoiceOverRunning()=%d",b);
//	if(!b){
//		return;
//	}
	
	[self setSpeakerMode:[UIDevice currentDevice].proximityState];
}

- (void)syncSaveButtonWithScloud:(SCloudObject*)scloud
{
    // adjust save item
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
    if(scloud.fyeo)
    {
        if(toolbarItems.count > 6)
        {
            [toolbarItems removeLastObject];
            toolBar.items = toolbarItems;
        }
    }
    else
    {
        if(toolbarItems.count < 7)
        {
            [toolbarItems addObject:saveItem];
            toolBar.items = toolbarItems;
        }
        
    }
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    [self syncPlayPauseButtons];
    player.currentTime = 0;
	
	NSAssert([NSThread isMainThread], @"Delegate callback isn't thread-safe!");
	
	if ([self.delegate respondsToSelector:@selector(audioPlaybackViewDidStopPlaying:finished:)])
		[self.delegate audioPlaybackViewDidStopPlaying:self finished:YES];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)playItemHit
{
	NSAssert([NSThread isMainThread], @"Delegate callback isn't thread-safe!");
	
    player.meteringEnabled = YES;
	[self startTimer];
	[player play];
    [self syncPlayPauseButtons];

}
- (void)pauseItemHit
{
	NSAssert([NSThread isMainThread], @"Delegate callback isn't thread-safe!");
	
    [player pause];
    [self syncPlayPauseButtons];
	
	if ([self.delegate respondsToSelector:@selector(audioPlaybackViewDidStopPlaying:finished:)])
		[self.delegate audioPlaybackViewDidStopPlaying:self finished:NO];
}

- (void)shareItemHit
{
    [self stop];
    
    if (AppConstants.isIPad)
    {
        if ([self.delegate respondsToSelector:@selector(audioPlaybackView:needsHidePopoverAnimated:)])
            [self.delegate audioPlaybackView:self needsHidePopoverAnimated:NO];
    }

	if ([self.delegate respondsToSelector:@selector(audioPlaybackView:shareAudio:fromRect:inView:)])
		[self.delegate audioPlaybackView:self shareAudio:savedScloud fromRect:savedRect inView:savedView];

	savedView = NULL;
}

- (IBAction)rewindAction:(id)sender
{
	float decrement = player.duration * 0.05;
	
	if (player)
	{
		player.currentTime -= decrement;
		if (player.currentTime < 0)
			player.currentTime = 0;
		if (!player.isPlaying)
			[self updateCurrentTime];
	}
}

- (IBAction)forwardAction:(id)sender
{
	float increment = player.duration * 0.05;
	
	if (player)
	{
		NSTimeInterval currTime = player.currentTime;
		currTime += increment;
		if (currTime > player.duration)
			currTime = 0;
		player.currentTime = currTime;
		if (!player.isPlaying)
			[self updateCurrentTime];
	}
}

- (IBAction)speakerAction:(id)sender {
	
	MPVolumeSettingsAlertShow();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Level Meter and Duration Updater
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateCurrentTime
{
    int minutes = player.currentTime / 60;
    int seconds = ((int)player.currentTime) % 60;
	
  	audioLabel.text = [NSString stringWithFormat: @"%02d:%02d", minutes, seconds];
}

- (void)updateSoundStatus
{
	BOOL isPlaying = player.isPlaying;
	
	[player updateMeters];
    
    const float min_interesting = -70; // decibels
	
	float curLevel;
	if (isPlaying)
		curLevel = [player averagePowerForChannel:0];
	else
		curLevel = min_interesting;
	
	if (curLevel < min_interesting)
		curLevel = min_interesting;
	
	curLevel += -min_interesting;
	curLevel /= -min_interesting;
  
	CGRect frame = audioLabel.frame;
    frame.origin.y += audioLabel.frame.size.height + 1;
    frame.size.height = 3;
    frame.size.width = (audioLabel.frame.size.width * curLevel);
    frame.origin.x = audioLabel.frame.origin.x
            + audioLabel.frame.size.width/2 -(audioLabel.frame.size.width * curLevel/2);
    
	levelBar.frame =  frame;
	
	[self updateCurrentTime];

	if (!isPlaying) {
		[self stopTimer];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Timer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)stopTimer
{
	[_updateTimer invalidate];
	_updateTimer = nil;
}

- (void)startTimer
{
	if (_updateTimer)
		[self stopTimer];
	
	_updateTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateSoundStatus)];
	[_updateTimer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

@end
