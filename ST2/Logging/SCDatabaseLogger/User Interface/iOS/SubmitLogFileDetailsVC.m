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
#import "SubmitLogFileDetailsVC.h"

// We probably shouldn't be using DDLog() statements within the DDLog implementation.
// But we still want to leave our log statements for any future debugging,
// and to allow other developers to trace the implementation (which is a great learning tool).
//
// So we use primitive logging macros around NSLog.
// We maintain the NS prefix on the macros to be explicit about the fact that we're using NSLog.

#define LOG_LEVEL 4

#define LOG_PREFIX @"SubmitLogFileDetailsVC: "

#define NSLogError(frmt, ...)    do{ if(LOG_LEVEL >= 1) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(LOG_LEVEL >= 2) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(LOG_LEVEL >= 3) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(LOG_LEVEL >= 4) NSLog((LOG_PREFIX frmt), ##__VA_ARGS__); } while(0)


@implementation SubmitLogFileDetailsVC {
@private
	
	__weak IBOutlet UITextView *textView;
	
	BOOL isObserver;
}

@synthesize root = root;

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	NSDictionary *reportInfo = root.reportInfo;
	NSString *reportStr = [NSString stringWithFormat:@"%@\n\n", [reportInfo description]];
	
	NSDictionary *attributes = @{
	  NSForegroundColorAttributeName : [UIColor blackColor]
	};
	NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:reportStr attributes:attributes];
	
	textView.attributedText = attrStr;
	
	NSData *rtfData = root.rtfData;
	if (rtfData) {
		[self loadRtfWithData:rtfData];
	}
	else {
		[self addRtfObserver];
	}
}

- (void)dealloc
{
	[self removeRtfObserver];
}

- (void)addRtfObserver
{
	if (!isObserver)
	{
		isObserver = YES;
		[root addObserver:self
		       forKeyPath:NSStringFromSelector(@selector(rtfData))
		          options:NSKeyValueObservingOptionNew
		          context:NULL];
	}
}

- (void)removeRtfObserver
{
	if (isObserver)
	{
		isObserver = NO;
		[root removeObserver:self forKeyPath:NSStringFromSelector(@selector(rtfData))];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	NSData *rtfData = root.rtfData;
	if (rtfData)
	{
		[self loadRtfWithData:rtfData];
		[self removeRtfObserver];
	}
}

- (void)loadRtfWithURL:(NSURL *)rtfURL
{
	__weak typeof(self) weakSelf = self;
	
	dispatch_queue_t bgQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(bgQ, ^{ @autoreleasepool {
	#pragma clang diagnostic push
	#pragma clang diagnostic warning "-Wimplicit-retain-self"
		
		NSError *error = nil;
		NSAttributedString *attrStr =
		  [[NSAttributedString alloc] initWithFileURL:rtfURL options:nil documentAttributes:nil error:&error];
		
		if (error)
		{
			NSLogError(@"Error reading RTF file: %@", error);
		}
		else
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				
				[weakSelf appendLogFile:attrStr];
			});
		}
		
	#pragma clang diagnostic pop
	}});
}

- (void)loadRtfWithData:(NSData *)rtfData
{
	__weak typeof(self) weakSelf = self;
	
	dispatch_queue_t bgQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(bgQ, ^{ @autoreleasepool {
	#pragma clang diagnostic push
	#pragma clang diagnostic warning "-Wimplicit-retain-self"
	
		NSError *error = nil;
		NSAttributedString *attrStr =
		  [[NSAttributedString alloc] initWithData:rtfData options:nil documentAttributes:nil error:&error];
		
		if (error)
		{
			NSLogError(@"Error reading RTF data: %@", error);
		}
		else
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				
				[weakSelf appendLogFile:attrStr];
			});
		}
		
	#pragma clang diagnostic pop
	}});
}

- (void)appendLogFile:(NSAttributedString *)attrStr
{
	NSAssert([NSThread isMainThread], @"Attempting UI changes on non-main-thread !");
	
	[textView.textStorage appendAttributedString:attrStr];
}

@end
