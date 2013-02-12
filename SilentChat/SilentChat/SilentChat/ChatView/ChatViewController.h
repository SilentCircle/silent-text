/*
Copyright © 2012-2013, Silent Circle, LLC.  All rights reserved.

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
//  ChatViewController.h
//  SilentChat
//

#import <UIKit/UIKit.h>
#import "XMPPStream.h"
#import "STBubbleTableViewCell.h"
#import "HPGrowingTextView.h"
//#import "WEPopoverController.h"
//#import "ChatOptionsViewDelegate.h"
#import "ChatOptionsViewDelegate.h"
#import "ChatOptionsViewControllerDelegate.h"
#import "STAudioView.h"
#import "ConversationManager.h"
#import "STMediaController.h"
#import "ChatViewRow.h"
#import "STFwdViewController.h"
#import <MapKit/MapKit.h>


@protocol XMPPUser;

@class Conversation;
@class MKMapView;

@interface ChatViewController : UIViewController 

<UITableViewDelegate,
UITableViewDataSource,
UITextFieldDelegate,
UIScrollViewDelegate,
UIActionSheetDelegate,
UIGestureRecognizerDelegate,
XMPPStreamDelegate,
ChatViewRowDelegate,
HPGrowingTextViewDelegate,
//WEPopoverControllerDelegate,
ChatOptionsViewDelegate,
ChatOptionsViewControllerDelegate,
ConversationManagerDelegate,
STMediaDelegate,
STFwdViewDelegate,
STAudioViewDelegate>

//@property (nonatomic, weak) IBOutlet UINavigationItem* navigationItem;

@property (weak, nonatomic) IBOutlet UIView *backgroundView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView  *headerView;

@property (weak, nonatomic) IBOutlet UIView *textEntryView;
@property (weak, nonatomic) IBOutlet UIView *entryContainerView;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;
@property (weak, nonatomic) IBOutlet UIButton *optionsButton;
//@property (weak, nonatomic) IBOutlet UIView *userEntryView;
//@property (weak, nonatomic) IBOutlet UITextField *usernameField;

//@property (weak, nonatomic) IBOutlet UIButton *contactButton;
//@property (weak, nonatomic) IBOutlet UIButton *callButton;

@property (weak, nonatomic) IBOutlet UILabel *headerLine;
//@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@property (strong, nonatomic) XMPPStream *xmppStream;
@property (strong, nonatomic) Conversation *conversation;

#define     kSwipeDown  (@selector(swipeDown:))
- (IBAction) swipeDown: (UISwipeGestureRecognizer *) gestureRecognizer;

#define     kGearAction  (@selector(gearAction:))
- (IBAction) gearAction: (UIBarButtonItem *) gearButton;

#define     kContactAction  (@selector(contactAction:))
- (IBAction) contactAction: (UIButton *) sender;

#define     kCameraAction  (@selector(cameraAction:))
- (IBAction) cameraAction: (UIButton *) sender;

#define     kPhoneAction  (@selector(phoneAction:))
- (IBAction) phoneAction: (UIButton *) sender;

@property (weak, nonatomic) IBOutlet ChatOptionsView *cov;

@property (nonatomic, weak) IBOutlet STAudioView* aiv;

- (void) calculateBurnTimes;

@end
