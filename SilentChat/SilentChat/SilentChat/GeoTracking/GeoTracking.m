/*
Copyright © 2012, Silent Circle
All rights reserved.

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
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "AppConstants.h"
#import "App.h"
#import "ServiceCredential.h"
#import "GeoTracking.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

/*
 App *app = App.sharedApp;
 
 NSString *geotrackingKeyIdentifier = [NSString stringWithFormat: kGeoTrackingKeyFormat, app.identifier];
 ServiceCredential *geoTrackingKey = [ServiceCredential.alloc initWithService: geotrackingKeyIdentifier];
 //   apiKey.data = [ geoTrackingString dataUsingEncoding :NSUTF8StringEncoding];

 */
 
@interface GeoTracking()
 
 
@property (strong, nonatomic) CLLocationManager *locationManager;

@property (strong, nonatomic) CLLocation *lastLocation;

@end

@implementation GeoTracking
@dynamic  isTracking;


NSString *const kGeoTrackingFormat    = @"%@.geotracking";
NSString *const kIsTrackingKey    = @"isTracking";

 
#pragma mark - GeoTracking

- (GeoTracking *) init {
	
	self = [super init];
	
	if (self) {
        CLLocationManager *lm = CLLocationManager.new;
        lm.delegate = self;
        lm.desiredAccuracy = kCLLocationAccuracyKilometer;
        
        self.locationManager = lm;
        self.lastLocation = NULL;

      }
	return self;
	
} // init


- (NSData*) trackingValue
{
    App *app = App.sharedApp;
    
    NSString *apiKeyIdentifier = [NSString stringWithFormat: kGeoTrackingFormat, app.identifier];
    ServiceCredential *trackingValue = [ServiceCredential.alloc initWithService: apiKeyIdentifier];
    
    return (trackingValue.data);
}


- (void) setTracking:(BOOL)isTracking
{
    App *app = App.sharedApp;
    NSError *error;
     
    if(!isTracking)
    {
        [self.locationManager  stopUpdatingLocation];
    }

    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithBool: isTracking], kIsTrackingKey ,
                                nil];
    
    NSData *jsondata = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (error==nil)
    {
        NSString *jsonString = [[NSString alloc] initWithData:jsondata encoding:NSUTF8StringEncoding];
        NSString *gtKeyIdentifier = [NSString stringWithFormat: kGeoTrackingFormat, app.identifier];
        ServiceCredential *gtKey = [ServiceCredential.alloc initWithService: gtKeyIdentifier];
        
        gtKey.data = [ jsonString dataUsingEncoding :NSUTF8StringEncoding];
    }

    
}

- (BOOL) tracking {
    
    BOOL trackValue = NO;
    
    if(self.trackingValue)
    {
        NSError *error;
 
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData: self.trackingValue options:0 error:&error];
        
         if (error==nil){
             
             trackValue = [[dict valueForKey:kIsTrackingKey] boolValue];
         }
    }
     
    return trackValue;
}

- (void) startUpdating
{
    if(self.isTracking)
    {
        [self.locationManager  startUpdatingLocation];
    }

}

- (void) stopUpdating
{
    [self.locationManager  stopUpdatingLocation];
    self.lastLocation = NULL;
    

}


- (BOOL) isTracking {
     return self.tracking;
    
} // -isTracking

- (BOOL) allowTracking
{
   return ([CLLocationManager locationServicesEnabled] &&
           [CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied);
        
}

- (CLLocation*) location
{
    return self.lastLocation;
}

#pragma mark - Location Manager delagate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    
    DDGDesc(newLocation);
    
    self.lastLocation = newLocation;
    
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    
     self.lastLocation = NULL;

    
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
     
    if(status != kCLAuthorizationStatusAuthorized)
        self.lastLocation = NULL;
    
}



@end
