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

#import "BaseGeometry.h"

#pragma mark - Conversion
// Degrees from radians
CGFloat DegreesFromRadians(CGFloat radians)
{
    return radians * 180.0f / M_PI;
}

// Radians from degrees
CGFloat RadiansFromDegrees(CGFloat degrees)
{
    return degrees * M_PI / 180.0f;
}

#pragma mark - Clamp
CGFloat Clamp(CGFloat a, CGFloat min, CGFloat max)
{
    return fmin(fmax(min, a), max);
}

CGPoint ClampToRect(CGPoint pt, CGRect rect)
{
    CGFloat x = Clamp(pt.x, CGRectGetMinX(rect), CGRectGetMaxX(rect));
    CGFloat y = Clamp(pt.y, CGRectGetMinY(rect), CGRectGetMaxY(rect));
    return CGPointMake(x, y);
}


#pragma mark - General Geometry
CGPoint RectGetCenter(CGRect rect)
{
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

CGFloat PointDistanceFromPoint(CGPoint p1, CGPoint p2)
{
    CGFloat dx = p2.x - p1.x;
    CGFloat dy = p2.y - p1.y;
    
    return sqrt(dx*dx + dy*dy);
}

CGPoint RectGetPointAtPercents(CGRect rect, CGFloat xPercent, CGFloat yPercent)
{
    CGFloat dx = xPercent * rect.size.width;
    CGFloat dy = yPercent * rect.size.height;
    return CGPointMake(rect.origin.x + dx, rect.origin.y + dy);
}

#pragma mark - Rectangle Construction
CGRect RectMakeRect(CGPoint origin, CGSize size)
{
    return (CGRect){.origin = origin, .size = size};
}

CGRect SizeMakeRect(CGSize size)
{
    return (CGRect){.size = size};
}

CGRect PointsMakeRect(CGPoint p1, CGPoint p2)
{
    CGRect rect = CGRectMake(p1.x, p1.y, p2.x - p1.x, p2.y - p1.y);
    return CGRectStandardize(rect);
}

CGRect OriginMakeRect(CGPoint origin)
{
    return (CGRect){.origin = origin};
}

CGRect RectAroundCenter(CGPoint center, CGSize size)
{
    CGFloat halfWidth = size.width / 2.0f;
    CGFloat halfHeight = size.height / 2.0f;
    
    return CGRectMake(center.x - halfWidth, center.y - halfHeight, size.width, size.height);
}

CGRect RectCenteredInRect(CGRect rect, CGRect mainRect)
{
    CGFloat dx = CGRectGetMidX(mainRect)-CGRectGetMidX(rect);
    CGFloat dy = CGRectGetMidY(mainRect)-CGRectGetMidY(rect);
    return CGRectOffset(rect, dx, dy);
}


#pragma mark -
#pragma mark - ET Rect 
CGRect SmallSquareFromRect(CGRect rect) {
    CGFloat side = (rect.size.width > rect.size.height) ? rect.size.height : rect.size.width;
    rect.size = CGSizeMake(side, side);
    return rect;
}

CGRect LargeSquareFromRect(CGRect rect) {
    CGFloat side = (rect.size.width > rect.size.height) ? rect.size.width : rect.size.height;
    rect.size = CGSizeMake(side, side);
    return rect;
}

BOOL RectIsSquare(CGRect rect) {
    return rect.size.width == rect.size.height;
}

#pragma mark -
#pragma mark - Point Location
CGPoint PointAddPoint(CGPoint p1, CGPoint p2)
{
    return CGPointMake(p1.x + p2.x, p1.y + p2.y);
}

CGPoint PointSubtractPoint(CGPoint p1, CGPoint p2)
{
    return CGPointMake(p1.x - p2.x, p1.y - p2.y);
}

#pragma mark - Cardinal Points
CGPoint RectGetTopLeft(CGRect rect)
{
    return CGPointMake(
                       CGRectGetMinX(rect),
                       CGRectGetMinY(rect)
                       );
}

CGPoint RectGetTopRight(CGRect rect)
{
    return CGPointMake(
                       CGRectGetMaxX(rect),
                       CGRectGetMinY(rect)
                       );
}

CGPoint RectGetBottomLeft(CGRect rect)
{
    return CGPointMake(
                       CGRectGetMinX(rect),
                       CGRectGetMaxY(rect)
                       );
}

CGPoint RectGetBottomRight(CGRect rect)
{
    return CGPointMake(
                       CGRectGetMaxX(rect),
                       CGRectGetMaxY(rect)
                       );
}

CGPoint RectGetMidTop(CGRect rect)
{
    return CGPointMake(
                       CGRectGetMidX(rect),
                       CGRectGetMinY(rect)
                       );
}

CGPoint RectGetMidBottom(CGRect rect)
{
    return CGPointMake(
                       CGRectGetMidX(rect),
                       CGRectGetMaxY(rect)
                       );
}

CGPoint RectGetMidLeft(CGRect rect)
{
    return CGPointMake(
                       CGRectGetMinX(rect),
                       CGRectGetMidY(rect)
                       );
}

CGPoint RectGetMidRight(CGRect rect)
{
    return CGPointMake(
                       CGRectGetMaxX(rect),
                       CGRectGetMidY(rect)
                       );
}

#pragma mark - Aspect and Fitting
CGSize SizeScaleByFactor(CGSize aSize, CGFloat factor)
{
    return CGSizeMake(aSize.width * factor, aSize.height * factor);
}

CGSize RectGetScale(CGRect sourceRect, CGRect destRect)
{
    CGSize sourceSize = sourceRect.size;
    CGSize destSize = destRect.size;
    
    CGFloat scaleW = destSize.width / sourceSize.width;
    CGFloat scaleH = destSize.height / sourceSize.height;
    
    return CGSizeMake(scaleW, scaleH);
}

CGFloat AspectScaleFill(CGSize sourceSize, CGRect destRect)
{
    CGSize destSize = destRect.size;
    CGFloat scaleW = destSize.width / sourceSize.width;
    CGFloat scaleH = destSize.height / sourceSize.height;
    return fmax(scaleW, scaleH);
}

CGFloat AspectScaleFit(CGSize sourceSize, CGRect destRect)
{
    CGSize destSize = destRect.size;
    CGFloat scaleW = destSize.width / sourceSize.width;
    CGFloat scaleH = destSize.height / sourceSize.height;
    return fmin(scaleW, scaleH);
}

CGRect RectByFittingRect(CGRect sourceRect, CGRect destinationRect)
{
    CGFloat aspect = AspectScaleFit(sourceRect.size, destinationRect);
    CGSize targetSize = SizeScaleByFactor(sourceRect.size, aspect);
    return RectAroundCenter(RectGetCenter(destinationRect), targetSize);
}

CGRect RectByFillingRect(CGRect sourceRect, CGRect destinationRect)
{
    CGFloat aspect = AspectScaleFill(sourceRect.size, destinationRect);
    CGSize targetSize = SizeScaleByFactor(sourceRect.size, aspect);
    return RectAroundCenter(RectGetCenter(destinationRect), targetSize);
}

CGRect RectInsetByPercent(CGRect rect, CGFloat percent)
{
    CGFloat wInset = rect.size.width * (percent / 2.0f);
    CGFloat hInset = rect.size.height * (percent / 2.0f);
    return CGRectInset(rect, wInset, hInset);
}

#pragma mark - Transforms

// Extract the x scale from transform
CGFloat TransformGetXScale(CGAffineTransform t)
{
    return sqrt(t.a * t.a + t.c * t.c);
}

// Extract the y scale from transform
CGFloat TransformGetYScale(CGAffineTransform t)
{
    return sqrt(t.b * t.b + t.d * t.d);
}

// Extract the rotation in radians
CGFloat TransformGetRotation(CGAffineTransform t)
{
    return atan2f(t.b, t.a);
}
