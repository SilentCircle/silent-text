/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

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
//  SCTTextField.m
//  ST2
//
//  Created by Eric Turner on 6/30/14.
//

#import "SCTPasswordTextfield.h"
#import "BBPasswordStrength.h"
#import "STLogging.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)

@interface SCTPasswordTextfield ()

@property (nonatomic, weak) id<UITextFieldDelegate> privateDelegate;
@property (nonatomic) BOOL eyeWasOpen;

@end


@implementation SCTPasswordTextfield

#pragma mark - Initialization

- (instancetype) initWithFrame:(CGRect) aRect
{
    self = [super initWithFrame:aRect];
    if (!self) return nil;
    
    self.delegate = self;
    
    self.secureTextEntry = YES;
    self.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.rightViewMode = UITextFieldViewModeAlways;
    self.tintColor = self.superview.tintColor;
    
    // Setup button with eye images in rightView property
	CGRect frame = CGRectMake(0, 0, 30, 30);
	_eyeball = [[SCTEyeball alloc] initWithFrame:frame];
    [_eyeball addTarget:self action:@selector(eyeballWasPoked:) forControlEvents:UIControlEventTouchUpInside];
    self.rightView = _eyeball;

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    self.secureTextEntry = YES;
    self.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.rightViewMode = UITextFieldViewModeAlways;
    self.tintColor = self.superview.tintColor;
        
    // Setup button with eye images in rightView property
	CGRect frame = CGRectMake(0, 0, 30, 30);
	_eyeball = [[SCTEyeball alloc] initWithFrame:frame];
    [_eyeball addTarget:self action:@selector(eyeballWasPoked:) forControlEvents:UIControlEventTouchUpInside];
    self.rightView = _eyeball;
    
    return self;
}

- (void)awakeFromNib 
{
    self.delegate = self;
}

#pragma mark - Delegate swizzle

/**
 * Override setter to initialize delegate as self and set argument as privateDelegate.
 *
 * The "delegate" UITextField property is set to self to intercept the 
 * textField:shouldChangeCharactersInRange:replacementString: callback in order to perform input string validation on
 * input string characters, and password strength testing. The private delegate property is implemented to "pass
 * through" UITextFieldDelegate callbacks.
 *
 * @param aDelegate An object conforming to the UITextFieldDelegate protocol to which to forward delegate messages.
 */
- (void)setDelegate:(id<UITextFieldDelegate>)aDelegate
{
    [super setDelegate:self];
    if (aDelegate != self)
    {
        _privateDelegate = aDelegate;
    }
}


#pragma mark - Password Validity Logic

/**
 * This readonly property is where rules for password validity should be implemented. The expectation is that it will
 * be based on some combination of minimum string length and entropy score.
 */
- (BOOL) passwordIsValid 
{
    // Currently the only "passing" criteria is that the password length is 1 character or more
    return (self.text.length > 0);
}


#pragma mark - UITextFieldDelegate  customization method

