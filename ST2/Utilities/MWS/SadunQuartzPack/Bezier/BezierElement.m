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


#import "Bezier.h"

#pragma mark - Bezier Element -

@implementation BezierElement
- (instancetype) init
{
    self = [super init];
    if (self)
    {
        _elementType = kCGPathElementMoveToPoint;
        _point = NULLPOINT;
        _controlPoint1 = NULLPOINT;
        _controlPoint2 = NULLPOINT;
    }
    return self;
}

+ (instancetype) elementWithPathElement: (CGPathElement) element
{
    BezierElement *newElement = [[self alloc] init];
    newElement.elementType = element.type;
    
    switch (newElement.elementType)
    {
        case kCGPathElementCloseSubpath:
            break;
        case kCGPathElementMoveToPoint:
        case kCGPathElementAddLineToPoint:
        {
            newElement.point = element.points[0];
            break;
        }
        case kCGPathElementAddQuadCurveToPoint:
        {
            newElement.point = element.points[1];
            newElement.controlPoint1 = element.points[0];
            break;
        }
        case kCGPathElementAddCurveToPoint:
        {
            newElement.point = element.points[2];
            newElement.controlPoint1 = element.points[0];
            newElement.controlPoint2 = element.points[1];
            break;
        }
        default:
            break;
    }
    
    return newElement;
}

- (instancetype) copyWithZone: (NSZone *) zone
{
    BezierElement *theCopy = [[[self class] allocWithZone:zone] init];
    if (theCopy)
    {
        theCopy.elementType = _elementType;
        theCopy.point = _point;
        theCopy.controlPoint1 = _controlPoint1;
        theCopy.controlPoint2 = _controlPoint2;
    }
    return theCopy;
}

#pragma mark - Path

- (BezierElement *) elementByApplyingBlock: (PathBlock) block
{
    BezierElement *output = [self copy];
    if (!block)
        return output;
    
    if (!POINT_IS_NULL(output.point))
        output.point = block(output.point);
    if (!POINT_IS_NULL(output.controlPoint1))
        output.controlPoint1 = block(output.controlPoint1);
    if (!POINT_IS_NULL(output.controlPoint2))
        output.controlPoint2 = block(output.controlPoint2);
    return output;
}

- (void) addToPath: (UIBezierPath *) path
{
    switch (self.elementType)
    {
        case kCGPathElementCloseSubpath:
            [path closePath];
            break;
        case kCGPathElementMoveToPoint:
            [path moveToPoint:self.point];
            break;
        case kCGPathElementAddLineToPoint:
            [path addLineToPoint:self.point];
            break;
        case kCGPathElementAddQuadCurveToPoint:
            [path addQuadCurveToPoint:self.point controlPoint:self.controlPoint1];
            break;
        case kCGPathElementAddCurveToPoint:
            [path addCurveToPoint:self.point controlPoint1:self.controlPoint1 controlPoint2:self.controlPoint2];
            break;
        default:
            break;
    }
}

#pragma mark - Strings

- (NSString *) stringValue
{
    switch (self.elementType)
    {
        case kCGPathElementCloseSubpath:
            return @"Close Path";
        case kCGPathElementMoveToPoint:
            return [NSString stringWithFormat:@"Move to point %@", POINTSTRING(self.point)];
        case kCGPathElementAddLineToPoint:
            return [NSString stringWithFormat:@"Add line to point %@", POINTSTRING(self.point)];
        case kCGPathElementAddQuadCurveToPoint:
            return [NSString stringWithFormat:@"Add quad curve to point %@ with control point %@", POINTSTRING(self.point), POINTSTRING(self.controlPoint1)];
        case kCGPathElementAddCurveToPoint:
            return [NSString stringWithFormat:@"Add curve to point %@ with control points %@ and %@", POINTSTRING(self.point), POINTSTRING(self.controlPoint1), POINTSTRING(self.controlPoint2)];
    }
    return nil;
}

- (void) showTheCode
{
    switch (self.elementType)
    {
        case kCGPathElementCloseSubpath:
            printf("    [path closePath];\n\n");
            break;
        case kCGPathElementMoveToPoint:
            printf("    [path moveToPoint:CGPointMake(%f, %f)];\n",
                   self.point.x, self.point.y);
            break;
        case kCGPathElementAddLineToPoint:
            printf("    [path addLineToPoint:CGPointMake(%f, %f)];\n",
                   self.point.x, self.point.y);
            break;
        case kCGPathElementAddQuadCurveToPoint:
            printf("    [path addQuadCurveToPoint:CGPointMake(%f, %f) controlPoint:CGPointMake(%f, %f)];\n",
                   self.point.x, self.point.y, self.controlPoint1.x, self.controlPoint1.y);
            break;
        case kCGPathElementAddCurveToPoint:
            printf("    [path addCurveToPoint:CGPointMake(%f, %f) controlPoint1:CGPointMake(%f, %f) controlPoint2:CGPointMake(%f, %f)];\n",
                   self.point.x, self.point.y, self.controlPoint1.x, self.controlPoint1.y, self.controlPoint2.x, self.controlPoint2.y);
            break;
        default:
            break;
    }
}
@end

