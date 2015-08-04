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
#import "SCDatabaseLogger.h"
#import "SCDatabaseLoggerString.h"
#import "SCDatabaseLoggerPrivate.h"
#import "SCDatabaseLoggerChangeSet.h"
#import "SCDatabaseLoggerConnectionState.h"

#import <libkern/OSAtomic.h>
#import <mach/mach_time.h>

// We can't use DDLog() statements within the DDLog implementation.
// But we still want to leave our log statements for any future debugging,
// and to allow other developers to trace the implementation (which is a great learning tool).
//
// So we use primitive logging macros around NSLog.
// We maintain the NS prefix on the macros to be explicit about the fact that we're using NSLog.

#if DEBUG && robbie_hanson
  #define LOG_LEVEL 4
#else
  #define LOG_LEVEL 2
#endif

#define NSLogError(frmt, ...)    do{ if(LOG_LEVEL >= 1) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(LOG_LEVEL >= 2) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(LOG_LEVEL >= 3) NSLog((frmt), ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(LOG_LEVEL >= 4) NSLog((frmt), ##__VA_ARGS__); } while(0)

NSString *const SCDatabaseLoggerChangedNotification = @"SCDatabaseLoggerChangedNotification";


@implementation SCDatabaseLogger {

// Inherited from DDAbstractLogger
/*
@protected
	id <DDLogFormatter> formatter;
	
	dispatch_queue_t loggerQueue;
*/

// Declared in SCDatabaseLoggerPrivate.h
/*
	void *IsOnSnapshotQueueKey;
	void *IsOnWriteQueueKey;
	
	dispatch_queue_t snapshotQueue;
	dispatch_queue_t writeQueue;
	
	NSMutableArray *connectionStates;
	
*/
	NSUInteger maxAge;
	
	dispatch_queue_t checkpointQueue;
	
	NSMutableArray *_mustBeInsideLock_pendingLogEntries;
	NSMutableArray *_mustBeInsideLock_pendingLogEntryUUIDs;
	OSSpinLock pendingLogEntriesLock;
	NSUInteger pendingLogEntriesOffset;
	
	sqlite3 *db;
	NSString *databasePath;
#ifdef SQLITE_HAS_CODEC
	SCDatabaseLoggerCipherKeyBlock cipherKeyBlock;
#endif
	
	NSMutableArray *changesets;
	uint64_t snapshot;
	
	BOOL loggerQueue_isDatabaseReady;
	BOOL snapshotQueue_isDatabaseReady;
	SCDatabaseLoggerConnection *writeConnection;
	NSUInteger flushCount;
	
	NSString *sqliteVersion;
	uint64_t pageSize;
}

@dynamic databasePath;
#ifdef SQLITE_HAS_CODEC
@dynamic cipherKeyBlock;
#endif

@dynamic maxAge;

- (instancetype)init
{
	if ((self = [super init]))
	{
		maxAge = (60 * 60 * 24 * 7);
		
		_mustBeInsideLock_pendingLogEntries = [[NSMutableArray alloc] init];
		_mustBeInsideLock_pendingLogEntryUUIDs = [[NSMutableArray alloc] init];
		pendingLogEntriesLock = OS_SPINLOCK_INIT;
		
		changesets = [[NSMutableArray alloc] init];
		connectionStates = [[NSMutableArray alloc] init];
		
		snapshotQueue   = dispatch_queue_create("SCDatabaseLogger-Snapshot", NULL);
		writeQueue      = dispatch_queue_create("SCDatabaseLogger-Write", NULL);
		checkpointQueue = dispatch_queue_create("SCDatabaseLogger-Checkpoint", NULL);
		
		IsOnSnapshotQueueKey = &IsOnSnapshotQueueKey;
		dispatch_queue_set_specific(snapshotQueue, IsOnSnapshotQueueKey, IsOnSnapshotQueueKey, NULL);
		
		IsOnWriteQueueKey = &IsOnWriteQueueKey;
		dispatch_queue_set_specific(writeQueue, IsOnWriteQueueKey, IsOnWriteQueueKey, NULL);
	}
	return self;
}

- (void)dealloc
{
	if (db)
	{
		int status = sqlite3_close(db);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error in sqlite_close: %d %s", status, sqlite3_errmsg(db));
		}
		
		db = NULL;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSTimeInterval)maxAge
{
	// The design of this method is taken from the DDAbstractLogger implementation.
	// For extensive documentation please refer to the DDAbstractLogger implementation.

	// Note: The internal implementation MUST access the variable directly.
	// This method is designed explicitly for external access.
	//
	// Using "self." syntax to go through this method will cause immediate deadlock.
	// This is the intended result. Fix it by accessing the ivar directly.
	// Great strides have been take to ensure this is safe to do. Plus it's MUCH faster.

	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");

	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];

	__block NSTimeInterval result;

	dispatch_sync(globalLoggingQueue, ^{
		dispatch_sync(loggerQueue, ^{
			result = maxAge;
		});
	});

	return result;
}

