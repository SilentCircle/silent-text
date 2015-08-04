//
//  BBRepeatMatcher.m
//  ZXCVBN
//
//  Created by wangsw on 10/20/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBRepeatMatcher.h"

#import "BBPattern.h"

@implementation BBRepeatMatcher

- (NSArray *)match:(NSString *)password {
    NSMutableArray *result = [NSMutableArray array];
    
    NSString *currentRepeatingChar;
    int begin, repeatCount = 0;
    for (int i = 0; i < password.length; i++) {
        NSString *ch = [password substringWithRange:NSMakeRange(i, 1)];
        if ([currentRepeatingChar isEqualToString:ch]) {
            repeatCount++;
        } else {
            if (currentRepeatingChar && repeatCount > 2) {
                BBPattern *match = [[BBPattern alloc] init];
                match.type = BBPatternTypeRepeat;
                match.begin = begin;
                match.end = i - 1;
                match.token = [password substringWithRange:NSMakeRange(begin, i - begin)];
                match.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                    currentRepeatingChar, BBRepeatPatternUserInfoKeyRepeatedChar,
                                    nil];
                [result addObject:match];
            }
            repeatCount = 1;
            begin = i;
            currentRepeatingChar = ch;
        }
    }
    
    return result;
}

@end