/**
 * This class, as its own delegate, implements this UITextFieldDelegate callback to intercept user-entered text or
 * deleted text messages to validate the a password string for validity against a character set, and to assess password
 * strength.
 * 
 * A BBPassword instance is initialized with the full prospective password string and the self password strength
 * properties updated.
 *
 * If the password score is changed by the string replacement, both the `passwordTextfieldDelegate` and the
 * `entropyDelegate` delegates are messaged with the strength object.
 * 
 * ## WORKAROUND
 *
 * The problem: as a password textfield, the secureTextEntry UITextInputTrait flag is set by default. When there is an
 * existing text string and the user toggles the secureTextEntry flag off to display the string as plain text, if the
 * user toggles back to secureTextEntry, the default Apple behavior is to delete the existing string at the next input.
 *
 * Presumably, Apple implements this behavior on the assumption that a user edit of an obscured text string is a 
 * actually a request to start over, since ordinarily the string characters are obscured. 
 *
 * Note that this (undesired) default behavior is executed after the return of this method.
 *
 * Additionally, there is an iOS7, iOS7.1 bug that puts a space or carriage return after the text when secureTextEntry
 * is toggle off, which is handled in the `eyeballPokeAction:` "toggling" method.
 *
 * The workaround: this method is messaged with the original textfield.text which is captured and trimmed. As the 
 * delete behavior is executed by the Apple frameworks after this method returns, a message is dispatched 
 * asynchronously back to the main thread, resetting the text property with the string which results from the 
 * replacement handling with the pre-invocation text value.
 *
 * @param textField The text field containing the text.
 * @param range The range of characters to be replaced.
 * @param string The replacement string.
 * @return `YES` if the specified text range should be replaced; otherwise, `NO` to keep the old text.
 */
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range 
replacementString:(NSString *)string
{    
    NSString *testStr = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
#pragma mark - WORKAROUND: secureTextEntry string loss
    testStr = [testStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL eyeIsNowClosed = !self.eyeball.isOpen;

    if ((_eyeWasOpen && eyeIsNowClosed) && testStr.length > 0) 
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            textField.text = testStr;
            [self sendActionsForControlEvents:UIControlEventEditingChanged];
            _eyeWasOpen = NO;
        });
    }
    
    // Test charset legality
    for (int i = 0; i < [string length]; i++) 
    {
        unichar c = [string characterAtIndex:i];
        if (! [self.passwordCharSet characterIsMember:c] ) 
        {
            return NO;
        }
    }
    
    // DDLogPurple(@"text: %@, string: %@, range: %@", textField.text, string, NSStringFromRange(range));
              
    NSUInteger previousScore = _score;
    double previousEntropy   = _entropy;

    BBPasswordStrength *strength = [[BBPasswordStrength alloc] initWithPassword:testStr];
    double entropyperchar = strength.entropy / testStr.length;
    _crackTime          = strength.crackTime;
    _crackTimeDisplay   = strength.crackTimeDisplay;
    _entropy            = strength.entropy;
    _entropyperchar     = round(entropyperchar * 1000) / 1000;
    _matchSequence      = strength.matchSequence;
    _score              = strength.score;
    _scoreLabel         = strength.scoreLabel;
        
//    DDLogPurple(@"%u Cracked in %@! - ereEntropy: %.3f ", 
//                (int) strength.score, strength.crackTimeDisplay, strength.entropy);

    
    // Message score change to delegates

    if (previousScore != _score) 
    {        
        if ([_passwordTextfieldDelegate respondsToSelector:@selector(passwordStrengthDidChange:)]) 
        {
            [_passwordTextfieldDelegate passwordStrengthDidChange: strength];
        }
        
        if ([_entropyDelegate respondsToSelector:@selector(passwordStrengthDidChange:)]) 
        {
            [_entropyDelegate passwordStrengthDidChange: strength];
        }

    }

    // Message entropy change to delegates
    
    if (previousEntropy != _entropy)
    {
            if ([_passwordTextfieldDelegate respondsToSelector:@selector(passwordEntropyDidChange:)]) 
            {
                [_passwordTextfieldDelegate passwordEntropyDidChange: strength];
            }
            
            if ([_entropyDelegate respondsToSelector:@selector(passwordEntropyDidChange:)]) 
            {
                [_entropyDelegate passwordEntropyDidChange: strength];
            }
    }

    // Return privateDelegate return value
    if ([_privateDelegate respondsToSelector:
         @selector(textField:shouldChangeCharactersInRange:replacementString:)]) 
    {
            return [_privateDelegate textField:textField 
                 shouldChangeCharactersInRange:range 
                             replacementString:string];
    }
    
    return YES;
}


#pragma mark - UITextFieldDelegate Methods (pass thru)

/** 
 * Passes through the [UITextFieldDelegate textFieldShouldBeginEditing:] callback.
 *
 * When the user performs an action that would normally initiate an editing session, the text field calls
 * this method first to see if editing should actually proceed. In most circumstances, you would simply
 * return YES from this method to allow editing to proceed.
 *
 * @param textField Active textField instance passed by the UITextFieldDelegate callback.
 * @return Boolean indicating whether to begin editing
 */
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if ([_privateDelegate respondsToSelector:@selector(textFieldShouldBeginEditing:)]) 
    {
        return [_privateDelegate textFieldShouldBeginEditing:textField];
    }
    if ([_entropyDelegate respondsToSelector:@selector(textFieldShouldBeginEditing:)])
    {
        [_entropyDelegate textFieldShouldBeginEditing:textField];
    }
    return YES;
}

