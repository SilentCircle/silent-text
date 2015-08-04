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
//  STMessage+Utilities.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 7/22/14.
//
#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "YapDatabase.h"

#import "AvatarManager.h"
#import "STMessage+Utilities.h"
#import "AppConstants.h"
#import "STSCloud.h"
#import "Siren.h"
#import "UIImage+Thumbnail.h"
#import "STImage.h"
#import "SnippetGraphView.h"
#import "AppTheme.h"    
#import "UIImage+maskColor.h"
#import "SCloudObject.h"
#import "SCDateFormatter.h"
#import <MapKit/MapKit.h>
#import "MKMapView+SCUtilities.h"
#import "CLLocation+NSDictionary.h"
#import "SCDateFormatter.h"
#import "STLogging.h"

#import "SCMapImage.h"
 
// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
static const int ddLogLevel = LOG_LEVEL_VERBOSE; // | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@implementation STMessage (Utilities)


- (UIImage *)imageForThumbNailScaledToHeight:(float)height
                       withHorizontalPadding:(float)horizontalPadding
                                   annotate:(BOOL)annotate
                                fromUserName:(NSString*)userName
 {
    AvatarManager* avatarManager =  [AvatarManager sharedInstance];

     AppTheme* theme = [AppTheme getThemeBySelectedKey];
     UIColor* tintColor = self.isOutgoing?theme.selfBubbleTextColor:theme.otherBubbleTextColor;

    // determine if there is an image for this message
	UIImage *msgImage = NULL;
    
	Siren *siren = self.siren;
    STSCloud *scl = [self scloudForMessage];
    NSString* fileName = scl?scl.metaData?[scl.metaData objectForKey:kSCloudMetaData_FileName]?:NULL:NULL:NULL;
     
     NSArray* exceptionTheseMediaTypes = @[@"com.adobe.photoshop-image" , @"com.adobe.illustrator.ai-image"];
     
 
     /*
      Ff there is a scl.thumbnail, it means te user has already open the file once and as a result
      calculated a high quality thumbail from the Scloud Object
      typically this is a photo. In that case use this image as the prefered thumbnail.
      */
     if(scl)
     {
         NSString* metaThumbnailString = scl?scl.metaData?[scl.metaData objectForKey:kSCloudMetaData_Thumbnail]?:NULL:NULL:NULL;
         
         if(metaThumbnailString.length)
         {
             NSData* metathumbData = [[NSData  alloc  ]initWithBase64EncodedString:metaThumbnailString options:NSDataBase64DecodingIgnoreUnknownCharacters];
             msgImage = [UIImage imageWithData:metathumbData];
             
         }
         else if(scl.thumbnail)
         {
             msgImage = scl.thumbnail;
             
         }
         
         
         // we might need to add the annotations for these images
         //        msgImage = annotate
         //        ? [self addAnnotationToImage:scl.thumbnail withSiren:siren]
         //        : scl.thumbnail;
         //
         if(msgImage && siren.isPDF)
         {
             msgImage = [msgImage scaledToHeight:height];
         }
         
         if(msgImage)
             return msgImage;
         
     }
     
    /* All enclosures should have media types */
    if(siren.mediaType)
    {
        /* audio messages */
        if(UTTypeConformsTo( (__bridge CFStringRef)siren.mediaType, kUTTypeAudio))
        {
            BOOL isVoiceMail = (self.siren.callerIdName || self.siren.callerIdNumber);
            
            if(isVoiceMail)
            {
                msgImage = [self voiceMailThumbnailScaledToHeight:height
                                            withHorizontalPadding:horizontalPadding
                                                         annotate:annotate];
             
            }
            else
            {
                msgImage = [self audioThumbnailScaledToHeight:height
                                        withHorizontalPadding:horizontalPadding
                                                     annotate:annotate];
                
            }
        }
        
        /* contact cards */
        else if(UTTypeConformsTo( (__bridge CFStringRef)siren.mediaType, kUTTypeVCard))
		{
            // check for modern SC vcard,  has mimeType and preview
 			if(siren.mimeType && [siren.mimeType isEqualToString:kMimeType_vCard] && siren.preview)
			{
                UIImage* cardImage = [avatarManager defaultVCardImageScaledToHeight:height];
                
                /* if a vcard has a preview, paste it into the vCard frame */
                UIImage* personImage =  (siren.preview)
                ?[UIImage imageWithData:siren.preview]
                : [UIImage imageNamed:@"defaultPerson"];
                
                UIGraphicsBeginImageContext(CGSizeMake(122, 94));
                [cardImage drawInRect:CGRectMake(0, 0, 122, 94)];
                [personImage drawInRect:CGRectMake(16, 15, 52, 51)];
                
                cardImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                msgImage = cardImage;
                
 			}
            
            // handle legacy Android. vcard bug
            else if([siren.mediaType isEqualToString:kMimeType_vCard])
            {
                UIImage* cardImage = [avatarManager defaultVCardImageScaledToHeight:height];
                UIImage* personImage = [UIImage imageNamed:@"defaultPerson"];
                
                UIGraphicsBeginImageContext(CGSizeMake(122, 94));
                [cardImage drawInRect:CGRectMake(0, 0, 122, 94)];
                [personImage drawInRect:CGRectMake(16, 15, 52, 51)];
                
                cardImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                
                msgImage = cardImage;
            }
            else // old style vcard, the image is complete thumbnail with card background
            {
                STImage *thumbnail = [self stImageThumbnail];
                
                if(!thumbnail && !siren.thumbnail)
                {
                    UIImage* cardImage = [avatarManager defaultVCardImageScaledToHeight:height];
                    UIImage* personImage = [UIImage imageNamed:@"defaultPerson"];
                    
                    UIGraphicsBeginImageContext(CGSizeMake(122, 94));
                    [cardImage drawInRect:CGRectMake(0, 0, 122, 94)];
                    [personImage drawInRect:CGRectMake(16, 15, 52, 51)];
                    
                    cardImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    
                    msgImage = cardImage;
                    
                }
                else

                    msgImage = thumbnail ? thumbnail.image : [UIImage imageWithData:siren.thumbnail];
                
                 }
  		}
        
        /* calendar events */
        else if(UTTypeConformsTo( (__bridge CFStringRef)siren.mediaType,  (__bridge CFStringRef) @"public.calendar-event"))
		{
            msgImage = [avatarManager defaultVCalendarImageScaledToHeight:height];
            msgImage = [msgImage maskWithColor:tintColor];
            
		}
        
        /* folders (zip files) */
        
        else if(UTTypeConformsTo( (__bridge CFStringRef)siren.mediaType,  (__bridge CFStringRef) @"public.folder"))
		{
            msgImage = [avatarManager defaultFolderImageScaledToHeight:height];
            msgImage = [msgImage maskWithColor:tintColor];

		}
        
        /* messages with thumbnails */
        else if (self.hasThumbnail || siren.thumbnail)
        {
            STImage *thumbnail = [self stImageThumbnail];
            msgImage = thumbnail ? thumbnail.image : [UIImage imageWithData:siren.thumbnail 
                                                                      scale:[[UIScreen mainScreen] scale]];
            
            if(annotate)
                msgImage = [self addAnnotationToImage:msgImage withSiren:siren];
            
            
            /*
             an  attempt to put lipstick on the pig that is Android
             */
            
            if([siren.mediaType isEqualToString:@"public.data"]
               && [siren.mimeType isEqualToString:@"text/plain"])
            {
                msgImage = [avatarManager defaultImageForMediaType: @"public.text"
                                                              scaledToHeight:height];

            }
            else if([siren.mediaType isEqualToString:@"public.data"]
                    && [siren.mimeType isEqualToString:@"application/pdf"])
            {
                msgImage = [avatarManager defaultImageForMediaType: @"com.adobe.pdf"
                                                    scaledToHeight:height];
                

            }
            else  if([siren.mediaType isEqualToString:@"public.data"]
                     && [siren.mimeType hasPrefix:@"application/vnd.android."])
            {
                /* android vendor specific crap */
                msgImage = [avatarManager defaultAndroidFileImageScaledToHeight:height];
              }
            
            /* handle pdf files */
            else if(siren.isPDF)
            {
                if(msgImage)
                {
                    msgImage = [msgImage scaledToHeight:height];
                }
                else
                {
                    msgImage = [avatarManager defaultImageForMediaType: @"com.adobe.pdf"
                                                        scaledToHeight:height];
                    
                 }
              }
            
            /*  try and override the thumbnail if it's not one of these items  */
            else if( ! ( (UTTypeConformsTo((__bridge CFStringRef)siren.mediaType,    kUTTypeImage)
                          ||  UTTypeConformsTo( (__bridge CFStringRef)siren.mediaType,  kUTTypeMovie))
                        )
                    || ([exceptionTheseMediaTypes containsObject:siren.mediaType])
                    )
            {
                
                UIImage* alternateImage = NULL;
                if(fileName)
                {
                    alternateImage = [self alternateImageForMediaType:siren.mediaType
                                                        fileExtension:[fileName pathExtension]
                                                       scaledToHeight:height];
                    
                 }
                if(alternateImage)
                {
                    msgImage = alternateImage;
                }
                else
                    msgImage = [avatarManager defaultImageForMediaType:siren.mediaType
                                                              scaledToHeight:height];
            }
         }
        
        /* other media types we dont know about  - fail?*/
        else
        {
            msgImage = [avatarManager defaultImageForMediaType: siren.mediaType
                                                scaledToHeight:height];
            
        }
    }
    
    /* this is an old style ST1 vcard */
    else if (siren.vcard)
    {
        msgImage =  [avatarManager defaultVCardImageScaledToHeight:height];
    }
    
    /* broken case, an enclosure without any media type? */
    else if(siren.cloudLocator)
    {
        msgImage = [UIImage defaultImageForMediaType:(__bridge NSString*) kUTTypeData];
        msgImage = [msgImage scaledToHeight:height];
        
    }
     
    /* Null message with location, this indicates a map coordinate */
    else if(siren.isMapCoordinate)
    {
        
        msgImage = [avatarManager defaultMapImageScaledToHeight:height];
        
        if(annotate)
        {
            if(self.hasThumbnail)
            {
                 STImage *thumbnail = [self stImageThumbnail];
                msgImage = thumbnail ? thumbnail.image :NULL;
             }
            else
            {
 // FIXME: !  - vinnie
//  we really should check for self.isOutgoing and handle the option of not hittingthe map tile server for any locations
// that I transmit.   this sounds like a privacy option.
//                [self updateThumbNailWithMapImage];
                

             }
            
        }
        
    }
    return msgImage;
}

