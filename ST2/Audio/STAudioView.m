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
#import "STAudioView.h"

#import "AppConstants.h"
#import "AppDelegate.h"
#import "MBProgressHUD.h"
#import "SCloudObject.h"
#import "SCFileManager.h"
#import "SilentTextStrings.h"
#import "Siren.h"
#import "SnippetGraphView.h"
#import "STLocalUser.h"
#import "STUser.h"
#import "XMPPJID.h"

// Categories
#import "NSDate+SCDate.h"
#import "NSString+SCUtilities.h"
#import "UIImage+Thumbnail.h"

// Libraries
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>


@interface STAudioView () {
//	CADisplayLink * _updateTimer;
	NSTimer       * _updateTimer;
}

@property (nonatomic, strong)     AVAudioRecorder *audioRecorder;
@property (nonatomic, strong)     AVAudioPlayer   *audioPlayer;
//@property (nonatomic, retain, )     NSURL           *url;

@property (nonatomic, strong)   MBProgressHUD    *HUD;

@property (nonatomic, weak) IBOutlet UIButton* recordButton;
@property (nonatomic, weak) IBOutlet UIButton* pauseButton;
@property (nonatomic, weak) IBOutlet UIButton* playButton;
@property (nonatomic, weak) IBOutlet UIButton* sendButton;
@property (nonatomic, weak) IBOutlet UIImageView* redLEDImageView;
@property (weak, nonatomic) IBOutlet UIImageView *blueLEDImageView;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIImageView *controlbarImageView;
@property (weak, nonatomic) IBOutlet UILabel *recordingLength;
//@property (weak, nonatomic) IBOutlet UIView *levelBar;
@property (weak, nonatomic) IBOutlet SnippetGraphView *sgView;
@property (weak, nonatomic) IBOutlet UIView *backgroundShade;


- (IBAction)recordAction:(id)sender;
- (IBAction)pauseAction:(id)sender;
- (IBAction)playAction:(id)sender;
- (IBAction)cancelAction:(id)sender;

- (IBAction)sendAction:(id)sender;

- (BOOL)isVisible;

@end

#pragma mark -

@implementation STAudioView

@synthesize delegate = delegate;
@synthesize needsThumbNail = needsThumbNail;

+ (BOOL) canRecord
{
    return YES;
}

