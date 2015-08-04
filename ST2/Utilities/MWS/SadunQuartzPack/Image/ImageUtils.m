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
/*
 
 Erica Sadun, http://ericasadun.com
 
 */

#import "ImageUtils.h"
//#import "Utility.h"
#import "BaseGeometry.h"

// Chapter 3-8
// Establish insets for image alignment
UIEdgeInsets BuildInsets(CGRect alignmentRect, CGRect imageBounds)
{
    // Ensure alignment rect is fully within source
    CGRect targetRect = CGRectIntersection(alignmentRect, imageBounds);
    
    // Calculate insets
    UIEdgeInsets insets;
    insets.left = CGRectGetMinX(targetRect) - CGRectGetMinX(imageBounds);
    insets.right = CGRectGetMaxX(imageBounds) - CGRectGetMaxX(targetRect);
    insets.top = CGRectGetMinY(targetRect) - CGRectGetMinY(imageBounds);
    insets.bottom = CGRectGetMaxY(imageBounds) - CGRectGetMaxY(targetRect);
    
    return insets;
}


// Chapter 3 - 1
UIImage *BuildSwatchWithColor(UIColor *color, CGFloat side)
{
    // Create image context
    UIGraphicsBeginImageContextWithOptions(
                                           CGSizeMake(side, side), YES,
                                           0.0);
    
    // Perform drawing
    [color setFill];
    UIRectFill(CGRectMake(0, 0, side, side));
    
    // Retrieve image
    UIImage *image =
    UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

// Chapter 3 - 2
UIImage *BuildThumbnail(UIImage *sourceImage, CGSize targetSize, BOOL useFitting)
{
    CGRect targetRect = SizeMakeRect(targetSize);
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 0.0);
    
    CGRect naturalRect = (CGRect){.size = sourceImage.size};
    CGRect destinationRect = useFitting ? RectByFittingRect(naturalRect, targetRect) : RectByFillingRect(naturalRect, targetRect);
    [sourceImage drawInRect:destinationRect];
    
    UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return thumbnail;
}

// Chapter 3 - 3
UIImage *ExtractRectFromImage(UIImage *sourceImage, CGRect subRect)
{
    // Extract image
    CGImageRef imageRef = CGImageCreateWithImageInRect(sourceImage.CGImage, subRect);
    if (imageRef != NULL)
    {
        UIImage *output = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        return output;
    }
    
    NSLog(@"Error: Unable to extract subimage");
    return nil;
}

// This is a little less flaky when moving to and from Retina images
UIImage *ExtractSubimageFromRect(UIImage *sourceImage, CGRect rect)
{
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 1);
    CGRect destRect = CGRectMake(-rect.origin.x, -rect.origin.y,
                                 sourceImage.size.width, sourceImage.size.height);
    [sourceImage drawInRect:destRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

// Chapter 3 - 4
UIImage *GrayscaleVersionOfImage(UIImage *sourceImage)
{
    // Establish grayscale color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    if (colorSpace == NULL)
    {
        NSLog(@"Error: Could not establish grayscale color space");
        return nil;
    }
    
    // Extents are integers
    int width = sourceImage.size.width;
    int height = sourceImage.size.height;
    
    // Build context: one byte per pixel, no alpha
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, BITS_PER_COMPONENT, width, colorSpace, (CGBitmapInfo)kCGImageAlphaNone);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
    {
        NSLog(@"Error: Could not build grayscale bitmap context");
        return nil;
    }
    
    // Replicate image using new color space
    CGRect rect = SizeMakeRect(sourceImage.size);
    CGContextDrawImage(context, rect, sourceImage.CGImage);
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    // Return the grayscale image
    UIImage *output = [UIImage imageWithCGImage:imageRef];
    CFRelease(imageRef);
    return output;
}

