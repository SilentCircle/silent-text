//
//  BBRegularExpressionMatchHelper.h
//  ZXCVBN
//
//  Created by wangsw on 10/20/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBPattern.h"

@interface BBRegularExpressionMatchHelper : NSObject

+ (NSArray *)match:(NSString *)password withRegularExpression:(NSString *)expression type:(BBPatternType)expressionType;

@end
