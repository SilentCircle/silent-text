//
//  BBL33tMatcher.h
//  ZXCVBN
//
//  Created by wangsw on 10/19/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBPatternMatcher.h"

@interface BBL33tMatcher : NSObject <BBPatternMatcher>

- (id)initWithDictionaryMatchers:(NSArray *)dictionaryMatcher;

@end
