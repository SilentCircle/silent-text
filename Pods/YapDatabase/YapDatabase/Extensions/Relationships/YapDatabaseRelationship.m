#import "YapDatabaseRelationship.h"
#import "YapDatabaseRelationshipPrivate.h"

#import "YapDatabasePrivate.h"
#import "YapDatabaseExtensionPrivate.h"

#import "YapDatabaseLogging.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

/**
 * Define log level for this file: OFF, ERROR, WARN, INFO, VERBOSE
 * See YapDatabaseLogging.h for more information.
**/
#if DEBUG
  static const int ydbLogLevel = YDB_LOG_LEVEL_WARN;
#else
  static const int ydbLogLevel = YDB_LOG_LEVEL_WARN;
#endif


@implementation YapDatabaseRelationship
{
	dispatch_queue_t fileManagerQueue;
}

/**
 * Subclasses MUST implement this method.
 *
 * This method is used when unregistering an extension in order to drop the related tables.
**/
+ (void)dropTablesForRegisteredName:(NSString *)registeredName
                    withTransaction:(YapDatabaseReadWriteTransaction *)transaction
                      wasPersistent:(BOOL __unused)wasPersistent
{
	sqlite3 *db = transaction->connection->db;
	
	NSString *tableName = [self tableNameForRegisteredName:registeredName];
	NSString *dropTable = [NSString stringWithFormat:@"DROP TABLE IF EXISTS \"%@\";", tableName];
	
	int status = sqlite3_exec(db, [dropTable UTF8String], NULL, NULL, NULL);
	if (status != SQLITE_OK)
	{
		YDBLogError(@"%@ - Failed dropping table (%@): %d %s",
		            THIS_METHOD, tableName, status, sqlite3_errmsg(db));
	}
}

+ (NSString *)tableNameForRegisteredName:(NSString *)registeredName
{
	return [NSString stringWithFormat:@"relationship_%@", registeredName];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Instance
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize versionTag = versionTag;
@dynamic options;

- (id)init
{
	return [self initWithVersionTag:nil options:nil];
}

- (id)initWithVersionTag:(NSString *)inVersionTag
{
	return [self initWithVersionTag:inVersionTag options:nil];
}

- (id)initWithVersionTag:(NSString *)inVersionTag options:(YapDatabaseRelationshipOptions *)inOptions
{
	if ((self = [super init]))
	{
		versionTag = inVersionTag ? [inVersionTag copy] : @"";
		options = inOptions ? [inOptions copy] : [[YapDatabaseRelationshipOptions alloc] init];
	}
	return self;
}

- (YapDatabaseRelationshipOptions *)options
{
	return [options copy];
}

/**
 * Subclasses must implement this method.
 * This method is called during the view registration process to enusre the extension supports
 * the database configuration.
**/
- (BOOL)supportsDatabase:(YapDatabase __unused *)database withRegisteredExtensions:(NSDictionary *)registeredExtensions
{
	// Only 1 relationship extension is supported at a time.
	
	__block BOOL supported = YES;
	
	[registeredExtensions enumerateKeysAndObjectsUsingBlock:^(id __unused key, id obj, BOOL *stop) {
		
		if ([obj isKindOfClass:[YapDatabaseRelationship class]])
		{
			YDBLogWarn(@"Only 1 YapDatabaseRelationship instance is supported at a time");
			
			supported = NO;
			*stop = YES;
		}
	}];
	
	return supported;
}

- (YapDatabaseExtensionConnection *)newConnection:(YapDatabaseConnection *)databaseConnection
{
	return [[YapDatabaseRelationshipConnection alloc] initWithRelationship:self databaseConnection:databaseConnection];
}

- (NSString *)tableName
{
	return [[self class] tableNameForRegisteredName:self.registeredName];
}

/**
 * The dispatch queue for performing file deletion operations.
 * Note: This method is not thread-safe, as it expects to only be invoked from within a read-write transaction.
**/
- (dispatch_queue_t)fileManagerQueue
{
	if (fileManagerQueue == NULL)
	{
		fileManagerQueue = dispatch_queue_create("YapDatabaseRelationship.fileManager", DISPATCH_QUEUE_SERIAL);
	}
	
	return fileManagerQueue;
}

@end
