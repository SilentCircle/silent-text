## About this class

This class make it easier to use `UIActionSheet` with blocks.

This allows you to provide directly the code to execute (as a block) in return to the tap on a button,
instead of declaring a delegate and implementing the corresponding methods.

This also has the huge advantage of **simplifying the code especially when using multiple `UIActionSheets`** in the same object (as in such case, it is not easy to have a clean code if you share the same delegate)

_Note: You may also be interested in [OHAlertView](https://github.com/AliSoftware/OHAlertView)_

## Usage Example

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
     
## ActionSheets with timeout

You can also use this class to generate an ActionSheet that will be dismissed after a given time.
_(You can even add a dynamic text on your sheet to display the live countdown)_

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

## Compatibility Notes

* This class uses blocks, which is a feature introduced in iOS 4.0.
* This class is compatible with both ARC and non-ARC projects.

## License

This code is under MIT License.

## CocoaPods

This class is referenced in CocoaPods, so you can simply add `pod OHActionSheet` to your Podfile to add it to your pods.
