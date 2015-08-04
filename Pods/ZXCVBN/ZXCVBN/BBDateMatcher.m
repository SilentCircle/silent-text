//
//  BBDateMatcher.m
//  ZXCVBN
//
//  Created by wangsw on 10/21/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBDateMatcher.h"

#import "BBPattern.h"

typedef struct {
    int year;
    int month;
    int day;
} BBDate;

static NSString * const BBDateCandidateInfoKeyDayMonth = @"daymonth";
static NSString * const BBDateCandidateInfoKeyMonth = @"month";
static NSString * const BBDateCandidateInfoKeyDay = @"day";
static NSString * const BBDateCandidateInfoKeyYear = @"year";
static NSString * const BBDateCandidateInfoKeyBegin = @"begin";
static NSString * const BBDateCandidateInfoKeyEnd = @"end";
static NSString * const BBDateCandidateInfoKeySeparator = @"separator";


@implementation BBDateMatcher

+ (BBDate)makeZeroDate {
    BBDate date;
    date.year = 0;
    date.month = 0;
    date.day = 0;
    return date;
}

+ (BBDate)validateDate:(BBDate)date {
    if (date.month > 12 && date.month < 32 && date.day < 13) {
        int tmp = date.month;
        date.month = date.day;
        date.day = tmp;
    }
    
    if (date.year > 2019 || date.year < 1900) {
        return [BBDateMatcher makeZeroDate];
    }
    if (date.month > 12 || date.month < 1) {
        return [BBDateMatcher makeZeroDate];
    }
    if (date.day > 12 || date.day < 1) {
        return [BBDateMatcher makeZeroDate];
    }
    
    return date;
}

- (NSArray *)match:(NSString *)password {
    NSMutableArray *result = [NSMutableArray array];
    [result addObjectsFromArray:[self matchWithoutSeparator:password]];
    [result addObjectsFromArray:[self matchWithSeperator:password]];
    return result;
}

