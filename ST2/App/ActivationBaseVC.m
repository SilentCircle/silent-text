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
//  ActivationBaseVC.m
//  ST2
//
//  Created by Eric Turner on 10/28/14.
//

#import "ActivationBaseVC.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "AppDelegate.h"
#import "STLogging.h"
#import "STDynamicHeightView.h"

// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
static const int ddLogLevel = LOG_LEVEL_INFO; // VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


@interface ActivationBaseVC () @end


@implementation ActivationBaseVC

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
    DDLogAutoTrace();
    [super viewDidLoad];
    
    self.view.tintColor = self.theme.appTintColor;
    
    // Handle navbar underlapping
//    if (self.navigationController.navigationBar.isTranslucent)
//        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    self.navigationController.navigationBar.translucent = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    DDLogAutoTrace();
    [super viewWillAppear:animated];
        
    // Tweak vertical position of containerView    
    [self updateContainerViewTopContstraint];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Rotation & Constraints
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateContainerViewTopContstraint
{
    DDLogAutoTrace();
    
    CGFloat totalHeight = self.view.bounds.size.height;
    CGFloat containerViewHeight = containerView.frame.size.height;
    
    CGFloat availableHeight = totalHeight - containerViewHeight;
    
    DDLogVerbose(@"totalHeight(%.0f) containerViewHeight(%.0f) availableHeight(%.0f)",
                 totalHeight, containerViewHeight, availableHeight);
    
    if (availableHeight <= 0)
    {
        DDLogVerbose(@"containerViewTopContstraint.constant = 0 (availableHeight <= 0)");
        containerViewTopContstraint.constant = 0;
    }
    else if ([AppConstants isIPhone])
    {
        // We want it to be 10 pixels from the top (if possible)
        CGFloat offsetFromTop = MIN(availableHeight, 10.0f);
        
        DDLogVerbose(@"containerViewTopContstraint.constant = %.0f (iPhone)", offsetFromTop);
        containerViewTopContstraint.constant = offsetFromTop;
    }
    else // if ([AppConstants isIPad])
    {
        // We don't want it to be exactly vertically centered.
        // We want it more towards the top.
        //
        // Top/Bottom ratio == 30/70
        
        CGFloat offsetFromTop = floorf(availableHeight * 0.3f);
        
        DDLogVerbose(@"containerViewTopContstraint.constant = %.0f (iPad)", offsetFromTop);
        containerViewTopContstraint.constant = offsetFromTop;
    }
    
    [containerView setNeedsUpdateConstraints];
}

/**
 * This method is called from within the animation block used to rotate the view. You can override this method
 * and use it to configure additional animations that should occur during the view rotation. For example, you could
 * use it to adjust the zoom level of your content, change the scroller position, or modify other animatable
 * properties of your view.
 *
 * By the time this method is called, the interfaceOrientation property is already set to the new orientation,
 * and the bounds of the view have been changed. Thus, you can perform any additional layout required by your
 * views in this method.
 **/
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    DDLogAutoTrace();
    [super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];
    
    [self updateContainerViewTopContstraint];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Popover Size
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is queried * by our own code * when creating popover controllers.
 * It is conceptually similar to the deprecated contentSizeForViewInPopover method.
 **/
- (CGSize)preferredPopoverContentSize
{
    DDLogAutoTrace();
    
    // If this method is queried before we've loaded the view, then containerView will be nil.
    // So we make sure the view is loaded first.
    if (![self isViewLoaded]) {
        (void)[self view];
    }
    
    CGFloat height = containerView.frame.size.height;
    
    // Note: If we just return the height,
    // then in iOS 8 the popover will continually get longer
    // everytime we bring up an action sheet.
    //
    // So its important that we use a calculated height (via intrinsicContentSize).    
    if ([containerView isKindOfClass:[STDynamicHeightView class]])
    {
        CGSize size = [(STDynamicHeightView *)containerView intrinsicContentSize];
        if (size.height != UIViewNoIntrinsicMetric)
        {
            height = size.height;
        }
    }
    
    return CGSizeMake(320, height);
}

/**
 * This method is invoked automatically when the view is displayed in a popover.
 * The popover system uses this method to automatically size the popover accordingly.
 */ 
- (CGSize)preferredContentSize
{
    DDLogAutoTrace();
    return [self preferredPopoverContentSize];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Accessors
- (AppTheme *)theme
{
    return STAppDelegate.theme;
}

@end