-(void) updateThumbNailWithMapImage
{
    CGSize mapSize  = { .height = 90, .width = 160};
    NSError *jsonError;
    
    NSDictionary *locInfo = [NSJSONSerialization
                             JSONObjectWithData:[self.siren.location dataUsingEncoding:NSUTF8StringEncoding]
                             options:0 error:&jsonError];
    
    if (jsonError==nil){
        
        __block NSString* messageId = self.uuid;
        __block NSString* conversationId = self.conversationId;
       
        CLLocation* location = [[CLLocation alloc] initWithDictionary: locInfo];
         NSString* mapTitle = NULL;
        
        if(location.timestamp)
        {
            NSDateFormatter *formatter  = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterShortStyle
                                                                            timeStyle:NSDateFormatterShortStyle];
            
            mapTitle = [formatter stringFromDate:location.timestamp];
        }
        
        SCMapPin* pin  = [[SCMapPin alloc] initWithLocation: location
                                                      title: @""
                                                   subTitle: @""
                                                     image : NULL
                                                       uuid: NULL] ;
        [SCMapImage mapImageWithPins:@[pin]
                            withSize:mapSize
                             mapName:mapTitle
                 withCompletionBlock:^(UIImage *image, NSError *error) {
                     
                     if(!error)
                     {
                         
                         YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
                         [rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                             
                             STMessage *message = [transaction objectForKey:messageId inCollection:conversationId];
                             if(message)
                             {
                                 STImage *thumbnail = [[STImage alloc] initWithImage:image
                                                                           parentKey:messageId
                                                                          collection:conversationId];
                                 
                                 [transaction setObject:thumbnail
                                                 forKey:thumbnail.parentKey
                                           inCollection:kSCCollection_STImage_Message];
                                 
                                 message = message.copy;
                                 message.hasThumbnail = YES;
                                 
                                 [transaction setObject:message
                                                 forKey:message.uuid
                                           inCollection:message.conversationId];
                                 
                             }
                             
                         } completionBlock:^{
                             
                             
                         }];
                         
                         
                         
                     }
                     
                 }];
        
        
    };
    
    
}

