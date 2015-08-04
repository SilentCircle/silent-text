#import "YapDatabaseFullTextSearch.h"
#import "YapDatabaseFullTextSearchHandler.h"
#import "YapDatabaseFullTextSearchConnection.h"
#import "YapDatabaseFullTextSearchTransaction.h"

#import "YapDatabase.h"
#import "YapDatabaseConnection.h"
#import "YapDatabaseTransaction.h"

#import "sqlite3.h"

/**
 * This version number is stored in the yap2 table.
 * If there is a major re-write to this class, then the version number will be incremented,
 * and the class can automatically rebuild the tables as needed.
**/
#define YAP_DATABASE_FTS_CLASS_VERSION 1

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface YapDatabaseFullTextSearch () {
@public
	
	YapDatabaseFullTextSearchBlock block;
	YapDatabaseFullTextSearchBlockType blockType;
	
	NSOrderedSet *columnNames;
	NSDictionary *options;
	NSString *versionTag;
	
	id columnNamesSharedKeySet;
}

- (NSString *)tableName;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface YapDatabaseFullTextSearchConnection () {
@public
	
	__strong YapDatabaseFullTextSearch *fts;
	__unsafe_unretained YapDatabaseConnection *databaseConnection;
	
	NSMutableDictionary *blockDict;
}

- (id)initWithFTS:(YapDatabaseFullTextSearch *)fts
   databaseConnection:(YapDatabaseConnection *)databaseConnection;

- (sqlite3_stmt *)insertRowidStatement;
- (sqlite3_stmt *)setRowidStatement;
- (sqlite3_stmt *)removeRowidStatement;
- (sqlite3_stmt *)removeAllStatement;
- (sqlite3_stmt *)queryStatement;
- (sqlite3_stmt *)querySnippetStatement;
- (sqlite3_stmt *)rowidQueryStatement;
- (sqlite3_stmt *)rowidQuerySnippetStatement;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface YapDatabaseFullTextSearchTransaction () {
@private
	
	__unsafe_unretained YapDatabaseFullTextSearchConnection *ftsConnection;
	__unsafe_unretained YapDatabaseReadTransaction *databaseTransaction;
	
	BOOL isMutated;
}

- (id)initWithFTSConnection:(YapDatabaseFullTextSearchConnection *)ftsConnection
        databaseTransaction:(YapDatabaseReadTransaction *)databaseTransaction;

- (void)enumerateRowidsMatching:(NSString *)query
                     usingBlock:(void (^)(int64_t rowid, BOOL *stop))block;

- (void)enumerateRowidsMatching:(NSString *)query
             withSnippetOptions:(YapDatabaseFullTextSearchSnippetOptions *)inOptions
                     usingBlock:
            (void (^)(NSString *snippet, int64_t rowid, BOOL *stop))block;

- (BOOL)rowid:(int64_t)rowid matches:(NSString *)query;
- (NSString *)rowid:(int64_t)rowid matches:(NSString *)query
                        withSnippetOptions:(YapDatabaseFullTextSearchSnippetOptions *)options;

@end
