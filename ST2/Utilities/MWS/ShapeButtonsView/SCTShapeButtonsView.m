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
//  SCTShapeButtonsView.m
//  ST2
//
//  Created by Eric Turner on 7/1/14.
//

#import "SCTShapeButtonsView.h"
#import "SCTShapeButton.h"
#import "SCTShapeButtonConstants.h"

@implementation SCTShapeButtonsView


#pragma mark - Initialization

/**
 * Initializes the shapeButtons array property.
 *
 * @param aDecoder An unarchiver object.
 * @return self, initialized using the data in decoder.
 */
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    _shapeButtons = [self shapeButtonsInView:self];
    return self;
}
    
#pragma mark - Color Configuration

/**
 * Updates all buttons in button subviews with the given color.
 *
 * When used in a PIN lock screen view this method is invoked by `SCTLockScreenVC` viewDidLoad: method to reconfigure
 * buttons defined in Interface Builder with the given color. It invokes the `configureAllShapesWithOptions:` method
 * passing a configurations dictionary returned by `shapeOptionsWithColor:`.
 *
 * @param aColor The color with which to configure all buttons in self subviews
 * @see `SCTLockScreenConstants` for key constants
 */
- (void)configureAllShapesWithColor:(UIColor *)aColor 
{
    NSDictionary *colorsDict = [self shapeOptionsWithColor: aColor];
    NSLog(@"%s colorsDict:%@",__PRETTY_FUNCTION__, colorsDict);
    [self configureAllShapesWithOptions: colorsDict];
}

/**
 * A convenience method to configure all shape buttons in the `shapeButtons` array with the given options.
 *
 * @param optionsDict A dictionary of SCTShapeButton key/value configurations
 * @see `configureAllShapesWithColor:`
 * @see `SCTShapeButtonConstants` for key constants
 */
- (void)configureAllShapesWithOptions:(NSDictionary *)optionsDict 
{
    [self configureShapeButtons:_shapeButtons withOptions:optionsDict];
}

/**
 * This class method configures `SCTShapeButton`s in the given array with the given options dictionary.
 *
 * @param arr An array of `SCTShapeButton`s instances to configure
 * @param optionsDict A dictionary of SCTShapeButton key/value configurations
 * @see `SCTShapeButtonConstants` for key constants
 */
+ (void)configureShapeButtons:(NSArray *)arr withOptions:(NSDictionary *)optionsDict 
{
    [arr enumerateObjectsUsingBlock: ^(SCTShapeButton *btn, NSUInteger idx, BOOL *stop) {
        [btn redrawWithOptions: optionsDict];
    }];
}

/**
 * This instance method invokes the class method to configure `SCTShapeButton`s in the given array with the given 
 * options dictionary.
 *
 * @param arr An array of `SCTShapeButton`s instances to configure
 * @param optionsDict A dictionary of SCTShapeButton key/value configurations
 * @see `SCTShapeButtonConstants` for key constants
 */
- (void)configureShapeButtons:(NSArray *)arr withOptions:(NSDictionary *)optionsDict 
{
    [[self class] configureShapeButtons:arr withOptions:optionsDict];
}

/**
 * A class method which returns a dicitonary of SCTShapeButton configuration options.
 *
 * This method configures a dictionary with the given color value for `SCTShapeButton` property keys. The stroke,
 * highlight, title text, and subTitle text color properties of buttons are configured with the given color. The button
 * fill color propety is set to an NSNull which results in the default (clearColor) fill color. The resulting default
 * configuration is a shape outline in the given color. When highlighted, the shape is the solid given color.
 *
 * @param aColor A UIColor instance, or nil for defaults
 * @return A dictionary of default `SCTShapeButton` option key/values
 * @see `SCTShapeButtonConstants` for key constants
 */
+ (NSDictionary *)shapeOptionsWithColor:(UIColor *)aColor 
{
    NSDictionary *colorsDict = @{SCT_ShapeButton_strokeColor:           (aColor) ?: [NSNull null],
                                 SCT_ShapeButton_highlightColor:        (aColor) ?: [NSNull null],
                                 SCT_ShapeButton_fillColor:             [NSNull null],
                                 SCT_ShapeButton_titleColor:            (aColor) ?: [NSNull null],
                                 SCT_ShapeButton_subTitleColor:         (aColor) ?: [NSNull null],
                                 SCT_ShapeButton_strokeWidth:           @(SCT_DEFAULT_SHAPEBUTTON_STROKE_WIDTH),
                                 SCT_ShapeButton_useHighlightAnimation: @(YES)
                                 };
    return colorsDict;
}

/**
 * An instance method invoking the class method which returns a dicitonary of SCTShapeButton configuration options.
 *
 * The class method configures a dictionary with the given color value for `SCTShapeButton` property keys. The stroke,
 * highlight, title text, and subTitle text color properties of buttons are configured with the given color. The button
 * fill color propety is set to an NSNull which results in the default (clearColor) fill color. The resulting default
 * configuration is a shape outline in the given color. When highlighted, the shape is the solid given color.
 *
 * @param aColor A UIColor instance, or nil for defaults
 * @return A dictionary of default `SCTShapeButton` option key/values
 * @see `SCTShapeButtonConstants` for key constants
 */
- (NSDictionary *)shapeOptionsWithColor:(UIColor *)aColor
{
    return [[self class] shapeOptionsWithColor:aColor];
}


#pragma mark - Highlight Methods

/**
 * Highlights the shape button at the given index in the `shapeButtons` array, optionally with animation.
 *
 * @param idx The index into the `shapeButtons` array of an `SCTShapeButton` instance
 * @param animated `YES` to animate highlighting, `NO` otherwise
 */
