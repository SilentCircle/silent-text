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
//  SCTTextCopyLabel.m
//  ST2
//
//  Created by Eric Turner on 7/11/14.
//

#import "SCTTextCopyLabel.h"
#import "STLogging.h"

// Log levels: off, error, warn, info, verbose
//#if DEBUG
//static const int ddLogLevel = LOG_LEVEL_INFO;
//#else
//static const int ddLogLevel = LOG_LEVEL_WARN;
//#endif


@interface SCTTextCopyLabel ()
@property (nonatomic, strong) NSArray *menuItemsCache;
@end

@implementation SCTTextCopyLabel


#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) { return  nil; }
    
    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc] initWithTarget:self 
                                                                                     action:@selector(handleLongPress:)];
	[self addGestureRecognizer:gr];

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (!self) { return nil; }
    
    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc] initWithTarget:self 
                                                                                     action:@selector(handleLongPress:)];
	[self addGestureRecognizer:gr];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Tap Handler / Menu setup

/**
 * The longPress gesture recognizer handler which fires the "Copy" menu presentation.
 *
 * @param gr The longPress gesture recognizer instantiated in the initializing method.
 */
- (IBAction)handleLongPress:(UILongPressGestureRecognizer *)gr
{
    if (gr.state == UIGestureRecognizerStateBegan)
    {
        // ET 07/11/14
        //
        // For flexibility, if the target/action pair are non-nil, we punt to the target. 
        // In effect, this creates a longPress-able label, and the copy function is not executed.
        //
        // Note that self is sent as the object argument, which means that the action selector
        // must be a method which takes a single parameter of a type UILabel, this sublass, or id. For example:
        // - (void)doSomethingWithLabel:(UILabel *)lbl
        //
        if (_target && _action) {
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            
            [_target performSelector:_action withObject:self];
            
#pragma clang diagnostic pop            
            if (nil == _delegate)
            {
                return; // return without presenting the copy menu
            }
        }
        
        if (nil == _delegate || [_delegate respondsToSelector:@selector(copyLabelShouldPresentCopyMenu:)])
        {            
            // Note: The call to self to become firstResponder MUST precede the call to presentMenuController.
            //
            // Info: The menu controller setup code is not required to be abstracted into another method; it can 
            //       follow the call to becomeFirstResponder.
            //
            [self becomeFirstResponder];
            [self presentMenuController];
        }
    }
}

/**
 * Presents the menuController with a single "Copy" item.
 *
 * This method abstracts the presentation of the menu from the longPress event handler, but the abstraction is not 
 * necessary. Importantly, the call for self to become firstResponder must precede the execution of the menu 
 * presentation code.
 */
- (void)presentMenuController
{
    // Store current sharedMenuController state
    self.menuItemsCache = [[UIMenuController sharedMenuController] menuItems];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    [menuController setTargetRect:self.frame inView:self.superview];    
    [menuController setMenuVisible:YES animated:YES];    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willHideMenuController:)
                                               name:UIMenuControllerWillHideMenuNotification
                                             object:nil];    
}

#pragma mark - Copy to Pasteboard
/**
 * Copy the self text string to the pasteboard
 *
 * @param The messaging instance: UIMenuController sharedController
 */
- (void)copy:(id)sender
{
    [[UIPasteboard generalPasteboard] setString:self.text];
}


#pragma mark - willHideMenuController Notification

/**
 * This notification handler restores the menuItems of the sharedMenuController singleton when the menu item is
 * dismissed, either by a tap on the "Copy" menu item, or in the view outside, to dismiss the menu without action.
 *
 * @param A system notification that the menu will be dismissed.
 */
- (void)willHideMenuController:(NSNotification *)notification
{
	[NSNotificationCenter.defaultCenter removeObserver:self
												  name:UIMenuControllerWillHideMenuNotification
												object:nil];
	
	// Replace shared menuController original items.
	[[UIMenuController sharedMenuController] setMenuItems:_menuItemsCache];
}


#pragma mark - Override Methods

/**
 * @return `YES`. This return value is required for this UILabel subclass to present the menu.
 */
- (BOOL)canBecomeFirstResponder
{
    return YES;
}

/**
 * @return `YES` for a given copy: action, `NO` otherwise. This method is queried for all system default menu actions.
 * This implementation limits the menu items to the single "Copy" action.
 */
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    return (action == @selector(copy:));
}


@end
