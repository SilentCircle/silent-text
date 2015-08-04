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
#import "DDLog.h"

#import "SCDatabaseLogger.h"
#import "SCDatabaseLoggerCache.h"
#import "SCDatabaseLoggerConnection.h"
#import "SCDatabaseLoggerTransaction.h"
#import "SCDatabaseLoggerInternalChangeset.h"
#import "SCDatabaseLogEntry.h"

#import "sqlite3.h"

@class SCDatabaseLoggerWriteTransaction;

/**
 * Helper method to conditionally invoke sqlite3_finalize on a statement, and then set the ivar to NULL.
**/
NS_INLINE void sqlite_finalize_null(sqlite3_stmt **stmtPtr)
{
	if (*stmtPtr) {
		sqlite3_finalize(*stmtPtr);
		*stmtPtr = NULL;
	}
}

#ifndef SQLITE_BIND_START
#define SQLITE_BIND_START 1
#endif

#ifndef SQLITE_COLUMN_START
#define SQLITE_COLUMN_START 0
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SCDatabaseLogger () {
@public
	
	void *IsOnSnapshotQueueKey;
	void *IsOnWriteQueueKey;
	
	dispatch_queue_t snapshotQueue;
	dispatch_queue_t writeQueue;
	
	NSMutableArray *connectionStates;
}

#ifdef SQLITE_HAS_CODEC
- (BOOL)configureEncryptionForDatabase:(sqlite3 *)sqlite;
#endif

- (void)removeConnection:(SCDatabaseLoggerConnection *)connection;

@property (atomic, readonly) uint64_t snapshot;

- (void)getPendingLogEntriesForRead:(NSArray **)entriesPtr uuids:(NSArray **)uuidsPtr;
- (void)removePendingLogEntries:(NSUInteger)count;

- (void)notePendingChanges:(SCDatabaseLoggerInternalChangeset *)pendingChangeset;
- (void)noteCommittedChanges:(SCDatabaseLoggerInternalChangeset *)changeset
              fromConnection:(SCDatabaseLoggerConnection *)connection;

- (NSArray *)pendingAndCommittedChangesSince:(uint64_t)connectionSnapshot until:(uint64_t)maxSnapshot;
- (NSArray *)pendingAndCommittedChangesAfter:(int64_t)snapshot;

- (void)asyncCheckpoint:(uint64_t)maxCheckpointableSnapshot;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SCDatabaseLoggerConnection () {
@public
	
	__strong SCDatabaseLogger *logger;
	
	dispatch_queue_t connectionQueue;
	void *IsOnConnectionQueueKey;
	
	sqlite3 *db;
	
	int64_t dbSnapshot;
	int64_t ffSnapshot;
	
	SCDatabaseLoggerCache * logEntryCache;
	NSUInteger logEntryCacheLimit;
	
	NSMutableSet        * fastforward_deletedRowids;
	NSMutableArray      * fastforward_insertedRowids;
	NSMutableDictionary * fastforward_insertedLogEntries; // rowid -> logEntry
	NSArray             * pending_insertedUUIDs;
	NSMutableDictionary * pending_insertedLogEntries;     // uuid -> logEntry
}

- (instancetype)initWithLogger:(SCDatabaseLogger *)parent;
- (void)prepareDatabase;

- (sqlite3_stmt *)beginTransactionStatement;
- (sqlite3_stmt *)commitTransactionStatement;

- (sqlite3_stmt *)enumerateRowidsStatement;
- (sqlite3_stmt *)enumerateRowidsRangeStatement;
- (sqlite3_stmt *)enumerateLogEntriesStatement;
- (sqlite3_stmt *)enumerateLogEntriesRangeStatement;
- (sqlite3_stmt *)getLogEntryCountStatement;
- (sqlite3_stmt *)getLogEntryLowRangeStatement;
- (sqlite3_stmt *)getLogEntryHighRangeStatement;
- (sqlite3_stmt *)getLogEntryForRowidStatement;
- (sqlite3_stmt *)insertForRowidStatement;
- (sqlite3_stmt *)enumerateOldRowidsStatement;
- (sqlite3_stmt *)deleteOldLogEntriesStatement;

- (void)asyncReadWriteWithBlock:(void (^)(SCDatabaseLoggerWriteTransaction *transaction))block
                completionQueue:(dispatch_queue_t)completionQueue
                completionBlock:(dispatch_block_t)completionBlock;

- (void)maybeResetLongLivedReadTransaction;

- (void)noteCommittedChanges:(SCDatabaseLoggerInternalChangeset *)changeset;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SCDatabaseLoggerTransaction () {
@public
	
	__unsafe_unretained SCDatabaseLoggerConnection *connection;
	
	BOOL isFastForwarded;
}

- (instancetype)initWithConnection:(SCDatabaseLoggerConnection *)connection isFastForwarded:(BOOL)isFastForwarded;

- (void)beginTransaction;
- (void)commitTransaction;

@end

@interface SCDatabaseLoggerWriteTransaction : SCDatabaseLoggerTransaction {
@public
	
	NSMutableArray *deletedRowids;
	NSMutableArray *insertedRowids;
	
	NSMutableDictionary *insertedLogEntries; // rowid -> SCDatabaseLogEntry
	NSMutableDictionary *insertedMappings;   // rowid -> uuid
}

- (void)findAndDeleteOldLogEntries:(NSTimeInterval)maxAge;
- (void)insertLogEntries:(NSArray *)logEntries withUUIDs:(NSArray *)uuids;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SCDatabaseLoggerChangeset ()

- (instancetype)initWithDeletedLogEntryIDs:(NSArray *)ieletedLogEntryIDs
                       insertedLogEntryIDs:(NSArray *)insertedLogEntryIDs
                        insertedLogEntries:(NSArray *)insertedLogEntries;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SCDatabaseLogEntry () {
@public
	NSDate *timestamp;
	
	int context;
	int flags;
	NSString *tag;
	NSString *message;
}

- (instancetype)initWithLogMessage:(DDLogMessage *)logMessage formattedMessage:(NSString *)formattedMessage;

@end


