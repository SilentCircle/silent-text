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
#import "SCDatabaseLogEntry.h"
#import "SCDatabaseLoggerPrivate.h"


@implementation SCDatabaseLogEntry {
	
// From SCDatabaseLoggerPrivate.h:
/*
@public
	NSDate *timestamp;
	
	int context;
	int flags;
	NSString *tag;
	NSString *message;
*/
}

@synthesize timestamp = timestamp;

@synthesize context = context;
@synthesize flags = flags;
@synthesize tag = tag;
@synthesize message = message;

- (instancetype)initWithLogMessage:(DDLogMessage *)logMessage formattedMessage:(NSString *)formattedMessage
{
	if ((self = [super init]))
	{
		// DDLogMessage ivars:
		//
		// - int logLevel;
		// - int logFlag;
		// - int logContext;
		// - NSString *logMsg;
		// - NSDate *timestamp;
		// - char *file;
		// - char *function;
		// - int lineNumber;
		// - mach_port_t machThreadID;
		// - char *queueLabel;
		// - NSString *threadName;
		//
		// For 3rd party extensions to the framework, where flags and contexts aren't enough.
		// - id tag;
		//
		// For 3rd party extensions that manually create DDLogMessage instances.
		// - DDLogMessageOptions options;
		
		timestamp = logMessage->timestamp;
		context   = logMessage->logContext;
		flags     = logMessage->logFlag;
		
		if ([logMessage->tag isKindOfClass:[NSString class]])
		{
			tag = (NSString *)logMessage->tag;
		}
		
		message = formattedMessage ?: logMessage->logMsg;
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<SCDatabaseLogEntry: timestamp(%@) message(%@)>", timestamp, message];
}

@end
