//
//  BBPatternMatcher.h
//  ZXCVBN
//
//  Created by wangsw on 10/18/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

@protocol BBPatternMatcher <NSObject>

- (NSArray *)match:(NSString *)password;

@end
