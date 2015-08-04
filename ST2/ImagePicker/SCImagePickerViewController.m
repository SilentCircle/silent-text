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
//  SCImagePickerViewController.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 9/30/13.
//

#import "SCImagePickerViewController.h"
#import "QBImagePickerController.h"
#import "OHActionSheet.h"

#import "AppDelegate.h"
#import "AppConstants.h"
#import "SilentTextStrings.h"
#import "STUser.h"
#import "SCloudObject.h"
#import "SCAssetInfo.h"

#import "NSDate+SCDate.h"
#import "NSNumber+Filesize.h"
#import "NSDictionary+SCDictionary.h"
#import "ALAsset+SCUtilities.h"
#import "UIImage+Thumbnail.h"

#import <libkern/OSAtomic.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>


@implementation SCImagePickerViewController
{
    id <SCImagePickerViewControllerDelegate> delegate;
    
    UIViewController *viewController;
    UIPopoverController* ipcPopController;
    UINavigationController *nvc;
 }

- (id)initWithViewController:(UIViewController*) aViewController  withDelegate:(id) aDelegate
{
	if ((self = [super init]))
	{
		delegate = aDelegate;
		viewController = aViewController;
     
    }
	return self;
}

- (void)pickMultiplePhotosFromRect:(CGRect)inRect inView:(UIView *)inView
{
    QBImagePickerController *imagePickerController = [[QBImagePickerController alloc] init];
    imagePickerController.delegate = self;
    imagePickerController.allowsMultipleSelection = YES;
 
    nvc = [[UINavigationController alloc] initWithRootViewController:imagePickerController];
    
    imagePickerController.title = NSLocalizedString(@"Photo Library", @"Image picker title");
    
    if (AppConstants.isIPhone)
    {
         [viewController presentViewController:nvc animated:YES completion:NULL];
    }
    else
    {
		ipcPopController =  [[UIPopoverController alloc] initWithContentViewController:nvc];
//		ipcPopController.popoverContentSize = CGSizeMake(400.0, 600.0);
		ipcPopController.delegate  = self;
        
		[ipcPopController presentPopoverFromRect:inRect
		                                  inView:inView
		                permittedArrowDirections:UIPopoverArrowDirectionAny
		                                animated:YES];
	}
}

