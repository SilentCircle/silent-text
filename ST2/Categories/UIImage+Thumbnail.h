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
//  UIImage+Thumbnail.h
//  SilentText
//

#import <UIKit/UIKit.h>

@interface UIImage (Thumbnail)

- (UIImage *)scaled:(float)scaleFactor;

- (UIImage *)scaledToWidth:(float)width;
- (UIImage *)scaledToHeight:(float)height;

- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees;

- (UIImage *)imageWithBadgeOverlay:(UIImage*)watermarkImage origin:(CGPoint)origin;

- (UIImage *)imageWithBadgeOverlay:(UIImage*)watermarkImage text:(NSString*)textString textColor:(UIColor*) textColor;

- (UIImage *)roundedImageWithCornerRadius:(float)radius;

- (UIImage *)avatarImageWithDiameter:(CGFloat)radius;

- (UIImage *)scaledAvatarImageWithDiameter:(CGFloat)radius;

- (UIImage *)avatarImageWithDiameter:(CGFloat)diameter usingColor:(UIColor*)color  font:(UIFont*)font text:(NSString*)text;
- (UIImage *)avatarImageWithDiameter:(CGFloat)radius usingColor:(UIColor*)color;

+ (UIImage *)multiAvatarImageWithFront:(UIImage *)frontImage back:(UIImage *)backImage diameter:(CGFloat)diameter;

- (UIImage *)convertToGrayScale;

+ (UIImage *)defaultImageForMediaType:(NSString *)mediaType;

//ST-928 03/28/15
+ (CGFloat)maxSirenThumbnailHeightOrWidth;

@end