- (id)init
{
		// Initialization code
	NSArray *nibArray = [[NSBundle mainBundle] loadNibNamed:@"STAudioView" owner:self options:nil];
	self = [nibArray firstObject];

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

- (void) dealloc
{
	fileIsInUse = NO;
	url = nil;
}
BOOL 		fileIsInUse = NO;
NSURL       *url;

+(void) sanitizeFolder:(NSString *)path
{
	NSError *error     = nil;
	NSFileManager *fm  = [NSFileManager defaultManager];
	// shall we compare the following with the passed in path?
	// should this class have the same notion of where the folder for sanitzation is? 
//	NSString *ourPath = [App.sharedApp makeDirectory:kClassPath];
	NSArray *fileNames = [fm contentsOfDirectoryAtPath: path error: &error];
	
	if (fileNames.count) {
		NSLog(@"sanitize: audio files %@", fileNames);

		for (NSString *filePath in fileNames) {
			
            NSString *fullPath = [path stringByAppendingPathComponent: filePath];
			
			BOOL isDirectory = NO;
			
			if ([fm fileExistsAtPath: fullPath isDirectory: &isDirectory]) {
				if (isDirectory) {
					// do something with directories, if directories are created
					// possibly recurse.
				}
				else if ([fm isDeletableFileAtPath: fullPath]) {
					error = nil;
					if (!(fileIsInUse && [fullPath isEqualToString:[url path]])) {
						[fm removeItemAtPath: fullPath error: &error];
					}
				}
			}
		}
	}

}

-(BOOL) setupRecorderWithError: (NSError **)error
{
	//	[self updateSoundStatus];
	[_pauseButton setEnabled:NO];
	[_playButton  setEnabled:NO];
	[_sendButton  setEnabled:NO];
	[_redLEDImageView setHidden:YES];
	[_blueLEDImageView setHidden:YES];
	
//	UIEdgeInsets insets = UIEdgeInsetsMake(14, 13, 13, 13);
//	
//	UIImage *sendBtnBackground = [[UIImage imageNamed:@"MessageEntrySendButton.png"] resizableImageWithCapInsets: insets];
//	[_sendButton setBackgroundImage:sendBtnBackground forState:UIControlStateNormal];
//	
//	insets = UIEdgeInsetsMake(16, 19, 16, 19);
//	UIImage *btnDisabledBackground = [[UIImage imageNamed:@"LighterButton"] resizableImageWithCapInsets: insets];
//	
//	UIImage *activeBtnBackground = [[UIImage imageNamed:@"DarkerButton"] resizableImageWithCapInsets: insets];
//	[_sendButton setBackgroundImage:btnDisabledBackground forState:UIControlStateDisabled];
//	[_cancelButton setBackgroundImage:activeBtnBackground forState:UIControlStateNormal];
//	[_cancelButton setBackgroundImage:btnDisabledBackground forState:UIControlStateDisabled];
	_audioRecorder = nil;
	_audioPlayer = nil;
	return YES;
}

- (void) unfurlOnView:(UIView*)view under:(UIView*)underview  atPoint:(CGPoint) point
{
	NSError*  error = NULL;
	
	if ([self superview]) {
		return;
	}
	
	view.tintColor = view.superview.tintColor;
	_cancelButton.tintColor = _sendButton.tintColor = view.tintColor;
	[_sgView reset];
	_sgView.clipsToBounds = YES;
	_sgView.backgroundColor = [UIColor blackColor];
	_sgView.layer.borderColor = [UIColor whiteColor].CGColor;
	_sgView.layer.borderWidth = 1;
	_sgView.waveColor = [UIColor redColor];

	if(![self setupRecorderWithError: &error])
	{
        if ([delegate respondsToSelector:@selector(STAudioView:didFinishRecordingWithSiren:error:)])
            [delegate STAudioView:self didFinishRecordingWithSiren: NULL error:error];
        
 	}
	else
	{
//		CGRect screenBounds = [[UIScreen mainScreen] bounds];
		self.frame = CGRectMake(0,
								view.bounds.size.height,
								view.bounds.size.width,
								view.bounds.size.height);
		self.alpha = 0.0;
		_backgroundShade.alpha = 0.0;
		[view addSubview:self];
		//        [view insertSubview:self belowSubview:underview];
		[UIView animateWithDuration:0.5f
						 animations:^{
							 [self setAlpha:1.0];
							 self.frame = CGRectMake(0,
													 0,
													 view.bounds.size.width,
													 view.bounds.size.height);
							 
							 
						 }
						 completion:^(BOOL finished) {
							 [UIView animateWithDuration:0.25f animations:^{
								 _backgroundShade.alpha = 1.0;
							 }];
						 }];
		//	completion:^(BOOL finished) {
		//	}];
	}
}


- (void) deleteAudioFile
{
	[_audioRecorder deleteRecording];
	// the following is for redundancy.  It's important to delete the sound file and not leave any behind
	_audioRecorder = nil;
	if (url)
	{
		NSString *filePath = [url path];
		NSFileManager *fm = [NSFileManager defaultManager];
		
		if( filePath && [fm fileExistsAtPath:filePath]) {
			[fm removeItemAtPath:filePath error:nil];
		}
		url = nil;
	}
	fileIsInUse = NO;
}

- (void) fadeOut
{
	
//	CGRect screenBounds = [[UIScreen mainScreen] bounds];
	UIView *parentView = self.superview;
	self.frame = CGRectMake(0,
							0,
							parentView.bounds.size.width,
							parentView.bounds.size.height);
	[UIView animateWithDuration:0.25f
					 animations:^{
						_backgroundShade.alpha = 0.0;

					 }
					 completion:^(BOOL finished) {
						 [UIView animateWithDuration:0.5f animations:^{
							 [self setAlpha:0.0];
							 self.frame = CGRectMake(0,
													 parentView.bounds.size.height,
													 parentView.bounds.size.width,
													 parentView.bounds.size.height);

						 }
						  completion:^(BOOL finished) {
							  [self removeFromSuperview];

						  }];
					 }];
	
}
- (BOOL) isVisible
{
	return [self superview] ? YES : NO;
}

- (void) hide
{
	[self stopTimer];
	if (_audioRecorder) {
		_audioRecorder.delegate = nil;
		if (_audioRecorder.isRecording)
			[_audioRecorder stop];
	}
	AVAudioSession *session = [AVAudioSession sharedInstance];
	[session setCategory:AVAudioSessionCategorySoloAmbient error:nil];
	[session setActive:NO error:nil];

	[self deleteAudioFile];
	if (_audioRecorder) self.audioRecorder = NULL;
	if (_audioPlayer) self.audioPlayer = NULL;
	
	[self fadeOut];
}

- (void) stopPlay
{
	[_audioPlayer stop];
	[_playButton setSelected:NO];
	[_blueLEDImageView setHidden:YES];
}

- (IBAction)recordAction:(id)sender
{
	if (!_audioRecorder.recording)
	{
		[self stopPlay];
		_audioPlayer = nil;
		[self deleteAudioFile];
		AVAudioSession *session = [AVAudioSession sharedInstance];
		[session setCategory:AVAudioSessionCategoryRecord error:nil];
		[session setActive:YES error:nil];
		
		//	NSDictionary *recordSettings = [NSDictionary dictionaryWithObjectsAndKeys:
		//									[NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
		//									[NSNumber numberWithInt:AVAudioQualityMin], AVEncoderAudioQualityKey,
		//									[NSNumber numberWithInt:16], AVEncoderBitRateKey,
		//									[NSNumber numberWithInt: 1], AVNumberOfChannelsKey,
		//									[NSNumber numberWithFloat:44100], AVSampleRateKey, nil];
		NSDictionary *recordSettings = @{
										 AVFormatIDKey : @(kAudioFormatMPEG4AAC),
										 AVEncoderAudioQualityKey : @(AVAudioQualityMin),
										 //									 AVEncoderBitRateKey : @16,
										 AVNumberOfChannelsKey : @1,
										 AVSampleRateKey : @44100.0
										 };
	 	
		NSDateFormatter *format = [[NSDateFormatter alloc] init];
		[format setDateFormat:@"yyyyMMdd-HHmmss"];
		
		NSString *filename = [NSString stringWithFormat:@"%@.m4a", [format stringFromDate:NSDate.date]];
        
		url = [[SCFileManager recordingCacheDirectoryURL] URLByAppendingPathComponent:filename];
		
//		NSError *error;
		_audioRecorder = [[AVAudioRecorder alloc]
						  initWithURL:url
						  settings:recordSettings
						  error:nil];
		
		if (_audioRecorder != NULL) {
			_audioRecorder.delegate = self;
			[_audioRecorder prepareToRecord];
//			[self startTimer];
			[_sgView reset];
			_audioRecorder.meteringEnabled = YES;

			[_audioRecorder recordForDuration:900.0];
			[_playButton setEnabled:NO];
			[_sendButton setEnabled:NO];
			[_recordButton setSelected:YES];
			
			[_redLEDImageView setHidden:NO];
			
			CABasicAnimation *theOpacityAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"];
			theOpacityAnimation.duration=0.7;
			theOpacityAnimation.repeatCount=HUGE_VALF;
			theOpacityAnimation.autoreverses=YES;
			theOpacityAnimation.fromValue=[NSNumber numberWithFloat:1.0];
			theOpacityAnimation.toValue=[NSNumber numberWithFloat:0.25];
			[_redLEDImageView.layer addAnimation:theOpacityAnimation forKey:@"animateOpacity"]; //
			fileIsInUse = YES;
			NSLog(@"start record: audio file is %@ (%@)", [_audioRecorder.url lastPathComponent], url);
			[self startTimer];
		}
	}
	else
	{
		[_audioRecorder stop];
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
- (void) loadAudioFile
{
	NSError *error;
	if (!_audioPlayer) {
		_audioPlayer = [[AVAudioPlayer alloc]
						initWithContentsOfURL:_audioRecorder.url
						error:&error];
		NSLog(@"Error: %@",   [error localizedDescription]);
		if (!_audioPlayer) {
			NSData *soundData = [[NSData alloc] initWithContentsOfURL:_audioRecorder.url];
			_audioPlayer = [[AVAudioPlayer alloc] initWithData: soundData
														 error: &error];
			NSLog(@"Error: %@",   [error localizedDescription]);
		}
		if (_audioPlayer) {
			_audioPlayer.delegate = self;
		}
		else {
			[_playButton setEnabled:NO];
			[_sendButton setEnabled:NO];
		}
	}
	
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
			[_sgView reset];

			_audioPlayer.meteringEnabled = YES;
			[self startTimer];
			[_audioPlayer play];
			[_playButton setSelected:YES];
			[_blueLEDImageView setHidden:NO];
		}
		else {
			[self stopPlay];
		}
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
	_audioPlayer.meteringEnabled = NO;
	
	[_playButton setSelected:NO];
	[_blueLEDImageView setHidden:YES];
}


-(void)audioPlayerDecodeErrorDidOccur:
(AVAudioPlayer *)player
								error:(NSError *)error
{
	NSLog(@"Decode Error occurred");
}

-(void)audioRecorderDidFinishRecording:
(AVAudioRecorder *)recorder
						  successfully:(BOOL)flag
{
	_audioRecorder.meteringEnabled = NO;
	[self updateUIForRecordingStop];
	[self loadAudioFile];
}
- (void) updateUIForRecordingStop
{
	
	[_playButton setEnabled:YES];
	[_sendButton setEnabled:YES];
	[_recordButton setSelected:NO];
	[_redLEDImageView setHidden:YES];
	[_redLEDImageView.layer removeAllAnimations];
}

-(void)audioRecorderEncodeErrorDidOccur:
(AVAudioRecorder *)recorder
								  error:(NSError *)error
{
	//	NSLog(@"Encode Error occurred");
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient error:nil];
	[self updateUIForRecordingStop];
	
}

- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder;
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	[self audioRecorderDidFinishRecording: recorder successfully:YES];
	
}

