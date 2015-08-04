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
 
#import "ConversationInfoViewController.h"
#import "PKRevealController.h"
#import "AppConstants.h"
#import "AppDelegate.h"

#import "BurnTimePickerController.h"
#import <QuartzCore/QuartzCore.h>


@implementation ConversationInfoViewController

#define custom_color_background 1
@synthesize delegate;
@synthesize section0HeaderLabel;
@synthesize section0FooterLabel;
@synthesize section1FooterLabel;
@synthesize section2FooterLabel;
@synthesize section3FooterLabel;

@synthesize conversationId = conversationId;

- (void)setConversationId:(NSString*)inConversationId
{
    [self.tableView reloadData];
    
    if (conversationId != inConversationId)
    {
        conversationId = inConversationId;
        
        [STAppDelegate.conversationInfoButton setEnabled: conversationId==NULL?NO:YES];
    }
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
    
    // Each view can dynamically specify the min/max width that can be revealed.
   
    [STAppDelegate.revealController setMinimumWidth:300.
									   maximumWidth:300.
								  forViewController:STAppDelegate.conversationInfoNavController];
 
	self.navigationItem.title = NSLocalizedString(@"Conversation Options", @"Conversation Options");
	showBurnTime = NO;
#if custom_color_background
    //	self.section0HeaderLabel = [self getHeaderLabelForBlackBackgroundWithText: NSLocalizedString(@"Options for this conversation.", @"Text Options Note")];
	self.section0FooterLabel = [self getFooterLabelForBlackBackgroundWithText:
                                NSLocalizedString(@"After the specified delay, Burn Notice will destroy the selected message.", @"Burn Help")];
    
	self.section1FooterLabel = [self getFooterLabelForBlackBackgroundWithText:
                                NSLocalizedString(@"For added security, verify this message with the recipient.", @"verify help text    ")];
	
    self.section2FooterLabel = [self getFooterLabelForBlackBackgroundWithText: NSLocalizedString(@"Reset the encryption keys.", @"Location Help")];
    
    self.section3FooterLabel = [self getFooterLabelForBlackBackgroundWithText: NSLocalizedString(@"Erase the Conversation.", @"Clear Conversation help")];

 #endif
	//
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}


#pragma mark - API

- (IBAction)showOppositeView:(id)sender
{
    [self.revealController showViewController:self.revealController.leftViewController];
}

- (IBAction)togglePresentationMode:(id)sender
{
    if (![self.revealController isPresentationModeActive])
    {
        [self.revealController enterPresentationModeAnimated:YES
                                                  completion:NULL];
    }
    else
    {
        [self.revealController resignPresentationModeEntirely:NO
                                                     animated:YES
                                                   completion:NULL];
    }
}

#pragma mark - Autorotation

/*
 * Please get familiar with iOS 6 new rotation handling as if you were to nest this controller within a UINavigationController,
 * the UINavigationController would _NOT_ relay rotation requests to his children on its own!
 */

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    CGRect frame = tableView.frame;
    frame.size.width = 260;
    tableView.frame = frame;
    
    return 44;
    
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if (section == 0) {
		if (showBurnTime)
			return 2;
		else
			return 1;
	}
    if (section == 1)
        return 2;
    
    if (section == 2)
		return 1;
    
    if (section == 3)
		return 1;

	return 0;
}

