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
//  SCTPinLockScreenVC.m
//  ST2
//
//  Created by Eric Turner on 7/1/14.
//


#import "SCTPinLockScreenVC.h"
#import "SCTShapeButton.h"
#import "SCTPinLockKeypad.h"
#import "SCTPinLockScreenConstants.h"
#import "UIImage+ImageEffects.h"
#import "UIImage+ETAdditions.h"
#import "UIColor+FlatColors.h"

@interface SCTPinLockScreenVC () <SCTPinLockKeypadDelegate>
@property (strong, nonatomic) UIImage *bgImg;
@property (weak, nonatomic) IBOutlet UIImageView *bgImgView;
@property (weak, nonatomic) IBOutlet SCTPinLockKeypad *lockPadView;
@end


@implementation SCTPinLockScreenVC


#pragma mark - Initialization

/**
 * Invoke when app resigns active to background.
 *
 * @return A configured MTSLockScreenVC instance.
 */
- (instancetype)init {
    UIStoryboard *sbLock = [UIStoryboard storyboardWithName: @"SCTPinLockScreenVC" bundle: nil];
    self = [sbLock instantiateViewControllerWithIdentifier: NSStringFromClass( [self class] )];
    if (!self) { return  nil; }
    self.bgImg = [self imageFromScreen];
    self.bgImgView.image = _bgImg;
    
    return self;
}

/**
 *
 */
- (UIImage *)imageFromScreen {
    UIImage *screenImage = [UIImage imageFromScreen];       // UIImage category method
    UIImage *blurredImage = [screenImage applyLightEffect]; // UIImage category method
    return blurredImage;
}


#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    if (nil == _bgImgView.image) {
        self.bgImgView.image = (_bgImg) ?: [self imageFromScreen];
    }
}


#pragma mark - MTSPinLockPadViewDelegate

- (void)lockPadSelectedButtonTitles:(NSArray *)arrTitles {
    BOOL pinVerified = NO;        
    if ([_delegate respondsToSelector: @selector(authenticateWithLockScreenEntries:)]) {
        pinVerified = [_delegate authenticateWithLockScreenEntries: arrTitles];
    }
    // User entry is INVALID: re-init the circleButtons array and call the shake animation
    if (NO == pinVerified) {
        [_lockPadView animateInvalidEntryResponse];
    }
}

- (void)lockPadSelectedLogout {
    if ([_delegate respondsToSelector: @selector(lockScreenSelectedLogout)]) {
        [_delegate lockScreenSelectedLogout];
    }
}


@end
