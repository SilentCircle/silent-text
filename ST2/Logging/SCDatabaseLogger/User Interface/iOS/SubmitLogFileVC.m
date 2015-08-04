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
#import "SubmitLogFileVC.h"
#import "SubmitLogFileInfoVC.h"

#import "SCDatabaseLogger.h"
#import "SCDatabaseLogger+JID.h"
#import "SCDatabaseLogger+RTF.h"
#import "SCDatabaseLoggerColorProfiles.h"

#import "AppDelegate.h"
#import "AppConstants.h"
#import "SCWebAPIManager.h"
#import "STLocalUser.h"

// We probably shouldn't be using DDLog() statements within the DDLog implementation.
// But we still want to leave our log statements for any future debugging,
// and to allow other developers to trace the implementation (which is a great learning tool).
//
// So we use primitive logging macros around NSLog.
// We maintain the NS prefix on the macros to be explicit about the fact that we're using NSLog.

#define LOG_LEVEL 4

#define LOG_PREFIX @"SubmitLogFileVC: "

#define NSLogError(frmt, ...)    do{ if(LOG_LEVEL >= 1) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(LOG_LEVEL >= 2) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(LOG_LEVEL >= 3) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(LOG_LEVEL >= 4) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)


static NSString *const report_key_appVersion     = @"appVersion";
static NSString *const report_key_appBuild       = @"appBuild";
static NSString *const report_key_iOSVersion     = @"iOSVersion";
static NSString *const report_key_username       = @"username";
static NSString *const report_key_apsEnvironment = @"apsEnvironment";
static NSString *const report_key_report         = @"report";
static NSString *const report_key_log            = @"log";

@interface SubmitLogFileVC ()

@property (nonatomic, strong, readwrite) NSData *rtfData;

@end

@implementation SubmitLogFileVC {
@private
	
	__weak IBOutlet UITextView *textView;
	__weak IBOutlet UIButton *submitButton;
	__weak IBOutlet UIActivityIndicatorView *spinner;
	
	BOOL hasClearedTextView;
	BOOL rtfTaskComplete;
	BOOL waitingForRtfTask;
	
	NSString *originalSubmitButtonTitle;
}

@dynamic reportInfo;
@dynamic userDescription;

@synthesize rtfData = __mustUseDotSyntaxToSupportObserving_rtfData;

+ (instancetype)initWithProperStoryboard
{
	UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"SubmitLogFileVC" bundle:nil];
	SubmitLogFileVC *vc = [storyboard instantiateViewControllerWithIdentifier:@"SubmitLogFileVC"];
	
	return vc;
}

