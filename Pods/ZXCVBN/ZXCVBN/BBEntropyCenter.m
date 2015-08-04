//
//  BBEntropyCenter.m
//  ZXCVBN
//
//  Created by wangsw on 10/22/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBEntropyCenter.h"

#import "BBPattern.h"

static BBEntropyCenter *g_defaultCenter;

@interface BBEntropyCenter ()

@property (nonatomic) double keyboardAverageDegree;
@property (nonatomic) double keypadAverageDegree;

@property (nonatomic) NSUInteger keyboardStartingPositions;
@property (nonatomic) NSUInteger keypadStartingPositions;

@end

@implementation BBEntropyCenter

+ (int)bruteforceCardinalityOfString:(NSString *)string {
    int lower = 0, upper = 0, digits = 0, symbols = 0;
    for (int i = 0; i < string.length; i++) {
        unichar ch = [string characterAtIndex:i];
        if ([[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:ch]) {
            lower = 26;
        } else if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:ch]) {
            upper = 26;
        } else if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:ch]) {
            digits = 10;
        } else {
            symbols = 33;
        }
    }
    return lower + upper + digits + symbols;
}

+ (void)initializeWithAdjacencyGraphs:(NSDictionary *)adjacencyGraphs {
    g_defaultCenter = [[BBEntropyCenter alloc] initWithAdjacencyGraphs:adjacencyGraphs];
}

+ (BBEntropyCenter *)defaultCenter {
    return g_defaultCenter;
}

+ (double)averageDegreeOfAdjacencyGraph:(NSDictionary *)graph {
    double average = 0.0;
    
    for (NSArray *neighbors in graph.allValues) {
        for (NSString *neighbor in neighbors) {
            if (neighbor != (NSString *)[NSNull null]) {
                average += 1;
            }
        }
    }
    
    average /= graph.count;
    return average;
}

+ (long long)binomialCoefficientOf:(NSInteger)k outOf:(NSInteger)n {
    if (k > n) {
        return 0;
    }
    if (k == 0) {
        return 1;
    }
    
    long long result = 1;
    for (int denominator = 1; denominator < k + 1; denominator++) {
        result *= n;
        result /= denominator;
        n--;
    }
    return result;
}

- (id)initWithAdjacencyGraphs:(NSDictionary *)adjacencyGraphs {
    self = [super init];
    if (self) {
        self.keyboardAverageDegree = [BBEntropyCenter averageDegreeOfAdjacencyGraph:[adjacencyGraphs objectForKey:@"qwerty"]];
        self.keypadAverageDegree = [BBEntropyCenter averageDegreeOfAdjacencyGraph:[adjacencyGraphs objectForKey:@"keypad"]];
        
        self.keyboardStartingPositions = ((NSDictionary *)[adjacencyGraphs objectForKey:@"qwerty"]).count;
        self.keypadStartingPositions = ((NSDictionary *)[adjacencyGraphs objectForKey:@"keypad"]).count;
    }
    return self;
}

- (double)entropyOf:(BBPattern *)match {
    if (match.entropy != ENTROPY_UNKONWN) {
        return match.entropy;
    }
    
    double entropy = 0.0;
    
    if (match.type == BBPatternTypeRepeat) {
        entropy = [self repeatEntropyOf:match];
    } else if (match.type == BBPatternTypeSequence) {
        entropy = [self sequenceEntropyOf:match];
    } else if (match.type == BBPatternTypeDigits) {
        entropy = [self digitsEntropyOf:match];
    } else if (match.type == BBPatternTypeYear) {
        entropy = [self yearEntropyOf:match];
    } else if (match.type == BBPatternTypeDate) {
        entropy = [self dateEntropyOf:match];
    } else if (match.type == BBPatternTypeSpatial) {
        entropy = [self spatialEntropyOf:match];
    } else if (match.type == BBPatternTypeDictionary || match.type == BBPatternTypeL33t) {
        entropy = [self dictionaryEntropyOf:match];
    }
    
    match.entropy = entropy;
    
    return entropy;
}

- (double)repeatEntropyOf:(BBPattern *)match {
    return log2([BBEntropyCenter bruteforceCardinalityOfString:match.token] * match.token.length);
}

- (double)sequenceEntropyOf:(BBPattern *)match {
    unichar firstChar = [match.token characterAtIndex:0];
    double baseEntropy;
    if (firstChar == (unichar)'a' || firstChar == (unichar)'1') {
        baseEntropy = 1;
    } else {
        if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:firstChar]) {
            baseEntropy = log2(10);
        } else if ([[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:firstChar]) {
            baseEntropy = log2(26);
        } else {
            baseEntropy = log2(26) + 1;
        }
    }
    if (!((NSNumber *)[match.userInfo objectForKey:BBSequencePatternUserInfoKeyAscending]).boolValue) {
        baseEntropy += 1;
    }
    return baseEntropy + log2(match.token.length);
}

- (double)digitsEntropyOf:(BBPattern *)match {
    return log2(pow(10, match.token.length));
}

static int YEAR_COUNT = 2019 - 1990;
static int MONTH_COUNT = 12;
static int DAY_COUNT = 31;

- (double)yearEntropyOf:(BBPattern *)match {
    return log2(YEAR_COUNT);
}

