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
#import "SCDatabaseLoggerTransaction.h"
#import "SCDatabaseLoggerPrivate.h"
#import "SCDatabaseLoggerString.h"

// We can't use DDLog() statements within the DDLog implementation.
// But we still want to leave our log statements for any future debugging,
// and to allow other developers to trace the implementation (which is a great learning tool).
//
// So we use primitive logging macros around NSLog.
// We maintain the NS prefix on the macros to be explicit about the fact that we're using NSLog.

#if robbie_hanson
  #define LOG_LEVEL 2
#else
  #define LOG_LEVEL 2
#endif
#define NSLogError(frmt, ...)    do{ if(LOG_LEVEL >= 1) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(LOG_LEVEL >= 2) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(LOG_LEVEL >= 3) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(LOG_LEVEL >= 4) NSLog((frmt), ##__VA_ARGS__); } while(0)


@implementation SCDatabaseLoggerTransaction

@synthesize isFastForwarded = isFastForwarded;

- (instancetype)initWithConnection:(SCDatabaseLoggerConnection *)inConnection isFastForwarded:(BOOL)inIsFastForwarded
{
	if ((self = [super init]))
	{
		connection = inConnection;
		isFastForwarded = inIsFastForwarded;
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Transaction States
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)beginTransaction
{
	NSAssert(connection->db != NULL, @"Improper method call");
	
	sqlite3_stmt *statement = [connection beginTransactionStatement];
	if (statement == NULL) return;
	
	// BEGIN TRANSACTION;
	
	int status = sqlite3_step(statement);
	if (status != SQLITE_DONE)
	{
		NSLogError(@"Couldn't begin transaction: %d %s", status, sqlite3_errmsg(connection->db));
	}
	
	sqlite3_reset(statement);
}

- (void)commitTransaction
{
	NSAssert(connection->db != NULL, @"Improper method call");
	
	sqlite3_stmt *statement = [connection commitTransactionStatement];
	if (statement == NULL) return;
	
	// COMMIT TRANSACTION;
	
	int status = sqlite3_step(statement);
	if (status != SQLITE_DONE)
	{
		NSLogError(@"Couldn't commit transaction: %d %s", status, sqlite3_errmsg(connection->db));
	}
	
	sqlite3_reset(statement);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Database Helpers
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Private API.
 * Returns just what we see in sqlite (excluding any fast-forwarding stuff).
**/
- (NSUInteger)_numberOfLogEntriesInDatabase
{
	if (connection->db == NULL) return 0;
	
	sqlite3_stmt *statement = [connection getLogEntryCountStatement];
	if (statement == NULL) {
		return 0;
	}
	
	NSUInteger count = 0;
	
	// SELECT COUNT(*) AS NumberOfRows FROM "logs";
	
	int status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		count = (NSUInteger)sqlite3_column_int64(statement, SQLITE_COLUMN_START);
	}
	else if (status == SQLITE_ERROR)
	{
		NSLogError(@"Error executing 'getLogEntryCountStatement': %d %s",
				   status, sqlite3_errmsg(connection->db));
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	
	return count;
}

/**
 * Private API.
 * Returns just what we see in sqlite (excluding any fast-forwarding stuff).
**/
- (NSUInteger)_numberOfLogEntriesInDatabaseGreaterThanOrEqual:(NSDate *)startDate
{
	NSParameterAssert(startDate != nil);
	
	if (connection->db == NULL) return 0;
	
	sqlite3_stmt *statement = [connection getLogEntryHighRangeStatement];
	if (statement == NULL) {
		return 0;
	}
	
	NSUInteger count = 0;
	
	// SELECT COUNT(*) AS NumberOfRows FROM "logs"
	//   WHERE "timestamp" >= ?
	//   ORDER BY "timestamp" ASC;
	
	NSTimeInterval interval = [startDate timeIntervalSinceReferenceDate];
	sqlite3_bind_double(statement, SQLITE_BIND_START, interval);
	
	int status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		count = (NSUInteger)sqlite3_column_int64(statement, 0);
	}
	else if (status == SQLITE_ERROR)
	{
		NSLogError(@"Error executing 'getLogEntryLowRangeStatement': %d %s",
				   status, sqlite3_errmsg(connection->db));
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	
	return count;
}

/**
 * Private API.
 * Returns just what we see in sqlite (excluding any fast-forwarding stuff).
**/
- (NSUInteger)_numberOfLogEntriesInDatabaseLessThanOrEqual:(NSDate *)endDate
{
	NSParameterAssert(endDate != nil);
	
	if (connection->db == NULL) return 0;
	
	sqlite3_stmt *statement = [connection getLogEntryLowRangeStatement];
	if (statement == NULL) {
		return 0;
	}
	
	NSUInteger count = 0;
	
	// SELECT COUNT(*) AS NumberOfRows FROM "logs"
	//   WHERE "timestamp" <= ?
	//   ORDER BY "timestamp" ASC;
	
	NSTimeInterval interval = [endDate timeIntervalSinceReferenceDate];
	sqlite3_bind_double(statement, SQLITE_BIND_START, interval);
	
	int status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		count = (NSUInteger)sqlite3_column_int64(statement, 0);
	}
	else if (status == SQLITE_ERROR)
	{
		NSLogError(@"Error executing 'getLogEntryLowRangeStatement': %d %s",
				   status, sqlite3_errmsg(connection->db));
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
	
	return count;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark ReadTransaction
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the number of available log entries.
**/
- (NSUInteger)numberOfLogEntries
{
	NSUInteger baseCount = [self _numberOfLogEntriesInDatabase];
	
	NSUInteger deletedOffset  = connection->fastforward_deletedRowids.count;
	NSUInteger insertedOffset = connection->fastforward_insertedLogEntries.count
	                          + connection->pending_insertedLogEntries.count;
	
	return baseCount - deletedOffset + insertedOffset;
}

/**
 * Private API
 *
 * Returns the range of all log entries such that:
 * logEntry.timestamp >= startDate
**/
- (NSRange)_rangeOfLogEntriesWithStartDate:(NSDate *)startDate  fullDbCount:(NSUInteger)fullDbCount
{
	// Start with what we have in memory.
	// We may be able to skip the db query (which would save us disk IO).
	//
	// Work backwards, scanning from the newest entry toward the oldest entry until
	// we find a logEntry.timestamp that's before the startDate (older than the startDate).
	//
	// If we discover such a logEntry (in memory), then we know that all logEntries after it
	// can be included in the result range.
	//
	// If we can't find such a logEntry in memory, then we can just query the database.
	
	__block BOOL found = NO;
	__block NSUInteger foundIndex = 0;
	
	[connection->pending_insertedUUIDs enumerateObjectsWithOptions:NSEnumerationReverse
	                                                    usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
	{
		SCDatabaseLogEntry *logEntry = [connection->pending_insertedLogEntries objectForKey:obj];
		if ([logEntry.timestamp compare:startDate] == NSOrderedAscending)
		{
			found = YES;
			foundIndex = idx;
			*stop = YES;
		}
	}];
	
	if (found)
	{
		return (NSRange){
			.location = fullDbCount
			          - connection->fastforward_deletedRowids.count
			          + connection->fastforward_insertedLogEntries.count
			          + (foundIndex + 1), // from connection->pending_insertedUUIDs
			.length = connection->pending_insertedUUIDs.count - (foundIndex + 1)
		};
	}
	
	[connection->fastforward_insertedRowids enumerateObjectsWithOptions:NSEnumerationReverse
	                                                         usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
	{
		SCDatabaseLogEntry *logEntry = [connection->fastforward_insertedLogEntries objectForKey:obj];
		if ([logEntry.timestamp compare:startDate] == NSOrderedAscending)
		{
			found = YES;
			foundIndex = idx;
			*stop = YES;
		}
	}];
	
	if (found)
	{
		return (NSRange){
			.location = fullDbCount
			          - connection->fastforward_deletedRowids.count
			          + (foundIndex + 1), // from connection->fastforward_insertedRowids
			.length = connection->fastforward_insertedRowids.count - (foundIndex + 1)
		};
	}
	
	NSUInteger matchDbCount = [self _numberOfLogEntriesInDatabaseGreaterThanOrEqual:startDate];
	//
	// matchDbCount represents "high range" of items in the database:
	//
	// | x | x | x | x | x | x | x | x |
	//                     ^^^^^^^^^^^^^
	
	if (matchDbCount == 0)
	{
		// Only those in memory are included in the range
		return (NSRange){
			.location = fullDbCount - connection->fastforward_deletedRowids.count,
			.length = connection->fastforward_insertedRowids.count
			        + connection->pending_insertedUUIDs.count
		};
	}
	
	NSRange match_dbRange = (NSRange){
		.location = fullDbCount - matchDbCount,
		.length = matchDbCount
	};
	
	NSRange deleted_dbRange = (NSRange){
		.location = 0,
		.length = connection->fastforward_deletedRowids.count
	};
	
	NSRange excludeRange = NSIntersectionRange(match_dbRange, deleted_dbRange);
	if (excludeRange.length > 0) {
		matchDbCount -= excludeRange.length;
	}
	
	return (NSRange){
		.location = fullDbCount
		          - matchDbCount
		          - connection->fastforward_deletedRowids.count,
		.length = matchDbCount
		        + connection->fastforward_insertedRowids.count
		        + connection->pending_insertedUUIDs.count
	};
}

/**
 * Private API
 *
 * Returns the range of all log entries such that:
 * logEntry.timestamp <= endDate
**/
- (NSRange)_rangeOfLogEntriesWithEndDate:(NSDate *)endDate fullDbCount:(NSUInteger)fullDbCount
{
	// Start with what we have in memory.
	// We may be able to skip the db query (which would save us disk IO).
	//
	// Work backwards, scanning from the newest entry toward the oldest entry until
	// we find a logEntry.timestamp that's before the endDate (older than the endDate).
	//
	// If we discover such a logEntry (in memory), then we know that it and all other logEntries before it
	// (including those in the db) can be included in the result range.
	//
	// If we can't find such a logEntry in memory, then we can just query the database.
	
	__block BOOL found = NO;
	__block NSUInteger foundIndex = 0;
	
	[connection->pending_insertedUUIDs enumerateObjectsWithOptions:NSEnumerationReverse
	                                                    usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
	{
		SCDatabaseLogEntry *logEntry = [connection->pending_insertedLogEntries objectForKey:obj];
		if ([logEntry.timestamp compare:endDate] != NSOrderedDescending)
		{
			found = YES;
			foundIndex = idx;
			*stop = YES;
		}
	}];
	
	if (found)
	{
		return (NSRange){
			.location = 0,
			.length = fullDbCount
			        - connection->fastforward_deletedRowids.count
			        + connection->fastforward_insertedRowids.count
			        + (foundIndex + 1) // from connection->pending_insertedUUIDs
		};
	}
	
	[connection->fastforward_insertedRowids enumerateObjectsWithOptions:NSEnumerationReverse
	                                                         usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
	{
		SCDatabaseLogEntry *logEntry = [connection->fastforward_insertedLogEntries objectForKey:obj];
		if ([logEntry.timestamp compare:endDate] != NSOrderedDescending)
		{
			found = YES;
			foundIndex = idx;
			*stop = YES;
		}
	}];
	
	if (found)
	{
		return (NSRange){
			.location = 0,
			.length = fullDbCount
			        - connection->fastforward_deletedRowids.count
			        + (foundIndex + 1) // from connection->fastforward_insertedRowids
		};
	}
	
	NSUInteger matchDbCount = [self _numberOfLogEntriesInDatabaseLessThanOrEqual:endDate];
	//
	// matchDbCount represents "low range" of items in the database:
	//
	// | x | x | x | x | x | x | x | x |
	// ^^^^^^^^^^^^^
	
	if (matchDbCount > connection->fastforward_deletedRowids.count)
		matchDbCount -= connection->fastforward_deletedRowids.count;
	else
		matchDbCount = 0;
	
	return NSMakeRange(0, matchDbCount);
}

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
- (NSRange)rangeOfLogEntriesWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
	BOOL hasStartDate = startDate &&
	                  ([startDate compare:[NSDate dateWithTimeIntervalSinceReferenceDate:0]] == NSOrderedDescending);
	
	BOOL hasEndDate = endDate &&
	                ([endDate compare:[NSDate date]] == NSOrderedAscending);
	
	if (!hasStartDate && !hasEndDate)
	{
		NSUInteger count = [self numberOfLogEntries];
		return NSMakeRange(0, count);
	}
	
	NSUInteger fullDbCount = [self _numberOfLogEntriesInDatabase];
	
	if (!hasStartDate)
	{
		return [self _rangeOfLogEntriesWithEndDate:endDate fullDbCount:fullDbCount];
	}
	else if (!hasEndDate)
	{
		return [self _rangeOfLogEntriesWithStartDate:startDate fullDbCount:fullDbCount];
	}
	else // if (hasStartDate && hasEndDate)
	{
		NSRange lowRange  = [self _rangeOfLogEntriesWithEndDate:endDate fullDbCount:fullDbCount];
		NSRange highRange = [self _rangeOfLogEntriesWithStartDate:startDate fullDbCount:fullDbCount];
		
		return NSIntersectionRange(lowRange, highRange);
	}
}

/**
 * Returns an array of IDs (opaque objects of type NSNumber and/or NSUUID),
 * which can be used to fetch the corresponding SCDatabaseLogEntry objects via the logEntryForID method.
 * 
 * The results are sorted by timestamp, oldest to newest.
 * So the oldest log message is at index 0, and the newest (most recent) is at the end of the array.
**/
- (NSArray *)allLogEntryIDs
{
	NSMutableArray *logEntryIDs = [NSMutableArray array];
	
	if (connection->db)
	{
		sqlite3_stmt *statement = [connection enumerateRowidsStatement];
		if (statement == NULL) {
			return nil;
		}
		
		// SELECT "rowid" FROM "logs" ORDER BY "timestamp" ASC;
		
		int status;
		while ((status = sqlite3_step(statement)) == SQLITE_ROW)
		{
			int64_t rowid = sqlite3_column_int64(statement, 0);
			
			[logEntryIDs addObject:@(rowid)];
		}
		
		if (status != SQLITE_DONE)
		{
			NSLogError(@"%@ - sqlite_step error: %d %s", THIS_METHOD, status, sqlite3_errmsg(connection->db));
		}
		
		sqlite3_clear_bindings(statement);
		sqlite3_reset(statement);
	}
	
	NSUInteger deletedOffset = connection->fastforward_deletedRowids.count;
	if (deletedOffset > 0)
	{
		[logEntryIDs removeObjectsInRange:NSMakeRange(0, deletedOffset)];
	}
	
	[logEntryIDs addObjectsFromArray:connection->fastforward_insertedRowids];
	[logEntryIDs addObjectsFromArray:connection->pending_insertedUUIDs];
	
	return logEntryIDs;
}

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
- (NSArray *)logEntryIDsWithLimit:(NSUInteger)limit offset:(NSUInteger)offset
{
	// If we fastforwarded, then there may be items in the database that are scheduled for deletion
	// (and which we're not including in our external representation).
	//
	// So we're going to convert the given range into a range that does take into account those entries in
	// the database (that are scheduled for deletion, but still exist within our snapshot of the database).
	
	NSUInteger dbCount = [self _numberOfLogEntriesInDatabase];
	NSUInteger dbOffset = connection->fastforward_deletedRowids.count;
	
	NSRange requestedRange = (NSRange){ // translated to match sqlite snapshot
		.location = offset + dbOffset,
		.length = limit,
	};
	
	NSRange db_fullRange = (NSRange){ // what's all in sqlite
		.location = 0,
		.length   = dbCount,
	};
	
	NSRange ff_fullRange = (NSRange){ // what's all in fastforward_inserted
		.location = dbCount,
		.length   = connection->fastforward_insertedRowids.count,
	};
	
	NSRange pd_fullRange = (NSRange){ // what's all in pending_inserted
		.location = dbCount + connection->fastforward_insertedRowids.count,
		.length   = connection->pending_insertedUUIDs.count,
	};
	
	// Now we just grab the intersections
	
	NSRange db_intersectRange = NSIntersectionRange(requestedRange, db_fullRange);
	NSRange ff_intersectRange = NSIntersectionRange(requestedRange, ff_fullRange);
	NSRange pd_intersectRange = NSIntersectionRange(requestedRange, pd_fullRange);
	
	
	NSUInteger capacity = 0;
	capacity += db_intersectRange.length;
	capacity += ff_intersectRange.length;
	capacity += pd_intersectRange.length;
	
	NSMutableArray *logEntryIDs = [NSMutableArray arrayWithCapacity:capacity];
	
	if (db_intersectRange.length > 0)
	{
		int64_t offset = (int64_t)db_intersectRange.location;
		int64_t limit  = (int64_t)db_intersectRange.length;
		
		sqlite3_stmt *statement = [connection enumerateRowidsRangeStatement];
		if (statement == NULL) {
			return nil;
		}
		
		// SELECT "rowid" FROM "logs" ORDER BY "timestamp" ASC LIMIT ? OFFSET ?;
		
		int const column_idx_rowid = SQLITE_COLUMN_START;
		int const bind_idx_limit   = SQLITE_BIND_START + 0;
		int const bind_idx_offset  = SQLITE_BIND_START + 1;
		
		sqlite3_bind_int64(statement, bind_idx_limit, limit);
		sqlite3_bind_int64(statement, bind_idx_offset, offset);
		
		int status;
		while ((status = sqlite3_step(statement)) == SQLITE_ROW)
		{
			int64_t rowid = sqlite3_column_int64(statement, column_idx_rowid);
			
			[logEntryIDs addObject:@(rowid)];
		}
		
		if (status != SQLITE_DONE)
		{
			NSLogError(@"%@ - sqlite_step error: %d %s", THIS_METHOD, status, sqlite3_errmsg(connection->db));
		}
		
		sqlite3_clear_bindings(statement);
		sqlite3_reset(statement);
	}
	
	if (ff_intersectRange.length > 0)
	{
		NSUInteger offset = ff_intersectRange.location = ff_fullRange.location;
		NSUInteger limit  = ff_intersectRange.length;
		
		for (NSUInteger i = offset; i < limit; i++)
		{
			NSNumber *rowid = connection->fastforward_insertedRowids[i];
			[logEntryIDs addObject:rowid];
		}
	}
	
	if (pd_intersectRange.length > 0)
	{
		NSUInteger offset = pd_intersectRange.location - pd_fullRange.location;
		NSUInteger limit  = pd_intersectRange.length;
		
		for (NSUInteger i = offset; i < limit; i++)
		{
			NSUUID *uuid = connection->pending_insertedUUIDs[i];
			[logEntryIDs addObject:uuid];
		}
	}
	
	return logEntryIDs;
}

/**
 * Returns the full LogEntry object for the given rowid.
 * 
 * Makes use of the built-in cache for super-fast access (helpful for scrolling).
**/
- (SCDatabaseLogEntry *)logEntryForID:(id)logEntryID
{
	if (logEntryID == nil) return nil;
	
	if ([logEntryID isKindOfClass:[NSUUID class]])
	{
		return [connection->pending_insertedLogEntries objectForKey:logEntryID];
	}
	if (![logEntryID isKindOfClass:[NSNumber class]])
	{
		return nil;
	}
	
	SCDatabaseLogEntry *logEntry;
	
	logEntry = [connection->fastforward_insertedLogEntries objectForKey:logEntryID];
	if (logEntry) {
		return logEntry;
	}
	
	if ([connection->fastforward_deletedRowids containsObject:logEntryID]) {
		return nil;
	}
	
	if (connection->db)
	{
		sqlite3_stmt *statement = [connection getLogEntryForRowidStatement];
		if (statement == NULL) {
			return nil;
		}
		
		// SELECT "timestamp", "context", "flags", "tag", "message" FROM "logs" WHERE "rowid" = ?;
		
		int const column_idx_timestamp = SQLITE_COLUMN_START + 0;
		int const column_idx_context   = SQLITE_COLUMN_START + 1;
		int const column_idx_flags     = SQLITE_COLUMN_START + 2;
		int const column_idx_tag       = SQLITE_COLUMN_START + 3;
		int const column_idx_message   = SQLITE_COLUMN_START + 4;
		int const bind_idx_rowid       = SQLITE_BIND_START;
		
		int64_t rowid = [(NSNumber *)logEntryID longLongValue];
		sqlite3_bind_int64(statement, bind_idx_rowid, rowid);
		
		int status = sqlite3_step(statement);
		if (status == SQLITE_ROW)
		{
			logEntry = [[SCDatabaseLogEntry alloc] init];
			
			double ts = sqlite3_column_double(statement, column_idx_timestamp);
			logEntry->timestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:ts];
			
			logEntry->context = sqlite3_column_int(statement, column_idx_context);
			logEntry->flags = sqlite3_column_int(statement, column_idx_flags);
			
			const unsigned char *text;
			int textSize;
			
			text = sqlite3_column_text(statement, column_idx_tag);
			textSize = sqlite3_column_bytes(statement, column_idx_tag);
			
			logEntry->tag = [[NSString alloc] initWithBytes:text length:textSize encoding:NSUTF8StringEncoding];
			
			text = sqlite3_column_text(statement, column_idx_message);
			textSize = sqlite3_column_bytes(statement, column_idx_message);
			
			logEntry->message = [[NSString alloc] initWithBytes:text length:textSize encoding:NSUTF8StringEncoding];
		}
		else if (status == SQLITE_ERROR)
		{
			NSLogError(@"Error executing 'getLogEntryForRowidStatement': %d %s", status, sqlite3_errmsg(connection->db));
		}
		
		sqlite3_clear_bindings(statement);
		sqlite3_reset(statement);
		
		if (logEntry) {
			[connection->logEntryCache setObject:logEntry forKey:logEntryID];
		}
	}
	
	return logEntry;
}

/**
 * Enumerates all the log entries available to the transaction.
 *
 * The log entries are enumerated by timestamp, oldest to newest.
 * So the oldest log message is first, and the newest (most recent) is last.
**/
- (void)enumerateLogEntriesWithBlock:(void (^)(id logEntryID, SCDatabaseLogEntry *logEntry, BOOL *stop))block
{
	BOOL stop = NO;
	
	if (connection->db)
	{
		sqlite3_stmt *statement = [connection enumerateLogEntriesStatement];
		if (statement == NULL) {
			return;
		}
		
		BOOL unlimitedCacheLimit = (connection->logEntryCacheLimit == 0);
		
		// SELECT "rowid", "timestamp", "context", "flags", "tag", "message" FROM "logs" ORDER BY "timestamp" ASC;
		
		int const column_idx_rowid     = SQLITE_COLUMN_START + 0;
		int const column_idx_timestamp = SQLITE_COLUMN_START + 1;
		int const column_idx_context   = SQLITE_COLUMN_START + 2;
		int const column_idx_flags     = SQLITE_COLUMN_START + 3;
		int const column_idx_tag       = SQLITE_COLUMN_START + 4;
		int const column_idx_message   = SQLITE_COLUMN_START + 5;
		
		int status;
		while ((status = sqlite3_step(statement)) == SQLITE_ROW)
		{
			int64_t rowid = sqlite3_column_int64(statement, column_idx_rowid);
			
			if ([connection->fastforward_deletedRowids containsObject:@(rowid)]) {
				continue;
			}
			
			SCDatabaseLogEntry *logEntry = [connection->logEntryCache objectForKey:@(rowid)];
			if (logEntry == nil)
			{
				logEntry = [[SCDatabaseLogEntry alloc] init];
				
				double ts = sqlite3_column_double(statement, column_idx_timestamp);
				logEntry->timestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:ts];
				
				logEntry->context = sqlite3_column_int(statement, column_idx_context);
				logEntry->flags = sqlite3_column_int(statement, column_idx_flags);
				
				const unsigned char *text;
				int textSize;
				
				text = sqlite3_column_text(statement, column_idx_tag);
				textSize = sqlite3_column_bytes(statement, column_idx_tag);
				
				logEntry->tag = [[NSString alloc] initWithBytes:text length:textSize encoding:NSUTF8StringEncoding];
				
				text = sqlite3_column_text(statement, column_idx_message);
				textSize = sqlite3_column_bytes(statement, column_idx_message);
				
				logEntry->message = [[NSString alloc] initWithBytes:text length:textSize encoding:NSUTF8StringEncoding];
			
				// Cache considerations:
				// Do we want to add the entry to the cache here?
				// If the cache is unlimited then we should.
				// Otherwise we should only add to the cache if it's not full.
				// The cache should generally be reserved for items that are explicitly fetched,
				// and we don't want to crowd them out during enumerations.
				
				if (unlimitedCacheLimit || [connection->logEntryCache count] < connection->logEntryCacheLimit)
				{
					[connection->logEntryCache setObject:logEntry forKey:@(rowid)];
				}
			}
			
			block(@(rowid), logEntry, &stop);
			
			if (stop) break;
		}
		
		if ((status != SQLITE_DONE) && !stop)
		{
			NSLogError(@"%@ - sqlite_step error: %d %s", THIS_METHOD, status, sqlite3_errmsg(connection->db));
		}
		
		sqlite3_clear_bindings(statement);
		sqlite3_reset(statement);
	}
	
	if (!stop)
	{
		for (NSNumber *rowid in connection->fastforward_insertedRowids)
		{
			SCDatabaseLogEntry *logEntry = [connection->fastforward_insertedLogEntries objectForKey:rowid];
			
			block(rowid, logEntry, &stop);
			if (stop) break;
		}
	}
	
	if (!stop)
	{
		for (NSUUID *uuid in connection->pending_insertedUUIDs)
		{
			SCDatabaseLogEntry *logEntry = [connection->pending_insertedLogEntries objectForKey:uuid];
			
			block(uuid, logEntry, &stop);
			if (stop) break;
		}
	}
}

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
                               block:(void (^)(id logEntryID, SCDatabaseLogEntry *logEntry, BOOL *stop))block
{
	// If we fastforwarded, then there may be items in the database that are scheduled for deletion
	// (and which we're not including in our external representation).
	//
	// So we're going to convert the given range into a range that does take into account those entries in
	// the database (that are scheduled for deletion, but still exist within our snapshot of the database).
	
	NSUInteger dbCount = [self _numberOfLogEntriesInDatabase];
	NSUInteger dbOffset = connection->fastforward_deletedRowids.count;
	
	NSRange requestedRange = (NSRange){ // translated to match sqlite snapshot
		.location = offset + dbOffset,
		.length = limit,
	};
	
	NSRange db_fullRange = (NSRange){ // what's all in sqlite
		.location = 0,
		.length   = dbCount,
	};
	
	NSRange ff_fullRange = (NSRange){ // what's all in fastforward_inserted
		.location = dbCount,
		.length   = connection->fastforward_insertedRowids.count,
	};
	
	NSRange pd_fullRange = (NSRange){ // what's all in pending_inserted
		.location = dbCount + connection->fastforward_insertedRowids.count,
		.length   = connection->pending_insertedUUIDs.count,
	};
	
	// Now we just grab the intersections
	
	NSRange db_intersectRange = NSIntersectionRange(requestedRange, db_fullRange);
	NSRange ff_intersectRange = NSIntersectionRange(requestedRange, ff_fullRange);
	NSRange pd_intersectRange = NSIntersectionRange(requestedRange, pd_fullRange);
	
	BOOL stop = NO;
	
	if (db_intersectRange.length > 0)
	{
		int64_t offset = (int64_t)db_intersectRange.location;
		int64_t limit  = (int64_t)db_intersectRange.length;
		
		sqlite3_stmt *statement = [connection enumerateLogEntriesRangeStatement];
		if (statement == NULL) {
			return;
		}
		
		BOOL unlimitedCacheLimit = (connection->logEntryCacheLimit == 0);
		
		// SELECT "rowid", "timestamp", "context", "flags", "tag", "message" FROM "logs"
		//  ORDER BY "timestamp" ASC LIMIT ? OFFSET ?;
		
		int const column_idx_rowid     = SQLITE_COLUMN_START + 0;
		int const column_idx_timestamp = SQLITE_COLUMN_START + 1;
		int const column_idx_context   = SQLITE_COLUMN_START + 2;
		int const column_idx_flags     = SQLITE_COLUMN_START + 3;
		int const column_idx_tag       = SQLITE_COLUMN_START + 4;
		int const column_idx_message   = SQLITE_COLUMN_START + 5;
		int const bind_idx_limit       = SQLITE_BIND_START + 0;
		int const bind_idx_offset      = SQLITE_BIND_START + 1;
		
		sqlite3_bind_int64(statement, bind_idx_limit, limit);
		sqlite3_bind_int64(statement, bind_idx_offset, offset);
		
		int status;
		while ((status = sqlite3_step(statement)) == SQLITE_ROW)
		{
			int64_t rowid = sqlite3_column_int64(statement, column_idx_rowid);
			
			if ([connection->fastforward_deletedRowids containsObject:@(rowid)]) {
				continue;
			}
			
			SCDatabaseLogEntry *logEntry = [connection->logEntryCache objectForKey:@(rowid)];
			if (logEntry == nil)
			{
				logEntry = [[SCDatabaseLogEntry alloc] init];
				
				double ts = sqlite3_column_double(statement, column_idx_timestamp);
				logEntry->timestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:ts];
				
				logEntry->context = sqlite3_column_int(statement, column_idx_context);
				logEntry->flags = sqlite3_column_int(statement, column_idx_flags);
				
				const unsigned char *text;
				int textSize;
				
				text = sqlite3_column_text(statement, column_idx_tag);
				textSize = sqlite3_column_bytes(statement, column_idx_tag);
				
				logEntry->tag = [[NSString alloc] initWithBytes:text length:textSize encoding:NSUTF8StringEncoding];
				
				text = sqlite3_column_text(statement, column_idx_message);
				textSize = sqlite3_column_bytes(statement, column_idx_message);
				
				logEntry->message = [[NSString alloc] initWithBytes:text length:textSize encoding:NSUTF8StringEncoding];
				
				// Cache considerations:
				// Do we want to add the entry to the cache here?
				// If the cache is unlimited then we should.
				// Otherwise we should only add to the cache if it's not full.
				// The cache should generally be reserved for items that are explicitly fetched,
				// and we don't want to crowd them out during enumerations.
				
				if (unlimitedCacheLimit || [connection->logEntryCache count] < connection->logEntryCacheLimit)
				{
					[connection->logEntryCache setObject:logEntry forKey:@(rowid)];
				}
			}
			
			block(@(rowid), logEntry, &stop);
			
			if (stop) break;
		}
		
		if ((status != SQLITE_DONE) && !stop)
		{
			NSLogError(@"%@ - sqlite_step error: %d %s", THIS_METHOD, status, sqlite3_errmsg(connection->db));
		}
		
		sqlite3_clear_bindings(statement);
		sqlite3_reset(statement);
	}
	
	if (!stop && ff_intersectRange.length > 0)
	{
		NSUInteger offset = ff_intersectRange.location - ff_fullRange.location;
		NSUInteger limit  = ff_intersectRange.length;
		
		for (NSUInteger i = offset; i < limit; i++)
		{
			NSNumber *rowid = connection->fastforward_insertedRowids[i];
			SCDatabaseLogEntry *logEntry = [connection->fastforward_insertedLogEntries objectForKey:rowid];
			
			block(rowid, logEntry, &stop);
			
			if (stop) break;
		}
	}
	
	if (!stop && pd_intersectRange.length > 0)
	{
		NSUInteger offset = pd_intersectRange.location - pd_fullRange.location;
		NSUInteger limit  = pd_intersectRange.length;
		
		for (NSUInteger i = offset; i < limit; i++)
		{
			NSUUID *uuid = connection->pending_insertedUUIDs[i];
			SCDatabaseLogEntry *logEntry = [connection->pending_insertedLogEntries objectForKey:uuid];
			
			block(uuid, logEntry, &stop);
			
			if (stop) break;
		}
	}
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation SCDatabaseLoggerWriteTransaction

