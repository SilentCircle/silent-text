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
//  SCTPinLockKeypad.m
//  ST2
//
//  Created by Eric Turner on 7/1/14.
//


#import "SCTPinLockKeypad.h"
#import "SCTShapeButton.h"
#import "SCTShapeButtonConstants.h"
#import "SCTShapeButtonsView.h"
#import "SCTPinLockScreenConstants.h"
#import "UIColor+FlatColors.h"

@interface SCTPinLockKeypad () <SCTShapeButtonDelegate>

/** A storage array for collecting titles of `SCTShapeButtons` entered by user */
@property (strong, nonatomic) NSMutableArray *arrEntries;

/** A dual-purpose button for handling entry deletes and log out events. */
@property (weak, nonatomic) IBOutlet UIButton *btnLogoutDelete;

/** A subview containing the small `SCTShapeButton`s. These fill for user pad entries. */
@property (weak, nonatomic) IBOutlet SCTShapeButtonsView *circleButtonsView;

/** A subview containing the tappable `SCTShapeButton`s */
@property (weak, nonatomic) IBOutlet UIView *mainButtonsView;

/** A subview containing the top label; default title is "Enter passcode" */
@property (weak, nonatomic) IBOutlet UILabel *topLabel;

@end


@implementation SCTPinLockKeypad


#pragma mark - Layout

/**
 * Sets the `btnLogoutDelete` button title, initializes user's entries storage array, configures circleButtons in 
 * subviews with a color, and sets view/subview background colors to clear.
 *
 * The self view and subviews are set with clearColor backgrounds at hydration from storyboard, for
 * the intended effect of the `SCTLockScreenVC` blurred background view; in IB these background
 * colors are set for visibility at design time.
 */
- (void)awakeFromNib {
    // Clear "Cancel" button title, set in IB
    [self.btnLogoutDelete setTitle: SCT_LOGOUT_TITLE forState: UIControlStateNormal];
    
    // initialize arrEntries
    self.arrEntries = [NSMutableArray arrayWithCapacity: SCT_PIN_ENTRIES_COUNT];

    // Configure "tracking" circles in shapeButtonsView with superview tintColor
    UIColor *btnsColor = self.superview.tintColor;
    
    //-------------------------------- Make all shapes circles and configure with btnsColor --------------------------//
    // optionsDict with color and shape configurations
    NSMutableDictionary *mDict = [NSMutableDictionary dictionaryWithDictionary:
                                  [SCTShapeButtonsView shapeOptionsWithColor:btnsColor]];
    [mDict setObject:[NSNumber numberWithBool:YES] forKey:SCT_ShapeButton_isCircleShape];
    NSDictionary *optionsDict = [NSDictionary dictionaryWithDictionary:mDict];
    
    // configure tracking circles (non-keypad circles in _circleButtonsView)
    [_circleButtonsView configureAllShapesWithOptions:optionsDict];
    
    // configure keypadButtons (keypad circles in _mainButtonsView)
    NSArray *keypadButtons = [SCTShapeButtonsView shapeButtonsInView:_mainButtonsView];
    [SCTShapeButtonsView configureShapeButtons:keypadButtons withOptions:optionsDict];
    //----------------------------------------------------------------------------------------------------------------//
                                 
    // clear subview background colors.
    // Background colors are likely set in IB for visual convenience for layout, but are set to clear here at runtime
    self.backgroundColor = [UIColor clearColor];
    self.mainButtonsView.backgroundColor = [UIColor clearColor];
    self.circleButtonsView.backgroundColor = [UIColor clearColor];
    self.topLabel.backgroundColor = [UIColor clearColor];
}


#pragma mark - SCTShapeButtonDelegate Methods

/**
 * Invokes the fill-to-highlight color change method and notifies the self delegate.
 *
 * This callback is invoked by `SCTCircleButton` for a touchesBegan: event to set highlight color
 * in the "tracker" circle button, informing the display of number of user button selections, or
 * "entries".
 *
 * The calling  `SCTCircleButton` title text is stored in the `arrEntries` 
 * array, which is used both for tracking number of entries and for passing to the self 
 * `SCTLockPadDelegate` when the `arrEntries` array is full.
 *
 * `updateButtonTitle` is invoked to set the `btnLogoutDelete` title appropriately for the number of
 * currently stored title entries.
 *
 * @param cb An `SCTCircleButton` instance
 */
- (void)shapeButtonDidStartTouch:(SCTShapeButton *)cb {
    
    [_arrEntries addObject: cb.lblTitle.text];
    
    // Highlight the tracking circleButton
    [_circleButtonsView highlightShapeAtIndex: _arrEntries.count - 1 animated: NO];
    
    // Update the Cancel/Delete button title
    [self updateButtonTitle];
    
    if ([_delegate respondsToSelector: @selector(shapeButtonDidStartTouch:)]) {
        [_delegate shapeButtonDidStartTouch: cb];
    }
}

