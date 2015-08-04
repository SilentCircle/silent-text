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
/*
 
 Erica Sadun, http://ericasadun.com
 
 */

//#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "BezierFunctions.h"

#define COLOR_LEVEL(_selector_, _alpha_) [([UIColor _selector_])colorWithAlphaComponent:_alpha_]
#define WHITE_LEVEL(_amt_, _alpha_) [UIColor colorWithWhite:(_amt_) alpha:(_alpha_)]

// Gradient drawing styles
#define LIMIT_GRADIENT_EXTENT 0
#define BEFORE_START kCGGradientDrawsBeforeStartLocation
#define AFTER_END kCGGradientDrawsAfterEndLocation
#define KEEP_DRAWING kCGGradientDrawsAfterEndLocation | kCGGradientDrawsBeforeStartLocation

typedef __attribute__((NSObject)) CGGradientRef GradientObject;

@interface Gradient : NSObject
@property (nonatomic, readonly) CGGradientRef gradient;
+ (instancetype) gradientWithColors: (NSArray *) colors locations: (NSArray *) locations;
+ (instancetype) gradientFrom: (UIColor *) color1 to: (UIColor *) color2;

+ (instancetype) rainbow;
+ (instancetype) linearGloss:(UIColor *) color;
+ (instancetype) gradientUsingInterpolationBlock: (InterpolationBlock) block between: (UIColor *) c1 and: (UIColor *) c2;
+ (instancetype) easeInGradientBetween: (UIColor *) c1 and:(UIColor *) c2;
+ (instancetype) easeInOutGradientBetween: (UIColor *) c1 and:(UIColor *) c2;
+ (instancetype) easeOutGradientBetween: (UIColor *) c1 and:(UIColor *) c2;

- (void) drawFrom:(CGPoint) p1 toPoint: (CGPoint) p2 style: (int) mask;
- (void) drawRadialFrom:(CGPoint) p1 toPoint: (CGPoint) p2 radii: (CGPoint) radii style: (int) mask;

- (void) drawTopToBottom: (CGRect) rect;
- (void) drawBottomToTop: (CGRect) rect;
- (void) drawLeftToRight: (CGRect) rect;
- (void) drawFrom:(CGPoint) p1 toPoint: (CGPoint) p2;
- (void) drawAlongAngle: (CGFloat) angle in:(CGRect) rect;

- (void) drawBasicRadial: (CGRect) rect;
- (void) drawRadialFrom: (CGPoint) p1 toPoint: (CGPoint) p2;
@end;
