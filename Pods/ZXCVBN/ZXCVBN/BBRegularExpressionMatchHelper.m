//
//  BBRegularExpressionMatchHelper.m
//  ZXCVBN
//
//  Created by wangsw on 10/20/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBRegularExpressionMatchHelper.h"

@implementation BBRegularExpressionMatchHelper

+ (NSArray *)match:(NSString *)password withRegularExpression:(NSString *)expression type:(BBPatternType)expressionType {
    NSMutableArray *matches = [NSMutableArray array];
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:expression options:0 error:nil];
    [regex enumerateMatchesInString:password options:0 range:NSMakeRange(0, password.length) usingBlock:^ (NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSRange range = result.range;
        NSUInteger begin = range.location;
        NSUInteger end = range.location + range.length - 1;
        BBPattern *match = [[BBPattern alloc] init];
        match.type = expressionType;
        match.begin = begin;
        match.end = end;
        match.token = [password substringWithRange:range];
        [matches addObject:match];
    }];
    
    return matches;
}

@end
