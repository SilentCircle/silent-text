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
//  SCTEyeball.h
//  ST2
//
//  Created by Eric Turner on 7/1/14.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCTEyeballDelegate.h"

/**
 * A custom control which toggles between displaying "open" and "closed" eye images, responding to a tap.
 *
 * Discussion:
 * This method overrides the superclass beginTrackingWithTouch:withEvent: method to toggle the open/closed eye images.
 *
 * Note: the `imgView` eye image is toggled before forwarding to super.
 *
 * History:
 * Original use: `SCTPasswordTextfield` initializes an instance of this control as its rightView property. It
 * responds to the UIControlEventTouchUpInside to display the secured password as plain text, and to message 
 * its `SCTPasswordTextfieldDelegate`.
 *
 */
@interface SCTEyeball: UIControl

/** The image for the "closed eye" state */
@property (nonatomic, strong) UIImage *closedImg;

/** */
@property (nonatomic, strong) UIImageView *imgView;

/** */
@property (nonatomic, readonly) BOOL isOpen;

/** The image for the "eye open" state */
@property (nonatomic, strong) UIImage *openImg;

/** Set this flag to `YES` to disable eye image toggling */
@property (nonatomic) BOOL pokeIsDisabled;


@end
