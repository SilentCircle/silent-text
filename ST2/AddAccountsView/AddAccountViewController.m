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
//  AddAccountViewController.m
//  ST2
//
//  Created by mahboud on 3/12/14.
//

#import "AddAccountViewController.h"
#import "AppDelegate.h"

@interface AddAccountTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel     * usernameLabel;
@property (weak, nonatomic) IBOutlet UITextField * usernameTextField;

@property (weak, nonatomic) IBOutlet UILabel     * passwordLabel;
@property (weak, nonatomic) IBOutlet UITextField * passwordTextField;

@property (weak, nonatomic) IBOutlet UILabel  * showPasswordLabel;
@property (weak, nonatomic) IBOutlet UISwitch * showPasswordSwitch;

@property (weak, nonatomic) IBOutlet UILabel     * deviceLabel;
@property (weak, nonatomic) IBOutlet UITextField * deviceTextField;

@property (weak, nonatomic) IBOutlet UIButton * activateButton;

@property (weak, nonatomic) IBOutlet UILabel  * networkLabel;
@property (weak, nonatomic) IBOutlet UIButton * networkButton;



@end
@interface AddAccountViewController ()

- (void)activateAction:(UIButton *)activateButton;
- (void)networkAction:(UIButton *)networkButton;
- (void)showPasswordAction:(UISwitch *)spSwitch;

@end

@implementation AddAccountViewController {
	
	__weak IBOutlet UITableView *tableView;
	
}
- (id) init
{
	
	UIStoryboard *storyboard = [UIStoryboard storyboardWithName: @"AddAccountViewController" bundle: nil];
    return [storyboard instantiateViewControllerWithIdentifier: @"AddAccount"];

	self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil];
	if (self != nil) {
	}
	return self;
}



- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	
	self.title = NSLocalizedString(@"Add Account", @"AddAccountsViewController title");
	self.navigationItem.leftBarButtonItem =  STAppDelegate.settingsButton;

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 6;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
    NSString *CellIdentifier = [NSString stringWithFormat:@"Cell%02ld", (long)indexPath.row];

//	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
	if( cell == nil ) {
//		cell.backgroundColor = [UIColor clearColor];
		//		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
//		cell.contentView.translatesAutoresizingMaskIntoConstraints = NO;
//		CGFloat width = cell.contentView.frame.size.width;
//		CGFloat height = cell.contentView.frame.size.height;
//		cell.backgroundColor = [UIColor clearColor];
//		UITextField *textField;
//		NSArray *horizContraints;
//		NSString *visualFormat;
//		UILabel *label;
//		switch (indexPath.row) {
//			case 0:
//				label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width / 5.0 * 2.0, height)];
//				label.autoresizingMask = 0;
//				label.text = @"Username";
//				label.textAlignment = NSTextAlignmentRight;
//				[label sizeToFit];
//				[cell.contentView addSubview:label];
//				
//				textField = [[UITextField alloc] initWithFrame:CGRectMake(width / 5.0 * 2.0 + 10, 0, width / 5.0 * 3.0, height)];
//				textField.borderStyle = UITextBorderStyleRoundedRect;
//				[cell.contentView addSubview:textField];
////				visualFormat = [NSString stringWithFormat: @"H:|-[label]-%f-[textField(==100)]-10.0-|", 10.0];
////				horizContraints = [NSLayoutConstraint
////											constraintsWithVisualFormat:visualFormat
////											options:0
////											metrics:nil
////											views:NSDictionaryOfVariableBindings(label, textField)];
////
////				[cell.contentView addConstraints:horizContraints];
//			break;
//				
//			case 1:
//				label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width / 5.0 * 2.0, height)];
//				label.text = @"Password";
//				label.textAlignment = NSTextAlignmentRight;
//				label.backgroundColor = [UIColor yellowColor];
//				[cell.contentView addSubview:label];
//				break;
//			case 2:
//				label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width / 5.0 * 2.0, height)];
//				label.text = @"Show Password";
//				label.textAlignment = NSTextAlignmentRight;
//				label.backgroundColor = [UIColor yellowColor];
//				[cell.contentView addSubview:label];
//				break;
//			case 3:
//				label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width / 5.0 * 2.0, height)];
//				label.text = @"Device";
//				label.textAlignment = NSTextAlignmentRight;
//				label.backgroundColor = [UIColor yellowColor];
//				[cell.contentView addSubview:label];
//				break;
//			case 4:
//				label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width / 5.0 * 2.0, height)];
//				label.text = @"-";
//				label.textAlignment = NSTextAlignmentRight;
//				label.backgroundColor = [UIColor yellowColor];
//				[cell.contentView addSubview:label];
//				break;
//			case 5:
//				label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width / 5.0 * 2.0, height)];
//				cell.backgroundColor = [UIColor clearColor];
//				label.text = @"Network";
//				label.textAlignment = NSTextAlignmentRight;
//				label.backgroundColor = [UIColor yellowColor];
//				[cell.contentView addSubview:label];
//				break;
//
//			default:
//				break;
//		}
////		UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
////		button.frame = cell.contentView.frame;
////		[button setTitle:buttonTitle forState:UIControlStateNormal];
////		NSString *fontName = button.titleLabel.font.fontName;
////		button.titleLabel.font = [UIFont fontWithName:fontName size:20];
////		[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
////		button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
////		[cell.contentView addSubview:button];
////
//	
    // Configure the cell...
	}
    return cell;
}
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor clearColor];
}

/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */


/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
 }
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */


/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */


/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    /*
     DetailViewController *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     [detailViewController release];
     */
}

/*
 - (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
 return 44.0f;
 }
 */
@end