- (void)setMaxAge:(NSTimeInterval)inInterval
{
	NSTimeInterval interval = fabs(inInterval);
	
    dispatch_block_t block = ^{ @autoreleasepool {
        
		if (maxAge != interval)
        {
            NSTimeInterval oldMaxAge = maxAge;
            NSTimeInterval newMaxAge = interval;
            
            maxAge = interval;
            
			// There are several possible situations here:
			// 
			// 1. The maxAge was previously enabled and it just got disabled.
			//    Nothing to do.
			// 
			// 2. The maxAge was previously disabled and it just got enabled.
			//    So we should perform an immediate flush (to delete any expired entries in the database).
			// 
			// 3. The maxAge was increased.
			//    Nothing to do.
			// 
			// 4. The maxAge was decreased.
			//    So we should perform an immediate flush (to delete any expired entries in the database).
			
            BOOL shouldDeleteNow = NO;
			
			NSAssert(oldMaxAge >= 0.0, @"Forgot to fabs() the maxAge somewhere.");
			NSAssert(newMaxAge >= 0.0, @"Forgot to fabs() the maxAge somewhere.");
			
            if (oldMaxAge > 0.0)
            {
				if (oldMaxAge > newMaxAge)
                {
					// Situation #2 :
					//
					// The maxAge was decreased.
					// So we should perform an immediate flush (to delete any expired entries in the database).
					
                    shouldDeleteNow = YES;
				}
			}
			else // oldMaxAge == 0.0
			{
				if (newMaxAge > 0.0)
            	{
					// Situation #4 :
					//
					// The maxAge was previously disabled and it just got enabled.
					// So we should perform an immediate flush (to delete any expired entries in the database).
					
					shouldDeleteNow = YES;
				}
			}
			
            if (shouldDeleteNow)
            {
				[self flushToDatabase];
            }
        }
    }};
    
    // The design of the setter logic below is taken from the DDAbstractLogger implementation.
    // For documentation please refer to the DDAbstractLogger implementation.
	
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	
	dispatch_queue_t globalLoggingQueue = [DDLog loggingQueue];
	
	dispatch_async(globalLoggingQueue, ^{
		dispatch_async(loggerQueue, block);
	});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SQLite - Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)databasePath
{
	__block NSString *result = nil;
	
	dispatch_block_t block = ^{
		result = databasePath;
	};
	
	if ([self isOnInternalLoggerQueue])
		block();
	else
		dispatch_sync(loggerQueue, block);
	
	return result;
}

#ifdef SQLITE_HAS_CODEC
- (SCDatabaseLoggerCipherKeyBlock)cipherKeyBlock
{
	__block SCDatabaseLoggerCipherKeyBlock result = NULL;
	
	dispatch_block_t block = ^{
		result = cipherKeyBlock;
	};
	
	if ([self isOnInternalLoggerQueue])
		block();
	else
		dispatch_sync(loggerQueue, block);
	
	return result;
}
#endif

/**
 * Configures the underlying sqlite database for the logger.
 * Until this method is invoked, the logger is simply buffering logEntries in memory.
**/
- (void)setupDatabaseWithPath:(NSString *)inDatabasePath completion:(void (^)(BOOL ready))completionBlock
{
	dispatch_async(loggerQueue, ^{
		
		if (databasePath != nil)
		{
			NSLogWarn(@"The database is already setup !");
			
			if (completionBlock) {
				dispatch_async(dispatch_get_main_queue(), ^{
					completionBlock(NO);
				});
			}
			return;
		}
		
		databasePath = [inDatabasePath stringByStandardizingPath];
		
		[self _setupDatabaseWithCompletion:completionBlock];
	});
}

#ifdef SQLITE_HAS_CODEC
/**
 * Configures the underlying sqlite database for the logger.
 * Until this method is invoked, the logger is simply buffering logEntries in memory.
**/
- (void)setupDatabaseWithPath:(NSString *)inDatabasePath
               cipherKeyBlock:(SCDatabaseLoggerCipherKeyBlock)inCipherKeyBlock
                   completion:(void (^)(BOOL ready))completionBlock
{
	dispatch_async(loggerQueue, ^{
		
		if (databasePath != nil)
		{
			NSLogWarn(@"The database is already setup !");
			
			if (completionBlock) {
				dispatch_async(dispatch_get_main_queue(), ^{
					completionBlock(NO);
				});
			}
			return;
		}
		
		databasePath = [inDatabasePath stringByStandardizingPath];
		cipherKeyBlock = inCipherKeyBlock;
		
		[self _setupDatabaseWithCompletion:completionBlock];
	});
}
#endif

- (void)_setupDatabaseWithCompletion:(void (^)(BOOL ready))completionBlock
{
	dispatch_queue_t bgQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(bgQ, ^{ @autoreleasepool {
		
		BOOL result = [self openConfigCreate];
		
		if (result)
		{
			dispatch_async(snapshotQueue, ^{ @autoreleasepool {
				
				[self prepare];
				
				snapshotQueue_isDatabaseReady = YES;
				
				for (SCDatabaseLoggerConnectionState *state in connectionStates)
				{
					// Create strong reference (state->connection is weak)
					__strong SCDatabaseLoggerConnection *connection = state->connection;
					
					if (connection)
					{
						dispatch_async(connection->connectionQueue, ^{ @autoreleasepool {
							
							[connection prepareDatabase];
						}});
					}
				}
			}});
			
			dispatch_async(loggerQueue, ^{ @autoreleasepool {
				
				loggerQueue_isDatabaseReady = YES;
				[self maybeFlushToDatabase];
			}});
		}
		
		if (completionBlock) {
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(result);
			});
		}
	}});
}

- (BOOL)openConfigCreate
{
	if (databasePath == nil) return NO;
	
	__block BOOL isNewDatabaseFile = ![[NSFileManager defaultManager] fileExistsAtPath:databasePath];
	
	BOOL(^openConfigCreate)(void) = ^BOOL (void) { @autoreleasepool {
		
		BOOL result = YES;
		
		if (result) result = [self openDatabase];
	#ifdef SQLITE_HAS_CODEC
		if (result) result = [self configureEncryptionForDatabase:db];
	#endif
		if (result) result = [self configureDatabase:isNewDatabaseFile];
		if (result) result = [self createTables];
		
		if (!result && db)
		{
			sqlite3_close(db);
			db = NULL;
		}
		
		return result;
	}};
	
	BOOL result = openConfigCreate();
	if (!result)
	{
		// There are a few reasons why the database might not open.
		// One possibility is if the database file has become corrupt.
		//
		// Try to delete the corrupt database file.
		
		NSError *error = nil;
		BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:databasePath error:&error];
		
		if (deleted)
		{
			isNewDatabaseFile = YES;
			result = openConfigCreate();
			
			if (result) {
				NSLogInfo(@"Database corruption resolved. Deleted corrupt file. (name=%@)",
							[databasePath lastPathComponent]);
			}
			else {
				NSLogError(@"Database corruption unresolved. (name=%@)", [databasePath lastPathComponent]);
			}
		}
		else
		{
			NSLogError(@"Error deleting corrupt database file: %@", error);
		}
	}
	
	return result;
}

