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
//  STMediaController
//  SilentText
//

#import "App.h"
#import "XMPPJID.h"
 #import "STMediaController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import "UIImage+Thumbnail.h"
#import "MBProgressHUD.h"
#import "NSDate+SCDate.h"
#import "MZActionSheet.h"
#import "SCloudObject.h"
#import "SCloudManager.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "ALAsset+SCUtilities.h"
#import <ImageIO/ImageIO.h>

@interface STMediaController ()


@property (strong,  nonatomic) id<STMediaDelegate> delegate;

@property (nonatomic)           BOOL            newMedia;
@property (nonatomic, strong)   MBProgressHUD    *HUD;

@end

@implementation STMediaController
 

@synthesize delegate = _delegate;
@synthesize newMedia = _newMedia;


const CGSize   kthumbNailSize  =  {150.f, 150.f};

- (id)initWithDelegate:(id)aDelegate
{
      
	if ((self = [super init]))
	{
		self.delegate = aDelegate;
        self.location = NULL;
         
    }
	return self;
}

-(void) continuePickerProcessing: (UIImagePickerController *)picker
                       thumbnail:(UIImage*)thumbnail
                            data:(NSData*)data
                            info:(NSDictionary *)info
{
    __block SCloudObject    *scloud     = NULL;
    __block NSError         *error      = NULL;
    __block NSData          *theData    = data;
    __block NSDictionary    *theInfo  = info;
    
    NSString *mediaType = [info objectForKey:kSCloudMetaData_MediaType];
    
    if(self.location)
    {
        NSMutableDictionary* newInfo = [NSMutableDictionary dictionaryWithDictionary:info];
        
        CLLocationDegrees exifLatitude  = _location.coordinate.latitude;
        CLLocationDegrees exifLongitude = _location.coordinate.longitude;
        
        NSString *latRef;
        NSString *lngRef;
        if (exifLatitude < 0.0) {
            exifLatitude = exifLatitude * -1.0f;
            latRef = @"S";
        } else {
            latRef = @"N";
        }
        
        if (exifLongitude < 0.0) {
            exifLongitude = exifLongitude * -1.0f;
            lngRef = @"W";
        } else {
            lngRef = @"E";
        }
        
        NSMutableDictionary *locDict = [[NSMutableDictionary alloc] init];
        if ([newInfo objectForKey:(NSString*)kCGImagePropertyGPSDictionary]) {
            [locDict addEntriesFromDictionary:[newInfo objectForKey:(NSString*)kCGImagePropertyGPSDictionary]];
        }
    
        [locDict setObject:[_location.timestamp ExifString] forKey:(NSString*)kCGImagePropertyGPSTimeStamp];
        [locDict setObject:latRef forKey:(NSString*)kCGImagePropertyGPSLatitudeRef];
        [locDict setObject:[NSNumber numberWithFloat:exifLatitude] forKey:(NSString*)kCGImagePropertyGPSLatitude];
        [locDict setObject:lngRef forKey:(NSString*)kCGImagePropertyGPSLongitudeRef];
        [locDict setObject:[NSNumber numberWithFloat:exifLongitude] forKey:(NSString*)kCGImagePropertyGPSLongitude];
        [locDict setObject:[NSNumber numberWithFloat:_location.horizontalAccuracy] forKey:(NSString*)kCGImagePropertyGPSDOP];
        [locDict setObject:[NSNumber numberWithFloat:_location.altitude] forKey:(NSString*)kCGImagePropertyGPSAltitude];
        
        [newInfo setObject:locDict forKey:(NSString*)kCGImagePropertyGPSDictionary];
        theInfo = newInfo;
        
        thumbnail = [thumbnail imageWithBadgeOverlay:[UIImage imageNamed:@"mapwhite.png"] text:NULL textColor:[UIColor whiteColor] ];

    }
    
    scloud =  [[SCloudObject alloc] initWithDelegate:self
                                                data:theData
                                            metaData:theInfo
                                           mediaType:mediaType
                                       contextString:App.sharedApp.currentJID.bare ];
    scloud.thumbnail = thumbnail;
         
    if(scloud)
    {
        NSString * mediaTypeString = NSLS_COMMON_DOCUMENT;
        
        if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeImage))
        {
            mediaTypeString = NSLS_COMMON_IMAGE;
        }
        else if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeMovie))
        {
            mediaTypeString = NSLS_COMMON_MOVIE;
        }
        else if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeAudio))
        {
            mediaTypeString = NSLS_COMMON_AUDIO;
        }

        
        _HUD = [[MBProgressHUD alloc] initWithView:picker.view];
        [picker.view addSubview:_HUD];
        _HUD.mode = MBProgressHUDModeAnnularDeterminate;
        _HUD.labelText = [NSString stringWithFormat:NSLS_COMMON_PREPARING, mediaTypeString];
 
        [_HUD showAnimated:YES whileExecutingBlock:^{
        
           if(theData && theInfo); // force to retain data and info
            
             [scloud saveToCacheWithError:&error];
        } completionBlock:^{
            [_HUD removeFromSuperview];
            
            [self dismissModalViewControllerAnimated:YES];
            [self.navigationController popViewControllerAnimated:YES];
            
            if(error)
            {
                scloud = NULL;
            }
            else
            {
                [self.delegate didFinishPickingMediaWithScloud: scloud];
            }
        }];
    }
    else
    {
        [self dismissModalViewControllerAnimated:YES];
        [self.navigationController popViewControllerAnimated:YES];
        scloud = NULL;
    }
}