- (void)queueAssetsForSending:(NSArray *)assets scale:(float)scale
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        for (ALAsset *asset in assets)
        {
			NSDictionary *assetInfo = [SCAssetInfo assetInfoForAsset:asset withScale:scale];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				if ([delegate respondsToSelector:@selector(scImagePickerViewController:didPickAssetWithInfo:)])
					[delegate scImagePickerViewController:self didPickAssetWithInfo:assetInfo];
			});
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
                                 
			[self closeDialog];
		});
    });
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UIPopoverControllerDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	if ([delegate respondsToSelector:@selector(scImagePickerViewController:didPickAssetWithInfo:)])
		[delegate scImagePickerViewController:self didPickAssetWithInfo:NULL];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Cleanup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)closeDialog
{
	NSAssert([NSThread isMainThread], @"MUST be invoked on main thread!");
	
	if ([delegate respondsToSelector:@selector(scImagePickerViewController:didPickAssetWithInfo:)])
		[delegate scImagePickerViewController:self didPickAssetWithInfo:NULL];
	
	[viewController dismissViewControllerAnimated:YES completion:NULL];
	
	if (AppConstants.isIPhone)
	{
		[nvc popViewControllerAnimated: YES];
	}
	else
	{
		if (ipcPopController.popoverVisible)
			[ipcPopController dismissPopoverAnimated:YES];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark QBImagePickerControllerDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController
{
    [self closeDialog];
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAssets:(NSArray *)assets
{
	long long totalPhotoSize = 0;
	long long otherSizes = 0;
	
    BOOL hasPhotos = NO;
    BOOL hasCroppedPhotos = NO;
    BOOL hasGIFs = NO;
	
	for (ALAsset *asset in assets)
	{
		NSString *assetType = [asset valueForProperty:ALAssetPropertyType];
		ALAssetRepresentation *rep = [asset defaultRepresentation];
		
		if ([assetType isEqualToString:ALAssetTypePhoto])
		{
			hasPhotos = YES;
			totalPhotoSize += rep.size;
			
			unsigned char header[4];
			[rep getBytes:header fromOffset:0 length:4 error:nil];
			
			if (memcmp(header, "GIF", 3) == 0)
				hasGIFs = YES;
			
			if (rep.metadata[@"AdjustmentXMP"])
				hasCroppedPhotos = YES;
		}
		else
		{
			otherSizes += rep.size;
		}
	}
	
	long long reducedSmall = totalPhotoSize * 0.25;
    long long reducedMedium = totalPhotoSize * 0.5;
	
	NSNumber * smallNumber  = [NSNumber numberWithLongLong:reducedSmall + otherSizes];
	NSNumber * mediumNumber = [NSNumber numberWithLongLong:reducedMedium + otherSizes];
    NSNumber * fullNumber   = [NSNumber numberWithLongLong:totalPhotoSize + otherSizes];
	
	NSString *small  = NSLocalizedString(@"Small", @"Image picker size option");
	NSString *medium = NSLocalizedString(@"Medium", @"Image picker size option");
	NSString *full   = NSLocalizedString(@"Full Size", @"Image picker size option");

	NSString *message = nil;
	NSArray *buttonTitles = nil;
	NSArray *buttonValues = nil;
	
	if (hasCroppedPhotos)
	{
		// Size calculation is not accurate for cropped photos
		
		message =  NSLocalizedString(@"You can reduce the message size by scaling images",
		                             @"Dialogue in image picker");
		
		buttonTitles = @[ small  , medium, full   ];
		buttonValues = @[ @(0.25), @(0.5), @(1.0) ];
	}
	else if (!hasPhotos || hasGIFs)
    {
		// Note: Do NOT make assumptions about foreign languages.
		// In other language, the number may need to go BEFORE the word "Upload".
		
		NSString *frmt = nil;
		
		if (assets.count == 1)
		{
			frmt = NSLocalizedString(@"Upload 1 file. Total size: %@.", @"Dialogue in image picker");
			message = [NSString stringWithFormat:frmt, [fullNumber fileSizeString]];
		}
		else
		{
			frmt = NSLocalizedString(@"Upload %lu files. Total size: %@.", @"Dialogue in image picker");
			message = [NSString stringWithFormat:frmt, (unsigned long)[assets count], [fullNumber fileSizeString]];
		}
		
		NSString *encryptAndSend = NSLocalizedString(@"Encrypt & Send", @"Image picker size option");
		
        buttonTitles = @[ encryptAndSend ];
		buttonValues = @[ @(1.0)         ];
    }
	else
	{
		NSString *frmt = NSLocalizedString(@"This message is %@. You can reduce the message size by scaling images.",
		                                   @"Dialogue in image picker");
		
		message = [NSString stringWithFormat:frmt, [fullNumber fileSizeString]];
		
		
		
		NSString *smallWithSize  = [NSString stringWithFormat:@"%@ (%@)", small,  [smallNumber  fileSizeString]];
		NSString *mediumWithSize = [NSString stringWithFormat:@"%@ (%@)", medium, [mediumNumber fileSizeString]];
		NSString *fullWithSize   = [NSString stringWithFormat:@"%@ (%@)", full,   [fullNumber   fileSizeString]];
		
		buttonTitles = @[ smallWithSize, mediumWithSize, fullWithSize ];
		buttonValues = @[ @(0.25)      , @(0.5),         @(1.0)       ];
	}
	
	NSAssert(buttonTitles.count == buttonValues.count, @"Oops");
    
		[OHActionSheet showFromVC:nvc
		                   inView:nvc.view
		                    title:message
		        cancelButtonTitle:NSLS_COMMON_CANCEL
		   destructiveButtonTitle:nil
		        otherButtonTitles:buttonTitles
		               completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
		{
			NSString *choiceTitle = [sheet buttonTitleAtIndex:buttonIndex];
			
			if ([choiceTitle isEqualToString:NSLS_COMMON_CANCEL])
			{
				[self closeDialog];
			}
			else
			{
				NSUInteger choiceIndex = [buttonTitles indexOfObject:choiceTitle];
				NSNumber *scale = [buttonValues objectAtIndex:choiceIndex];
				
				[self queueAssetsForSending:assets scale:scale.floatValue];
			}
		}];
//	}
}




@end
