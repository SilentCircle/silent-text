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
//  vCalendarViewController.h
//  ST2
//
//  Created by Vinnie Moscaritolo on 5/22/14.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

#import "SCloudObject.h"
#import "STDynamicHeightView.h"


@interface vCalendarViewController : UIViewController

- (id)initWithSCloud:(SCloudObject*)scloud;

@property (nonatomic, weak) id delegate;

@property (nonatomic, strong) IBOutlet STDynamicHeightView *containerView; // strong to support moving around

@property (nonatomic, weak) IBOutlet UILabel *summaryLabel;
@property (nonatomic, weak) IBOutlet UILabel *locationLabel;
@property (nonatomic, weak) IBOutlet UILabel *dateLabel;
@property (nonatomic, weak) IBOutlet UILabel *urlLabel;
@property (nonatomic, weak) IBOutlet UITextView *eventNoteView;

@property (nonatomic, weak) IBOutlet UIButton *importButton;
@property (nonatomic, weak) IBOutlet UIButton *previewButton;

- (IBAction)importButtonTapped:(id)sender;
- (IBAction)previewButtonTapped:(id)sender;

@end


@protocol vCalendarViewControllerDelegate <NSObject>
@optional

- (void)vCalendarViewController:(vCalendarViewController *)sender previewVCalender:(SCloudObject*)scloud;
- (void)vCalendarViewController:(vCalendarViewController *)sender needsHidePopoverAnimated:(BOOL)animated;
- (void)vCalendarViewController:(vCalendarViewController *)sender showMapForEvent:(NSString*)eventName
                                                                        atLocation:(CLLocation*)location
                                                                            andTime:(NSDate *)date;

- (void)vCalendarViewController:(vCalendarViewController *)sender showURLForEvent:(NSURL*)eventURL;
@end
