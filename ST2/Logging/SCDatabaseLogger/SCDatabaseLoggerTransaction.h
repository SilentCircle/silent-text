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
#import <Foundation/Foundation.h>
#import "SCDatabaseLogEntry.h"


@interface SCDatabaseLoggerTransaction : NSObject

/**
 * When a transaction is started, it is either fast-forwarded, or not.
 * You cannot change a transaction once started.
 * 
 * @see SCDatabaseLoggerConnection usesFastForwarding
**/
@property (nonatomic, readonly) BOOL isFastForwarded;

/**
 * Returns the number of available log entries.
**/
- (NSUInteger)numberOfLogEntries;

/**
 * Returns the range of all log entries such that:
 * startDate <= logEntry.timestamp <= endDate
 * 
 * If you want to find all log entries before a particular time, then pass nil as the startDate.
 * If you want to find all log entries after a particular time, then pass nil as the endDate.
 * 
 * @return
 *     If there were no matching logEntries found, returns a range with range.length == 0.
 *     Otherwise, returns a valid range.
**/
- (NSRange)rangeOfLogEntriesWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate;

/**
 * Returns an array of IDs (opaque objects of type NSNumber and/or NSUUID),
 * which can be used to fetch the corresponding SCDatabaseLogEntry objects via the logEntryForID method.
 * 
 * The results are sorted by timestamp, oldest to newest.
 * So the oldest log message is at index 0, and the newest (most recent) is at the end of the array.
**/
- (NSArray *)allLogEntryIDs;

/**
 * Returns an array of IDs (opaque objects of type NSNumber and/or NSUUID),
 * which can be used to fetch the corresponding SCDatabaseLogEntry objects via the logEntryForID method.
 * 
 * The results are sorted by timestamp, oldest to newest.
 * So the oldest log message is at index 0, and the newest (most recent) is at the end of the array.
 *
 * @param limit
 *   The maximum number of results to return.
 * 
 * @param offset
 *   The offset to use for the query.
 * 
 * For example:
 * - If there are 10 log messages, and you want the most recent 5: limit=5, offset=5
 * - If there are 10 log messages, and you want the oldest 3: limit=3, offset=0
**/
- (NSArray *)logEntryIDsWithLimit:(NSUInteger)limit offset:(NSUInteger)offset;

/**
 * Returns the full LogEntry object for the given rowid.
 * 
 * Makes use of the built-in cache for super-fast access (helpful for scrolling).
**/
- (SCDatabaseLogEntry *)logEntryForID:(id)logEntryID;

/**
 * Enumerates all the log entries available to the transaction.
 * 
 * The log entries are enumerated by timestamp, oldest to newest.
 * So the oldest log message is first, and the newest (most recent) is last.
**/
- (void)enumerateLogEntriesWithBlock:(void (^)(id logEntryID, SCDatabaseLogEntry *logEntry, BOOL *stop))block;

/**
 * Enumerates a subset of the log entries available to the transaction.
 * 
 * The log entries are enumerated by timestamp, oldest to newest.
 * So the oldest log message is first, and the newest (most recent) is last.
 * 
 * @param limit
 *   The maximum number of results to return.
 *
 * @param offset
 *   The offset to use for the query.
 *
 * For example:
 * - If there are 10 log messages, and you want the most recent 5: limit=5, offset=5
 * - If there are 10 log messages, and you want the oldest 3: limit=3, offset=0
**/
- (void)enumerateLogEntriesWithLimit:(NSUInteger)limit
                              offset:(NSUInteger)offset
                               block:(void (^)(id logEntryID, SCDatabaseLogEntry *logEntry, BOOL *stop))block;

@end