- (void)highlightShapeAtIndex:(NSInteger)idx animated:(BOOL)animated 
{
    // Out-of-bounds check
    if (idx >= _shapeButtons.count) { return; }
    
    [_shapeButtons[idx] applyHighlightWithAnimation: animated];
}

/**
 * Dismisses the highlight of the shape button at the given index in the `shapeButtons` array, optionally with 
 * animation.
 *
 * @param idx The index into the `shapeButtons` array of an SCTShapeButton instance
 * @param animated `YES` to animate dismissing highlighting, `NO` otherwise
 */
- (void)clearShapeHighlightAtIndex:(NSInteger)idx animated:(BOOL)animated 
{
    if (idx >= _shapeButtons.count) return;
    
    [_shapeButtons[idx] dismissHighlightWithAnimation: animated];    
}

/**
 * Highlights shape buttons in the `shapeButtons` array, optionally with animation.
 *
 * @param animated `YES` to animate highlighting, `NO` otherwise
 */
- (void)highlightShapesWithAnimation:(BOOL)animated 
{
    [_shapeButtons enumerateObjectsUsingBlock: ^(SCTShapeButton *shape, NSUInteger idx, BOOL *stop) {
        [shape applyHighlightWithAnimation: animated];
    }];    
}

/**
 * Dismisses highlights of shape buttons in the `shapeButtons` array, optionally with animation.
 *
 * @param animated `YES` to animate dismissing highlights, `NO` otherwise
 */
- (void)clearShapeHighlightsWithAnimation:(BOOL)animated 
{
    [_shapeButtons enumerateObjectsUsingBlock: ^(SCTShapeButton *shape, NSUInteger idx, BOOL *stop) {
        [shape dismissHighlightWithAnimation: animated];
    }];    
}


#pragma mark - Shake Methods
// Consider putting Shake methods in a higher level class category; maybe UIView

/**
 * Performs the Apple "wrong-password shake" animation and clears the shapeButtons highlights.
 *
 * @param completion An optional block, run in the ending "shake" animation. May be nil.
 */
- (void)shakeAndClearShapeButtonsWithCompletion:(void (^)(void))completion 
{
    [self shakeWithCompletion: completion]; // pass 0.0 for default delta
}

/**
 * Performs the first part of the Apple "wrong-password shake" animation, then invokes `endShakeWithCenter:` to 
 * complete.
 *
 * @param completion An optional block passed to `endShakeWithCenter:` in this method's animation
 * completiont block. May be nil.
 */
- (void)shakeWithCompletion:(void (^)(void))completion 
{
    // default delta to 44, i.e. the distance to move the center.x value negatively
    CGFloat dx = 44;
    
    CGPoint origCenter = CGPointMake(self.center.x, self.center.y);
    CGPoint offsetCenter = CGPointMake(self.center.x - dx, self.center.y);
    [UIView animateWithDuration:0.05
                          delay:0.15
         usingSpringWithDamping:1
          initialSpringVelocity:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations: ^{
                         self.center = offsetCenter;
                     } 
                     completion:^(BOOL finished) {
                         [self endShakeWithCenter: origCenter completion: completion];
                     }];
}

/**
 * Performs the final part of the "Apple wrong-password shake" animation, including clearing shapeButtons highlights.
 *
 * @param completion An optional block passed to `shakeWithCompletion:`, run in the animation
 * completiont block. May be nil.
 */
- (void)endShakeWithCenter:(CGPoint)aPoint completion:(void (^)(void))completion 
{
    __weak typeof (self) weakSelf = self;
    [UIView animateWithDuration:0.4
                          delay:0
         usingSpringWithDamping:0.11
          initialSpringVelocity:4
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.center = aPoint;
                         [weakSelf clearShapeHighlightsWithAnimation: YES];
                     } 
                     completion:^(BOOL finished) {
                         if (completion) {
                             completion();
                         }
                     }];    
}


#pragma mark - Utilities

/**
 * A class method which returns an array of `SCTShapeButton` instances collected in the subviews of the given view.
 *
 * An instance of this class invokes this method in the awakeFromNib method to initialize the `shapeButtons` array.
 * Note that the `shapeButtons` property implements a self-initializing accessor.
 *
 * @param aView The view from which to collect `SCTShapeButton` instances
 * @return An array of `SCTShapeButton` instances collected from the given aView
 */
+ (NSArray *)shapeButtonsInView:(UIView *)aView 
{
    __block NSMutableArray *tmpArr = [NSMutableArray array];
    [aView.subviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) 
    {
        if ([view isKindOfClass: [SCTShapeButton class]]) 
        {
            [tmpArr addObject: view];
        }
    }];
    return [NSArray arrayWithArray: tmpArr];    
}

/**
 * Returns an array of `SCTShapeButton` instances via the return value of the class method.
 *
 * @param aView The view from which to collect `SCTShapeButton` instances
 * @return An array returned by the shapeButtonsInView: class method
 * @see shapeButtonsInView:
 */
- (NSArray *)shapeButtonsInView:(UIView *)aView 
{
    return [[self class] shapeButtonsInView:aView];
}


#pragma mark - Accessors

/**
 * A self-initializing accessor to an array of SCTShapeButton subviews derived from the self view.
 */
- (NSArray *)shapeButtons 
{
    if (nil == _shapeButtons) 
    {
        _shapeButtons = [self shapeButtonsInView: self];
    }
    return _shapeButtons;
}

@end
