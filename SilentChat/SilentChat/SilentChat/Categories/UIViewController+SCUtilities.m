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
//  UIViewController+SCUtilities.m
//  SilentText
//

#import "App.h"
#import "UIViewController+SCUtilities.h"
#import "NotiView.h"
#import "NSTimer+Blocks.h"

@implementation UIViewController (SCUtilities)



- (CGFloat) viewWidth {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGFloat width = self.view.frame.size.width;
    if (orientation == UIInterfaceOrientationLandscapeRight || orientation == UIInterfaceOrientationLandscapeLeft) {
        width = self.view.frame.size.height;
    }
    return width;
}

- (void)displayMessageBannerFrom:(NSString*)from  message:(NSString*) message withIcon:(UIImage*)image
{

    CGFloat offset = [UIApplication sharedApplication].statusBarFrame.size.height;
    
    NotiView *nv = [[NotiView alloc] initWithTitle:from
                                            detail:message
                                              icon:image];
    [nv setWidth:320.0];
    
    [ nv setColor:[UIColor  darkGrayColor]];
    //   [nv setColor:[self randomColor]];
    
    CGRect f = nv.frame;
    f.origin.x = [self viewWidth] - f.size.width;
    f.origin.y = -f.size.height;
    nv.frame = f;
    
    [App.sharedApp.window addSubview:nv];
    
    [UIView animateWithDuration:0.4 animations:^{
        nv.frame = CGRectOffset(nv.frame, 0.0, f.size.height+offset);
    } completion:^(BOOL finished) {
        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:NO block:^(NSTimer *timer) {
            [UIView animateWithDuration:0.4 animations:^{
                nv.frame = CGRectOffset(nv.frame, f.size.width+offset, 0.0);
            } completion:^(BOOL finished) {
                [nv removeFromSuperview];
            }];
        }];
    }];
    
}

@end
