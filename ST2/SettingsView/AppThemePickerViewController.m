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
//  AppThemePickerViewController.m
//  ST2
//
//  Created by mahboud on 1/12/14.
//

#import "AppTheme.h"
#import "AppThemeTableViewCell.h"
#import "AppThemeView.h"
#import "AppThemePickerViewController.h"

@interface AppThemePickerViewController ()
@property (weak, nonatomic) IBOutlet UITableView *themeListTableView;
//@property (strong, nonatomic) IBOutlet NSLayoutConstraint *dynamicHeight;
@end

@implementation AppThemePickerViewController
static NSString *CellIdentifier = @"ThemeCell";


- (id) init
{
	self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil];
	if (self != nil) {
		
	}
	return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	self.navigationItem.title = NSLocalizedString(@"Themes", @"Themes label");
	self.themeListTableView.delegate = self;
	self.themeListTableView.dataSource = self;
	//	[self.themeListTableView registerClass:[AppThemeTableViewCell class] forCellReuseIdentifier:CellIdentifier];
	[self.themeListTableView registerNib: [UINib nibWithNibName:@"AppThemeTableViewCell" bundle:nil] forCellReuseIdentifier:CellIdentifier];

	NSString *currName = [AppTheme getSelectedKey];
	NSArray *allNames = [AppTheme getAllThemeKeys];
	NSInteger index = [allNames indexOfObject:currName];
	[self.themeListTableView selectRowAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
}

- (void) viewDidAppear:(BOOL)animated
{
	[self.themeListTableView flashScrollIndicators];

}
//
//-(void)viewDidLayoutSubviews
//{
//    CGFloat height = MIN(self.view.bounds.size.height, self.themeListTableView.contentSize.height);
//    self.t.constant = height;
//    [self.view layoutIfNeeded];
//}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [AppTheme count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	
	AppThemeTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
	
    // Configure the cell...
//	cell.themeName.textAlignment = NSTextAlignmentCenter;
    NSString* themeKey = [AppTheme getThemeKeyForIndex:indexPath.row];
    AppTheme* theTheme = [AppTheme getThemeByKey: themeKey];
 	cell.themeName.text = theTheme.localizedName;
 //
//	UIView	*themedView = [[AppThemeView alloc] initWithThemeName: cell.themeName.text andTheme:[AppTheme getThemeByName:cell.themeName.text]];
//	themedView.layer.borderColor = [UIColor grayColor].CGColor;
//	themedView.layer.borderWidth = 1.0;
//	themedView.layer.cornerRadius = 5.0;
//	themedView.clipsToBounds = YES;
//	
//	UIImage *anImage = [self snapshot: themedView];
//	cell.themeImageView.image = anImage;
//	
	UIView	*themedView = [[AppThemeView alloc] initWithThemeName: themeKey
                                                        andTheme:[AppTheme getThemeByKey:themeKey]];
	cell.themeImageView.image = [self snapshot: themedView];
	cell.themeImageView.backgroundColor = [UIColor blackColor];
    return cell;
}

- (UIImage *) snapshot:(UIView *) view
{
	UIImage *image;
    UIGraphicsBeginImageContext(view.frame.size);
	//new iOS 7 method to snapshot
//	BOOL gotit = [view drawViewHierarchyInRect:view.frame afterScreenUpdates:YES];
	[view.layer renderInContext:UIGraphicsGetCurrentContext()];
	image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	return image;
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
    NSString* theme  =  [AppTheme getThemeKeyForIndex:indexPath.row];
	[AppTheme selectWithKey: theme];
    [AppTheme setSelectedKey:theme];
    
    //ET 01/30/15 - dismiss on selection
    if ([_delegate respondsToSelector:@selector(popoverNeedsDismiss)])
    {   // Call delegate (SettingsVC) to dismiss with no animation
        [_delegate popoverNeedsDismiss];
    }
}

/*
 - (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
 return 44.0f;
 }
 */

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