/**
 * Invokes the highlight-back-to-fill color change method and notifies the self delegate.
 *
 * The `arrEntries` array stores user-selected button titles, added in the 
 * `[SCTShapeButtonDelegate shapeButtonDidStartTouch:]` callback. This method checks at each
 * button "touch up" event whether the `arrEntries` array count is "full", defined by the
 * SCT_PIN_ENTRIES_COUNT constant. When the `arrEntries` is full, this method notifies its
 * delegate with the array.
 *
 * @param cb An `SCTCircleButton` instance
 * @see `SCTLockScreenConstants`
 */
- (void)shapeButtonDidEndTouch:(SCTShapeButton *)cb {
    if ([_delegate respondsToSelector: @selector(shapeButtonDidEndTouch:)]) {
        [_delegate shapeButtonDidEndTouch: cb];
    }
    
    // Message delegate with arrEntries selections when complete
    if (_arrEntries.count == SCT_PIN_ENTRIES_COUNT && [_delegate respondsToSelector: @selector(lockPadSelectedButtonTitles:)]) {
        [_delegate lockPadSelectedButtonTitles: _arrEntries];
    }
}


#pragma mark - Logout/Delete Button

/**
 * Fires the `[SCTLockPadViewDelegate lockPadSelectedLogout]` delegate callback, notifying of a
 * user "Log out" selection if there are no stored user PIN entries in `arrEntries`, or, removes
 * the previous button title user selection from `arrEntries` and invokes `updateButtonTitle` to
 * update button title.
 *
 * Note: this method could be updated for use by the delegate so as to let the delegate determine
 * the functionality of the button. To implement, the delegate callbacks would be defined in the
 * SCTLockPadViewDelegate protocol. When this method is fired, the button would be passed to the
 * delegate, which could manage with the use of tags. The updateButtonTitle method would need to 
 * be refactored to allow for delegate configuration for state changes. In both methods, the current
 * implementation would be executed unless the delegate implements these new callbacks.
 */
- (IBAction)handleLogoutDeleteButton:(UIButton *)sender {
    BOOL logout = (0 == _arrEntries.count);
    if (logout) {
        if ([_delegate respondsToSelector: @selector(lockPadSelectedLogout)]) {
            [_delegate lockPadSelectedLogout];
        }
        return;
    }

    // Clear last entry and update tracker circle and logoutDeleteButton title
    [_circleButtonsView clearShapeHighlightAtIndex: (_arrEntries.count - 1) animated: YES];
    [self.arrEntries removeLastObject];    
    [self updateButtonTitle];
}

/**
 * Sets the dual-purpose `btnLogoutDelete` title appropriately for the current state.
 *
 * When the `arrEntries` array is empty, the button title is set to the SCT_LOGOUT_TITLE string
 * constant, and to the SCT_DELETE_TITLE otherwise.
 *
 * Note: this method and `handleLogoutDeleteButton:` could be refactored to optionally enable the
 * delegate to control the button appearance/state and functionality, as described in the 
 * `handleLogoutDeleteButton:` documentation.
 *
 * @see handleLogoutDeleteButton: for more on refactoring
 */
- (void)updateButtonTitle {
    NSString *title = (self.arrEntries.count == 0) ? SCT_LOGOUT_TITLE : SCT_DELETE_TITLE;
    [self.btnLogoutDelete setTitle: title forState: UIControlStateNormal];
}


#pragma mark - Animations

/**
 * Resets self to a PIN sequence start state and updates the display.
 *
 * When the `arrEntries` collection of user button title entries is passed to `MTLockScreenVC`, it
 * notifies its SCTLockScreenDelegate with the entries and is returned a BOOL pass/fail. If the
 * PIN/entries fails authentication, `MTLockScreenVC` calls this method to restart the PIN sequence.
 *
 * This method reinitializes the arrEntries array, updates the `logoutDeleteButton` and invokes
 * `[trackerButtonsView shakeAndClearShapeButtonsWithCompletion:]` to do the Apple 
 * "wrong-password shake". The userInteractionEnabled flag is cleared at the start of the method to
 * prevent addtional button press events while the shake animation runs, and then reenables
 * user interaction in the completion callback;
 */
- (void)animateInvalidEntryResponse {
    _arrEntries = [NSMutableArray arrayWithCapacity: SCT_PIN_ENTRIES_COUNT];
    [self updateButtonTitle];

    self.userInteractionEnabled = NO;    
    __weak typeof(self) weakSelf = self;
    [_circleButtonsView shakeAndClearShapeButtonsWithCompletion:^{
        weakSelf.userInteractionEnabled = YES;
    }];
}


#pragma mark - Utilities

/** 
 * Return circleButton title label text
 */
- (NSString *)strEntryWithButton:(SCTShapeButton *)cb {
    NSString *title = cb.lblTitle.text;
    return title;
}


@end