-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    
    NSString            *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
 //   NSURL               *assetURL = [info objectForKey:UIImagePickerControllerReferenceURL];

    MZActionSheet       *sheet;
    
    if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeImage))
    {
        sheet   = [[MZActionSheet alloc] initWithTitle:@"You can reduce the message size by scaling the image to one of the sizes below."
                                              delegate:nil
                                     cancelButtonTitle:@"Cancel"
                                destructiveButtonTitle:nil
                                     otherButtonTitles:@"Small", @"Medium",@"Full Size",  nil];
    	
        [sheet setActionBlock: ^(NSInteger buttonPressed) {
            
            switch(buttonPressed)
            {
                case 0:
                    [self mediaIsApprovedForSending:picker withInfo:info scale:.25] ;
                    break;
                    
                case   1:
                    [self mediaIsApprovedForSending:picker withInfo:info scale:.5] ;
                    break;
                    
                case 2:
                    [self mediaIsApprovedForSending:picker withInfo:info scale:1.0] ;
                    break;
                    
                default:
                    [self dismissModalViewControllerAnimated:YES];
                    [self.navigationController popViewControllerAnimated:YES];
            }
        }];
        
    }
    else
    {
        sheet   = [[MZActionSheet alloc] initWithTitle:nil delegate:nil
                                     cancelButtonTitle:@"Cancel"
                                destructiveButtonTitle:nil
                                     otherButtonTitles:@"Encrypt & Send", nil];
        [sheet setActionBlock: ^(NSInteger buttonPressed) {
            if (buttonPressed == 0) {
                [self mediaIsApprovedForSending:picker withInfo:info scale:0] ;
            }
            else {
                [self dismissModalViewControllerAnimated:YES];
                [self.navigationController popViewControllerAnimated:YES];
            }
        }];
        
    }
	
	[sheet showInView:self.view];
}

