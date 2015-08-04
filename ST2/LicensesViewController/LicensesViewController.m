/*
Copyright (C) 2013-2015, Silent Circle, LLC. All rights reserved.

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
#import "AppDelegate.h"
#import "LicensesViewController.h"
#import "STLogging.h"


// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_WARN;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


@implementation LicensesViewController
{
	NSURL *url;
}

- (id)initWithURL:(NSURL *)inURL
{
	if ((self = [super init]))
	{
		url = inURL;
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.edgesForExtendedLayout = UIRectEdgeNone;
	self.extendedLayoutIncludesOpaqueBars = NO;
	
	[self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
                                                 navigationType:(UIWebViewNavigationType)navigationType
{
	DDLogVerbose(@"navigationType: %d", (int)navigationType);
	DDLogVerbose(@"request.URL: %@", request.URL);
	
	if (navigationType == UIWebViewNavigationTypeLinkClicked)
	{
       // allow the mailto:
        if ([[[request URL] scheme] isEqual:@"mailto"]) {
            [[UIApplication sharedApplication] openURL:[request URL]];
            return NO;
        }
        
		// Prevent navigating to other sites.
		// But allow inline links.
		//
		// E.g. <a href="section_within_page"/>
		//
		// There may be a more precise way to do this with NSURL...
		
		NSString *str1 = [url absoluteString];
		NSString *str2 = [request.URL absoluteString];
		
		if ([str1 hasPrefix:str2])
			return YES;
		else
			return NO;
	}
	
	return YES;
}

@end