- (void)findAndDeleteOldLogEntries:(NSTimeInterval)maxAge
{
	if (maxAge <= 0.0)
	{
		NSLogWarn(@"%@ - Invalid parameter: maxAge must be > 0", THIS_METHOD);
		return;
	}
	
	NSAssert(deletedRowids == nil, @"Unexpected double invocation of method within transaction");
	deletedRowids = [NSMutableArray arrayWithCapacity:1];
	
	NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
	NSTimeInterval old = now - maxAge;
	
	if (YES)
	{
		sqlite3_stmt *statement = [connection enumerateOldRowidsStatement];
		if (statement == NULL) {
			return;
		}
		
		// SELECT "rowid" FROM "logs" WHERE "timestamp" < ? ORDER BY "timestamp" ASC;
		
		int const column_idx_rowid  = SQLITE_COLUMN_START;
		int const bind_idx_timestamp = SQLITE_BIND_START;
		
		sqlite3_bind_double(statement, bind_idx_timestamp, old);
		
		int status = sqlite3_step(statement);
		if (status == SQLITE_ROW)
		{
			do
			{
				int64_t rowid = sqlite3_column_int64(statement, column_idx_rowid);
				[deletedRowids addObject:@(rowid)];
				
			} while ((status = sqlite3_step(statement)) == SQLITE_ROW);
		}
		
		if (status != SQLITE_DONE)
		{
			NSLogError(@"%@ - sqlite_step error (A): %d %s", THIS_METHOD, status, sqlite3_errmsg(connection->db));
		}
		
		sqlite3_clear_bindings(statement);
		sqlite3_reset(statement);
	}
	
	if (deletedRowids.count > 0)
	{
		sqlite3_stmt *statement = [connection deleteOldLogEntriesStatement];
		if (statement == NULL) {
			return;
		}
		
		// DELETE FROM "logs" WHERE "timestamp" < ?;
		
		sqlite3_bind_double(statement, SQLITE_BIND_START, old);
		
		int status = sqlite3_step(statement);
		
		if (status != SQLITE_DONE)
		{
			NSLogError(@"%@ - sqlite_step error (B): %d %s", THIS_METHOD, status, sqlite3_errmsg(connection->db));
		}
		
		sqlite3_clear_bindings(statement);
		sqlite3_reset(statement);
	}
}

