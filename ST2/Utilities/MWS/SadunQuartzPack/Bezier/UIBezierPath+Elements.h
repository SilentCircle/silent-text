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
#import "Bezier.h"

// Construct path
UIBezierPath *BezierPathWithElements(NSArray *elements);
UIBezierPath *BezierPathWithPoints(NSArray *points);
UIBezierPath *InterpolatedPath(UIBezierPath *path);

// Partial paths
UIBezierPath *CroppedPath(UIBezierPath *path, CGFloat percent);
UIBezierPath *PathFromPercentToPercent(UIBezierPath *path, CGFloat startPercent, CGFloat endPercent);

/*

 UIBezierPath - Elements Category
 
 */

@interface UIBezierPath (Elements)

@property (nonatomic, readonly) NSArray *elements;
@property (nonatomic, readonly) NSArray *subpaths;

@property (nonatomic, readonly) NSArray *destinationPoints;
@property (nonatomic, readonly) NSArray *interpolatedPathPoints;

@property (nonatomic, readonly) NSUInteger count;
- (id)objectAtIndexedSubscript:(NSUInteger)idx;

@property (nonatomic, readonly) CGPoint center;
@property (nonatomic, readonly) CGRect calculatedBounds;

@property (nonatomic, readonly) UIBezierPath *reversed;
@property (nonatomic, readonly) UIBezierPath *inverse;
@property (nonatomic, readonly) UIBezierPath *boundedInverse;

@property (nonatomic, readonly) BOOL subpathIsClosed;
- (BOOL) closeSafely;

// Measure length
@property (nonatomic, readonly) CGFloat pathLength;
- (CGPoint) pointAtPercent: (CGFloat) percent withSlope: (CGPoint *) slope;

// String Representations
- (void) showTheCode;
- (NSString *) stringValue;

// -- Invert path to arbitrary rectangle
- (UIBezierPath *) inverseInRect: (CGRect) rect;
@end