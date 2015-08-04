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
#import "DDLog.h"
#import "LumberjackUser.h"

/**
 * Add this to the top of your implementation file:
 * 
 * // LEVELS: off, error, warn, info, verbose; FLAGS: trace
 * #if DEBUG
 *   static const int ddLogLevel = LOG_LEVEL_VERBOSE;
 * #else
 *   static const int ddLogLevel = LOG_LEVEL_WARN;
 * #endif
 * 
 * If you want per-user log levels, then use your name as it appears in LumberjackUser.h (post compile):
 * 
 * // LEVELS: off, error, warn, info, verbose; FLAGS: trace
 * #if DEBUG && robbie_hanson
 *   static const int ddLogLevel = LOG_LEVEL_VERBOSE;
 * #elif DEBUG
 *   static const int ddLogLevel = LOG_LEVEL_INFO;
 * #else
 *   static const int ddLogLevel = LOG_LEVEL_WARN;
 * #endif
 * 
 *
**/

// Undefine standard options

#undef LOG_ASYNC_ENABLED

#undef LOG_ASYNC_ERROR
#undef LOG_ASYNC_WARN
#undef LOG_ASYNC_INFO
#undef LOG_ASYNC_VERBOSE

#undef DDLogError
#undef DDLogWarn
#undef DDLogInfo
#undef DDLogVerbose

#undef DDLogCError
#undef DDLogCWarn
#undef DDLogCInfo
#undef DDLogCVerbose

// Redefine standard options.
// We want to customize the asynchronous logging configuration.

#ifdef DEBUG
  #define LOG_ASYNC_ENABLED  NO // Change me to YES after all log statements have switched to use Lumberjack
#else
  #define LOG_ASYNC_ENABLED  NO // Change me to YES after all log statements have switched to use Lumberjack
#endif

#define LOG_ASYNC_ERROR      ( NO && LOG_ASYNC_ENABLED)
#define LOG_ASYNC_WARN       (YES && LOG_ASYNC_ENABLED)
#define LOG_ASYNC_INFO       (YES && LOG_ASYNC_ENABLED)
#define LOG_ASYNC_VERBOSE    (YES && LOG_ASYNC_ENABLED)

#define DDLogError(frmt, ...)   LOG_OBJC_MAYBE(LOG_ASYNC_ERROR,   ddLogLevel, LOG_FLAG_ERROR,   0, frmt, ##__VA_ARGS__)
#define DDLogWarn(frmt, ...)    LOG_OBJC_MAYBE(LOG_ASYNC_WARN,    ddLogLevel, LOG_FLAG_WARN,    0, frmt, ##__VA_ARGS__)
#define DDLogInfo(frmt, ...)    LOG_OBJC_MAYBE(LOG_ASYNC_INFO,    ddLogLevel, LOG_FLAG_INFO,    0, frmt, ##__VA_ARGS__)
#define DDLogVerbose(frmt, ...) LOG_OBJC_MAYBE(LOG_ASYNC_VERBOSE, ddLogLevel, LOG_FLAG_VERBOSE, 0, frmt, ##__VA_ARGS__)

#define DDLogCError(frmt, ...)   LOG_C_MAYBE(LOG_ASYNC_ERROR,   ddLogLevel, LOG_FLAG_ERROR,   0, frmt, ##__VA_ARGS__)
#define DDLogCWarn(frmt, ...)    LOG_C_MAYBE(LOG_ASYNC_WARN,    ddLogLevel, LOG_FLAG_WARN,    0, frmt, ##__VA_ARGS__)
#define DDLogCInfo(frmt, ...)    LOG_C_MAYBE(LOG_ASYNC_INFO,    ddLogLevel, LOG_FLAG_INFO,    0, frmt, ##__VA_ARGS__)
#define DDLogCVerbose(frmt, ...) LOG_C_MAYBE(LOG_ASYNC_VERBOSE, ddLogLevel, LOG_FLAG_VERBOSE, 0, frmt, ##__VA_ARGS__)

// Fine grained logging.
// The first 4 bits are being used by the standard log levels (0 - 3)

#define LOG_FLAG_TRACE  (1 << 4)
#define LOG_FLAG_COLOR  (1 << 5)

