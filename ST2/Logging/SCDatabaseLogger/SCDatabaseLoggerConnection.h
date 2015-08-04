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
#import "SCDatabaseLoggerChangeset.h"

@class SCDatabaseLogger;
@class SCDatabaseLoggerTransaction;


@interface SCDatabaseLoggerConnection : NSObject

//
// Use [SCDatabaseLogger newConnection] to create an instance of this class.
//

/**
 * The parent logger instance.
 *
 * Note that a loggerConnection maintains a strong reference to its parent. This is by design.
 * A connection to the database file implicitly prevents the database file from being deleted from disk.
 * The same dynamic is being represented here with objects.
**/
@property (nonatomic, strong, readonly) SCDatabaseLogger *logger;

/**
 * Allows you to control the size of cache (of SCDatabaseLogEntry's).
 * A cacheLimit of zero means an unlimited cache size.
 *
 * The default cacheEnabled value is YES.
 * The default cacheLimit value is 500.
**/
@property (atomic, assign, readwrite) BOOL cacheEnabled;
@property (atomic, assign, readwrite) NSUInteger cacheLimit;

/**
 * Fast-Forwarding is the one concept that is unique to SCDatabaseLogger.
 * (The one concept we didn't steal from YapDatabase.)
 * 
 * Basically, fast-forwarding allows a connection to see beyond what's currently in the database.
 * It can also see what's scheduled to hit the database (soon).
 * 
 * The idea is simple:
 *
 * In an ideal world, the database would be "infinitely" fast, and we could execute 500 billion transactions per second.
 * But that's not the case. So instead we have to batch logEntries into a number of transactions per second,
 * depending on how fast the hardware is. And, on top of that, if the application is hammering the logging system,
 * without rest, then we occasionally have to pause our transactions in order to checkpoint the WAL (so that
 * it doesn't grow to infinity).
 * 
 * But just because a log entry hasn't hit the disk yet doesn't mean we can't include it within a transaction.
 * That is, we have the log entry sitting in memory. It's just waiting for a transaction batch before it goes to disk.
 * So we can easily pretend that it's already on the disk, and make it visible within a transaction.
 * 
 * So fast-forwarding allows a transaction to see a future state of the database.
 * Slightly ahead of exactly where it is now.
 * Another way to think of it is that fast-forwarding allows the connection to see in real-time.
 * It can see all the log entries that have happened, even those that haven't technically hit the disk yet.
 * 
 * The default value is YES.
**/
@property (atomic, assign, readwrite) BOOL usesFastForwarding;

#pragma mark Transactions

/**
 * Synchronous access to the logger database.
 * 
 * Provides a snapshot-in-time of the current set of available log entries,
 * which is actually a merger of on-disk entries & those pending insertion. (i.e. real-time snapshot)
**/
- (void)readWithBlock:(void (^)(SCDatabaseLoggerTransaction *transaction))block;

/**
 * Asynchronous access to the logger database.
 *
 * Provides a snapshot-in-time of the current set of available log entries,
 * which is actually a merger of on-disk entries & those pending insertion. (i.e. real-time snapshot)
**/
- (void)asyncReadWithBlock:(void (^)(SCDatabaseLoggerTransaction *transaction))block;

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
           completionBlock:(dispatch_block_t)completionBlock;

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
           completionBlock:(dispatch_block_t)completionBlock;

#pragma mark Long-Lived Transactions

/**
 * A long-lived read transaction allows you to freeze the connection on a particular commit.
 * 
 * This is useful if you intend to display log entries within the UI.
 * For example, display a live stream of log entries within the app.
 * 
 * This code-base heavily mirrors YapDatabase.
 * So I'll also refer you to the YapDatabase documentation on long-lived transactions:
 * https://github.com/yapstudios/YapDatabase/wiki/LongLivedReadTransactions
 * 
 * (And by heavily mirrors, I mean I straight up stole YapDatabase's architecture & code for this project.
 *  But I also wrote YapDatabase, so I promise not to sue myself.)
**/

- (SCDatabaseLoggerChangeset *)beginLongLivedReadTransaction;
- (SCDatabaseLoggerChangeset *)endLongLivedReadTransaction;

- (BOOL)isInLongLivedReadTransaction;

@end
