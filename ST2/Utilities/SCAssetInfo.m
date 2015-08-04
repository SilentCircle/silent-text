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
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <ImageIO/ImageIO.h>

#import "SCAssetInfo.h"
#import "AppConstants.h"
#import "SCloudObject.h"
#import "SCDateFormatter.h"
#import "Siren.h"
//Categories
#import "ALAsset+SCUtilities.h"
#import "NSDate+SCDate.h"
#import "NSDictionary+SCDictionary.h"
#import "UIImage+Thumbnail.h"


NSString *const kAssetInfo_Metadata      = @"thumbnail";  // NSDictionary with kSCloudMetaData_X keys
NSString *const kAssetInfo_ThumbnailData = @"metadata";   // NSData (JPEG)
NSString *const kAssetInfo_MediaData     = @"mediaData";  // NSData (JPEG)
NSString *const kAssetInfo_Asset         = @"asset";      // ALAsset (if no MediaData)

// Second parameter for UIImageJPEGRepresentation.
// From the docs:
//   The value 0.0 represents the maximum compression (or lowest quality)
//   while the value 1.0 represents the least compression (or best quality).
//
// Changes:
// - 2014-11-4 : Bumped from 0.1 to 0.2 (for better looking thumbnails, while still keeping size down)
const float kThumbnailCompressionQuality = 0.2;


@implementation SCAssetInfo

/**
 * Creates the proper AssetInfo to pass to MessageStream.
**/
+ (NSDictionary *)assetInfoForAsset:(ALAsset *)asset withScale:(float)scale
{
	ALAssetRepresentation *rep = [asset defaultRepresentation];
	NSDictionary *metadata = rep.metadata;
	
	NSString * mediaType     = nil;
	NSString * mimeType      = nil;
	NSDate   * date          = nil;
	NSString * filename      = nil;
	NSNumber * fileSize      = nil;
	NSData   * thumbnailData = nil;
	NSData   * mediaData     = nil;
	NSString * duration      = nil;
	
	BOOL isCroppedPhoto = NO;
    UIImage *image = nil;
	
	
	mediaType = rep.UTI;
	
	mimeType = (__bridge_transfer NSString *)
	  UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)mediaType, kUTTagClassMIMEType);
	
    if (metadata)
    {
        NSString *dateTime = [[rep.metadata objectForKey:@"{Exif}"] objectForKey:@"DateTimeOriginal"];
        if (dateTime)
            date = [NSDate dateFromEXIF:dateTime];
    }
    if (date == nil) {
		date = [asset valueForProperty:ALAssetPropertyDate];
	}
	
	filename = rep.filename;
	fileSize =  @(rep.size);
    
    if (rep.metadata[@"AdjustmentXMP"])
    {
		isCroppedPhoto = YES;
		CGImageRef croppedImage = [asset createAdjustedImageUsingCIImage];
		
		image = [UIImage imageWithCGImage:croppedImage
		                            scale:rep.scale
		                      orientation:(UIImageOrientation)rep.orientation];
		
		CGImageRelease(croppedImage);
    }
	else
	{
		CGImageRef fullImage = rep.fullResolutionImage;
		if (fullImage)
		{
			image = [UIImage imageWithCGImage:fullImage
			                            scale:rep.scale
			                      orientation:(UIImageOrientation)rep.orientation];
		}
	}
	
	if (image)
    {
		UIImage *thumbnail = nil;
		
        CGFloat width = image.size.width;
        CGFloat height = image.size.height;
		
        //ST-928 03/20/15
        if (height > width)
            thumbnail = [image scaledToHeight:[UIImage maxSirenThumbnailHeightOrWidth]];
        else
            thumbnail = [image scaledToWidth:[UIImage maxSirenThumbnailHeightOrWidth]];
		
		thumbnailData = UIImageJPEGRepresentation(thumbnail, kThumbnailCompressionQuality);
    }
    
    if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeGIF])
    {
		// Process this as an asset, don't mess with GIF
    }
	else if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage))
	{
		if (scale < 1.0)
		{
			mediaData = UIImageJPEGRepresentation([image scaled:scale], 1.0);
			fileSize = @(mediaData.length);
		}
		else if (isCroppedPhoto)
		{
			mediaData = UIImageJPEGRepresentation(image, 1.0);
			fileSize = @(mediaData.length);
		}
	}
    else if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeMovie))
    {
		duration = [NSString stringWithFormat:@"%f", [[asset valueForProperty:ALAssetPropertyDuration] doubleValue]];
    }
	
	// Create the metadata dictionary.
	
	NSMutableDictionary *metaDict = [[NSMutableDictionary alloc] initWithCapacity:10];
	
	[metadata filterEntriesFromMetaDataTo:metaDict];
	
	if (mediaType)
		[metaDict setObject:mediaType forKey:kSCloudMetaData_MediaType];
	
	if (mimeType)
		[metaDict setObject:mimeType forKey:kSCloudMetaData_MimeType];
	
	if (date)
		[metaDict setObject:[date rfc3339String] forKey:kSCloudMetaData_Date];
	
	if (filename)
		[metaDict setObject: filename forKey:kSCloudMetaData_FileName];
    
	if (fileSize)
		[metaDict setObject:fileSize forKey:kSCloudMetaData_FileSize];
	
	if (duration)
		[metaDict setObject:duration forKey:kSCloudMetaData_Duration];
	
	// And create the master assetInfo dictionary.
	
	NSMutableDictionary *assetInfo = [NSMutableDictionary dictionaryWithCapacity:4];
	
	[assetInfo setObject:metaDict forKey:kAssetInfo_Metadata];
	
	if (thumbnailData)
		[assetInfo setObject:thumbnailData forKey:kAssetInfo_ThumbnailData];
	
	if (mediaData)
		[assetInfo setObject:mediaData forKey:kAssetInfo_MediaData];
	else
		[assetInfo setObject:asset forKey:kAssetInfo_Asset];
	
    return assetInfo;
}

