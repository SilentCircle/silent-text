//
//  MediaPickerWaterfallLayout
//
//  Created by Nelson on 12/11/19.
//  Copyright (c) 2012 Nelson Tai. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MediaPickerWaterfallLayout;
@protocol  MediaPickerWaterfallLayoutDelegate  <UICollectionViewDelegate>
- (CGFloat)collectionView:(UICollectionView *)collectionView
                   layout:(MediaPickerWaterfallLayout *)collectionViewLayout
 heightForItemAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface MediaPickerWaterfallLayout : UICollectionViewLayout
@property (nonatomic, weak) IBOutlet id<MediaPickerWaterfallLayoutDelegate> delegate;
@property (nonatomic, assign) NSUInteger columnCount; // How many columns
@property (nonatomic, assign) CGFloat itemWidth; // Width for every column
@property (nonatomic, assign) UIEdgeInsets sectionInset; // The margins used to lay out content in a section
@end
