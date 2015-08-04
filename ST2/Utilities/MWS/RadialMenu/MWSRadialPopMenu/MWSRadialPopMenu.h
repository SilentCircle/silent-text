//
//  MWSRadialPopMenu.h
//  PopPlayground
//
//  Created by Eric Turner on 11/1/14.
//  Copyright (c) 2014 Victor Baro. All rights reserved.
//

#import <UIKit/UIKit.h>

extern BOOL const POP_MENU_CENTER;

@class MWSRadialPopMenu;

@protocol MWSRadialPopMenuDelegate <NSObject>
//@optional
- (void)radialMenuDidDismiss;
@end

@interface MWSRadialPopMenu : UIControl

@property (nonatomic, weak) id<MWSRadialPopMenuDelegate> delegate;

- (instancetype) initWithFrame:(CGRect)frame
                     direction:(CGFloat)directionInRadians
                     iconArray:(NSArray *)menuItems
                presentingView:(UIView *)pView
                   contextView:(UIView *)cView;


@end