-(UIImage*) alternateImageForMediaType:(NSString*)mediaType
                         fileExtension:(NSString*)fileExtension
                        scaledToHeight:(float)height
{
    UIImage* image = NULL;
    
    if( [mediaType hasPrefix:@"com.apple.iwork"]
    ||  [mediaType isEqualToString:(__bridge NSString*)kUTTypeRTFD])
        return NULL;
    
  // reasonable file extension name
    NSString* textString  = (fileExtension.length > 0) && (fileExtension.length < 5)? fileExtension:@"?";
    
    UIImage* baseImage  = [[AvatarManager sharedInstance] defaultDocumentFileImageScaledToHeight:height];
    
    
    UIColor* textColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    
    CGFloat fontSize = height / 3;
    UIFont *font = [UIFont systemFontOfSize:fontSize];
    
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineBreakMode = NSLineBreakByTruncatingTail;
    style.alignment = NSTextAlignmentCenter;

    NSDictionary *attributes = @{
                   NSFontAttributeName: font,
                   NSParagraphStyleAttributeName: style,
                   NSForegroundColorAttributeName: textColor
                   };
    
    CGPoint origin = CGPointMake(baseImage.size.width /2, (baseImage.size.height /2));
    
    CGSize textRectSize = [textString sizeWithAttributes:attributes];
  
    CGRect textRect = (CGRect){
        .origin.x =  baseImage.size.width - textRectSize.width - (baseImage.size.width - textRectSize.width)/2 ,
        .origin.y = origin.y - font.pointSize / 2 ,
        .size.width = textRectSize.width,
        .size.height = textRectSize.height
    };

    UIGraphicsBeginImageContext(baseImage.size);
    
    [baseImage drawInRect:CGRectMake(0, 0, baseImage.size.width, baseImage.size.height)];

    [textColor set];
    
    [textString drawInRect:textRect withAttributes:attributes];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    image =  newImage;
    
 
    return image;
}




