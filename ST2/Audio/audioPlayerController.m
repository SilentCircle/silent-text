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
//  audioPlayerController.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 10/21/13.
//

#import "audioPlayerController.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "STPreferences.h"
#import <AVFoundation/AVFoundation.h>
#import "STLogging.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

@interface audioPlayerController ()

@property (nonatomic, strong   )            SCloudObject    *scloud;
@property (nonatomic, strong   )            NSDate          *recordDate;
@property (nonatomic, strong)               AVAudioPlayer   *audioPlayer;

@end

@implementation audioPlayerController
{
  
}


- (id)initWithSCloud:(SCloudObject*)inScloud
{
    _scloud = inScloud;
    
  	if (AppConstants.isIPhone)
		return [self initWithNibName:@"audioPlayerController_iPhone" bundle:nil];
	else
		return [self initWithNibName:@"audioPlayerController_iPad" bundle:nil];
}

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
    [super viewDidLoad];
     
    NSDictionary * metaData = _scloud.metaData;
    
    NSString* filename = [metaData objectForKey:kSCloudMetaData_FileName];
    NSString* displayName = [filename stringByDeletingPathExtension];
 
     _recordDate = [metaData objectForKey:kSCloudMetaData_Date];
    
    
    if (AppConstants.isIPhone)
    {
        
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"")
                                                                                 style:UIBarButtonItemStylePlain target:self
                                                                                action:@selector(handleActionBarDone)];
		
       
    }
    
    self.navigationItem.title = displayName;

 	[self loadAudioFile: _scloud.decryptedFileURL ];
}

-(void)  viewDidAppear:(BOOL)animated
 {
//     [self playAction:NULL];
}

- (void)viewWillDisappear:(BOOL)animated
{
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
	[session setCategory:AVAudioSessionCategorySoloAmbient error:nil];
	[session setActive:NO error:nil];
    

//    [self stopPlay];
    
    _scloud = NULL;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (void) handleActionBarDone
{
	[self.navigationController popViewControllerAnimated: YES];
}



- (void) loadAudioFile:(NSURL*) url
{
	NSError *error;
	if (!_audioPlayer) {
		_audioPlayer = [[AVAudioPlayer alloc]
						initWithContentsOfURL:url
						error:&error];
	
        DDLogError(@"Error: %@",   [error localizedDescription]);
        
		if (!_audioPlayer) {
			NSData *soundData = [[NSData alloc] initWithContentsOfURL:url];
			_audioPlayer = [[AVAudioPlayer alloc] initWithData: soundData
														 error: &error];
            
			DDLogError(@"Error: %@",   [error localizedDescription]);
		}
        
		if (_audioPlayer) {
			_audioPlayer.delegate = self;
		}
		else {
//			[_playButton setEnabled:NO];
		}
	}
	
}
- (void) stopPlay
{
	[_audioPlayer stop];
//	[_playButton setSelected:NO];
//	[_blueLEDImageView setHidden:YES];
}


- (IBAction)playAction:(id)sender
{
	
	//	[self loadAudioFile];
	if (_audioPlayer)
	{
		if (!_audioPlayer.playing) {
			AVAudioSession *session = [AVAudioSession sharedInstance];
			[session setCategory:AVAudioSessionCategoryPlayback error:nil];
			[session setActive:YES error:nil];
			
//			_audioPlayer.meteringEnabled = YES;
//			[self startTimer];
			[_audioPlayer play];
//			[_playButton setSelected:YES];
//			[_blueLEDImageView setHidden:NO];
		}
		else {
//			[self stopPlay];
		}
	}
}


#pragma mark - AVAudioPlayerDelegate

-(void)audioPlayerDidFinishPlaying:
(AVAudioPlayer *)player successfully:(BOOL)flag
{
	//	NSLog(@"finsihed");
	_audioPlayer.meteringEnabled = NO;
	
//	[_playButton setSelected:NO];
//	[_blueLEDImageView setHidden:YES];
}


-(void)audioPlayerDecodeErrorDidOccur:
(AVAudioPlayer *)player
								error:(NSError *)error
{
	NSLog(@"Decode Error occurred");
}


#pragma mark - Level Meter and Duration Updater

#if 0
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

- (void)updateSoundStatus
{
	id player;
	if (_audioRecorder.isRecording)
		player = (id) _audioRecorder;
	else
		player = (id) _audioPlayer;
	BOOL nothingHappening = !_audioPlayer.isPlaying && !_audioRecorder.isRecording;
	
	[player updateMeters];
#define min_interesting -70  // decibels
	float curLevel;
	if (nothingHappening)
		curLevel = min_interesting;
	else
		curLevel = [player averagePowerForChannel:0];
	if (curLevel < min_interesting)
		curLevel = min_interesting;
	curLevel += -min_interesting;
	curLevel /= -min_interesting;
	CGRect frame = _levelBar.frame;
	float width = self.frame.size.width * curLevel;
	_levelBar.frame = CGRectMake((self.frame.size.width - width) / 2.0, frame.origin.y, width, frame.size.height);
	
	NSUInteger duration;
	if (nothingHappening)
		duration = [_audioPlayer duration] * 100.0;
	else if (_audioPlayer.isPlaying)
		duration = [_audioPlayer currentTime] * 100.0;
	else //if (_audioRecorder.isRecording)
		duration = [_audioRecorder currentTime] * 100.0;
	
	_recordingLength.text = [NSString stringWithFormat:@"%02d:%02d.%02d", duration / 6000, (duration % 6000) / 100, duration % 100];
	if (nothingHappening)
		[self stopTimer];
}

#endif


 @end
