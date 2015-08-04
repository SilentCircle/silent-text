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
//
//  vCardViewController.h
//  ST2
//
//  Created by Vinnie Moscaritolo on 10/21/13.
//

#import <UIKit/UIKit.h>
#import "SCloudObject.h"

@protocol vCardViewControllerDelegate;


@interface vCardViewController : UIViewController

- (id)initWithSCloud:(SCloudObject *)scloud;

@property (nonatomic, weak) id delegate;

@property (nonatomic, strong) IBOutlet UIView *containerView; // strong to support moving around

@property (nonatomic, weak) IBOutlet UIImageView *userImageView;
@property (nonatomic, weak) IBOutlet UILabel *displayNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *organizationLabel;
@property (nonatomic, weak) IBOutlet UILabel *userNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *spPhone;

@property (nonatomic, weak) IBOutlet UIButton *importSCButton;
@property (nonatomic, weak) IBOutlet UIButton *importABButton;
@property (nonatomic, weak) IBOutlet UIButton *previewButton;


- (IBAction)importSCButtonTapped:(id)sender;
- (IBAction)importABButtonTapped:(id)sender;

@end


#pragma mark -


@protocol vCardViewControllerDelegate <NSObject>
@optional

- (void)vCardViewController:(vCardViewController *)sender previewVCard:(SCloudObject*)scloud;
- (void)vCardViewController:(vCardViewController *)sender needsHidePopoverAnimated:(BOOL)animated;

@end