- (NSArray *)matchWithoutSeparator:(NSString *)password {
    NSMutableArray *candidates1 = [NSMutableArray array];
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\d{4,8}" options:0 error:nil];
    [regex enumerateMatchesInString:password options:0 range:NSMakeRange(0, password.length) usingBlock:^ (NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSRange range = result.range;
        NSNumber *begin = [NSNumber numberWithUnsignedInteger:range.location];
        NSNumber *end = [NSNumber numberWithUnsignedInteger:range.location + range.length - 1];
        NSString *token = [password substringWithRange:range];
        
        // token.length == 6 can both be explained as "09 11 20" or "2009 1 2"
        if (token.length < 7) {
            [candidates1 addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [token substringFromIndex:2], BBDateCandidateInfoKeyDayMonth,
                                    [token substringToIndex:2], BBDateCandidateInfoKeyYear,
                                    begin, BBDateCandidateInfoKeyBegin,
                                    end, BBDateCandidateInfoKeyEnd,
                                    nil]];
            [candidates1 addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [token substringToIndex:token.length - 2], BBDateCandidateInfoKeyDayMonth,
                                    [token substringFromIndex:token.length - 2], BBDateCandidateInfoKeyYear,
                                    begin, BBDateCandidateInfoKeyBegin,
                                    end, BBDateCandidateInfoKeyEnd,
                                    nil]];
        }
        if (token.length > 5) {
            [candidates1 addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [token substringFromIndex:4], BBDateCandidateInfoKeyDayMonth,
                                    [token substringToIndex:4], BBDateCandidateInfoKeyYear,
                                    begin, BBDateCandidateInfoKeyBegin,
                                    end, BBDateCandidateInfoKeyEnd,
                                    nil]];
            [candidates1 addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [token substringToIndex:token.length - 4], BBDateCandidateInfoKeyDayMonth,
                                    [token substringFromIndex:token.length - 4], BBDateCandidateInfoKeyYear,
                                    begin, BBDateCandidateInfoKeyBegin,
                                    end, BBDateCandidateInfoKeyEnd,
                                    nil]];
        }
    }];
    
    NSMutableArray *candidates2 = [NSMutableArray array];
    
    for (NSDictionary *candidate in candidates1) {
        NSString *daymonth = [candidate objectForKey:BBDateCandidateInfoKeyDayMonth];
        if (daymonth.length == 2) {
            [candidates2 addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [daymonth substringToIndex:1], BBDateCandidateInfoKeyDay,
                                    [daymonth substringFromIndex:1], BBDateCandidateInfoKeyMonth,
                                    [candidate objectForKey:BBDateCandidateInfoKeyYear], BBDateCandidateInfoKeyYear,
                                    [candidate objectForKey:BBDateCandidateInfoKeyBegin], BBDateCandidateInfoKeyBegin,
                                    [candidate objectForKey:BBDateCandidateInfoKeyEnd], BBDateCandidateInfoKeyEnd,
                                    nil]];
        } else if (daymonth.length == 3) {
            [candidates2 addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [daymonth substringToIndex:1], BBDateCandidateInfoKeyDay,
                                    [daymonth substringFromIndex:1], BBDateCandidateInfoKeyMonth,
                                    [candidate objectForKey:BBDateCandidateInfoKeyYear], BBDateCandidateInfoKeyYear,
                                    [candidate objectForKey:BBDateCandidateInfoKeyBegin], BBDateCandidateInfoKeyBegin,
                                    [candidate objectForKey:BBDateCandidateInfoKeyEnd], BBDateCandidateInfoKeyEnd,
                                    nil]];
            [candidates2 addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [daymonth substringToIndex:2], BBDateCandidateInfoKeyDay,
                                    [daymonth substringFromIndex:2], BBDateCandidateInfoKeyMonth,
                                    [candidate objectForKey:BBDateCandidateInfoKeyYear], BBDateCandidateInfoKeyYear,
                                    [candidate objectForKey:BBDateCandidateInfoKeyBegin], BBDateCandidateInfoKeyBegin,
                                    [candidate objectForKey:BBDateCandidateInfoKeyEnd], BBDateCandidateInfoKeyEnd,
                                    nil]];
        } else if (daymonth.length == 4) {
            [candidates2 addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [daymonth substringToIndex:2], BBDateCandidateInfoKeyDay,
                                    [daymonth substringFromIndex:2], BBDateCandidateInfoKeyMonth,
                                    [candidate objectForKey:BBDateCandidateInfoKeyYear], BBDateCandidateInfoKeyYear,
                                    [candidate objectForKey:BBDateCandidateInfoKeyBegin], BBDateCandidateInfoKeyBegin,
                                    [candidate objectForKey:BBDateCandidateInfoKeyEnd], BBDateCandidateInfoKeyEnd,
                                    nil]];
        }
    }
    
    NSMutableArray *matches = [NSMutableArray array];
    
    for (NSDictionary *candidate in candidates2) {
        BBDate date;
        NSString *dayStr = [candidate objectForKey:BBDateCandidateInfoKeyDay];
        date.day = dayStr.intValue;
        NSString *monthStr = [candidate objectForKey:BBDateCandidateInfoKeyMonth];
        date.month = monthStr.intValue;
        NSString *yearStr = [candidate objectForKey:BBDateCandidateInfoKeyYear];
        date.year = yearStr.intValue;
        date = [BBDateMatcher validateDate:date];
        if (date.year) {
            BBPattern *match = [[BBPattern alloc] init];
            match.type = BBPatternTypeDate;
            match.begin = ((NSNumber *)[candidate objectForKey:BBDateCandidateInfoKeyBegin]).intValue;
            match.end = ((NSNumber *)[candidate objectForKey:BBDateCandidateInfoKeyEnd]).intValue;
            match.token = [password substringWithRange:NSMakeRange(match.begin, match.end - match.begin + 1)];
            match.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithInt:date.year], BBDatePatternUserInfoKeyYear,
                              [NSNumber numberWithInt:date.month], BBDatePatternUserInfoKeyMonth,
                              [NSNumber numberWithInt:date.day], BBDatePatternUserInfoKeyDay,
                              @"", BBDatePatternUserInfoKeySeparator,
                              nil];
            [matches addObject:match];
        }
    }
    
    return matches;
}

