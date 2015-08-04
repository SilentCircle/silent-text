//
//  BBSequenceMatcher.m
//  ZXCVBN
//
//  Created by wangsw on 10/20/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBSequenceMatcher.h"

#import "BBPattern.h"

static NSDictionary *g_sequences;

@implementation BBSequenceMatcher

+ (NSDictionary *)sequences {
    if (!g_sequences) {
        g_sequences = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"abcdefghijklmnopqrstuvwxyz", @"lower",
                       @"ABCDEFGHIJKLMNOPQRSTUVWXYZ", @"upper",
                       @"0123456789", @"digits",
                       nil];
    }
    return g_sequences;
}

- (NSArray *)match:(NSString *)password {
    NSMutableArray *result = [NSMutableArray array];
    
    int i = 0;
    while (i < password.length) {
        int j = i + 1;
        NSString *sequence;
        NSString *sequenceName;
        NSInteger sequenceDirection;
        
        NSDictionary *sequences = [BBSequenceMatcher sequences];
        for (NSString *candidateName in sequences) {
            NSString *candidateSequence = [sequences objectForKey:candidateName];
            NSInteger iPosition = [candidateSequence rangeOfString:[password substringWithRange:NSMakeRange(i, 1)]].location;
            NSInteger jPosition = NSNotFound;
            if (j < password.length) {
                jPosition = [candidateSequence rangeOfString:[password substringWithRange:NSMakeRange(j, 1)]].location;
            }
            
            if (iPosition != NSNotFound && jPosition != NSNotFound) {
                NSInteger direction = jPosition - iPosition;
                if (abs((int)direction) == 1) {
                    sequence = candidateSequence;
                    sequenceName = candidateName;
                    sequenceDirection = direction;
                    break;
                }
            }
        }
        
        if (sequence) {
            while (1) {
                NSInteger previousPosition = NSNotFound, currentPosition = NSNotFound;
                if (j < password.length) {
                    NSString *previousChar = [password substringWithRange:NSMakeRange(j - 1, 1)];
                    NSString *currentChar = [password substringWithRange:NSMakeRange(j, 1)];
                    previousPosition = [sequence rangeOfString:previousChar].location;
                    currentPosition = [sequence rangeOfString:currentChar].location;
                }
                if (j == password.length || currentPosition - previousPosition != sequenceDirection) {
                    if (j - i > 2) {
                        BBPattern *match = [[BBPattern alloc] init];
                        match.type = BBPatternTypeSequence;
                        match.begin = i;
                        match.end = j - 1;
                        match.token = [password substringWithRange:NSMakeRange(i, j - i)];
                        match.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                          sequenceName, BBSequencePatternUserInfoKeySequenceName,
                                          [NSNumber numberWithInteger:sequence.length], BBSequencePatternUserInfoKeySequenceSpace,
                                          [NSNumber numberWithBool:sequenceDirection == 1], BBSequencePatternUserInfoKeyAscending,
                                          nil];
                        [result addObject:match];
                    }
                    break;
                } else {
                    j += 1;
                }
            }
        }
        i = j;
    }
    
    return result;
}

@end
