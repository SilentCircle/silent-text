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
//  SCCameraView.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 9/26/13.
//

#import <CoreLocation/CoreLocation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "SCCameraViewController.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "SilentTextStrings.h"
#import "STUser.h"
#import "SCloudObject.h"
#import "SCDateFormatter.h"
#import "SCAssetInfo.h"

#import "OHActionSheet.h"

#import "ALAsset+SCUtilities.h"
#import "NSDate+SCDate.h"
#import "NSDictionary+SCDictionary.h"
#import "UIImage+Thumbnail.h"

@interface SCCameraViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@end

@implementation SCCameraViewController

@synthesize delegate = delegate;
@synthesize location = location;

- (id)initWithDelegate:(id)aDelegate
{
	if ((self = [super init]))
	{
		delegate = aDelegate;
		location = NULL;
		
        self.view.translatesAutoresizingMaskIntoConstraints = YES;
	}
	return self;
}

- (void)pickNewPhoto
{
 	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.delegate      = self;
	picker.sourceType    = UIImagePickerControllerSourceTypeCamera;
	picker.mediaTypes    = [UIImagePickerController availableMediaTypesForSourceType:picker.sourceType];
	picker.allowsEditing = NO;
	picker.videoQuality  = UIImagePickerControllerQualityTypeHigh;
	
	[self presentViewController:picker animated:YES completion:NULL];
}

#pragma mark - UIImagePickerController delegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	[self dismissViewControllerAnimated:YES  completion:^{
	
		[self.navigationController popViewControllerAnimated:YES];
	}];
}




-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	
	NSString            *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
	//   NSURL               *assetURL = [info objectForKey:UIImagePickerControllerReferenceURL];

    //ET 10/16/14 OHActionSheet update
    //
    // Since we don't have access to the picker view subviews to find the button from which
    // to present the actionSheet popover (iPad), we create a rect in the bottom right corner.
    // Note that after presented, a rotation will re-present the actionSheet popover in the
    // wrong place.
    // When presented on an iPhone, OHActionSheet presents an actionSheet from bottom.
    CGRect frame = picker.view.frame;
    CGFloat side = 144.0f;
    CGFloat heightMargin = 64.0f;
    frame.origin.x = frame.size.width - side;
    frame.size.width = side;
    frame.origin.y = frame.size.height - heightMargin;
    frame.size.height = heightMargin;

	if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage))
	{
		NSString	*smallStr = NSLocalizedString(@"Small", @"Small"),
					*mediumStr = NSLocalizedString(@"Medium", @"Medium"),
					*fullStr = NSLocalizedString(@"Full Size", @"Full Size");
		
        NSArray* otherButtonsTitles =  @[ smallStr, mediumStr, fullStr ];
		
		NSString *title = NSLocalizedString(
		  @"You can reduce the message size by scaling the image to one of the sizes below.",
		  @"Camera dialogue");
		
        //ET 10/16/14 OHActionSheet update
		[OHActionSheet showFromRect:frame
		                   sourceVC:picker
		                     inView:picker.view
		             arrowDirection:UIPopoverArrowDirectionAny
		                      title:title
		          cancelButtonTitle:NSLS_COMMON_CANCEL
		     destructiveButtonTitle:NULL
		          otherButtonTitles:otherButtonsTitles
		                 completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
		{
			NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
			
			if ([choice isEqualToString:smallStr])
			{
				[self queueMediaForSending:info scale:0.25];
			}
			else  if ([choice isEqualToString:mediumStr])
			{
				[self queueMediaForSending:info scale:0.5];
			}
			else  if ([choice isEqualToString:fullStr])
			{
				[self queueMediaForSending:info scale:1.0];
			}
			else
			{
				[self dismissViewControllerAnimated:YES  completion:^{
					
					[self.navigationController popViewControllerAnimated:YES];
				}];
			}
		}];
    
	}
	else
	{
        //ET 10/16/14 OHActionSheet update
        [OHActionSheet showFromRect:frame 
                           sourceVC:picker 
                             inView:picker.view
                     arrowDirection:UIPopoverArrowDirectionAny
                              title: nil
                  cancelButtonTitle: NSLS_COMMON_CANCEL
             destructiveButtonTitle: NULL
                  otherButtonTitles: @[NSLocalizedString(@"Encrypt & Send", @"Encrypt & Send")]
                         completion: ^(OHActionSheet *sheet, NSInteger buttonIndex)
		{
			if (buttonIndex == sheet.cancelButtonIndex)
			{
				[self dismissViewControllerAnimated:YES  completion:^{
					
					[self.navigationController popViewControllerAnimated:YES];
				}];
			}
			else if (buttonIndex == 0)
			{
				[self queueMediaForSending:info scale:0];
			}
		}];
	}
}

#pragma mark - post processing

- (void)queueMediaForSending:(NSDictionary *)info scale:(float)scale
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		NSDictionary *assetInfo = [SCAssetInfo assetInfoForImagePickerInfo:info withScale:scale location:self.location];
		
		dispatch_async(dispatch_get_main_queue(), ^{
		
			if ([delegate respondsToSelector:@selector(scCameraViewController:didPickAssetWithInfo:)])
				[delegate scCameraViewController:self didPickAssetWithInfo:assetInfo];
			
			[self dismissViewControllerAnimated:YES  completion:^{
				
				[self.navigationController popViewControllerAnimated:YES];
			}];
		});
	});
}

@end
