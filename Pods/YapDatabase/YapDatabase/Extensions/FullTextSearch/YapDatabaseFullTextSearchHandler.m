#import "YapDatabaseFullTextSearchHandler.h"


@implementation YapDatabaseFullTextSearchHandler

@synthesize block = block;
@synthesize blockType = blockType;

+ (instancetype)withKeyBlock:(YapDatabaseFullTextSearchWithKeyBlock)block
{
	if (block == NULL) return nil;
	
	YapDatabaseFullTextSearchHandler *handler = [[YapDatabaseFullTextSearchHandler alloc] init];
	handler->block = block;
	handler->blockType = YapDatabaseFullTextSearchBlockTypeWithKey;
	
	return handler;
}

+ (instancetype)withObjectBlock:(YapDatabaseFullTextSearchWithObjectBlock)block
{
	if (block == NULL) return nil;
	
	YapDatabaseFullTextSearchHandler *handler = [[YapDatabaseFullTextSearchHandler alloc] init];
	handler->block = block;
	handler->blockType = YapDatabaseFullTextSearchBlockTypeWithObject;
	
	return handler;
}

+ (instancetype)withMetadataBlock:(YapDatabaseFullTextSearchWithMetadataBlock)block
{
	if (block == NULL) return nil;
	
	YapDatabaseFullTextSearchHandler *handler = [[YapDatabaseFullTextSearchHandler alloc] init];
	handler->block = block;
	handler->blockType = YapDatabaseFullTextSearchBlockTypeWithMetadata;
	
	return handler;
}

+ (instancetype)withRowBlock:(YapDatabaseFullTextSearchWithRowBlock)block
{
	if (block == NULL) return nil;
	
	YapDatabaseFullTextSearchHandler *handler = [[YapDatabaseFullTextSearchHandler alloc] init];
	handler->block = block;
	handler->blockType = YapDatabaseFullTextSearchBlockTypeWithRow;
	
	return handler;
}

@end
