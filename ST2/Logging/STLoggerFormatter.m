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
#import "STLoggerFormatter.h"

#import <unistd.h>
#import <sys/uio.h>
#import <libkern/OSAtomic.h>

/**
 * This class is a log-message-formatter for use with the Lumberjack logging framework.
 *
 * It automatically prepends the filename to all log messages.
 * For example:
 *
 * DDLogVerbose(@"Invalid thingy"); => prints "AppDelegate: Invalid thingy"
**/
@implementation STLoggerFormatter
{
	NSCalendar *calendar;
	NSUInteger calendarUnitFlags;
	
	NSString *appName;
	int processID;
	
	int32_t atomicLoggerCount;
}

- (instancetype)init
{
	return [self initWithTimestamp:YES];
}

- (instancetype)initWithTimestamp:(BOOL)includeTimestamp
{
	if ((self = [super init]))
	{
		if (includeTimestamp)
		{
			calendar = [NSCalendar autoupdatingCurrentCalendar];
			
			calendarUnitFlags = 0;
			calendarUnitFlags |= NSCalendarUnitHour;
			calendarUnitFlags |= NSCalendarUnitMinute;
			calendarUnitFlags |= NSCalendarUnitSecond;
		}
		
		appName = [[NSProcessInfo processInfo] processName];
		processID = getpid();
    }
	return self;
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
	// Format: HH:mm:ss:SSS
	// Space : 123456789_123 (don't forget trailing \n)
	//
	char timestamp[13];
	
	if (calendar)
	{
		// Calculate timestamp.
		// The technique below is faster than using NSDateFormatter.
		
		NSDateComponents *components = [calendar components:calendarUnitFlags fromDate:logMessage->timestamp];
		
		NSTimeInterval epoch = [logMessage->timestamp timeIntervalSinceReferenceDate];
		int milliseconds = (int)((epoch - floor(epoch)) * 1000);
		
		snprintf(timestamp, 13, "%02ld:%02ld:%02ld:%03d", // HH:mm:ss:SSS
		         (long)components.hour,
		         (long)components.minute,
		         (long)components.second, milliseconds);
	}
	
	// Generate formatted log message
	
	if (logMessage->logContext == 0)
	{
		// Automatically prefix filename to log message.
		
		if (calendar)
		{
			return [NSString stringWithFormat:@"%s [%x] %@: %@",
					timestamp, logMessage->machThreadID, [logMessage fileName], logMessage->logMsg];
		}
		else
		{
			return [NSString stringWithFormat:@"[%x] %@: %@",
					logMessage->machThreadID, [logMessage fileName], logMessage->logMsg];
		}
	}
	else
	{
		// Log message coming from external framework (such as XMPP, YapDatabase, etc).
		// These frameworks typically already include filename, so we don't have to add it ourself.
		
		if (calendar)
		{
			return [NSString stringWithFormat:@"%s [%x] %@",
					timestamp, logMessage->machThreadID, logMessage->logMsg];
		}
		else
		{
			return [NSString stringWithFormat:@"[%x] %@",
					logMessage->machThreadID, logMessage->logMsg];
		}
	}
}

- (void)didAddToLogger:(id <DDLogger>)logger
{
	int32_t loggerCount = OSAtomicIncrement32(&atomicLoggerCount);
	if (loggerCount > 1)
	{
		NSString *reason =
		  @"A STLoggerFormatter may only be used with a single logger at a time."
		  @" If you wish to use the STLoggerFormatter class with multiple loggers,"
		  @" then you must create multiple STLoggerFormatter instances."
		  @" (This is due to internal optimizations around timestamp formatting, which aren't thread-safe.)";
		
		@throw [NSException exceptionWithName:@"STLoggerFormatter" reason:reason userInfo:nil];
	}
}

@end
