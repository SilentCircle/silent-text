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


@interface SCDatabaseLoggerChangeset : NSObject

/**
 * LogEntryIDs that were removed since last longLivedReadTransaction.
 * These are logEntries that exceeded the maxAge of the logger (as configured), and were deleted from the database.
 *
 * Keep in mind that deletedLogEntryIDs always represent a range that is anchored to the oldest log entry.
 * That is, anchored to the beginning of the allLogEntryIDs array.
 *
 * For example:
 * 
 * Say you started a longLivedReadTransaction, and the fetched allLogEntryIDs.
 * Your allLogEntryIDs array contains 500 items.
 * You later invoke longLivedReadTransaction again, and receive an SCDatabaseLoggerChangeset.
 * And changeset.deletedLogEntryIDs.count is 25.
 * Thus you can simply remove the first 25 entries from your existing allLogEntryIDs array.
 * 
 * The entryIDs are ordered by timestamp from oldest to newest.
**/
@property (nonatomic, readonly) NSArray *deletedLogEntryIDs;

/**
 * LogEntryIDs that were inserted since last longLivedReadTransaction.
 * 
 * Keep in mind that insertedLogEntryIDs always represent a range that is anchored to the previous newest log entry.
 * That is, anchored to the end of the allLogEntryIDs array.
 *
 * For example:
 * 
 * Say you started a longLivedReadTransaction, and the fetched allLogEntryIDs.
 * Your allLogEntryIDs array contains 500 items.
 * You later invoke longLivedReadTransaction again, and receive an SCDatabaseLoggerChangeset.
 * And changeset.insertedLogEntryIDs.count is 15.
 * Thus you can simply append these 15 insertedLogEntryIDs to your existing allLogEntryIDs array.
 *
 * The entryIDs are ordered by timestamp from oldest to newest.
**/
@property (nonatomic, readonly) NSArray *insertedLogEntryIDs;

@property (nonatomic, readonly) NSArray *insertedLogEntries;

@end
