//
//  UICollectionViewWaterfallCell.m
//  Demo
//
//  Created by Nelson on 12/11/27.
//  Copyright (c) 2012年 Nelson. All rights reserved.
//

#import "CHTCollectionViewWaterfallCell.h"

@interface CHTCollectionViewWaterfallCell ()
@property (nonatomic, strong) IBOutlet UIImageView  *imageview;

@end

@implementation CHTCollectionViewWaterfallCell

@synthesize scloudID = scloudID;

#pragma mark - Accessors
 
-(UIImage*) image
{
    return _imageview.image;
}

- (void)setImage:(UIImage *)displayImage {
    
    _imageview.image  = displayImage;
}


#pragma mark - Life Cycle
- (void)dealloc {
    [_imageview removeFromSuperview];
    _imageview = nil;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.contentView.layer.borderColor = [UIColor whiteColor].CGColor;
        self.contentView.layer.borderWidth = 1.f;
        
        _imageview = [[UIImageView alloc]initWithFrame:CGRectMake(0.0, 0.0, frame.size.width, frame.size.height)];
        
        [self.contentView addSubview:_imageview];
        
        _imageview.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
        _imageview.backgroundColor = [UIColor grayColor];
    }
    return self;
}


// Must implement this method either here or in the UIViewController
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    
    if ((action == @selector(burnAction:))
        && [self.delegate respondsToSelector:@selector(canBurn:forCell:)]
               && [self.delegate canBurn:sender forCell:self])
        return YES;
 
    if ((action == @selector(sendAction:))
        && [self.delegate respondsToSelector:@selector(canSend:forCell:)]
        && [self.delegate canSend:sender forCell:self])
        return YES;
    
    return NO;
}


// Call our ViewController to do the work, since it has knowledge of the data model, not this view.
// On iOS 7.0, you'll have to implement this method to make the custom menu appear with a UICollectionViewController
- (void)burnAction:(id)sender {
    if([self.delegate respondsToSelector:@selector(burnAction:forCell:)]) {
        [self.delegate burnAction:sender forCell:self];
    }
}


// Call our ViewController to do the work, since it has knowledge of the data model, not this view.
// On iOS 7.0, you'll have to implement this method to make the custom menu appear with a UICollectionViewController
- (void)sendAction:(id)sender {
    if([self.delegate respondsToSelector:@selector(sendAction:forCell:)]) {
        [self.delegate sendAction:sender forCell:self];
    }
}

@end
