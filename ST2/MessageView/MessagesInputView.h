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

@class MessagesViewController;
@class AutoGrowingTextView;


/**
 * This is a custom class for the inputView within MessagesViewController.
**/
@interface MessagesInputView : UIView

@property (nonatomic, weak)	IBOutlet MessagesViewController *messagesViewController;

@property (nonatomic, weak) IBOutlet UIToolbar *toolbar;
@property (nonatomic, weak) IBOutlet AutoGrowingTextView *autoGrowTextView;
@property (nonatomic, weak) IBOutlet UIButton *sendButton;
@property (nonatomic, weak) IBOutlet UIButton *optionsButton;

@property (nonatomic, strong) NSString *typedText;

- (void)enableSendButtonIfHasText:(BOOL)enableAllowed;

@end

@protocol MessagesInputViewDelegate // Implemented by MessagesViewController
@required

/**
 * Called with a YES when autoGrowTextView is firstResponder (has keyboard), OR has some text in it.
 * Otherwise called with a NO if it resignsFirstResponder (loses keyboard) AND has no text.
 * 
 * In other words, active means it appears the user is preparing to send a message.
 * This is an indicator to do things such as spin up GPS (if needed).
**/
- (void)inputViewIsActive:(BOOL)isActive;

/**
 * Invoked when the text changes within the autoGrowTextField.
**/
- (void)inputViewTextChanged;

/**
 * Invoked upon completion of the inputView frame size animation.
**/
- (void)inputViewSizeChanged;

/**
 * Just before this class fires the 'sendButtonTappedWithText' method,
 * it invokes [AutoGrowingTextView acceptSuggestionWithoutDismissingKeyboard].
 * And during this process, the autoGrowingTextView temporarily loses firstResponder.
 * Its a rather harmless thing, but it does cause some of the keyboard events to fire multiple times.
 * So these methods can be used to set flags to ignore those actions, if needed.
**/
- (void)inputViewWillTemporarilyLoseFirstResponder;
- (void)inputViewDidTemporarilyLoseFirstResponder;

/**
 * Invoked when the sendButton is tapped.
 * This method need only concern itself with sending the given message.
 * The inputView handles clearing the autoGrowTextField, and other UI stuff.
**/
- (void)sendButtonTappedWithText:(NSString *)text;

/**
 * We add messagesViewController as a target for the optionsButton.
 * This is the selector that is invoked.
**/
- (void)chatOptionsPress:(id)sender;

@end