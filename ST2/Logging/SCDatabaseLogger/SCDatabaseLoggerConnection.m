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
#import "SCDatabaseLoggerConnection.h"
#import "SCDatabaseLoggerPrivate.h"
#import "SCDatabaseLoggerConnectionState.h"
#import "SCDatabaseLoggerInternalChangeset.h"

#import <mach/mach_time.h>
#import <libkern/OSAtomic.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

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



@implementation SCDatabaseLoggerConnection {
	
	BOOL usesFastForwarding;
	BOOL resettingLongLivedReadTransaction;
	
	SCDatabaseLoggerTransaction *longLivedReadTransaction;
	NSMutableArray *pendingChangesets;
	NSMutableArray *processedChangesets;
	
	sqlite3_stmt *beginTransactionStatement;
	sqlite3_stmt *commitTransactionStatement;
	
	sqlite3_stmt *enumerateRowidsStatement;
	sqlite3_stmt *enumerateRowidsRangeStatement;
	sqlite3_stmt *enumerateLogEntriesStatement;
	sqlite3_stmt *enumerateLogEntriesRangeStatement;
	sqlite3_stmt *getLogEntryCountStatement;
	sqlite3_stmt *getLogEntryLowRangeStatement;
	sqlite3_stmt *getLogEntryHighRangeStatement;
	sqlite3_stmt *getLogEntryForRowidStatement;
	sqlite3_stmt *insertForRowidStatement;
	sqlite3_stmt *enumerateOldRowidsStatement;
	sqlite3_stmt *deleteOldLogEntriesStatement;
	
	sqlite3_stmt *getSnapshotStatement;
	sqlite3_stmt *setSnapshotStatement;
	
	int32_t loggerChangedNotificationFlag;
}

- (instancetype)initWithLogger:(SCDatabaseLogger *)inLogger
{
	if ((self = [super init]))
	{
		logger = inLogger;
		connectionQueue = dispatch_queue_create("SCDatabaseLoggerConnection", NULL);
		
		IsOnConnectionQueueKey = &IsOnConnectionQueueKey;
		dispatch_queue_set_specific(connectionQueue, IsOnConnectionQueueKey, IsOnConnectionQueueKey, NULL);
		
		pendingChangesets = [[NSMutableArray alloc] init];
		processedChangesets = [[NSMutableArray alloc] init];
		
		logEntryCacheLimit = 500;
		logEntryCache = [[SCDatabaseLoggerCache alloc] initWithCountLimit:logEntryCacheLimit];
		logEntryCache.allowedKeyClasses = [NSSet setWithObject:[NSNumber class]];
		logEntryCache.allowedObjectClasses = [NSSet setWithObject:[SCDatabaseLogEntry class]];
		
		usesFastForwarding = YES;
		
		#if TARGET_OS_IPHONE
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(didReceiveMemoryWarning:)
		                                             name:UIApplicationDidReceiveMemoryWarningNotification
		                                           object:nil];
		#endif
	}
	return self;
}

- (void)dealloc
{
	NSLogVerbose(@"Dealloc <SCDatabaseLoggerConnection %p: databaseName=%@>",
	              self, [logger.databasePath lastPathComponent]);
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		if (longLivedReadTransaction) {
			[self postReadTransaction:longLivedReadTransaction];
			longLivedReadTransaction = nil;
		}
	}};
	
	if (dispatch_get_specific(IsOnConnectionQueueKey))
		block();
	else
		dispatch_sync(connectionQueue, block);
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self _flushStatements];
	
	if (db)
	{
		int status = sqlite3_close(db);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error in sqlite_close: %d %s", status, sqlite3_errmsg(db));
		}
		
		db = NULL;
	}
	
	[logger removeConnection:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Memory
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)_flushStatements
{
	sqlite_finalize_null(&beginTransactionStatement);
	sqlite_finalize_null(&commitTransactionStatement);
	
	sqlite_finalize_null(&enumerateRowidsStatement);
	sqlite_finalize_null(&enumerateRowidsRangeStatement);
	sqlite_finalize_null(&enumerateLogEntriesStatement);
	sqlite_finalize_null(&enumerateLogEntriesRangeStatement);
	sqlite_finalize_null(&getLogEntryCountStatement);
	sqlite_finalize_null(&getLogEntryLowRangeStatement);
	sqlite_finalize_null(&getLogEntryHighRangeStatement);
	sqlite_finalize_null(&getLogEntryForRowidStatement);
	sqlite_finalize_null(&insertForRowidStatement);
	sqlite_finalize_null(&enumerateOldRowidsStatement);
	sqlite_finalize_null(&deleteOldLogEntriesStatement);
	
	sqlite_finalize_null(&getSnapshotStatement);
	sqlite_finalize_null(&setSnapshotStatement);
}

- (void)_flushMemory
{
	[self _flushStatements];
	[logEntryCache removeAllObjects];
}

- (void)flushMemory
{
	dispatch_block_t block = ^{
		
		[self _flushMemory];
	};
	
	if (dispatch_get_specific(IsOnConnectionQueueKey))
		block();
	else
		dispatch_async(connectionQueue, block);
}

#if TARGET_OS_IPHONE
- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
	[self flushMemory];
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize logger = logger;

@dynamic cacheEnabled;
@dynamic cacheLimit;
@dynamic usesFastForwarding;

- (BOOL)cacheEnabled
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = (logEntryCache != nil);
	};
	
	if (dispatch_get_specific(IsOnConnectionQueueKey))
		block();
	else
		dispatch_sync(connectionQueue, block);
	
	return result;
}

- (void)setCacheEnabled:(BOOL)flag
{
	dispatch_block_t block = ^{
		
		if (flag) // Enabled
		{
			if (logEntryCache == nil)
			{
				logEntryCache = [[SCDatabaseLoggerCache alloc] initWithCountLimit:logEntryCacheLimit];
				logEntryCache.allowedKeyClasses = [NSSet setWithObject:[NSNumber class]];
				logEntryCache.allowedObjectClasses = [NSSet setWithObject:[SCDatabaseLogEntry class]];
			}
		}
		else // Disabled
		{
			logEntryCache = nil;
		}
	};
	
	if (dispatch_get_specific(IsOnConnectionQueueKey))
		block();
	else
		dispatch_async(connectionQueue, block);
}

