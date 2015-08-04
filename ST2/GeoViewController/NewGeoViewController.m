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
//  NewGeoViewController.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 9/15/14.
//

#import "NewGeoViewController.h"
#import <MapKit/MapKit.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import "AppConstants.h"
#import "AppTheme.h"
#import "AvatarManager.h"
#import "STLogging.h"
#import "STLocalUser.h"
#import "STPreferences.h"
#import "SCDateFormatter.h"
#import "OHActionSheet.h"
#import "SilentTextStrings.h"
#import "GeoTracking.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG && eric_turner
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


@interface NewGeoViewController ()

@property (nonatomic, weak) IBOutlet MKMapView *mapView;
@property (nonatomic, weak) IBOutlet UIButton *btnMapViewPageCurl;

@end

@implementation NewGeoViewController
{
    BOOL isShowingMyLocation;
    CLLocation* currentLocation;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(locationDidUpdate:)
                                                 name:GeoTrackingWillUpdateNotification
                                               object:nil];
    
    
    if(!self.title)
        self.title = NSLocalizedString(@"Location", @"GeoViewController title");
     
}


- (void) dealloc {
    
    [NSNotificationCenter.defaultCenter removeObserver: self];
    
} // -dealloc


- (void) viewWillAppear:(BOOL)animated
{
     [self reloadMap];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void) locationDidUpdate: (NSNotification *) notification
{
    
    if(isShowingMyLocation)
        [self reloadMap];
    
}

 - (void)setMapPins:(NSArray *)mapPinsIn
{
    DDLogAutoTrace();
     
    _mapPins = mapPinsIn;
    [self reloadMap];
 }

- (void) reloadMap
{
     if (isShowingMyLocation)
        [[GeoTracking sharedInstance] beginTracking];
    else
        [[GeoTracking sharedInstance] stopTracking];

    currentLocation =  [[GeoTracking sharedInstance] currentLocation];
    
    MKMapType mapType = [STPreferences preferedMapType];
    if(mapType != _mapView.mapType )
        _mapView.mapType = mapType;

    // force refresh of drop pin
    for (id<MKAnnotation> annotation in _mapView.annotations) {
        [_mapView removeAnnotation:annotation];
    }
    
    NSMutableArray* pins = [NSMutableArray arrayWithArray:_mapPins];
 
    if(isShowingMyLocation)
    {
        STLocalUser* me = STDatabaseManager.currentUser;
        if(me.lastLocation || currentLocation)
        {
            // Note: SCDateFormatter caches the dateFormatter for us automatically
            NSDateFormatter *formatter =    [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
                                                                              timeStyle:NSDateFormatterShortStyle];
            

            SCMapPin* pin  = [[SCMapPin alloc] initWithLocation: currentLocation? currentLocation: me.lastLocation
                                                          title: me.displayName
                                                       subTitle: [formatter stringFromDate:me.lastLocation.timestamp]
                                                         image : NULL
                                                           uuid: me.uuid] ;
            
            [pins addObject:pin];
        }
    }
    
    [_mapView  addAnnotations:pins];

    for(SCMapPin *dropPin in _mapPins)
    {
        [_mapView  selectAnnotation:dropPin animated:YES];
     }
    
    
    [_mapView zoomToFitAnnotations:YES];
    
}


- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapViewIn
{
    // force refresh of drop pin, we need to do this to keep the selected annotation data in the the view
//    
//    for (id<MKAnnotation> annotation in _mapView.annotations) {
//        [mapViewIn removeAnnotation:annotation];
//    }
//    
//    [mapViewIn  addAnnotations:_mapPins];
//    
//    for(SCMapPin *dropPin in _mapPins)
//    {
//        [_mapView  selectAnnotation:dropPin animated:YES];
//        
//    }
//
//    [mapViewIn zoomToFitAnnotations:YES];
    
}



