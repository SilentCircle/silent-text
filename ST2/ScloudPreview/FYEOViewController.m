/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

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
//
//  FYEOViewController.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 2/12/14.
//

#import "FYEOViewController.h"
#import "STLogging.h"

// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && vinnie_moscaritolo
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@interface FYEOViewController ()

@end

@implementation FYEOViewController
{
    NSArray*   qlItems;

};


@synthesize delegate = delegate;


- (id)initWithDelegate:(id)inDelagate qlItems:(NSArray*)qlItemsIn
{
	if ((self = [super initWithNibName:@"FYEOViewController" bundle:nil]))
	{
		delegate = inDelagate;
        qlItems = qlItemsIn;
        
 	}
	return self;
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    
	self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                  target:self
                                                  action:@selector(cancelButtonTapped:)];
    
    
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(userDidTakeScreenshot:)
												 name:UIApplicationUserDidTakeScreenshotNotification
											   object:nil];
	
    
    self.navigationItem.title = NSLocalizedString(@"DO NOT FORWARD", @"DO NOT FORWARD");
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)viewWillDisappear:(BOOL)animated;
{
    
    if ([delegate respondsToSelector:@selector(fyeoViewControllerWillDismiss:)]) {
        [delegate fyeoViewControllerWillDismiss:self];
    }

}


- (void)userDidTakeScreenshot:(NSNotification *)notification
{
    
    QLItem* item = [qlItems firstObject];
    NSURL *url =  item.scloud.decryptedFileURL;
   

    DDLogRed(@"Screenshot detected of %@",  [url lastPathComponent] );
    
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle: NSLocalizedString(@"Screenshot detected", @"Screenshot detected")
                          message: [NSString stringWithFormat: @"%@: %@  ",
									NSLocalizedString(@"Detected screenshot of the DO NOT FORWARD document", @"detected screenshot of the DO NOT FORWARD document"),
									[url lastPathComponent] ]
                          delegate: nil
                          cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                          otherButtonTitles:nil];
    [alert show];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)cancelButtonTapped:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:NULL];

}



@end