- (UIImage *)voiceMailThumbnailScaledToHeight:(float)height
                        withHorizontalPadding:(float)horizontalPadding
                                     annotate:(BOOL)annotate

{
    
    AppTheme* theme = [AppTheme getThemeBySelectedKey];
    
    UIColor* color = self.isOutgoing?theme.selfBubbleTextColor:theme.otherBubbleTextColor;
    UIImage* image = NULL;
    
    CGSize frameSize = {250,88};
    
    image = [SnippetGraphView thumbnailImageForSirenVoiceMail: self.siren
                                                    frameSize: frameSize
                                                        color: color];
    
    return image;
}


- (UIImage *)audioThumbnailScaledToHeight:(float)height
                    withHorizontalPadding:(float)horizontalPadding
                                 annotate:(BOOL)annotate

{
    
    AppTheme* theme = [AppTheme getThemeBySelectedKey];

    UIColor* color = self.isOutgoing?theme.selfBubbleTextColor:theme.otherBubbleTextColor;
    UIImage* image = NULL;
    
    CGSize frameSize = {250,44};
    
    frameSize.width -= horizontalPadding;
  
    if(!annotate)
    {
        image =  [[AvatarManager sharedInstance] defaultAudioImageScaledToHeight:frameSize.height];
        
    }
    else
    {
        image = [SnippetGraphView thumbnailImageForSirenAudio: self.siren
                                                    frameSize: frameSize
                                                        color: color];
    }
  
    return image;
}



- (UIImage*) addAnnotationToImage:(UIImage*)imageIn withSiren:(Siren*) siren
{
    static 	NSDateFormatter *durationFormatter = NULL;
    UIImage* image = imageIn;
 
    if(siren.hasGPS || siren.duration)
    {
        NSString* overlayText = NULL;
        UIImage* overlayBadge = NULL;
        
        if(siren.duration)
        {
            if(!durationFormatter)
            {
                durationFormatter = [[NSDateFormatter alloc] init] ;
                [durationFormatter setDateFormat:@"mm:ss"];
             }
            
            NSTimeInterval duration =  siren.duration.doubleValue;
            overlayText = [durationFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: duration]];
        }
        
        if(siren.hasGPS)
        {
            overlayBadge = [UIImage imageNamed:@"mapwhite.png"];
        }
        
        image = [imageIn imageWithBadgeOverlay:overlayBadge
                                          text:overlayText
                                     textColor:[UIColor whiteColor]];
    }
    
    return image;
}



- (STSCloud *)scloudForMessage
{
    YapDatabaseConnection *databaseConnection = STDatabaseManager.uiDatabaseConnection;
    
	__block STSCloud *scl = nil;
	if (self.scloudID)
	{
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			scl = [transaction objectForKey:self.scloudID inCollection:kSCCollection_STSCloud];
		}];
	}
	
	return scl;
}

- (STImage *)stImageThumbnail
{
    YapDatabaseConnection *databaseConnection = STDatabaseManager.uiDatabaseConnection;

	__block STImage *thumbnail = nil;
	if (self.hasThumbnail)
	{
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			thumbnail = [transaction objectForKey:self.uuid inCollection:kSCCollection_STImage_Message];
		}];
	}
	
	return thumbnail;
}



@end
