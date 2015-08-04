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
//  SCTShapeButtonsView.h
//  ST2
//
//  Created by Eric Turner on 7/1/14.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * This class manages an array of SCTShapeButtons, accessed from its subviews, and provides an interface for 
 * configuring their properties, and manipulating their highlighted states, as a group. 
 *
 * The "Apple wrong-password-shake" animation is implemented in this class, which performs the shake animation on a 
 * given view. This class was originally implemented as a complement to a PIN lock screen view controller, encapsulating
 * the "tracking" shapes for UI feedback of user pin code entries, highlighting one for each entry.
 *
 * In the PIN lock screen implementation, an instance of the SCTPinLockKeypad implements an instance of this class for
 * managing the display of the tracking shapes. When the user's PIN entries sequence is complete, if the PIN is not
 * valid, the shake method is invoked with the shapeButtons view.
 
 It also provides convenience methods for 
 *
 *
 */
@interface SCTShapeButtonsView : UIView

@property (strong, nonatomic) NSArray *shapeButtons;


#pragma mark - Color Configuration
- (void)configureAllShapesWithColor:(UIColor *)aColor;

- (void)configureAllShapesWithOptions:(NSDictionary *)optionsDict;

// Provides an interface for configuring shapeButtons in the given array with the given options
+ (void)configureShapeButtons:(NSArray *)arr withOptions:(NSDictionary *)optionsDict;
- (void)configureShapeButtons:(NSArray *)arr withOptions:(NSDictionary *)optionsDict;

// A convenience accessor for a configuration dictionary of default button color options
+ (NSDictionary *)shapeOptionsWithColor:(UIColor *)aColor;
- (NSDictionary *)shapeOptionsWithColor:(UIColor *)aColor;

#pragma mark - Highlight Methods
- (void)highlightShapeAtIndex:(NSInteger)idx animated:(BOOL)animated;

- (void)clearShapeHighlightAtIndex:(NSInteger)idx animated:(BOOL)animated;

- (void)highlightShapesWithAnimation:(BOOL)animated;

- (void)clearShapeHighlightsWithAnimation:(BOOL)animated;

- (void)shakeAndClearShapeButtonsWithCompletion:(void (^)(void))completion;

#pragma mark - Utilities
+ (NSArray *)shapeButtonsInView:(UIView *)aView;
- (NSArray *)shapeButtonsInView:(UIView *)aView;

@end