- (NSInteger)tableView:(UITableView *)tableView indentationLevelForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ((indexPath.section == 0 && indexPath.row == 1)) {
		return 2;
	}
	else
		return 0;
}
//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//	if ((indexPath.section == 0 && indexPath.row == 2)) {
//		return 216;
//	}
//	else
//		return tableView.rowHeight;
//
//}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;// = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Configure the cell...
	if ((indexPath.section == 0 && indexPath.row == 0)
        || ((indexPath.section == 1) && indexPath.row == 0)) {
		static NSString *CellIdentifier = @"COVSwitchCell";
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if( cell == nil ) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
			cell.accessoryView = switchView;
			[switchView setOn:showBurnTime animated:NO];
			[switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
			if (indexPath.section == 0 && indexPath.row == 0) {
				burnNoticeSwitch = switchView;
				burnNoticeSwitch.on	= [delegate getBurnNoticeState];
			}
			else if (indexPath.section == 1 && indexPath.row == 0) {
				authenticateSwitch = switchView;
				authenticateSwitch.on = [delegate getAuthenticateState];
			}
			else if (indexPath.section == 1 && indexPath.row == 1) {
				fyeoSwitch = switchView;
				fyeoSwitch.on = [delegate getFYEOState];
			}
		}
	}
	else if (indexPath.section == 2) {
		static NSString *CellIdentifier = @"COVButtonCell";
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		}
	}
    else if (indexPath.section == 3) {
		static NSString *CellIdentifier = @"COVButtonCell";
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
  		}
	}

	else if ((indexPath.section == 0 && indexPath.row == 1)) {
		static NSString *CellIdentifier = @"COVAccessoryCell";
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
	}
    //	else if ((indexPath.section == 0 && indexPath.row == 2)) {
    //		static NSString *CellIdentifier = @"COVPickerCell";
    //		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    //		if (cell == nil) {
    //			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    //			cell.selectionStyle = UITableViewCellSelectionStyleNone;
    //			UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:[tableView rectForRowAtIndexPath:indexPath]];
    //			picker.datePickerMode = UIDatePickerModeCountDownTimer;
    //			cell.accessoryView = picker;
    ////			[switchView setOn:NO animated:NO];
    ////			[switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    //
    //		}
    //	}
	else {
		static NSString *CellIdentifier = @"StdCell";
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
	}
	
	// Get the section index, and so the region for that section.
	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			cell.textLabel.text = NSLocalizedString(@"Burn Notice", @"Burn Notice");
            //			cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
		}
		else if (indexPath.row == 1) {
			cell.textLabel.text = NSLocalizedString(@"Delay", @"Delay");
			cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
			cell.detailTextLabel.text = [self getBurnTimeTextFromTimeValue: [delegate getBurnNoticeDelay]];
		}
	}
	else if (indexPath.section == 1) {
		if (indexPath.row == 0) {
			cell.textLabel.text = NSLocalizedString(@"Verified", @"Verified");
            //			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
            authenticateSwitch.on = [delegate getAuthenticateState];
		}
        
        if (indexPath.row == 1) {
            
            NSDictionary* info =  [delegate getSecureContextInfo];
            
            NSString *SAS  = info?[info valueForKey:kSCIMPInfoSAS]:NULL;
            BOOL has_secret = [[info valueForKey:kSCIMPInfoHasCS] boolValue];
            BOOL secrets_match = [[info valueForKey:kSCIMPInfoCSMatch] boolValue];
            
            if(SAS)
            {
                cell.textLabel.text = SAS;
                cell.textLabel.textColor = [UIColor blackColor];
                /*
                 cell.textLabel.textColor =  has_secret && secrets_match
                 ?[UIColor greenColor]
                 :[UIColor colorWithRed:1.0 green:.8 blue:0 alpha:.8];
                 */
            }
            else
            {
                cell.textLabel.text = @"Not Verified";
                cell.textLabel.textColor = [UIColor darkGrayColor];
                
            }
            
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.font = [UIFont italicSystemFontOfSize: 16.0];
        }
        
        //		else if (indexPath.row == 1) {
        //			cell.textLabel.text = NSLocalizedString(@"For Your Eyes Only", @"For Your Eyes Only");
        ////			cell.accessoryType = UITableViewCellAccessoryCheckmark;
        //		}
	}
	else if (indexPath.section == 2) {
		cell.textLabel.text = NSLocalizedString(@"Reset Keys", @"Reset Keys");
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
	}
	else if (indexPath.section == 3) {
		cell.textLabel.text = NSLocalizedString(@"Clear Conversation", @"Clear Conversation");
		cell.textLabel.textAlignment = NSTextAlignmentCenter;
	}
	else {
		cell.textLabel.text = [NSString stringWithFormat:@"%d, %d", indexPath.section, indexPath.row];
	}
    //	NSLog(@"tableprep");
    return cell;
}

- (void) buttonPressed:(id)sender
{
}

- (void) switchChanged:(id)sender
{
	UISwitch *aSwitch = (UISwitch *) sender;
    //	UITableViewCell *parentCell = (UITableViewCell *) ((UISwitch *)sender).superview;
	//	UITableView *tableView = (UITableView *)cell.superview;
    //	NSIndexPath *indexPath = [self.tableView indexPathForCell:parentCell];
    //	NSLog(@"%d, %d", indexPath.section, indexPath.row);
    //	if ((indexPath.section == 0 && indexPath.row == 0)) {
	if (aSwitch == burnNoticeSwitch) {
		NSIndexPath *singleIndexPath = [NSIndexPath indexPathForRow:1 inSection:0];
		NSArray *indexArray = [NSArray arrayWithObjects:singleIndexPath,nil];
		showBurnTime = aSwitch.on;
		if (aSwitch.on)
			[self.tableView insertRowsAtIndexPaths:indexArray withRowAnimation:UITableViewRowAnimationFade];
		else
			[self.tableView deleteRowsAtIndexPaths:indexArray withRowAnimation:UITableViewRowAnimationFade];
		[delegate setBurnNoticeState:aSwitch.on];
		[self setBurnTimeToCell:[self getBurnTimeTextFromTimeValue: [delegate getBurnNoticeDelay]]];
        
	}
	else if (aSwitch == authenticateSwitch) {
        [delegate setAuthenticateState:aSwitch.on];
	}
	else if (aSwitch == fyeoSwitch) {
		[delegate setFYEOState:aSwitch.on];
	}
}
// can't do it this way as the text comes out looking ugly on the black background

