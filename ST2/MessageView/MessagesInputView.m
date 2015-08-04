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
#import "MessagesInputView.h"
#import "MessagesViewController.h"
#import "AutoGrowingTextView.h"

#import "AppConstants.h"
#import "STLogging.h"

// Levels:
// Error   == 0000001
// Warn    == 0000011
// Info    == 0000111
// Verbose == 0001111
//
// Trace is independent of levels, and can be set by bitwise-or'ing it
//
// Flags:
// Trace   == 0010000
//
// (ddLogLevel is technically ddLogBitMask)
#if DEBUG & eturner
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG & robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#elif DEBUG
  static const int ddLogLevel = LOG_FLAG_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface MessagesInputView (private) <UITextViewDelegate>
@end

static inline UIViewAnimationOptions AnimationOptionsForCurve(UIViewAnimationCurve curve)
{
	return (curve << 16 | UIViewAnimationOptionBeginFromCurrentState);
}

@implementation MessagesInputView
{
	CGFloat heightPadding;
	CGFloat minHeight;
	
	BOOL canEnableSendButtonIfHasText;
	BOOL pendingFrameSizeChange;
    
    //ET 12/16/14 increase tap target with invisible underlying button
    IBOutlet UIButton *_btnOptionsTapTarget;
}

@synthesize messagesViewController = messagesViewController;

@synthesize toolbar = toolbar;
@synthesize autoGrowTextView = autoGrowTextView;
@synthesize sendButton = sendButton;
@synthesize optionsButton = optionsButton;

@dynamic typedText;


- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		[self commonInit];
	}
	return self;
}

- (void)awakeFromNib
{
	[self commonInit];
}

- (void)commonInit
{
	// Init ivars
	
	canEnableSendButtonIfHasText = YES;
	
	// Capture initial state
	
	heightPadding = self.frame.size.height - autoGrowTextView.frame.size.height;
	minHeight = self.frame.size.height;
	
	// Configure textView
	//
	// Note: We tweak the insets to give us a few more pixels to work with.
	// We want the text to be rather tight within the textView,
	// rather than the usual abundance of vertical paddint (top & bottom) that is the default on iOS.
	//
	// Default on iOS 7 : { top=8, right=0, bottom=8, left=0 }
	// Default on iOS 8 : { top=8, right=0, bottom=8, left=0 }
	
	UIEdgeInsets modifiedInsets = autoGrowTextView.textContainerInset;
	modifiedInsets.top -= 2;
	modifiedInsets.bottom -= 2;
	autoGrowTextView.textContainerInset = modifiedInsets;
	
	autoGrowTextView.delegate = self;
	
	autoGrowTextView.keyboardAppearance = UIKeyboardAppearanceDark;
	autoGrowTextView.returnKeyType = UIReturnKeyDefault;
	
	autoGrowTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
	autoGrowTextView.layer.borderWidth = 1.0;
	autoGrowTextView.layer.cornerRadius = 4.0;
	
	// Configure optionsButton
    
    //ET 12/16/14 increase tap target with invisible underlying button
    // -- a quick hack to address difficulty in hitting the original
    // button with size of 23x23 without modifying the button image.
    [_btnOptionsTapTarget addTarget:self.messagesViewController
                             action:@selector(chatOptionsPress:)
                   forControlEvents:UIControlEventTouchUpInside];
    //03/28/15 - Accessibility
    // Make this a non-accessibility control. If this is not disabled here,
    // VoiceOver will speak "button" when finger moving from chatOptions button.
    _btnOptionsTapTarget.isAccessibilityElement = NO;


    // orig optionsButton assignmnet to messagesVC handler
	[optionsButton addTarget:self.messagesViewController
	                  action:@selector(chatOptionsPress:)
	        forControlEvents:UIControlEventTouchUpInside];
    optionsButton.accessibilityLabel = NSLocalizedString(@"Chat options", @"Chat Options button - accessibility label");
	
	// Configure send button
	
	[sendButton setTitle:NSLocalizedString(@"Send", @"Send") forState:UIControlStateNormal];
	
	[sendButton setTitleColor:self.tintColor forState:UIControlStateNormal];
//	[sendButton setTitleColor:self.tintColor forState:UIControlStateDisabled];
	
	if (AppConstants.isIPad)
		sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
	else
		sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
	
	[sendButton addTarget:self
	               action:@selector(sendButtonTapped:)
	     forControlEvents:UIControlEventTouchUpInside];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Dynamic Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)typedText
{
	return autoGrowTextView.text;
}