/** 
 * Passes through the [UITextFieldDelegate textFieldDidBeginEditing:] callback.
 *
 * This method notifies the delegate that the specified text field just became the first responder. You can use
 * this method to update your delegate’s state information. For example, you might use this method to show
 * overlay views that should be visible while editing. 
 *
 * @param textField Active textField instance passed by the UITextFieldDelegate callback.
 */
- (void)textFieldDidBeginEditing:(UITextField *)textField 
{
    if ([_privateDelegate respondsToSelector:@selector(textFieldDidBeginEditing:)]) 
    {
        [_privateDelegate textFieldDidBeginEditing:textField];
    }
    if ([_entropyDelegate respondsToSelector:@selector(textFieldDidBeginEditing:)]) 
    {
        [_entropyDelegate textFieldDidBeginEditing:textField];
    }
}

/** 
 * Passes through the [UITextFieldDelegate textFieldShouldEndEditing:] callback.
 *
 * This method is called when the text field is asked to resign the first responder status. This might occur when
 * your application asks the text field to resign focus or when the user tries to change the editing focus to another
 * control. Before the focus actually changes, however, the text field calls this method to give your delegate a chance
 * to decide whether it should.
 *
 * Normally, you would return YES from this method to allow the text field to resign the first responder status.
 * You might return NO, however, in cases where your delegate detects invalid contents in the text field. By returning NO,
 * you could prevent the user from switching to another control until the text field contained a valid value. 
 * 
 * @param textField Active textField instance passed by the UITextFieldDelegate callback.
 * @return Boolean indicator back to the UIKeyboard whether to process the Done key event
 */
- (BOOL)textFieldShouldEndEditing:(UITextField *)textField 
{
    if ([_privateDelegate respondsToSelector:@selector(textFieldShouldEndEditing:)]) 
    {
        return [_privateDelegate textFieldShouldEndEditing:textField];
    }
    if ([_entropyDelegate respondsToSelector:@selector(textFieldShouldEndEditing:)]) 
    {
        [_entropyDelegate textFieldShouldEndEditing:textField];
    }
    return YES;    
}

/**
 * Passes through the [UITextFieldDelegate textFieldShouldClear:] callback.
 *
 * The text field calls this method in response to the user pressing the built-in clear button. (This button is not 
 * shown by default but can be enabled by changing the value in the clearButtonMode property of the text field.) This
 * method is also called when editing begins and the clearsOnBeginEditing property of the text field is set to YES.
 *
 * Implementation of this method by the delegate is optional. If it is not present, the text is cleared as if this 
 * method had returned YES.
 *
 * @param textField Active textField instance passed by the UITextFieldDelegate callback.
 * @return `YES` if textfield should clear, `NO` otherwise.
 */
- (BOOL)textFieldShouldClear:(UITextField *)textField 
{
    if ([_privateDelegate respondsToSelector:@selector(textFieldShouldClear:)]) 
    {
        return [_privateDelegate textFieldShouldClear:textField];
    }
    if ([_entropyDelegate respondsToSelector:@selector(textFieldShouldClear:)]) 
    {
        [_entropyDelegate textFieldShouldClear:textField];
    }
    return YES;
}

/** 
 * Passes through the [UITextFieldDelegate textFieldDidEndEditing:] callback.
 *
 * This method is called after the text field resigns its first responder status. You can use this method to
 * update your delegate’s state information. For example, you might use this method to hide overlay views that
 * should be visible only while editing.
 * 
 * @param textField Active textField instance passed by the UITextFieldDelegate callback.
 */
- (void)textFieldDidEndEditing:(UITextField *)textField 
{
    if ([_privateDelegate respondsToSelector:@selector(textFieldDidEndEditing:)]) 
    {
        [_privateDelegate textFieldDidEndEditing:textField];
    }    
    if ([_entropyDelegate respondsToSelector:@selector(textFieldDidEndEditing:)]) 
    {
        [_entropyDelegate textFieldDidEndEditing:textField];
    }    
}