- (MKAnnotationView *)mapView:(MKMapView *)mapViewIn viewForAnnotation:(id<MKAnnotation>)annotation {
    MKAnnotationView *annotationView = [mapViewIn dequeueReusableAnnotationViewWithIdentifier:@"MapVC"];
    if (!annotationView) {
        annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"MapVC"];
        annotationView.canShowCallout = YES;
        //        annotationView.leftCalloutAccessoryView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
        annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        // could put a rightCalloutAccessoryView here
    } else {
        annotationView.annotation = annotation;
        //       [(UIImageView *)annotationView.leftCalloutAccessoryView setImage:nil];
    }
    
    return annotationView;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
    
    SCMapPin* dropPin = view.annotation;
    
    NSString *coordString = [NSString stringWithFormat:@"%@: %f\r%@: %f\r%@: %g",
                             NSLocalizedString(@"Latitude",@"Latitude"), dropPin.coordinate.latitude,
                             NSLocalizedString(@"Longitude",@"Longitude"), dropPin.coordinate.longitude,
                             NSLocalizedString(@"Altitude",@"Altitude"), dropPin.altitude];
    
    // ET 10/16/14 OHActionSheet update
    [OHActionSheet showFromRect:view.frame
                       sourceVC:self 
                         inView:self.view
                 arrowDirection:UIPopoverArrowDirectionDown
                          title:[NSString stringWithFormat: NSLocalizedString(@"Coordinates for %@ ",@"Coordinatesfor %@"), dropPin.title]
              cancelButtonTitle:NSLS_COMMON_CANCEL  
         destructiveButtonTitle:nil
              otherButtonTitles:@[NSLocalizedString(@"Open in Maps",@"Open in Maps"), NSLocalizedString(@"Copy",@"Copy")]
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                       
                       switch(buttonIndex)
                       {
                           case 0:
                           {
                               MKPlacemark *theLocation = [[MKPlacemark alloc] initWithCoordinate:dropPin.coordinate
                                                                                addressDictionary:nil];
                               MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:theLocation];
                               
                               if ([mapItem respondsToSelector:@selector(openInMapsWithLaunchOptions:)]) {
                                   [mapItem setName:dropPin.title];
                                   
                                   [mapItem openInMapsWithLaunchOptions:nil];
                               }
                               else {
                                   NSString *latlong = [NSString stringWithFormat: @"%f,%f",
                                                        dropPin.coordinate.latitude, dropPin.coordinate.longitude];
                                   
                                   NSString *url = [NSString stringWithFormat: @"http://maps.google.com/maps?ll=%@",
                                                    [latlong stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                   
                                   [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                               }
                           }
                               break;
                               
                           case 1:
                           {
                               UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                               NSMutableDictionary *items = [NSMutableDictionary dictionaryWithCapacity:1];
                               NSString *copiedString = [NSString stringWithFormat:@"%@ %@:\r%@",
                                                         NSLocalizedString(@"Location of", @"Location of"),
                                                         dropPin.title, coordString];
                               
                               [items setValue:copiedString forKey:(NSString *)kUTTypeUTF8PlainText];
                               pasteboard.items = [NSArray arrayWithObject:items];
                               
                           }
                               break;
                               
                           default:
                               break;
                       }
                       
                   }];
    
    
}

- (IBAction)showMapOptions:(UIButton *)sender
{
    DDLogAutoTrace();
    
#define NSLS_COMMON_Map NSLocalizedString(@"Map", @"Map")
#define NSLS_COMMON_Satellite NSLocalizedString(@"Satellite", @"Satellite")
#define NSLS_COMMON_Hybrid NSLocalizedString(@"Hybrid", @"Hybrid")
#define NSLS_COMMON_hideMe NSLocalizedString(@"Don't show my location", @"Don't show my location")
#define NSLS_COMMON_ShowMe NSLocalizedString(@"Show my location too", @"Show my location too")
    
    NSMutableArray* choices = @[].mutableCopy;
    
    switch (_mapView.mapType) {
        case MKMapTypeStandard :
            [choices addObjectsFromArray:@[NSLS_COMMON_Satellite, NSLS_COMMON_Hybrid]];
            break;
            
        case MKMapTypeSatellite :
            [choices addObjectsFromArray:@[NSLS_COMMON_Map, NSLS_COMMON_Hybrid]];
            break;
            
        case MKMapTypeHybrid :
            [choices addObjectsFromArray:@[NSLS_COMMON_Map, NSLS_COMMON_Satellite]];
            break;
    }
    
    if( [[GeoTracking sharedInstance] allowsTracking] || STDatabaseManager.currentUser.lastLocation)
    {
        [choices addObject:isShowingMyLocation ? NSLS_COMMON_hideMe : NSLS_COMMON_ShowMe];
    }
    else
    {
        isShowingMyLocation = NO;
    }
    
    // ET 10/16/14 OHActionSheet update
    [OHActionSheet showFromRect:sender.frame
                       sourceVC:self 
                         inView:self.view
                 arrowDirection:UIPopoverArrowDirectionAny
                          title:NSLocalizedString(@"Change Map Display Options", @"Change Map Display Options")
              cancelButtonTitle:NSLS_COMMON_CANCEL  
         destructiveButtonTitle:nil
              otherButtonTitles:choices
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {

                       NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
                       
                       if ([choice isEqualToString:NSLS_COMMON_Map])
                       {
                           _mapView.mapType = MKMapTypeStandard;
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_Satellite])
                       {
                           _mapView.mapType = MKMapTypeSatellite;
                           
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_Hybrid])
                       {
                           _mapView.mapType = MKMapTypeHybrid;
                           
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_hideMe])
                       {
                           isShowingMyLocation = NO;
                           [self reloadMap];
                           
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_ShowMe])
                       {
                           isShowingMyLocation = YES;
                           [self reloadMap];
                       }
                       
                       [STPreferences setPreferedMapType:_mapView.mapType];
                       
                   }];
    
}


@end
