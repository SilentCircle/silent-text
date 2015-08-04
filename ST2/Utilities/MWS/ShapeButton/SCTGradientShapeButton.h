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
//  SCTGradientShapeButton.h
//  ST2
//
//  Created by Eric Turner on 7/6/14.
//

#import "SCTShapeButton.h"

/**
 * This class, as originally implemented, is a view displaying UI feedback for user-entered password text strength.
 *
 * The color range of the gradient drawn in this view can be defined in terms of HSB color wheel start and end
 * locations. The initWithCoder: method initializes the instance with the full 360 degree "rainbow" color spectrum by
 * default, drawing from the leftmost to rightmost x coordinates, at midpoint y.
 *
 * The progress property modifies the frame of the private maskLayer property revealing more or less of the underlying
 * gradient layer as a percentage of the range from 0 to 1.
 *
 * Note: This class subclasses SCTShapeButton. As such, features one might expect, for example drawing a gradient into
 * or onto an arbitrary UIBezierPath defined by the shapePath property, or the ability to specify the direction of the
 * masking behavior, are not in this first implementation.
 *
 * ## History
 *
 * 07/07/14
 * The first implementation of this class was for the SCTPasswordFieldView password strength view, which progressed or
 * regressed as the user entered password strings into its SCTPasswordField passwordField property.
 *
 * @see SCTShapeButton
 * @see SCTPasswordField
 * @see SCTPasswordFieldView
 */
@interface SCTGradientShapeButton : SCTShapeButton

@property (nonatomic, readwrite, assign) double progress;

- (void)setGradientStartPoint:(CGPoint)ptStart endPoint:(CGPoint)ptEnd;

- (void)setColorsFrom:(CGFloat)colorStart toEnd:(CGFloat)colorEnd;

@end
