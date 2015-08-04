//
//  UIColor+MWSAdditions.h
//
//  Created by Eric Turner on 06/16/14.
//  Copyright (c) 2013 MagicWave Software, LLC. All rights reserved.
//

#import "UIColor+FlatColors.h"

@interface UIColor (MWSAdditions)

+ (UIColor *)textColor;
+ (UIColor *)blueTintColor;
+ (UIColor *)darkBackgroundColor;
+ (UIColor *)mildDarkBackgroundColor;
+ (UIColor *)darkBackgroundColorWithAlpha:(CGFloat)alphaVal;

#pragma mark - Erica Sadun
+ (UIColor *)skyColor;
+ (UIColor *)darkSkyColor;

@end