- (NSUInteger)cacheLimit
{
	__block NSUInteger result = 0;
	
	dispatch_block_t block = ^{
		result = logEntryCacheLimit;
	};
	
	if (dispatch_get_specific(IsOnConnectionQueueKey))
		block();
	else
		dispatch_sync(connectionQueue, block);
	
	return result;
}

- (void)setCacheLimit:(NSUInteger)newCacheLimit
{
	dispatch_block_t block = ^{
		
		if (logEntryCacheLimit != newCacheLimit)
		{
			logEntryCacheLimit = newCacheLimit;
			
			if (logEntryCache == nil)
			{
				// Limit changed, but cache is still disabled
			}
			else
			{
				logEntryCache.countLimit = logEntryCacheLimit;
			}
		}
	};
	
	if (dispatch_get_specific(IsOnConnectionQueueKey))
		block();
	else
		dispatch_async(connectionQueue, block);
}

- (BOOL)usesFastForwarding
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		result = usesFastForwarding;
	};
	
	if (dispatch_get_specific(IsOnConnectionQueueKey))
		block();
	else
		dispatch_sync(connectionQueue, block);
	
	return result;
}

- (void)setUsesFastForwarding:(BOOL)flag
{
	dispatch_block_t block = ^{
		usesFastForwarding = flag;
	};
	
	if (dispatch_get_specific(IsOnConnectionQueueKey))
		block();
	else
		dispatch_async(connectionQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SQLite Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is invoked once the logger's database is setup.
 * This method is invoked from our connectionQueue.
**/
- (void)prepareDatabase
{
	NSAssert(dispatch_get_specific(IsOnConnectionQueueKey), @"Method must be invoked on connectionQueue.");
	
	[self openDatabase];
	
	ffSnapshot = dbSnapshot = logger.snapshot;
}

- (void)openDatabase
{
	// Open the database connection.
	//
	// We use SQLITE_OPEN_NOMUTEX to use the multi-thread threading mode,
	// as we will be serializing access to the connection externally.
	
	int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_PRIVATECACHE;
	
	int status = sqlite3_open_v2([logger.databasePath UTF8String], &db, flags, NULL);
	if (status != SQLITE_OK)
	{
		// Sometimes the open function returns a db to allow us to query it for the error message
		if (db) {
			NSLogWarn(@"Error opening database: %d %s", status, sqlite3_errmsg(db));
		}
		else {
			NSLogError(@"Error opening database: %d", status);
		}
	}
	else
	{
#ifdef SQLITE_HAS_CODEC
		// Configure SQLCipher encryption for the new database connection.
		[logger configureEncryptionForDatabase:db];
#endif
		
		// Set synchronous pragma.
		// We're willing to sacrifice a small bit of durability for performance gains here.
				
		status = sqlite3_exec(db, "PRAGMA synchronous = NORMAL;", NULL, NULL, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error setting PRAGMA synchronous: %d %s", status, sqlite3_errmsg(db));
		}
		
		// Disable autocheckpointing.
		//
		// We have our own optimized checkpointing algorithm built-in.
		// It knows the state of every active connection for the database,
		// so it can invoke the checkpoint methods at the precise time
		// in which a checkpoint can be most effective.
		
		sqlite3_wal_autocheckpoint(db, 0);
		
		// Edge case workaround.
		//
		// If there's an active checkpoint operation,
		// then the very first time we call sqlite3_prepare_v2 on this db,
		// we sometimes get a SQLITE_BUSY error.
		//
		// This only seems to happen once, and only during the very first use of the db instance.
		// I'm still tyring to figure out exactly why this is.
		// For now I'm setting a busy timeout as a temporary workaround.
		//
		// Note: I've also tested setting a busy_handler which logs the number of times its called.
		// And in all my testing, I've only seen the busy_handler called once per db.
		
		sqlite3_busy_timeout(db, 50); // milliseconds
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Transactions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Synchronous access to the logger database.
 * 
 * Provides a snapshot-in-time of the current set of available log entries,
 * which is actually a merger of on-disk entries & those pending insertion. (i.e. real-time snapshot)
**/
- (void)readWithBlock:(void (^)(SCDatabaseLoggerTransaction *transaction))block
{
	dispatch_sync(connectionQueue, ^{ @autoreleasepool {
		
		if (longLivedReadTransaction)
		{
			block(longLivedReadTransaction);
		}
		else
		{
			SCDatabaseLoggerTransaction *transaction = [self newReadTransaction];
			
			[self preReadTransaction:transaction];
			block(transaction);
			[self postReadTransaction:transaction];
		}
	}});
}

/**
 * Asynchronous access to the logger database.
 *
 * Provides a snapshot-in-time of the current set of available log entries,
 * which is actually a merger of on-disk entries & those pending insertion. (i.e. real-time snapshot)
**/
- (void)asyncReadWithBlock:(void (^)(SCDatabaseLoggerTransaction *transaction))block
{
	[self asyncReadWithBlock:block completionQueue:NULL completionBlock:NULL];
}

/**
 * Asynchronous access to the logger database.
 *
 * Provides a snapshot-in-time of the current set of available log entries,
 * which is actually a merger of on-disk entries & those pending insertion. (i.e. real-time snapshot)
 * 
 * An optional completion block may be used.
 * The completionBlock will be invoked on the main thread (dispatch_get_main_queue()).
**/
- (void)asyncReadWithBlock:(void (^)(SCDatabaseLoggerTransaction *transaction))block
           completionBlock:(dispatch_block_t)completionBlock
{
	[self asyncReadWithBlock:block completionQueue:NULL completionBlock:completionBlock];
}

/**
 * Asynchronous access to the logger database.
 *
 * Provides a snapshot-in-time of the current set of available log entries,
 * which is actually a merger of on-disk entries & those pending insertion. (i.e. real-time snapshot)
 * 
 * An optional completion block may be used.
 * Additionally the dispatch_queue to invoke the completion block may also be specified.
 * If NULL, dispatch_get_main_queue() is automatically used.
**/
- (void)asyncReadWithBlock:(void (^)(SCDatabaseLoggerTransaction *transaction))block
           completionQueue:(dispatch_queue_t)completionQueue
           completionBlock:(dispatch_block_t)completionBlock
{
	if (completionQueue == NULL && completionBlock != NULL)
		completionQueue = dispatch_get_main_queue();
	
	dispatch_async(connectionQueue, ^{ @autoreleasepool {
		
		if (longLivedReadTransaction)
		{
			block(longLivedReadTransaction);
		}
		else
		{
			SCDatabaseLoggerTransaction *transaction = [self newReadTransaction];
			
			[self preReadTransaction:transaction];
			block(transaction);
			[self postReadTransaction:transaction];
		}
		
		if (completionBlock)
			dispatch_async(completionQueue, completionBlock);
	}});
}

/**
 * Private API
**/
- (void)asyncReadWriteWithBlock:(void (^)(SCDatabaseLoggerWriteTransaction *transaction))block
                completionQueue:(dispatch_queue_t)completionQueue
                completionBlock:(dispatch_block_t)completionBlock
{
	if (completionQueue == NULL && completionBlock != NULL)
		completionQueue = dispatch_get_main_queue();
	
	dispatch_async(connectionQueue, ^{
		
		dispatch_sync(logger->writeQueue, ^{ @autoreleasepool {
			
			SCDatabaseLoggerWriteTransaction *transaction = [self newReadWriteTransaction];
			
			[self preReadWriteTransaction:transaction];
			block(transaction);
			[self postReadWriteTransaction:transaction];
			
			if (completionBlock)
				dispatch_async(completionQueue, completionBlock);
			
		}}); // End dispatch_sync(database->writeQueue)
	});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Statements - general
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (sqlite3_stmt *)beginTransactionStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &beginTransactionStatement;
	if (*statement == NULL)
	{
		char *stmt = "BEGIN TRANSACTION;";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)commitTransactionStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &commitTransactionStatement;
	if (*statement == NULL)
	{
		char *stmt = "COMMIT TRANSACTION;";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Statements - logs
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * CREATE TABLE IF NOT EXISTS "logs"
 *   ("rowid" INTEGER PRIMARY KEY,
 *    "timestamp" REAL NOT NULL,
 *    "context" INTEGER NOT NULL,
 *    "flags" INTEGER NOT NULL,
 *    "tag" TEXT,
 *    "message" TEXT
 *   );
 * 
 * CREATE INDEX IF NOT EXISTS "timestamp" ON "logs" ( "timestamp" );
**/

- (sqlite3_stmt *)enumerateRowidsStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &enumerateRowidsStatement;
	if (*statement == NULL)
	{
		char *stmt = "SELECT \"rowid\" FROM \"logs\" ORDER BY \"timestamp\" ASC;";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)enumerateRowidsRangeStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &enumerateRowidsRangeStatement;
	if (*statement == NULL)
	{
		char *stmt = "SELECT \"rowid\" FROM \"logs\" ORDER BY \"timestamp\" ASC LIMIT ? OFFSET ?;";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)enumerateLogEntriesStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &enumerateLogEntriesStatement;
	if (*statement == NULL)
	{
		char *stmt = "SELECT \"rowid\", \"timestamp\", \"context\", \"flags\", \"tag\", \"message\" FROM \"logs\""
		             " ORDER BY \"timestamp\" ASC;";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)enumerateLogEntriesRangeStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &enumerateLogEntriesRangeStatement;
	if (*statement == NULL)
	{
		char *stmt = "SELECT \"rowid\", \"timestamp\", \"context\", \"flags\", \"tag\", \"message\" FROM \"logs\""
		             " ORDER BY \"timestamp\" ASC LIMIT ? OFFSET ?;";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)getLogEntryCountStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &getLogEntryCountStatement;
	if (*statement == NULL)
	{
		char *stmt = "SELECT COUNT(*) AS NumberOfRows FROM \"logs\";";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)getLogEntryLowRangeStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &getLogEntryLowRangeStatement;
	if (*statement == NULL)
	{
		char *stmt = "SELECT COUNT(*) AS NumberOfRows FROM \"logs\""
		             " WHERE \"timestamp\" <= ?"
		             " ORDER BY \"timestamp\" ASC;";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)getLogEntryHighRangeStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &getLogEntryHighRangeStatement;
	if (*statement == NULL)
	{
		char *stmt = "SELECT COUNT(*) AS NumberOfRows FROM \"logs\""
		             " WHERE \"timestamp\" >= ?"
		             " ORDER BY \"timestamp\" ASC;";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)getLogEntryForRowidStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &getLogEntryForRowidStatement;
	if (*statement == NULL)
	{
		char *stmt =
		  "SELECT \"timestamp\", \"context\", \"flags\", \"tag\", \"message\" FROM \"logs\" WHERE \"rowid\" = ?;";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)insertForRowidStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &insertForRowidStatement;
	if (*statement == NULL)
	{
		char *stmt = "INSERT INTO \"logs\""
		  " (\"timestamp\", \"context\", \"flags\", \"tag\", \"message\") VALUES (?, ?, ?, ?, ?);";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", NSStringFromSelector(_cmd), status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)enumerateOldRowidsStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &enumerateOldRowidsStatement;
	if (*statement == NULL)
	{
		char *stmt = "SELECT \"rowid\" FROM \"logs\" WHERE \"timestamp\" < ? ORDER BY \"timestamp\" ASC;";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", NSStringFromSelector(_cmd), status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)deleteOldLogEntriesStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &deleteOldLogEntriesStatement;
	if (*statement == NULL)
	{
		char *stmt = "DELETE FROM \"logs\" WHERE \"timestamp\" < ?;";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", NSStringFromSelector(_cmd), status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Statements - sc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * CREATE TABLE IF NOT EXISTS "sc"
 *   ("key" TEXT PRIMARY KEY,
 *    "data" BLOB
 *   );
**/

- (sqlite3_stmt *)getSnapshotStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &getSnapshotStatement;
	if (*statement == NULL)
	{
		char *stmt = "SELECT \"data\" FROM \"sc\" WHERE \"key\" = 'snapshot';";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

- (sqlite3_stmt *)setSnapshotStatement
{
	NSAssert(db != NULL, @"Requesting sqlite3_stmt without db in place!");
	
	sqlite3_stmt **statement = &setSnapshotStatement;
	if (*statement == NULL)
	{
		char *stmt = "INSERT OR REPLACE INTO \"sc\" (\"key\", \"data\") VALUES ('snapshot', ?);";
		int stmtLen = (int)strlen(stmt);
		
		int status = sqlite3_prepare_v2(db, stmt, stmtLen+1, statement, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error creating '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
	}
	
	return *statement;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Transaction States
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (SCDatabaseLoggerTransaction *)newReadTransaction
{
	return [[SCDatabaseLoggerTransaction alloc] initWithConnection:self isFastForwarded:usesFastForwarding];
}

- (SCDatabaseLoggerWriteTransaction *)newReadWriteTransaction
{
	return [[SCDatabaseLoggerWriteTransaction alloc] initWithConnection:self isFastForwarded:usesFastForwarding];
}

/**
 * This method executes the state transition steps required before executing a read-only transaction block.
 * 
 * This method must be invoked from within the connectionQueue.
**/
- (void)preReadTransaction:(SCDatabaseLoggerTransaction *)transaction
{
	__block NSArray *ffChangesets = nil;
	
	__block NSArray *pendingLogEntries = nil;
	__block NSArray *pendingUUIDs = nil;
	
	// Pre-Read-Transaction: Step 1 of 6
	//
	// Execute "BEGIN TRANSACTION" on database connection.
	// This is actually a deferred transaction, meaning the sqlite connection won't actually
	// acquire a shared read lock until it executes a select statement.
	// There are alternatives to this, including a "begin immediate transaction".
	// However, this doesn't do what we want. Instead it blocks other read-only transactions.
	
	if (db)
	{
		[transaction beginTransaction];
	}
	
	dispatch_sync(logger->snapshotQueue, ^{ @autoreleasepool {
		
		// Pre-Read-Transaction: Step 2 of 6
		//
		// Ensure our cache is in-sync with the state of the database.
		
		if (db)
		{
			uint64_t ourSnapshot = dbSnapshot;
			uint64_t sqlSnapshot = [self readSnapshotFromDatabase];
			
			if (ourSnapshot < sqlSnapshot)
			{
				// The transaction can see the sqlite commit(s) from another transaction.
				// and it hasn't processed the changeset(s) yet. We need to process them now.
				
				NSArray *changesets = [logger pendingAndCommittedChangesSince:ourSnapshot until:sqlSnapshot];
				
				for (SCDatabaseLoggerInternalChangeset *changeset in changesets)
				{
					[self noteCommittedChanges:changeset];
				}
				
				// The noteCommittedChanges method (invoked above) updates our 'snapshot' variable.
				NSAssert(dbSnapshot == sqlSnapshot,
				         @"Invalid connection state in preReadTransaction:"
				         @" dbSnapshot(%llu) != sqlSnapshot(%llu): %@",
				         dbSnapshot, sqlSnapshot, changesets);
			}
		}
		
		// Pre-Read-Transaction: Step 3 of 6
		//
		// Update our connection state within the state table.
		// We need to mark this connection as being within an active transaction.
		
		SCDatabaseLoggerConnectionState *myState = nil;
		
		for (SCDatabaseLoggerConnectionState *state in logger->connectionStates)
		{
			if (state->connection == self)
			{
				myState = state;
				break;
			}
		}
		
		NSAssert(myState != nil, @"Missing state in database->connectionStates");
		
		myState->activeReadTransaction = YES;
		myState->longLivedReadTransaction = (longLivedReadTransaction != nil);
		myState->lastTransactionSnapshot = dbSnapshot;
		myState->lastTransactionTime = mach_absolute_time();
			
		// Pre-Read-Transaction: Step 4 of 6
		//
		// Fast-forward the connection by grabbing pending commits & pending logEntries.
		
		if (usesFastForwarding && !resettingLongLivedReadTransaction)
		{
			ffChangesets = [logger pendingAndCommittedChangesAfter:dbSnapshot];
			
			[logger getPendingLogEntriesForRead:&pendingLogEntries uuids:&pendingUUIDs];
		}
	}});
	
	
	// Pre-Read-Transaction: Step 5 of 6
	//
	// Process ffChangesets.
 	//
	// Squash into the following ivars:
	// - fastforward_deletedRowids       (NSSet)(NSNumber)
	// - fastforward_insertedLogEntries  (NSDictionary)(rowid -> logEntry)
	//
	// And update ffSnapshot ivar.
	
	if (ffChangesets.count > 0)
	{
		if (fastforward_deletedRowids == nil)
			fastforward_deletedRowids = [[NSMutableSet alloc] init];
		
		if (fastforward_insertedRowids == nil)
			fastforward_insertedRowids = [[NSMutableArray alloc] init];
		
		if (fastforward_insertedLogEntries == nil)
			fastforward_insertedLogEntries = [[NSMutableDictionary alloc] init];
		
		ffSnapshot = [[ffChangesets lastObject] snapshot];
		
		BOOL isIndexZero = YES;
		for (SCDatabaseLoggerInternalChangeset *changeset in ffChangesets)
		{
			if (isIndexZero)
			{
				[fastforward_deletedRowids addObjectsFromArray:changeset.deletedRowids];
				isIndexZero = NO;
			}
			else
			{
				for (NSNumber *rowid in changeset.deletedRowids)
				{
					if ([fastforward_insertedLogEntries objectForKey:rowid])
					{
						[fastforward_insertedLogEntries removeObjectForKey:rowid];
						
						NSUInteger index = [fastforward_insertedRowids indexOfObject:rowid];
						if (index != NSNotFound) {
							[fastforward_insertedRowids removeObjectAtIndex:index];
						}
					}
					else
					{
						[fastforward_deletedRowids addObject:rowid];
					}
				}
			}
			
			[fastforward_insertedLogEntries addEntriesFromDictionary:changeset.insertedLogEntries];
			[fastforward_insertedRowids addObjectsFromArray:changeset.insertedRowids];
		}
		
	}
	else if (!resettingLongLivedReadTransaction)
	{
		NSAssert(fastforward_deletedRowids.count      == 0, @"Forgot to clear transaction variable.");
		NSAssert(fastforward_insertedRowids.count     == 0, @"Forgot to clear transaction variable.");
		NSAssert(fastforward_insertedLogEntries.count == 0, @"Forgot to clear transaction variable.");
		
		ffSnapshot = dbSnapshot;
	}
	
	// Pre-Read-Transaction: Step 6 of 6
	//
	// Process pendingLogEntries & pendingUUIDs
	// - pending_insertedLogEntries (NSDictionary) (uuid -> logEntry)
	
	if (pendingLogEntries.count > 0)
	{
		if (pending_insertedLogEntries == nil)
			pending_insertedLogEntries = [[NSMutableDictionary alloc] init];
		
		NSUInteger i = 0;
		for (SCDatabaseLogEntry *logEntry in pendingLogEntries)
		{
			NSUUID *uuid = [pendingUUIDs objectAtIndex:i];
			
			pending_insertedLogEntries[uuid] = logEntry;
			i++;
		}
		
		pending_insertedUUIDs = pendingUUIDs;
	}
	else if (!resettingLongLivedReadTransaction)
	{
		NSAssert(pending_insertedLogEntries.count == 0, @"Forgot to clear transaction variable.");
		NSAssert(pending_insertedUUIDs.count      == 0, @"Forgot to clear transaction variable.");
	}
}

/**
 * This method executes the state transition steps required after executing a read-only transaction block.
 *
 * This method must be invoked from within the connectionQueue.
**/
- (void)postReadTransaction:(SCDatabaseLoggerTransaction *)transaction
{
	// Post-Read-Transaction: Step 1 of 4
	//
	// 1. Execute "COMMIT TRANSACTION" on database connection.
	// If we had acquired "sql-level" shared read lock, this will release associated resources.
	// It may also free the auto-checkpointing architecture within sqlite to sync the WAL to the database.
	
	if (db)
	{
		[transaction commitTransaction];
	}
	
	__block uint64_t minSnapshot = 0;
	
	dispatch_sync(logger->snapshotQueue, ^{ @autoreleasepool {
		
		// Post-Read-Transaction: Step 2 of 4
		//
		// Update our connection state within the state table.
		
		minSnapshot = [logger snapshot];
		
		for (SCDatabaseLoggerConnectionState *state in logger->connectionStates)
		{
			if (state->connection == self)
			{
				state->activeReadTransaction = NO;
				state->longLivedReadTransaction = NO;
			}
			else if (state->activeReadTransaction)
			{
				// Active sibling connection: read-only
				
				minSnapshot = MIN(state->lastTransactionSnapshot, minSnapshot);
			}
			else if (state->activeWriteTransaction)
			{
				// Active sibling connection: read-write
				
				minSnapshot = MIN(state->lastTransactionSnapshot, minSnapshot);
			}
		}
		
		NSLogVerbose(@"SCDatabaseLoggerConnection(%p) completing read-only transaction.", self);
	}});
	
	// Post-Read-Transaction: Step 3 of 4
	//
	// Check to see if this connection has been holding back the checkpoint process.
	// That is, was this connection the last active connection on an old snapshot?
	
	if (db && (dbSnapshot < minSnapshot))
	{
		// There are commits ahead of us that need to be checkpointed.
		// And we were the oldest active connection,
		// so we were previously preventing the checkpoint from progressing.
		// Thus we can now continue the checkpoint operation.
		
		[logger asyncCheckpoint:minSnapshot];
	}
	
	// Post-Read-Transaction: Step 4 of 4
	//
	// Cleanup any un-needed variables (those specific to a transaction).
	
	if (fastforward_deletedRowids)
		[fastforward_deletedRowids removeAllObjects];
	
	if (fastforward_insertedRowids)
		[fastforward_insertedRowids removeAllObjects];
	
	if (fastforward_insertedLogEntries)
		[fastforward_insertedLogEntries removeAllObjects];
	
	if (pending_insertedUUIDs)
		pending_insertedUUIDs = nil;
	
	if (pending_insertedLogEntries)
		[pending_insertedLogEntries removeAllObjects];
}

/**
 * This method executes the state transition steps required before executing a read-write transaction block.
 *
 * This method must be invoked from within the connectionQueue.
 * This method must be invoked from within the logger.writeQueue.
**/
- (void)preReadWriteTransaction:(SCDatabaseLoggerWriteTransaction *)transaction
{
	NSAssert(db != NULL, @"Logic error - prepareDatabase method expected to run first");
	
	// Pre-Write-Transaction: Step 1 of 4
	//
	// Execute "BEGIN TRANSACTION" on database connection.
	// This is actually a deferred transaction, meaning the sqlite connection won't actually
	// acquire any locks until it executes something.
	// There are various alternatives to this, including "immediate" and "exclusive" transactions.
	// However, these don't do what we want. Instead they block other read-only transactions.
	// The deferred transaction allows other read-only transactions and even avoids
	// sqlite operations if no modifications are made.
	//
	// Remember, we are the only active write transaction for this database.
	// No other write transactions can occur until this transaction completes.
	// Thus no other transactions can possibly modify the database during our transaction.
	// Therefore it doesn't matter when we acquire our "sql-level" locks for writing.
	
	[transaction beginTransaction];
	
	dispatch_sync(logger->snapshotQueue, ^{ @autoreleasepool {
		
		// Pre-Write-Transaction: Step 2 of 4
		//
		// Validate our cache based on snapshot numbers
		
		uint64_t ourCurrentSnapshot = dbSnapshot;
		uint64_t mostRecentSnapshot = logger.snapshot;
		
		if (ourCurrentSnapshot < mostRecentSnapshot)
		{
			NSArray *changesets = [logger pendingAndCommittedChangesSince:ourCurrentSnapshot until:mostRecentSnapshot];
			
			for (SCDatabaseLoggerInternalChangeset *changeset in changesets)
			{
				[self noteCommittedChanges:changeset];
			}
			
			// The noteCommittedChanges method (invoked above) updates our 'snapshot' variable.
			NSAssert(dbSnapshot == mostRecentSnapshot,
					 @"Invalid connection state in preReadWriteTransaction:"
					 @" dbSnapshot(%llu) != mostRecentSnapshot(%llu)",
					 dbSnapshot, mostRecentSnapshot);
		}
		
		// Pre-Write-Transaction: Step 3 of 4
		//
		// Update our connection state within the state table.
		
		SCDatabaseLoggerConnectionState *myState = nil;
		
		for (SCDatabaseLoggerConnectionState *state in logger->connectionStates)
		{
			if (state->connection == self)
			{
				myState = state;
				
			}
		}
		
		NSAssert(myState != nil, @"Missing state in logger->connectionStates");
		
		myState->activeWriteTransaction = YES;
		myState->lastTransactionSnapshot = dbSnapshot;
		myState->lastTransactionTime = mach_absolute_time();
		
		NSLogVerbose(@"YapDatabaseConnection(%p) starting read-write transaction.", self);
	}});
	
	// Pre-Write-Transaction: Step 4 of 4
	//
	// Add IsOnConnectionQueueKey flag to writeQueue.
	// This allows various methods that depend on the flag to operate correctly.
	
	dispatch_queue_set_specific(logger->writeQueue, IsOnConnectionQueueKey, IsOnConnectionQueueKey, NULL);
}

/**
 * This method executes the state transition steps required after executing a read-only transaction block.
 *
 * This method must be invoked from within the connectionQueue.
 * This method must be invoked from within the logger.writeQueue.
**/
- (void)postReadWriteTransaction:(SCDatabaseLoggerWriteTransaction *)transaction
{
	// Post-Write-Transaction: Step 1 of 8
	//
	// Create changeset.
	// Then update the snapshot in the database (if any changes were made).
	
	SCDatabaseLoggerInternalChangeset *changeset = nil;
	
	if ((transaction->insertedRowids.count > 0) || (transaction->deletedRowids.count > 0))
	{
		dbSnapshot++;
		[self writeSnapshotToDatabase];
		
		changeset = [[SCDatabaseLoggerInternalChangeset alloc] initWithSnapshot:dbSnapshot
		                                                          deletedRowids:transaction->deletedRowids
		                                                         insertedRowids:transaction->insertedRowids
		                                                     insertedLogEntries:transaction->insertedLogEntries
		                                                       insertedMappings:transaction->insertedMappings];
	}
	
	// Post-Write-Transaction: Step 2 of 8
	//
	// Register pending changeset. (adds insertedRowids for readers)
	// And remove the insertedRowids from pending.
	
	if (changeset)
	{
		dispatch_sync(logger->snapshotQueue, ^{ @autoreleasepool {
			
			[logger notePendingChanges:changeset];
			[logger removePendingLogEntries:transaction->insertedRowids.count];
		}});
	}
	
	// Post-Write-Transaction: Step 3 of 8
	//
	// Execute "COMMIT TRANSACTION" on database connection.
	// This will write the changes to the WAL.
	
	[transaction commitTransaction];
	
	__block uint64_t minSnapshot = UINT64_MAX;
	
	dispatch_sync(logger->snapshotQueue, ^{ @autoreleasepool {
		
		// Post-Write-Transaction: Step 4 of 8
		//
		// Notify system of committed changes.
		
		if (changeset)
		{
			[logger noteCommittedChanges:changeset fromConnection:self];
		}
		
		// Post-Write-Transaction: Step 5 of 8
		//
		// Update our connection state within the state table.
		
		SCDatabaseLoggerConnectionState *myState = nil;
		
		for (SCDatabaseLoggerConnectionState *state in logger->connectionStates)
		{
			if (state->connection == self)
			{
				myState = state;
			}
			else if (state->activeReadTransaction)
			{
				minSnapshot = MIN(state->lastTransactionSnapshot, minSnapshot);
			}
		}
		
		NSAssert(myState != nil, @"Missing state in logger->connectionStates");
		
		myState->activeWriteTransaction = NO;
		
		NSLogVerbose(@"SCDatabaseLoggerConnection(%p) completing read-write transaction.", self);
	}});
	
	// Post-Write-Transaction: Step 6 of 8
	
	if (changeset)
	{
		// We added frames to the WAL.
		// We can invoke a checkpoint if there are no other active connections.
		
		if (minSnapshot == UINT64_MAX)
		{
			[logger asyncCheckpoint:dbSnapshot];
		}
	}
	
	// Post-Write-Transaction: Step 7 of 8
	//
	// Post SCDatabaseLoggerChangedNotification (if needed).
	
	if (changeset)
	{
		[self queueLoggerChangedNotification];
	}
	
	// Post-Write-Transaction: Step 8 of 8
	//
	// Drop IsOnConnectionQueueKey flag from writeQueue since we're exiting writeQueue.
	
	dispatch_queue_set_specific(logger->writeQueue, IsOnConnectionQueueKey, NULL, NULL);
}

/**
 * This method "kills two birds with one stone".
 * 
 * First, it invokes a SELECT statement on the database.
 * This executes the sqlite machinery to acquire a "sql-level" snapshot of the database.
 * That is, the encompassing transaction will now reference a specific commit record in the WAL,
 * and will ignore any commits made after this record.
 * 
 * Second, it reads a specific value from the database, and tells us which commit record in the WAL its using.
 * This allows us to validate the transaction, and check for a particular race condition.
**/
- (uint64_t)readSnapshotFromDatabase
{
	sqlite3_stmt *statement = [self getSnapshotStatement];
	if (statement == NULL) return 0;
	
	uint64_t result = 0;
	
	// SELECT "data" FROM 'sc' WHERE key = 'snapshot';
	
	int status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		result = (uint64_t)sqlite3_column_int64(statement, 0);
	}
	else if (status == SQLITE_ERROR)
	{
		NSLogError(@"Error executing 'getSnapshotStatement': %d %s", status, sqlite3_errmsg(db));
	}
	
	sqlite3_reset(statement);
	
	return result;
}

- (void)writeSnapshotToDatabase
{
	sqlite3_stmt *statement = [self setSnapshotStatement];
	if (statement == NULL) return;
	
	// INSERT OR REPLACE INTO "sc" ("key", "data") VALUES ('snapshot', ?);
	
	sqlite3_bind_int64(statement, SQLITE_BIND_START, dbSnapshot);
	
	int status = sqlite3_step(statement);
	if (status != SQLITE_DONE)
	{
		NSLogError(@"Error executing 'setSnapshotStatement': %d %s", status, sqlite3_errmsg(db));
	}
	
	sqlite3_clear_bindings(statement);
	sqlite3_reset(statement);
}

- (void)queueLoggerChangedNotification
{
	bool originalFlag = OSAtomicTestAndSet(0, &loggerChangedNotificationFlag);
	if (originalFlag == NO)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			
			OSAtomicTestAndClear(0, &loggerChangedNotificationFlag);
			[[NSNotificationCenter defaultCenter] postNotificationName:SCDatabaseLoggerChangedNotification
			                                                    object:logger];
		});
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Long-Lived Transactions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSMutableArray *)_beginLongLivedReadTransaction
{
	NSAssert(dispatch_get_specific(IsOnConnectionQueueKey), @"Method must be invoked on connectionQueue.");
	
	NSMutableArray *internalChangesets = nil;
	
	if (longLivedReadTransaction)
	{
		// Caller using implicit atomic reBeginLongLivedReadTransaction
		internalChangesets = [self _endLongLivedReadTransaction];
	}
	
	longLivedReadTransaction = [self newReadTransaction];
	[self preReadTransaction:longLivedReadTransaction];
	
	// The preReadTransaction method acquires the "sqlite-level" snapshot.
	// In doing so, if it needs to fetch and process any changesets,
	// then it adds them to the processedChangesets ivar for us.
	
	if (internalChangesets == nil)
		internalChangesets = [processedChangesets mutableCopy];
	else
		[internalChangesets addObjectsFromArray:processedChangesets];
	
	[processedChangesets removeAllObjects];
	
	return internalChangesets;
}

- (SCDatabaseLoggerChangeset *)beginLongLivedReadTransaction
{
	__block SCDatabaseLoggerChangeset *externalChangeset;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		int64_t prev_ffSnapshot = ffSnapshot;
		NSMutableDictionary *prev_pendingLogEntries = [pending_insertedLogEntries mutableCopy];
		
		NSMutableArray *internalChangesets = [self _beginLongLivedReadTransaction];
		
		externalChangeset = [self createExternalChangesetFrom:internalChangesets
		                                      prev_ffSnapshot:prev_ffSnapshot
		                               prev_pendingLogEntries:prev_pendingLogEntries];
	}};
	
	if (dispatch_get_specific(IsOnConnectionQueueKey))
		block();
	else
		dispatch_sync(connectionQueue, block);
	
	return externalChangeset;
}

- (NSMutableArray *)_endLongLivedReadTransaction
{
	NSAssert(dispatch_get_specific(IsOnConnectionQueueKey), @"Method must be invoked on connectionQueue.");
	
	NSMutableArray *internalChangesets = nil;
	
	if (longLivedReadTransaction)
	{
		// End the transaction (sqlite commit)
		
		[self postReadTransaction:longLivedReadTransaction];
		longLivedReadTransaction = nil;
		
		// Now process any changesets that were pending.
		// And extract the corresponding external notifications to return the the caller.
		
		NSUInteger count = pendingChangesets.count;
		if (count > 0)
		{
			for (SCDatabaseLoggerInternalChangeset *changeset in pendingChangesets)
			{
				[self noteCommittedChanges:changeset];
			}
			
			internalChangesets = [pendingChangesets mutableCopy];
			[pendingChangesets removeAllObjects];
		}
	}
	
	return internalChangesets;
}

- (SCDatabaseLoggerChangeset *)endLongLivedReadTransaction
{
	__block SCDatabaseLoggerChangeset *externalChangeset;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		int64_t prev_ffSnapshot = ffSnapshot;
		NSMutableDictionary *prev_pendingLogEntries = [pending_insertedLogEntries mutableCopy];
		
		NSMutableArray *internalChangesets = [self _endLongLivedReadTransaction];
		
		externalChangeset = [self createExternalChangesetFrom:internalChangesets
		                                      prev_ffSnapshot:prev_ffSnapshot
		                               prev_pendingLogEntries:prev_pendingLogEntries];
	}};
	
	if (dispatch_get_specific(IsOnConnectionQueueKey))
		block();
	else
		dispatch_sync(connectionQueue, block);
	
	return externalChangeset;
}

- (SCDatabaseLoggerChangeset *)createExternalChangesetFrom:(NSArray *)internalChangesets
                                           prev_ffSnapshot:(int64_t)prev_ffSnapshot
                                    prev_pendingLogEntries:(NSMutableDictionary *)prev_pendingLogEntries
{
	NSAssert(dispatch_get_specific(IsOnConnectionQueueKey), @"Method must be invoked on connectionQueue.");
	// Because this method directly accesses pending_uuids ivar.
	
	NSMutableArray *deletedLogEntryIDs  = [NSMutableArray array];
	NSMutableArray *insertedLogEntryIDs = [NSMutableArray array];
	NSMutableArray *insertedLogEntries  = [NSMutableArray array];
	
	NSMutableSet *insertedRowids = [NSMutableSet set];
	
	for (SCDatabaseLoggerInternalChangeset *internalChangeset in internalChangesets)
	{
		if (internalChangeset.snapshot > prev_ffSnapshot)
		{
			for (NSNumber *rowid in internalChangeset.deletedRowids)
			{
				if ([insertedRowids containsObject:rowid])
				{
					[insertedRowids removeObject:rowid];
					
					NSUInteger index = [insertedLogEntryIDs indexOfObject:rowid];
					if (index != NSNotFound) {
						[insertedLogEntryIDs removeObjectAtIndex:index];
						[insertedLogEntries  removeObjectAtIndex:index];
					}
				}
				else
				{
					[deletedLogEntryIDs addObject:rowid];
				}
			}
			
			for (NSNumber *rowid in internalChangeset.insertedRowids)
			{
				NSUUID *uuid = internalChangeset.insertedMappings[rowid];
				
				if ([prev_pendingLogEntries objectForKey:uuid])
				{
					[prev_pendingLogEntries removeObjectForKey:uuid];
				}
				else
				{
					SCDatabaseLogEntry *logEntry = [internalChangeset.insertedLogEntries objectForKey:rowid];
					
					[insertedRowids addObject:rowid];
					[insertedLogEntryIDs addObject:rowid];
					[insertedLogEntries addObject:logEntry];
				}
			}
		}
	}
	
	for (NSUUID *uuid in pending_insertedUUIDs)
	{
		SCDatabaseLogEntry *logEntry = [pending_insertedLogEntries objectForKey:uuid];
		
		[insertedLogEntryIDs addObject:uuid];
		[insertedLogEntries addObject:logEntry];
	}
	
	return [[SCDatabaseLoggerChangeset alloc] initWithDeletedLogEntryIDs:deletedLogEntryIDs
	                                                 insertedLogEntryIDs:insertedLogEntryIDs
	                                                  insertedLogEntries:insertedLogEntries];
}

- (BOOL)isInLongLivedReadTransaction
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		
		result = (longLivedReadTransaction != nil);
	};
	
	if (dispatch_get_specific(IsOnConnectionQueueKey))
		block();
	else
		dispatch_sync(connectionQueue, block);
	
	return result;
}

/**
 * Long-lived read transactions are a great way to achive stability, especially in places like the main-thread.
 * However, they pose a unique problem. These long-lived transactions often start out by
 * locking the WAL (write ahead log). This prevents the WAL from ever getting reset,
 * and thus causes the WAL to potentially grow infinitely large. In order to allow the WAL to get properly reset,
 * we need the long-lived read transactions to "reset". That is, without changing their stable state (their snapshot),
 * we need them to restart the transaction, but this time without locking this WAL.
 * 
 * We use the maybeResetLongLivedReadTransaction method to achieve this.
**/
- (void)maybeResetLongLivedReadTransaction
{
	// Async dispatch onto the writeQueue so we know there aren't any other active readWrite transactions
	
	dispatch_async(logger->writeQueue, ^{
		
		// Pause the writeQueue so readWrite operations can't interfere with us.
		
		dispatch_suspend(logger->writeQueue);
		
		// Async dispatch onto our connectionQueue.
		
		dispatch_async(connectionQueue, ^{
			
			// If possible, silently reset the longLivedReadTransaction (same snapshot, no longer locking the WAL)
			
			if (longLivedReadTransaction && (dbSnapshot == [logger snapshot]))
			{
				resettingLongLivedReadTransaction = YES;
				SCDatabaseLoggerChangeset *changeset = [self beginLongLivedReadTransaction];
				resettingLongLivedReadTransaction = NO;
				
				if (changeset.deletedLogEntryIDs.count > 0 ||
				    changeset.insertedLogEntryIDs.count > 0 )
				{
					NSLogError(@"Core logic failure! "
					            @"Silent longLivedReadTransaction reset resulted in non-empty notification array!");
				}
			}
			
			// Resume the writeQueue
			
			dispatch_resume(logger->writeQueue);
		});
	});
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Changeset Architecture
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)processChangeset:(SCDatabaseLoggerInternalChangeset *)changeset
{
	for (NSNumber *rowid in changeset.deletedRowids)
	{
		[logEntryCache removeObjectForKey:rowid];
	}
}

/**
 * Internal method.
 *
 * This method is invoked with the changeset from a sibling connection.
**/
- (void)noteCommittedChanges:(SCDatabaseLoggerInternalChangeset *)changeset
{
	// This method must be invoked from within connectionQueue.
	// It may be invoked from:
	//
	// 1. [database noteCommittedChanges:fromConnection:]
	//   via dispatch_async(connectionQueue, ...)
	//
	// 2. [self  preReadTransaction:]
	//   via dispatch_X(connectionQueue) -> dispatch_sync(database->snapshotQueue)
	//
	// 3. [self preReadWriteTransaction:]
	//   via dispatch_X(connectionQueue) -> dispatch_sync(database->snapshotQueue)
	//
	// In case 1 (the common case) we can see IsOnConnectionQueueKey.
	// In case 2 & 3 (the edge cases) we can see IsOnSnapshotQueueKey.
	
	NSAssert(dispatch_get_specific(IsOnConnectionQueueKey) ||
	         dispatch_get_specific(logger->IsOnSnapshotQueueKey), @"Must be invoked within connectionQueue");
	
	// Grab the new snapshot.
	// This tells us the minimum snapshot we could get if we started a transaction right now.
	
	uint64_t changesetSnapshot = changeset.snapshot;
	
	if (changesetSnapshot <= dbSnapshot)
	{
		// We already processed this changeset.
		
		NSLogVerbose(@"Ignoring previously processed changeset %lu for connection %@",
		              (unsigned long)changesetSnapshot, self);
		
		return;
	}
	
	if (longLivedReadTransaction)
	{
		if (dispatch_get_specific(logger->IsOnSnapshotQueueKey))
		{
			// This method is being invoked from preReadTransaction:.
			// We are to process the changeset for it.
			
			[processedChangesets addObject:changeset];
		}
		else
		{
			// This method is being invoked from [database noteCommittedChanges:].
			// We cannot process the changeset yet.
			// We must wait for the longLivedReadTransaction to be reset.
			
			NSLogVerbose(@"Storing pending changeset %lu for connection %@",
			              (unsigned long)changesetSnapshot, self);
			
			[pendingChangesets addObject:changeset];
			return;
		}
	}
	
	// Changeset processing
	
	NSLogVerbose(@"Processing changeset %lu for connection %@",
	              (unsigned long)changesetSnapshot, self);
	
	dbSnapshot = changesetSnapshot;
	[self processChangeset:changeset];
}

@end
