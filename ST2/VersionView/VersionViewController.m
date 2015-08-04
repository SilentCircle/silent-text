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
//
//  VersionViewController.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 10/21/13.
//

#import <SCCrypto/SCcrypto.h>

#import "VersionViewController.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "git_version_hash.h"
#import "LicensesViewController.h"
#import "STPreferences.h"


@interface VersionViewController ()

@end

@implementation VersionViewController
{
    NSString *versionStr;
    NSString *buildStr;
    NSString *dateString;
    NSString *gitCommitVersion;
    NSString *sccryptoString;
    NSString *xcodeString;
    NSString *iOSSDKString;

}
- (id)initWithProperNib
{
    
	return [self initWithNibName:@"VersionViewController" bundle:nil];
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
  
//    self.navigationController.navigationBar.barStyle =  UIBarStyleBlack;
//    self.navigationController.navigationBar.translucent  = YES;
//    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    
    //    self.collectionView.contentInset = UIEdgeInsetsMake(self.navigationController.navigationBar.frame.size.height, 0,0,0);
    
    //    self.view.backgroundColor =  [UIColor colorWithWhite: .95 alpha:1];
   
    if (AppConstants.isIPhone)
    {
        
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"Done")
                                                                                 style:UIBarButtonItemStylePlain target:self
                                                                                action:@selector(handleActionBarDone)];
		
       
    }
	self.navigationItem.title = NSLocalizedString(@"SilentText Info", @"SilentText Info");
 	
	NSBundle *main = NSBundle.mainBundle;
	versionStr = [main objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
	NSString *build   = [main objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
	
    BOOL isDebug = [AppConstants isApsEnvironmentDevelopment];
    if(isDebug) versionStr = [versionStr stringByAppendingString:@" dev"];
    
	// this one incorporates the build number
 //   NSString* appVersion = [NSString stringWithFormat: @"%@ (%@)", version, build];
	buildStr = [NSString stringWithFormat: @"%@", build];
	gitCommitVersion = [NSString stringWithFormat: @"%s", GIT_COMMIT_HASH];
    
	dateString = [NSString stringWithFormat: @"%s", BUILD_DATE];
	NSString *xcodeVersion = [main objectForInfoDictionaryKey: @"DTXcode"];
	NSString *xcodeBuild = [main objectForInfoDictionaryKey: @"DTXcodeBuild"];
	//	NSString *xcodeVersion = @"4.6.3 (4H1503)";
	
    xcodeString = [NSString stringWithFormat: @"%@ (%@)", xcodeVersion, xcodeBuild];
   
    char scrypto_version_string[64];
    SCCrypto_GetVersionString(sizeof(scrypto_version_string) , scrypto_version_string);
    
    sccryptoString = [NSString stringWithFormat: @"%s", scrypto_version_string];
    
	NSInteger iosSDK = __IPHONE_OS_VERSION_MAX_ALLOWED;
	NSInteger iosSDKMajor = iosSDK / 10000;
	NSInteger iOSSDKMinor = (iosSDK / 100) % 100;
	NSInteger iosSDKRevision = iosSDK % 100;
	NSString *iOSSDKBuild = [main objectForInfoDictionaryKey: @"DTSDKBuild"];
    
	NSString *iosSDKVersion = iosSDKRevision ?
    [NSString stringWithFormat: @"%ld.%ld.%ld", (long)iosSDKMajor, (long)iOSSDKMinor, (long)iosSDKRevision]
    : [NSString stringWithFormat: @"%ld.%ld", (long)iosSDKMajor, (long)iOSSDKMinor];

    iOSSDKString = [NSString stringWithFormat: @"%@ (%@)", iosSDKVersion, iOSSDKBuild];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 4;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    NSInteger rows = 0;
    
    switch(section)
    {
        case  3:
			rows = 7; break;
            
		case  0:
		case  1:
        case  2:
			rows = 1; break;
            
    }
    return  rows;
    
}


-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = NULL;
    NSString* label = NULL;
    NSString* detail = NULL;
     UIColor* textColor = [UIColor blackColor];
    
    if ((indexPath.section  < 3)) {
		NSString * settingCellIdentifier;
		NSString * buttonTitle;
		SEL		action;
        
		if (indexPath.section == 0) {
			settingCellIdentifier = @"ackStatementCellButton";
			buttonTitle = NSLocalizedString(@"Acknowledgements", @"Acknowledgements");
			action = @selector(acknowledgeAction:);
		}
		else if (indexPath.section == 1) {
			settingCellIdentifier = @"privStatementCellButton";
			buttonTitle = NSLocalizedString(@"Privacy Statement", @"Privacy Statement");
			action = @selector(privacyAction:);
		}
        else if (indexPath.section == 2) {
            settingCellIdentifier = @"termsOfServiceCellButton";
            buttonTitle = NSLocalizedString(@"Terms of Service", @"Terms of Service");
            action = @selector(termAction:);
        }

		cell = [tableView dequeueReusableCellWithIdentifier:settingCellIdentifier];
		
		if( cell == nil ) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:settingCellIdentifier];
			UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
			button.frame = cell.contentView.frame;
			[button setTitle:buttonTitle forState:UIControlStateNormal];
			NSString *fontName = button.titleLabel.font.fontName;
			button.titleLabel.font = [UIFont fontWithName:fontName size:20];
			[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
			button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			[cell.contentView addSubview:button];
		}
//		cell.textLabel.text = @"Acknowledgements";
	}
		
    else if (indexPath.section == 3) {
		
		static NSString * settingCellIdentifier = @"VersionCell";
		
		cell = [tableView dequeueReusableCellWithIdentifier:settingCellIdentifier];
		
		if( cell == nil ) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:settingCellIdentifier];
			
		}
		cell.accessoryType = UITableViewCellAccessoryNone ;
	  
		switch( indexPath.row)
		{
			case 0:
				 label = @"Version";
				 detail = versionStr;
				 break;
				
			case 1:
				label = @"Date";
				detail = dateString;
				break;
	 
			case 2:
				label = @"Build";
				detail = buildStr;
				break;
	 
			case 3:
				label = @"Git Commit";
				detail = gitCommitVersion;
				break;
	 
			case 4:
				label = @"SC Crypto";
				detail = sccryptoString;
				break;
	 
			case 5:
				label = @"Xcode";
				detail = xcodeString;
				break;
	 
			case 6:
				label = @"iOS SDK";
				detail = iOSSDKString;
				break;
				
		}
		cell.textLabel.textAlignment = NSTextAlignmentRight;
		[cell.textLabel setText:label];
		cell.textLabel.textColor = textColor;
		[cell.detailTextLabel setText:detail];
    }
    return  cell;
    
}