/**
 * Attempts to open (or create & open) the database connection.
**/
- (BOOL)openDatabase
{
	// Open the database connection.
	//
	// We use SQLITE_OPEN_NOMUTEX to use the multi-thread threading mode,
	// as we will be serializing access to the connection externally.
	
	int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX | SQLITE_OPEN_PRIVATECACHE;
	
	int status = sqlite3_open_v2([databasePath UTF8String], &db, flags, NULL);
	if (status != SQLITE_OK)
	{
		// There are a few reasons why the database might not open.
		// One possibility is if the database file has become corrupt.
		
		// Sometimes the open function returns a db to allow us to query it for the error message.
		// The openConfigCreate block will close it for us.
		if (db) {
			NSLogError(@"Error opening database: %d %s", status, sqlite3_errmsg(db));
		}
		else {
			NSLogError(@"Error opening database: %d", status);
		}
		
		return NO;
	}
	
	return YES;
}

#ifdef SQLITE_HAS_CODEC
/**
 * Configures database encryption via SQLCipher.
**/
- (BOOL)configureEncryptionForDatabase:(sqlite3 *)sqlite
{
	if (cipherKeyBlock)
	{
		NSData *keyData = cipherKeyBlock();
		
		if (keyData == nil)
		{
			NSAssert(NO, @"SCDatabaseLogger.cipherKeyBlock cannot return nil!");
			return NO;
		}
		
		int status = sqlite3_key(sqlite, [keyData bytes], (int)[keyData length]);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error setting SQLCipher key: %d %s", status, sqlite3_errmsg(sqlite));
			return NO;
		}
	}
	
	return YES;
}
#endif

/**
 * Configures the database connection.
 * This mainly means enabling WAL mode, and configuring the auto-checkpoint.
**/
- (BOOL)configureDatabase:(BOOL)isNewDatabaseFile
{
	int status;
	
	// Set mandatory pragmas
	
	status = sqlite3_exec(db, "PRAGMA journal_mode = WAL;", NULL, NULL, NULL);
	if (status != SQLITE_OK)
	{
		NSLogError(@"Error setting PRAGMA journal_mode: %d %s", status, sqlite3_errmsg(db));
		return NO;
	}
	
	if (isNewDatabaseFile)
	{
		status = sqlite3_exec(db, "PRAGMA auto_vacuum = FULL; VACUUM;", NULL, NULL, NULL);
		if (status != SQLITE_OK)
		{
			NSLogError(@"Error setting PRAGMA auto_vacuum: %d %s", status, sqlite3_errmsg(db));
		}
	}
	
	// Set synchronous to normal for increased performance (at a slight loss of durability).
	//
	// (This doesn't affect checkpoint operations, which will fsync regardless.)
	
	status = sqlite3_exec(db, "PRAGMA synchronous = NORMAL;", NULL, NULL, NULL);
	if (status != SQLITE_OK)
	{
		NSLogError(@"Error setting PRAGMA synchronous: %d %s", status, sqlite3_errmsg(db));
		// This isn't critical, so we can continue.
	}
	
	// Set journal_size_limit to zero.
	//
	// We only need to do set this pragma for THIS connection,
	// because it is the only connection that performs checkpoints.
	
	NSString *stmt =
	  [NSString stringWithFormat:@"PRAGMA journal_size_limit = %d;", 0];
	
	status = sqlite3_exec(db, [stmt UTF8String], NULL, NULL, NULL);
	if (status != SQLITE_OK)
	{
		NSLogError(@"Error setting PRAGMA journal_size_limit: %d %s", status, sqlite3_errmsg(db));
		// This isn't critical, so we can continue.
	}
	
	// Disable autocheckpointing.
	//
	// We have our own optimized checkpointing algorithm built-in.
	// It knows the state of every active connection for the database,
	// so it can invoke the checkpoint methods at the precise time in which a checkpoint can be most effective.
	
	sqlite3_wal_autocheckpoint(db, 0);
	
	return YES;
}

