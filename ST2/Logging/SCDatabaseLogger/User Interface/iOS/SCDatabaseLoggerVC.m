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
#import "SCDatabaseLoggerVC.h"
#import "AppDelegate.h"

#import "SCDatabaseLogger.h"
#import "SCDatabaseLoggerColorProfiles.h"

// We probably shouldn't be using DDLog() statements within the DDLog implementation.
// But we still want to leave our log statements for any future debugging,
// and to allow other developers to trace the implementation (which is a great learning tool).
//
// So we use primitive logging macros around NSLog.
// We maintain the NS prefix on the macros to be explicit about the fact that we're using NSLog.

#if DEBUG && robbie_hanson
  #define LOG_LEVEL 2
#else
  #define LOG_LEVEL 1
#endif

#define LOG_PREFIX @"SCDatabaseLoggerVC: "

#define NSLogError(frmt, ...)    do{ if(LOG_LEVEL >= 1) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(LOG_LEVEL >= 2) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(LOG_LEVEL >= 3) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(LOG_LEVEL >= 4) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)


@implementation SCDatabaseLoggerVC {
@private
	
	__weak IBOutlet UITextView * textView;
	__weak IBOutlet UIView     * doneBackgroundView;
	
	SCDatabaseLoggerConnection *loggerConnection;
	SCDatabaseLoggerColorProfiles *colorProfiles;
	
	NSMutableArray *logEntryIDs;
	NSMutableArray *logEntries;
	
	NSCalendar *calendar;
	NSUInteger calendarUnitFlags;
	
	BOOL hasViewDidAppear;
	BOOL isScrollingToBottom;
	BOOL hasPendingChanges;
}

+ (instancetype)initWithProperStoryboard
{
	UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"SCDatabaseLogger" bundle:nil];
	SCDatabaseLoggerVC *vc = [storyboard instantiateViewControllerWithIdentifier:@"SCDatabaseLoggerVC"];
	
	return vc;
}

- (void)dealloc
{
	NSLogVerbose(@"dealloc");
	
	[loggerConnection endLongLivedReadTransaction];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	textView.textContainerInset = (UIEdgeInsets){
		.top = doneBackgroundView.frame.size.height,
		.bottom = 0,
		.left = 0,
		.right = 0
	};
	
	loggerConnection = [self.appDelegate.databaseLogger newConnection];
	colorProfiles = self.appDelegate.databaseLoggerColorProfiles;
	
	logEntryIDs = [[NSMutableArray alloc] init];
	logEntries  = [[NSMutableArray alloc] init];
	
	calendar = [NSCalendar autoupdatingCurrentCalendar];
	
	calendarUnitFlags = 0;
	calendarUnitFlags |= NSCalendarUnitHour;
	calendarUnitFlags |= NSCalendarUnitMinute;
	calendarUnitFlags |= NSCalendarUnitSecond;
	
	[self fetchInitialLogEntries];
	[self initializeTextView];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseLoggerChanged:)
	                                             name:SCDatabaseLoggerChangedNotification
	                                           object:STAppDelegate.databaseLogger];
}