- (double)dateEntropyOf:(BBPattern *)match {
    double entropy;
    if (((NSNumber *)[match.userInfo objectForKey:BBDatePatternUserInfoKeyYear]).intValue < 100) {
        entropy = log2(DAY_COUNT * MONTH_COUNT * 100);
    } else {
        entropy = log2(DAY_COUNT * MONTH_COUNT * YEAR_COUNT);
    }
    
    if (((NSString *)[match.userInfo objectForKey:BBDatePatternUserInfoKeySeparator]).length) {
        entropy += 2;
    }
    return entropy;
}

- (double)spatialEntropyOf:(BBPattern *)match {
    double averageDegree;
    NSUInteger startingPositions;
    NSString *graphType = [match.userInfo objectForKey:BBSpatialPatternUserInfoKeyGraph];
    if ([graphType isEqualToString:@"qwerty"] || [graphType isEqualToString:@"dvorak"]) {
        averageDegree = self.keyboardAverageDegree;
        startingPositions = self.keyboardStartingPositions;
    } else {
        averageDegree = self.keypadAverageDegree;
        startingPositions = self.keypadStartingPositions;
    }
    
    long long possibilities = 0;
    NSUInteger length = match.token.length;
    NSInteger turns = ((NSNumber *)[match.userInfo objectForKey:BBSpatialPatternUserInfoKeyTurns]).integerValue;
    
    for (int i = 2; i < length + 1; i++) {
        NSInteger possiblyTurns = MIN(turns, i - 1);
        for (int j = 1; j < possiblyTurns + 1; j++) {
            long long x = [BBEntropyCenter binomialCoefficientOf:j - 1 outOf:i - 1] * startingPositions * pow(averageDegree, j);
            possibilities += x;
        }
    }
    
    double entropy = log2(possibilities);
    
    NSInteger shifted = ((NSNumber *)[match.userInfo objectForKey:BBSpatialPatternUserInfoKeyShiftedCount]).integerValue;
    NSInteger unshifted = length - shifted;
    possibilities = 0;
    for (int i = 0; i < MIN(shifted, unshifted); i++) {
        possibilities += [BBEntropyCenter binomialCoefficientOf:i outOf:length];
    }
    if (possibilities) {
        entropy += log2(possibilities);
    }
    return entropy;
}

- (double)dictionaryEntropyOf:(BBPattern *)match {
    int rank = ((NSNumber *)[match.userInfo objectForKey:BBDictionaryPatternUserInfoKeyRank]).intValue;
    double baseEntropy = log2(rank);
    double uppercaseEntropy = [self extraUppercaseEntropyOf:match];
    double l33tEntropy = 0.0;
    
    NSMutableDictionary *newUserInfo = [match.userInfo mutableCopy];
    [newUserInfo setObject:[NSNumber numberWithDouble:baseEntropy] forKey:BBDictionaryPatternUserInfoKeyBaseEntropy];
    [newUserInfo setObject:[NSNumber numberWithDouble:uppercaseEntropy] forKey:BBDictionaryPatternUserInfoKeyUppercaseEntropy];
    
    if (match.type == BBPatternTypeL33t) {
        l33tEntropy = [self extraL33tEntropyOf:match];
        [newUserInfo setObject:[NSNumber numberWithDouble:l33tEntropy] forKey:BBL33tPatternUserInfoKeyL33tEntropy];
    }
    
    match.userInfo = newUserInfo;
    
    double result = baseEntropy + uppercaseEntropy + l33tEntropy;
    return result;
}

- (double)extraUppercaseEntropyOf:(BBPattern *)match {
    NSString *word = match.token;
    
    if ([word.lowercaseString isEqualToString:word]) {
        return 0;
    }
    
    NSArray *upperRegularExpressions = [NSArray arrayWithObjects:
                                        @"^[A-Z][^A-Z]+$",
                                        @"^[^A-Z]+[A-Z]$",
                                        @"^[A-Z]+$",
                                        nil];
    for (NSString *regularExpression in upperRegularExpressions) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regularExpression options:0 error:nil];
        if ([regex numberOfMatchesInString:word options:0 range:NSMakeRange(0, word.length)]) {
            return 1;
        }
    }
    
    int upperCount = 0, lowerCount = 0;
    for (int i = 0; i < word.length; i++) {
        unichar ch = [word characterAtIndex:i];
        if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:ch]) {
            upperCount++;
        } else if ([[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:ch]) {
            lowerCount++;
        }
    }
    long long possibilities = 0;
    for (int i = 0; i < MIN(upperCount, lowerCount) + 1; i++) {
        possibilities += [BBEntropyCenter binomialCoefficientOf:i outOf:upperCount + lowerCount];
    }
    return log2(possibilities);
}

- (double)extraL33tEntropyOf:(BBPattern *)match {
    long long possibilities = 0;
    NSDictionary *substitution = [match.userInfo objectForKey:BBL33tPatternUserInfoKeySubstitution];
    for (NSString *l33tChar in substitution) {
        NSString *originChar = [substitution objectForKey:l33tChar];
        int l33tCount = 0, originCount = 0;
        for (int i = 0; i < match.token.length; i++) {
            NSString *ch = [match.token substringWithRange:NSMakeRange(i, 1)];
            if ([ch isEqualToString:l33tChar]) {
                l33tCount++;
            } else if ([ch isEqualToString:originChar]) {
                originCount++;
            }
        }
        
        for (int i = 0; i < MIN(l33tCount, originCount) + 1; i++) {
            possibilities += [BBEntropyCenter binomialCoefficientOf:i outOf:l33tCount + originCount];
        }
    }
    
    if (possibilities <= 1) {
        return 1;
    } else {
        return log2(possibilities);
    }
}

@end
