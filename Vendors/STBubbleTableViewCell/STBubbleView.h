//
//  STBubbleView.h
//  SilentText
//
//  Created by mahboud on 12/3/12.
//  Copyright (c) 2012 Silent Circle, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#define done_with_media_image_drawn_into_calayer
//#define done_using_an_imageview 1
#ifdef done_using_an_imageview
@interface STBubbleView : UIImageView
#else
@interface STBubbleView : UIImageView /*<CAAction>*/
#endif
@property (nonatomic, strong) UIImage *bubbleImage;
@property (nonatomic, strong) UIImage *mediaImage;
@property (nonatomic, assign) CGRect mainFrame;
@property (nonatomic, assign) CGRect mediaFrame;
//@property (nonatomic, strong) UIImage *geoImage;
//@property (nonatomic, strong) UIImage *burnImage;
@property (nonatomic, strong) CALayer *mediaLayer;
@property (nonatomic, strong) CALayer *mediaImageLayer;

- (void) reset;
//- (CGRect) geoRect;
//- (CGRect) burnRect;
@end