//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
//	if (section == 0) {
//		return NSLocalizedString(@"These options apply to this conversation only", @"Text Options Note");
//	}
//	return nil;
//}
//
//
//- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
//	if (section == 0) {
//		return NSLocalizedString(@"Turning on Burn Notice will, after a delay, destroy your recipient's copy of each message.  [Fix the shadow on this text!]", @"Burn Help");
//	}
//	return nil;
//}


/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
 {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 }
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */
#pragma mark -
#pragma mark selection of cells

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //	NSIndexPath *rowToSelect = indexPath;
	
    //	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:CGRectZero];
    //	picker.datePickerMode = UIDatePickerModeCountDownTimer;
    //	 [self.view addSubview:picker];
    //
    //	[picker setCenter:CGPointMake(150, 500)]; // place the pickerView outside the screen boundaries
    //	[picker setHidden:NO]; // set it to visible and then animate it to slide up
    //	[UIView beginAnimations:@"slideIn" context:nil];
    //	[picker setCenter:CGPointMake(150, 250)];
    //	[UIView commitAnimations];
    
	//	NSInteger section = indexPath.section;
	//	BOOL isEditing = self.editing;
	//
	//	// If editing, don't allow instructions to be selected
	//	// Not editing: Only allow instructions to be selected
	//	if ((isEditing && section == 0) || (!isEditing && section != 0)) {
	//		[tableView deselectRowAtIndexPath:indexPath animated:YES];
	//		rowToSelect = nil;
	//	}
	if ((indexPath.section == 2) && (indexPath.row == 0)) {
		[delegate resetKeysNow: self.view];
	}
    
    if ((indexPath.section == 3) && (indexPath.row == 0)) {
		[delegate clearConversationNow: self.view];
	}

	return nil;
}
#if custom_color_background
- (UILabel *) getHeaderLabelForBlackBackgroundWithText: (NSString *) text
{
    
	UIFont *font = [UIFont boldSystemFontOfSize:17];
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.backgroundColor = [UIColor clearColor];
	label.font = font;
	label.textColor = [UIColor lightGrayColor];
	label.shadowColor = [UIColor darkGrayColor];
	label.shadowOffset = CGSizeMake(0, 1);
	
	label.text = text;
	label.numberOfLines = 0;
	return label;
}
- (UILabel *) getFooterLabelForBlackBackgroundWithText: (NSString *) text
{
	UIFont *font = [UIFont systemFontOfSize:14];
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.backgroundColor = [UIColor clearColor];
	label.font = font;
	label.textColor = [UIColor whiteColor];
    //	label.shadowColor = [UIColor darkGrayColor];
	label.shadowOffset = CGSizeMake(0, 1);
	label.textAlignment = NSTextAlignmentCenter;
	
	label.text = text;
	label.numberOfLines = 0;
	return label;
}
- (void) setLabelSize:(UILabel *) label withMaxWidth:(CGFloat) maxWidth shrinkSpaceOnEachSideBy: (CGFloat) shrink
{
    //	NSLog(@"setlabel being called for \"%@\" - it had a left of %f", label.text, label.frame.origin.x);
	UIFont *font = label.font;
	CGSize maximumLabelSize = CGSizeMake(maxWidth - 2 * shrink,240);
	CGSize expectedLabelSize = [label.text sizeWithFont:font
                                      constrainedToSize:maximumLabelSize
                                          lineBreakMode:NSLineBreakByWordWrapping];
	CGFloat leftSide;
	if (label.textAlignment == NSTextAlignmentCenter)
		leftSide = (maxWidth - expectedLabelSize.width) /2;
	else
		leftSide = shrink; //label.frame.origin.x;
    
    expectedLabelSize.width = 220;
    
	label.frame = CGRectMake(leftSide, label.frame.origin.y, expectedLabelSize.width, expectedLabelSize.height);
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;
{
    //	NSLog(@"give me header view for section %d", section);
	if (section == 0) {
		UILabel *label = section0HeaderLabel;
		if ([label superview]) {
			return [label superview];
		}
		
		UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 240, label.frame.size.height)];
#define section_header_space_above	10
#define section_header_space_left	20
		label.frame = CGRectMake(section_header_space_left, section_header_space_above, label.frame.size.width, label.frame.size.height);
		
		[headerView addSubview:label];
		
		return headerView;
	}
	return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section;
{
    //	NSLog(@"give me footer view for section %d", section);
	if (section == 0 || section == 1 || section == 2 || section == 3) {
		UILabel *label;
		if (section == 0)
			label = section0FooterLabel;
		else if (section == 1)
			label = section1FooterLabel;
		else  if (section == 2)
			label = section2FooterLabel;
        else  if (section == 3)
			label = section3FooterLabel;

		if ([label superview]) {
			return [label superview];
		}
        
		UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 260, label.frame.size.height)];
        //		footerView.backgroundColor = [UIColor lightGrayColor];
        //		footerView.layer.borderColor = [[UIColor whiteColor] CGColor];
		footerView.layer.cornerRadius = 15;