- (void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder withOptions:(NSUInteger)flags
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	
}


- (IBAction)sendAction:(id)sender
{
	
	
	if (_audioRecorder.recording)
	{
		[_audioRecorder stop];
	}
	
    if (![delegate respondsToSelector:@selector(STAudioView:didFinishRecordingWithSiren:error:)])
    {
     	_audioPlayer = NULL;
        _audioRecorder = NULL;
        [self hide];
        return;
	}
	
	__block SCloudObject        *scloud     = NULL;
    __block Siren               *siren      = NULL;
	__block NSData              *theData    = NULL;
	__block NSData			    *soundWaveData    = NULL;
	__block NSDictionary        *metaData   = NULL;
    __block NSString            *mimeType   = NULL;
  	__block NSError             *error      = NULL;
    __block NSTimeInterval      audioDuration   = _audioPlayer.duration;
    __block NSString            *durationString = [NSString stringWithFormat:@"%f", audioDuration];
 	
	if (!_audioPlayer)
		NSLog(@"can't get duration!!");
	
    
    NSString *theUTI = (__bridge_transfer NSString *) UTTypeCreatePreferredIdentifierForTag( kUTTagClassFilenameExtension,  (__bridge CFStringRef) url.pathExtension, NULL);
    mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef) theUTI, kUTTagClassMIMEType);
  	
    theData = [NSData dataWithContentsOfURL:url];
	NSInteger numOfPoints;
	unsigned char *soundWave = [_sgView getNativeGraphPoints:&numOfPoints];
