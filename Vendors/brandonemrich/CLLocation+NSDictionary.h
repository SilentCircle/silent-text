//
//  CLLocation+NSDictionary.h
//
//  Created by Brandon Emrich on 11/27/11.
//  Copyright (c) 2011 Zueos, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface CLLocation (NSDictionary)

- (id)initWithDictionary:(NSDictionary*)dictRep;
- (NSDictionary*)dictionaryRepresentation;
- (NSString*) JSONString;

@end
