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
#import "STLogging.h"
#import "GeoTracking.h"
#import "AppConstants.h"


// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE; // | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


NSString *const  GeoTrackingWillUpdateNotification = @"GeoTrackingWillUpdateNotification";

const NSTimeInterval kLocationStaleTime = 60 * 10;
const NSTimeInterval kLocationAccuracyThreshold = 100.0;

@interface GeoTracking ()
@property (atomic, copy, readwrite) CLLocation *lastLocation;
@end

@implementation GeoTracking
{
	CLLocationManager *locationManager;
	BOOL tracking;
}

static GeoTracking *sharedInstance;

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		sharedInstance = [[GeoTracking alloc] init];
  	}
}

+ (GeoTracking *)sharedInstance
{
	return sharedInstance;
}

@synthesize lastLocation = __lastLocation_noDirectAccess_MUST_goThroughAtomicProperty;

- (id)init
{
	NSAssert(sharedInstance == nil, @"You MUST use sharedInstance");
	
	if ((self = [super init]))
	{
		locationManager = [[CLLocationManager alloc] init];
        locationManager.delegate = self;
        
	//	lm.desiredAccuracy = kCLLocationAccuracyKilometer; // don't specify, use the default
		
		self.lastLocation = nil;
		
 		[[NSNotificationCenter defaultCenter] addObserver: self
		                                         selector: @selector(handleEnteredBackground:)
		                                             name: UIApplicationDidEnterBackgroundNotification
		                                           object: nil];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
		                                         selector: @selector(handleEnteredForground:)
		                                             name: UIApplicationWillEnterForegroundNotification
		                                           object: nil];
	}
	return self;
}

- (CLLocation *)currentLocation
{
	CLLocation *lastLocation = self.lastLocation;
	if (lastLocation)
	{
		NSTimeInterval howRecent = [lastLocation.timestamp timeIntervalSinceNow];
		
		if (fabs(howRecent) < kLocationStaleTime) {
			return lastLocation;
		}
    }
	
	return nil;
}

- (void)handleEnteredForground:(NSNotification *)notification
{
    if (tracking)
	{
//        DDLogOrange(@"startUpdatingLocation - forground");
        [locationManager  startUpdatingLocation];
    }
}

- (void)handleEnteredBackground:(NSNotification *)notification
{
    if(tracking)
    {
//        DDLogOrange(@"stopUpdatingLocation - background");
        [locationManager stopMonitoringSignificantLocationChanges];
        [locationManager  stopUpdatingLocation];

    }
}


- (BOOL)beginTracking
{
	DDLogAutoTrace();
	
	// Todo: This method is NOT thread-safe.
	// Should it be?
	// If not then we should add something like:
	//   NSAssert([NSThread isMainThread], @"Oops")
	// to make sure it's only called from the main thread.
  
    BOOL willTrack = NO;
    
    if ([self allowsTracking])
    {
        tracking = YES;
        [locationManager startUpdatingLocation];
        willTrack = YES;
    }
    else
    {
        [self askForPermision];
    }
   
    
    return willTrack;
    
}

-(void) askForPermision
{
    if(AppConstants.isIOS8OrLater )
    {
        [locationManager requestWhenInUseAuthorization];
    }

}

- (void)stopTracking
{
	DDLogAutoTrace();
	
	// Todo: This method is NOT thread-safe.
	// Should it be?
	// If not then we should add something like:
	//   NSAssert([NSThread isMainThread], @"Oops")
	// to make sure it's only called from the main thread.
	
	tracking = NO;
	
	[locationManager stopMonitoringSignificantLocationChanges];
	[locationManager stopUpdatingLocation];
}


- (BOOL)allowsTracking
{
    BOOL allowed = NO;
    
    CLAuthorizationStatus status = kCLAuthorizationStatusNotDetermined;
    
    if([CLLocationManager locationServicesEnabled] )
    {
        status = [CLLocationManager authorizationStatus];
        
        if( !AppConstants.isIOS8OrLater && status == kCLAuthorizationStatusNotDetermined)
        {
            tracking = YES;
            [locationManager startUpdatingLocation];
            allowed = YES;
        }
        else
        {
			CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
			allowed = (authorizationStatus == kCLAuthorizationStatusAuthorizedAlways)
			       || (authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse);
		}
    }
    
    return allowed;
}




#pragma mark CLLocationManager Delegate

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
//	DDLogInfo(@"%@", THIS_METHOD);
  
    BOOL isCloseBy = NO;
    CLLocationDistance  distance = 0;
    
    if ([self currentLocation])
	{
		distance  = [[self currentLocation] distanceFromLocation: newLocation];
		isCloseBy = (distance < kLocationAccuracyThreshold/2);
	}

	self.lastLocation = newLocation;
    
//    DDLogOrange(@"didUpdateToLocation %@ - %f" , @(isCloseBy), distance);

	if (newLocation.horizontalAccuracy < kLocationAccuracyThreshold && isCloseBy)
	{
		// Optional: turn off location services once we've gotten a good location
		
		[locationManager stopUpdatingLocation];
		[locationManager startMonitoringSignificantLocationChanges];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:GeoTrackingWillUpdateNotification object:self];
        
    }

}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
	DDLogInfo(@"%@ %@", THIS_METHOD, error);
	
	self.lastLocation = nil;
    tracking = NO;
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
	DDLogInfo(@"%@ %d", THIS_METHOD, status);
	
	if (status != kCLAuthorizationStatusAuthorizedAlways) {
		self.lastLocation = nil;
	}
}

@end
