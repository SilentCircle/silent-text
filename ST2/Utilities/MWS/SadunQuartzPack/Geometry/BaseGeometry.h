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

#import <CoreGraphics/CoreGraphics.h> 
#import <Foundation/Foundation.h>

// Just because
#define TWO_PI (2 * M_PI)

// Undefined point
#define NULLPOINT CGRectNull.origin
#define POINT_IS_NULL(_POINT_) CGPointEqualToPoint(_POINT_, NULLPOINT)

// General
#define RECTSTRING(_aRect_)        NSStringFromCGRect(_aRect_)
#define POINTSTRING(_aPoint_)    NSStringFromCGPoint(_aPoint_)
#define SIZESTRING(_aSize_)        NSStringFromCGSize(_aSize_)

#define RECT_WITH_SIZE(_SIZE_) (CGRect){.size = _SIZE_}
#define RECT_WITH_POINT(_POINT_) (CGRect){.origin = _POINT_}

// Conversion
CGFloat DegreesFromRadians(CGFloat radians);
CGFloat RadiansFromDegrees(CGFloat degrees);

// Clamping
CGFloat Clamp(CGFloat a, CGFloat min, CGFloat max);
CGPoint ClampToRect(CGPoint pt, CGRect rect);

// General Geometry
CGPoint RectGetCenter(CGRect rect);
CGFloat PointDistanceFromPoint(CGPoint p1, CGPoint p2);
#pragma mark - ET Rect 
CGRect SmallSquareFromRect(CGRect rect);
CGRect LargeSquareFromRect(CGRect rect);
BOOL   RectIsSquare(CGRect rect);

// Construction
CGRect RectMakeRect(CGPoint origin, CGSize size);
CGRect SizeMakeRect(CGSize size);
CGRect PointsMakeRect(CGPoint p1, CGPoint p2);
CGRect OriginMakeRect(CGPoint origin);
CGRect RectAroundCenter(CGPoint center, CGSize size);
CGRect RectCenteredInRect(CGRect rect, CGRect mainRect);

// Point Locations
CGPoint RectGetPointAtPercents(CGRect rect, CGFloat xPercent, CGFloat yPercent);
CGPoint PointAddPoint(CGPoint p1, CGPoint p2);
CGPoint PointSubtractPoint(CGPoint p1, CGPoint p2);

// Cardinal Points
CGPoint RectGetTopLeft(CGRect rect);
CGPoint RectGetTopRight(CGRect rect);
CGPoint RectGetBottomLeft(CGRect rect);
CGPoint RectGetBottomRight(CGRect rect);
CGPoint RectGetMidTop(CGRect rect);
CGPoint RectGetMidBottom(CGRect rect);
CGPoint RectGetMidLeft(CGRect rect);
CGPoint RectGetMidRight(CGRect rect);

// Aspect and Fitting
CGSize  SizeScaleByFactor(CGSize aSize, CGFloat factor);
CGSize  RectGetScale(CGRect sourceRect, CGRect destRect);
CGFloat AspectScaleFill(CGSize sourceSize, CGRect destRect);
CGFloat AspectScaleFit(CGSize sourceSize, CGRect destRect);
CGRect  RectByFittingRect(CGRect sourceRect, CGRect destinationRect);
CGRect  RectByFillingRect(CGRect sourceRect, CGRect destinationRect);
CGRect  RectInsetByPercent(CGRect rect, CGFloat percent);

// Transforms
CGFloat TransformGetXScale(CGAffineTransform t);
CGFloat TransformGetYScale(CGAffineTransform t);
CGFloat TransformGetRotation(CGAffineTransform t);
