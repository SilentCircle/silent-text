//
//  BBDigitsMatcher.m
//  ZXCVBN
//
//  Created by wangsw on 10/20/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBDigitsMatcher.h"

#import "BBRegularExpressionMatchHelper.h"

@implementation BBDigitsMatcher

- (NSArray *)match:(NSString *)password {
    return [BBRegularExpressionMatchHelper match:password withRegularExpression:@"\\d{3,}" type:BBPatternTypeDigits];
}

@end
