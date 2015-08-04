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
//  SCTShapeButton.m
//  ST2
//
//  Created by Eric Turner on 7/1/14.
//

#import "SCTShapeButton.h"
#import "SCTShapeButtonConstants.h"


@interface SCTShapeButton ()
@property (nonatomic, strong) CAShapeLayer *shapeLayer;
@end


@implementation SCTShapeButton



#pragma mark - ShapeLayer Methods

/**
 * Resets the self layer with defaults. Removes `circle` sublayer if not nil.
 * Invoked by the setIsCircleShape mutator to reset to default UIView rectangle attributes.
 * Not animated.
 */
- (void)setShapeWithShapePath
{
    // shapePath may be nil if called by an enclosing view when it awakes from nib
    if (!_shapePath) 
    { 
        self.shapePath = [self rectanglePath];
    }
    
    [self prepareSelfLayer];
    [self removeCurrentShapeLayer];
    self.shapeLayer = [self shapeLayerFromShapePath:_shapePath];
    // Add to parent layer
    [self.layer addSublayer: _shapeLayer];
}

// Initialize shapeLayer from shapePath property
- (CAShapeLayer *)shapeLayerFromShapePath:(UIBezierPath *)aPath
{
    if (! aPath) { return nil; }
    
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    shapeLayer.path = aPath.CGPath;
    shapeLayer.fillColor   = [self fillColor].CGColor;
    shapeLayer.strokeColor = [self strokeColor].CGColor;
    shapeLayer.lineWidth   = [self strokeWidth];
    
    return shapeLayer;
}

- (void)removeCurrentShapeLayer
{
    if (_shapeLayer)
    {
        [_shapeLayer removeFromSuperlayer];
        self.shapeLayer = nil;
    }    
}

// Set the default layer clear to display the default rectangle path
- (void)prepareSelfLayer 
{  
    self.backgroundColor    = [UIColor clearColor];
}

#pragma mark - Rectangle Shape Methods

- (void)setRectangleShape
{
    self.shapePath = [self rectanglePath];
    [self setShapeWithShapePath];
}

#pragma mark - Circle Shape Methods
// Need to do anything if setIsCircleShape is NO?
- (void)setIsCircleShape:(BOOL)yesno 
{
    _isCircleShape = yesno;
    if (_isCircleShape)
    {
        [self setCircleShape];
    }
}

- (void)setCircleShape
{
    self.shapePath = [self circlePath];
    [self setShapeWithShapePath];
}


#pragma mark - Configuration Options

/**
 * Initializes configuration properties with values in given dictionary and reinitializes circle.
 *
 * Note: An NSNull value reverts a property to its default.
 *
 * @param optionsDict Dictionary with configuration key/value pairs
 */
