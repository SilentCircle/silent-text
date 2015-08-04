//
//  UIColor+MWSAdditions.m
//
//  Created by Eric Turner on 06/16/14.
//  Copyright (c) 2013 MagicWave Software, LLC. All rights reserved.
//

#import "UIColor+MWSAdditions.h"
#import "UIColor+FlatColors.h"
#import "Drawing-Util.h"

@implementation UIColor (MWSAdditions)

+ (UIColor *)textColor {
    return [UIColor darkTextColor];
}

+ (UIColor *)blueTintColor {
    return [UIColor colorWithRed:0.0/255.0 green:122.0/255.0 blue:255.0/255.0 alpha:1.0];
}

+ (UIColor *)darkBackgroundColor {
    return [self darkBackgroundColorWithAlpha: 1.0];
}

+ (UIColor *)mildDarkBackgroundColor {
    return [self darkBackgroundColorWithAlpha: 0.64f];
}

+ (UIColor *)darkBackgroundColorWithAlpha:(CGFloat)alphaVal {
    return [UIColor colorWithRed: 111.0/255.0 green: 113.0/255.0 blue: 121.0/255.0 alpha: alphaVal];
}

#pragma mark - Erica Sadun
+ (UIColor *)skyColor {
    return [UIColor colorWithRed:0.0 green:0.75 blue:1.0 alpha:1];
}

+ (UIColor *)darkSkyColor {
    return ScaleColorBrightness([self skyColor], 0.5);
}

@end