- (void)dealloc
{
	NSLogVerbose(@"dealloc");
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	spinner.hidden = YES;
	textView.delegate = self;
	
	originalSubmitButtonTitle = [submitButton titleForState:UIControlStateNormal];
	
	if (AppConstants.isIPhone)
	{
		// On iPad, the user can dismiss the keyboard using the "dismiss" button on the keyboard itself.
		// On iPhone, the dismiss button doesn't exist in portrait mode.
		// So we set alwaysBoundVertical to YES.
		// And when this is combined with the keyboardDismissMode (UIScrollViewKeyboardDismissModeInteractive),
		// it provides a way for the user to be able to dismiss the keyboard.
		textView.alwaysBounceVertical = YES;
	}
	
	self.navigationItem.rightBarButtonItem =
	  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
	                                                target:self
	                                                action:@selector(cancelDoneButtonTapped:)];
	
	[self createRTFFromLogs];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	SubmitLogFileInfoVC *info = (SubmitLogFileInfoVC *)segue.destinationViewController;
	info.root = self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SCDatabaseLogger
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)createRTFFromLogs
{
	SCDatabaseLoggerColorProfiles *colorProfiles = STAppDelegate.databaseLoggerColorProfiles;
	
	SCDatabaseLoggerConnection *loggerConnection = [STAppDelegate.databaseLogger newConnection];
	loggerConnection.usesFastForwarding = YES;
	
	if (loggerConnection == nil)
	{
		// Defensive programming:
		//
		// Problem creating the logger maybe ?
		// Let's work around it...
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			self.rtfData = nil;
			self->rtfTaskComplete = YES;
			
			[self finishSubmitReportIfNeeded];
		});
		
		return;
	}
	
	__block NSData *outputData = nil;
	
	__weak typeof(self) weakSelf = self;
	
	[loggerConnection asyncReadWithBlock:^(SCDatabaseLoggerTransaction *transaction) {
		
		NSDate *oneWeekAgo = [NSDate dateWithTimeIntervalSinceNow:(-7 * 86400)];
		NSRange range = [transaction rangeOfLogEntriesWithStartDate:oneWeekAgo endDate:nil];
		
		if (range.length == 0) {
			return; // from_block (jump to completionBlock)
		}
		
		NSCalendar *calendar = [NSCalendar currentCalendar];
		NSUInteger calendarUnitFlags = 0;
		
		calendarUnitFlags |= NSCalendarUnitYear;
		calendarUnitFlags |= NSCalendarUnitMonth;
		calendarUnitFlags |= NSCalendarUnitDay;
		calendarUnitFlags |= NSCalendarUnitHour;
		calendarUnitFlags |= NSCalendarUnitMinute;
		calendarUnitFlags |= NSCalendarUnitSecond;
		
		NSAttributedString* (^AttributedStringForLogEntry)(SCDatabaseLogEntry *logEntry);
		AttributedStringForLogEntry = ^ NSAttributedString *(SCDatabaseLogEntry *logEntry){
			
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
			
			// Format: yyyy-MM-dd HH:mm:ss:SSS
			// Space : 123456789_123456789_1234 (don't forget trailing \n)
			//
			size_t tsSize = 24;
			char timestamp[tsSize];
			
			NSDateComponents *components = [calendar components:calendarUnitFlags fromDate:logEntry.timestamp];
			
			NSTimeInterval ti = [logEntry.timestamp timeIntervalSinceReferenceDate];
			int milliseconds = (int)((ti - floor(ti)) * 1000);
			
			snprintf(timestamp, tsSize, "%04ld-%02ld-%02ld %02ld:%02ld:%02ld:%03d", // yyyy-MM-dd HH:mm:ss:SSS
			  (long)components.year,
			  (long)components.month,
			  (long)components.day,
			  (long)components.hour,
			  (long)components.minute,
			  (long)components.second, milliseconds);
			
			NSString *str = [NSString stringWithFormat:@"%s %@\n", timestamp, logEntry.message];
			
			return [[NSAttributedString alloc] initWithString:str attributes:attributes];
		};
		
		NSUInteger offset = range.location;
		NSUInteger limit = range.length;
		
		// enforce upper limit to avoid huge RTF file
		NSUInteger max = 1000;
		if (limit > max)
		{
			NSUInteger diff = limit - max;
			offset += diff;
			limit -= diff;
		}
		
		NSMutableAttributedString *mutableAttrStr = [[NSMutableAttributedString alloc] init];
		
		[transaction enumerateLogEntriesWithLimit:limit
		                                   offset:offset
		                                    block:^(id logEntryID, SCDatabaseLogEntry *logEntry, BOOL *stop)
		{
			NSAttributedString *attrStr = AttributedStringForLogEntry(logEntry);
			if (attrStr) {
				[mutableAttrStr appendAttributedString:attrStr];
			}
		}];
		
		[SCDatabaseLogger maskJIDsInAttributedString:mutableAttrStr];
		
	//	NSString *uuid = [[NSUUID UUID] UUIDString];
	//	NSString *fileName = [uuid stringByAppendingString:@".rtf"];
	//	NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
	//
	//	NSURL *url = [NSURL fileURLWithPath:filePath];
	//
	//	NSError *error = nil;
	//	BOOL success = [SCDatabaseLogger exportAttributedString:mutableAttrStr toRTFWithURL:url error:&error];
		
		NSError *error = nil;
		NSData *data = [SCDatabaseLogger convertAttributedString:mutableAttrStr toRTFWithError:&error];
		
		if (data) {
			outputData = data;
		}
		else {
			NSLogError(@"Error converting attributedString to RTF: %@", error);
		}
		
	} completionBlock:^{
	#pragma clang diagnostic push
	#pragma clang diagnostic warning "-Wimplicit-retain-self"
		
		__strong typeof(self) strongSelf = weakSelf;
		if (strongSelf)
		{
			strongSelf.rtfData = outputData;
			strongSelf->rtfTaskComplete = YES;
			
			[strongSelf finishSubmitReportIfNeeded];
		}
		
	#pragma clang diagnostic pop
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Submission Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)reportInfo
{
	NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSString *appBuild = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
	
	NSString *osVersion = [[UIDevice currentDevice] systemVersion];
	
	NSString *username = [STDatabaseManager.currentUser.jid bare];
	
	BOOL isApsEnvironmentDevelopment = [AppConstants isApsEnvironmentDevelopment];
	
	return @{
	  report_key_appVersion     : (appVersion ?: @""),
	  report_key_appBuild       : (appBuild   ?: @""),
	  report_key_iOSVersion     : (osVersion  ?: @""),
	  report_key_username       : (username   ?: @""),
	  report_key_apsEnvironment : (isApsEnvironmentDevelopment ? @"development" : @"production"),
	};
}

- (NSString *)userDescription
{
	if (hasClearedTextView)
		return textView.text;
	else
		return @"";
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)textViewShouldBeginEditing:(UITextView *)sender
{
	if (!hasClearedTextView)
	{
		textView.text = @"";
		hasClearedTextView = YES;
	}
	
	return YES;
}

- (void)cancelDoneButtonTapped:(__unused id)sender
{
	if ([textView isFirstResponder]) {
		[textView resignFirstResponder];
	}
	
	[STAppDelegate.window.rootViewController dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)submitReport
{
	NSLogVerbose(@"%@", NSStringFromSelector(_cmd));
	
	if ([textView isFirstResponder]) {
		[textView resignFirstResponder];
	}
	
	spinner.hidden = NO;
	[spinner startAnimating];
	
	textView.editable = NO;
	submitButton.enabled = NO;
	
	UIColor *color = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
	
	[submitButton setTitle:originalSubmitButtonTitle forState:UIControlStateDisabled];
	[submitButton setTitleColor:color forState:UIControlStateDisabled];
	
	if (!rtfTaskComplete) {
		waitingForRtfTask = YES;
	}
	else {
		[self _submitReport];
	}
}

- (void)finishSubmitReportIfNeeded
{
	NSLogVerbose(@"%@", NSStringFromSelector(_cmd));
	
	if (waitingForRtfTask)
	{
		[self _submitReport];
		waitingForRtfTask = NO;
	}
}

- (void)_submitReport
{
	NSLogVerbose(@"%@", NSStringFromSelector(_cmd));
	
//	// Faking it
//	
//	__weak typeof(self) weakSelf = self;
//	dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC));
//	dispatch_after(delay, dispatch_get_main_queue(), ^{
//		
//		[weakSelf _uploadFailed:nil];
//	//	[weakSelf _uploadSucceeded];
//	});
	
	NSMutableDictionary *reportInfo = [self.reportInfo mutableCopy];
	
	reportInfo[report_key_report] = self.userDescription ?: @"";
	
	NSString *logDataForJSON = [self.rtfData base64EncodedStringWithOptions:0];
	reportInfo[report_key_log] = logDataForJSON ?: @"";
	
	__weak typeof(self) weakSelf = self;
	
	[[SCWebAPIManager sharedInstance] postFeedbackForLocalUser:STDatabaseManager.currentUser
	                                            withReportInfo:reportInfo
	                                           completionBlock:^(NSError *error, NSDictionary *infoDict)
	{
		if (error)
			[weakSelf _uploadFailed:error];
		else
			[weakSelf _uploadSucceeded];
	}];
}

- (void)_uploadFailed:(__unused NSError *)error
{
	NSLogVerbose(@"%@", NSStringFromSelector(_cmd));
	
	[spinner stopAnimating];
	spinner.hidden = YES;
	
	textView.editable = YES;
	submitButton.enabled = YES;
	
	NSString *title = NSLocalizedString(@"Error sending report! Try again.",
	                                    @"Button title - indicates report submission failed");
	UIColor *color = [UIColor colorWithRed:0.5 green:0.0 blue:0 alpha:1.0];
	
	[submitButton setTitle:title forState:UIControlStateNormal];
	[submitButton setTitleColor:color forState:UIControlStateNormal];
}

- (void)_uploadSucceeded
{
	NSLogVerbose(@"%@", NSStringFromSelector(_cmd));
	
	[spinner stopAnimating];
	spinner.hidden = YES;
	
	NSString *title = NSLocalizedString(@"Thank You! Your report has been submitted.",
	                                    @"Button title - indicates report submission was successful");
	UIColor *color = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1.0];
	
	[submitButton setTitle:title forState:UIControlStateDisabled];
	[submitButton setTitleColor:color forState:UIControlStateDisabled];
	
	self.navigationItem.rightBarButtonItem =
	  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
	                                                target:self
	                                                action:@selector(cancelDoneButtonTapped:)];
	
	// Auto-dismiss view after a short delay
	
	__weak typeof(self) weakSelf = self;
	dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC));
	dispatch_after(delay, dispatch_get_main_queue(), ^{
		
		__strong typeof(self) strongSelf = weakSelf;
		if (strongSelf == nil) return;
		
		if (strongSelf.navigationController.topViewController == strongSelf)
		{
			[strongSelf cancelDoneButtonTapped:nil];
		}
	});
}

@end
