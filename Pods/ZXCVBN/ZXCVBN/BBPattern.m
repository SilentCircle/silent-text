//
//  BBPattern.m
//  ZXCVBN
//
//  Created by wangsw on 10/18/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

#import "BBPattern.h"

NSString * const BBDictionaryPatternUserInfoKeyMatchedWord = @"matchedWord";
NSString * const BBDictionaryPatternUserInfoKeyRank = @"rank";
NSString * const BBDictionaryPatternUserInfoKeyDictionaryName = @"dictionaryName";
NSString * const BBDictionaryPatternUserInfoKeyBaseEntropy = @"baseEntropy";
NSString * const BBDictionaryPatternUserInfoKeyUppercaseEntropy = @"uppercaseEntropy";

NSString * const BBL33tPatternUserInfoKeySubstitution = @"substitution";
NSString * const BBL33tPatternUserInfoKeySubstitutionDisplay = @"substitutionDisplay";
NSString * const BBL33tPatternUserInfoKeyL33tEntropy = @"l33tEntropy";

NSString * const BBSpatialPatternUserInfoKeyGraph = @"graph";
NSString * const BBSpatialPatternUserInfoKeyTurns = @"turns";
NSString * const BBSpatialPatternUserInfoKeyShiftedCount = @"shiftedCount";

NSString * const BBRepeatPatternUserInfoKeyRepeatedChar = @"repeatedChar";

NSString * const BBSequencePatternUserInfoKeySequenceName = @"sequenceName";
NSString * const BBSequencePatternUserInfoKeySequenceSpace = @"sequenceSpace";
NSString * const BBSequencePatternUserInfoKeyAscending = @"ascending";

NSString * const BBDatePatternUserInfoKeyMonth = @"month";
NSString * const BBDatePatternUserInfoKeyDay = @"day";
NSString * const BBDatePatternUserInfoKeyYear = @"year";
NSString * const BBDatePatternUserInfoKeySeparator = @"separator";

NSString * const BBBruteforcePatternUserInfoKeyCardinality = @"cardinality";

@implementation BBPattern

- (id)init {
    self = [super init];
    if (self) {
        self.entropy = ENTROPY_UNKONWN;
    }
    return self;
}

- (NSString *)description {
    NSString *patternType;
    switch (self.type) {
        case BBPatternTypeDictionary:
            patternType = @"BBPatternTypeDictionary";
            break;
            
        case BBPatternTypeL33t:
            patternType = @"BBPatternTypeL33t";
            break;
            
        case BBPatternTypeSpatial:
            patternType = @"BBPatternTypeSpatial";
            break;
            
        case BBPatternTypeRepeat:
            patternType = @"BBPatternTypeRepeat";
            break;
            
        case BBPatternTypeSequence:
            patternType = @"BBPatternTypeSequence";
            break;
            
        case BBPatternTypeDigits:
            patternType = @"BBPatternTypeDigits";
            break;
            
        case BBPatternTypeYear:
            patternType = @"BBPatternTypeYear";
            break;
            
        case BBPatternTypeDate:
            patternType = @"BBPatternTypeDate";
            break;
            
        case BBPatternTypeBruteforce:
            patternType = @"BBPatternTypeBruteforce";
            break;
            
        default:
            patternType = @"BBPatternTypeUnknown";
            break;
    }

    return [NSString stringWithFormat:@"<BBPattern (%@): %@, %f>", patternType, self.token, self.entropy];
}

@end