/**
 * Creates the proper AssetInfo to pass to MessageStream.
 *
 * @param imagePickerInfo
 *   The info dictionary returned by UIImagePicker.
**/
+ (NSDictionary *)assetInfoForImagePickerInfo:(NSDictionary *)imagePickerInfo
                                    withScale:(float)scale
                                     location:(CLLocation *)location
{
    NSDictionary *metadata = [imagePickerInfo valueForKey:UIImagePickerControllerMediaMetadata];
	
	NSString     * mediaType     = nil;
	NSString     * mimeType      = nil;
	NSDate       * date          = nil;
	NSString     * filename      = nil;
	NSNumber     * fileSize      = nil;
	NSData       * thumbnailData = nil;
	NSData       * mediaData     = nil;
	NSString     * duration      = nil;
	NSDictionary * gpsDict       = nil;
    
    mediaType = [imagePickerInfo objectForKey:UIImagePickerControllerMediaType];
	
	mimeType = (__bridge_transfer NSString *)
	  UTTypeCopyPreferredTagWithClass((__bridge CFStringRef) mediaType, kUTTagClassMIMEType);
    
	if (metadata)
	{
		NSString *dateTime = [[metadata objectForKey:@"{Exif}"] objectForKey:@"DateTimeOriginal"];
		if (dateTime) {
			date = [NSDate dateFromEXIF:dateTime];
		}
	}
	if (date == nil) {
		date = [NSDate date];
	}
	
	NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
	                                                               timeStyle:NSDateFormatterShortStyle];
	filename = [formatter stringFromDate:date];
 
	if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage))
	{
		UIImage *image = [imagePickerInfo objectForKey:UIImagePickerControllerOriginalImage];
		UIImage *thumbnail = nil;
		
		CGFloat width = image.size.width;
		CGFloat height = image.size.height;
        
        //ST-928 03/20/15
		if (height > width)
			thumbnail = [image scaledToHeight:[UIImage maxSirenThumbnailHeightOrWidth]];
		else
			thumbnail = [image scaledToWidth:[UIImage maxSirenThumbnailHeightOrWidth]];
        
        thumbnailData = UIImageJPEGRepresentation(thumbnail, kThumbnailCompressionQuality);
        
		if (scale < 1.0)
		{
			mediaData = UIImageJPEGRepresentation([image scaled:scale], 1.0);
			fileSize = @(mediaData.length);
		}
        else
		{
			mediaData = UIImageJPEGRepresentation(image, 1.0);
			fileSize = @(mediaData.length);
		}
		
		mimeType = @"image/jpeg";
		filename = [[NSMutableString stringWithString:filename] stringByAppendingPathExtension:@"JPG"];
	}
	else if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeMovie))
	{
		NSURL *url = [imagePickerInfo objectForKey:UIImagePickerControllerMediaURL];
		
		// Todo: This is very wasteful.
		// Can't we just pass the URL directly into SCloud ?
		mediaData = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:nil];
		
		UIImage *thumbnail = nil;
		if ([self getThumbnailImage:&thumbnail duration:&duration forMovieWithURL:url])
		{
			thumbnailData = UIImageJPEGRepresentation(thumbnail, kThumbnailCompressionQuality);
		}
		
		if (!mimeType)
			mimeType = @"video/quicktime";
		filename = [[NSMutableString stringWithString:filename] stringByAppendingPathExtension:@"MOV"];
    }
	
	if (location)
	{
		CLLocationDegrees exifLatitude  = location.coordinate.latitude;
		CLLocationDegrees exifLongitude = location.coordinate.longitude;
		
		NSString *latRef;
		NSString *lngRef;
		if (exifLatitude < 0.0) {
			exifLatitude = exifLatitude * -1.0f;
			latRef = NSLocalizedString(@"S", "S as in the identifier for South");
		} else {
			latRef = NSLocalizedString(@"N", "N as in the identifier for North");
		}
		
		if (exifLongitude < 0.0) {
			exifLongitude = exifLongitude * -1.0f;
			lngRef = NSLocalizedString(@"W", "W as in the identifier for West");
		} else {
			lngRef = NSLocalizedString(@"E", "E as in the identifier for East");
		}
		
		NSMutableDictionary *locDict = [[NSMutableDictionary alloc] initWithCapacity:7];
		
		NSDictionary *imageLocDict = [imagePickerInfo objectForKey:(NSString *)kCGImagePropertyGPSDictionary];
		if (imageLocDict) {
			[locDict addEntriesFromDictionary:imageLocDict];
		}
		
		locDict[(NSString *)kCGImagePropertyGPSTimeStamp]    = [location.timestamp ExifString];
		locDict[(NSString *)kCGImagePropertyGPSLatitudeRef]  = latRef;
		locDict[(NSString *)kCGImagePropertyGPSLatitude]     = @(exifLatitude);
		locDict[(NSString *)kCGImagePropertyGPSLongitudeRef] = lngRef;
		locDict[(NSString *)kCGImagePropertyGPSLongitude]    = @(exifLongitude);
		locDict[(NSString *)kCGImagePropertyGPSDOP]          = @(location.horizontalAccuracy);
		locDict[(NSString *)kCGImagePropertyGPSAltitude]     = @(location.altitude);
		
		gpsDict = [locDict copy];
	}
	
	// Create the metadata dictionary.
	
	NSMutableDictionary *metaDict = [[NSMutableDictionary alloc] initWithCapacity:10];
	
    [metadata filterEntriesFromMetaDataTo:metaDict];
	
	if (mediaType)
		[metaDict setObject:mediaType forKey: kSCloudMetaData_MediaType];
	
	if (mimeType)
		[metaDict setObject: mimeType forKey:kSCloudMetaData_MimeType];
	
	if (date)
		[metaDict setObject:[date rfc3339String] forKey:kSCloudMetaData_Date];
    
	if (filename)
		[metaDict setObject: filename forKey:kSCloudMetaData_FileName];
   
	if (mimeType)
		[metaDict setObject: mimeType forKey:kSCloudMetaData_MimeType];
    
	if (fileSize)
		[metaDict setObject:fileSize forKey:kSCloudMetaData_FileSize];
    
	if (duration)
		[metaDict setObject:duration forKey:kSCloudMetaData_Duration];
	
	if (gpsDict)
		[metaDict setObject:gpsDict forKey:(NSString *)kCGImagePropertyGPSDictionary];

	// And create the master assetInfo dictionary.

	NSMutableDictionary *assetInfo = [NSMutableDictionary dictionaryWithCapacity:4];
	
	[assetInfo setObject:metaDict forKey:kAssetInfo_Metadata];
	
	if (thumbnailData)
		[assetInfo setObject:thumbnailData forKey:kAssetInfo_ThumbnailData];
	
	if (mediaData)
		[assetInfo setObject:mediaData forKey:kAssetInfo_MediaData];
	
	return assetInfo;
}

