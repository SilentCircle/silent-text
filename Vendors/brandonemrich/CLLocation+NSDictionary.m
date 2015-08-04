//
//  CLLocation+NSDictionary.m
//
//  Created by Brandon Emrich on 11/27/11.
//  Copyright (c) 2011 Zueos, Inc. All rights reserved.
//

// updated by Vinnie to use NSJSONSerialization


#import "CLLocation+NSDictionary.h"

@implementation CLLocation (NSDictionary)

- (id)initWithDictionary:(NSDictionary*)dictRep {
    CLLocationCoordinate2D coordinate = {};
    
    CLLocationAccuracy hAccuracy = -1.0;
    if ([dictRep objectForKey:@"latitude"] && [dictRep objectForKey:@"longitude"]) {
        hAccuracy = 0.0;
        
        CLLocationDegrees lat = [[dictRep objectForKey:@"latitude"] doubleValue];
        CLLocationDegrees lon = [[dictRep objectForKey:@"longitude"] doubleValue];
        coordinate = CLLocationCoordinate2DMake(lat, lon);
        
        if ([dictRep objectForKey:@"horizontalAccuracy"]) {
            hAccuracy = [[dictRep objectForKey:@"horizontalAccuracy"] doubleValue];
        }
    }
    
    CLLocationDistance altitude = 0.0;
    CLLocationAccuracy vAccuracy = -1.0;
    
    if ([dictRep objectForKey:@"altitude"]) {
        
        altitude = [[dictRep objectForKey:@"altitude"] doubleValue];
        
        if ([dictRep objectForKey:@"verticalAccuracy"]) {
            vAccuracy = [[dictRep objectForKey:@"verticalAccuracy"] doubleValue];
        }
        
    }
    
    NSDate* timestamp = nil;
    
    if ([dictRep objectForKey:@"timestamp"]) {
        
        NSTimeInterval epochTimestamp = [[dictRep objectForKey:@"timestamp"] doubleValue];
        timestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:epochTimestamp];
        
    } else {
        
        timestamp = [NSDate date];
    }
    
    // What about course and speed?
    
    return [self initWithCoordinate:coordinate altitude:altitude horizontalAccuracy:hAccuracy verticalAccuracy:vAccuracy timestamp:timestamp];
}

 
- (id)initWithJSON:(NSString*)json {
   
    return NULL;
    
 //   NSDictionary *dict = [json objectFromJSONString];
//    return [self initWithDictionary:dict];
}
 

- (NSDictionary*)dictionaryRepresentation {
    NSMutableDictionary* dictRep = [NSMutableDictionary dictionary];
    
    [dictRep setObject:[NSNumber numberWithDouble:self.coordinate.latitude] forKey:@"latitude"];
    [dictRep setObject:[NSNumber numberWithDouble:self.coordinate.longitude] forKey:@"longitude"];
    
    //   Using reference date since PHP and MySQL use Jan 1st 2001
    [dictRep setObject:[NSNumber numberWithDouble:[self.timestamp timeIntervalSinceReferenceDate]] forKey:@"timestamp"];
    [dictRep setObject:[NSNumber numberWithDouble:self.altitude] forKey:@"altitude"];
    
    //  Not Including these, only to lighten up HTTP requests
    //  [dictRep setObject:[NSNumber numberWithDouble:self.course] forKey:@"course"];
    //  [dictRep setObject:[NSNumber numberWithDouble:self.speed] forKey:@"speed"];
    
    [dictRep setObject:[NSNumber numberWithDouble:self.horizontalAccuracy] forKey:@"horizontalAccuracy"];
    [dictRep setObject:[NSNumber numberWithDouble:self.verticalAccuracy] forKey:@"verticalAccuracy"];
    
    return dictRep;
}


 
- (NSString*) JSONString {
    NSError *jsonError;
    
    NSString *jsonString = [NSString alloc];
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[self dictionaryRepresentation] options:NSJSONWritingPrettyPrinted error:&jsonError];
 
    if (jsonError==nil)
    {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    return jsonString;
   
}
 
@end