#define default_sound_wave_width	150
	soundWaveData = [NSData dataWithBytes:soundWave length:MIN(numOfPoints, default_sound_wave_width)];

    metaData =  @{
                  kSCloudMetaData_MediaType:  (__bridge NSString *)kUTTypeAudio,
                  kSCloudMetaData_FileName: [url lastPathComponent] ,
                  kSCloudMetaData_MimeType: mimeType,
                  kSCloudMetaData_Duration: durationString,
                  kSCloudMetaData_FileSize: [NSNumber numberWithUnsignedInteger:theData.length],
                  kSCloudMetaData_Date:     [[NSDate date] rfc3339String],
//				  kSCloudMetaData_MediaWaveform: [soundWaveData base64Encoded]
                  kSCloudMetaData_MediaWaveform: [soundWaveData base64EncodedStringWithOptions:0]
				  };
  	
	scloud =  [[SCloudObject alloc] initWithDelegate:self
												data:theData
											metaData:metaData
										   mediaType:(__bridge NSString*) kUTTypeAudio
									   contextString:[STDatabaseManager.currentUser.jid full]];
	
 	_audioPlayer = NULL;
	_audioRecorder = NULL;
	
	if(scloud)
	{
		
		_HUD = [[MBProgressHUD alloc] initWithView:self];
		[self addSubview:_HUD];
		
		_HUD.mode = MBProgressHUDModeAnnularDeterminate;
		
		_HUD.labelText = [NSString stringWithFormat:NSLS_COMMON_PREPARING, NSLS_COMMON_AUDIO];
		
		[_HUD showAnimated:YES whileExecutingBlock:^{
			
			[scloud saveToCacheWithError:&error];
			[self deleteAudioFile];
			
			
		} completionBlock:^{
			
			[_HUD removeFromSuperview];
			
			[self hide];
			self.audioRecorder = NULL;
			if(error)
			{
				scloud = NULL;
			}
			else
			{
                siren = Siren.new;
                siren.mediaType     = (__bridge NSString*) kUTTypeAudio;
                siren.mimeType      = mimeType;
                siren.duration      = durationString;
                siren.cloudKey      = scloud.keyString;
                siren.cloudLocator  = scloud.locatorString;
                siren.waveform  	= soundWaveData;
				
                // added this code for ST 1.X compatibiity, we need a thumbnail for that version
                
                if(needsThumbNail)
                {
                    UIImage * thumbnail = [UIImage imageNamed: @"vmemo70"] ;
                    NSDateFormatter* durationFormatter = [[NSDateFormatter alloc] init] ;
                    [durationFormatter setDateFormat:@"mm:ss"];
                    NSString* overlayText = [durationFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: audioDuration]];
                    thumbnail = [thumbnail imageWithBadgeOverlay:NULL text:overlayText textColor:[UIColor whiteColor]];
                    NSData * thumbnailData = UIImageJPEGRepresentation(thumbnail, 0.1);
                    siren.thumbnail = thumbnailData;
                }
                
                [delegate STAudioView: self  didFinishRecordingWithSiren: siren error:error];
				
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

- (void)scloudObject:(SCloudObject *)sender savingDidStart:(NSString*) mediaType totalSegments:(NSInteger)totalSegments
{
    _HUD.labelText = NSLocalizedString(@"Encrypting", @"HUD text");
   	_HUD.mode = MBProgressHUDModeAnnularDeterminate;
    
}
- (void)scloudObject:(SCloudObject *)sender savingProgress:(float) progress
{
  	_HUD.progress = progress;
    
}
- (void)scloudObject:(SCloudObject *)sender savingDidCompleteWithError:(NSError *)error
{
    
}


#pragma mark - Level Meter and Duration Updater
- (void)stopTimer
{
	[_updateTimer invalidate];
	_updateTimer = nil;
}

- (void)startTimer
{
	if (_updateTimer)
		[self stopTimer];

//	_updateTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateSoundStatus)];
//	[_updateTimer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	_updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateSoundStatus) userInfo:nil repeats:YES];
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
	float audioPower = [player averagePowerForChannel:0];

#define min_interesting -40  // decibels
	float curLevel;
	if (nothingHappening)
		curLevel = min_interesting;
	else
		curLevel = audioPower;
	if (curLevel < min_interesting)
		curLevel = min_interesting;
	curLevel += -min_interesting;
	curLevel /= -min_interesting;
//	float   level;                // The linear 0.0 .. 1.0 value we need.
//	float   minDecibels = -80.0f; // Or use -60dB, which I measured in a silent room.
//	float   decibels    = audioPower;
//	
//	if (decibels < minDecibels)
//	{
//		level = 0.0f;
//	}
//	else if (decibels >= 0.0f)
//	{
//		level = 1.0f;
//	}
//	else
//	{
//		float   root            = 2.0f;
//		float   minAmp          = powf(10.0f, 0.05f * minDecibels);
//		float   inverseAmpRange = 1.0f / (1.0f - minAmp);
//		float   amp             = powf(10.0f, 0.05f * decibels);
//		float   adjAmp          = (amp - minAmp) * inverseAmpRange;
//		
//		level = powf(adjAmp, 1.0f / root);
//	}
//
	
	
	[_sgView addPoint:curLevel];
//	CGRect frame = _levelBar.frame;
//	float width = self.frame.size.width * curLevel;
//	_levelBar.frame = CGRectMake((self.frame.size.width - width) / 2.0, frame.origin.y, width, frame.size.height);
	
	NSUInteger duration;
	if (nothingHappening)
		duration = [_audioPlayer duration] * 100.0;
	else if (_audioPlayer.isPlaying)
		duration = [_audioPlayer currentTime] * 100.0;
	else //if (_audioRecorder.isRecording)
		duration = [_audioRecorder currentTime] * 100.0;
	
	_recordingLength.text = [NSString stringWithFormat:@"%02d:%02d.%02d",
	                         (int)(duration / 6000),
	                         (int)((duration % 6000) / 100),
	                         (int)(duration % 100)];
	if (nothingHappening)
		[self stopTimer];
}


@end