// NSLog color replacements.
// 
// The log statements below are straight NSLog replacements, and are NOT affected by the file's log level.
// In other words, they're exactly like NSLog, but they print in color.
// 
// They are handy for quick debugging sessions,
// but please don't leave them in your code, or commit them to the repository.

static NSString *const BlackTag     = @"Black";
static NSString *const WhiteTag     = @"White";
static NSString *const GrayTag      = @"Gray";
static NSString *const DarkGrayTag  = @"DarkGray";
static NSString *const LightGrayTag = @"LightGray";
static NSString *const RedTag       = @"Red";
static NSString *const GreenTag     = @"Green";
static NSString *const BlueTag      = @"Blue";
static NSString *const CyanTag      = @"Cyan";
static NSString *const MagentaTag   = @"Magenta";
static NSString *const YellowTag    = @"Yellow";
static NSString *const OrangeTag    = @"Orange";
static NSString *const PurpleTag    = @"Purple";
static NSString *const BrownTag     = @"Brown";
static NSString *const PinkTag      = @"Pink";

#define DDLogBlack(frmt, ...)     LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, BlackTag,     frmt, ##__VA_ARGS__)
#define DDLogWhite(frmt, ...)     LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, WhiteTag,     frmt, ##__VA_ARGS__)
#define DDLogGray(frmt, ...)      LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, GrayTag,      frmt, ##__VA_ARGS__)
#define DDLogDarkGray(frmt, ...)  LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, DarkGrayTag,  frmt, ##__VA_ARGS__)
#define DDLogLightGray(frmt, ...) LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, LightGrayTag, frmt, ##__VA_ARGS__)
#define DDLogRed(frmt, ...)       LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, RedTag,       frmt, ##__VA_ARGS__)
#define DDLogGreen(frmt, ...)     LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, GreenTag,     frmt, ##__VA_ARGS__)
#define DDLogBlue(frmt, ...)      LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, BlueTag,      frmt, ##__VA_ARGS__)
#define DDLogCyan(frmt, ...)      LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, CyanTag,      frmt, ##__VA_ARGS__)
#define DDLogMagenta(frmt, ...)   LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, MagentaTag,   frmt, ##__VA_ARGS__)
#define DDLogYellow(frmt, ...)    LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, YellowTag,    frmt, ##__VA_ARGS__)
#define DDLogOrange(frmt, ...)    LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, OrangeTag,    frmt, ##__VA_ARGS__)
#define DDLogPurple(frmt, ...)    LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, PurpleTag,    frmt, ##__VA_ARGS__)
#define DDLogBrown(frmt, ...)     LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, BrownTag,     frmt, ##__VA_ARGS__)
#define DDLogPink(frmt, ...)      LOG_OBJC_TAG_MACRO(NO, 0, LOG_FLAG_COLOR, 0, PinkTag,      frmt, ##__VA_ARGS__)

// Trace - Used to trace program execution. Generally placed at the top of methods.
//         Very handy for tracking down bugs like "why isn't this code executing..." or "is this method getting hit"
//
// DDLogAutoTrace() - Prints "[Method Name]"
// DDLogTrace()     - Prints whatever you put. Generally used to print arg values.

#define LOG_TRACE       (ddLogLevel & LOG_FLAG_TRACE)

#define LOG_ASYNC_TRACE (YES && LOG_ASYNC_ENABLED)

#define DDLogAutoTrace()   LOG_OBJC_MAYBE(LOG_ASYNC_TRACE, ddLogLevel, LOG_FLAG_TRACE, 0, @"%@", THIS_METHOD)
#define DDLogAutoCTrace()     LOG_C_MAYBE(LOG_ASYNC_TRACE, ddLogLevel, LOG_FLAG_TRACE, 0, @"%@",  __FUNCTION__)

#define DDLogTrace(frmt, ...)  LOG_OBJC_MAYBE(LOG_ASYNC_TRACE, ddLogLevel, LOG_FLAG_TRACE, 0, frmt, ##__VA_ARGS__)
#define DDLogCTrace(frmt, ...)    LOG_C_MAYBE(LOG_ASYNC_TRACE, ddLogLevel, LOG_FLAG_TRACE, 0, frmt, ##__VA_ARGS__)