+ (BOOL)getThumbnailImage:(UIImage **)thumbnailImagePtr duration:(NSString **)durationPtr forMovieWithURL:(NSURL *)url
{
	if (url == nil)
	{
		if (thumbnailImagePtr) *thumbnailImagePtr = nil;
		if (durationPtr) *durationPtr = nil;
		return NO;
	}
	
	UIImage *thumbnail = nil;
	NSString *duration = nil;
	
	AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
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
        //SC-928 03/20/15
		thumbnail = [[UIImage imageWithCGImage:image] scaledToHeight:[UIImage maxSirenThumbnailHeightOrWidth]];
	}
	else if((orientation == UIInterfaceOrientationLandscapeRight)
			|| (orientation == UIInterfaceOrientationLandscapeLeft))
	{
        //SC-928 03/20/15
		thumbnail = [[UIImage imageWithCGImage:image] scaledToWidth:[UIImage maxSirenThumbnailHeightOrWidth]];
	}
	
	CGImageRelease(image);
	
	NSTimeInterval durationSeconds = CMTimeGetSeconds([asset duration]);
	duration = [NSString stringWithFormat:@"%f", durationSeconds];
	
	if (thumbnailImagePtr) *thumbnailImagePtr = thumbnail;
	if (durationPtr) *durationPtr = duration;
	return YES;
}

@end
