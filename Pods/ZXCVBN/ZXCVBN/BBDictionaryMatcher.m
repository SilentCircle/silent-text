//
//  BBDictionaryMatcher.m
//  ZXCVBN
//
//  Created by wangsw on 10/18/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBDictionaryMatcher.h"

#import "BBPattern.h"

@interface BBDictionaryMatcher ()

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSDictionary *dictionary;

@end

@implementation BBDictionaryMatcher

- (id)initWithDictionaryName:(NSString *)name andList:(NSArray *)list {
    self = [super init];
    if (self) {
        self.name = name;
        
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        int i = 1;
        for (NSString *word in list) {
            [dictionary setObject:[NSNumber numberWithInt:i] forKey:word];
            i++;
        }
        self.dictionary = dictionary;
    }
    return self;
}

- (NSArray *)match:(NSString *)password {
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger length = password.length;
    NSString *lower = [password lowercaseString];
    
    for (int i = 0; i < length; i++) {
        for (int j = i; j < length; j++) {
            NSString *word = [lower substringWithRange:NSMakeRange(i, j - i + 1)];
            NSNumber *rank = [self.dictionary objectForKey:word];
            if (rank) {
                BBPattern *pattern = [[BBPattern alloc] init];
                pattern.type = BBPatternTypeDictionary;
                pattern.begin = i;
                pattern.end = j;
                pattern.token = [password substringWithRange:NSMakeRange(i, j - i + 1)];
                pattern.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                    word, BBDictionaryPatternUserInfoKeyMatchedWord,
                                    rank, BBDictionaryPatternUserInfoKeyRank,
                                    self.name, BBDictionaryPatternUserInfoKeyDictionaryName,
                                    nil];
                [result addObject:pattern];
            }
        }
    }
    
    return result;
}

@end
