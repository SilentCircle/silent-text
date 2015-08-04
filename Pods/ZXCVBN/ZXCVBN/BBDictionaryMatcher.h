//
//  BBDictionaryMatcher.h
//  ZXCVBN
//
//  Created by wangsw on 10/18/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBPatternMatcher.h"

@interface BBDictionaryMatcher : NSObject <BBPatternMatcher>

- (id)initWithDictionaryName:(NSString *)name andList:(NSArray *)list;

@end
