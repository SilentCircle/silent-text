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
//  UIColor-HSVAdditions.m
//
//  Created by Matt Reagan (bravobug.com) on 12/31/09.
//  
// Released into the public domain
//Original code: http://en.literateprograms.org/RGB_to_HSV_color_space_conversion_%28C%29

#import "UIColor-HSVAdditions.h"

@implementation UIColor (UIColor_HSVAdditions)
+(struct hsv_color)HSVfromRGB:(struct rgb_color)rgb
{
	struct hsv_color hsv;

	CGFloat rgb_min, rgb_max;
	///rgb_min = MIN3(rgb.r, rgb.g, rgb.b); /* value wasn't used */
	rgb_max = MAX3(rgb.r, rgb.g, rgb.b);

	hsv.val = rgb_max;
	if (hsv.val == 0) {
		hsv.hue = hsv.sat = 0;
		return hsv;
	}

	rgb.r /= hsv.val;
	rgb.g /= hsv.val;
	rgb.b /= hsv.val;
	rgb_min = MIN3(rgb.r, rgb.g, rgb.b);
	rgb_max = MAX3(rgb.r, rgb.g, rgb.b);

	hsv.sat = rgb_max - rgb_min;
	if (hsv.sat == 0) {
		hsv.hue = 0;
		return hsv;
	}

	if (rgb_max == rgb.r) {
		hsv.hue = 0.0 + 60.0*(rgb.g - rgb.b);
		if (hsv.hue < 0.0) {
			hsv.hue += 360.0;
		}
	} else if (rgb_max == rgb.g) {
		hsv.hue = 120.0 + 60.0*(rgb.b - rgb.r);
	} else /* rgb_max == rgb.b */ {
		hsv.hue = 240.0 + 60.0*(rgb.r - rgb.g);
	}

	return hsv;
}
-(CGFloat)hue
{
	struct hsv_color hsv;
	struct rgb_color rgb;
	rgb.r = [self red];
	rgb.g = [self green];
	rgb.b = [self blue];
	hsv = [UIColor HSVfromRGB: rgb];
	return (hsv.hue / 360.0);
}
-(CGFloat)saturation
{
	struct hsv_color hsv;
	struct rgb_color rgb;
	rgb.r = [self red];
	rgb.g = [self green];
	rgb.b = [self blue];
	hsv = [UIColor HSVfromRGB: rgb];
	return hsv.sat;
}
-(CGFloat)brightness
{
	struct hsv_color hsv;
	struct rgb_color rgb;
	rgb.r = [self red];
	rgb.g = [self green];
	rgb.b = [self blue];
	hsv = [UIColor HSVfromRGB: rgb];
	return hsv.val;
}
-(CGFloat)value
{
	return [self brightness];
}
@end