/** 
 * Passes through the [UITextFieldDelegate textFieldShouldReturn:] callback.
 *
 * The text field calls this method whenever the user taps the return button. You can use this method to implement
 * any custom behavior when the button is tapped. 
 * 
 * @param textField Active textField instance passed by the UITextFieldDelegate callback.
 * @return Boolean indicator back to the UIKeyboard whether to process the Done key event
 */
- (BOOL)textFieldShouldReturn:(UITextField *)textField 
{
    if ([_privateDelegate respondsToSelector:@selector(textFieldShouldReturn:)]) 
    {
        return [_privateDelegate textFieldShouldReturn:textField];
    }
    if ([_entropyDelegate respondsToSelector:@selector(textFieldShouldReturn:)]) 
    {
        [_entropyDelegate textFieldShouldReturn:textField];
    }
    return YES;
}


#pragma mark - Actions
/**
 * Toggle the secureTextEntry UITextInputTrait to display obscured text as plain, and vice versa.
 *
 * If the eye is tapped opened and the self textfield is not firstResponder, make self first responder.
 *
 * ## WORKAROUND
 *
 * There is an iOS7, iOS7.1 bug that puts a space or carriage return after the text when secureTextEntry
 * is toggled off. The workaround solution is to trim the existing string and restore the text property with the trimmed
 * string after the toggle.
 *
 * @param eye The SCTEyeball instance messaged by the `[SCTEyeballDelegate eyeballWasPoked:]` callback.
 */
- (void) eyeballPokeAction:(SCTEyeball *) eye 
{
#pragma mark - WORKAROUND: secureTextEntry toggle newline   
    NSString *cachedStr = [self.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (eye.isOpen && !self.isFirstResponder) {
        [self becomeFirstResponder];
    }
    if (eye.isOpen)
    {
        _eyeWasOpen = YES;
    }
    self.secureTextEntry = !eye.isOpen;
    self.text = cachedStr;
}


#pragma mark - SCTEyeballDelegate Methods

/**
 * This callback method is messaged when the eyeyball control is tapped, optionally, toggling the secureTextEntry 
 * property, and messaging the `SCTTextFieldPasswordDelegate`.
 *
 * The default behavior of this method, regardless of a delegate, is toggling the self secureTextEntry UITextInputTrait
 * on and off for eyeball tap events by invoking the `eyeballPokeAction:` method to display/obscure password text.
 * If the `pokeIsDisabled` flag is set, `eyeballPokeAction:` is not called.
 *
 * @param eye The SCTEyeball control instance, as the self rightView property.
 */
- (void) eyeballWasPoked:(SCTEyeball *) eye {

    // Default: nil passwordTextFieldDelegate and clear pokeIsDisabled flag
    if (nil == self.passwordTextfieldDelegate && !self.pokeIsDisabled) {
        [self eyeballPokeAction: eye];
    }
    
    // Default behavior and didReceiveEyeballPokeAction: callback
    else if (self.passwordTextfieldDelegate && !self.pokeIsDisabled) {
        [self eyeballPokeAction: eye];
        if ([_passwordTextfieldDelegate respondsToSelector:@selector(didReceiveEyeballPokeAction:)]) 
        {
            [self.passwordTextfieldDelegate didReceiveEyeballPokeAction:eye];
        }
    }
    
    // didReceiveEyeballPokeAction: callback and default behavior disabled
    else if (self.passwordTextfieldDelegate && self.pokeIsDisabled) 
    {
        if ([self.passwordTextfieldDelegate respondsToSelector:@selector(didReceiveEyeballPokeAction:)]) 
        {
            [self.passwordTextfieldDelegate didReceiveEyeballPokeAction:eye];
        }
    }
}



#pragma mark - Accessors

/**
 * @return A self-initialized default NSCharacterSet against which to evaluate passord strings.
 */
- (NSCharacterSet *)passwordCharSet {
    if (nil == _passwordCharSet) {
        NSMutableCharacterSet* charSet = [[NSMutableCharacterSet alloc] init];
        [charSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        [charSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [charSet formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
        [charSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
        _passwordCharSet = charSet;
    }
    return _passwordCharSet;
}


@end
