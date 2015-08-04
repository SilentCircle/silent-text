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

//#import <Foundation/Foundation.h>
//#import "BaseGeometry.h"

CGRect PathBoundingBox(UIBezierPath *path);
CGRect PathBoundingBoxWithLineWidth(UIBezierPath *path);
CGPoint PathBoundingCenter(UIBezierPath *path);
CGPoint PathCenter(UIBezierPath *path);

// Transformations
void ApplyCenteredPathTransform(UIBezierPath *path, CGAffineTransform transform);
UIBezierPath *PathByApplyingTransform(UIBezierPath *path, CGAffineTransform transform);

// Utility
void RotatePath(UIBezierPath *path, CGFloat theta);
void ScalePath(UIBezierPath *path, CGFloat sx, CGFloat sy);
void OffsetPath(UIBezierPath *path, CGSize offset);
void MovePathToPoint(UIBezierPath *path, CGPoint point);
void MovePathCenterToPoint(UIBezierPath *path, CGPoint point);
void MirrorPathHorizontally(UIBezierPath *path);
void MirrorPathVertically(UIBezierPath *path);

// Fitting
void FitPathToRect(UIBezierPath *path, CGRect rect);
void AdjustPathToRect(UIBezierPath *path, CGRect destRect);

// Path Attributes
void CopyBezierState(UIBezierPath *source, UIBezierPath *destination);
void CopyBezierDashes(UIBezierPath *source, UIBezierPath *destination);
void AddDashesToPath(UIBezierPath *path);

// String to Path
UIBezierPath *BezierPathFromString(NSString *string, UIFont *font);
UIBezierPath *BezierPathFromStringWithFontFace(NSString *string, NSString *fontFace);

// N-Gons
UIBezierPath *BezierPolygon(NSUInteger numberOfSides);
UIBezierPath *BezierInflectedShape(NSUInteger numberOfInflections, CGFloat percentInflection);
UIBezierPath *BezierStarShape(NSUInteger numberOfInflections, CGFloat percentInflection);

// Misc
void ClipToRect(CGRect rect);
void FillRect(CGRect rect, UIColor *color);
void ShowPathProgression(UIBezierPath *path, CGFloat maxPercent);

// Effects
void SetShadow(UIColor *color, CGSize size, CGFloat blur);
void DrawShadow(UIBezierPath *path, UIColor *color, CGSize size, CGFloat blur);
void DrawInnerShadow(UIBezierPath *path, UIColor *color, CGSize size, CGFloat blur);
void EmbossPath(UIBezierPath *path, UIColor *color, CGFloat radius, CGFloat blur);
void BevelPath(UIBezierPath *p,  UIColor *color, CGFloat r, CGFloat theta);
void InnerBevel(UIBezierPath *p,  UIColor *color, CGFloat r, CGFloat theta);
void ExtrudePath(UIBezierPath *path, UIColor *color, CGFloat radius, CGFloat angle);

@interface UIBezierPath (HandyUtilities)
@property (nonatomic, readonly) CGPoint center;
@property (nonatomic, readonly) CGRect computedBounds;
@property (nonatomic, readonly) CGRect computedBoundsWithLineWidth;

// Stroke/Fill
- (void) stroke: (CGFloat) width;
- (void) stroke: (CGFloat) width color: (UIColor *) color;
- (void) strokeInside: (CGFloat) width;
- (void) strokeInside: (CGFloat) width color: (UIColor *) color;
- (void) fill: (UIColor *) fillColor;
- (void) fill: (UIColor *) fillColor withMode: (CGBlendMode) blendMode;
- (void) fillWithNoise: (UIColor *) fillColor;
- (void) addDashes;
- (void) addDashes: (NSArray *) pattern;
- (void) applyPathPropertiesToContext;

// Clipping
- (void) clipToPath; // I hate addClip
- (void) clipToStroke: (NSUInteger) width;

// Util
- (UIBezierPath *) safeCopy;
@end
