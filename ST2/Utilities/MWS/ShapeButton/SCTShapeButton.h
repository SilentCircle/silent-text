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
//  SCTShapeButton.h
//  ST2
//
//  Created by Eric Turner on 7/1/14.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@class SCTShapeButton;

@protocol SCTShapeButtonDelegate <NSObject>
@optional
- (void)shapeButtonDidStartTouch:(SCTShapeButton *)cb;
- (void)shapeButtonDidEndTouch:(SCTShapeButton *)cb;
@end


@interface SCTShapeButton : UIView

/** Circle radius; defaults to 1/2 view frame width cast to int */
@property (nonatomic) CGFloat cornerRadius;

/** Delegate for SCTShapeButtonDelegate callbacks */
@property (weak, nonatomic) IBOutlet id<SCTShapeButtonDelegate> delegate;

/** Color of the circle fill; defaults to clearColor */
@property (strong, nonatomic) UIColor *fillColor;

/** For a tap down event, the highlight color fills the circle; defaults to strokeWidth color */
@property (strong, nonatomic) UIColor *highlightColor;

/** A flag property to set shape as circle */
@property (nonatomic) BOOL isCircleShape;

/** Large, main title label; textColor defaults to strokeColor, set in initializer.
 * IB configuration: textColor: black, font: Helvetica Neue 53.0, aligned center. */ 
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;

/** Small subtitle label; textColor defaults to strokeColor, set in initializer.
 * IB configuration: textColor: black, font: Helvetica Neue 53.0, aligned center. */ 
@property (weak, nonatomic) IBOutlet UILabel *lblSubTitle;

/** A path with which to draw a shape. The default is a rectangle with zero cornerRadius and stroke attriubutes, the
 * color of the self background color.
 * Note: at initialization, e.g. in IB, this class sets a rectangle path with the attributes of the self layer as the
 * shapePath property, which may be reconfigured as another shape. */
@property (strong, nonatomic) UIBezierPath *shapePath;

/** Color of the circle stroke; defaults to the superview tint color */
@property (strong, nonatomic) UIColor *strokeColor;

/** Width of the circle stroke; defaults to 2 pts */
@property (nonatomic) CGFloat strokeWidth;

/** Enables the higlight color animation, filling the circle layer */
@property (nonatomic) BOOL useHighlightAnimation;


#pragma Button Behaviors
// Animates the circle fill color from fill color (default clearColor) to highlight color.
- (void)applyHighlightWithAnimation:(BOOL)animated;

// Animates the circle fill color from highlight color to fill color (default clearColor)
- (void)dismissHighlightWithAnimation:(BOOL)animated;


#pragma Redraw Methods
// Takes a dictionary of values for property keys to redraw
// @see SCTCircleButtonConstants
- (void)redrawWithOptions:(NSDictionary *)optionsDict;

@end
