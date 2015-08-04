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
//  ActivationBaseVC.h
//  ST2
//
//  Created by Eric Turner on 10/28/14.
//

#import <UIKit/UIKit.h>
#import "ActivationVCDelegate.h"

/** ET 10/29/14
 * This class abstracts view handling for "Activation" controllers.
 *
 * The updateContainerViewTopContstraint method positions the controller view appropriately for iPad/iPhone
 * device sizes. This class also implements scrollView, containerView, and constraint properties for this
 * purpose.
 *
 * ActivationVCDelegte is a companion new delegate protocol which, similarly, generalizes the callback to
 * dismiss the Activation controller with a single delegate handler, instead of separate handlers for the 
 * several "Activation" controller classes. OnboardViewController, SettingsViewController, and MessagesViewController
 * classes all now implement this single delegate callback.
 */

@class STDynamicHeightView;
@class AppTheme;

@interface ActivationBaseVC : UIViewController
{    
    IBOutlet STDynamicHeightView *containerView;
    IBOutlet NSLayoutConstraint *containerViewTopContstraint;
    IBOutlet UIScrollView *scrollView;
}
@property (nonatomic, weak) id<ActivationVCDelegate>delegate;
@property (nonatomic, assign) BOOL isModal;
@property (nonatomic, assign) BOOL isInPopover;
@property (nonatomic, readonly) AppTheme *theme;

@end
