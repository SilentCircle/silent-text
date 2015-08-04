/*
Copyright (C) 2013-2015, Silent Circle, LLC. All rights reserved.

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
#import <AddressBookUI/AddressBookUI.h>
#import "EditUserInfoViewController.h"
#import "STDynamicHeightView.h"
#import <MapKit/MapKit.h>

@protocol UserInfoViewControllerDelegate;

@interface UserInfoViewController : UIViewController <MKMapViewDelegate,
                                                      ABPeoplePickerNavigationControllerDelegate,
                                                      EditUserInfoViewControllerDelegate>

- (id)initWithProperNib;


@property (nonatomic, weak) id delegate;

@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSString *userJID; // use if userID not available

@property (nonatomic, assign) BOOL isInPopover;
@property (nonatomic, assign) BOOL isModal;

// ContainerView stuff

@property (nonatomic, strong) IBOutlet STDynamicHeightView *containerView; // strong to support moving around

@property (nonatomic, weak) IBOutlet UIImageView *userImageView;
@property (nonatomic, weak) IBOutlet UILabel *displayNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *organizationLabel;
@property (nonatomic, weak) IBOutlet UILabel *networkLabel;

@property (nonatomic, weak) IBOutlet UILabel *userNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *phoneLabel;
@property (nonatomic, weak) IBOutlet UILabel *expireDateLabel;

@property (nonatomic, weak) IBOutlet UIButton *textButton;
@property (nonatomic, weak) IBOutlet UIButton *callButton;

@property (nonatomic, weak) IBOutlet UIView *horizontalRule;

@property (nonatomic, weak) IBOutlet UITextView *userNotes;

@property (nonatomic, weak) IBOutlet UIButton *addressBookButton;
@property (nonatomic, weak) IBOutlet UILabel *addressBookTip;

@property (nonatomic, weak) IBOutlet UIButton *keyInfo;

@property (nonatomic, weak) IBOutlet UIButton *checkButton; // refresh button
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activity;

@property (nonatomic, weak) IBOutlet UIButton *keyButton;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *keyActivity;

@property (nonatomic, weak) IBOutlet MKMapView *mapView;
@property (nonatomic, weak) IBOutlet UIButton *mapViewPageCurlButton;

@property (nonatomic, weak) IBOutlet UIButton *subscribeButton;

// DebugView stuff

@property (nonatomic, strong) IBOutlet UIView *debugView; // strong to support moving around

@property (nonatomic, weak) IBOutlet UITextView *debugNotes;

// Actions

- (IBAction)checkButtonTapped:(id)sender;
- (IBAction)keyButtonTapped:(id)sender;

- (IBAction)keyInfoTapped:(id)sender;

- (IBAction)textButtonTapped:(id)sender;
- (IBAction)callButtonTapped:(id)sender;
- (IBAction)subscribeButtonTapped:(id)sender;

- (IBAction)addressBookButtonTapped:(id)sender;

- (IBAction)showMapOptions:(id)sender;

// Other

- (CGSize)preferredPopoverContentSize;


@end

@protocol UserInfoViewControllerDelegate <NSObject>
@optional

- (void)userInfoViewController:(UserInfoViewController *)sender needsDismissPopoverAnimated:(BOOL)animated;

/**
 * These methods are used on iPad, in MessagesViewController:
 *
 * - Tap user avatar to bring up UserInfoViewController in a popover
 * - Tap edit button to bring up EditUserInfoViewController
 * - Tap edit avatar button, and select "choose photo"
 *
 * The UIImagePickerController is a subclass of UINavigationController.
 * And so we can't push it onto our existing navController.
 * Instead, we need to set it as the "root" contentViewController of the popover.
 * And then, when we're done with the image picker,
 * we need to restore our own navController as the contentViewController of the popover.
**/

- (void)userInfoViewController:(UserInfoViewController *)sender
          needsPushImagePicker:(UIImagePickerController *)imagePicker;

- (void)userInfoViewController:(UserInfoViewController *)sender
           needsPopImagePicker:(UIImagePickerController *)imagePicker;

/**
 * These methods are used on iPad, in MessagesViewController:
 *
 * - Tap user avatar to bring up UserInfoViewController in a popover
 * - Tap edit button to bring up EditUserInfoViewController
 * - Tap edit avatar button, and select "choose photo"
 * - Select a photo
 *
 * At this point the MoveAndScaleImageViewController needs to come up full screen.
 * And thus the popover needs to get temporarily dismissed until the MoveAndScaleImageViewController is dismissed.
**/

- (void)userInfoViewController:(UserInfoViewController *)sender
      needsHidePopoverAnimated:(BOOL)animated;

- (void)userInfoViewController:(UserInfoViewController *)sender
      needsShowPopoverAnimated:(BOOL)animated;

@end

