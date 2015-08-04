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
//
//  MediaPickerWaterfallCell
 
#import "MediaPickerWaterfallCell.h"

@interface MediaPickerWaterfallCell ()
@property (nonatomic, strong) IBOutlet UIImageView  *imageview;

@end

@implementation MediaPickerWaterfallCell

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


// Call our ViewController to do the work, since it has knowledge of the data model, not this view.
// On iOS 7.0, you'll have to implement this method to make the custom menu appear with a UICollectionViewController
- (void)burnAction:(id)sender {
    if([self.delegate respondsToSelector:@selector(burnAction:forCell:)]) {
        [self.delegate burnAction:sender forCell:self];
    }
}

// Must implement this method either here or in the UIViewController
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
     if (action == @selector(burnAction:)) {
        return YES;
    }
    return NO;
}
@end
