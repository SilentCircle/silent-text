/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
//
//  BurnDelays.m
//  ST2
//
//  Created by mahboud on 3/5/14.
//

#import "BurnDelays.h"
@interface BurnDelays ()
@property (nonatomic, strong) NSDictionary *burnDelayDict;
@end

@implementation BurnDelays
@synthesize burnDelayDict;
@synthesize values = burnDelays;

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)initializeBurnDelaysWithOff:(BOOL) addOff
{
	NSMutableDictionary *dict = @{
                       @(0) : NSLocalizedString(@"Off",@"Off"),
                       @(1 * 60) : NSLocalizedString(@"1 Minute",@"1 Minute"),
					   //                     @(3 * 60) : NSLocalizedString(@"3 Minutes",@"3 Minutes"),
                       @(5 * 60) : NSLocalizedString(@"5 Minutes",@"5 Minutes"),
                       @(10 * 60) : NSLocalizedString(@"10 Minutes",@"10 Minutes"),
                       @(15 * 60) : NSLocalizedString(@"15 Minutes",@"15 Minutes"),
                       @(30 * 60) : NSLocalizedString(@"30 Minutes",@"30 Minutes"),
                       @(1 * 60 * 60) : NSLocalizedString(@"1 Hour",@"1 Hour"),
                       @(3 * 60 * 60) : NSLocalizedString(@"3 Hours",@"3 Hours"),
                       @(6 * 60 * 60) : NSLocalizedString(@"6 Hours",@"6 Hours"),
                       @(12 * 60 * 60) : NSLocalizedString(@"12 Hours",@"12 Hours"),
                       @(24 * 60 * 60) : NSLocalizedString(@"1 Day",@"1 Day"),
                       @(48 * 60 * 60) : NSLocalizedString(@"2 Days",@"2 Days"),
                       @(72 * 60 * 60) : NSLocalizedString(@"3 Days",@"3 Days"),
                       @(120 * 60 * 60) : NSLocalizedString(@"5 Days",@"5 Days"),
                       @(7 * 24 * 60 * 60) : NSLocalizedString(@"1 Week",@"1 Week"),
                       @(14 * 24 * 60 * 60) : NSLocalizedString(@"2 Weeks",@"2 Weeks"),
					   //                     @(15 * 24 * 60 * 60) : NSLocalizedString(@"15 Days",@"15 Days"),
					   @(28 * 24 * 60 * 60) : NSLocalizedString(@"4 Weeks",@"4 Weeks"),
					   //                     @(31 * 24 * 60 * 60) : NSLocalizedString(@"1 Month",@"1 Month"),
                       @(45 * 24 * 60 * 60) : NSLocalizedString(@"45 Days",@"45 Days"),
                       @(90 * 24 * 60 * 60) : NSLocalizedString(@"90 Days",@"90 Days"),
                       @(180 * 24 * 60 * 60) : NSLocalizedString(@"180 Days",@"180 Days"),
                       @(365 * 24 * 60 * 60) : NSLocalizedString(@"1 Year",@"1 Year"),
                       }.mutableCopy;
	if (!addOff)
		[dict removeObjectForKey:@(0)];
    
    burnDelayDict = [NSDictionary dictionaryWithDictionary:dict];
	burnDelays = [self makeSortedKeyList];
}



- (NSArray *) makeSortedKeyList
{
	return [[burnDelayDict allKeys] sortedArrayUsingComparator: ^(id obj1, id obj2) {
		
		if ([obj1 integerValue] > [obj2 integerValue]) {
			return (NSComparisonResult)NSOrderedDescending;
		}
		
		if ([obj1 integerValue] < [obj2 integerValue]) {
			return (NSComparisonResult)NSOrderedAscending;
		}
		return (NSComparisonResult)NSOrderedSame;
	}];
    
}
/**
 * Given an interval (possibly from an outside source, or a different app version),
 * returns an index for a "matching" interval from the current list of burn intervals.
 *
 * If no exact match is found, then returns the closest interval that is less than the given interval (if possible).
 **/

- (NSUInteger)indexForDelay:(NSUInteger)inDelay
{
	for (NSUInteger i = [burnDelays count]; i > 0; i--)
	{
		int delay = [[burnDelays objectAtIndex:(i-1)] intValue];
		
		if (delay <= inDelay)
		{
			return (i-1);
		}
	}
	
	return 0;
}
- (NSString *)stringForDelay:(NSUInteger)inDelay
{
	return [self stringForDelayIndex:[self indexForDelay:inDelay]];
}
- (NSString *)stringForDelayIndex:(NSUInteger)index
{
	return [burnDelayDict objectForKey: [burnDelays objectAtIndex:index]];
}

- (NSUInteger) delayInUIntForIndex:(NSUInteger) index
{
	return [[burnDelays objectAtIndex:index] unsignedIntValue];
}
@end
