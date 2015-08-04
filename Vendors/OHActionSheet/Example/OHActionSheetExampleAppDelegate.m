//
//  AlertsExExampleAppDelegate.m
//  AlertsExExample
//
//  Created by Olivier on 31/01/11.
//  Copyright 2011 AliSoftware. All rights reserved.
//

#import "OHActionSheetExampleAppDelegate.h"
#import "OHActionSheet.h"


@implementation OHActionSheetExampleAppDelegate


-(IBAction)showSheet1
{
	NSArray* flavours = [NSArray arrayWithObjects:@"chocolate",@"vanilla",@"strawberry",nil];
	
	[OHActionSheet showSheetInView:self.window
							   title:@"Ice cream?"
				   cancelButtonTitle:@"Maybe later"
			  destructiveButtonTitle:@"No thanks!"
				   otherButtonTitles:flavours
						  completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	 {
		 NSLog(@"button tapped: %d",buttonIndex);
		 if (buttonIndex == sheet.cancelButtonIndex) {
			 self.status.text = @"Your order has been postponed";
		 } else if (buttonIndex == sheet.destructiveButtonIndex) {
			 self.status.text = @"Your order has been cancelled";
		 } else {
			 NSString* flavour = [flavours objectAtIndex:(buttonIndex-sheet.firstOtherButtonIndex)];
			 self.status.text = [NSString stringWithFormat:@"You ordered a %@ ice cream.",flavour];
		 }
	 }];
}

-(IBAction)showSheet2
{
	NSArray* flavours = [NSArray arrayWithObjects:@"apple",@"pear",@"banana",nil];

	[[[OHActionSheet alloc] initWithTitle:@"What's your favorite fruit?"
                 cancelButtonTitle:@"Don't care"
            destructiveButtonTitle:nil
                 otherButtonTitles:flavours
                        completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	 {
		 NSLog(@"button tapped: %d",buttonIndex);
		 if (buttonIndex == sheet.cancelButtonIndex) {
			 self.status.text = @"You didn't answer the question";
		 } else if (buttonIndex == -1) {
			 self.status.text = @"The action sheet timed out";
		 } else {
			 NSString* fruit = [flavours objectAtIndex:(buttonIndex-sheet.firstOtherButtonIndex)];
			 self.status.text = [NSString stringWithFormat:@"Your favorite fruit is %@.",fruit];
		 }
	 }] showInView:self.window withTimeout:8 timeoutButtonIndex:-1];
}



/////////////////////////////////////////////////////////////////////////////
// MARK: -
// MARK: App LifeCycle
/////////////////////////////////////////////////////////////////////////////

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    // Override point for customization after application launch.
    [self.window makeKeyAndVisible];
    return YES;
}

@end