-(void)mediaIsApprovedForSending:(UIImagePickerController *)picker withInfo:(NSDictionary *)info scale:(float)scale
{
    NSString            *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    NSURL               *assetURL = [info objectForKey:UIImagePickerControllerReferenceURL];
    __block  NSError    *error;
    
    if(assetURL)
    {
        
        dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            NSAssert(![NSThread isMainThread], @"can't be called on the main thread due to ALAssetLibrary limitations");
            
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library assetForURL:assetURL
                 resultBlock:^(ALAsset *asset)  {
                     NSMutableDictionary *metaDict = [[NSMutableDictionary alloc] init];
                     
                     ALAssetRepresentation *rep = [asset defaultRepresentation];
                     NSDictionary   *metadata  = rep.metadata;
                     UIImage        *thumbnail = NULL;
                     NSData         *mediaData = NULL;
                     NSDate         *date      = NULL;
                     NSString       *filename  = NULL;
                     
                     [metaDict setObject:mediaType forKey: kSCloudMetaData_MediaType];
                     
                     if(metadata)
                     {
                         [metaDict addEntriesFromDictionary:metadata];
                         NSString * dateTime = [[ metadata  objectForKey:@"{Exif}"] objectForKey:@"DateTimeOriginal"];
                         if(dateTime)
                             date = [NSDate dateFromEXIF: dateTime];
                     }
                     
                     if(!date)  date = [asset valueForProperty:ALAssetPropertyDate];
                     
                      filename = rep.filename;
                     
                     
                      CGImageRef iFull = rep.fullResolutionImage;

                     if(iFull)
                     {
                         size_t width = CGImageGetWidth(iFull);
                         size_t height = CGImageGetHeight(iFull);
                          
                         ALAssetOrientation orient = [rep orientation];
                         
                         if(orient == ALAssetOrientationUp) //landscape image
                         {
                              if(height > width)
                                 thumbnail = [[UIImage imageWithCGImage:iFull] scaledToHeight:150];
                             else
                                thumbnail = [[UIImage imageWithCGImage:iFull] scaledToWidth:150];
                         }
                         else  // portrait image
                         {
                             if(height > width)
                                 thumbnail = [[[UIImage imageWithCGImage:iFull] scaledToHeight:150] imageRotatedByDegrees:90];
                             else
                                 thumbnail = [[[UIImage imageWithCGImage:iFull] scaledToWidth:150] imageRotatedByDegrees:90];
                         }
                     }
                      
                     if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeImage))
                     {
                         if(metadata && [metadata valueForKey:kSCloudMetaData_GPS])
                         {
                             thumbnail = [thumbnail imageWithBadgeOverlay:[UIImage imageNamed:@"mapwhite.png"] text:NULL textColor:[UIColor whiteColor] ];
                         }
                         
                         NSString *uti = rep.UTI;
                         
                        if(scale < .9 && ![uti isEqualToString: (__bridge NSString*)kUTTypeGIF])
                         {
                             UIImage* image1 = [asset scaledImage: scale];
                             mediaData =  UIImageJPEGRepresentation(image1, 1.0);
                             
                         }
                         else
                              {
                             Byte *buffer = (Byte*)malloc(rep.size);
                             NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:&error];
                             if(! error)
                             {
                                  mediaData = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
                             }
                         }
                         
                       }
                     else if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeMovie))
                     {
                         NSURL *mediaURL = [info objectForKey:UIImagePickerControllerMediaURL];
                         mediaData = [NSData dataWithContentsOfURL:mediaURL options:NSDataReadingMappedIfSafe error:&error];
                         
                          NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                         [formatter setDateFormat:@"mm:ss"];
                         
                         NSString* durationString = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[[asset valueForProperty:ALAssetPropertyDuration] doubleValue]]];
                         
                         thumbnail = [thumbnail imageWithBadgeOverlay:[UIImage imageNamed:@"movie.png"] text:durationString  textColor:[UIColor whiteColor] ];
                     }
                     
                     if(!error)
                     {
                         if(date) [metaDict setObject: [date rfc3339String] forKey:kSCloudMetaData_Date];
                         if(filename) [metaDict setObject: filename forKey:kSCloudMetaData_FileName];
                         
                         [self continuePickerProcessing:picker thumbnail:thumbnail data:mediaData info:metaDict ];
                     }
                     else
                     {
                         dispatch_async( dispatch_get_main_queue(), ^{
                             [self.delegate  mediaPickingError: error];
                               });
                     }
                     mediaData = nil;
                     
                 }
                failureBlock:^(NSError *error) {
                    
                    dispatch_async( dispatch_get_main_queue(), ^{
                        [self dismissModalViewControllerAnimated:YES];
                        [self.navigationController popViewControllerAnimated:YES];
                        });
                    }];
        });
 
    }
    else
    {
        NSMutableDictionary *metaDict = [[NSMutableDictionary alloc] init];
        NSDictionary *metadata = [info valueForKey:UIImagePickerControllerMediaMetadata];
        
        UIImage             *thumbnail = NULL;
        NSData              *mediaData = NULL;
        NSDate              *date = [NSDate date];
        
        [metaDict setObject:mediaType forKey: kSCloudMetaData_MediaType];
        
        if(metadata)
        {
            [metaDict addEntriesFromDictionary:metadata];
            NSString * dateTime = [[ metadata  objectForKey:@"{Exif}"] objectForKey:@"DateTimeOriginal"];
            if(dateTime)
                date = [NSDate dateFromEXIF: dateTime];
        }
        
        
        if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeImage))
        {
            UIImage *originalImage = [info objectForKey:UIImagePickerControllerOriginalImage];
             
            size_t width = originalImage.size.width;
            size_t height = originalImage.size.height;
         
            if(height > width)
                thumbnail = [originalImage scaledToHeight:150];
            else
                thumbnail = [originalImage scaledToWidth:150];
            
            if(scale < .9)
            {
                originalImage = [originalImage scaled:scale];
            }
            
            mediaData =  UIImageJPEGRepresentation(originalImage, 1.0);
             
         }
        else if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeMovie))
        {
            NSString *moviePath = [[info objectForKey:UIImagePickerControllerMediaURL] path];
            NSURL* movieURL = [NSURL fileURLWithPath:moviePath isDirectory:NO];
            
            mediaData = [NSData dataWithContentsOfURL:movieURL options:NSDataReadingMappedIfSafe error:nil];
            
            AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:movieURL options:nil];
            AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
            gen.appliesPreferredTrackTransform = YES;
            CMTime time = CMTimeMakeWithSeconds(0.0, 600);
            NSError *error = nil;
            CMTime actualTime;
            
            CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
              
            UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
            
            AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
            CGSize size = [videoTrack naturalSize];
            CGAffineTransform txf = [videoTrack preferredTransform];
            
            if (size.width == txf.tx && size.height == txf.ty)
                orientation =  UIInterfaceOrientationLandscapeRight;
            else if (txf.tx == 0 && txf.ty == 0)
                orientation =  UIInterfaceOrientationLandscapeLeft;
            else if (txf.tx == 0 && txf.ty == size.width)
                orientation =  UIInterfaceOrientationPortraitUpsideDown;
    
            if((orientation == UIInterfaceOrientationPortrait)
                || (orientation == UIInterfaceOrientationPortraitUpsideDown))
            {
                thumbnail = [[UIImage imageWithCGImage:image] scaledToHeight:150];
             }
            else if((orientation == UIInterfaceOrientationLandscapeRight)
                || (orientation == UIInterfaceOrientationLandscapeLeft))
            {
                thumbnail = [[UIImage imageWithCGImage:image] scaledToWidth:150];
            }
            
                
            CGImageRelease(image);
            
               
            NSTimeInterval durationSeconds = CMTimeGetSeconds([asset duration]);
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"mm:ss"];
            
            NSString* durationString = [formatter stringFromDate:
                                        [NSDate dateWithTimeIntervalSince1970:durationSeconds]];
            
            thumbnail = [thumbnail imageWithBadgeOverlay:[UIImage imageNamed:@"movie.png"] text:durationString  textColor:[UIColor whiteColor] ];

      	}
        
        [metaDict setObject: [date rfc3339String] forKey:kSCloudMetaData_Date];
        
        
        [self continuePickerProcessing:picker thumbnail:thumbnail data:mediaData info:metaDict ];
    }
     
 }

