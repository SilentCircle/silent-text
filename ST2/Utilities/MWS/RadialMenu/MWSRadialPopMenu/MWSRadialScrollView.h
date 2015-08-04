//
//  MWSRadialScrollView.h
//  MWSRadialMenuDemo
//
//  Created by Eric Turner on 11/15/14.
//  Copyright (c) 2014 MagicWave Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MWSRadialScrollView;

@protocol MWSRadialScrollViewDelegate <NSObject, UIScrollViewDelegate>
- (void)radialScrollViewDidFinishPresenting;
- (void)radialScrollViewDidFinishDismissing;
@end

@interface MWSRadialScrollView : UIScrollView


- (instancetype)initWithFrame:(CGRect)frame items:(NSArray *)items directionAngle:(CGFloat)angle;

@property (nonatomic, weak) id<MWSRadialScrollViewDelegate> delegate;


- (void)presentItems;

- (void)dismissItems;

@end
