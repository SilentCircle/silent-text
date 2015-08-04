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
//  SCTTextCopyLabel.h
//  ST2
//
//  Created by Eric Turner on 7/11/14.
//

#import <UIKit/UIKit.h>

@class SCTTextCopyLabel;

/**
 * The SCTCopyLabelDelegate protocol defines messages sent to a copy label delegate.
 *
 * The copyLabelShouldPresentCopyMenu: callback enables the delegate to return`YES` to display the copy menu, or
 * `NO` to not display the copy menu for a longPress user event. This delegate callback may be used in conjuction with
 * the target/action properties to enable a target instance to take some action before allowing or disallowing the
 * copy label to display the copy menu.
 *
 * An example is ConversationDetailsVC: the conversation details view controller sets itself as the delegate of its
 * lblSASPhrase label. If the SAS phrase is not available for the conversation the conversations details view
 * controller returns `NO` to the callback, else `YES` to enable the user to copy the phrase to the pasteboard. In this
 * example, the target/action is not employed, as no action needs to take place other than the decision to disply the
 * copy menu or not.
 *
 * Note: If there is a non-nil target/action pair, the longPress gesture handling will execute the action. Afterward,
 * if there is a non-nil delegate, the copy menu will be displayed conditional on the callback return value. Otherwise,
 * if there is no delegate, the target/action handling is executed instead of the default copy menu handling.
 *
 */
@protocol SCTCopyLabelDelegate <NSObject>
@required
- (BOOL)copyLabelShouldPresentCopyMenu:(SCTTextCopyLabel *)copyLabel;
@end

/**
 * This is a lightweight label control which encapsulates presenting to the user a Copy menu for copying the text 
 * property string to the system pasteboard.
 *
 * This is a drop-in replacement for a UILabel in Interface Builder. The controller class need not import this class
 * header or implement anything to get the default behavior. A UIMenuController is presented with a single "Copy"
 * menu item.
 *
 * Note that the original menu items of the shared UIMenuController singleton are cached. After the menu is presented
 * in the label superview, the private UIMenuControllerWillHideMenuNotification notification handler restores the 
 * singleton menu items, if any.
 *
 * This class implements a handler for a longPress gesture recognizer. To implement alternative behavior for a 
 * longPress event, set both the target and action properties. 
 *
 * ## Important
 *
 * Note that self is sent as the object argument to the `action` selector, which means that the action selector must be
 * a method with a single parameter of a type UILabel, this sublass, or id. 
 * For example:
 * - (void)doSomethingWithLabel:(UILabel *)lbl
 *
 * The action for the longPress will be either the default copy behavior OR an alternative, implemented by the action
 * method in the target instance. 
 * 
 * For example, in a view controller, the label text could refer to an object having a number of properties. The 
 * alternative behavior might be to format text describing the object properties and then insert the text as the body 
 * of an email in an MFMailComposeViewController. So instead of the default behavior of the label.text being copied to
 * the system pasteboard, the desired alternative would be implemented in the action method.
 *
 */
@interface SCTTextCopyLabel : UILabel

@property (nonatomic, weak) IBOutlet id<SCTCopyLabelDelegate> delegate;
@property (nonatomic, weak) IBOutlet id target;
@property (nonatomic) SEL action;

@end
