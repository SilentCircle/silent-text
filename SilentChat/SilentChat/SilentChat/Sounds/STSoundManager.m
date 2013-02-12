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
//  STSounds.m
//  SilentText
//

#import "STSoundManager.h"
#import <AudioToolbox/AudioServices.h>
#import "App.h"
#import "Preferences.h"


@interface STSoundManager()

@property (nonatomic) SystemSoundID messageInID;
@property (nonatomic) SystemSoundID messageOutID;

@end

@implementation STSoundManager

@synthesize messageInID = _messageInID;
@synthesize messageOutID = _messageOutID;
 
#pragma mark - STSoundManager

- (STSoundManager *) init {
	
	self = [super init];
	
	if (self) {
      
        NSURL *messageInURL = [NSURL fileURLWithPath:[[NSBundle mainBundle]
                                                  pathForResource: @"received"
                                                  ofType: @"wav"] isDirectory:NO];
        
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)messageInURL, &_messageInID);

 
        
        NSURL *messageOutURL = [NSURL fileURLWithPath:[[NSBundle mainBundle]
                                                      pathForResource: @"sent"
                                                      ofType: @"wav"] isDirectory:NO];
        
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)messageOutURL, &_messageOutID);
        
        self.inSound = TRUE;
        self.vibrate = TRUE;
        self.outSound = NO;

     }
	return self;
	
} // init


-(void)dealloc {
	if(_messageInID)
        AudioServicesDisposeSystemSoundID(_messageInID);
    
 }

#pragma mark - accessors

- (void) setVibrate:(BOOL)doesVibrate
{
    App *app = App.sharedApp;
   
    app.preferences.vibrate = doesVibrate;
    [app.preferences writePreferences];
}
 
- (BOOL) doesVibrate
{
    
    return App.sharedApp.preferences.vibrate;
}


- (void) setInSound:(BOOL)inSound
{
    App *app = App.sharedApp;

    app.preferences.inSound = inSound;
    [app.preferences writePreferences];


}
- (BOOL) doesInSound
{
      return App.sharedApp.preferences.inSound;
}

- (void) setOutSound:(BOOL)outSound
{
    App *app = App.sharedApp;
    
    app.preferences.outSound = outSound;
    [app.preferences writePreferences];
    
}

- (BOOL) doesOutSound
{
    return App.sharedApp.preferences.outSound;
}

#pragma mark - play sounds


- (void)playMessageInSound
{
    if(self.inSound)
        AudioServicesPlaySystemSound(_messageInID);
    
    if(self.vibrate)
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
}

- (void)playMessageOutSound
{
    if(self.outSound)
        AudioServicesPlaySystemSound(_messageOutID);
    
}



@end

