//
//  CGICalendarContentLine.m
//
//  Created by Satoshi Konno on 11/01/28.
//  Copyright 2011 Satoshi Konno. All rights reserved.
//

#import "CGICalendarContentLine.h"

/*
 The following notation defines the lines of content in an iCalendar
 object:
 contentline        = name *(";" param ) ":" value CRLF
 ; This ABNF is just a general definition for an initial parsing
 ; of the content line into its property name, parameter list,
 ; and value string
 ; When parsing a content line, folded lines MUST first
 ; be unfolded according to the unfolding procedure
 ; described above. When generating a content line, lines
 ; longer than 75 octets SHOULD be folded according to
 ; the folding procedure described above.
 name               = x-name / iana-token
 iana-token = 1*(ALPHA / DIGIT / "-")
 ; iCalendar identifier registered with IANA
 x-name             = "X-" [vendorid "-"] 1*(ALPHA / DIGIT / "-")
 ; Reservered for experimental use. Not intended for use in
 ; released products.
 vendorid   = 3*(ALPHA / DIGIT)     ;Vendor identification
 param              = param-name "=" param-value
 *("," param-value)
 ; Each property defines the specific ABNF for the parameters
 ; allowed on the property. Refer to specific properties for
 ; precise parameter ABNF.
 param-name = iana-token / x-token
 param-value        = paramtext / quoted-string
 paramtext  = *SAFE-CHAR
 value      = *VALUE-CHAR
 quoted-string      = DQUOTE *QSAFE-CHAR DQUOTE
 NON-US-ASCII       = %x80-F8
 ; Use restricted by charset parameter
 ; on outer MIME object (UTF-8 preferred)
 QSAFE-CHAR = WSP / %x21 / %x23-7E / NON-US-ASCII
 ; Any character except CTLs and DQUOTE
 SAFE-CHAR  = WSP / %x21 / %x23-2B / %x2D-39 / %x3C-7E
 / NON-US-ASCII
 ; Any character except CTLs, DQUOTE, ";", ":", ","
 VALUE-CHAR = WSP / %x21-7E / NON-US-ASCII
 ; Any textual character
 CR = %x0D
 ; carriage return
 LF = %x0A
 ; line feed
 CRLF       = CR LF
 ; Internet standard newline
 CTL        = %x00-08 / %x0A-1F / %x7F
 ; Controls
 ALPHA      = %x41-5A / %x61-7A   ; A-Z / a-z
 DIGIT      = %x30-39
 ; 0-9
 DQUOTE     = %x22
 ; Quotation Mark
 WSP        = SPACE / HTAB
 SPACE      = %x20
 HTAB       = %x09
 */

NSString * const CGICalendarContentlineTerm = @"\r\n";
NSString * const CGICalendarContentlineFoldingSpace = @" ";
NSString * const CGICalendarContentlineFoldingTab = @"\t";
NSString * const CGICalendarContentlineDelimiter = @":";
NSString * const CGICalendarContentlineNameparamDelimiter = @";";

NSString * const CGICalendarContentlineComponentVcalendar = @"VCALENDAR";
NSString * const CGICalendarContentlineComponentVevent = @"VEVENT";
NSString * const CGICalendarContentlineComponentVjournal = @"VJOURNAL";
NSString * const CGICalendarContentlineComponentVfreebusy = @"VFREEBUSY";
NSString * const CGICalendarContentlineComponentVtimezone = @"VTIMEZONE";

@implementation CGICalendarContentLine

+ (BOOL)IsFoldingLineString:(NSString *)aString {
	if ([aString hasPrefix:CGICalendarContentlineFoldingSpace] || [aString hasPrefix:CGICalendarContentlineFoldingTab])
		return YES;
	return NO;
}

+ (id)contentLineWithString:(NSString *)aString {
	CGICalendarContentLine *icalContentLine = [[CGICalendarContentLine alloc] initWithString:aString];
	return icalContentLine;
}

- (id)initWithString:(NSString *)aString {
	if ((self = [self init])) {
		[self setString:aString];
	}
	return self;
}

- (void)setString:(NSString *)aString {
	NSString *nowNewLineString = [aString stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	NSArray *values = [nowNewLineString componentsSeparatedByString:CGICalendarContentlineDelimiter];
	NSUInteger valuesCount = [values count];
	if (valuesCount < 2) {
		return;
	}
	NSArray *nameParameters = [[values objectAtIndex:0] componentsSeparatedByString:CGICalendarContentlineNameparamDelimiter];
	NSMutableArray *parameters = [NSMutableArray array];
	NSUInteger nameParametersCount = [nameParameters count];
	for (NSUInteger n = 0; n < nameParametersCount; n++) {
		if (n == 0) {
			[self setName:[nameParameters objectAtIndex:0]];
			continue;
		}
		CGICalendarParameter *icalParam = [[CGICalendarParameter alloc] initWithString:[nameParameters objectAtIndex:n]];
		[parameters addObject:icalParam];
	}
	[self setParameters:parameters];

	NSMutableString *valueString = [NSMutableString string];
	for (NSUInteger n = 1; n < valuesCount; n++) {
		if (1 < n) {
			[valueString appendString:CGICalendarContentlineDelimiter];
		}
		[valueString appendString:[values objectAtIndex:n]];
	}
	[self setValue:valueString];
}

- (NSString *)description; {
	NSMutableString *contentLine = [NSMutableString string];
	if ([self hasName]) {
		[contentLine appendString:[self name]];
	}
	for (CGICalendarParameter *param in [self parameters]) {
		[contentLine appendString:CGICalendarContentlineNameparamDelimiter];
		[contentLine appendString:[param string]];
	}
	[contentLine appendString:CGICalendarContentlineDelimiter];
	if ([self hasValue]) {
		[contentLine appendString:[self value]];
	}
	[contentLine appendString:CGICalendarContentlineDelimiter];
	return contentLine;
}

- (BOOL)isBegin {
	return [self isName:CGICalendarContentlineNameBegin];
}

- (BOOL)isEnd {
	return [self isName:CGICalendarContentlineNameEnd];
}

@end
