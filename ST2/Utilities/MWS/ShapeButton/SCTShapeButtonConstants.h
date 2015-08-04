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
//
//  SCTShapeButtonConstants.h
//  ST2
//
//  Created by Eric Turner on 7/1/14.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SCTShapeButtonConstants : NSObject
@end

#pragma mark - SCTShapeButtonConstants Constants

// Color properties
//extern NSString * const SCT_fillColorKey;
//extern NSString * const SCT_highlightColorKey;
//extern NSString * const SCT_strokeColorKey;
//extern NSString * const SCT_subTitleColorKey;
//extern NSString * const SCT_titleColorKey;
// Non-color properties
//extern NSString * const SCT_cornerRadiusKey;
//extern NSString * const SCT_isCircleShapeKey;
//extern NSString * const SCT_shapePathKey;
//extern NSString * const SCT_strokeWidthKey;
//extern NSString * const SCT_subTitleTextKey;
//extern NSString * const SCT_titleTextKey;
//extern NSString * const SCT_useHighlightAnimationKey;

extern NSString * const SCT_ShapeButton_fillColor;
extern NSString * const SCT_ShapeButton_highlightColor;
extern NSString * const SCT_ShapeButton_strokeColor;
extern NSString * const SCT_ShapeButton_subTitleColor;
extern NSString * const SCT_ShapeButton_titleColor;

// Non-color properties
extern NSString * const SCT_ShapeButton_cornerRadius;
extern NSString * const SCT_ShapeButton_isCircleShape;
extern NSString * const SCT_ShapeButton_shapePath;
extern NSString * const SCT_ShapeButton_strokeWidth;
extern NSString * const SCT_ShapeButton_subTitleText;
extern NSString * const SCT_ShapeButton_titleText;
extern NSString * const SCT_ShapeButton_useHighlightAnimation;

//#define SCT_CIRCLE_SHAPE_RADIUS  (int)self.frame.size.width / 2
//#define SCT_CIRCLE_RECT     CGRectMake(0, 0, 2 * SCT_DEFAULT_SHAPE_CORNER_RADIUS, 2 * SCT_DEFAULT_SHAPE_CORNER_RADIUS)
#define SCT_DEFAULT_SHAPEBUTTON_CORNER_RADIUS       0
#define SCT_DEFAULT_SHAPEBUTTON_STROKE_WIDTH        2
#define SCT_DEFAULT_SHAPEBUTTON_STROKE_COLOR        self.superview.tintColor
#define SCT_DEFAULT_SHAPEBUTTON_FILL_COLOR          [UIColor clearColor]
#define SCT_DEFAULT_SHAPEBUTTON_HIGHLIGHT_COLOR     SCT_DEFAULT_STROKE_COLOR // default: highlight same as stroke
extern NSTimeInterval const SCT_SHAPE_BUTTON_ANIMATION_DURATION;