// Just for fun. Return image with colors flipped
UIImage *InvertImage(UIImage *sourceImage)
{
    UIGraphicsBeginImageContextWithOptions(sourceImage.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [sourceImage drawInRect:SizeMakeRect(sourceImage.size)];
    CGContextSetBlendMode(context, kCGBlendModeDifference);
    CGContextSetFillColorWithColor(context,[UIColor whiteColor].CGColor);
    CGContextFillRect(context, SizeMakeRect(sourceImage.size));
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

// Chapter 3-6
// Extract bytes
NSData *BytesFromRGBImage(UIImage *sourceImage)
{
    if (!sourceImage) return nil;
    
    // Establish color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL)
    {
        NSLog(@"Error creating RGB color space");
        return nil;
    }
    
    // Establish context
    int width = sourceImage.size.width;
    int height = sourceImage.size.height;
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, BITS_PER_COMPONENT, width * ARGB_COUNT, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace );
    if (context == NULL)
    {
        NSLog(@"Error creating context");
        return nil;
    }
    
    // Draw source into context bytes
    CGRect rect = (CGRect){.size = sourceImage.size};
    CGContextDrawImage(context, rect, sourceImage.CGImage);
    
    // Create NSData from bytes
    NSData *data = [NSData dataWithBytes:CGBitmapContextGetData(context) length:(width * height * 4)];
    CGContextRelease(context);
    
    return data;
}

// Chapter 3-7
// Create image from bytes
UIImage *ImageFromRGBBytes(NSData *data, CGSize targetSize)
{
    // Check data
    int width = targetSize.width;
    int height = targetSize.height;
    if (data.length < (width * height * 4))
    {
        NSLog(@"Error: Not enough RGB data provided. Got %lu bytes. Expected %d bytes", 
              (unsigned long)data.length, width * height * 4);
        return nil;
    }
    
    // Create a color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL)
    {
        NSLog(@"Error creating RGB colorspace");
        return nil;
    }
    
    // Create the bitmap context
    Byte *bytes = (Byte *) data.bytes;
    CGContextRef context = CGBitmapContextCreate(bytes, width, height, BITS_PER_COMPONENT, width * ARGB_COUNT, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace );
    if (context == NULL)
    {
        NSLog(@"Error. Could not create context");
        return nil;
    }
    
    // Convert to image
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    
    // Clean up
    CGContextRelease(context);
    CFRelease(imageRef);
    
    return image;
}

#pragma mark - Context

// From Chapter 1
void FlipContextVertically(CGSize size)
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
    {
        NSLog(@"Error: No context to flip");
        return;
    }
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformScale(transform, 1.0f, -1.0f);
    transform = CGAffineTransformTranslate(transform, 0.0f, -size.height);
    CGContextConcatCTM(context, transform);
}

void FlipImageContextVertically()
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
    {
        NSLog(@"Error: No context to flip");
        return;
    }
    
    // I don't like this approach
    //    CGFloat scale = [UIScreen mainScreen].scale;
    //    CGSize size = CGSizeMake(CGBitmapContextGetWidth(context) / scale, CGBitmapContextGetHeight(context) / scale);
    //    FlipContextVertically(size);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    FlipContextVertically(image.size);
}

void FlipContextHorizontally(CGSize size)
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformScale(transform, -1.0f, 1.0f);
    transform = CGAffineTransformTranslate(transform, -size.width, 0.0);
    CGContextConcatCTM(context, transform);
}

void FlipImageContextHorizontally()
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
    {
        NSLog(@"Error: No context to flip");
        return;
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    FlipContextHorizontally(image.size);
}

void RotateContext(CGSize size, CGFloat theta)
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, size.width / 2.0f, size.height / 2.0f);
    CGContextRotateCTM(context, theta);
    CGContextTranslateCTM(context, -size.width / 2.0f, -size.height / 2.0f);
}

void MoveContextByVector(CGPoint vector)
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, vector.x, vector.y);
}

UIImage *ImageMirroredVertically(UIImage *source)
{
    UIGraphicsBeginImageContextWithOptions(source.size, NO, 0.0);
    FlipContextVertically(source.size);
    [source drawInRect:SizeMakeRect(source.size)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}


#pragma mark - PDF Util
// Chapter 3-12
void DrawPDFPageInRect(CGPDFPageRef pageRef, CGRect destinationRect)
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
    {
        NSLog(@"Error: No context to draw to");
        return;
    }
    
    CGContextSaveGState(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    // Flip the context to Quartz space
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformScale(transform, 1.0f, -1.0f);
    transform = CGAffineTransformTranslate(transform, 0.0f, -image.size.height);
    CGContextConcatCTM(context, transform);
    
    // Flip the rect, which remains in UIKit space
    CGRect d = CGRectApplyAffineTransform(destinationRect, transform);
    
    // Calculate a rectangle to draw to
    CGRect pageRect = CGPDFPageGetBoxRect(pageRef, kCGPDFCropBox);
    CGFloat drawingAspect = AspectScaleFit(pageRect.size, d);
    CGRect drawingRect = RectByFittingRect(pageRect, d);
    
    // Draw the page outline (optional)
    UIRectFrame(drawingRect);
    
    // Adjust the context
    CGContextTranslateCTM(context, drawingRect.origin.x, drawingRect.origin.y);
    CGContextScaleCTM(context, drawingAspect, drawingAspect);
    
    // Draw the page
    CGContextDrawPDFPage(context, pageRef);
    CGContextRestoreGState(context);
}