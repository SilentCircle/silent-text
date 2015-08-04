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
//  SCTPasswordTextfield
//  ST2
//
//  Created by Eric Turner on 6/30/14.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCTPasswordTextfieldDelegate.h"
#import "SCTPasswordFieldEntropyDelegate.h"
#import "SCTEyeball.h"

// ET 07/03/14
/** 
 * Extends the UITextField to present an eyeball with open/close behavior, to display obscured password text as
 * plain text when the eye is "open", and to implement password validity logic.
 *
 * ## Password Validation
 *
 * This class overrides the setDelegate: setter to initialize itself as its own UITextFieldDelegate. In setDelegate: 
 * self is set as the delegate and the caller instance is stored in a private "privateDelegate" property. The result is 
 * that the self instance intercepts the textField:shouldChangeCharactersInRange:replacementString: callback to perform
 * password strength and character validity tests. Consumers wishing to receive these delegate callbacks may set 
 * themselves as the delegate property as usual.
 *
 * Note that the passwordCharSet property may be set from the outside to perform character validity with non-default
 * NSCharacterSet criteria. The default set consists of the alphanumericCharacterSet, punctuationCharacterSet, and
 * symbolCharacterSet NSCharacterSets.
 *
 * The isValid accessor is intended to be the central point for password validation logic. This boolean return value
 * can be any combination of password string length, entropy strength, etc.
 *
 * The BBPasswordStrength class is the entropy testing under-the-hood implementation. This class exposes the
 * BBPasswordStrength property values in dedicated properties.
 *
 * The strength of a password string changes as the user enters and deletes characters in the textfield. When the
 * BBPasswordStrength rating changes, a passwordStrengthDidChange: message is sent to the SCTPasswordTextfieldDelegate
 * and SCTPasswordFieldEntropyDelegate instances, passing the strength object. This allows the SCTPasswordTextfieldView
 * as the entropyDelegate to receive strength change updates to update the UI,  and also for interested 
 * passwordTextfieldDelegates to be messaged with the strength change.
 *
 * ## The Eyeball
 *
 * The basic "eyeball" behaviors implemented in this class should work as expected in view controllers managing a 
 * password textfield simply by making the textfield an instance of this class. This may be added in Interface Builder.
 *
 * When the "eye is poked", i.e., the `SCTEyeball` control is tapped, the eye image toggles between "open" and "closed".
 * Also, obscured password text is toggled to display as plain text when the "eye is open", then back to obscured text
 * when the eye is poked again.
 *
 * These behaviors are the default and require only that the password textfield be an instance of this class. This can
 * be set in Interface Builder.
 *
 * For controllers needing to extend the base eyeball behaviors:
 *   - Initialize the `passwordTextfieldDelegate` property and implement the 
 *     `[SCTPasswordTextfieldDelegate didReceiveEyeballPokeAction:]` callback.
 *
 *   - to receive delegate callback without the default behaviors, set the `pokeIsDisabled` flag property.
 *
 * Note: Changing the tintColor of the view in the containing superview updates the color of the eye image immediately.
 *
 * For an eye "poke" action, this class tests the `pokeIsDisabled` flag and tests for a delegate supporting the callback. 
 * This allows for several scenarios:
 *   - Default behavior:
 *     Make the password field an instance of this class; nothing else required.
 *
 *   - Default behavior with or without UITextFieldDelegate callbacks:
 *     Set (superclass) `delegate` property as desired for UITextFieldDelegate callbacks. No other configuration.
 *
 *   - No default or custom behavior, with or without UITextFieldDelegate callbacks:
 *     Set the `pokeIsDisabled` flag. Set (superclass) `delegate` property as desired for UITextFieldDelegate callbacks.
 *
 *   - Default behavior AND extended behaviors, with or without UITextFieldDelegate callbacks:
 *     Set the `passwordTextfieldDelegate` property and implement the 
 *     `[SCTPasswordTextfieldDelegate didReceiveEyeballPokeAction:]` callback. Leave the `pokeIsDisabled` flag unset. 
 *     Extend the default behaviors in the callback.
 *
 *   - Only custom (or no) behaviors, with or without UITextFieldDelegate callbacks:
 *     Set the `passwordTextfieldDelegate` property and implement the 
 *     `[SCTPasswordTextfieldDelegate didReceiveEyeballPokeAction:]` callback. Set the `pokeIsDisabled` flag (set to
 *     `YES`) to disable the default behaviors. Implement desired behaviors in the callback.
 *
 * ## History
 *
 * (06/30/14)
 * 1. The original implementation of eye image and secure text toggling behaviors was implemented in a view controller.
 *    An undesired artefact of an eye implemented as UIButton, set as the textfield rightView property, was that the 
 *    button background displayed as a colored rectangle with the view tintColor behind the open eye icon. This was a 
 *    result of the default masking behavior of the button in the textfield.rightView when selected.
 *
 * 2. This class implements the secure text toggling behavior. The `eyeball` control property implements the toggling
 *    eye image behavior, messaging this control for UIControlEventTouchUpInside events.
 *
 * (07/03/14)
 * 3. The first use case of this control is in CreateAccountViewController. Previously, it performed password checking
 *    in the UITextFieldDelegate textField:shouldChangeCharactersInRange:replacementString: callback, along with checks
 *    on the username field. With all password validation logic now implemented in this control, 
 *    CreateAccountViewController simply accesses the passwordIsValid property value.
 *
 * (07/07/14)
 * 4. Per suggestion by Robbie Hanson, the previous implementation requiring use of the passwordTextfieldDelegate to
 *    receive UITextFieldDelegate callbacks was refactored to override the setDelegate: method to intercept password
 *    input to perform the character validity and strength functions. Additionally, the workaround for the undesired
 *    secureTextEntry toggling issues required additionally messaging targets of the UIControlEventEditingChanged
 *    UIControlEvent.
 *
 * @see SCTEyeball
 * @see SCTPasswordFieldView
 * @see BBPasswordStrength
 * @see SCTPasswordTextfieldDelegate
 * @see SCTPasswordFieldEntropyDelegate
 */
