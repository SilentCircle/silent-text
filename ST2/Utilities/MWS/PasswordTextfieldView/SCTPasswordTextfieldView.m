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
//  SCTPasswordTextfieldView.m
//  ST2
//
//  Created by Eric Turner on 7/1/14.
//

#import "SCTPasswordTextfieldView.h"
#import "AppTheme.h"
#import "BBPasswordStrength.h"
#import "SCTGradientShapeButton.h"
#import "SCTPasswordTextfield.h"


@interface SCTPasswordTextfieldView ()

#pragma mark - Private Properties

/** A view of SCTShapeButtons for use as entropy-test level indicatators */
@property (nonatomic, weak) IBOutlet SCTShapeButtonsView *shapeButtonsView;

/** A view for setting a background color under the gradient view. The gradient mask hides the enclosing view. This
    view exposes another enclosing view for a backdrop to the gradient. */
@property (nonatomic, weak) IBOutlet UIView *shapeButtonsBackgroundView;

/** A view of SCTShapeButtons for use as entropy-test level indicatators */
@property (nonatomic, weak) IBOutlet SCTGradientShapeButton *btnGradient;

@property (nonatomic) BOOL entropyViewIsVisible;
@end


@implementation SCTPasswordTextfieldView 


#pragma mark - Initialization

/**
 * Configures the self tintColor with the app theme color, and configures the entropy view with gradient colors and
 * background view outline.
 */
- (void) awakeFromNib 
{    
    // Default to app theme color
    AppTheme *theme = [AppTheme getThemeBySelectedKey];
    self.tintColor = theme.appTintColor;
    _passwordField.entropyDelegate = self; // set explicitly

    // Configure shapeButtonsBackgroundView as background for gradient view
    CALayer *layer = _shapeButtonsBackgroundView.layer;
    layer.cornerRadius = _shapeButtonsBackgroundView.frame.size.height / 2;
    layer.borderWidth  = 1;
    UIColor *borderColor = [self.tintColor colorWithAlphaComponent:0.35];
    layer.borderColor  = borderColor.CGColor;
    _shapeButtonsBackgroundView.clipsToBounds = YES;

    // Set color positions for gradient: red to green, linear
    [_btnGradient setColorsFrom:0 toEnd:120];
    
    //Hide entropy bar until it contains text
    [self showEntopy:NO];
}


#pragma mark - SCTPasswordEntropyDelegate

/**
 * This method updates the gradient progress with the password entropy value, and fades in the entropy view if the
 * entropy value is greater than zero, and fades out the entropy view if the value is zero.
 *
 * Note: this method only invokes the `showEntropy:` method if the entropy view should be visibile and is not, or
 * vice versa.
 *
 * @param strength
 */
- (void) passwordEntropyDidChange:(BBPasswordStrength *) strength 
{
    BOOL shouldDisplayEntropyView = (strength.entropy > 0);
    if (NO == _entropyViewIsVisible && shouldDisplayEntropyView) {
        [self showEntopy:YES];
    }
    else if (NO == shouldDisplayEntropyView && _entropyViewIsVisible) {
        [self showEntopy:NO];
    }
    CGFloat val = strength.entropy / 42;    
    _btnGradient.progress = val;
}

/**
 * This delegate callback fires the `showEntropy:` method to fade in the entropy view if the textfield contains text.
 *
 * @param textField An SCTPasswordTextfield instance.
 * @param The return value of this method is ignored by the sender.
 */
- (BOOL) textFieldShouldBeginEditing:(UITextField *)textField
{
    [self showEntopy: (textField.text.length > 0)];
    return YES;
}

/**
 * This delegate callback fires the `showEntropy:` method to fade out the entropy view.
 *
 * @param textField An SCTPasswordTextfield instance.
 */
- (void) textFieldDidEndEditing:(UITextField *)textField 
{
    [self showEntopy:NO];
}


#pragma mark - Utilities

/**
 * Fades the entropy view in or out.
 *
 * Fades in the `shapeButtonsBackgroundView` and sets the `entropyViewIsVisible` flag in the completion block.
 *
 * @param yesno `YES` to fade `shapeButtonsBackgroundView` in, or `NO` to fade out.
 */
- (void)showEntopy:(BOOL)yesno
{
    [UIView animateWithDuration:0.25 
                     animations:^{
                         _shapeButtonsBackgroundView.alpha = (yesno) ? 1 : 0; 
                     } 
                     completion:^(BOOL finished) {
                         _entropyViewIsVisible = yesno;
                     }];
}

@end
