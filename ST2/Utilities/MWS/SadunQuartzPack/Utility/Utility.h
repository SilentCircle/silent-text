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

#import <UIKit/UIKit.h>
//#import <QuartzCore/QuartzCore.h>
//#import "BaseGeometry.h"
//#import "Drawing-Block.h"
//#import "Drawing-Util.h"
//#import "Drawing-Gradient.h"
//#import "Bezier.h"
//#import "ImageUtils.h"

#define BARBUTTON(TITLE, SELECTOR) [[UIBarButtonItem alloc] initWithTitle:TITLE style:UIBarButtonItemStylePlain target:self action:SELECTOR]
#define RGBCOLOR(_R_, _G_, _B_) [UIColor colorWithRed:(CGFloat)(_R_)/255.0f green: (CGFloat)(_G_)/255.0f blue: (CGFloat)(_B_)/255.0f alpha: 1.0f]

#define OLIVE RGBCOLOR(125, 162, 63)
#define LIGHTPURPLE RGBCOLOR(99, 62, 162)
#define DARKGREEN RGBCOLOR(40, 55, 32)

// Bail with complaint
#define COMPLAIN_AND_BAIL(_COMPLAINT_, _ARG_) {NSLog(_COMPLAINT_, _ARG_); return;}
#define COMPLAIN_AND_BAIL_NIL(_COMPLAINT_, _ARG_) {NSLog(_COMPLAINT_, _ARG_); return nil;}

UIBezierPath *BuildBunnyPath();
UIBezierPath *BuildMoofPath();
UIBezierPath *BuildStarPath();

UIColor *NoiseColor();