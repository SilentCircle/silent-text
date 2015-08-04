//
//  BBSpatialMatcher.h
//  ZXCVBN
//
//  Created by wangsw on 10/20/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBPatternMatcher.h"

@interface BBSpatialMatcher : NSObject <BBPatternMatcher>

- (id)initWithAdjacencyGraphs:(NSDictionary *)adjacencyGraphs;

@end
