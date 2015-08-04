//
//  BBYearMatcher.m
//  ZXCVBN
//
//  Created by wangsw on 10/20/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBYearMatcher.h"

#import "BBRegularExpressionMatchHelper.h"

@implementation BBYearMatcher

- (NSArray *)match:(NSString *)password {
    return [BBRegularExpressionMatchHelper match:password withRegularExpression:@"19\\d\\d|200\\d|201\\d" type:BBPatternTypeYear];
}

@end