- (void)viewDidLayoutSubviews
{
	NSLogVerbose(@"viewDidLayoutSubviews");
	[super viewDidLayoutSubviews];
	
	// Note: This method is called after viewWillAppear
	
	if (!hasViewDidAppear)
	{
		// I can't get scrolling sans-animation to work properly :(
	//	[self scrollTextViewToBottomAnimated:NO];
		[self scrollTextViewToBottomAnimated:YES];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	NSLogVerbose(@"viewDidAppear");
	[super viewDidAppear:animated];
	
	hasViewDidAppear = YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Database
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)fetchInitialLogEntries
{
	[loggerConnection beginLongLivedReadTransaction];
	[loggerConnection readWithBlock:^(SCDatabaseLoggerTransaction *transaction) {
		
		NSUInteger count = [transaction numberOfLogEntries];
		
		// There could be thousands & thousands of log entries.
		// It's probably not worth trying to read them all on an iDevice.
		// So we're going to limit it, and only display the most recent X (where X is reasonable).
		
		NSUInteger limit = 500;
		
		if (count > limit)
		{
			NSUInteger offset = count - limit;
			
			[transaction enumerateLogEntriesWithLimit:limit
			                                   offset:offset
			                                    block:^(id logEntryID, SCDatabaseLogEntry *logEntry, BOOL *stop)
			{
				[logEntryIDs addObject:logEntryID];
				[logEntries  addObject:logEntry];
			}];
		}
		else
		{
			[transaction enumerateLogEntriesWithBlock:^(id logEntryID, SCDatabaseLogEntry *logEntry, BOOL *stop) {
				
				[logEntryIDs addObject:logEntryID];
				[logEntries  addObject:logEntry];
			}];
		}
	}];
}

- (void)databaseLoggerChanged:(__unused NSNotification *)notification
{
	if (isScrollingToBottom)
	{
		NSLogVerbose(@"databaseLoggerChanged - pending");
		
		// Delay this update until the scrolling animation completes.
		hasPendingChanges = YES;
		return;
	}
	else
	{
		NSLogVerbose(@"databaseLoggerChanged - processing");
		
		hasPendingChanges = NO;
	}
	
	BOOL wasScrolledToBottom = [self isTextViewScrolledToBottom];
	
	SCDatabaseLoggerChangeset *changeset = [loggerConnection beginLongLivedReadTransaction];
	
	// Process log entries that were deleted.
	//
	// Since we initialize the textView with only the most recent 500 log messages,
	// the deletedLogEntries may not be included in our list.
	
	NSUInteger deletedCharactersCount = 0;
	
	if (changeset.deletedLogEntryIDs.count > 0)
	{
		id oldestLogEntryID = [logEntryIDs firstObject];
		
		for (id deletedLogEntryID in changeset.deletedLogEntryIDs)
		{
			if ([deletedLogEntryID isEqual:oldestLogEntryID])
			{
				SCDatabaseLogEntry *deletedLogEntry = [logEntries objectAtIndex:0];
				deletedCharactersCount += deletedLogEntry.message.length + 1; // +1 for '\n'
				
				[logEntryIDs removeObjectAtIndex:0];
				[logEntries  removeObjectAtIndex:0];
				
				oldestLogEntryID = [logEntryIDs firstObject];
			}
		}
	}
	
	// Process log entries that were inserted
	
	if (changeset.insertedLogEntryIDs.count > 0)
	{
		NSAssert(changeset.insertedLogEntryIDs.count == changeset.insertedLogEntries.count, @"Oops");
		
		[logEntryIDs addObjectsFromArray:changeset.insertedLogEntryIDs];
		[logEntries  addObjectsFromArray:changeset.insertedLogEntries];
	}
	
	// Update the underlying text storage.
	// And update the contentOffset of the scrollView.
	//
	// If we were previously scrolled to the bottom, then we'd like to continue automatically scrolling to the bottom.
	// That is, display new log entries automatically as they arrive.
	//
	// But if we're not scrolled to the bottom, then we should maintain the current position.
	// This doesn't mean the same contentOffset.
	// It means that whatever is being displayed, then it should still be displayed after updating the textView.
	// The goal is to do so without any noticeable movement what-so-ever (if possible).
	
	CGFloat deletedHeight = 0;
	CGFloat insertedHeight = 0;
	
	if (deletedCharactersCount > 0)
	{
		// First calculate the size of entries we're going to remove.
		
		NSRange characterRange = NSMakeRange(0, deletedCharactersCount);
		NSRange glyphRange;
		[textView.layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:&glyphRange];
		
		CGRect rect = [textView.layoutManager boundingRectForGlyphRange:glyphRange
		                                                inTextContainer:textView.textContainer];
		
		NSLogVerbose(@"deletedRect: %@", NSStringFromCGRect(rect));
		
		deletedHeight = rect.size.height;
		NSLogVerbose(@"deletedHeight = %.6f", deletedHeight);
		
		// Then actually remove the deleted characters from the textStorage backing system.
		
		[textView.textStorage replaceCharactersInRange:characterRange withString:@""];
	}
	
	if (changeset.insertedLogEntries.count > 0)
	{
		// First add the inserted characters to the textStorage backing system.
		
		NSUInteger insertedCharactersCount = 0;
		
		for (SCDatabaseLogEntry *logEntry in changeset.insertedLogEntries)
		{
			NSAttributedString *attrStr = [self attributedStringForLogEntry:logEntry];
			insertedCharactersCount += attrStr.length;
			
			[textView.textStorage appendAttributedString:attrStr];
		}
		
		NSLogVerbose(@"insertedCharactersCount = %llu", (unsigned long long)insertedCharactersCount);
		
		// Then calculate the size of the inserted entries.
		
		NSRange characterRange = (NSRange){
			.location = textView.textStorage.length - insertedCharactersCount,
			.length = insertedCharactersCount
		};
		NSRange glyphRange;
		[textView.layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:&glyphRange];
		
		CGRect rect = [textView.layoutManager boundingRectForGlyphRange:glyphRange
		                                                inTextContainer:textView.textContainer];
		
		insertedHeight = rect.size.height;
	}
	
	if (wasScrolledToBottom)
	{
		[self scrollTextViewToBottomAnimated:YES];
	}
	else
	{
		// Try to maintain whatever is currently on screen.
		//
		// This is possible unless the user is scrolled all the way to the top.
		// In that case we just pin the contentOffset at the top.
		
		CGPoint oldContentOffset = textView.contentOffset;
		CGPoint newContentOffset = (CGPoint){
			.x = oldContentOffset.x,
			.y = oldContentOffset.y - deletedHeight
		};
		
		if (newContentOffset.y < 0.0F)
			newContentOffset.y = 0.0F;
		
		[textView setContentOffset:newContentOffset animated:NO];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (AppDelegate *)appDelegate
{
	return STAppDelegate;
}

- (NSAttributedString *)attributedStringForLogEntry:(SCDatabaseLogEntry *)logEntry
{
	if (logEntry == nil) return nil;
	
	UIColor *fgColor = nil;
	UIColor *bgColor = nil;
	
	[colorProfiles getForegroundColor:&fgColor
					  backgroundColor:&bgColor
							  forFlag:logEntry.flags
							  context:logEntry.context
								  tag:logEntry.tag];
	
	if (fgColor == nil) {
		fgColor = [UIColor blackColor];
	}
	
	NSDictionary *attributes = nil;
	if (bgColor) {
		attributes = @{ NSForegroundColorAttributeName : fgColor, NSBackgroundColorAttributeName : bgColor };
	}
	else {
		attributes = @{ NSForegroundColorAttributeName : fgColor };
	}
	
	// Format: HH:mm:ss:SSS
	// Space : 123456789_123 (don't forget trailing \n)
	//
	char timestamp[13];
	
	NSDateComponents *components = [calendar components:calendarUnitFlags fromDate:logEntry.timestamp];
	
	NSTimeInterval ti = [logEntry.timestamp timeIntervalSinceReferenceDate];
	int milliseconds = (int)((ti - floor(ti)) * 1000);
	
	snprintf(timestamp, 13, "%02ld:%02ld:%02ld:%03d", // HH:mm:ss:SSS
			 (long)components.hour,
			 (long)components.minute,
			 (long)components.second, milliseconds);
	
	NSString *str = [NSString stringWithFormat:@"%s %@\n", timestamp, logEntry.message];
	
	return [[NSAttributedString alloc] initWithString:str attributes:attributes];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITextView
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)initializeTextView
{
	for (SCDatabaseLogEntry *logEntry in logEntries)
	{
		NSAttributedString *attrStr = [self attributedStringForLogEntry:logEntry];
		
		[textView.textStorage appendAttributedString:attrStr];
	}
	
	NSLogVerbose(@"textView.textStorage.length = %llu", (unsigned long long)textView.textStorage.length);
}

- (BOOL)isTextViewScrolledToBottom
{
	if (isScrollingToBottom) return YES;
	
	// Note: We also have a textView.textContainerInset.top set (to 44).
	// This value actually increases the contentSize (as the scrollView understands it).
	// So we don't have to take it into account below.
	
	CGFloat contentOffsetY = textView.contentOffset.y;
	CGFloat textViewHeight = textView.frame.size.height;
	
	CGFloat contentHeight  = textView.contentSize.height;
	
	NSLogVerbose(@"%@ - contentOffsetY  : %f", NSStringFromSelector(_cmd), contentOffsetY);
	NSLogVerbose(@"%@ - textViewHeight  : %f", NSStringFromSelector(_cmd), textViewHeight);
	NSLogVerbose(@"%@ - contentHeight   : %f", NSStringFromSelector(_cmd), contentHeight);
	
	BOOL result = (ceilf(contentOffsetY + textViewHeight) + 3.0F) >= floorf(contentHeight);
	NSLogVerbose(@"isTextViewScrolledToBottom = %@", (result ? @"YES" : @"NO"));
	
	return result;
}

- (void)scrollTextViewToBottomAnimated:(BOOL)animated
{
	NSLogVerbose(@"scrollTextViewToBottomAnimated: %@", (animated ? @"YES" : @"NO"));
	
	if (animated)
	{
		isScrollingToBottom = YES;
		[textView scrollRangeToVisible:NSMakeRange(textView.textStorage.length, 0)];
		
		__weak typeof(self) weakSelf = self;
		
		dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.305 * NSEC_PER_SEC));
		dispatch_after(delay, dispatch_get_main_queue(), ^{
		#pragma clang diagnostic push
		#pragma clang diagnostic warning "-Wimplicit-retain-self"
			
			__strong typeof(self) strongSelf = weakSelf;
			if (strongSelf)
			{
				strongSelf->isScrollingToBottom = NO;
				
				if (strongSelf->hasPendingChanges) {
					[strongSelf databaseLoggerChanged:nil];
				}
			}
			
		#pragma clang diagnostic pop
		});
	}
	else
	{
		// This doesn't work.
		// It does scrollToBottom without animation but ...
		// How exactly does it not work?
		//
		// When used, one is unable to properly scroll the textView up.
		// That is, it will properly jump to the bottom (without animation) as expected.
		// But attempting to scroll up afterwards will be horribly broken.
		// The textView will jump erratically, and constantly seek back to the bottom.
		
	//	[UIView setAnimationsEnabled:NO];
	//	[textView scrollRangeToVisible:NSMakeRange([textView.text length], 0)];
	//	[UIView setAnimationsEnabled:YES];
		
	#if 0
		
		// This doesn't work properly either.
		// The textView's size seems to grow mysteriously after we've scrolled to the bottom.
		
		NSLogVerbose(@"%@ - textViewSize   : %@", NSStringFromSelector(_cmd), NSStringFromCGSize(textView.frame.size));
		NSLogVerbose(@"%@ - contentHeight  : %@", NSStringFromSelector(_cmd), NSStringFromCGSize(textView.contentSize));
		
		CGFloat contentHeight  = textView.contentSize.height;
		CGFloat textViewHeight = textView.frame.size.height;
		
		if (contentHeight > textViewHeight)
		{
			CGPoint newContentOffset = (CGPoint){
				.x = 0,
				.y = ceilf(contentHeight - textViewHeight)
			};
	
			[textView setContentOffset:newContentOffset animated:NO];
		}
		
		NSUInteger numCharacters = textView.textStorage.length;
		NSRange characterRange = NSMakeRange(0, numCharacters);
		NSRange glyphRange;
		[textView.layoutManager glyphRangeForCharacterRange:characterRange actualCharacterRange:&glyphRange];
		
		CGRect rect = [textView.layoutManager boundingRectForGlyphRange:glyphRange
		                                                inTextContainer:textView.textContainer];
		
		NSLogVerbose(@"%@ - boundingRect: %@", NSStringFromSelector(_cmd), NSStringFromCGRect(rect));
		
	#else
	
		[textView scrollRangeToVisible:NSMakeRange([textView.text length], 0)];
		
	#endif
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark IBActions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)doneButtonTapped:(id)sender
{
	[self.appDelegate.window.rootViewController dismissViewControllerAnimated:YES completion:NULL];
}

@end