@interface SCTPasswordTextfield : UITextField <UITextFieldDelegate>

#pragma mark - SCTEyeball Properties

/** A delegate for messaging password strength values. */
@property (nonatomic, weak) IBOutlet id<SCTPasswordFieldEntropyDelegate> entropyDelegate;

/** The eyeyball icon */
@property (nonatomic, strong) SCTEyeball *eyeball;

/** A delegate for extending default behaviors via `SCTPasswordTextfieldDelegate` callback. */
@property (nonatomic, weak) IBOutlet id<SCTPasswordTextfieldDelegate> passwordTextfieldDelegate;

/** Set this flag to `YES` to disable default behavior. */
@property (nonatomic) BOOL pokeIsDisabled;


#pragma mark - Password Properties

/** A BBPasswordStrength calculation of how long to crack the current `password` text value. */
@property (nonatomic) double crackTime;

/** A BBPasswordStrength casual string description of `crackTime`, e.g., "no time" or "6 days". */
@property (nonatomic, strong) NSString *crackTimeDisplay;

/** An entropy value calculated by BBPasswordStrength on the `password` text value. */
@property (nonatomic) double entropy;

/** An entropy value calculated (by Vinnie) on the replacement character(s) of the last password text entry. */
@property (nonatomic) double entropyperchar;

/** An array of values initialized and evaluated by BBPasswordStrength in calculating `entropy`. */
@property (nonatomic, strong) NSArray *matchSequence;

/** The password text of the textfield. */
@property (nonatomic, strong) NSString *password;

/** The inclusive charset against which to test password characters.
 * Note: This property is lazy loaded with a self-initializing accessor. The default characterSet includes 
 * alphanumericCharacterSet, punctuationCharacterSet, and symbolCharacterSet (no white space characters). This property
 * may be initialized with a preferred characterSet with which it will evaluate the return value of the
 * UITextFieldDelegate textField:shouldChangeCharactersInRange:replacementString:. */
@property (nonatomic, strong) NSCharacterSet *passwordCharSet;

/** The central implementation of logic evaluating password validity. */
@property (nonatomic, readonly) BOOL passwordIsValid;

/** An integer score from 0 - 4 calculated by BBPasswordStrength, rating the `password` strength. */
@property (nonatomic) NSUInteger score;

/** A BBPasswordStrength casual string description of `score`, e.g., "Very Weak" or "Great!". */
@property (nonatomic, strong) NSString *scoreLabel;

/**
 * Toggles the display of password text characters between security-obscured and plain text, if the value of 
 * `pokeIsDisabled` is `NO`. Also resigns textfield as firstResponder if currently firstResponder.
 *
 * @param eye The SCTEyeball as the UITextField rightView property
 * @see SCTEyeball
 */
- (void) eyeballPokeAction:(SCTEyeball *) eye;

@end