/**
 * Creates the database table(s) if needed.
**/
- (BOOL)createTables
{
	int status;
	
	char *createScTableStatement =
	    "CREATE TABLE IF NOT EXISTS \"sc\""
	    " (\"key\" TEXT PRIMARY KEY, "
	    "  \"data\" BLOB"
	    " );";
	
	status = sqlite3_exec(db, createScTableStatement, NULL, NULL, NULL);
	if (status != SQLITE_OK)
	{
		NSLogError(@"Failed creating 'sc' table: %d %s", status, sqlite3_errmsg(db));
		return NO;
	}
	
	char *createLogsTableStatement =
	    "CREATE TABLE IF NOT EXISTS \"logs\""
	    " (\"rowid\" INTEGER PRIMARY KEY,"
	    "  \"timestamp\" REAL NOT NULL,"
	    "  \"context\" INTEGER NOT NULL,"
	    "  \"flags\" INTEGER NOT NULL,"
	    "  \"tag\" TEXT,"
	    "  \"message\" TEXT"
	    " );";
	
	status = sqlite3_exec(db, createLogsTableStatement, NULL, NULL, NULL);
	if (status != SQLITE_OK)
	{
		NSLogError(@"Failed creating 'logs' table: %d %s", status, sqlite3_errmsg(db));
		return NO;
	}
	
	char *createIndexStatement =
	    "CREATE INDEX IF NOT EXISTS \"timestamp\" ON \"logs\" ( \"timestamp\" );";
	
	status = sqlite3_exec(db, createIndexStatement, NULL, NULL, NULL);
	if (status != SQLITE_OK)
	{
		NSLogError(@"Failed creating index on 'log' table: %d %s", status, sqlite3_errmsg(db));
		return NO;
	}
	
	return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SQLite - Prepare
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is run asynchronously on the snapshotQueue.
**/
- (void)prepare
{
	// Initialize snapshot
	
	snapshot = 0;
	
	// Write it to disk (replacing any previous value from last app run)
	
	[self beginTransaction];
	{
		sqliteVersion = [self fetchSqliteVersion];
		NSLogVerbose(@"sqlite version = %@", sqliteVersion);
		
		pageSize = [self fetchPageSize];
		
		[self writeSnapshot];
	}
	[self commitTransaction];
	[self asyncCheckpoint:snapshot];
}

- (void)beginTransaction
{
	int status = status = sqlite3_exec(db, "BEGIN TRANSACTION;", NULL, NULL, NULL);
	if (status != SQLITE_OK)
	{
		NSLogError(@"Error in '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
	}
}

- (void)commitTransaction
{
	int status = status = sqlite3_exec(db, "COMMIT TRANSACTION;", NULL, NULL, NULL);
	if (status != SQLITE_OK)
	{
		NSLogError(@"Error in '%@': %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
	}
}

- (NSString *)fetchSqliteVersion
{
	sqlite3_stmt *statement;
	
	int status = sqlite3_prepare_v2(db, "SELECT sqlite_version();", -1, &statement, NULL);
	if (status != SQLITE_OK)
	{
		NSLogError(@"%@: Error creating statement! %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		return nil;
	}
	
	NSString *version = nil;
	
	status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		const unsigned char *text = sqlite3_column_text(statement, SQLITE_COLUMN_START);
		int textSize = sqlite3_column_bytes(statement, SQLITE_COLUMN_START);
		
		version = [[NSString alloc] initWithBytes:text length:textSize encoding:NSUTF8StringEncoding];
	}
	else
	{
		NSLogError(@"%@: Error executing statement! %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
	}
	
	sqlite3_finalize(statement);
	statement = NULL;
	
	return version;
}

- (uint64_t)fetchPageSize
{
	// If anything goes wrong, we should return a valid pageSize value.
	uint64_t defaultResult = 4096;
	
	sqlite3_stmt *statement;
	
	int status = sqlite3_prepare_v2(db, "PRAGMA page_size;", -1, &statement, NULL);
	if (status != SQLITE_OK)
	{
		NSLogError(@"%@: Error creating statement! %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		return defaultResult;
	}
	
	int64_t result = 0;
	
	status = sqlite3_step(statement);
	if (status == SQLITE_ROW)
	{
		result = sqlite3_column_int64(statement, SQLITE_COLUMN_START);
	}
	else if (status == SQLITE_ERROR)
	{
		NSLogError(@"%@: Error executing statement! %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
	}
	
	sqlite3_finalize(statement);
	statement = NULL;
	
	if (result > 0)
		return (uint64_t)result;
	else
		return defaultResult;
}

- (void)writeSnapshot
{
	int status;
	sqlite3_stmt *statement;
	
	char *stmt = "INSERT OR REPLACE INTO \"sc\" (\"key\", \"data\") VALUES (?, ?);";
	
	int const bind_idx_key  = SQLITE_BIND_START + 0;
	int const bind_idx_data = SQLITE_BIND_START + 1;
	
	status = sqlite3_prepare_v2(db, stmt, (int)strlen(stmt)+1, &statement, NULL);
	if (status != SQLITE_OK)
	{
		NSLogError(@"%@: Error creating statement: %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
	}
	else
	{
		char *key = "snapshot";
		sqlite3_bind_text(statement, bind_idx_key, key, (int)strlen(key), SQLITE_STATIC);
		
		sqlite3_bind_int64(statement, bind_idx_data, (sqlite3_int64)snapshot);
		
		status = sqlite3_step(statement);
		if (status != SQLITE_DONE)
		{
			NSLogError(@"%@: Error in statement: %d %s", THIS_METHOD, status, sqlite3_errmsg(db));
		}
		
		sqlite3_finalize(statement);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark PendingLogEntries
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addPendingLogEntry:(SCDatabaseLogEntry *)logEntry
{
	NSUUID *uuid = [[NSUUID alloc] init];
	
	OSSpinLockLock(&pendingLogEntriesLock);
	{
		[_mustBeInsideLock_pendingLogEntries addObject:logEntry];
		[_mustBeInsideLock_pendingLogEntryUUIDs addObject:uuid];
	}
	OSSpinLockUnlock(&pendingLogEntriesLock);
}

- (BOOL)hasPendingLogEntries
{
	BOOL result;
	
	OSSpinLockLock(&pendingLogEntriesLock);
	{
		result = (_mustBeInsideLock_pendingLogEntries.count > 0);
	}
	OSSpinLockUnlock(&pendingLogEntriesLock);
	
	return result;
}

- (void)getPendingLogEntriesForWrite:(NSArray **)entriesPtr uuids:(NSArray **)uuidsPtr
{
	NSArray *entries = nil;
	NSArray *uuids = nil;
	
	OSSpinLockLock(&pendingLogEntriesLock);
	{
		if (pendingLogEntriesOffset == 0)
		{
			entries = [_mustBeInsideLock_pendingLogEntries copy];
			uuids   = [_mustBeInsideLock_pendingLogEntryUUIDs copy];
		}
		else if (pendingLogEntriesOffset < _mustBeInsideLock_pendingLogEntries.count)
		{
			NSRange range;
			range.location = pendingLogEntriesOffset;
			range.length = _mustBeInsideLock_pendingLogEntries.count - pendingLogEntriesOffset;
			
			entries = [_mustBeInsideLock_pendingLogEntries subarrayWithRange:range];
			uuids   = [_mustBeInsideLock_pendingLogEntryUUIDs subarrayWithRange:range];
		}
		
		pendingLogEntriesOffset = _mustBeInsideLock_pendingLogEntries.count;
	}
	OSSpinLockUnlock(&pendingLogEntriesLock);
	
	if (entriesPtr) *entriesPtr = entries;
	if (uuidsPtr) *uuidsPtr = uuids;
}

- (void)getPendingLogEntriesForRead:(NSArray **)entriesPtr uuids:(NSArray **)uuidsPtr
{
	NSAssert(dispatch_get_specific(IsOnSnapshotQueueKey), @"Must go through snapshotQueue for atomic access.");
	
	NSArray *entries = nil;
	NSArray *uuids = nil;
	
	OSSpinLockLock(&pendingLogEntriesLock);
	{
		entries = [_mustBeInsideLock_pendingLogEntries copy];
		uuids   = [_mustBeInsideLock_pendingLogEntryUUIDs copy];
	}
	OSSpinLockUnlock(&pendingLogEntriesLock);
	
	if (entriesPtr) *entriesPtr = entries;
	if (uuidsPtr) *uuidsPtr = uuids;
}

- (void)removePendingLogEntries:(NSUInteger)count
{
	NSAssert(dispatch_get_specific(IsOnSnapshotQueueKey), @"Must go through snapshotQueue for atomic access.");
	
	if (count == 0) return;
	
	OSSpinLockLock(&pendingLogEntriesLock);
	{
		NSRange range = NSMakeRange(0, count);
		
		[_mustBeInsideLock_pendingLogEntries removeObjectsInRange:range];
		[_mustBeInsideLock_pendingLogEntryUUIDs removeObjectsInRange:range];
		
		if (pendingLogEntriesOffset > count)
			pendingLogEntriesOffset -= count;
		else
			pendingLogEntriesOffset = 0;
	}
	OSSpinLockUnlock(&pendingLogEntriesLock);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)flushToDatabase
{
	NSAssert([self isOnInternalLoggerQueue], @"Must go through loggerQueue for thread-safety.");
	
	// Get the latest batch of pendingLogEntries we need to write to the database.
	//
	// Note: If we're currently in the middle of an existing flush, then the snapshotLogEntries method
	// will only return logEntries that were appended after the last time we invoked snapshotLogEntries.
	
	NSArray *pendingLogEntries = nil;
	NSArray *uuids = nil;
	
	[self getPendingLogEntriesForWrite:&pendingLogEntries uuids:&uuids];
	NSTimeInterval maxAgeSnapshot = maxAge;
	
	if (pendingLogEntries.count == 0 && maxAgeSnapshot <= 0.0)
	{
		// Nothing to flush
		return;
	}
	
	if (writeConnection == nil)
	{
		writeConnection = [self newConnection];
		writeConnection.cacheEnabled = NO;
	}
	
	flushCount++;
	[writeConnection asyncReadWriteWithBlock:^(SCDatabaseLoggerWriteTransaction *transaction) {
		
		// Delete old entries FIRST.
		// This reduces overhead, and ensures we never delete what we just inserted.
		[transaction findAndDeleteOldLogEntries:maxAgeSnapshot];
		
		// Then perform our insert(s).
		[transaction insertLogEntries:pendingLogEntries withUUIDs:uuids];
		
	} completionQueue:loggerQueue completionBlock:^{
		
		flushCount--;
	}];
}

- (void)maybeFlushToDatabase
{
	NSAssert([self isOnInternalLoggerQueue], @"Must go through loggerQueue for thread-safety.");
	
	// Do we have a database to flush to ?
	if (loggerQueue_isDatabaseReady)
	{
		// Do we have any reason to flush ?
		if ([self hasPendingLogEntries] || maxAge > 0.0)
		{
			// Are we in the middle of flush already ?
			if (flushCount == 0)
			{
				[self flushToDatabase];
			}
		}
	}
}

- (void)maybeFlushToDatabaseAfterAppendingLogEntry
{
	NSAssert([self isOnInternalLoggerQueue], @"Must go through loggerQueue for thread-safety.");
	
	// Do we have a database to flush to ?
	if (loggerQueue_isDatabaseReady)
	{
		// Are we in the middle of flush already ?
		if (flushCount == 0)
		{
			[self flushToDatabase];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark DDLogger Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)willRemoveLogger
{
	dispatch_async(loggerQueue, ^{ @autoreleasepool {
		
		[self flushToDatabase];
		writeConnection = nil;
	}});
}

- (void)logMessage:(DDLogMessage *)logMessage
{
	// This method is invoked on the loggerQueue.
	
	NSString *formattedMessage = nil;
	if (formatter)
	{
		formattedMessage = [formatter formatLogMessage:logMessage];
		if (formattedMessage == nil) {
			return;
		}
	}
	
	SCDatabaseLogEntry *logEntry =
	  [[SCDatabaseLogEntry alloc] initWithLogMessage:logMessage formattedMessage:formattedMessage];
	
	[self addPendingLogEntry:logEntry];
	[self maybeFlushToDatabaseAfterAppendingLogEntry];
}

- (void)flush
{
	// Todo: [self flushToDatabase] is asynchronous.
	// For this method, we may need to make a synchronous version of flushToDatabase.
	
	dispatch_sync(loggerQueue, ^{ @autoreleasepool {
		
		[self flushToDatabase];
	}});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connection Handling
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is called from newConnection, either above or from a subclass.
**/
- (void)addConnection:(SCDatabaseLoggerConnection *)connection
{
	// Add the connection to the state table.
	
	dispatch_sync(snapshotQueue, ^{ @autoreleasepool {
		
		// Add the connection to the state table
		
		SCDatabaseLoggerConnectionState *state =
		  [[SCDatabaseLoggerConnectionState alloc] initWithConnection:connection];
		[connectionStates addObject:state];
		
		NSLogVerbose(@"Created new connection(%p) for <%@ %p: databaseName=%@, connectionCount=%lu>",
		              connection, [self class], self, [databasePath lastPathComponent],
		              (unsigned long)[connectionStates count]);
		
		// Tell the connection to prepare its database (if needed)
		
		if (snapshotQueue_isDatabaseReady)
		{
			dispatch_async(connection->connectionQueue, ^{ @autoreleasepool {
				
				[connection prepareDatabase];
			}});
		}
	}});
}

/**
 * This method is called from YapDatabaseConnection's dealloc method.
**/
- (void)removeConnection:(SCDatabaseLoggerConnection *)connection
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSUInteger index = 0;
		for (SCDatabaseLoggerConnectionState *state in connectionStates)
		{
			if (state->connection == connection)
			{
				[connectionStates removeObjectAtIndex:index];
				break;
			}
			
			index++;
		}
		
		NSLogVerbose(@"Removed connection(%p) from <%@ %p: databaseName=%@, connectionCount=%lu>",
					  connection, [self class], self, [databasePath lastPathComponent],
					  (unsigned long)[connectionStates count]);
	}};
	
	// We prefer to invoke this method synchronously.
	//
	// The connection may be the last object retaining the database.
	// It's easier to trace object deallocations when they happen in a predictable order.
	
	if (dispatch_get_specific(IsOnSnapshotQueueKey))
		block();
	else
		dispatch_sync(snapshotQueue, block);
}

- (SCDatabaseLoggerConnection *)newConnection
{
	SCDatabaseLoggerConnection *connection = [[SCDatabaseLoggerConnection alloc] initWithLogger:self];
	
	[self addConnection:connection];
	return connection;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Snapshot Architecture
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The snapshot represents when the database was last modified by a read-write transaction.
 * This information isn persisted to the 'sc' database, and is separately held in memory.
 * It serves multiple purposes.
 *
 * First is assists in validation of a connection's cache.
 * When a connection begins a new transaction, it may have items sitting in the cache.
 * However the connection doesn't know if the items are still valid because another connection may have made changes.
 *
 * The snapshot also assists in correcting for a race condition.
 * It order to minimize blocking we allow read-write transactions to commit outside the context
 * of the snapshotQueue. This is because the commit may be a time consuming operation, and we
 * don't want to block read-only transactions during this period.
 *
 * The snapshot is simply a 64-bit integer.
 * It is reset when the SCDatabaseLogger instance is initialized,
 * and incremented by each read-write transaction (if changes are actually made).
**/
- (uint64_t)snapshot
{
	if (dispatch_get_specific(IsOnSnapshotQueueKey))
	{
		// Very common case.
		// This method is called on just about every transaction.
		return snapshot;
	}
	else
	{
		__block uint64_t result = 0;
		
		dispatch_sync(snapshotQueue, ^{
			result = snapshot;
		});
		
		return result;
	}
}

/**
 * This method is only accessible from within the snapshotQueue.
 * 
 * Prior to starting the sqlite commit, the connection must report its changeset to the database.
 * The database will store the changeset, and provide it to other connections if needed (due to a race condition).
 * 
 * The following MUST be in the dictionary:
 *
 * - snapshot : NSNumber with the changeset's snapshot
**/
- (void)notePendingChanges:(SCDatabaseLoggerInternalChangeset *)pendingChangeset
{
	NSAssert(dispatch_get_specific(IsOnSnapshotQueueKey), @"Must go through snapshotQueue for atomic access.");
	
	// We're preparing to start the sqlite commit.
	// We save the changeset in advance to handle possible edge cases.
	
	[changesets addObject:pendingChangeset];
	
	NSLogVerbose(@"Adding pending changeset %llu for database: %@", pendingChangeset.snapshot, self);
}

/**
 * This method is only accessible from within the snapshotQueue.
 *
 * This method is used by a transaction to catch-up to its database snapshot (if needed).
**/
- (NSArray *)pendingAndCommittedChangesSince:(uint64_t)connectionSnapshot until:(uint64_t)maxSnapshot
{
	NSAssert(dispatch_get_specific(IsOnSnapshotQueueKey), @"Must go through snapshotQueue for atomic access.");
	
	NSUInteger capacity = (NSUInteger)(maxSnapshot - connectionSnapshot);
	NSMutableArray *relevantChangesets = [NSMutableArray arrayWithCapacity:capacity];
	
	for (SCDatabaseLoggerInternalChangeset *changeset in changesets)
	{
		uint64_t changesetSnapshot = changeset.snapshot;
		
		if ((changesetSnapshot > connectionSnapshot) && (changesetSnapshot <= maxSnapshot))
		{
			[relevantChangesets addObject:changeset];
		}
	}
	
	return relevantChangesets;
}

/**
 * This method is only accessible from within the snapshotQueue.
 *
 * This method is used by a transaction to fast-forward itself beyond its database snapshot.
**/
- (NSArray *)pendingAndCommittedChangesAfter:(int64_t)afterSnapshot
{
	NSAssert(dispatch_get_specific(IsOnSnapshotQueueKey), @"Must go through snapshotQueue for atomic access.");
	
	NSUInteger remaining = changesets.count;
	NSMutableArray *relevantChangesets = nil;
	
	for (SCDatabaseLoggerInternalChangeset *changeset in changesets)
	{
		uint64_t changesetSnapshot = changeset.snapshot;
		
		if (changesetSnapshot > afterSnapshot)
		{
			if (relevantChangesets == nil)
				relevantChangesets = [NSMutableArray arrayWithCapacity:remaining];
			
			[relevantChangesets addObject:changeset];
		}
		else
		{
			remaining--;
		}
	}
	
	return relevantChangesets;
}

/**
 * This method is only accessible from within the snapshotQueue.
 *
 * Upon completion of a readwrite transaction, the connection must report its changeset to the database.
 * The database will then forward the changes to all other connections.
**/
- (void)noteCommittedChanges:(SCDatabaseLoggerInternalChangeset *)changeset
              fromConnection:(SCDatabaseLoggerConnection *)sender
{
	NSAssert(dispatch_get_specific(IsOnSnapshotQueueKey), @"Must go through snapshotQueue for atomic access.");
	
	// The sender has finished the sqlite commit, and all data is now written to disk.
	
	// Update the in-memory snapshot,
	// which represents the most recent snapshot of the last committed readwrite transaction.
	
	snapshot = changeset.snapshot;
	
	// Forward the changeset to all other connections so they can perform any needed updates.
	// Generally this means updating the in-memory components such as the cache.
	
	dispatch_group_t group = NULL;
	
	for (SCDatabaseLoggerConnectionState *state in connectionStates)
	{
		if (state->connection != sender)
		{
			// Create strong reference (state->connection is weak)
			__strong SCDatabaseLoggerConnection *connection = state->connection;
			
			if (connection)
			{
				if (group == NULL)
					group = dispatch_group_create();
				
				dispatch_group_async(group, connection->connectionQueue, ^{ @autoreleasepool {
					
					[connection noteCommittedChanges:changeset];
				}});
			}
		}
	}
	
	// Schedule block to be executed once all connections have processed the changes.

	dispatch_block_t block = ^{
		
		// All connections have now processed the changes.
		// So we no longer need to retain the changeset in memory.
		
		NSLogVerbose(@"Dropping processed changeset %llu for database: %@", changeset.snapshot, self);
		
		[changesets removeObjectAtIndex:0];
	};
	
	if (group)
		dispatch_group_notify(group, snapshotQueue, block);
	else
		block();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Manual Checkpointing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static BOOL const SC_PRINT_WAL_SIZE = NO;

/**
 * This method should be called whenever the maximum checkpointable snapshot is incremented.
 * That is, the state of every connection is known to the system.
 * And a snaphot cannot be checkpointed until every connection is at or past that snapshot.
 * Thus, we can know the point at which a snapshot becomes checkpointable,
 * and we can thus optimize the checkpoint invocations such that
 * each invocation is able to checkpoint one or more commits.
**/
- (void)asyncCheckpoint:(uint64_t)maxCheckpointableSnapshot
{
	__weak SCDatabaseLogger *weakSelf = self;
	
	dispatch_async(checkpointQueue, ^{ @autoreleasepool {
	#pragma clang diagnostic push
	#pragma clang diagnostic warning "-Wimplicit-retain-self"
		
		__strong SCDatabaseLogger *strongSelf = weakSelf;
		if (strongSelf == nil) return;
		
		NSLogVerbose(@"Checkpointing up to snapshot %llu", maxCheckpointableSnapshot);
		
		if ((LOG_LEVEL >= 4) && SC_PRINT_WAL_SIZE)
		{
			NSString *walFilePath = [strongSelf.databasePath stringByAppendingString:@"-wal"];
			
			NSDictionary *walAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:walFilePath error:NULL];
			unsigned long long walFileSize = [walAttr fileSize];
			
			NSLogVerbose(@"Pre-checkpoint file size: %@",
			  [NSByteCountFormatter stringFromByteCount:(long long)walFileSize
			                                 countStyle:NSByteCountFormatterCountStyleFile]);
		}
		
		// We're ready to checkpoint more frames.
		//
		// So we're going to execute a passive checkpoint.
		// That is, without disrupting any connections, we're going to write pages from the WAL into the database.
		// The checkpoint can only write pages from snapshots if all connections are at or beyond the snapshot.
		// Thus, this method is only called by a connection that moves the min snapshot forward.
		
		int toalFrameCount = 0;
		int checkpointedFrameCount = 0;
		
		int result = sqlite3_wal_checkpoint_v2(strongSelf->db, "main", SQLITE_CHECKPOINT_PASSIVE,
		                                       &toalFrameCount, &checkpointedFrameCount);
		
		// frameCount      = total number of frames in the log file
		// checkpointCount = total number of checkpointed frames
		//                  (including any that were already checkpointed before the function was called)
		
		if (result != SQLITE_OK)
		{
			if (result == SQLITE_BUSY) {
				NSLogVerbose(@"sqlite3_wal_checkpoint_v2 returned SQLITE_BUSY");
			}
			else {
				NSLogWarn(@"sqlite3_wal_checkpoint_v2 returned error code: %d", result);
			}
			
			return;// from_block
		}
		
		NSLogVerbose(@"Post-checkpoint (mode=passive) (snapshot=%llu): frames(%d) checkpointed(%d)",
		              maxCheckpointableSnapshot, toalFrameCount, checkpointedFrameCount);
		
		if ((LOG_LEVEL >= 4) && SC_PRINT_WAL_SIZE)
		{
			NSString *walFilePath = [strongSelf.databasePath stringByAppendingString:@"-wal"];
			
			NSDictionary *walAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:walFilePath error:NULL];
			unsigned long long walFileSize = [walAttr fileSize];
			
			NSLogVerbose(@"Post-checkpoint file size: %@",
			  [NSByteCountFormatter stringFromByteCount:(long long)walFileSize
			                                 countStyle:NSByteCountFormatterCountStyleFile]);
		}
		
		// Have we checkpointed the entire WAL yet?
		
		if (toalFrameCount == checkpointedFrameCount)
		{
			// We've checkpointed every single frame in the WAL.
			// This means the next read-write transaction may be able to reset the WAL (instead of appending to it).
			//
			// However, the WAL reset will get spoiled if there are active read-only transactions that
			// were started before our checkpoint finished, and continue to exist during the next read-write.
			// It's not a big deal if the occasional read-only transaction happens to spoil the WAL reset.
			// In those cases, the WAL generally gets reset shortly thereafter (on a subsequent write).
			// Long-lived read transactions are a different case entirely.
			// These transactions spoil it every single time, and could potentially cause the WAL to grow indefinitely.
			//
			// The solution is to notify active long-lived connections, and tell them to re-begin their transaction
			// on the same snapshot. But this time the sqlite machinery will read directly from the database,
			// and thus unlock the WAL so it can be reset.
			
			dispatch_async(strongSelf->snapshotQueue, ^{
				
				for (SCDatabaseLoggerConnectionState *state in strongSelf->connectionStates)
				{
					if (state->longLivedReadTransaction &&
					    state->lastTransactionSnapshot == strongSelf->snapshot)
					{
						[state->connection maybeResetLongLivedReadTransaction];
					}
				}
			});
		}
		
		// Take steps to ensure the WAL gets reset/truncated (if needed).
		
		uint64_t const aggressiveWALTruncationSize = (1024 * 1024);
		
		uint64_t walApproximateFileSize = toalFrameCount * strongSelf->pageSize;
		
		if (walApproximateFileSize >= aggressiveWALTruncationSize)
		{
			int64_t lastCheckpointTime = mach_absolute_time();
			[self aggressiveTryTruncateLargeWAL:lastCheckpointTime];
		}
		
	#pragma clang diagnostic pop
	}});
}

- (void)aggressiveTryTruncateLargeWAL:(int64_t)lastCheckpointTime
{
	__weak SCDatabaseLogger *weakSelf = self;
	
	dispatch_async(writeQueue, ^{
		
		dispatch_sync(checkpointQueue, ^{ @autoreleasepool {
		#pragma clang diagnostic push
		#pragma clang diagnostic warning "-Wimplicit-retain-self"
			
			__strong SCDatabaseLogger *strongSelf = weakSelf;
			if (strongSelf == nil) return;
			
			// First we set an adequate busy timeout on our database connection.
			// We're going to run a non-passive checkpoint.
			// Which may cause it to busy-wait while waiting on read transactions to complete.
			
			sqlite3_busy_timeout(strongSelf->db, 2000); // milliseconds
			
			// Can we use SQLITE_CHECKPOINT_TRUNCATE ?
			//
			// This feature was added in sqlite v3.8.8.
			// But it was buggy until v3.8.8.2 when the following fix was added:
			//
			//   "Enhance sqlite3_wal_checkpoint_v2(TRUNCATE) interface so that it truncates the
			//    WAL file even if there is no checkpoint work to be done."
			//
			//   http://www.sqlite.org/changes.html
			//
			// It is often the case, when we call checkpoint here, that there is no checkpoint work to be done.
			// So we really can't depend on it until 3.8.8.2
			
			int checkpointMode = SQLITE_CHECKPOINT_RESTART;
			
			// Remember: The compiler defines (SQLITE_VERSION, SQLITE_VERSION_NUMBER) only tell us
			// what version we're compiling against. But we may encounter an earlier sqlite version at runtime.
			
		#ifndef SQLITE_VERSION_NUMBER_3_8_8
		#define SQLITE_VERSION_NUMBER_3_8_8 3008008
		#endif
			
		#if SQLITE_VERSION_NUMBER > SQLITE_VERSION_NUMBER_3_8_8
			
			checkpointMode = SQLITE_CHECKPOINT_TRUNCATE;
			
		#elif SQLITE_VERSION_NUMBER == SQLITE_VERSION_NUMBER_3_8_8
			
			NSComparisonResult cmp = [strongSelf->sqliteVersion compare:@"3.8.8.2" options:NSNumericSearch];
			if (cmp != NSOrderedAscending)
			{
				checkpointMode = SQLITE_CHECKPOINT_TRUNCATE;
			}
			
		#endif
			
			int toalFrameCount = 0;
			int checkpointedFrameCount = 0;
			
			int result = sqlite3_wal_checkpoint_v2(strongSelf->db, "main", checkpointMode,
			                                       &toalFrameCount, &checkpointedFrameCount);
			
			NSLogInfo(@"Post-checkpoint (mode=%@): result(%d): frames(%d) checkpointed(%d)",
			            (checkpointMode == SQLITE_CHECKPOINT_RESTART ? @"restart" : @"truncate"),
			            result, toalFrameCount, checkpointedFrameCount);
			
			if ((checkpointMode == SQLITE_CHECKPOINT_RESTART) && (result == SQLITE_OK))
			{
				// Write something to the database to force restart the WAL.
				// We're just going to set a random value in the yap2 table.
				
				NSString *uuid = [[NSUUID UUID] UUIDString];
				
				[strongSelf beginTransaction];
				
				int status;
				sqlite3_stmt *statement;
				
				char *stmt = "INSERT OR REPLACE INTO \"sc\" (\"key\", \"data\") VALUES (?, ?);";
				
				int const bind_idx_key  = SQLITE_BIND_START + 0;
				int const bind_idx_data = SQLITE_BIND_START + 1;
				
				status = sqlite3_prepare_v2(strongSelf->db, stmt, (int)strlen(stmt)+1, &statement, NULL);
				if (status != SQLITE_OK)
				{
					NSLogError(@"%@: Error creating statement: %d %s",
					             THIS_METHOD, status, sqlite3_errmsg(strongSelf->db));
				}
				else
				{
					char *key = "random";
					sqlite3_bind_text(statement, bind_idx_key, key, (int)strlen(key), SQLITE_STATIC);
					
					SCDatabaseLoggerString _uuid; MakeSCDatabaseLoggerString(&_uuid, uuid);
					sqlite3_bind_text(statement, bind_idx_data, _uuid.str, _uuid.length, SQLITE_STATIC);
					
					status = sqlite3_step(statement);
					if (status != SQLITE_DONE)
					{
						NSLogError(@"%@: Error in statement: %d %s",
						             THIS_METHOD, status, sqlite3_errmsg(strongSelf->db));
					}
					
					sqlite3_finalize(statement);
					FreeSCDatabaseLoggerString(&_uuid);
				}
				
				[strongSelf commitTransaction];
			}
			
			if ((LOG_LEVEL >= 4) && SC_PRINT_WAL_SIZE)
			{
				NSString *walFilePath = [strongSelf.databasePath stringByAppendingString:@"-wal"];
				
				NSDictionary *walAttr = [[NSFileManager defaultManager] attributesOfItemAtPath:walFilePath error:NULL];
				unsigned long long walFileSize = [walAttr fileSize];
				
				NSLogVerbose(@"Post-checkpoint (mode=%@) file size: %@",
				   (checkpointMode == SQLITE_CHECKPOINT_RESTART ? @"restart" : @"truncate"),
				   [NSByteCountFormatter stringFromByteCount:(long long)walFileSize
				                                  countStyle:NSByteCountFormatterCountStyleFile]);
			}

			
		#pragma clang diagnostic pop
		}});
	});
}

@end
