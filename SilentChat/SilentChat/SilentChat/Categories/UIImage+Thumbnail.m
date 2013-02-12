/*
Copyright © 2012-2013, Silent Circle, LLC.  All rights reserved.

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

#import "UIImage+Thumbnail.h"
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>

CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
 
@implementation UIImage (Thumbnail)


-(UIImage*)scaled:(float)scaleFactor
{
    float newWidth = self.size.width * scaleFactor;
    float newHeight = self.size.height * scaleFactor;
     
    UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
    [self drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
    
}


-(UIImage*)scaledToHeight:(float)height;
{
    float oldHeight = self.size.height;
    float scaleFactor = height / oldHeight;
    
    float newWidth = self.size.width * scaleFactor;
    float newHeight = oldHeight * scaleFactor;
    
    UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
    [self drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
    
}

-(UIImage*)scaledToWidth:(float)width
{
    float oldWidth = self.size.width;
    float scaleFactor = width / oldWidth;
    
    float newHeight = self.size.height * scaleFactor;
    float newWidth = oldWidth * scaleFactor;
    
    UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
    [self drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
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


- (UIImage *)imageWithBadgeOverlay:(UIImage*)watermarkImage text:(NSString*)textString textColor:(UIColor*) textColor
{
    
    
    CGFloat fontSize = 14.;
    UIFont *font = [UIFont systemFontOfSize:fontSize];
    
    CGSize watermarkImageSize = watermarkImage? watermarkImage.size : CGSizeMake(5,5);
    
    CGPoint origin = CGPointMake(10, self.size.height - 5 - watermarkImageSize.height *2);
    
    CGSize textRectSize    = [textString sizeWithFont:font];
    CGRect textRect = CGRectMake( self.size.width - textRectSize.width - fontSize, origin.y + font.descender, textRectSize.width, textRectSize.height);
    CGRect badgeRect = CGRectMake(textRect.origin.x - (watermarkImageSize.width * 2) -  2,
                                  origin.y, watermarkImageSize.width * 2, watermarkImageSize.height *2);
    
    CGRect unionRect = CGRectInset(CGRectMake(badgeRect.origin.x, badgeRect.origin.y, (textRect.origin.x + textRect.size.width) - badgeRect.origin.x,
                                  textRect.size.height > badgeRect.size.height? textRect.size.height :badgeRect.size.height), font.descender , font.descender );
    if(!watermarkImage)
    {
        unionRect.origin.x += watermarkImageSize.width;
        unionRect.size.width -= watermarkImageSize.width;
        unionRect.origin.y+=5;
     }
    
    UIGraphicsBeginImageContext(self.size);
    
     
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
    if(watermarkImage) [watermarkImage drawInRect:badgeRect];
    
    [textColor set];
    
    [textString drawInRect:textRect
                  withFont:font
             lineBreakMode:NSLineBreakByTruncatingTail
                 alignment:NSTextAlignmentLeft];
    
    
    [[UIColor colorWithWhite:0.0 alpha:.5] set];
    UIBezierPath* path = [UIBezierPath bezierPathWithRoundedRect:unionRect cornerRadius:10.0];
    [path fillWithBlendMode:kCGBlendModeOverlay alpha:.5];
    
  //  UIRectFillUsingBlendMode(unionRect, kCGBlendModeOverlay);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    return newImage;
}

-(UIImage *)roundedImageWithRadius: (float) radius
{
    CALayer *imageLayer = [CALayer layer];
    imageLayer.frame = CGRectMake(0, 0, self.size.width, self.size.height);
    imageLayer.contents = (id) self.CGImage;
    
    imageLayer.masksToBounds = YES;
    imageLayer.cornerRadius = radius;
    
    UIGraphicsBeginImageContext(self.size);
    [imageLayer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *roundedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return roundedImage;
}

@end
