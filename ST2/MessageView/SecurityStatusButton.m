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
//  SecurityStatusButton.m
//  SecurityStatusButton
//
//  Created by Jacob Hazelgrove on 2/22/14.
//

#import "SecurityStatusButton.h"

typedef NS_ENUM(NSUInteger, _SCSecurityLevelInternal) {
	_SCSecurityLevelInternalLow,	/**< Indicates a low security dot, should be drawn red */
	_SCSecurityLevelInternalMedium,	/**< Indicates a medium security dot, should be drawn yellow */
    _SCSecurityLevelInternalHigh	/**< Indicates a high security dot, should be drawn green */
};


@interface SecurityStatusButton ()

/*!
 @property levelIndicators
 @discussion Returns an array of NSNumber objects representing type _SCSecurityLevelInternal to be drawn. A nil or empty array draws nothing.
 */
@property (strong) NSArray *levelIndicators;

- (void)commonInit;

@end

@implementation SecurityStatusButton

- (id)init {
	return [self initWithFrame:CGRectZero];
}

- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	if (self) {
		[self commonInit];
	}
	
	return self;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	
	if (self) {
		[self commonInit];
	}
	
	return self;
}


- (void)commonInit {
	self.securityLevel = SCSecurityLevelNone;
}

//-(void)setTintColor:(UIColor *)tintColor
//{
//	[super setTintColor:tintColor];
//}
//- (void)setEnabled:(BOOL)enabled
//{
//	[super setEnabled:enabled];
//}
//
//- (void)setSelected:(BOOL)enabled
//{
//	[super setSelected:enabled];
//}
//
//-(void)setHighlighted:(BOOL)highlighted
//{
//	[super setHighlighted:highlighted];
//}
//
//-(void)setNeedsDisplay {
//	[super setNeedsDisplay];
//	[self setImage:[[self imageWithColor:YES] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
//	[self setImage:[[self imageWithColor:NO] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateDisabled];
//
//}

- (void)setSecurityLevel:(SCSecurityLevel)securityLevel {
	_securityLevel = securityLevel;
	
	switch (_securityLevel) {
		case SCSecurityLevelNone:
			self.levelIndicators = nil;
			break;
			
		case SCSecurityLevelRed:
			self.levelIndicators = @[@(_SCSecurityLevelInternalLow), @(_SCSecurityLevelInternalLow), @(_SCSecurityLevelInternalLow)];
			break;
			
		case SCSecurityLevelYellow1:
			self.levelIndicators = @[@(_SCSecurityLevelInternalMedium)];
			break;
			
		case SCSecurityLevelYellow2:
			self.levelIndicators = @[@(_SCSecurityLevelInternalMedium), @(_SCSecurityLevelInternalMedium)];
			break;
			
		case SCSecurityLevelYellow3:
			self.levelIndicators = @[@(_SCSecurityLevelInternalMedium), @(_SCSecurityLevelInternalMedium), @(_SCSecurityLevelInternalMedium)];
			break;
			
		case SCSecurityLevelGreen:
			self.levelIndicators = @[@(_SCSecurityLevelInternalHigh), @(_SCSecurityLevelInternalHigh), @(_SCSecurityLevelInternalHigh)];
			break;

		default:
			break;
	}

	[self setNeedsDisplay];
}

- (UIColor *)colorForInternalSecurityLevel:(_SCSecurityLevelInternal)internalSecurityLevel {
	UIColor *color = nil;
	
	if (internalSecurityLevel == _SCSecurityLevelInternalLow) {
		color = [UIColor redColor];
	}
	
	else if (internalSecurityLevel == _SCSecurityLevelInternalMedium) {
		color = [UIColor yellowColor];
	}
	
	else if (internalSecurityLevel == _SCSecurityLevelInternalHigh) {
		color = [UIColor greenColor];
	}
	
	return color;
}

- (void)drawRect:(CGRect)rect {
	// clear out existing text
	//[self setTitle:nil forState:UIControlStateNormal];

	// NOTE: frame is optimized for use as a UIBarButtonItem
	CGRect frame = CGRectMake(CGRectMaxXEdge - 1.0f, self.bounds.origin.y + 4.0f, 44.0f, 18.0f);

	CGFloat radius = CGRectGetHeight(frame) / 2.00f;

	[self.superview.tintColor set];
	UIBezierPath *capsulePath = [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:radius];
	capsulePath.lineWidth = 1.0f;
	[capsulePath stroke];

	CGRect dotContainer = CGRectInset(frame, 4.0f, 2.0f);
	CGFloat offset = dotContainer.size.width/6;
	CGFloat dotHeight = dotContainer.size.height/2;

	if (self.levelIndicators) {
		for (NSNumber *levelIndicatorNumber in self.levelIndicators) {
			CGRect rect = CGRectMake(CGRectGetMinX(dotContainer) + offset - dotHeight/2, CGRectGetMinY(dotContainer) + dotHeight/2, dotHeight, dotHeight);

			UIColor *color = [self colorForInternalSecurityLevel:[levelIndicatorNumber integerValue]];
			[color set];
			UIBezierPath *dotPath = [UIBezierPath bezierPathWithOvalInRect:rect];
			[dotPath fill];

			// give it an outline
			[[UIColor darkGrayColor] set];
			dotPath.lineWidth = 0.5f;
			[dotPath stroke];

			offset += (dotContainer.size.width)/3;
		}
	}
}

- (UIImage *)imageWithColor:(BOOL)color
{
    UIGraphicsBeginImageContext(self.frame.size);
//	CGContextRef context = UIGraphicsGetCurrentContext();
	
	// NOTE: frame is optimized for use as a UIBarButtonItem
	CGRect frame = CGRectMake(CGRectMaxXEdge - 1.0f, self.bounds.origin.y + 4.0f, 44.0f, 18.0f);
	
	CGFloat radius = CGRectGetHeight(frame) / 2.00f;
	if (color)
		[self.superview.tintColor set];
	UIBezierPath *capsulePath = [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:radius];
	capsulePath.lineWidth = 1.0f;
	[capsulePath stroke];
	
	CGRect dotContainer = CGRectInset(frame, 4.0f, 2.0f);
	CGFloat offset = dotContainer.size.width/6;
	CGFloat dotHeight = dotContainer.size.height/2;
	
	if (self.levelIndicators) {
		for (NSNumber *levelIndicatorNumber in self.levelIndicators) {
			CGRect rect = CGRectMake(CGRectGetMinX(dotContainer) + offset - dotHeight/2, CGRectGetMinY(dotContainer) + dotHeight/2, dotHeight, dotHeight);
			
			if (color)
			{
				UIColor *color = [self colorForInternalSecurityLevel:[levelIndicatorNumber integerValue]];
				[color set];
			}
			UIBezierPath *dotPath = [UIBezierPath bezierPathWithOvalInRect:rect];
			[dotPath fill];
			
			// give it an outline
			[[UIColor darkGrayColor] set];
			dotPath.lineWidth = 0.5f;
			[dotPath stroke];
			
			offset += (dotContainer.size.width)/3;
		}
	}

	
	
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	
    return image;
}


@end
