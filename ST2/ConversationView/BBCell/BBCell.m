//
//  BBCell.m
//  CircleView
//
//  Created by Bharath Booshan on 6/8/12.
//  Copyright (c) 2012 Bharath Booshan Inc. All rights reserved.
//

#import "BBCell.h"

@implementation BBCell
@synthesize mLabel, mImageView, color, mCellText;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        //add the image layer
        self.contentView.backgroundColor = [UIColor clearColor];
        //mImageLayer =[CALayer layer];
        //mImageLayer.cornerRadius = 16.0;
        ////mImageLayer.backgroundColor = [UIColor greenColor].CGColor;
        ////  mImageLayer.contents = (id)[UIImage imageNamed:@"2.png"].CGImage;
        //[self.contentView.layer addSublayer:mImageLayer];
        //mImageLayer.borderWidth=2.0;
        //mImageLayer.borderColor = [UIColor greenColor].CGColor;
        //mImageLayer.shadowColor = [UIColor blackColor].CGColor;
        //mImageLayer.shadowOffset = CGSizeMake(2, 2);
        //mImageLayer.shadowOpacity = 0.5;
        //the title label
        mLabel = [[UILabel alloc] initWithFrame:CGRectMake(44.0, 10.0, self.contentView.bounds.size.width - 44.0, 21.0)];
        [self.contentView addSubview:mLabel];
        mLabel.backgroundColor= [UIColor clearColor];
        mLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
		mLabel.shadowColor = [UIColor darkGrayColor];
		mLabel.shadowOffset = CGSizeMake(1, 2);
        //        mLabel.textColor = [UIColor whiteColor];
		
		mImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:mImageView];
		mImageView.contentMode = UIViewContentModeScaleToFill;
        //        mImageView.layer.cornerRadius = 16.0;
        //mImageView.layer.backgroundColor = [UIColor greenColor].CGColor;
		//  mImageView.layer.contents = (id)[UIImage imageNamed:@"2.png"].CGImage;
        mImageView.layer.borderWidth=2.0;
        //        mImageView.layer.borderColor = [UIColor greenColor].CGColor;
		mImageView.layer.shadowColor = [UIColor blackColor].CGColor;
		mImageView.layer.shadowOffset = CGSizeMake(2, 2);
		mImageView.layer.shadowOpacity = 0.5;
		mImageView.userInteractionEnabled = YES;

        mCellText = [[UILabel alloc] initWithFrame:CGRectMake(44.0, 30.0, self.contentView.bounds.size.width - 44.0, 21.0)];
        [self.contentView addSubview:mCellText];
        mCellText.backgroundColor= [UIColor clearColor];
        mCellText.textColor = [UIColor whiteColor];
        mCellText.font = [UIFont fontWithName:@"Noteworthy" size:14.0];
        mCellText.shadowColor = [UIColor darkGrayColor];
		mCellText.shadowOffset = CGSizeMake(1, 2);
        
    }
    return self;
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
    mImageView.layer.cornerRadius = heightOfImageLayer/2.0f;
    mImageView.frame = CGRectMake(4.0, imageY, heightOfImageLayer, heightOfImageLayer);

    mLabel.frame = CGRectMake(heightOfImageLayer+10.0,
                                      10,
        //                              floorf(heightOfImageLayer/2.0 - (21/2.0f))+4.0,
                                      self.contentView.bounds.size.width-heightOfImageLayer+10.0,
                                      21.0);

    mCellText.frame = CGRectMake(heightOfImageLayer+10.0,
                                      30,
                                      self.contentView.bounds.size.width-heightOfImageLayer+10.0,
                                      21.0);

}

-(void)setCellTitle:(NSString*)title
{
    mLabel.text = title;    
}

-(void)setCellText:(NSString*)cellText
{
    mCellText.text = cellText;
    
}


-(void)setIcon:(UIImage*)image
{
    //    [CATransaction begin];
    //    [CATransaction setAnimationDuration:0];
    //    mImageLayer.contents = (id)image.CGImage;
    //    [CATransaction commit];
	
	mImageView.image = image;
}

-(void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
}

-(void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    
    [super setSelected:selected animated:animated];
    mImageView.layer.borderColor = selected ? [UIColor lightGrayColor].CGColor : color.CGColor;
    mLabel.textColor = selected ? [UIColor lightGrayColor] : color;
    mCellText.textColor = selected ? [UIColor lightGrayColor] : color;
    
  }

@end
