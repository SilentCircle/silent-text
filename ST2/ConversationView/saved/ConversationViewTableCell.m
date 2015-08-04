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
#import "ConversationViewTableCell.h"

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@implementation ConversationViewTableCell

@synthesize nameLabel   = nameLabel;
@synthesize bodyLabel   = bodyLabel;
@synthesize timeLabel   = timeLabel;
@synthesize imageLabel  = imageLabel;
@synthesize isStatus    = isStatus;
@synthesize alertLabel  = alertLabel;

@synthesize  color;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
  
    }
    return self;
}

-(void)setColor:(UIColor *)aColor
{
    color = aColor;
}


-(void)layoutSubviews
{
    [super layoutSubviews];
    //    float imageY = 4.0;
    //    float heightOfImageLayer  = self.bounds.size.height - imageY*2.0;
    //    heightOfImageLayer = floorf(heightOfImageLayer);
    //    mImageLayer.cornerRadius = heightOfImageLayer/2.0f;
    //    mImageLayer.frame = CGRectMake(4.0, imageY, heightOfImageLayer, heightOfImageLayer);
    float imageY = 4.0;
    float heightOfImageLayer  = self.bounds.size.height - imageY*2.0;
    heightOfImageLayer = floorf(heightOfImageLayer);
    imageLabel.layer.cornerRadius = heightOfImageLayer/2.0f;
    imageLabel.frame = CGRectMake(4.0, imageY, heightOfImageLayer, heightOfImageLayer);
    
    imageLabel.layer.borderWidth=1.5;
    imageLabel.layer.borderColor = color.CGColor;
    
    imageLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    imageLabel.layer.shadowOffset = CGSizeMake(2, 2);
    imageLabel.layer.shadowOpacity = 0.5;
  
    bodyLabel.font = isStatus? [UIFont italicSystemFontOfSize:14]: [UIFont systemFontOfSize:13];

    
 //   Noteworthy Bold 12.0
      
}


-(void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
}

-(void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    imageLabel.layer.borderColor = selected ? [UIColor lightGrayColor].CGColor : color.CGColor;
 //   nameLabel.textColor = selected ? [UIColor lightGrayColor] : color;
}

@end