- (void)setTypedText:(NSString *)text
{
	if ([autoGrowTextView.text isEqualToString:text]) return;
	
	autoGrowTextView.text = text;
	[self textViewDidChange:autoGrowTextView];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Send Button
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateSendButtonEnabled
{
	if (canEnableSendButtonIfHasText)
	{
		NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
		NSString *trimmedString = [self.typedText stringByTrimmingCharactersInSet:whitespace];
		
		sendButton.enabled = (trimmedString.length > 0);
	}
	else
	{
		sendButton.enabled = NO;
	}
}

- (void)enableSendButtonIfHasText:(BOOL)enableAllowed
{
	DDLogAutoTrace();
	
	canEnableSendButtonIfHasText = enableAllowed;
	[self updateSendButtonEnabled];
}

- (void)sendButtonTapped:(AutoGrowingTextView *)sender
{
	DDLogAutoTrace();
	
	[self.messagesViewController inputViewWillTemporarilyLoseFirstResponder];
	[autoGrowTextView acceptSuggestionWithoutDismissingKeyboard];
	[self.messagesViewController inputViewDidTemporarilyLoseFirstResponder];
	
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSString *trimmedString = [autoGrowTextView.text stringByTrimmingCharactersInSet:whitespace];
	
	if (trimmedString.length == 0) {
		return;
	}
	
	[self.messagesViewController sendButtonTappedWithText:trimmedString];
	
	self.typedText = @"";
	
    // Prevent crash with shake gesture, clear undo history. (ST-736)
    [autoGrowTextView.undoManager removeAllActions];
	
	if (![autoGrowTextView isFirstResponder])
	{
		[self.messagesViewController inputViewIsActive:NO];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark TextView Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)textViewDidBeginEditing:(UITextView *)textView
{
	DDLogAutoTrace();
	
	[self.messagesViewController inputViewIsActive:YES];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
	DDLogAutoTrace();
	
	if ([textView.text length] == 0)
	{
		[self.messagesViewController inputViewIsActive:NO];
	}
}

/**
 * The text view calls this method in response to user-initiated changes to the text.
 * 
 * IMPORTANT:
 * This method is ***** not [automatically] called in response to programmatically initiated changes. *****
**/
- (void)textViewDidChange:(UITextView *)textView
{
	DDLogAutoTrace();
	
	CGFloat desiredHeight = [self intrinsicContentSize].height;
	CGFloat currentHeight = self.frame.size.height;
	
	if (desiredHeight != currentHeight)
	{
		[UIView animateWithDuration:0.1 animations:^{
		
			[autoGrowTextView invalidateIntrinsicContentSize];
			[self invalidateIntrinsicContentSize];
			
			pendingFrameSizeChange = YES;
		
		} completion:^(BOOL finished) {
		
			// When this completion block hits, autoGrowTextView.frame isn't updated yet.
			// So we're using the pendingFrameSizeChange hack instead.
			//
			// And yes, I also tried adding [self layoutIfNeeded], and it didn't help.
		}];
	}
	
	[self updateSendButtonEnabled];
	[self.messagesViewController inputViewTextChanged];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Misc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	if (pendingFrameSizeChange)
	{
		pendingFrameSizeChange = NO;
		
		if (autoGrowTextView.contentSize.height > autoGrowTextView.frame.size.height) {
			[autoGrowTextView scrollRangeToVisible:autoGrowTextView.selectedRange];
		}
		else {
			[autoGrowTextView setContentOffset:CGPointMake(0, 0) animated:YES];
		}
		
		[self.messagesViewController inputViewSizeChanged];
	}
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
	// The default code
	if (CGRectContainsPoint(self.bounds, point))
		return YES;
	
	// The chatOptionsView is outside the bounds of our inputView.
	// We extend this method to include taps within this area.
	
	for (UIView *subview in self.subviews)
	{
		if (CGRectContainsPoint(subview.frame, point))
			return YES;
		if ([subview pointInside:point withEvent:event])
			return YES;
	}
	
	return NO;
}

- (CGSize)intrinsicContentSize
{
	CGFloat textViewHeight = [autoGrowTextView intrinsicContentSize].height;
	
	CGFloat newHeight = textViewHeight + heightPadding;
	newHeight = MAX(newHeight, minHeight);
	
    return CGSizeMake(UIViewNoIntrinsicMetric, newHeight);
}

@end
