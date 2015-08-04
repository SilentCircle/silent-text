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
#import <UIKit/UIKit.h>

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
@interface STDynamicHeightView : UIView

- (CGSize)intrinsicContentSize; // overridden

@end
