/*
Copyright (C) 2013-2015, Silent Circle, LLC. All rights reserved.

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
//  STSRVRecord.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 11/22/13.
//

#import "STSRVRecord.h"
#import "AppConstants.h"

/**
 * Keys for encoding / decoding (to avoid typos)
**/
static NSString *const k_version   = @"version";
static NSString *const k_srvName   = @"srvName";
static NSString *const k_srvArray  = @"srvArray";
static NSString *const k_timeStamp = @"timeStamp";


@implementation STSRVRecord

@synthesize srvName = srvName;
@synthesize srvArray =  srvArray;
@synthesize timeStamp = timeStamp;

- (id)initWithSRVName:(NSString*)inSrvName
             srvArray:(NSArray*)inSrvArray
{
	if ((self = [super init]))
	{
        srvName     = [inSrvName copy];
        srvArray    = [inSrvArray copy];
        timeStamp   = [NSDate date];
    }
	return self;
}


#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		int32_t version = [decoder decodeInt32ForKey:k_version];
		
        if (version == 3)
		{
			srvName        = [decoder decodeObjectForKey:k_srvName];
			srvArray       = [decoder decodeObjectForKey:k_srvArray];
			timeStamp      = [decoder decodeObjectForKey:k_timeStamp];
  		}
        else
        {
			srvName        = [decoder decodeObjectForKey:k_srvName];
  			srvArray       = @[]; // empty
            // older versions used expireDate.. those are gone now.
            timeStamp       = [NSDate distantPast];
        }
 	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt32:3          forKey:k_version];
	[coder encodeObject:srvName   forKey:k_srvName];
	[coder encodeObject:srvArray  forKey:k_srvArray];
	[coder encodeObject:timeStamp forKey:k_timeStamp];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Convenience Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSDate *)expireDate
{
    return [timeStamp dateByAddingTimeInterval:kDefaultSRVRecordLifespan];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	STSRVRecord *copy = [super copyWithZone:zone];
    copy->srvName = srvName;
	copy->srvArray = srvArray;
    copy->timeStamp = [NSDate date];
	
 	return copy;
}

@end
