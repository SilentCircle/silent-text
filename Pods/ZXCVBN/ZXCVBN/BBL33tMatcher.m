//
//  BBL33tMatcher.m
//  ZXCVBN
//
//  Created by wangsw on 10/19/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBL33tMatcher.h"

#import "BBDictionaryMatcher.h"

#import "BBPattern.h"

static NSDictionary *g_l33tTable;

@interface BBL33tMatcher ()

@property (strong, nonatomic) NSArray *dictionaryMatchers;

@end

@implementation BBL33tMatcher

+ (NSDictionary *)table {
    if (!g_l33tTable) {
        g_l33tTable = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSArray arrayWithObjects:@"4", @"@", nil], @"a",
                       [NSArray arrayWithObjects:@"8", nil], @"b",
                       [NSArray arrayWithObjects:@"(", @"{", @"[", @"<", nil], @"c",
                       [NSArray arrayWithObjects:@"3", nil], @"e",
                       [NSArray arrayWithObjects:@"6", @"9", nil], @"g",
                       [NSArray arrayWithObjects:@"1", @"!", @"|", nil], @"i",
                       [NSArray arrayWithObjects:@"1", @"|", @"7", nil], @"l",
                       [NSArray arrayWithObjects:@"0", nil], @"o",
                       [NSArray arrayWithObjects:@"$", @"5", nil], @"s",
                       [NSArray arrayWithObjects:@"+", @"7", nil], @"t",
                       [NSArray arrayWithObjects:@"%", nil], @"x",
                       [NSArray arrayWithObjects:@"2", nil], @"z",
                       nil];
    }
    return g_l33tTable;
}

+ (NSDictionary *)relevantTableForPassword:(NSString *)password {
    NSCharacterSet *chars = [NSCharacterSet characterSetWithCharactersInString:password];
    NSDictionary *originTable = [BBL33tMatcher table];
    
    NSMutableDictionary *filteredTable = [NSMutableDictionary dictionary];
    
    for (NSString *letter in originTable) {
        NSArray *originChars = [originTable objectForKey:letter];
        NSMutableArray *filteredChars = [NSMutableArray array];
        for (NSString *ch in originChars) {
            if ([chars characterIsMember:*[ch UTF8String]]) {
                [filteredChars addObject:ch];
            }
        }
        if (filteredChars.count) {
            [filteredTable setObject:filteredChars forKey:letter];
        }
    }
    
    return filteredTable;
}

+ (NSSet *)enumerateSubstitutionsInTable:(NSDictionary *)relevantTable {
    NSMutableSet *substitutions = [NSMutableSet setWithObject:[NSMutableSet set]];
    NSMutableArray *keys = [relevantTable.allKeys mutableCopy];
    
    while (keys.count) {
        NSString *currentKey = [keys objectAtIndex:0];
        [keys removeObjectAtIndex:0];
        
        for (NSString *l33tChar in [relevantTable objectForKey:currentKey]) {
            NSMutableSet *newSubstitutions = [NSMutableSet set];
            for (NSMutableSet *substitution in substitutions) {
                BOOL duplicateFlag = NO;
                for (NSString *pair in substitution) {
                    if ([[pair substringToIndex:1] isEqualToString:l33tChar]) {
                        duplicateFlag = YES;
                        NSMutableSet *newSubstitution = [substitution mutableCopy];
                        [newSubstitution removeObject:pair];
                        [newSubstitution addObject:[NSString stringWithFormat:@"%@%@", l33tChar, currentKey]];
                        [newSubstitutions addObject:newSubstitution];
                        break;
                    }
                }
                if (!duplicateFlag) {
                    [substitution addObject:[NSString stringWithFormat:@"%@%@", l33tChar, currentKey]];
                }
            }
            [substitutions addObjectsFromArray:newSubstitutions.allObjects];
        }
    }
    
    return substitutions;
}

+ (NSString *)translate:(NSString *)string withSubstitution:(NSSet *)substitution {
    NSMutableDictionary *substitutionDictionary = [NSMutableDictionary dictionary];
    for (NSString *pair in substitution) {
        NSString *l33tChar = [pair substringToIndex:1];
        NSString *originChar = [pair substringFromIndex:1];
        [substitutionDictionary setObject:originChar forKey:l33tChar];
    }
    
    NSMutableString *result = [NSMutableString string];
    for (int i = 0; i < string.length; i++) {
        NSString *ch = [string substringWithRange:NSMakeRange(i, 1)];
        NSString *origin = [substitutionDictionary objectForKey:ch];
        if (origin) {
            [result appendString:origin];
        } else {
            [result appendString:ch];
        }
    }
    
    return result;
}

- (id)initWithDictionaryMatchers:(NSArray *)dictionaryMatcher {
    self = [super init];
    if (self) {
        self.dictionaryMatchers = dictionaryMatcher;
    }
    return self;
}

- (NSArray *)match:(NSString *)password {
    NSMutableArray *result = [NSMutableArray array];
    
    NSDictionary *relevantTable = [BBL33tMatcher relevantTableForPassword:password];
    NSSet *substitutions = [BBL33tMatcher enumerateSubstitutionsInTable:relevantTable];
    
    for (NSSet *substitution in substitutions) {
        if (substitution.count) {
            NSString *substituted = [BBL33tMatcher translate:password withSubstitution:substitution];
            for (BBDictionaryMatcher *matcher in self.dictionaryMatchers) {
                NSArray *matches = [matcher match:substituted];
                for (BBPattern *match in matches) {
                    NSString *token = [password substringWithRange:NSMakeRange(match.begin, match.end - match.begin + 1)];
                    token = token.lowercaseString;
                    if ([token isEqualToString:[match.userInfo objectForKey:BBDictionaryPatternUserInfoKeyMatchedWord]]) {
                        continue;
                    }
                    
                    match.type = BBPatternTypeL33t;
                    match.token = token;
                    
                    NSMutableDictionary *userInfo = [match.userInfo mutableCopy];
                    
                    NSMutableDictionary *matchSubstitution = [NSMutableDictionary dictionary];
                    NSMutableString *substitutionDisplay = [@"" mutableCopy];
                    for (NSString *pair in substitution) {
                        NSString *l33tChar = [pair substringToIndex:1];
                        if ([token rangeOfString:l33tChar].location != NSNotFound) {
                            NSString *originChar = [pair substringFromIndex:1];
                            [matchSubstitution setObject:originChar forKey:l33tChar];
                            if (substitutionDisplay) {
                                [substitutionDisplay appendFormat:@", %@ -> %@", l33tChar, originChar];
                            }
                        }
                    }
                    [userInfo setObject:matchSubstitution forKey:BBL33tPatternUserInfoKeySubstitution];
                    [userInfo setObject:substitutionDisplay forKey:BBL33tPatternUserInfoKeySubstitutionDisplay];
                    
                    match.userInfo = userInfo;
                    
                    [result addObject:match];
                }
            }
        }
    }
    
    return result;
}

@end
