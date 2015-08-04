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
//  SCMapImage.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 7/29/14.
//

#import "SCMapImage.h"
#import <MapKit/MapKit.h>
#import "MKMapView+SCUtilities.h"
#import "STLogging.h"
 // Log levels: off, error, warn, info, verbose

#if DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)

@interface SCMapPin()
{
    CLLocation* location;
    NSString *title;
    NSString *subtitle;
    UIImage* image;
    NSString* uuid;
}

@end

@implementation SCMapPin
@synthesize location;
@synthesize title;
@synthesize subtitle;
@synthesize image;
@synthesize uuid;

- (id)initWithLocation:(CLLocation*)locationIn
                 title:(NSString*)titleIn
              subTitle:(NSString*)subTitleIn
              image:(UIImage*)imageIn
                  uuid:(NSString*)uuidIn
{
    self = [super init];
    
    if (self != nil)
    {
        location    = locationIn;
        image       = imageIn;
        title       = titleIn;
        subtitle    = subTitleIn;
        uuid        = uuidIn;
        
    }
    return self;
    
}


- (CLLocationCoordinate2D) coordinate {
    CLLocationCoordinate2D coords = location.coordinate;
    
    return coords;
}

- (CLLocationDistance ) altitude {
    CLLocationDistance alt = location.altitude;
    
    return alt;
}


@end



@implementation SCMapImage

+(void) mapImageWithPins:(NSArray*)pins     //SCMapPin
                withSize:(CGSize)size
                 mapName:(NSString*)mapName
     withCompletionBlock:(void (^)(UIImage* image, NSError *error))completionBlock
{
     if(!completionBlock) return;
    
    CGRect frameRect =  {0,0,size.width,size.height};

    __block MKMapView*  mV = [[MKMapView alloc] initWithFrame:frameRect];
    
    mV.zoomEnabled = NO;
    mV.scrollEnabled = NO;
    mV.mapType = MKMapTypeStandard;
    
    if(pins.count)
    {
        [mV addAnnotations:pins];
        [mV zoomToFitAnnotations:YES];
    }
    
    MKMapSnapshotOptions *options = [[MKMapSnapshotOptions alloc] init];
    options.region = mV.region;
    options.size = mV.frame.size;
    options.scale = [[UIScreen mainScreen] scale];
    
    MKMapSnapshotter *snapshotter = [[MKMapSnapshotter alloc] initWithOptions:options];
    [snapshotter startWithCompletionHandler:^(MKMapSnapshot *snapshot, NSError *error)
    {
        
        if(!error)
        {
            UIImage *image = snapshot.image;

            UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
  
            [image drawAtPoint:CGPointMake(0.0f, 0.0f)];
            
             CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
            
            for (SCMapPin* annotation in mV.annotations)
            {
                
                MKAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:nil];
                if(annotation.image)
                    pin.image = annotation.image;
                 
                CGPoint point = [snapshot pointForCoordinate:annotation.coordinate];
                
                if (CGRectContainsPoint(rect, point))
                {
                    point.x = point.x + pin.centerOffset.x -
                    (pin.bounds.size.width / 2.0f);
                    point.y = point.y + pin.centerOffset.y -
                    (pin.bounds.size.height / 2.0f);
                    
                    UIImage* pinImage = pin.image;
                    
                    [pinImage drawAtPoint:point];
               }
            }
            
            
            if(mapName)
            {
                
                UIFont *titleFont = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
                
                NSMutableParagraphStyle *titleStyle = [[NSMutableParagraphStyle alloc] init];
                titleStyle.lineBreakMode = NSLineBreakByTruncatingTail;
                titleStyle.alignment = NSTextAlignmentCenter;
                
                NSDictionary *attributes = @{
                                             NSFontAttributeName: titleFont,
                                             NSParagraphStyleAttributeName: titleStyle,
                                             NSForegroundColorAttributeName: [UIColor blackColor],
                                             };
                
                CGSize textRectSize = [mapName sizeWithAttributes:attributes];
                
                float textWidth = textRectSize.width + 10 < image.size.width?textRectSize.width + 10: image.size.width;
                
                CGRect textRect = (CGRect){
                    .origin.x =  image.size.width / 2 - textWidth /2 ,
                    .origin.y = image.size.height - textRectSize.height - 5,
                    .size.width = textWidth,
                    .size.height = textRectSize.height + 2
                };
                
                [[[UIColor alloc]initWithWhite:1.0 alpha:.2]  setFill];
                 UIRectFillUsingBlendMode(textRect, kCGBlendModePlusLighter);
                [mapName drawInRect:textRect withAttributes:attributes];
            }
            
            UIImage *compositeImage = UIGraphicsGetImageFromCurrentImageContext();
 
            (completionBlock)(  compositeImage, NULL);
            
            UIGraphicsEndImageContext();
         }
        else
        {
            (completionBlock)( NULL, error);

        }
        

    }];
 }

@end
