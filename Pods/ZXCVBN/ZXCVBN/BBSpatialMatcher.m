//
//  BBSpatialMatcher.m
//  ZXCVBN
//
//  Created by wangsw on 10/20/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBSpatialMatcher.h"

#import "BBPattern.h"

@interface BBSpatialMatcher ()

@property (strong, nonatomic) NSDictionary *adjacencyGraphs;

@end

@implementation BBSpatialMatcher

- (id)initWithAdjacencyGraphs:(NSDictionary *)adjacencyGraphs {
    self = [super init];
    if (self) {
        self.adjacencyGraphs = adjacencyGraphs;
    }
    return self;
}

- (NSArray *)match:(NSString *)password {
    NSMutableArray *result = [NSMutableArray array];
    
    for (NSString *graphName in self.adjacencyGraphs) {
        NSDictionary *graph = [self.adjacencyGraphs objectForKey:graphName];
        [result addObjectsFromArray:[self match:password withAdjacencyGraph:graph named:graphName]];
    }
    
    return result;
}

- (NSArray *)match:(NSString *)password withAdjacencyGraph:(NSDictionary *)graph named:(NSString *)graphName {
    if ([password length] == 0) return @[];
    NSMutableArray *result = [NSMutableArray array];

    int i = 0;
    while (i < password.length - 1) {
        int j = i + 1;
        int lastDirection = -1;
        int turns = 0;
        int shiftedCount = 0;
        while (1) {
            NSString *previousChar = [password substringWithRange:NSMakeRange(j - 1, 1)];
            BOOL found = NO;
            int currentDirection = -1;
            NSArray *adjacents = [graph objectForKey:previousChar];
            if (!adjacents) {
                adjacents = [NSArray array];
            }
            if (j < password.length) {
                NSString *currentChar = [password substringWithRange:NSMakeRange(j, 1)];
                for (NSString *adjacent in adjacents) {
                    currentDirection++;
                    // Check if adjacent is nil, NSNull (if in json there is "null") or empty string
                    if (adjacent && adjacent != (NSString *)[NSNull null] && adjacent.length) {
                        NSRange foundPosition = [adjacent rangeOfString:currentChar];
                        if (foundPosition.location != NSNotFound) {
                            found = YES;
                            if (foundPosition.location == 1) {
                                shiftedCount++;
                            }
                            if (lastDirection != currentDirection) {
                                turns++;
                                lastDirection = currentDirection;
                            }
                            break;
                        }
                    }
                }
            }
            if (found) {
                j++;
            } else {
                if (j - i > 2) {
                    BBPattern *match = [[BBPattern alloc] init];
                    match.type = BBPatternTypeSpatial;
                    match.begin = i;
                    match.end = j - 1;
                    match.token = [password substringWithRange:NSMakeRange(i, j - i)];
                    match.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      graphName, BBSpatialPatternUserInfoKeyGraph,
                                      [NSNumber numberWithInt:turns], BBSpatialPatternUserInfoKeyTurns,
                                      [NSNumber numberWithInt:shiftedCount], BBSpatialPatternUserInfoKeyShiftedCount,
                                      nil];
                    [result addObject:match];
                }
                i = j;
                break;
            }
        }
    }
    
    return result;
}

@end