- (IBAction)privacyAction:(id)sender
{
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://silentcircle.com/web/privacy/"]];

//	NSURL *url = [[NSBundle mainBundle] URLForResource:@"privacy" withExtension:@"html"];
//	LicensesViewController *lvc = [[LicensesViewController alloc] initWithURL:url];
//	
//	lvc.modalPresentationStyle = UIModalPresentationCurrentContext;
//	lvc.navigationItem.title = NSLocalizedString(@"Privacy Statement", @"Privacy Statement");
//	
//	[self displayFullscreen:lvc];
}

- (IBAction)termAction:(id)sender
{
    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://accounts.silentcircle.com/terms/"]];
    
   }




- (IBAction)acknowledgeAction:(id)sender
{
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"licenses" withExtension:@"html"];
	LicensesViewController *lvc = [[LicensesViewController alloc] initWithURL:url];
	
	lvc.modalPresentationStyle = UIModalPresentationCurrentContext;
	lvc.navigationItem.title = NSLocalizedString(@"Acknowledgements", @"Acknowledgements");
	
	[self displayFullscreen:lvc];
}

- (void)displayFullscreen:(UIViewController *)viewController
{
	if (AppConstants.isIPhone)
    {
		[self.navigationController pushViewController:viewController animated:YES];
	}
	else
	{
		UINavigationController *navController =
		  [[UINavigationController alloc] initWithRootViewController:viewController];
		
		viewController.navigationItem.leftBarButtonItem =
		  [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"Done")
		                                   style:UIBarButtonItemStylePlain
		                                  target:self
		                                  action:@selector(handleActionBarDone)];
		
		[self presentViewController:navController animated:YES completion:nil];
	}
}

- (void) handleActionBarDone
{
	[self dismissViewControllerAnimated:YES completion:nil];
}
 @end
