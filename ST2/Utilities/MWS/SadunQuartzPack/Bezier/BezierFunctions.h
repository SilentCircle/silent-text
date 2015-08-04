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

#import <Foundation/Foundation.h>
#import "BezierElement.h"

#define NUMBER_OF_BEZIER_SAMPLES    6

typedef CGFloat (^InterpolationBlock)(CGFloat percent);

// Return Bezier Value
float CubicBezier(float t, float start, float c1, float c2, float end);
float QuadBezier(float t, float start, float c1, float end);

// Return Bezier Point
CGPoint CubicBezierPoint(CGFloat t, CGPoint start, CGPoint c1, CGPoint c2, CGPoint end);
CGPoint QuadBezierPoint(CGFloat t, CGPoint start, CGPoint c1, CGPoint end);

// Calculate Curve Length
float CubicBezierLength(CGPoint start, CGPoint c1, CGPoint c2, CGPoint end);
float QuadBezierLength(CGPoint start, CGPoint c1, CGPoint end);

// Element Distance
CGFloat ElementDistanceFromPoint(BezierElement *element, CGPoint point, CGPoint startPoint);

// Linear Interpolation
CGPoint InterpolateLineSegment(CGPoint p1, CGPoint p2, CGFloat percent, CGPoint *slope);

// Interpolate along element
CGPoint InterpolatePointFromElement(BezierElement *element, CGPoint point, CGPoint startPoint, CGFloat percent, CGPoint *slope);

// Ease
CGFloat EaseIn(CGFloat currentTime, int factor);
CGFloat EaseOut(CGFloat currentTime, int factor);
CGFloat EaseInOut(CGFloat currentTime, int factor);
