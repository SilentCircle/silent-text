/*
Copyright (C) 2015, Silent Circle, LLC. All rights reserved.

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
#import "SCDatabaseLoggerColorProfiles.h"
#import "DDLog.h"


#ifndef LOG_CONTEXT_ALL
#define LOG_CONTEXT_ALL INT_MAX
#endif

@interface SCDatabaseLoggerColorProfile : NSObject <NSCopying> {
@public
	
	int mask;
	int context;
	
	OSColor *fgColor;
	OSColor *bgColor;
}

- (instancetype)initWithForegroundColor:(OSColor *)fgColor
                        backgroundColor:(OSColor *)bgColor
                                   mask:(int)mask
                                context:(int)context;

@end

@implementation SCDatabaseLoggerColorProfile

- (instancetype)initWithForegroundColor:(OSColor *)inFgColor
                        backgroundColor:(OSColor *)inBgColor
                                   mask:(int)inMask
                                context:(int)inContext
{
	if ((self = [super init]))
	{
		mask = inMask;
		context = inContext;
		
		fgColor = inFgColor;
		bgColor = inBgColor;
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	// Even though this object is designed to be "immutable",
	// there are technically no protections in place to enforce it.
	// So just to be cautious, we're going to do an actual copy here.
	
	return [[SCDatabaseLoggerColorProfile alloc] initWithForegroundColor:fgColor
	                                                     backgroundColor:bgColor
	                                                                mask:mask
	                                                             context:context];
}

- (NSString *)description
{
	CGFloat fg_r, fg_g, fg_b, fg_a;
	[fgColor getRed:&fg_r green:&fg_g blue:&fg_b alpha:&fg_a];
	
	CGFloat bg_r, bg_g, bg_b, bg_a;
	[bgColor getRed:&bg_r green:&bg_g blue:&bg_b alpha:&bg_a];
	
	return [NSString stringWithFormat:
	    @"<SCDatabaseLoggerColorProfile: %p mask:%i ctxt:%i fg:%.0f,%.0f,%.0f,%.0f bg:%.0f,%.0f,%.0f,%.0f>",
	        self, mask, context, fg_r, fg_g, fg_b, fg_a, bg_r, bg_g, bg_b, bg_a];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation SCDatabaseLoggerColorProfiles {
@private
	
	NSMutableArray *colorProfilesArray;
	NSMutableDictionary *colorProfilesDict;
}

- (instancetype)init
{
	if ((self = [super init]))
	{
		colorProfilesArray = [[NSMutableArray alloc] init];
		colorProfilesDict = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	SCDatabaseLoggerColorProfiles *copy = [[SCDatabaseLoggerColorProfiles alloc] init];
	
	copy->colorProfilesArray = [[NSMutableArray alloc] initWithArray:self->colorProfilesArray copyItems:YES];
	copy->colorProfilesDict = [[NSMutableDictionary alloc] initWithDictionary:self->colorProfilesDict copyItems:YES];
	
	return copy;
}

- (void)setForegroundColor:(OSColor *)txtColor backgroundColor:(OSColor *)bgColor forFlag:(int)mask
{
	[self setForegroundColor:txtColor backgroundColor:bgColor forFlag:mask context:LOG_CONTEXT_ALL];
}

- (void)setForegroundColor:(OSColor *)txtColor backgroundColor:(OSColor *)bgColor forFlag:(int)mask context:(int)ctxt
{
	SCDatabaseLoggerColorProfile *newColorProfile =
	  [[SCDatabaseLoggerColorProfile alloc] initWithForegroundColor:txtColor
	                                                backgroundColor:bgColor
	                                                           mask:mask
	                                                        context:ctxt];
	
	NSUInteger i = 0;
	for (SCDatabaseLoggerColorProfile *colorProfile in colorProfilesArray)
	{
		if ((colorProfile->mask == mask) && (colorProfile->context == ctxt))
		{
			break;
		}
		
		i++;
	}
	
	if (i < [colorProfilesArray count])
		[colorProfilesArray replaceObjectAtIndex:i withObject:newColorProfile];
	else
		[colorProfilesArray addObject:newColorProfile];
}

- (void)setForegroundColor:(OSColor *)txtColor backgroundColor:(OSColor *)bgColor forTag:(id <NSCopying>)tag
{
	SCDatabaseLoggerColorProfile *newColorProfile =
	  [[SCDatabaseLoggerColorProfile alloc] initWithForegroundColor:txtColor
	                                                backgroundColor:bgColor
	                                                           mask:0
	                                                        context:0];
	
	[colorProfilesDict setObject:newColorProfile forKey:tag];
}

- (void)clearColorsForFlag:(int)mask
{
	[self clearColorsForFlag:mask context:0];
}

- (void)clearColorsForFlag:(int)mask context:(int)context
{
	NSUInteger i = 0;
	for (SCDatabaseLoggerColorProfile *colorProfile in colorProfilesArray)
	{
		if ((colorProfile->mask == mask) && (colorProfile->context == context))
		{
			break;
		}
		
		i++;
	}
	
	if (i < [colorProfilesArray count])
	{
		[colorProfilesArray removeObjectAtIndex:i];
	}
}

- (void)clearColorsForTag:(id <NSCopying>)tag
{
	[colorProfilesDict removeObjectForKey:tag];
}

- (void)clearColorsForAllFlags
{
	[colorProfilesArray removeAllObjects];
}

- (void)clearColorsForAllTags
{
	[colorProfilesDict removeAllObjects];
}

- (void)clearAllColors
{
	[colorProfilesArray removeAllObjects];
	[colorProfilesDict removeAllObjects];
}

- (void)getForegroundColor:(OSColor **)fgColorPtr
           backgroundColor:(OSColor **)bgColorPtr
                   forFlag:(int)mask
                   context:(int)context
                       tag:(id)tag
{
	SCDatabaseLoggerColorProfile *colorProfile = nil;
	
	if (tag)
	{
		colorProfile = [colorProfilesDict objectForKey:tag];
	}
	if (colorProfile == nil)
	{
		for (SCDatabaseLoggerColorProfile *cp in colorProfilesArray)
		{
			if (mask & cp->mask)
			{
				// Color profile set for this context?
				if (context == cp->context)
				{
					colorProfile = cp;
					
					// Stop searching
					break;
				}
				
				// Check if LOG_CONTEXT_ALL was specified as a default color for this flag
				if (cp->context == LOG_CONTEXT_ALL)
				{
					colorProfile = cp;
					
					// We don't break to keep searching for more specific color profiles for the context
				}
			}
		}
	}
	
	if (fgColorPtr) *fgColorPtr = colorProfile ? colorProfile->fgColor : nil;
	if (bgColorPtr) *bgColorPtr = colorProfile ? colorProfile->bgColor : nil;
}

@end