- (void)insertLogEntries:(NSArray *)logEntries withUUIDs:(NSArray *)uuids
{
	NSAssert(logEntries.count == uuids.count, @"Array count mismatch !");
	
	NSUInteger count = logEntries.count;
	if (count == 0) return;
	
	NSAssert(insertedRowids == nil, @"Unexpected double invocation of method within transaction");
	
	insertedRowids     = [[NSMutableArray alloc] initWithCapacity:count];
	insertedLogEntries = [[NSMutableDictionary alloc] initWithCapacity:count];
	insertedMappings   = [[NSMutableDictionary alloc] initWithCapacity:count];
	
	sqlite3_stmt *statement = [connection insertForRowidStatement];
	if (statement == NULL) {
		return;
	}
	
	SCDatabaseLoggerString _tag;
	SCDatabaseLoggerString _msg;
	
	NSUInteger i = 0;
	for (SCDatabaseLogEntry *logEntry in logEntries)
	{
		BOOL inserted = NO;
		int64_t rowid = 0;
		
		// INSERT INTO "log" ("timestamp", "context", "flags", "tag", "message") VALUES (?, ?, ?, ?, ?);
		
		int const bind_idx_timestamp = SQLITE_BIND_START + 0;
		int const bind_idx_context   = SQLITE_BIND_START + 1;
		int const bind_idx_flags     = SQLITE_BIND_START + 2;
		int const bind_idx_tag       = SQLITE_BIND_START + 3;
		int const bind_idx_message   = SQLITE_BIND_START + 4;
		
		NSTimeInterval interval = [logEntry->timestamp timeIntervalSinceReferenceDate];
		sqlite3_bind_double(statement, bind_idx_timestamp, interval);
		
		sqlite3_bind_int(statement, bind_idx_context, logEntry->context);
		sqlite3_bind_int(statement, bind_idx_flags, logEntry->flags);
		
		MakeSCDatabaseLoggerString(&_tag, logEntry->tag);
		MakeSCDatabaseLoggerString(&_msg, logEntry->message);
		
		if (logEntry->tag) {
			sqlite3_bind_text(statement, bind_idx_tag, _tag.str, _tag.length, SQLITE_STATIC);
		}
		if (logEntry->message) {
			sqlite3_bind_text(statement, bind_idx_message, _msg.str, _msg.length, SQLITE_STATIC);
		}
		
		int status = sqlite3_step(statement);
		if (status == SQLITE_DONE)
		{
			rowid = sqlite3_last_insert_rowid(connection->db);
			inserted = YES;
		}
		else
		{
			NSLogError(@"Error executing 'insertForRowidStatement': %d %s", status, sqlite3_errmsg(connection->db));
		}
		
		sqlite3_clear_bindings(statement);
		sqlite3_reset(statement);
		FreeSCDatabaseLoggerString(&_tag);
		FreeSCDatabaseLoggerString(&_msg);
		
		if (inserted)
		{
			NSUUID *uuid = uuids[i];
			
			[insertedRowids addObject:@(rowid)];
			
			insertedLogEntries[@(rowid)] = logEntry;
			insertedMappings[@(rowid)] = uuid;
		}
		i++;
	}
}

@end
