//
//  BBEntropyCenter.h
//  ZXCVBN
//
//  Created by wangsw on 10/22/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBPattern.h"

@interface BBEntropyCenter : NSObject

+ (int)bruteforceCardinalityOfString:(NSString *)string;

+ (void)initializeWithAdjacencyGraphs:(NSDictionary *)adjacencyGraphs;

+ (BBEntropyCenter *)defaultCenter;

- (double)entropyOf:(BBPattern *)match;

@end
