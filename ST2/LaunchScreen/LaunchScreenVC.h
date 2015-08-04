/*
Copyright (C) 2015, Silent Circle, LLC. All rights reserved.

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
//  LaunchScreenVC.h
//  ST2
//
//  Created by Eric Turner on 4/2/15.
//

#import <UIKit/UIKit.h>

/**
 * This class is the initial view controller in the LaunchScreen.storyboard.
 *
 * In iOS 8, Apple introduced the Launch Screen feature which enables the use
 * of a view controller from a storboard to define the launch view. This feature
 * is activated in Project Settings > General > Launch Screen File. In this
 * project, this setting is set to LaunchScreen.storyboard. Note also that the
 * Launch Images Source setting is cleared (displaying the Use Asset Catalog option).
 *
 * Note that a launch screen view controller does not get normal UIViewController
 * callbacks such as viewDidLoad, viewWillDisappear, etc., when going into or 
 * returning from the background.
 *
 * In this implementation, the LaunchScreenVC is configured in IB as the 
 * initialViewController. Its view contains two subviews:
 *
 * - an imageView containing the dark gradient background, pinned with autoLayout
 *   to resize to full containing view size,
 *
 * - a smaller imageView containing the SC logo image, centered with autoLayout
 *   and sized using AdaptiveLayout for various devices screen sizes and orientations.
 *
 * A single, high-resolution image is used for each imageView, with its view mode
 * set to scaleToFill. The autoLayout constraints handle rotating the imageViews
 * appropriately, and sizeClass configurations scale the logo imageView to a
 * percentage of the containing view width or height, as appropriate for device and
 * orientation.
 */
@interface LaunchScreenVC : UIViewController

@end
