#import "YapDatabaseViewTypes.h"

/**
 * The grouping block handles both filtering and grouping.
 *
 * When you add or update rows in the database the grouping block is invoked.
 * Your grouping block can inspect the row and determine if it should be a part of the view.
 * If not, your grouping block simply returns 'nil' and the object is excluded from the view (removing it if needed).
 * Otherwise your grouping block returns a group, which can be any string you want.
 * Once the view knows what group the row belongs to,
 * it will then determine the position of the row within the group (using the sorting block).
 *
 * You should choose a block type that takes the minimum number of required parameters.
 * The view can make various optimizations based on required parameters of the block.
**/
@implementation YapDatabaseViewGrouping

@synthesize groupingBlock = groupingBlock;
@synthesize groupingBlockType = groupingBlockType;

+ (instancetype)withKeyBlock:(YapDatabaseViewGroupingWithKeyBlock)groupingBlock
{
	if (groupingBlock == NULL) return nil;
	
	YapDatabaseViewGrouping *grouping = [[YapDatabaseViewGrouping alloc] init];
	grouping->groupingBlock = groupingBlock;
	grouping->groupingBlockType = YapDatabaseViewBlockTypeWithKey;
	
	return grouping;
}

+ (instancetype)withObjectBlock:(YapDatabaseViewGroupingWithObjectBlock)groupingBlock
{
	if (groupingBlock == NULL) return nil;
	
	YapDatabaseViewGrouping *grouping = [[YapDatabaseViewGrouping alloc] init];
	grouping->groupingBlock = groupingBlock;
	grouping->groupingBlockType = YapDatabaseViewBlockTypeWithObject;
	
	return grouping;
}

+ (instancetype)withMetadataBlock:(YapDatabaseViewGroupingWithMetadataBlock)groupingBlock
{
	if (groupingBlock == NULL) return nil;
	
	YapDatabaseViewGrouping *grouping = [[YapDatabaseViewGrouping alloc] init];
	grouping->groupingBlock = groupingBlock;
	grouping->groupingBlockType = YapDatabaseViewBlockTypeWithMetadata;
	
	return grouping;
}

+ (instancetype)withRowBlock:(YapDatabaseViewGroupingWithRowBlock)groupingBlock
{
	if (groupingBlock == NULL) return nil;
	
	YapDatabaseViewGrouping *grouping = [[YapDatabaseViewGrouping alloc] init];
	grouping->groupingBlock = groupingBlock;
	grouping->groupingBlockType = YapDatabaseViewBlockTypeWithRow;
	
	return grouping;
}

@end

#pragma mark -

/**
 * The sorting block handles sorting of objects within their group.
 *
 * After the view invokes the grouping block to determine what group a database row belongs to (if any),
 * the view then needs to determine what index within that group the row should be.
 * In order to do this, it needs to compare the new/updated row with existing rows in the same view group.
 * This is what the sorting block is used for.
 * So the sorting block will be invoked automatically during this process until the view has come to a conclusion.
 *
 * You should choose a block type that takes the minimum number of required parameters.
 * The view can make various optimizations based on required parameters of the block.
 *
 * For example, if sorting is based on the object, and the metadata of a row is updated,
 * then the view can deduce that the index hasn't changed (if the group hans't), and can skip this step.
 *
 * Performance Note:
 *
 * The view uses various optimizations (based on common patterns)
 * to reduce the number of times it needs to invoke the sorting block.
 *
 * - Pattern      : row is updated, but its index in the view doesn't change.
 *   Optimization : if an updated row doesn't change groups, the view will first compare it with
 *                  objects to the left and right.
 *
 * - Pattern      : rows are added to the beginning or end or a view
 *   Optimization : if the last change put an object at the beginning of the view, then it will test this quickly.
 *                  if the last change put an object at the end of the view, then it will test this quickly.
 *
 * These optimizations offer huge performance benefits to many common cases.
 * For example, adding objects to a view that are sorted by timestamp of when they arrived.
 *
 * The optimizations are not always performed.
 * For example, if the last change didn't place an item at the beginning or end of the view.
 *
 * If optimizations fail, or are skipped, then the view uses a binary search algorithm.
 *
 * Although this may be considered "internal information",
 * I feel it is important to explain for the following reason:
 *
 * Another common pattern is to fetch a number of objects in a batch, and then insert them into the database.
 * Now imagine a situation in which the view is sorting posts based on timestamp,
 * and you just fetched the most recent 10 posts. You can enumerate these 10 posts either forwards or backwards
 * while adding them to the database. One direction will hit the optimization every time. The other will cause
 * the view to perform a binary search every time.
 * These little one-liner optimzations are easy (given this internal information is known).
**/
@implementation YapDatabaseViewSorting

@synthesize sortingBlock = sortingBlock;
@synthesize sortingBlockType = sortingBlockType;

+ (instancetype)withKeyBlock:(YapDatabaseViewSortingWithKeyBlock)sortingBlock
{
	if (sortingBlock == NULL) return nil;
	
	YapDatabaseViewSorting *sorting = [[YapDatabaseViewSorting alloc] init];
	sorting->sortingBlock = sortingBlock;
	sorting->sortingBlockType = YapDatabaseViewBlockTypeWithKey;
	
	return sorting;
}

+ (instancetype)withObjectBlock:(YapDatabaseViewSortingWithObjectBlock)sortingBlock
{
	if (sortingBlock == NULL) return nil;
	
	YapDatabaseViewSorting *sorting = [[YapDatabaseViewSorting alloc] init];
	sorting->sortingBlock = sortingBlock;
	sorting->sortingBlockType = YapDatabaseViewBlockTypeWithObject;
	
	return sorting;
}

+ (instancetype)withMetadataBlock:(YapDatabaseViewSortingWithMetadataBlock)sortingBlock
{
	if (sortingBlock == NULL) return nil;
	
	YapDatabaseViewSorting *sorting = [[YapDatabaseViewSorting alloc] init];
	sorting->sortingBlock = sortingBlock;
	sorting->sortingBlockType = YapDatabaseViewBlockTypeWithMetadata;
	
	return sorting;
}

+ (instancetype)withRowBlock:(YapDatabaseViewSortingWithRowBlock)sortingBlock
{
	if (sortingBlock == NULL) return nil;
	
	YapDatabaseViewSorting *sorting = [[YapDatabaseViewSorting alloc] init];
	sorting->sortingBlock = sortingBlock;
	sorting->sortingBlockType = YapDatabaseViewBlockTypeWithRow;
	
	return sorting;
}

@end

