
//
//  BBPatternCenter.m
//  ZXCVBN
//
//  Created by wangsw on 10/18/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBPatternCenter.h"

#import "BBEntropyCenter.h"

#import "BBDictionaryMatcher.h"
#import "BBL33tMatcher.h"
#import "BBSpatialMatcher.h"
#import "BBRepeatMatcher.h"
#import "BBSequenceMatcher.h"
#import "BBDigitsMatcher.h"
#import "BBYearMatcher.h"

static BBPatternCenter *g_defaultCenter;

@interface BBPatternCenter ()

@property (strong, nonatomic) NSArray *dictionaryMatchers;
@property (strong, nonatomic) NSDictionary *adjacencyGraphs;

@end

@implementation BBPatternCenter

+ (BBPatternCenter *)defaultCenter {
    if (!g_defaultCenter) {
        g_defaultCenter = [[BBPatternCenter alloc] init];
        [g_defaultCenter loadJsonData];
    }
    return g_defaultCenter;
}

- (void)loadJsonData {
    [self loadDictionaryMatchers];
    [self loadAdjacencyGraphs];
    
    [BBEntropyCenter initializeWithAdjacencyGraphs:self.adjacencyGraphs];
}

- (NSArray *)match:(NSString *)password {
    NSMutableArray *result = [NSMutableArray array];
    
    for (BBDictionaryMatcher *matcher in self.dictionaryMatchers) {
        [result addObjectsFromArray:[matcher match:password]];
    }
    
    BBL33tMatcher *l33tMatcher = [[BBL33tMatcher alloc] initWithDictionaryMatchers:self.dictionaryMatchers];
    [result addObjectsFromArray:[l33tMatcher match:password]];

    BBSpatialMatcher *spatialMatcher = [[BBSpatialMatcher alloc] initWithAdjacencyGraphs:self.adjacencyGraphs];
    [result addObjectsFromArray:[spatialMatcher match:password]];
    
    BBRepeatMatcher *repeatMatcher = [[BBRepeatMatcher alloc] init];
    [result addObjectsFromArray:[repeatMatcher match:password]];
    
    BBSequenceMatcher *sequenceMatcher = [[BBSequenceMatcher alloc] init];
    [result addObjectsFromArray:[sequenceMatcher match:password]];
    
    BBDigitsMatcher *digitsMatcher = [[BBDigitsMatcher alloc] init];
    [result addObjectsFromArray:[digitsMatcher match:password]];
    
    BBYearMatcher *yearMatcher = [[BBYearMatcher alloc] init];
    [result addObjectsFromArray:[yearMatcher match:password]];
    
    return result;
}

- (void)loadDictionaryMatchers {
    NSMutableArray *matchers = [NSMutableArray array];
    NSString *jsonPath = [[NSBundle mainBundle] pathForResource:@"frequency_lists" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
    NSDictionary *dicts = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    for (NSString *dictName in dicts) {
        [matchers addObject:[[BBDictionaryMatcher alloc] initWithDictionaryName:dictName andList:[dicts objectForKey:dictName]]];
    }
    self.dictionaryMatchers = matchers;
}

- (void)loadAdjacencyGraphs {
    NSString *jsonPath = [[NSBundle mainBundle] pathForResource:@"adjacency_graphs" ofType:@"json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
    self.adjacencyGraphs = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
}

@end
