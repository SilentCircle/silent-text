/*
Copyright (C) 2015, Silent Circle, LLC. All rights reserved.

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
#import "STSoundManager.h"

#import "AppConstants.h"
#import "STPreferences.h"

#import <AudioToolbox/AudioServices.h>


@implementation STSoundManager
{
	SystemSoundID _messageInID;
	SystemSoundID _messageOutID;
	SystemSoundID _beepSoundID;
}

static STSoundManager *sharedInstance;

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[STSoundManager alloc] init];
	});
}

+ (STSoundManager *)sharedInstance
{
	return sharedInstance;
}

- (STSoundManager *)init
{
	NSAssert(sharedInstance == nil, @"You MUST use the sharedInstance - class is a singleton");
	
	if ((self = [super init]))
	{
		NSString *messageInPath = [[NSBundle mainBundle] pathForResource:@"received" ofType:@"wav"];
		NSURL *messageInURL = [NSURL fileURLWithPath:messageInPath isDirectory:NO];
		
		AudioServicesCreateSystemSoundID((__bridge CFURLRef)messageInURL, &_messageInID);
		
		NSString *messageOutPath = [[NSBundle mainBundle] pathForResource:@"sent" ofType:@"aiff"];
		NSURL *messageOutURL = [NSURL fileURLWithPath:messageOutPath isDirectory:NO];
		
		AudioServicesCreateSystemSoundID((__bridge CFURLRef)messageOutURL, &_messageOutID);
		
		NSString *beepSoundPath = [[NSBundle mainBundle] pathForResource:@"beep" ofType:@"m4a"];
		NSURL *beebSoundURL = [NSURL fileURLWithPath:beepSoundPath isDirectory:NO];
		
		AudioServicesCreateSystemSoundID((__bridge CFURLRef)beebSoundURL, &_beepSoundID);
	}
	return self;
}

- (void)dealloc
{
	if (_messageInID) {
		AudioServicesDisposeSystemSoundID(_messageInID);
	}
	if (_messageOutID) {
		AudioServicesDisposeSystemSoundID(_messageOutID);
	}
	if (_beepSoundID) {
		AudioServicesDisposeSystemSoundID(_beepSoundID);
	}
}

#pragma mark Play Sounds

- (void)playMessageInSound
{
	if ([STPreferences soundInMessage]) {
		AudioServicesPlaySystemSound(_messageInID);
	}
	
	if ([STPreferences soundVibrate]) {
		AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
	}
}

- (void)playMessageOutSound
{
	if ([STPreferences soundSentMessage]) {
		AudioServicesPlaySystemSound(_messageOutID);
	}
}

- (void)playBeepSound
{
	AudioServicesPlaySystemSound(_beepSoundID);
}

@end