- (NSArray *)matchWithSeperator:(NSString *)password {
    NSMutableArray *matches = [NSMutableArray array];
    
    NSString *yearSuffixPattern = @"(\\d{1,2})(\\s|-|/|\\|_|\\.)(\\d{1,2})\\2(19\\d{2}|200\\d|201\\d|\\d{2})";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:yearSuffixPattern options:0 error:nil];
    [regex enumerateMatchesInString:password options:0 range:NSMakeRange(0, password.length) usingBlock:^ (NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSRange dayRange = [result rangeAtIndex:1];
        int day = [password substringWithRange:dayRange].intValue;
        NSRange monthRange = [result rangeAtIndex:3];
        int month = [password substringWithRange:monthRange].intValue;
        NSRange yearRange = [result rangeAtIndex:4];
        int year = [password substringWithRange:yearRange].intValue;
        NSRange separatorRange = [result rangeAtIndex:2];
        NSString *separator = [password substringWithRange:separatorRange];
        NSRange range = result.range;
        NSUInteger begin = range.location;
        NSUInteger end = range.location + range.length - 1;
        [matches addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithInteger:day], BBDateCandidateInfoKeyDay,
                            [NSNumber numberWithInteger:month], BBDateCandidateInfoKeyMonth,
                            [NSNumber numberWithInteger:year], BBDateCandidateInfoKeyYear,
                            separator, BBDatePatternUserInfoKeySeparator,
                            [NSNumber numberWithInteger:begin], BBDateCandidateInfoKeyBegin,
                            [NSNumber numberWithInteger:end], BBDateCandidateInfoKeyEnd,
                            nil]];
    }];
    
    NSString *yearPrefixPattern = @"(19\\d{2}|200\\d|201\\d|\\d{2})(\\s|-|/|\\|_|\\.)(\\d{1,2})\\2(\\d{1,2})";
    regex = [NSRegularExpression regularExpressionWithPattern:yearPrefixPattern options:0 error:nil];
    [regex enumerateMatchesInString:password options:0 range:NSMakeRange(0, password.length) usingBlock:^ (NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSRange dayRange = [result rangeAtIndex:4];
        int day = [password substringWithRange:dayRange].intValue;
        NSRange monthRange = [result rangeAtIndex:3];
        int month = [password substringWithRange:monthRange].intValue;
        NSRange yearRange = [result rangeAtIndex:1];
        int year = [password substringWithRange:yearRange].intValue;
        NSRange separatorRange = [result rangeAtIndex:2];
        NSString *separator = [password substringWithRange:separatorRange];
        NSRange range = result.range;
        NSUInteger begin = range.location;
        NSUInteger end = range.location + range.length - 1;
        [matches addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithInteger:day], BBDateCandidateInfoKeyDay,
                            [NSNumber numberWithInteger:month], BBDateCandidateInfoKeyMonth,
                            [NSNumber numberWithInteger:year], BBDateCandidateInfoKeyYear,
                            separator, BBDatePatternUserInfoKeySeparator,
                            [NSNumber numberWithInteger:begin], BBDateCandidateInfoKeyBegin,
                            [NSNumber numberWithInteger:end], BBDateCandidateInfoKeyEnd,
                            nil]];
    }];
    
    NSMutableArray *result = [NSMutableArray array];
    
    for (NSDictionary *match in matches) {
        BBDate date;
        NSNumber *dayNum = [match objectForKey:BBDateCandidateInfoKeyDay];
        date.day = dayNum.intValue;
        NSNumber *monthNum = [match objectForKey:BBDateCandidateInfoKeyMonth];
        date.month = monthNum.intValue;
        NSNumber *yearNum = [match objectForKey:BBDateCandidateInfoKeyYear];
        date.year = yearNum.intValue;
        date = [BBDateMatcher validateDate:date];
        if (date.year) {
            BBPattern *pattern = [[BBPattern alloc] init];
            pattern.type = BBPatternTypeDate;
            pattern.begin = ((NSNumber *)[match objectForKey:BBDateCandidateInfoKeyBegin]).intValue;
            pattern.end = ((NSNumber *)[match objectForKey:BBDateCandidateInfoKeyEnd]).intValue;
            pattern.token = [password substringWithRange:NSMakeRange(pattern.begin, pattern.end - pattern.begin + 1)];
            pattern.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithInt:date.year], BBDatePatternUserInfoKeyYear,
                                [NSNumber numberWithInt:date.month], BBDatePatternUserInfoKeyMonth,
                                [NSNumber numberWithInt:date.day], BBDatePatternUserInfoKeyDay,
                                @"", BBDatePatternUserInfoKeySeparator,
                                nil];
            [result addObject:pattern];
        }
    }
    
    return result;
}

@end
