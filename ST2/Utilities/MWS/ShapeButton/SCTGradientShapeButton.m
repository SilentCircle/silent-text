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
//  SCTGradientShapeButton.m
//  ST2
//
//  Created by Eric Turner on 7/6/14.
//
//  Inspired by Nick Jensen GradientProgressView
//  https://nrj.io/animated-progress-view-with-cagradientlayer
//
//

#import "SCTGradientShapeButton.h"
#import <QuartzCore/QuartzCore.h>


@interface SCTGradientShapeButton ()

/** The mask layer hides the gradient to the extent resized by the setProgress mutator. */
@property (nonatomic, strong) CALayer *maskLayer;

@end


@implementation SCTGradientShapeButton

/**
 * Initializes the gradient start and end points, and colors, with defaults.
 *
 * @param aDecoder An unarchiver object.
 * @return self, initialized using the data in decoder.
 */
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    // Use a horizontal gradient
    [self setGradientStartPoint:CGPointMake(0.0, 0.5) endPoint:CGPointMake(1.0, 0.5)];

    // Default colors to HSB rainbow spectrum (360 degrees)
    [self setColorsFrom:0.0 toEnd:359.0];

    return self;
}

/**
 * Define the start and end points in the self view between which the gradient is drawn.
 *
 * The default is leftmost to rightmost x coordinates, at midpoint y.
 * 
 * @param ptStart The point at which gradient drawing begins in the self view.
 * @param ptEnd   The point at which gradient drawing ends in the self view.
 */
- (void)setGradientStartPoint:(CGPoint)ptStart endPoint:(CGPoint)ptEnd
{
    CAGradientLayer *layer = (CAGradientLayer *)[self layer];
    [layer setStartPoint:ptStart];
    [layer setEndPoint:ptEnd];
}

/**
 * This method defines the color "spectrum" with start and end positions on the HSB color wheel.
 *
 * @param colorStart A float value describing the start color as a position on the HSB wheel. For example, a value of
 *        0.0 defines the gradient beginning color as red.
 * @param colorEnd   A float value describing the end color as a position on the HSB wheel. For example, a value of
 *        120.0 defines the gradient from the start color ending in green.
 */
- (void)setColorsFrom:(CGFloat)colorStart toEnd:(CGFloat)colorEnd
{
    CAGradientLayer *layer = (CAGradientLayer *)[self layer];
    
    NSMutableArray *colors = [NSMutableArray array];
    CGFloat start = colorStart / 360.0;
    CGFloat end   = colorEnd   / 360.0;
    CGFloat granularity = 100; // iterations
    for (CGFloat hue = start; hue <= end; hue += (end / granularity)) {
        
        UIColor *color;
        color = [UIColor colorWithHue:hue
                           saturation:2.0
                           brightness:1.0
                                alpha:1.0];
        CGColorRef colorRef = color.CGColor;
        [colors addObject:(__bridge id)colorRef];
    }
    
    [layer setColors:[NSArray arrayWithArray:colors]];
}


#pragma mark - Getters

/**
 * Overrides the default property mutator to match the mask layer background color to the self backgroundColor when
 * initialized.
 *
 * bgColor The color to change the self backgroundColor.
 */
- (void)setBackgroundColor:(UIColor *)bgColor
{
    [super setBackgroundColor:bgColor];
    [self.maskLayer setBackgroundColor:[[bgColor copy] CGColor]];
}

/** 
 * A setter which updates the progress values and invokes setNeedsDisplay for a redraw of the maskLayer
 *
 * @param value The value with which to resize the width of the `maskLayer`.
 */
- (void)setProgress:(double)value 
{
    if (_progress != value) 
    {        
        // progress values go from 0.0 to 1.0
        _progress = MIN(1.0, fabs(value));
        [self setNeedsLayout];
    }
}

/** 
 * Resize mask layer based on the current progress
 */
- (void)layoutSubviews 
{  
    [super layoutSubviews];
    CGRect maskRect = [_maskLayer frame];
    maskRect.size.width = CGRectGetWidth([self bounds]) * _progress;
    [_maskLayer setFrame:maskRect];
}


#pragma mark - Accessors

/** 
 * A CAlayer to use as a mask. The width of this layer will be resized to reflect the current progress value.
 */
- (CALayer *)maskLayer 
{
    if (nil == _maskLayer)
    {
        _maskLayer = [CALayer layer];
        _maskLayer.frame = CGRectMake(0, 0, 0, self.frame.size.height);
        _maskLayer.backgroundColor = self.backgroundColor.CGColor;
        [(CAGradientLayer*)self.layer setMask:_maskLayer];
    }
    return _maskLayer;
}

/**
 * @return A CAGradientLayer subclass of the default self CALayer for drawing the gradient.
 */
+ (Class)layerClass 
{    
    // Tells UIView to use CAGradientLayer as our backing layer
    return [CAGradientLayer class];
}

@end
