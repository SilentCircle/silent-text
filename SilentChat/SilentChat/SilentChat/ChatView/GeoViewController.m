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
//  GeoViewController.m
//  SilentText
//

#import "GeoViewController.h"
#import "GeoViewOptionsViewController.h"
#import "MobileCoreServices/UTCoreTypes.h"
#import "MZAlertView.h"

@interface GeoViewController ()

@end

@implementation GeoViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
		self.dropPin = [[ChatSenderMapAnnotation alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
//	self.dataSource = self;
//	self.delegate = self;
}

- (void)setCoord:(CLLocationCoordinate2D)coord withName:(NSString *)name andTime:(NSDate *)date andAltitude:(double)altitude
{
	[self.mapView setCenterCoordinate:coord animated:NO];
	MKCoordinateRegion mapRegion;
    mapRegion.center = coord;
    mapRegion.span = MKCoordinateSpanMake(0.2, 0.2);
    [self.mapView setRegion:mapRegion animated: YES];
	//	- (MKAnnotationView *)viewForAnnotation:(id < MKAnnotation >)annotation
	
	_dropPin.name = name;
	_dropPin.date = date;
	_dropPin.coordinate = coord;
	_dropPin.altitude = altitude;
}

-(IBAction)showOptions:(id)sender
{
	GeoViewOptionsViewController *geovco = [GeoViewOptionsViewController.alloc initWithNibName: @"GeoViewOptionsViewController" bundle: nil];
	geovco.modalPresentationStyle = UIModalPresentationFullScreen;
	geovco.modalTransitionStyle = UIModalTransitionStylePartialCurl;
	geovco.delegate = self;
	[self presentModalViewController:geovco animated:YES];
}
//- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
//    MKCoordinateRegion mapRegion;
//    mapRegion.center = map.userLocation.coordinate;
//    mapRegion.span = MKCoordinateSpanMake(0.2, 0.2);
//    [map setRegion:mapRegion animated: YES];
//}
- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView
{
	[self.mapView addAnnotation:_dropPin];
	[self.mapView selectAnnotation:_dropPin animated:YES];

}


- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:@"MapVC"];
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
	// ???: do we want anything like "Go to Maps"?

	NSString *coordString = [NSString stringWithFormat:@"%@: %f\r%@: %f\r%@: %g",
							NSLocalizedString(@"Latitude",@"Latitude"), _dropPin.coordinate.latitude,
							NSLocalizedString(@"Longitude",@"Longitude"), _dropPin.coordinate.longitude,
							NSLocalizedString(@"Altitude",@"Altitude"), _dropPin.altitude];
	MZAlertView *alert = [[MZAlertView alloc]
						  initWithTitle: NSLocalizedString(@"Coordinates",@"Coordinates")
						  message: coordString
						  delegate: self
						  cancelButtonTitle:NSLocalizedString(@"Done",@"Done")
						  otherButtonTitles:NSLocalizedString(@"Open in Maps",@"Open in Maps"), NSLocalizedString(@"Copy",@"Copy"), nil];
	
	[alert show];
	
	[alert setActionBlock: ^(NSInteger buttonPressed, NSString *alertText){
		switch(buttonPressed)
		{
			case 1:
			{
				MKPlacemark *theLocation = [[MKPlacemark alloc] initWithCoordinate:_dropPin.coordinate addressDictionary:nil];
				MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:theLocation];

				if ([mapItem respondsToSelector:@selector(openInMapsWithLaunchOptions:)]) {
					[mapItem setName:_dropPin.name];
					
					[mapItem openInMapsWithLaunchOptions:nil];
				}
				else {
					NSString *latlong = [NSString stringWithFormat: @"%f,%f", _dropPin.coordinate.latitude, _dropPin.coordinate.longitude];
					NSString *url = [NSString stringWithFormat: @"http://maps.google.com/maps?ll=%@",
									 [latlong stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
					[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];

				}
			}
				break;
				
			case 2:
			{
				UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
				NSMutableDictionary *items = [NSMutableDictionary dictionaryWithCapacity:1];
				NSString *copiedString = [NSString stringWithFormat:@"%@ %@:\r%@", NSLocalizedString(@"Location of", @"Location of"), _dropPin.name, coordString];
				[items setValue:copiedString forKey:(NSString *)kUTTypeUTF8PlainText];
				pasteboard.items = [NSArray arrayWithObject:items];

			}
				break;
				
			default:
				break;
		}
		
	}];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) dismissGeoViewOptions
{

}

- (void) changeMapStyle:(MKMapType) mapType
{
	_mapView.mapType = mapType;
	
}
- (MKMapType) getMapStyle
{
	return _mapView.mapType;
	
}

//
//
//- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
//{
//	return nil;
//}
//- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
//{
//	return nil;
//}
//
//- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController
//{
//	return 0;
//}
//
//- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController
//{
//	return 0;
//}
@end
