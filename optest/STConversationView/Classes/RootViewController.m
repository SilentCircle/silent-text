/*
Copyright © 2012-2013, Silent Circle, LLC.  All rights reserved.

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


#import "RootViewController.h"
#import "ConversationViewTableCell.h"


@interface RootViewController ()

@property (nonatomic, retain) UIImage *replyImage;
@property (nonatomic, retain) UIImage *avatarImage;
@property (nonatomic, retain) UIImage *avatarImage1;

@end

@implementation RootViewController

static NSString *const kReplyIcon = @"replyarrow_flat";
//static NSString *const kAvatarIcon = @"defaultPerson";
static NSString *const kAvatarIcon = @"avatar"; //@"silhouette";
static NSString *const kPerson1 = @"bunbun1.gif";

#pragma mark -
#pragma mark View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	self.title = @"Silent Text Test";
    
   self.view.backgroundColor  = UIColor.blackColor;
    
    
    self.avatarImage =  [UIImage imageNamed: kAvatarIcon];
    self.avatarImage1 =  [UIImage imageNamed: kPerson1];
     
    self.replyImage = [UIImage imageNamed: kReplyIcon];
    
    
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
}
*/

/*
 // Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations.
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
 */


#pragma mark -
#pragma mark Table view data source

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 200;
}

 


static char *banter[] = {
    "Hello. My name is Inigo Montoya. You killed my father. Prepare to die.",
    " Finish him. Finish him, your way.",
    "Oh good, my way. Thank you Vizzini... what's my way?",
    "Возьмите один из тех пород, получить за валуном, в течение нескольких минут человек в черном прибежит за поворотом, в ту минуту его голова в виду, ударил его со скалой.",
    "My way's not very sportsman-like. ",
    "Why do you wear a mask? Were you burned by acid, or something like that?",
    "صمت، وأنا قتلك",
    " Oh no, it's just that they're terribly comfortable. I think everyone will be wearing them in the future.",
    " I do not envy you the headache you will have when you awake. But for now, rest well and dream of large women.",
    " I just want you to feel you're doing well.",
    "That Vizzini, he can *fuss*." ,
    "Fuss, fuss... I think he like to scream at *us*.",
    "Probably he means no *harm*. ",
    "He's really very short on *charm*." ,
    "You have a great gift for rhyme." ,
    "Yes, yes, some of the time.",
    "Enough of that.",
    "Fezzik, are there rocks ahead? ",
    "If there are, we all be dead. ",
    "No more rhymes now, I mean it. ",
    "Anybody want a peanut?",
    "short",
    "no",
    "",
    NULL
};

static char *names[] = {
    "Inigo Montoya",
    "Vizzini",
    "Fezzik",
    "Борис Баденов",
    "Наташа роковая",
    "Daphne Blake",
   "شمد، الإرهابي الميت",
    "Velma Elizabeth Dinkley",
    "Harvey Birdman",
    "Mr Squiggle",
      NULL,
 };

static char *devices[] = {
    "Ingo's iPhone",
    "Vizzini iPad",
    NULL,
    "Борис phone",
    NULL,
    "Daphne's Scooby Snack",
    NULL,
    "Velma toy",
    "The Bird Phone",
    "A really long very long line that is way too big to display over too many lines and it should break stuff",
    NULL,
};


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    int nameCount = (sizeof(names)/sizeof(char*)) -1;
    int nameItem = indexPath.row % nameCount;
    
    return devices[nameItem]?80:70;
    
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    int banterCount = (sizeof(banter)/sizeof(char*)) -1;
    int banterItem = indexPath.row % banterCount;

    int nameCount = (sizeof(names)/sizeof(char*)) -1;
    int nameItem = indexPath.row % nameCount;

    
    
    static NSString *CellIdentifier = @"Cell";
    
    ConversationViewTableCell *cell = (ConversationViewTableCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[ConversationViewTableCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
   int height =  cell.frame.size.height;
    
    NSDate *theDate =[[NSDate alloc] init];
    
    theDate = [theDate addTimeInterval: -(60*60*24*indexPath.row)];
      
	// Configure the cell.
	cell.titleString = [NSString stringWithUTF8String:names[nameItem]];
	cell.addressString = devices[nameItem]?[NSString stringWithUTF8String:devices[nameItem]]:NULL;
	cell.subTitleString = [NSString stringWithUTF8String:banter[banterItem]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    cell.badgeString = (indexPath.row & 1) ? [NSString stringWithFormat:@"%d", indexPath.row] : NULL;
    cell.avatar = self.avatarImage;

    if(indexPath.row == 3)
    {
        cell.badgeColor = [UIColor redColor];
        cell.avatar = self.avatarImage1;
        
    }
    else  if(indexPath.row == 2  || indexPath.row == 3)
    {
        cell.leftBadgeImage = self.replyImage;
        cell.badgeString = NULL;
    }
    else
    {
        
        cell.leftBadgeImage = NULL;
    }
    cell.date =  theDate;
    
    
    return cell;
}

	
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source.
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }   
}


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
    
	/*
	 <#subTitleViewController#> *subTitleViewController = [[<#subTitleViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
	 [self.navigationController pushViewController:subTitleViewController animated:YES];
	 [subTitleViewController release];
	 */
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end