#define section_footer_space_above	5
		label.frame = CGRectMake((tableView.frame.size.width - label.frame.size.width) /2, section_footer_space_above, label.frame.size.width, label.frame.size.height);
		[footerView addSubview:label];
		
		return footerView;
	}
	return nil;
}
- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    //	NSLog(@"give me header view heigt for section %d for frame %@", section, NSStringFromCGRect(tableView.frame));
	UILabel *label;
	if (section == 0) {
		label = section0HeaderLabel;
        
		[self setLabelSize: label withMaxWidth:tableView.frame.size.width /**- 2 * section_header_space_left**/ shrinkSpaceOnEachSideBy: section_header_space_left];
	}
#define section_header_space_below 10
	if (label)
		return label.frame.size.height + section_header_space_above + section_header_space_below;
	else
		return 0;
	
}
- (CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    //	NSLog(@"give me footer view heigt for section %d for frame %@", section, NSStringFromCGRect(tableView.frame));
	UILabel *label = nil;
	if (section == 0)
		label = section0FooterLabel;
	else if (section == 1)
		label = section1FooterLabel;
	else if (section == 2)
		label = section2FooterLabel;
	else if (section == 3)
		label = section3FooterLabel;
    
    
	if (label) {
		[self setLabelSize: label withMaxWidth:tableView.frame.size.width shrinkSpaceOnEachSideBy: section_header_space_left];
#define section_footer_space_below 15
		return label.frame.size.height + section_footer_space_above + section_footer_space_below;
	}
	else
		return 0;
	
}
#else
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0)
		return NSLocalizedString(@"These options apply only to this conversation.", @"Text Options Note");
	else
		return nil;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if (section == 0)
		return NSLocalizedString(@"After the specified delay, Burn Notice will destroy your recipient's copy of each message.", @"Burn Help");
	else if (section == 1)
		return NSLocalizedString(@"Turn on to include your location with outgoing messages.", @"Location Help");
	else
		return nil;
}
#endif

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
	if ((indexPath.section == 0) && (indexPath.row == 1)) {
 		BurnTimePickerController *btpc = [BurnTimePickerController.alloc initWithNibName: @"BurnTimePickerController" bundle: nil];
        
		self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back",nil) style:UIBarButtonItemStyleBordered target:nil action:nil];
        
        [self.navigationController  pushViewController: btpc animated: YES];
 		[btpc setTimer: [delegate getBurnNoticeDelay]];
        btpc.delegate = self;
	}
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}
- (void) updateBurnTimeValue: (UInt32) timeValue
{
	[delegate setBurnNoticeDelay: timeValue];
	[self setBurnTimeToCell:[self getBurnTimeTextFromTimeValue: timeValue]];
}

- (NSString *) getBurnTimeTextFromTimeValue: (UInt32) timeValue
{
	UInt16 hours, minutes;
	hours = timeValue / 3600;
	minutes = (timeValue % 3600) / 60;
	NSString	*text;
	// TODO: Localize the following
	NSString *hoursString, *minutesString;
	if (hours == 1)
		hoursString = NSLocalizedString(@"hour", @"hour");
	else
		hoursString = NSLocalizedString(@"hours",@"hours");
	if (minutes == 1)
		minutesString = NSLocalizedString(@"minute", @"minute");
	else
		minutesString = NSLocalizedString(@"minutes", @"minutes");
	if (hours && minutes) {
		text = [NSString stringWithFormat:@"%d %@ %@ %d %@", hours, hoursString, NSLocalizedString(@"and", @"and"), minutes, minutesString];
	}
	else if (hours)
		text = [NSString stringWithFormat:@"%d %@", hours, hoursString];
	else
		text = [NSString stringWithFormat:@"%d %@", minutes, minutesString];
	return text;
}
- (void) setBurnTimeToCell:(NSString *) text
{
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:1 inSection:0];
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
	cell.detailTextLabel.text = text;
}

#pragma mark - ConversationManagerDelegate methods.

-(void) didChangeState
{
    [self.tableView reloadData];  
}
//
//- (void)conversationmanager:(ConversationManager *)sender
//			 didChangeState:(XMPPJID *)theirJid
//				   newState:(ConversationState) state
//{
//    [self.tableView reloadData];
//}
//
//

@end