//
//  UICollectionViewWaterfallCell.h
//  Demo
//
//  Created by Nelson on 12/11/27.
//  Copyright (c) 2012年 Nelson. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CHTCollectionViewWaterfallCell; // Forward declare Custom Cell for the property

@protocol CHTCollectionViewWaterfallCellDelegate <NSObject>

@optional

- (BOOL)canBurn:(id)sender forCell:(CHTCollectionViewWaterfallCell *)cell;
- (BOOL)canSend:(id)sender forCell:(CHTCollectionViewWaterfallCell *)cell;


- (void)burnAction:(id)sender forCell:(CHTCollectionViewWaterfallCell *)cell;
- (void)sendAction:(id)sender forCell:(CHTCollectionViewWaterfallCell *)cell;
@end



@interface CHTCollectionViewWaterfallCell : UICollectionViewCell

@property (weak, nonatomic) id<CHTCollectionViewWaterfallCellDelegate> delegate;

@property (nonatomic, strong)  UIImage  *image;
@property (nonatomic, strong)  NSString  *scloudID;

@end
