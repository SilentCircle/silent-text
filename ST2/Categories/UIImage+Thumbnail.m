/*
Copyright © 2012-2014, Silent Circle, LLC.  All rights reserved.

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
//  UIImage+Thumbnail.m
//  SilentText
//
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>

#import "UIImage+Thumbnail.h"


CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
static CGFloat const kMaxSirenThumbnailHeightOrWidth = 150;
 
@implementation UIImage (Thumbnail)

+ (UIImage*) defaultImageForMediaType:(NSString*) mediaType
{
  
    UIImage* thumbnail = NULL;

    
    // stupid hack to fool UIDocumentInteractionController to give us icons for the UTI,
    //  Apple is infested with gnomes
    NSURL*fooUrl = [NSURL URLWithString:@"file://foot.dat"];
    UIDocumentInteractionController* doc = [UIDocumentInteractionController interactionControllerWithURL:fooUrl];
    doc.UTI =  mediaType;
    NSArray *icons = doc.icons;
    if(icons && icons.count > 0)
    {
        thumbnail =   [[icons lastObject] copy] ;

    }
    
    return thumbnail;
}

- (UIImage *)scaled:(float)scaleFactor
{
    float newWidth = self.size.width * scaleFactor;
    float newHeight = self.size.height * scaleFactor;
	
	CGSize newSize = CGSizeMake(newWidth, newHeight);
	float screenScale = [[UIScreen mainScreen] scale];
	
	UIImage *newImage = nil;
	UIGraphicsBeginImageContextWithOptions(newSize, NO, screenScale);
	{
		[self drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
		newImage = UIGraphicsGetImageFromCurrentImageContext();
	}
	UIGraphicsEndImageContext();
	
	return newImage;
}


- (UIImage *)scaledToHeight:(float)requestedHeight
{
	float scaleFactor = requestedHeight / self.size.height;
	
	float newWidth = self.size.width * scaleFactor;
	float newHeight = self.size.height * scaleFactor;
	
	CGSize newSize = CGSizeMake(newWidth, newHeight);
	float screenScale = [[UIScreen mainScreen] scale];
	
	UIImage *newImage = nil;
	UIGraphicsBeginImageContextWithOptions(newSize, NO, screenScale);
	{
		[self drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
		newImage = UIGraphicsGetImageFromCurrentImageContext();
	}
	UIGraphicsEndImageContext();
	
	return newImage;
}

- (UIImage *)scaledToWidth:(float)requestedWidth
{
    float scaleFactor = requestedWidth / self.size.width;
    
    float newHeight = self.size.height * scaleFactor;
    float newWidth = self.size.width * scaleFactor;
	
	CGSize newSize = CGSizeMake(newWidth, newHeight);
	float screenScale = [[UIScreen mainScreen] scale];
	
	UIImage *newImage = nil;
	UIGraphicsBeginImageContextWithOptions(newSize, NO, screenScale);
	{
		[self drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
		newImage = UIGraphicsGetImageFromCurrentImageContext();
	}
	UIGraphicsEndImageContext();
	
	return newImage;
}
 
//  UIImage-Extensions.m
//
//  Created by Hardy Macia on 7/1/09.
//  Copyright 2009 Catamount Software. All rights reserved.
//

- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees
{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.size.width, self.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(DegreesToRadians(degrees));
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    
    
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    //   // Rotate the image context
    CGContextRotateCTM(bitmap, DegreesToRadians(degrees));
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), [self CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
    
}

- (UIImage *)imageWithBadgeOverlay:(UIImage*)watermarkImage origin:(CGPoint)origin
{
    CGSize totalSize = self.size;
    
    if(origin.x < 0) totalSize.width +=  fabs(origin.x);
    if(origin.y < 0) totalSize.height +=  fabs(origin.y);
    
    CGSize watermarkImageSize = watermarkImage? watermarkImage.size : CGSizeMake(5,5);

    CGRect badgeRect = CGRectMake(origin.x < 0?0:origin.x,
                                  origin.y < 0?0:origin.y,
                                  watermarkImageSize.width,
                                  watermarkImageSize.height);
    
    
    CGRect imageRect = CGRectMake(origin.x < 0?fabs(origin.x):0,
                                  origin.y < 0?fabs(origin.y):0,
                                  self.size.width, self.size.height);
    
    
    UIGraphicsBeginImageContext(totalSize);
    
    [self drawInRect:imageRect];

    if(watermarkImage) [watermarkImage drawInRect:badgeRect];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    return newImage;

  }

- (UIImage *)imageWithBadgeOverlay:(UIImage *)watermarkImage text:(NSString *)textString textColor:(UIColor *)textColor
{
	CGFloat fontSize = 16.0;
	UIFont *font = [UIFont systemFontOfSize:fontSize];
    NSDictionary *attributes = @{ NSFontAttributeName: font };
	
    CGSize watermarkImageSize = watermarkImage ? watermarkImage.size : CGSizeMake(5, 5);
    
    CGPoint origin = CGPointMake(6, (self.size.height - 10 - watermarkImageSize.height * 2));
    
    CGSize textRectSize = [textString sizeWithAttributes:attributes];
	CGRect textRect = (CGRect){
		.origin.x = self.size.width - textRectSize.width - fontSize,
		.origin.y = origin.y + font.descender,
		.size.width = textRectSize.width,
		.size.height = textRectSize.height
	};
	CGRect badgeRect = (CGRect){
		.origin.x = textRect.origin.x - (watermarkImageSize.width * 2) -  2,
		.origin.y = origin.y,
		.size.width = watermarkImageSize.width * 2,
		.size.height = watermarkImageSize.height * 2
	};
	
	CGRect unionRect = (CGRect){
		.origin.x = badgeRect.origin.x,
		.origin.y = badgeRect.origin.y,
		.size.width = (textRect.origin.x + textRect.size.width) - badgeRect.origin.x,
		.size.height = (textRect.size.height > badgeRect.size.height ?textRect.size.height :badgeRect.size.height) + font.descender
	};
	unionRect = CGRectInset(unionRect, 2.0*font.descender, 2.0*font.descender);
	
	if(!watermarkImage)
    {
        unionRect.origin.x += watermarkImageSize.width;
        unionRect.size.width -= watermarkImageSize.width;
        unionRect.origin.y+=5;
	}
    
    UIGraphicsBeginImageContext(self.size);
    
	
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
	[[UIColor colorWithWhite:0.0 alpha:.5] set];
	UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:unionRect cornerRadius:10.0];
	[path fill];
	
	if (watermarkImage)
		[watermarkImage drawInRect:badgeRect];
	
	[textColor set];
    
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	style.lineBreakMode = NSLineBreakByTruncatingTail;
	style.alignment = NSTextAlignmentLeft;
	
	attributes = @{
	  NSFontAttributeName: font,
	  NSParagraphStyleAttributeName: style,
	  NSForegroundColorAttributeName: textColor
	};
	
    [textString drawInRect:textRect withAttributes:attributes];
    
//	UIRectFillUsingBlendMode(unionRect, kCGBlendModeOverlay);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    return newImage;
}

- (UIImage *)roundedImageWithCornerRadius:(float)radius
{
	CGSize size = self.size;
	float screenScale = [[UIScreen mainScreen] scale];
	
    CALayer *imageLayer = [CALayer layer];
    imageLayer.frame = CGRectMake(0, 0, size.width, size.height);
    imageLayer.contents = (id) self.CGImage;
    
    imageLayer.masksToBounds = YES;
    imageLayer.cornerRadius = radius;
	
	UIImage *roundedImage = nil;
	UIGraphicsBeginImageContextWithOptions(size, NO, screenScale);
	{
		[imageLayer renderInContext:UIGraphicsGetCurrentContext()];
    	roundedImage = UIGraphicsGetImageFromCurrentImageContext();
	}
	UIGraphicsEndImageContext();
	
	return roundedImage;
}

- (UIImage *)avatarImageWithDiameter:(CGFloat)diameter
{
	UIImage *finalImage;
 	float scale = [[UIScreen mainScreen] scale];
    diameter = diameter / scale;
    
	float lineWidth = diameter * 0.045;

	CGSize newSize = CGSizeMake(diameter * scale, diameter * scale);
    
    // are we on a retina display?
    if(scale == 2.0)
    {
         UIGraphicsBeginImageContextWithOptions(newSize, NO, 2.0);
    }
    else
    {
      	UIGraphicsBeginImageContext(newSize);
     }
    
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetShouldAntialias (context, YES);
    
	// the circle's stroke straddles the actual circle, so half its width will be on
	// the outside of the circle and half on the inside
	CGRect strokeRect = (CGRect){
		.origin.x = lineWidth / 2.0,
		.origin.y = lineWidth / 2.0,
		.size.width = newSize.width - lineWidth,
		.size.height = newSize.height - lineWidth
	};
	
	// the following three lines the circule around the image
	CGContextSetRGBStrokeColor(context, 1.0, 1.0, 1.0, 0.9);
	CGContextSetLineWidth(context, lineWidth);
	CGContextStrokeEllipseInRect(context, strokeRect);
	
	// the image area is the total area minus the stroke
	CGRect imageRect = CGRectMake(lineWidth, lineWidth, newSize.width - 2 * lineWidth, newSize.height - 2 * lineWidth);
	
	// the following three lines clips the image so nothing draws out beyond the image/circle area
	CGContextBeginPath(context);
	CGContextAddEllipseInRect(context, imageRect);
	CGContextClip(context);
	
	// flip the context and then draw the image
	CGAffineTransform transform = CGAffineTransformConcat(CGAffineTransformIdentity, CGAffineTransformMakeScale(1.0, -1.0));
	transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(0.0, newSize.height));
	CGContextConcatCTM(context, transform);
	CGContextDrawImage(context, imageRect, self.CGImage);
	
	finalImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return finalImage;
	
}

- (UIImage *)scaledAvatarImageWithDiameter:(CGFloat)diameter
{
	UIImage *finalImage;
 	float scale = [[UIScreen mainScreen] scale];
    diameter = diameter / scale;
    
    float lineWidth = diameter * 0.045;
	
	CGSize newSize = CGSizeMake(diameter * scale, diameter * scale);
    
    // are we on a retina display?
    if(scale == 2.0)
    {
        UIGraphicsBeginImageContextWithOptions(newSize, NO, 2.0);
    }
    else
    {
      	UIGraphicsBeginImageContext(newSize);
    }
    
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetShouldAntialias(context, YES);
    
//	// the circle's stroke straddles the actual circle, so half its width will be on
//	// the outside of the circle and half on the inside
//	CGRect strokeRect = (CGRect){
//		.origin.x = lineWidth / 2.0,
//		.origin.y = lineWidth / 2.0,
//		.size.width = newSize.width - lineWidth,
//		.size.height = newSize.height - lineWidth
//	};
//	
//	// the following three lines the circule around the image
//	CGContextSetRGBStrokeColor(context, 1.0, 1.0, 1.0, 0.9);
//	CGContextSetLineWidth(context, lineWidth);
//	CGContextStrokeEllipseInRect(context, strokeRect);
	
	// the image area is the total area minus the stroke
	CGRect imageRect = CGRectMake(lineWidth, lineWidth, newSize.width - 2 * lineWidth, newSize.height - 2 * lineWidth);
	
	// the following three lines clips the image so nothing draws out beyond the image/circle area
	CGContextBeginPath(context);
	CGContextAddEllipseInRect(context, imageRect);
	CGContextClip(context);
	
	// flip the context and then draw the image
	CGAffineTransform transform = CGAffineTransformConcat(CGAffineTransformIdentity, CGAffineTransformMakeScale(1.0, -1.0));
	transform = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(0.0, newSize.height));
	CGContextConcatCTM(context, transform);
	CGContextDrawImage(context, imageRect, self.CGImage);
	
	finalImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return finalImage;
	
}


- (UIImage *)avatarImageWithDiameter:(CGFloat)diameter usingColor:(UIColor *)color
{
	if (color == nil)
		color = [UIColor blackColor];
    
   	UIImage *finalImage;
 	float scale = [[UIScreen mainScreen] scale];
    diameter = diameter / scale;
    
	float lineWidth = diameter * 0.045;

	CGSize newSize = CGSizeMake(diameter * scale, diameter * scale);
    
    // are we on a retina display?
    if(scale == 2.0)
    {
        UIGraphicsBeginImageContextWithOptions(newSize, NO, 2.0);
    }
    else
    {
      	UIGraphicsBeginImageContext(newSize);
    }
    
    
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetShouldAntialias(context, YES);
 
    // draw original image into the context
	[self drawAtPoint:CGPointZero];
   
	// the circle's stroke straddles the actual circle, so half its width will be on
	// the outside of the circle and half on the inside
	CGRect strokeRect = (CGRect){
		.origin.x = lineWidth / 2.0,
		.origin.y = lineWidth / 2.0,
		.size.width = newSize.width - lineWidth,
		.size.height = newSize.height - lineWidth
	};

	// the following three lines draw the circle around the image
    CGContextSetStrokeColorWithColor(context, color.CGColor);
 	CGContextSetLineWidth(context, lineWidth);
	CGContextStrokeEllipseInRect(context, strokeRect);
 
    finalImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return finalImage;

}
- (UIImage *)avatarImageWithDiameter:(CGFloat)diameter usingColor:(UIColor*)color  font:(UIFont*)font text:(NSString*)text
{
    if(!color) color = [UIColor blackColor];
    
    UIImage *finalImage;
 	float scale = [[UIScreen mainScreen] scale];
    diameter = diameter / scale;
    
    
	CGSize newSize = CGSizeMake(diameter * scale, diameter * scale);
    
    // are we on a retina display?
    if(scale == 2.0)
    {
        UIGraphicsBeginImageContextWithOptions(newSize, NO, 2.0);
    }
    else
    {
      	UIGraphicsBeginImageContext(newSize);
    }
    
    // draw original image into the context
	[self drawAtPoint:CGPointZero];
 
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    [paragraphStyle setAlignment:NSTextAlignmentCenter];
    NSAttributedString *initialsString = [[NSAttributedString alloc] initWithString:text
                                                                         attributes:@{NSFontAttributeName:font,
                                                                                      NSForegroundColorAttributeName:color,
                                                                                      NSParagraphStyleAttributeName:paragraphStyle}];

 	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetShouldAntialias (context, YES);
   
    CGContextSetStrokeColorWithColor(context,  color.CGColor);
 
    [self drawAtPoint:CGPointMake(0.0f, 0.0f)];
    CGFloat fontHeight = font.lineHeight;
    
    CGFloat yOffset = (diameter - fontHeight) / 2.0;
    
    [initialsString drawInRect:CGRectMake(0, yOffset, diameter, diameter)];

    finalImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return finalImage;

}

+ (UIImage *)multiAvatarImageWithFront:(UIImage *)frontImage back:(UIImage *)backImage diameter:(CGFloat)diameter
{
	float scale = [[UIScreen mainScreen] scale];
	float avatarScale = .6;
	
	frontImage = [frontImage avatarImageWithDiameter:(diameter * avatarScale)];
	backImage = [backImage avatarImageWithDiameter:(diameter * avatarScale)];
	
	CGSize newSize = CGSizeMake(diameter * scale, diameter * scale);

    // are we on a retina display?
    if(scale == 2.0)
    {
        UIGraphicsBeginImageContextWithOptions(newSize, NO, 2.0);
    }
    else
    {
      	UIGraphicsBeginImageContext(newSize);
    }

    CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetShouldAntialias (context, YES);

    [backImage drawInRect:(CGRect){
		.origin.x = 0,
		.origin.y = 0,
		.size.width = newSize.width * avatarScale,
		.size.height = newSize.height * avatarScale
	}];
	
	[frontImage drawInRect:(CGRect){
		.origin.x = newSize.width * 0.3,
		.origin.y = newSize.height * 0.3,
		.size.width = newSize.width * avatarScale,
		.size.height = newSize.height * avatarScale
	}];
	
	UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	return finalImage;
}

- (UIImage *)convertToGrayScale
{
    // Create image rectangle with current image width/height
    CGRect imageRect = CGRectMake(0, 0, self.size.width, self.size.height);
    
    // Grayscale color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    
    // Create bitmap content with current image size and grayscale colorspace
    CGContextRef context = CGBitmapContextCreate(nil, self.size.width, self.size.height, 8, 0, colorSpace,
	                                             (kCGBitmapAlphaInfoMask & kCGImageAlphaNone));
    
    // Draw image into current context, with specified rectangle
    // using previously defined context (with grayscale colorspace)
    CGContextDrawImage(context, imageRect, [self CGImage]);
    
    // Create bitmap image info from pixel data in current context
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    
    // Create a new UIImage object
    UIImage *newImage = [UIImage imageWithCGImage:imageRef];
    
    // Release colorspace, context and bitmap information
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    CFRelease(imageRef);
    
    // Return the new grayscale image
    return newImage;
}


//ST-928 03/28/15
+ (CGFloat)maxSirenThumbnailHeightOrWidth 
{
    return kMaxSirenThumbnailHeightOrWidth;
}

@end
