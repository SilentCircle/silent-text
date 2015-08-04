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
//  SCRecoveryKeyManager.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 8/18/14.
//

#import <SCCrypto/SCcrypto.h> 

#import "SCRecoveryKeyViewController.h"
#import "AppConstants.h"
#import "qrencode.h"
#import "SCPasscodeManager.h"
#import "STDynamicHeightView.h"
#import "STLogging.h"


// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
static const int ddLogLevel = LOG_LEVEL_INFO; // VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

@interface ActivitySilentText : UIActivity
@end


@implementation ActivitySilentText


- (NSString *)activityType {
    return @"silenttext";
}

- (NSString *)activityTitle {
    return @"Silent Text";
}

- (UIImage *)activityImage {
    
    return [UIImage imageNamed:@"AppIcon76x76.png"];
}



- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    
    for (UIActivityItemProvider *item in activityItems)
    {
        if ([item isKindOfClass:[UIImage class]])
        {
            // required the Siren object
            return YES;
        }
        
    }

    return NO;
}


- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    for (id item in activityItems) {
        if ([item isKindOfClass:[UIImage class]])
        {
            
//            self.shareImage  = item;
        }

    }


}


- (UIViewController *)activityViewController {
    
    
    return NULL;
    
    
}

- (void)performActivity {
    
    [self activityDidFinish:NO];
    
}


-(void)documentInteractionController:(UIDocumentInteractionController *)controller
       willBeginSendingToApplication:(NSString *)application
{
  
    [self activityDidFinish:YES];
}


@end


#define PKDF_HASH_BYTES 16

@interface SCRecoveryKeyViewController()

@property (nonatomic, weak) IBOutlet STDynamicHeightView *containerView;
@property (nonatomic, weak) IBOutlet UILabel                 *keyLabel;

@property (nonatomic, strong   )            NSString        *keyString;
@property (nonatomic, strong   )            NSDictionary    *recoveryKeyDict;

@end

@implementation SCRecoveryKeyViewController
@synthesize containerView = containerView;


- (id)initWithRecoveryKeyString:(NSString*)inKeyString
                recoveryKeyDict:(NSDictionary*)inRecoveryKeyDict
{
	if ((self = [super initWithNibName:@"SCRecoveryKeyViewController" bundle:nil]))
	{
		_keyString = inKeyString;
        _recoveryKeyDict = inRecoveryKeyDict;
        
        
	}
	return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.navigationItem.title = NSLocalizedString(@"Recovery Key", @"Recovery Key");
	
    
    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                  target:self
                                                  action:@selector(actionButtonTapped:)];
    
     if (AppConstants.isIPhone)
    {
        self.navigationItem.leftBarButtonItem =
	    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
	                                                  target:self
	                                                  action:@selector(doneButtonTapped:)];
   }
	self.edgesForExtendedLayout=UIRectEdgeNone;
	self.extendedLayoutIncludesOpaqueBars=NO;
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
     
   _keyLabel.text = [SCPasscodeManager locatorCodeFromRecoveryKeyDict:_recoveryKeyDict];
    
    NSString* codeString = [SCPasscodeManager recoveryKeyCodeFromPassCode:_keyString
                                                          recoveryKeyDict:_recoveryKeyDict];
    
    UIImage *image = [self recoveryKeyQRCode:codeString withDimension:_qrImage.frame.size.width];
    
    //set the image
    [_qrImage setImage: image];
}

/**
 * This method is queried * by our own code * when creating popover controllers.
 * It is conceptually similar to the deprecated contentSizeForViewInPopover method.
 **/
- (CGSize)preferredPopoverContentSize
{
	DDLogAutoTrace();
	
	// If this method is queried before we've loaded the view, then containerView will be nil.
	// So we make sure the view is loaded first.
	(void)[self view];
    
    CGSize result = containerView.frame.size;
    result.height = containerView.intrinsicContentSize.height;
    return result;
}

- (void)doneButtonTapped:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}


