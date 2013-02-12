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
//  STAudioView.m
//  SilentText
//

#import "App+ApplicationDelegate.h"
#import "App.h"
#import "AppConstants.h"
#import "STAudioView.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "XMPPJID.h"
#import "SCloudObject.h"
#import "MBProgressHUD.h"
#import "NSDate+SCDate.h"
#import "MZAlertView.h"
#import "UIImage+Thumbnail.h"

@interface STAudioView ()

@property (nonatomic)               BOOL            isRecording;
@property (nonatomic, retain, )     AVAudioRecorder *audioRecorder;
@property (nonatomic, retain, )     AVAudioPlayer   *audioPlayer;
@property (nonatomic, retain, )     NSURL           *url;

@property (nonatomic, strong)   MBProgressHUD    *HUD;

@end

@implementation STAudioView


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

- (void) delloc
{
}


-(BOOL) setupRecorderWithError: (NSError **)error
{
	
	BOOL result = NO;
	
	[_pauseButton setEnabled:NO];
	[_playButton  setEnabled:NO];
	[_sendButton  setEnabled:NO];
	[_redLEDImageView setHidden:YES];
	[_blueLEDImageView setHidden:YES];
	
	
	UIImage *sendBtnBackground = [[UIImage imageNamed:@"MessageEntrySendButton.png"] stretchableImageWithLeftCapWidth:13 topCapHeight:13];
	[_sendButton setBackgroundImage:sendBtnBackground forState:UIControlStateNormal];
	
	UIEdgeInsets insets = UIEdgeInsetsMake(15, 19,
										   15, 19);
	
	
	UIImage *btnDisabledBackground = [[UIImage imageNamed:@"LighterButton"] resizableImageWithCapInsets: insets];
	UIImage *activeBtnBackground = [[UIImage imageNamed:@"DarkerButton"] resizableImageWithCapInsets: insets];
	[_sendButton setBackgroundImage:btnDisabledBackground forState:UIControlStateDisabled];
	[_cancelButton setBackgroundImage:activeBtnBackground forState:UIControlStateNormal];
	[_cancelButton setBackgroundImage:btnDisabledBackground forState:UIControlStateDisabled];
	
	
	NSMutableDictionary *settings = [[NSMutableDictionary alloc] initWithCapacity:0];
	
	
	[settings setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];
	[settings setValue :[NSNumber numberWithInt:16] forKey:AVEncoderBitRateKey];
	[settings setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
	[settings setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
	
	NSString* dirPath = [App.sharedApp makeDirectory: kDirectorySCloudCache ];
	
	NSDateFormatter *format = [[NSDateFormatter alloc] init];
	[format setDateFormat:@"yyyy-MM-dd HH-mm"];
	
	NSString *filename = [NSString stringWithFormat:@"%@.caf", [format stringFromDate:NSDate.date]];
	NSString *soundFilePath = [dirPath stringByAppendingPathComponent:filename];
	
	_url = [NSURL fileURLWithPath:soundFilePath];
	
	_audioRecorder = [[AVAudioRecorder alloc]
					  initWithURL:_url
					  settings:settings
					  error:error];
	
	if (_audioRecorder != NULL)
	{
		result = YES;
		[_audioRecorder prepareToRecord];
	}
	
	_isRecording = NO;
	
	return result;
}

- (void) unfurlOnView:(UIView*)view under:(UIView*)underview  atPoint:(CGPoint) point
{
	NSError*  error = NULL;
	
	if ([self superview]) {
		//		[self resetFadeOut];
		return;
	}
	
	
	if(![self setupRecorderWithError: &error])
	{
		[self.delegate didFinishRecordingAudioWithError:error scloud:NULL];
	}
	else
	{
		
		//        [self.layer setBorderColor:[[UIColor colorWithWhite: 0 alpha:0.5] CGColor]];
		//        [self.layer setBorderWidth:1.0f];
		//        // set a background color
		//        [self.layer setBackgroundColor:[[UIColor colorWithWhite: 0.2 alpha:0.60] CGColor]];
		//        // give it rounded corners
		//        [self.layer setCornerRadius:10.0];
		//        // add a little shadow to make it pop out
		//        [self.layer setShadowColor:[[UIColor blackColor] CGColor]];
		//        [self.layer setShadowOpacity:0.75];
		
		CGFloat height = self.frame.size.height;
		self.frame = CGRectMake(0,//point.x - self.frame.size.width/ 2,
								view.frame.origin.y + view.frame.size.height, view.frame.size.width, height);
		self.alpha = 0.0;
		[view addSubview:self];
		//        [view insertSubview:self belowSubview:underview];
		[UIView animateWithDuration:0.5f
						 animations:^{
							 [self setAlpha:1.0];
							 self.frame = CGRectMake(self.frame.origin.x,
													 self.frame.origin.y - height,
													 self.frame.size.width,
													 height);
							 //			 self.center = CGPointMake(self.center.x, point.y - self.frame.size.height /2);
							 
							 
						 }
						 completion:^(BOOL finished) {
							 //                                                        [self resetFadeOut];
						 }];
	}
}

//- (void) resetFadeOut
//{
//	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
////	[self performSelector:@selector(fadeOut) withObject:nil afterDelay:5.];
//
//}

- (void) deleteAudioFile
{
	if(_url)
	{
		NSString *filePath = [_url path];
		NSFileManager *fm = [NSFileManager defaultManager];
		
		if( filePath && [fm fileExistsAtPath:filePath])
			[fm removeItemAtPath:filePath error:nil];
		
		_url = NULL;
		
	}
}

- (void) fadeOut
{
	
	CGFloat height = self.frame.size.height;
	[UIView animateWithDuration:0.5f
					 animations:^{
						 [self setAlpha:0.0];
						 self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + height, self.frame.size.width, height);
						 
					 }
					 completion:^(BOOL finished) {
						 [self removeFromSuperview];
						 //		 self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + height, self.frame.size.width, height);
					 }];
	
}
- (BOOL) isVisible
{
	return [self superview] ? YES : NO;
}

- (void) hide
{
	
	if (_audioRecorder) _audioRecorder = NULL;
	[self deleteAudioFile];
	
	//	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
	[self fadeOut];
}

//- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
//{
//	[self resetFadeOut];
//}

- (void) stopPlay
{
	[_audioPlayer stop];
	[_playButton setSelected:NO];
	[_blueLEDImageView setHidden:YES];
}

- (IBAction)recordAction:(id)sender
{
	_isRecording = !_isRecording;
	
	if (!_audioRecorder.recording)
	{
		[self stopPlay];
		_audioPlayer = nil;
		[_audioRecorder record];
		[_playButton setEnabled:NO];
		[_sendButton setEnabled:NO];
		[_recordButton setSelected:YES];

		[_redLEDImageView setHidden:NO];
				
		CABasicAnimation *theOpacityAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"];
		theOpacityAnimation.duration=0.8;
		theOpacityAnimation.repeatCount=HUGE_VALF;
		theOpacityAnimation.autoreverses=YES;
		theOpacityAnimation.fromValue=[NSNumber numberWithFloat:1.0];
		theOpacityAnimation.toValue=[NSNumber numberWithFloat:0.5];
		[_redLEDImageView.layer addAnimation:theOpacityAnimation forKey:@"animateOpacity"]; //
		
		CABasicAnimation *theScaleAnimation=[CABasicAnimation animationWithKeyPath:@"scale"];
		theScaleAnimation.duration=0.4;
		theScaleAnimation.repeatCount=HUGE_VALF;
		theScaleAnimation.autoreverses=YES;
		theScaleAnimation.fromValue=[NSNumber numberWithFloat:1.2];
		theScaleAnimation.toValue=[NSNumber numberWithFloat:0.8];
		[_redLEDImageView.layer addAnimation:theScaleAnimation forKey:@"animateScale"]; //
		
	}
	else
	{
		[_audioRecorder stop];
		[_playButton setEnabled:YES];
		[_sendButton setEnabled:YES];
		[_recordButton setSelected:NO];
		[_redLEDImageView setHidden:YES];
		[_redLEDImageView.layer removeAllAnimations];		
	}
	
}

- (IBAction)pauseAction:(id)sender
{
	if (_audioRecorder.recording)
	{
		[_pauseButton setEnabled:NO];
		[_playButton setEnabled:YES];
		[_recordButton setSelected:YES];
		[_redLEDImageView.layer removeAllAnimations];
		[_redLEDImageView setHidden:YES];
		
		[_playButton setEnabled:YES];
		
		[_audioRecorder pause];
	}
	
}


- (IBAction)playAction:(id)sender
{
	NSError *error;
	
	if (!_audioPlayer) {
		_audioPlayer = [[AVAudioPlayer alloc]
					initWithContentsOfURL:_audioRecorder.url
					error:&error];
//				NSLog(@"Error: %@",   [error localizedDescription]);

		_audioPlayer.delegate = self;
		_audioPlayer.volume = 0.5;
		[_audioPlayer prepareToPlay];
	}
	if (!_audioPlayer.playing) {
		if (_audioPlayer)
		{
			
			NSTimeInterval duration = _audioPlayer.duration;
			
//			NSLog(@"%f  seconds", duration);
			[_audioPlayer play];
			[_playButton setSelected:YES];
			[_blueLEDImageView setHidden:NO];
		}
	}
	else {
		[self stopPlay];
	}
}

- (IBAction)cancelAction:(id)sender {
	[self hide];
}

#pragma mark - AVAudioPlayerDelegate

-(void)audioPlayerDidFinishPlaying:
(AVAudioPlayer *)player successfully:(BOOL)flag
{
//	NSLog(@"finsihed");
	[_playButton setSelected:NO];
	[_blueLEDImageView setHidden:YES];
}


-(void)audioPlayerDecodeErrorDidOccur:
(AVAudioPlayer *)player
								error:(NSError *)error
{
//	NSLog(@"Decode Error occurred");
}

-(void)audioRecorderDidFinishRecording:
(AVAudioRecorder *)recorder
						  successfully:(BOOL)flag
{
	
	
}

-(void)audioRecorderEncodeErrorDidOccur:
(AVAudioRecorder *)recorder
								  error:(NSError *)error
{
//	NSLog(@"Encode Error occurred");
}

- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder;
{
	
}

- (void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder withOptions:(NSUInteger)flags
{
	
}


- (IBAction)sendAction:(id)sender
{
	
	
	if (_audioRecorder.recording)
	{
		[_audioRecorder stop];
	}
	
	__block SCloudObject    *scloud     = NULL;
	__block NSError         *error      = NULL;
	__block NSData          *theData    = NULL;
	__block NSMutableDictionary    *theInfo   = [[NSMutableDictionary alloc] init];
	
	UIImage        *thumbnail = NULL;
	
	_audioPlayer = [[AVAudioPlayer alloc]
					initWithContentsOfURL:_audioRecorder.url
					error:&error];
	
	[_audioPlayer play];
	[theInfo setObject:(__bridge NSString*) kUTTypeAudio forKey: kSCloudMetaData_MediaType];
	[theInfo setObject: [_url lastPathComponent] forKey:kSCloudMetaData_FileName];
	
	[theInfo setObject: [NSString stringWithFormat:@"%f", _audioPlayer.duration] forKey:kSCloudMetaData_Duration];
	
	[theInfo setObject: [NSDate.date rfc3339String] forKey:kSCloudMetaData_Date];
	
	theData = [NSData dataWithContentsOfURL:_url];
	
	scloud =  [[SCloudObject alloc] initWithDelegate:self
												data:theData
											metaData:theInfo
										   mediaType:(__bridge NSString*) kUTTypeAudio
									   contextString:App.sharedApp.currentJID.bare ];
	
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"mm:ss"];
	
	NSString* durationString = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: _audioPlayer.duration]];
	
	thumbnail = [UIImage imageNamed: @"vmemo70"] ;
	thumbnail = [thumbnail imageWithBadgeOverlay:NULL text:durationString textColor:[UIColor whiteColor]];
	
	scloud.thumbnail =  thumbnail ;
	
	_audioPlayer = NULL;
	_audioRecorder = NULL;
	
	if(scloud)
	{
		
		_HUD = [[MBProgressHUD alloc] initWithView:self];
		[self addSubview:_HUD];
		
		_HUD.mode = MBProgressHUDModeAnnularDeterminate;
		
		_HUD.labelText = [NSString stringWithFormat:NSLS_COMMON_PREPARING, NSLS_COMMON_AUDIO];
		
		[_HUD showAnimated:YES whileExecutingBlock:^{
			
			if(theData && theInfo); // force to retain data and info
			
			[scloud saveToCacheWithError:&error];
			[self deleteAudioFile];
			
			
		} completionBlock:^{
			
			[_HUD removeFromSuperview];
			
			[self hide];
			
			if(error)
			{
				scloud = NULL;
			}
			else
			{
				[self.delegate didFinishRecordingAudioWithError:error scloud:scloud];
			}
		}];
	}
	
	else
	{
		
		[self hide];
		scloud = NULL;
	}
	
}

#pragma mark -
#pragma mark SCloudObjectDelegate methods

- (void)scloudObject:(SCloudObject *)sender calculatingKeysDidStart:(NSString*) mediaType
{
	_HUD.mode = MBProgressHUDModeIndeterminate;
}

- (void)scloudObject:(SCloudObject *)sender calculatingKeysProgress:(float) progress
{
	self.HUD.progress = progress;
}

- (void)scloudObject:(SCloudObject *)sender calculatingKeysDidCompleteWithError:(NSError *)error
{
}

- (void)scloudObject:(SCloudObject *)sender encryptingDidStart:(NSString*) mediaType
{
	_HUD.mode = MBProgressHUDModeIndeterminate;
	_HUD.labelText = @"Encrypting";
	
}

- (void)scloudObject:(SCloudObject *)sender encryptingProgress:(float) progress
{
	self.HUD.progress = progress;
	
}
- (void)scloudObject:(SCloudObject *)sender encryptingDidCompleteWithError:(NSError *)error
{
	
}



@end
