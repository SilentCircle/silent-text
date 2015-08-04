//
//  STBubbleTableViewCellDemoViewController.h
//  STBubbleTableViewCellDemo
//
//  Created by Cedric Vandendriessche on 18/04/12.
//  Copyright 2011 FreshCreations. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "STBubbleTableViewCell.h"

@interface STBubbleTableViewCellDemoViewController : UIViewController 

<UITableViewDelegate, UITableViewDataSource, STBubbleTableViewCellDelegate> {

	IBOutlet UITableView *tbl;
	NSMutableArray *messages;
}
@property (nonatomic, strong) UITableView *tbl;
@property (nonatomic, strong) NSMutableArray *messages;

@end

