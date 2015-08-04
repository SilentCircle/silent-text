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
//  SCTEyeball.m
//  ST2
//
//  Created by Eric Turner on 7/1/14.
//

#import "SCTEyeball.h"

@implementation SCTEyeball


#pragma mark - Initialization

- (instancetype) initWithFrame:(CGRect) aRect 
{
    self = [super initWithFrame:aRect];
    if (!self) return nil;

    // Configure the eye images to display, masked to the superview tintColor
    _imgView = [[UIImageView alloc] initWithFrame:aRect];
    UIImage *tmpImg = [UIImage imageNamed:@"MZ_EYE_ICON_OPEN"];
    _openImg = [tmpImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    tmpImg = [UIImage imageNamed:@"MZ_EYE_ICON_CLOSED"];
    _closedImg = [tmpImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _imgView.image = _closedImg;
    _imgView.backgroundColor = [UIColor clearColor];
    [self addSubview:_imgView];
    self.backgroundColor = [UIColor clearColor];
    return self;
}


#pragma mark - UIControl Override -

-(BOOL) beginTrackingWithTouch:(UITouch *) touch withEvent:(UIEvent *) event
{
    // Change the image before forwarding
    _imgView.image = (self.isOpen) ? _closedImg : _openImg;
    [super beginTrackingWithTouch:touch withEvent:event];
    return YES;
}

#pragma ReadOnly Getter

- (BOOL) isOpen 
{
    BOOL state = (_imgView.image == _openImg);
    return state;
}

@end
