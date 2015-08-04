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
#import "STDynamicHeightView.h"
#import "STLogging.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_OFF; // VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG && eric_turner
  static const int ddLogLevel = LOG_LEVEL_OFF; // LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_OFF; // | LOG_FLAG_TRACE;
#else
  static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

/**
 * This is a custom subview of UIView that implements intrinsicContentSize.
 * The intrinsicContentSize.height is automatically calculated based on NON-HIDDEN subviews.
 * So the height of this view will automatically change simply by showing / hiding subviews.
 *
 * Here's how to use it:
 *
 * In Interface Builder, you create a UIView, and then change its class to STDynamicHeightView.
 * Then you add a bunch of subviews to it (such as labels, buttons, etc).
 * Next add all the constraints for every view, with one exception:
 * Do not set a height constraint for this view.
 * Rather, in Interface Builder, change its "Intrinsic Size" from "Default (system defined)" to "Placeholder".
 * Then put a checkmark for "None" next to the width.
 * We are telling IB that this view has only an intrinsic height.
 * This way IB is in-sync with what will happen at runtime,
 * and you won't get a bunch of constraint warnings in IB.
 *
 * At runtime, simply toggle the hidden flag of subviews as needed.
 * Then invoke code like this:
 *
 * [subviewButton setHidden:YES];
 * [myDynamicHeightView invalidateIntrinsicContentSize];
 * [self.view setNeedsUpdateConstraints];
 *
 * Enjoy!
 *
 * -Robbie Hanson
**/
@implementation STDynamicHeightView
{
	CGFloat bottomPadding;
}

/**
 * This custom UIView is for constraints based layout systems.
 * Throw a hissy fit if we try to use it elsewhere.
**/
+ (BOOL)requiresConstraintBasedLayout
{
	return YES;
}

/**
 * This method is used to init the view from a XIB.
 * We hook into it in order to find out what kind of padding we should have on the bottom.
 * 
 * That is, the amount of extra space between the bottom of the "lowest" subview, and the bottom of our view.
 * Note that this value could be negative if the view is meant to cutoff some portion of the lowest subview.
**/
- (id)initWithCoder:(NSCoder *)decoder
{
	DDLogAutoTrace();
	
	if ((self = [super initWithCoder:decoder]))
	{
		CGFloat maxYValue = 0;
		for (UIView *subview in self.subviews)
		{
			CGRect subviewFrame = subview.frame;
			CGFloat subviewMaxYValue = subviewFrame.origin.y + subviewFrame.size.height;
			
			if (maxYValue < subviewMaxYValue) {
				maxYValue = subviewMaxYValue;
			}
		}
		
		CGFloat height = self.frame.size.height;
		
		bottomPadding = height - maxYValue;
		DDLogVerbose(@"%p: bottomPadding = %f", self, bottomPadding);
	}
	return self;
}

/**
 * This method is called as part of the constraints based layout system.
 * This is where we calculate how tall our view should be.
 * We do this by looking at visible subviews.
 * Any hidden subviews are ignored.
**/
- (CGSize)intrinsicContentSize
{
	DDLogAutoTrace();
	
	// Having problems with this method?
	// Perhaps it's not getting called when it ought to be.
	//
	// Step 1 - Turn on logging so you can see when it gets called (or set a breakpoint).
	// Step 2 - Invoke [myDynamicHeightView invalidateIntrinsicContentSize] whenever you
	//          hide/show a subview.
	
	UIView *maxYSubview = nil;
	
	CGFloat maxYValue = 0;
	for (UIView *subview in self.subviews)
	{
		if (subview.hidden)
		{
			DDLogVerbose(@"%p: subview hidden (ignoring)", self);
			continue;
		}
		
		CGRect subviewFrame = subview.frame;
		DDLogVerbose(@"%p: subviewFrame = %@", self, NSStringFromCGRect(subviewFrame));
		
		CGFloat subviewMaxYValue = subviewFrame.origin.y + subviewFrame.size.height;
		
		if (maxYValue < subviewMaxYValue) {
			maxYValue = subviewMaxYValue;
			maxYSubview = subview;
		}
	}
	
	CGSize result = CGSizeMake(UIViewNoIntrinsicMetric, (maxYValue + bottomPadding));
	DDLogVerbose(@"%p: maxYSubview: %@", self, maxYSubview);
	DDLogVerbose(@"%p: intrinsicContentSize = %@", self, NSStringFromCGSize(result));
	
	return result;
}

/**
 *
**/
- (void)layoutSubviews
{
	DDLogAutoTrace();
	
	// The layout system runs after the constraints system.
	// This poses a small problem for our intrinsicContentSize method.
	//
	// - The constraint system asks for our intrinsicContentSize and we calculate it
	// - Then the layout system moves the frame(s) of one or more subviews
	//
	// The code here is designed to catch this edge case.
	// And when it does invalidates its intrinsicContentSize,
	// and forces another pass through the constraints system.
	//
	//
	
	NSMutableDictionary *frames = [NSMutableDictionary dictionaryWithCapacity:[self.subviews count]];
	
	for (UIView *subview in self.subviews)
	{
		NSNumber *pointer = [NSNumber numberWithLong:(long)subview];
		NSValue *frame = [NSValue valueWithCGRect:subview.frame];
		
		[frames setObject:frame forKey:pointer];
	}
	
	[super layoutSubviews];
	
	BOOL needsUpdateIntrinsicContentSize = NO;
	
	for (UIView *subview in self.subviews)
	{
		NSNumber *pointer = [NSNumber numberWithLong:(long)subview];
		
		CGRect oldFrame = [[frames objectForKey:pointer] CGRectValue];
		CGRect newFrame = subview.frame;
		
		if (!CGRectEqualToRect(oldFrame, newFrame))
		{
			DDLogVerbose(@"Detected subview frame change for subview: %@", subview);
			DDLogVerbose(@"oldFrame: %@", NSStringFromCGRect(oldFrame));
			DDLogVerbose(@"newFrame: %@", NSStringFromCGRect(newFrame));
			
			needsUpdateIntrinsicContentSize = YES;
			break;
		}
	}
	
	if (needsUpdateIntrinsicContentSize)
	{
		[self invalidateIntrinsicContentSize];
		[super layoutSubviews];
	}
}

@end
