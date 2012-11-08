/*
Copyright © 2012, Silent Circle
All rights reserved.

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
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
 

#import <QuartzCore/QuartzCore.h>
#import "NSDate+SCDate.h"
#import "ConversationViewTableCell.h"
#import "SilentTextStrings.h"

#pragma mark -
#pragma mark pretty Date String  declaration
 

 #pragma mark -
#pragma mark ConversationView declaration

@interface ConversationView : UIView {
	
@private
	ConversationViewTableCell *cell_;
}

@property (nonatomic, retain) ConversationViewTableCell *cell;

- (id)initWithFrame:(CGRect)frame cell:(ConversationViewTableCell *)newCell;
@end

#pragma mark -
#pragma mark ConversationView implementation

@implementation ConversationView

@synthesize cell = cell_;

#pragma mark -
#pragma mark init

- (id)initWithFrame:(CGRect)frame cell:(ConversationViewTableCell *)newCell {
	
	if ((self = [super initWithFrame:frame])) {
		cell_ = newCell;
		
		self.backgroundColor = [UIColor clearColor];
		self.layer.masksToBounds = YES;
	}
	return self;
}

#pragma mark -
#pragma mark redraw

- (void)drawRect:(CGRect)rect {
    
	CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIColor *silentTheme = [UIColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:.9];
    
    UIColor *currentTitleColor =  silentTheme;
    UIColor *currentSubTitleColor = [UIColor whiteColor];
    UIColor *currentDateColor =  silentTheme;
    //   UIColor *currentDateColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.];
    UIColor *currentBadgeColor = self.cell.badgeColor?self.cell.badgeColor:[UIColor darkGrayColor];
    
	if (self.cell.isHighlighted || self.cell.isSelected) {
        currentTitleColor       = [UIColor whiteColor];
        currentSubTitleColor    = [UIColor whiteColor];
        currentDateColor        = [UIColor whiteColor];
		currentBadgeColor       = [UIColor whiteColor];
   	}
	
 /*
  UIGraphicsBeginImageContext(rect.size);
    CGContextSetFillColorWithColor(context, [[UIColor blackColor] CGColor] );
    CGContextFillRect(context, rect);
    UIGraphicsEndImageContext();

 */   
    CGSize badgeTextSize    = [self.cell.badgeString sizeWithFont:[UIFont boldSystemFontOfSize:11.]];
    CGRect badgeViewFrame   = CGRectIntegral(CGRectMake(
                                                        rect.size.width - 40,
                                                        ((rect.size.height - badgeTextSize.height - 4) / 2) + 5,
                                                        badgeTextSize.width + 14,
                                                        badgeTextSize.height + 4));
    
    
    if(self.cell.avatar)
    {
        CGRect avatarRect = CGRectIntegral(CGRectMake( 2,  6 , 48, 48));
        [self.cell.avatar drawInRect:avatarRect];
    }
    
    if (self.cell.isEditing)
    {
        [currentSubTitleColor set];
        CGRect subRect = CGRectIntegral(CGRectMake( 60,  23 , 200, 34));
        [self.cell.subTitleString drawInRect:subRect withFont:[UIFont systemFontOfSize:13] lineBreakMode:UILineBreakModeTailTruncation alignment:UITextAlignmentLeft];
    }
    else
    {
        CGContextSaveGState(context);
        CGPoint origin = CGPointMake(rect.size.width - 10, 28);
        UIBezierPath *bp = [UIBezierPath bezierPath];
        [bp moveToPoint:origin];
        [bp addLineToPoint:CGPointMake(origin.x + 6, origin.y + 6)];
        [bp addLineToPoint:CGPointMake(origin.x, origin.y + 6 * 2)];
        bp.lineWidth = 3.0;
        [[UIColor grayColor] set];
        [bp stroke];
        CGContextRestoreGState(context);
        
     //  date string
        [currentDateColor set];
        CGRect dateRect = CGRectIntegral(CGRectMake(  rect.size.width - 100,  4 , 90, 21));
         NSString *dateString = [self.cell.date whenString];
        [dateString drawInRect:dateRect withFont:[UIFont systemFontOfSize:14] lineBreakMode:UILineBreakModeTailTruncation alignment:UITextAlignmentRight];
        
        [currentSubTitleColor set];
        CGRect subRect = CGRectIntegral(CGRectMake( 60,  23 , rect.size.width - 100, 34));
        [self.cell.subTitleString drawInRect:subRect withFont:[UIFont systemFontOfSize:13] lineBreakMode:UILineBreakModeTailTruncation alignment:UITextAlignmentLeft];
        
        if(self.cell.leftBadgeImage)
        {
            CGRect badgeRect = CGRectIntegral(CGRectMake( rect.size.width - 40 ,  21 , 24, 24));
            [self.cell.leftBadgeImage drawInRect:badgeRect];
        }
        else if(self.cell.badgeString)
        {
            CGContextSaveGState(context);
            CGContextSetFillColorWithColor(context, currentBadgeColor.CGColor);
            CGMutablePathRef path = CGPathCreateMutable();
            CGPathAddArc(path, NULL, badgeViewFrame.origin.x + badgeViewFrame.size.width - badgeViewFrame.size.height / 2, badgeViewFrame.origin.y + badgeViewFrame.size.height / 2, badgeViewFrame.size.height / 2, M_PI / 2, M_PI * 3 / 2, YES);
            
            CGPathAddArc(path, NULL, badgeViewFrame.origin.x + badgeViewFrame.size.height / 2, badgeViewFrame.origin.y + badgeViewFrame.size.height / 2, badgeViewFrame.size.height / 2, M_PI * 3 / 2, M_PI / 2, YES);
            CGContextAddPath(context, path);
            CGContextDrawPath(context, kCGPathFill);
            CFRelease(path);
            CGContextRestoreGState(context);
            
            CGContextSaveGState(context);
            CGContextSetBlendMode(context, kCGBlendModeClear);
            
            [self.cell.badgeString drawInRect:CGRectInset(badgeViewFrame, 7, 2) withFont:[UIFont boldSystemFontOfSize:11.]];
            CGContextRestoreGState(context);
        }

    }
    
     
    [currentTitleColor set];
    [self.cell.titleString drawAtPoint:CGPointMake(60, 1)
                              forWidth: rect.size.width-150/*(rect.size.width - badgeViewFrame.size.width - 0) */
                              withFont:[UIFont boldSystemFontOfSize:16] lineBreakMode:UILineBreakModeTailTruncation];
    
	
}

