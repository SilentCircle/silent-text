//
//  BBPattern.h
//  ZXCVBN
//
//  Created by wangsw on 10/18/13.
//  Copyright (c) 2013 beanandbean. All rights reserved.
//

typedef enum {
    BBPatternTypeDictionary,
    BBPatternTypeL33t,
    BBPatternTypeSpatial,
    BBPatternTypeRepeat,
    BBPatternTypeSequence,
    BBPatternTypeDigits,
    BBPatternTypeYear,
    BBPatternTypeDate,
    BBPatternTypeBruteforce
} BBPatternType;

extern NSString * const BBDictionaryPatternUserInfoKeyMatchedWord;
extern NSString * const BBDictionaryPatternUserInfoKeyRank;
extern NSString * const BBDictionaryPatternUserInfoKeyDictionaryName;
extern NSString * const BBDictionaryPatternUserInfoKeyBaseEntropy;
extern NSString * const BBDictionaryPatternUserInfoKeyUppercaseEntropy;

extern NSString * const BBL33tPatternUserInfoKeySubstitution;
extern NSString * const BBL33tPatternUserInfoKeySubstitutionDisplay;
extern NSString * const BBL33tPatternUserInfoKeyL33tEntropy;

extern NSString * const BBSpatialPatternUserInfoKeyGraph;
extern NSString * const BBSpatialPatternUserInfoKeyTurns;
extern NSString * const BBSpatialPatternUserInfoKeyShiftedCount;

extern NSString * const BBRepeatPatternUserInfoKeyRepeatedChar;

extern NSString * const BBSequencePatternUserInfoKeySequenceName;
extern NSString * const BBSequencePatternUserInfoKeySequenceSpace;
extern NSString * const BBSequencePatternUserInfoKeyAscending;

extern NSString * const BBDatePatternUserInfoKeyMonth;
extern NSString * const BBDatePatternUserInfoKeyDay;
extern NSString * const BBDatePatternUserInfoKeyYear;
extern NSString * const BBDatePatternUserInfoKeySeparator;

extern NSString * const BBBruteforcePatternUserInfoKeyCardinality;

static const double ENTROPY_UNKONWN = -DBL_MAX;

@interface BBPattern : NSObject

@property (nonatomic) BBPatternType type;
@property (nonatomic) NSUInteger begin;
@property (nonatomic) NSUInteger end;
@property (strong, nonatomic) NSString *token;
@property (nonatomic) double entropy;
@property (strong, nonatomic) NSDictionary *userInfo;

@end