- (void)redrawWithOptions:(NSDictionary *)optionsDict 
{
    if (nil == optionsDict) return;
    
    __block BOOL shapeNeedsChange = NO;
    [optionsDict.allKeys enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) 
    {
        // Only look at string keys - these should be property name strings (see SCTShapeButtonConstants)
        if ([obj isKindOfClass: [NSString class]]) 
        {
            NSString *key = (NSString *)obj;
            id value = [optionsDict objectForKey: key];
            BOOL isNil = ([value isKindOfClass: [NSNull class]]);
            value = (isNil) ? nil : value;

            //------------------------------------------------------------//
            // Color Properties
            //------------------------------------------------------------//
            if ([key isEqualToString:SCT_ShapeButton_fillColor]) 
            {
                self.fillColor = value;
            }
            else if ([key isEqualToString:SCT_ShapeButton_highlightColor]) 
            {
                self.lblSubTitle.textColor = value;
            }
            else if ([key isEqualToString:SCT_ShapeButton_strokeColor]) 
            {
                 self.strokeColor = value;
            }            
            else if ([key isEqualToString: SCT_ShapeButton_subTitleColor]) 
            {
                self.lblSubTitle.textColor = value;
            }
            else if ([key isEqualToString:SCT_ShapeButton_titleColor]) 
            {
                self.lblTitle.textColor = value;
            }
            
            //------------------------------------------------------------//
            // Float properties
            //------------------------------------------------------------//
            else if ([key isEqualToString:SCT_ShapeButton_cornerRadius]) 
            {
                self.cornerRadius = [(NSNumber *)value floatValue];
            }
            
            else if ([key isEqualToString:SCT_ShapeButton_strokeWidth])
            {
                self.strokeWidth = [(NSNumber *)value floatValue];
            }
            
            //------------------------------------------------------------//
            // Label titles (value could be string or NSNull
            //------------------------------------------------------------//
            else if ([key isEqualToString: SCT_ShapeButton_titleText]) 
            {
                self.lblTitle.text = value;
            }
            else if ([key isEqualToString: SCT_ShapeButton_subTitleText]) 
            {
                self.lblSubTitle.text = value;
            }
            
            //------------------------------------------------------------//
            // Other
            //------------------------------------------------------------//            
            // Convenience circle shape setter
            else if ([key isEqualToString: SCT_ShapeButton_isCircleShape]) 
            {
                BOOL yesno = [value boolValue];
                shapeNeedsChange = (yesno != self.isCircleShape);
                // Set ivar directly without calling setter
                _isCircleShape = yesno;
                self.shapePath = [self circlePath];
            }
            // ShapePath
            else if ([key isEqualToString:SCT_ShapeButton_shapePath])
            {
                self.shapePath = (UIBezierPath *)value;
            }
            // Use highlight animation
            else if ([key isEqualToString: SCT_ShapeButton_useHighlightAnimation]) 
            {
                self.useHighlightAnimation = [(NSNumber *)value boolValue];
            }
            
            // take a chance on whatever's left?
//            else 
//            {
//                [self setValue: value forKey: key];
//            }
        }
    }];
    
    // Property values have been set with the foregoing.
    // If changing non-circle shape, assume the shapePath has been initialized with a path
    [self setShapeWithShapePath];
}


#pragma mark - Shape Property Accessors

- (UIBezierPath *)circlePath {
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect: [self shapeRect] 
                                                    cornerRadius: [self circleRadius]];
    return path;
}

- (CGFloat)circleRadius {
    return floorf([self shapeRect].size.width / 2);
}

- (UIBezierPath *)rectanglePath {
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect: [self shapeRect] 
                                                    cornerRadius: [self cornerRadius]];
    return path;
}


#pragma mark - Drawing Properties
// Constants defined in SCTShapeButtonConstants.h/.m

// Circle radius; defaults to 1/2 view frame width cast to int
- (CGFloat)cornerRadius 
{
    return (_cornerRadius) ?: self.layer.cornerRadius;
}

// Width of the circle stroke; defaults to 2 pts
- (CGFloat)strokeWidth 
{
    return (_strokeWidth) ?: self.layer.borderWidth;
}

// Rect to draw shape into
- (CGRect)shapeRect 
{
    return self.bounds;
}


#pragma mark - Color Property Accessors
// Color of the circle inside; defaults to clear
- (UIColor *)fillColor 
{
    return (_fillColor) ?: self.backgroundColor;
}

// Large, main title label; textColor defaults to strokeColor, set in initializer.
// IB configuration: textColor: black, font: Helvetica Neue 53.0, aligned center.
- (UIColor *)highlightColor 
{
    return (_highlightColor) ?: self.strokeColor; //SCT_DEFAULT_HIGHLIGHT_COLOR;
}

// Small subtitle label; textColor defaults to strokeColor, set in initializer.
// IB configuration: textColor: black, font: Helvetica Neue 53.0, aligned center.
- (UIColor *)strokeColor 
{
    return (_strokeColor) ?: [UIColor colorWithCGColor:self.layer.borderColor];
}


#pragma mark - Touch Events

