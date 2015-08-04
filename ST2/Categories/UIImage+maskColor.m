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
//  UIImage+maskColor.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 12/9/13.
//

#import "UIImage+maskColor.h"

@implementation UIImage (maskColor)

- (UIImage *)maskWithColor:(UIColor *)color
{
	CGImageRef maskImage = self.CGImage;
	CGFloat width = self.scale * self.size.width;
	CGFloat height = self.scale * self.size.height;
	CGRect bounds = CGRectMake(0,0,width,height);
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef bitmapContext =
	  CGBitmapContextCreate(NULL, width, height, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
	
	CGContextClipToMask(bitmapContext, bounds, maskImage);
	CGContextSetFillColorWithColor(bitmapContext, color.CGColor);
	CGContextFillRect(bitmapContext, bounds);
	
	CGImageRef cImage = CGBitmapContextCreateImage(bitmapContext);
	UIImage *coloredImage =
	  [UIImage imageWithCGImage:cImage scale:self.scale orientation:UIImageOrientationUp];
	
	CGContextRelease(bitmapContext);
	CGColorSpaceRelease(colorSpace);
	CGImageRelease(cImage);
	
	return coloredImage;
}

@end
