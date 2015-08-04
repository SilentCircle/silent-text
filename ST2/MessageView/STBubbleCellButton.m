/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

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
//  STBubbleCellButton.m
//  ST2
//
//  Created by mahboud on 5/14/14.
//
#import "STBubbleCellButton.h"
#import "UIImage+Thumbnail.h"

@implementation STBubbleCellButton

//- (id)initWithFrame:(CGRect)frame
//{
//    self = [super initWithFrame:frame];
//    if (self) {
//        // Initialization code
//    }
//    return self;
//}

- (instancetype) initWithImage:(UIImage *)image andDiameter:(CGFloat) diameter
{
	CGRect buttonFrame = CGRectMake(0, 0, diameter, diameter);
	self = [STBubbleCellButton buttonWithType:UIButtonTypeCustom];
	if (self) {
		self.frame = buttonFrame;
		self.contentMode = UIViewContentModeCenter;
		self.hitTestEdgeInsets = (UIEdgeInsets){
			.top    = -2,
			.bottom = -2,
			.left   = -2,
			.right  = -2
		};
		
		self.layer.backgroundColor = [[[UIColor whiteColor] colorWithAlphaComponent:0.5] CGColor];
		
		[self setImage:[image scaledToWidth:diameter - 2.0] forState:UIControlStateNormal];
	}
	return self;
}


- (void) setFrame:(CGRect)frame
{
	super.frame = frame;
	self.layer.borderWidth = 1;
	self.layer.cornerRadius = frame.size.width/2;
	
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