- (void)actionButtonTapped:(id)sender
{
    
    
    
    UIGraphicsBeginImageContextWithOptions(containerView.bounds.size, NO, 0.0);
    [containerView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    
    NSArray *objectsToShare = @[
                                [NSString stringWithFormat:  @"Silent Text recovery key: %@", _keyLabel.text],
                                viewImage];
    
 //   ActivitySilentText *silentTextActivity = [[ActivitySilentText alloc] init];

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:objectsToShare
                                                                             applicationActivities:  nil /* @[silentTextActivity] */];
 
    activityVC.excludedActivityTypes = @[UIActivityTypeAssignToContact,
                                         UIActivityTypePostToFacebook,
                                         UIActivityTypePostToTwitter,
                                         UIActivityTypePostToWeibo,
                                         UIActivityTypeAddToReadingList,
                                         UIActivityTypePostToVimeo,
                                         UIActivityTypePostToTencentWeibo,
                                         ];
    
    [self presentViewController:activityVC
                       animated:YES
                     completion:nil];
    
}


void freeRawData(void *info, const void *data, size_t size) {
    free((unsigned char *)data);
}

 -(UIImage*)recoveryKeyQRCode:(NSString*) dataString withDimension:(int)imageWidth
{
    UIImage *image = NULL;
    
//    CFUUIDRef ref = CFUUIDCreateFromString(NULL, (__bridge CFStringRef)(uuid));
//    CFUUIDBytes bytes = CFUUIDGetUUIDBytes (ref);//ISSUE
//     CFRelease(ref);
//    
//    
    QRcode *resultCode = QRcode_encodeString([dataString UTF8String], 0, QR_ECLEVEL_L, QR_MODE_8, 1);
    
    unsigned char *pixels = (*resultCode).data;
    int width = (*resultCode).width;
    int len = width * width;
    
    if (imageWidth < width)
        imageWidth = width;
    
    // Set bit-fiddling variables
    int bytesPerPixel = 4;
    int bitsPerPixel = 8 * bytesPerPixel;
    int bytesPerLine = bytesPerPixel * imageWidth;
    int rawDataSize = bytesPerLine * imageWidth;
    
    int pixelPerDot = imageWidth / width;
    int offset = (int)((imageWidth - pixelPerDot * width) / 2);
    
    // Allocate raw image buffer
    unsigned char *rawData = (unsigned char*)malloc(rawDataSize);
    memset(rawData, 0xFF, rawDataSize);
    
    // Fill raw image buffer with image data from QR code matrix
    int i;
    for (i = 0; i < len; i++) {
        char intensity = (pixels[i] & 1) ? 0 : 0xFF;
        
        int y = i / width;
        int x = i - (y * width);
        
        int startX = pixelPerDot * x * bytesPerPixel + (bytesPerPixel * offset);
        int startY = pixelPerDot * y + offset;
        int endX = startX + pixelPerDot * bytesPerPixel;
        int endY = startY + pixelPerDot;
        
        int my;
        for (my = startY; my < endY; my++) {
            int mx;
            for (mx = startX; mx < endX; mx += bytesPerPixel) {
                rawData[bytesPerLine * my + mx    ] = intensity;    //red
                rawData[bytesPerLine * my + mx + 1] = intensity;    //green
                rawData[bytesPerLine * my + mx + 2] = intensity;    //blue
                rawData[bytesPerLine * my + mx + 3] = 255;          //alpha
            }
        }
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, rawData, rawDataSize, (CGDataProviderReleaseDataCallback)&freeRawData);
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    CGImageRef imageRef = CGImageCreate(imageWidth, imageWidth, 8, bitsPerPixel, bytesPerLine, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    
    UIImage *quickResponseImage = [UIImage imageWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    CGColorSpaceRelease(colorSpaceRef);
    CGDataProviderRelease(provider);
    QRcode_free(resultCode);
    
    return quickResponseImage;
    return image;
}

@end