-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissModalViewControllerAnimated:YES];
    [self.navigationController popViewControllerAnimated:YES];

}

-(void)image:(UIImage *)image finishedSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    if (error) {
        
        [self.delegate  mediaPickingError: error];
           
    }
}
     

-(void) pickExistingPhoto
{
    _newMedia = NO;
  
    UIImagePickerController * picker =  [[UIImagePickerController alloc] init];
     picker.delegate        = self;
     picker.sourceType      = UIImagePickerControllerSourceTypePhotoLibrary;
     picker.mediaTypes =   [UIImagePickerController  availableMediaTypesForSourceType: picker.sourceType];
     picker.allowsEditing   = NO;
     picker.videoQuality = UIImagePickerControllerQualityTypeMedium;
    
// this should not compress, but it does (Apple Bug, sigh!)
// see http://openradar.appspot.com/11489478
  
    [self presentModalViewController: picker animated:YES];
}



-(void) pickNewPhoto
{
    _newMedia = YES;
 
      UIImagePickerController * picker  =  [[UIImagePickerController alloc] init];
     picker.delegate        = self;
     picker.sourceType      = UIImagePickerControllerSourceTypeCamera;
     picker.mediaTypes =   [UIImagePickerController  availableMediaTypesForSourceType: picker.sourceType];
     picker.allowsEditing   = NO;
     picker.videoQuality = UIImagePickerControllerQualityTypeMedium;
 
    [self presentModalViewController: picker animated:YES];
}



#pragma mark -
#pragma mark SCloudObjectDelegate methods
 
- (void)scloudObject:(SCloudObject *)sender calculatingKeysDidStart:(NSString*) mediaType
{
    _HUD.mode = MBProgressHUDModeIndeterminate;
}

- (void)scloudObject:(SCloudObject *)sender calculatingKeysProgress:(float) progress
{
     self.HUD.progress = progress;
}

- (void)scloudObject:(SCloudObject *)sender calculatingKeysDidCompleteWithError:(NSError *)error
{
 }

- (void)scloudObject:(SCloudObject *)sender encryptingDidStart:(NSString*) mediaType
{
    _HUD.mode = MBProgressHUDModeIndeterminate;
     _HUD.labelText = @"Encrypting";

}

- (void)scloudObject:(SCloudObject *)sender encryptingProgress:(float) progress
{
    self.HUD.progress = progress;
   
}
- (void)scloudObject:(SCloudObject *)sender encryptingDidCompleteWithError:(NSError *)error
{
    
}



@end