@end

#pragma mark -
#pragma mark ConversationViewTableCell private

@interface ConversationViewTableCell ()
@property (nonatomic, retain) ConversationView *	conversationView;
@end

#pragma mark -
#pragma mark ConversationViewTableCell implementation

@implementation ConversationViewTableCell

@synthesize titleString = _titleString;
@synthesize subTitleString = _subTitleString;
@synthesize date = _date;
@synthesize conversationView = _conversationView;
@synthesize badgeString = _badgeTextString;
@synthesize badgeColor = _badgeColor;
@synthesize leftBadgeImage = _leftBadgeImage;
 
 
#pragma mark -
#pragma mark init & dealloc

 
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
		_conversationView = [[ConversationView alloc] initWithFrame:self.contentView.bounds cell:self];
        _conversationView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _conversationView.contentMode = UIViewContentModeRedraw;
		_conversationView.contentStretch = CGRectMake(1., 0., 0., 0.);
        [self.contentView addSubview:_conversationView];
    }
    return self;
}

#pragma mark -
#pragma mark accessors

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];
		
	[self.conversationView setNeedsDisplay];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {

	[super setHighlighted:highlighted animated:animated];
		
	[self.conversationView setNeedsDisplay];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	
	[super setEditing:editing animated:animated];

	[self.conversationView setNeedsDisplay];
}

@end
