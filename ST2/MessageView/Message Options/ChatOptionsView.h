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
#import <UIKit/UIKit.h>

@class ChatOptionsGridView;
@protocol ChatOptionsViewDelegate;


@interface ChatOptionsView : UIView <UIScrollViewDelegate>

@property (nonatomic, weak) id<ChatOptionsViewDelegate> delegate;

// The default value is 4 seconds
@property (nonatomic, assign) NSTimeInterval fadeOutTimeout;
@property (nonatomic, assign) BOOL visible;
@property (nonatomic, weak) IBOutlet UIButton *paperclipButton;
@property (nonatomic, weak) IBOutlet UIButton *mapButton;

- (IBAction)fyeoAction:(id)sender;
- (IBAction)mapAction:(id)sender;
- (IBAction)cameraAction:(id)sender;
- (IBAction)burnAction:(id)sender;
- (IBAction)phoneAction:(id)sender;
- (IBAction)micAction:(id)sender;

- (IBAction)burnSliderTouchDown:(id)sender;
- (IBAction)burnSliderTouchUp:(id)sender;
- (IBAction)burnSliderChanged:(id)sender;
- (IBAction)toggleBurn:(id)sender;

- (void)suspendFading:(BOOL)shouldSuspend;
- (void)hideBurnOptions;
+ (instancetype)loadChatView;
- (void)showChatOptionsView;
- (void)hideChatOptionsView;

- (void)setMap:(BOOL) state;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol ChatOptionsViewDelegate <NSObject>
@required

- (BOOL)getBurnNoticeState;
- (void)setBurnNoticeState:(BOOL)state;

- (uint32_t)getBurnNoticeDelay;
- (void)setBurnNoticeDelay:(uint32_t)delayInSeconds;

- (BOOL)getIncludeLocationState;
- (void)setIncludeLocationState:(BOOL)state;

- (BOOL)getFYEOState;
- (void)setFYEOState:(BOOL)state;

- (BOOL)getPhoneState;
- (BOOL)getCameraState;
- (BOOL)getPaperClipState;
- (BOOL)getAudioState;

- (void)paperclipAction:(UIButton *)sender;
- (void)contactAction:(UIButton *)sender;
- (void)phoneAction:(UIButton *)sender;
- (void)micAction:(UIButton *)sender;
- (void)cameraAction:(UIButton *)sender;
- (void)sendLocationAction:(UIButton *)sender;


@optional

- (void)fadeOut:(ChatOptionsView *)sender;

@end
