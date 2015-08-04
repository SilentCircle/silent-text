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
//  UIImage+Crop.m
//  SilentText
//

#import "UIImage+Crop.h"

@implementation UIImage (Crop)

static inline double rad(double deg)
{
	return deg / 180.0 * M_PI;
}

- (UIImage *)crop:(CGRect)rect
{
#if 1
//	rect = CGRectMake(rect.origin.x*self.scale,
//	                  rect.origin.y*self.scale,
//	                  rect.size.width*self.scale,
//	                  rect.size.height*self.scale);
//	
//	NSLog(@"self.imageOrientation = %d", self.imageOrientation);
//	
//	UIImageOrientation orientation;
//	if (self.imageOrientation == UIImageOrientationRight)
//		orientation = UIImageOrientationLeft;
//	else if (self.imageOrientation == UIImageOrientationLeft)
//		orientation = UIImageOrientationRight;
//	else
//		orientation = UIImageOrientationUp;
//	
//	NSLog(@"NEW imageOrientation = %d", orientation);
//
//	CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], rect);
//	UIImage *result = [UIImage imageWithCGImage:imageRef
//	                                      scale:self.scale
//	                                orientation:orientation];
//	CGImageRelease(imageRef);
//	return result;
	
	// Part 1:
	// This rotates the given rect, according to the imageOrientation.
	// That way the crop is correct.
	
	CGAffineTransform rectTransform;
    switch (self.imageOrientation)
    {
        case UIImageOrientationLeft:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(rad(90)), 0, -self.size.height);
            break;
        case UIImageOrientationRight:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(rad(-90)), -self.size.width, 0);
            break;
        case UIImageOrientationDown:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(rad(-180)), -self.size.width, -self.size.height);
            break;
        default:
            rectTransform = CGAffineTransformIdentity;
    };
    rectTransform = CGAffineTransformScale(rectTransform, self.scale, self.scale);
	
    CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], CGRectApplyAffineTransform(rect, rectTransform));
    
	UIImage *result = [UIImage imageWithCGImage:imageRef scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(imageRef);
	
//	return result;
	
	// Part 2:
	// On the device, the image will still be sideways (or whatever).
	// So this rotates it back to the correct position.
	//
	// (I thought I could just specify UIImageOrientationUp, but that didn't work...)
	
	UIGraphicsBeginImageContext(result.size);
	CGContextRef context = (UIGraphicsGetCurrentContext());
	
    if (result.imageOrientation == UIImageOrientationRight) {
        CGContextRotateCTM (context, 90/180*M_PI) ;
    } else if (result.imageOrientation == UIImageOrientationLeft) {
        CGContextRotateCTM (context, -90/180*M_PI);
    } else if (result.imageOrientation == UIImageOrientationDown) {
        // NOTHING
    } else if (result.imageOrientation == UIImageOrientationUp) {
        CGContextRotateCTM (context, 90/180*M_PI);
    }
	
    [result drawAtPoint:CGPointMake(0, 0)];
    UIImage *img=UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
#else  // alternative
	   // Create bitmap image from original image data,
	   // using rectangle to specify desired crop area
	
	UIImageOrientation orientation = self.imageOrientation;
	
	CGAffineTransform transform;
    switch (orientation)
    {
        case UIImageOrientationLeft:
            transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(M_PI_2), 0, -self.size.height);
            break;
        case UIImageOrientationRight:
            transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(3 * M_PI_2), -self.size.width, 0);
            break;
        case UIImageOrientationDown:
            transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(M_PI), -self.size.width, -self.size.height);
            break;
        default:
            transform = CGAffineTransformIdentity;
    };
	CGRect newRect = CGRectApplyAffineTransform(rect, transform);
	
    CGImageRef imageRef = CGImageCreateWithImageInRect(self.CGImage, newRect);
    
	UIImage *croppedImage = [UIImage imageWithCGImage:imageRef scale:self.scale orientation:orientation];
    CGImageRelease(imageRef);
	
	return croppedImage;

	
#endif
}


- (UIImage *)imageByScalingAndCroppingForSize:(CGSize)targetSize
{
    UIImage *sourceImage = self;
    UIImage *newImage = nil;
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;
    CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);
    
    if (CGSizeEqualToSize(imageSize, targetSize) == NO)
    {
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;
        
        if (widthFactor > heightFactor)
        {
            scaleFactor = widthFactor; // scale to fit height
        }
        else
        {
            scaleFactor = heightFactor; // scale to fit width
        }
        
        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;
        
        // center the image
        if (widthFactor > heightFactor)
        {
            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
        }
        else
        {
            if (widthFactor < heightFactor)
            {
                thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
            }
        }
    }
    
    UIGraphicsBeginImageContext(targetSize); // this will crop
    
    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;
    
    [sourceImage drawInRect:thumbnailRect];
    
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    if(newImage == nil)
    {
        NSLog(@"could not scale image");
    }
    
    //pop the context to get back to the default
    UIGraphicsEndImageContext();
    
    return newImage;
}
@end
