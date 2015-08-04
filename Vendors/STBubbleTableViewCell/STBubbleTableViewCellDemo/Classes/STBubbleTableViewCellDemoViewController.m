//
//  STBubbleTableViewCellDemoViewController.m
//  STBubbleTableViewCellDemo
//
//  Created by Cedric Vandendriessche on 18/04/12.
//  Copyright 2011 FreshCreations. All rights reserved.
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "STBubbleTableViewCellDemoViewController.h"
#import "STBubbleTableViewCell.h"
#import "Message.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

@interface STBubbleTableViewCellDemoViewController ()

@property (nonatomic, readonly) CGFloat gutterWidth;

@end

@implementation STBubbleTableViewCellDemoViewController

@synthesize tbl, messages;
@dynamic    gutterWidth;


- (CGFloat) gutterWidth {
    
    return 40.0f;
//    return UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? 80.0f: 130.0f;
    
} // -gutterWidth


- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = @"Messages";
	
	messages = [[NSMutableArray alloc] initWithObjects:
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"Great, I just finished avatar support."],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"They will. Now you see me.."],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"And now you don't. :)"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"Great, I just finished avatar support." image:[UIImage imageNamed:@"SkyTrix.png"]],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?"],
				nil];
//	messages = [[NSMutableArray alloc] initWithObjects:
//				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
//				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
//				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
//				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
//				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
//				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
//				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
//				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
//				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
//				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
//				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
				[Message messageWithString:@"How is that bubble component of yours coming along? How is that bubble component of yours coming along? How is that bubble component of yours coming along?" image:[UIImage imageNamed:@"jonnotie.png"]],
				[Message messageWithString:@"Great, I just finished avatar support." image:[UIImage imageNamed:@"SkyTrix.png"]],
//				[Message messageWithString:@"That is awesome! I hope people will like that addition." image:[UIImage imageNamed:@"jonnotie.png"]],
//				[Message messageWithString:@"They will. Now you see me.." image:[UIImage imageNamed:@"SkyTrix.png"]],
//				[Message messageWithString:@"And now you don't. :)"],
//				nil];
	
	tbl.backgroundColor = [UIColor colorWithRed:219.0/255.0 green:226.0/255.0 blue:237.0/255.0 alpha:1.0];
	tbl.separatorStyle = UITableViewCellSeparatorStyleNone;
	
	// Some decoration
	CGSize screenSize = [[UIScreen mainScreen] applicationFrame].size;	
	UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width, 55)];
	
	UIButton *callButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	callButton.frame = CGRectMake(10, 10, (screenSize.width / 2) - 10, 35);
	callButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
	[callButton setTitle:@"Call" forState:UIControlStateNormal];
	
	UIButton *contactButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	contactButton.frame = CGRectMake((screenSize.width / 2) + 10, 10, (screenSize.width / 2) - 20, 35);
	contactButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
	[contactButton setTitle:@"Contact Info" forState:UIControlStateNormal];
	
	[headerView addSubview:callButton];
	[headerView addSubview:contactButton];
	
	tbl.tableHeaderView = headerView;
}


#pragma mark - STBubbleTableViewCellDataSource methods


- (CGFloat) minInsetForCell: (STBubbleTableViewCell *) cell {
    
    return UIInterfaceOrientationIsLandscape(self.interfaceOrientation) ? 100.0 : 50.0;
    
} // -minInsetForCell:


- (UIImage *) bubbleImageForCell: (STBubbleTableViewCell *) cell {
    
    return ((cell.authorType == STBubbleTableViewCellAuthorTypeUser) ?
            [[UIImage imageNamed: @"Bubble-0.png"] stretchableImageWithLeftCapWidth: 24 topCapHeight: 15] :
            [[UIImage imageNamed: @"Bubble-1.png"] stretchableImageWithLeftCapWidth: 24 topCapHeight: 15]);
    
} // -bubbleImageForCell:atIndexPath:


- (UIImage *) selectedBubbleImageForCell: (STBubbleTableViewCell *) cell {
    
    return [[UIImage imageNamed: @"Bubble-2.png"] stretchableImageWithLeftCapWidth: 24 topCapHeight: 15];
    
} // -selectedBubbleImageForCell:atIndexPath:


#pragma mark - STBubbleTableViewCellDelegate methods

- (void)tappedImageOfCell:(STBubbleTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
	Message *message = [messages objectAtIndex:indexPath.row];
	NSLog(@"%@", message.message);
}


#pragma mark - UITableViewDataSource methods.


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [messages count];
}


- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath {
    
    static NSString *CellIdentifier = @"Cell";
	
    STBubbleTableViewCell *cell = (STBubbleTableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        
        cell = [STBubbleTableViewCell.alloc initWithStyle: UITableViewCellStyleDefault 
                                          reuseIdentifier: CellIdentifier];
        cell.delegate = self;
	}
	Message *message = [messages objectAtIndex:indexPath.row];
	
	cell.textLabel.text = message.message;
	cell.imageView.image = message.avatar;
    cell.gutterWidth = self.gutterWidth;
    cell.authorType = indexPath.row % 2 ? STBubbleTableViewCellAuthorTypeUser: STBubbleTableViewCellAuthorTypeOther;
	cell.bubbleImage = [self bubbleImageForCell: cell];
	cell.selectedBubbleImage = [self selectedBubbleImageForCell: cell];
    
    return cell;

} // -tableView:cellForRowAtIndexPath:


#pragma mark - UITableViewDelegate methods.


- (CGFloat) tableView: (UITableView *) tableView heightForRowAtIndexPath: (NSIndexPath *) indexPath {

    STBubbleTableViewCell *cell = [STBubbleTableViewCell.alloc initWithStyle: UITableViewCellStyleDefault 
                                                             reuseIdentifier: nil];
    cell.delegate = self;
    
	Message *message = [messages objectAtIndex:indexPath.row];
	
	cell.textLabel.text = message.message;
	cell.imageView.image = message.avatar;
    cell.authorType = indexPath.row % 2 ? STBubbleTableViewCellAuthorTypeUser: STBubbleTableViewCellAuthorTypeOther;
    cell.gutterWidth = self.gutterWidth;
    
    return cell.height;
    
} // -tableView:heightForRowAtIndexPath:


#pragma mark - UIScrollViewDelegate methods.


- (void) scrollViewWillBeginDragging: (UIScrollView *) scrollView {
    
    DDGTrace();
    
} // -scrollViewWillBeginDragging:


#pragma mark -


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration {
	[tbl reloadData];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	self.tbl = nil;
}


@end