/**
 * Invokes `applyHighlightWithAnimation:` animate circle from fill color to highlight color
 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{
    if (_useHighlightAnimation) {
        [self applyHighlightWithAnimation: NO];
    }
    if ([self.delegate respondsToSelector: @selector(shapeButtonDidStartTouch:)]) {
        [self.delegate shapeButtonDidStartTouch: self];
    }
}

/**
 * Invokes `dismissHighlightWithAnimation:` animate circle from highlight color to fill color
 */
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event 
{
    if (_useHighlightAnimation) {
        [self dismissHighlightWithAnimation: NO];
    }    
    [super touchesCancelled:touches withEvent:event];
}

/**
 * Invokes `dismissHighlightWithAnimation:` animate circle from highlight color to fill color
 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
    if (_useHighlightAnimation) {
        [self dismissHighlightWithAnimation: YES];
    }
    if ([self.delegate respondsToSelector: @selector(shapeButtonDidEndTouch:)]) {
        [self.delegate shapeButtonDidEndTouch: self];
    }    
}


#pragma mark - Highlighting

/**
 * Changes circle fill color to highlight color.
 *
 * Invoked by touchesBegan:withEvent: to change circle colors, optionally with animation
 *
 * @param animated `YES` to animate, otherwise, animation is of zero duration
 */
- (void)applyHighlightWithAnimation:(BOOL)animated 
{
    [UIView animateWithDuration: (animated) ? SCT_SHAPE_BUTTON_ANIMATION_DURATION : 0
                          delay: 0 
                        options: UIViewAnimationOptionBeginFromCurrentState 
                     animations:^{
                         self.shapeLayer.fillColor = [self highlightColor].CGColor;
                     } completion:^(BOOL finished) {
                         
                     }];
}

/**
 * Changes circle hightlight color to fill color.
 *
 * Invoked by touchesEnded:withEvent: to change circle colors, optionally with animation
 *
 * @param animated `YES` to animate, otherwise, animation is of zero duration
 */
- (void)dismissHighlightWithAnimation:(BOOL)animated 
{
    [UIView animateWithDuration: (animated) ? SCT_SHAPE_BUTTON_ANIMATION_DURATION : 0
                          delay: 0 
                        options: UIViewAnimationOptionBeginFromCurrentState 
                     animations:^{
                         self.shapeLayer.fillColor = [self fillColor].CGColor;
                     } completion:^(BOOL finished) {
                         
                     }];
}


- (NSString *)description {
    NSMutableString *str = [NSMutableString string];
    [str setString:super.description];
    [str appendString:[NSString stringWithFormat:@"\nfillColor: %@", self.fillColor]];
    [str appendString:[NSString stringWithFormat:@"\nhighlightColor: %@", self.highlightColor]];
    [str appendString:[NSString stringWithFormat:@"\nstrokeColor: %@", self.strokeColor]];
    [str appendString:[NSString stringWithFormat:@"\nsubTitleColor: %@", self.lblSubTitle.textColor]];
    [str appendString:[NSString stringWithFormat:@"\ntitleColor: %@", self.lblTitle.textColor]];
    // Non-color properties
    [str appendString:[NSString stringWithFormat:@"\ncornerRadius: %1.2f", self.cornerRadius]];
    [str appendString:[NSString stringWithFormat:@"\nisCircleShape: %@", (_isCircleShape)?@"YES":@"NO"]];
    [str appendString:[NSString stringWithFormat:@"\nshapePath: %@", self.shapePath]];
    [str appendString:[NSString stringWithFormat:@"\nstrokeWidth: %1.2f", self.strokeWidth]];
    [str appendString:[NSString stringWithFormat:@"\nsubTitleText: %@", self.lblSubTitle.text]];
    [str appendString:[NSString stringWithFormat:@"\ntitleText: %@", self.lblTitle.text]];
    [str appendString:[NSString stringWithFormat:@"\nuseHighlightAnimation: %@", (_useHighlightAnimation)?@"YES":@"NO"]];
    return [NSString stringWithString:str];
}

@end
