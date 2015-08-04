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
//  vCalendarViewController.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 5/22/14.
//


#import "AppDelegate.h"
#import "AppConstants.h"
#import "STPreferences.h"
#import "AddressBookManager.h"
#import "SilentTextStrings.h"
#import "UIImage+Thumbnail.h"
#import "ECPhoneNumberFormatter.h"
#import "STUser.h"
#import "AppTheme.h"
#import "STLogging.h"
#import "vCalendarViewController.h"
#import "CGICalendar.h"
#import "SCDateFormatter.h"
#import "NSDate+SCDate.h"

// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
static const int ddLogLevel = LOG_LEVEL_INFO | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@interface vCalendarViewController ()

@property (nonatomic, strong) SCloudObject * scloud;
@property (nonatomic, strong) NSString     * cardName;

@end

#pragma mark -

@implementation vCalendarViewController
{
	AppTheme *theme;
	
	NSDictionary*      eventInfo;
    
    UITapGestureRecognizer* locationLabelGesture;
    UITapGestureRecognizer* urlLabelGesture;

    CLLocation*        eventGeo;
    NSURL*             eventURL;
    UIDocumentInteractionController* uiDocController;
}

@synthesize containerView = containerView;


@synthesize summaryLabel = summaryLabel;
@synthesize locationLabel = locationLabel;
@synthesize dateLabel = dateLabel;
@synthesize urlLabel = urlLabel;
@synthesize eventNoteView = eventNoteView;

@synthesize importButton;
@synthesize previewButton;

- (id)initWithSCloud:(SCloudObject *)inScloud
{
	if ((self = [super initWithNibName:@"vCalendarViewController" bundle:nil]))
	{
  		_scloud = inScloud;
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
	DDLogAutoTrace();
	[super viewDidLoad];
	
	self.navigationItem.title = NSLocalizedString(@"Event Details", @"vCalendar nav title");
	
	theme = [AppTheme getThemeBySelectedKey];
	
    summaryLabel.text = @"";
    locationLabel.text = @"";
    urlLabel.text = nil;
    eventNoteView.text = @"";
    dateLabel.text = @"";
    eventGeo  = NULL;
    eventURL = NULL;
    eventInfo = NULL;
	
	NSError *error = nil;
	NSDictionary *iCalDict = [self parseiCalFile:_scloud.decryptedFileURL error:&error];
	if (iCalDict)
	{
        eventInfo = iCalDict;
        summaryLabel.text = [iCalDict objectForKey:@"SUMMARY"];
        eventNoteView.text = [iCalDict objectForKey:@"NOTES"];
        
        NSDate *startDate = [iCalDict objectForKey:@"DTSTART"];
        NSDate *endDate = [iCalDict objectForKey:@"DTEND"];
        BOOL allDay = [[iCalDict objectForKey:@"ALLDAY"] boolValue];
        
        dateLabel.text = [self formatPeriodwithTime:startDate endTime:endDate allDay:allDay];
        
        locationLabel.text = [iCalDict objectForKey:@"LOCATION"];
    
        eventURL = [iCalDict objectForKey:@"URL"];
        if(eventURL)
            urlLabel.text = eventURL.absoluteString;
        
        eventGeo = [iCalDict objectForKey:@"GEO"];
    }
    
    if(eventURL)
    {
        urlLabel.textColor = theme.appTintColor;
        urlLabelGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(urlLabelTapped:)];
        [urlLabel addGestureRecognizer:urlLabelGesture];
	}
    
    if(eventGeo)
    {
        locationLabel.textColor =   theme.appTintColor;
        locationLabelGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(locationLabelTapped:)];
        [locationLabel addGestureRecognizer:locationLabelGesture];
    }
	
	// Add constraint between containerView & topLayoutGuide
	
	NSLayoutConstraint *topLayoutGuideConstraint =
	  [NSLayoutConstraint constraintWithItem:containerView
	                               attribute:NSLayoutAttributeTop
	                               relatedBy:NSLayoutRelationEqual
	                                  toItem:self.topLayoutGuide
	                               attribute:NSLayoutAttributeBottom
	                              multiplier:1.0
	                                constant:0.0];
	
	[self.view removeConstraint:[self topConstraintFor:containerView]];
	[self.view addConstraint:topLayoutGuideConstraint];
	
	// Register for notifications
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(applicationDidEnterBackground:)
	                                             name:UIApplicationDidEnterBackgroundNotification
	                                           object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
	
    if(_scloud.fyeo)
    {
        [previewButton setEnabled:NO];
        [importButton setEnabled:NO];
	}

    // We don't support this yet.
	[importButton setEnabled:NO];
}

//- (void)viewWillDisappear:(BOOL)animated
//{
//	DDLogAutoTrace();
//	[super viewWillDisappear:animated];
//	
//	// Note: This is getting hit when we push the map...
//	//
//	// So then why are we nil'ing this out ???
//    _scloud = NULL;
//}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSLayoutConstraint *)topConstraintFor:(id)item
{
	for (NSLayoutConstraint *constraint in self.view.constraints)
	{
		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeTop) ||
		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeTop))
		{
			return constraint;
		}
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	if ([self.delegate respondsToSelector:@selector(vCalendarViewController:needsHidePopoverAnimated:)]) {
		[self.delegate vCalendarViewController:self needsHidePopoverAnimated:NO];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handleActionBarDone
{
	DDLogAutoTrace();
	
	[self.navigationController popViewControllerAnimated:YES];
}

/*ET 02/03/15
 * ST-916 DEPRECATED - remove shared vCard and calendar preview feature;
 * preview workflow will be re-written */
- (IBAction)previewButtonTapped:(id)sender
{
    NSAssert(false, @"THIS METHOD HAS BEEN DEPRECATED at line %d",__LINE__);
    return;
	
	if ([self.delegate respondsToSelector:@selector(vCalendarViewController:previewVCalender:)]) {
        [self.delegate vCalendarViewController:self previewVCalender:_scloud];
    }
}

- (void)locationLabelTapped:(UIGestureRecognizer *)gestureRecognizer
{
	DDLogAutoTrace();

	if ([self.delegate respondsToSelector:@selector(vCalendarViewController:showMapForEvent:atLocation:andTime:)])
	{
        
        NSString* eventName =  [eventInfo objectForKey:@"SUMMARY"];
        
		[self.delegate vCalendarViewController:self
		                       showMapForEvent:eventName
		                            atLocation:eventGeo
		                               andTime:[NSDate date]];
    }
}

- (void)urlLabelTapped:(UIGestureRecognizer *)gestureRecognizer
{
	DDLogAutoTrace();

	if ([self.delegate respondsToSelector:@selector(vCalendarViewController:showURLForEvent:)]) {
        [self.delegate vCalendarViewController:self showURLForEvent:eventURL ];
    }
}

- (IBAction)importButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
	if (!uiDocController)
	{
		uiDocController = [UIDocumentInteractionController interactionControllerWithURL: _scloud.decryptedFileURL];
	}
	else
	{
		uiDocController.URL = _scloud.decryptedFileURL;
	}
	
	uiDocController.UTI = _scloud.mediaType;
	
	if ( ! [uiDocController presentOptionsMenuFromRect:importButton.frame inView:self.view animated:YES])
	{
		// ?
	}
}

#pragma mark - iCal parsing

- (NSString *)formatPeriodwithTime:(NSDate*)startTime
                             endTime:(NSDate*)endTime
                              allDay:(BOOL)allDay
{
    NSString *dateText = @"";
    BOOL isSameDay = NO;
  
    NSCalendarUnit units = 0;
	if (allDay)
		units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
	else
		units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
    
    
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	NSDateComponents *components;
    
    NSDateFormatter* dateFormatter = nil;
    NSDateFormatter* timeFormatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterNoStyle
                                                      timeStyle:NSDateFormatterShortStyle];
	
	if (endTime)
	{
		components = [gregorian components:units fromDate:startTime toDate:endTime options:0];
    }
	else
	{
		components = [gregorian components:units fromDate:startTime toDate:startTime options:0];
    }
    
    isSameDay = [components day] == 0;
    
    if(isSameDay)
    {
        dateFormatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
                                                          timeStyle:NSDateFormatterNoStyle];

        
        dateText = [dateText stringByAppendingString: [dateFormatter stringFromDate:startTime]];
        if(allDay)
        {
            dateText = [dateText stringByAppendingString: @"\tAll Day"];
        }
        else
        {
            dateText = [dateText stringByAppendingString: @" \t"];
            dateText = [dateText stringByAppendingString: [timeFormatter stringFromDate:startTime]];
            dateText = [dateText stringByAppendingString: @" to "];
            dateText = [dateText stringByAppendingString: [timeFormatter stringFromDate:endTime]];
        }
    }
    else
    {
        dateText = [dateText stringByAppendingString: @"from "];
        if(allDay)
        {
            dateFormatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterFullStyle
                                                                               timeStyle:NSDateFormatterNoStyle];
            
            dateText = [dateText stringByAppendingString: [dateFormatter stringFromDate:startTime]];
            dateText = [dateText stringByAppendingString: @"\nto "];
            dateText = [dateText stringByAppendingString: [dateFormatter stringFromDate:endTime]];
      }
        else
        {
            dateFormatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
                                                              timeStyle:NSDateFormatterNoStyle];
            

            dateText = [dateText stringByAppendingString: [timeFormatter stringFromDate:startTime]];
            dateText = [dateText stringByAppendingString: @", "];
            dateText = [dateText stringByAppendingString: [dateFormatter stringFromDate:startTime]];
            dateText = [dateText stringByAppendingString: @"\nto "];
            dateText = [dateText stringByAppendingString: [timeFormatter stringFromDate:endTime]];
            dateText = [dateText stringByAppendingString: @", "];
            dateText = [dateText stringByAppendingString: [dateFormatter stringFromDate:endTime]];
        }
       
    }
    
    return dateText;
}


- (NSString *)unescapeString :(NSString *) inStr
{
    NSString *retStr = inStr;
   if(retStr)
   {
       retStr = [retStr stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
       retStr = [retStr stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
       retStr = [retStr stringByReplacingOccurrencesOfString:@"\\," withString:@","];
      
   }

    return retStr;
}

-(NSDate*)adjustTimeForZone:(NSString*)zoneName
                       date:(NSDate*)date
                 offsetMins:(NSInteger)offsetMins
                   withRule:(NSMutableDictionary*)tzRules
{
    NSDate* result = date;
  
    if(zoneName && tzRules && date)
    {
        NSArray* rules = [tzRules objectForKey:zoneName];

        NSDictionary* useRule = NULL;
        NSDate* useRuleDate = NULL;
        
        for (NSDictionary* rule in rules)
        {
            NSString* startRule = [rule objectForKey:@"DTSTART"];
            NSDate* rDate = [NSDate dateWithICalendarString:startRule];
            if(![date isAfter:rDate]) continue;
            
            if(!useRuleDate || [rDate isAfter:useRuleDate])
            {
                useRuleDate =rDate;
                useRule = rule;
                continue;
            }
          }
        
        
        if(useRule)
        {
            DDLogOrange(@"TZD %@ %@", [useRule objectForKey:@"TZNAME"] , useRuleDate);
            int tzoffsetTo = [[useRule objectForKey:@"TZOFFSETTO"] intValue];
            int offsetHours = tzoffsetTo/100;
            int offsetMin   = tzoffsetTo - (offsetHours * 100);
            int tzOffsetMin = (offsetHours * 60) + offsetMin;
            
    //        int offsetDif = offsetMins ;
            
            result = [NSDate dateWithTimeInterval: -tzOffsetMin * 60 sinceDate: date];
 
        }
        
    }
    else
    {
           
        result = [NSDate dateWithTimeInterval: -offsetMins * 60 sinceDate: date];
  
    }
  
    
    
    return result;
}


-(NSDictionary*) parseiCalFile:(NSURL*) icalFileURL error:(NSError**)error;
{
    NSMutableDictionary* iCalDict = @{}.mutableCopy;
    
    CGICalendar *ical = [[CGICalendar alloc] init];
    
    NSTimeZone *localTime = [NSTimeZone localTimeZone];
    BOOL isDST = [localTime isDaylightSavingTime];
    
    NSMutableDictionary *tzRules = @{}.mutableCopy;
    
    if ([ical parseWithPath:icalFileURL.path error:error]) {
        
           for (CGICalendarObject *icalObj in [ical objects]) {
            
            for (CGICalendarComponent *icalComp in [icalObj components]) {
                
                if(icalComp.isTimezone)
                {
                    DDLogPurple(@"TZID: %@", [ icalComp propertyValueForName:@"TZID"]);
                    
                    NSString* tzid = [ icalComp propertyValueForName:@"TZID"];
                    
                    NSMutableArray *rules = @[].mutableCopy;
                    
                    for (CGICalendarComponent *tzc in [icalComp components])
                    {
                        
                        if(!isDST)
                        {
                            if([tzc.type isEqualToString:@"DAYLIGHT"]) continue;
                        }
                        else
                        {
                            if([tzc.type isEqualToString:@"STANDARD"]) continue;
                        };
                        
                        DDLogPurple(@"%@  ",tzc.type);
                        NSMutableDictionary *rule = @{}.mutableCopy;
                        
                        for (CGICalendarProperty *tzp in tzc.properties )
                        {
                            [rule setObject:tzp.value forKey:tzp.name];
                            DDLogPurple(@"%@ - %@",tzp.name,  tzp.value);
                        }
                        if (rule.count)
                            [rules addObject:rule];
                    }
                    if(rules.count)
                        [tzRules setObject:rules forKey:tzid];
                }
                
                
                if(icalComp.isEvent)
                {
                     if(icalComp.summary)
                         [iCalDict setObject: [self unescapeString:icalComp.summary] forKey:@"SUMMARY"];
                    
                    if(icalComp.notes)
                        [iCalDict setObject: [self unescapeString:icalComp.notes] forKey:@"NOTES"];
                    
                    if(icalComp.dateTimeStart)
                    {
                        NSDate* date = [self adjustTimeForZone:icalComp.zoneTimeStart
                                                          date:icalComp.dateTimeStart
                                                    offsetMins:[localTime secondsFromGMT]/60 withRule:tzRules];
                      
                            [iCalDict setObject: date forKey:@"DTSTART"];
                    }
                    else
                    {
                        NSString* dateString = [icalComp propertyValueForName:@"DTSTART"];
                        
                          // Use cached dateFormatter in thread dictionary
                        NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithLocalizedFormat: @"yyyyMMdd"
                                                                                                locale:nil
                                                                                              timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
                         NSDate* date =  [formatter dateFromString:dateString];
                        
                        date = [NSDate dateWithTimeInterval: -[localTime secondsFromGMT] sinceDate: date];
                   
                        [iCalDict setObject: date forKey:@"DTSTART"];
                        [iCalDict setObject: @YES forKey:@"ALLDAY"];
                        
                    }
                    
                    if(icalComp.dateTimeEnd)
                    {
                        NSDate* date = [self adjustTimeForZone:icalComp.zoneTimeEnd
                                                          date:icalComp.dateTimeEnd
                                                    offsetMins:[localTime secondsFromGMT]/60 withRule:tzRules];
                        [iCalDict setObject: date forKey:@"DTEND"];
                    }
                    else
                    {
                        NSString* dateString = [icalComp propertyValueForName:@"DTEND"];
                        
                        // Use cached dateFormatter in thread dictionary
                        NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithLocalizedFormat: @"yyyyMMdd"
                                                                                                locale:nil
                                                                                              timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
                        NSDate* date =  [formatter dateFromString:dateString];
                        
                        date = [NSDate dateWithTimeInterval: -[localTime secondsFromGMT] sinceDate: date];
                        
                        [iCalDict setObject: date forKey:@"DTEND"];
                        [iCalDict setObject: @YES forKey:@"ALLDAY"];
                        
                    }
                    
                    
                    if(icalComp.dateTimeEnd)
                    {
//                        NSDate* date = [self adjustTimeForZone:icalComp.zoneTimeEnd date:icalComp.dateTimeEnd withRule:tzRules];
//                        [iCalDict setObject: date forKey:@"DTEND"];
                    }
                    
                    if(icalComp.location && ![iCalDict objectForKey:@"LOCATION"])
                        [iCalDict setObject: [self unescapeString:icalComp.location] forKey:@"LOCATION"];
  
                    if(icalComp.url)
                        [iCalDict setObject: icalComp.url forKey:@"URL"];
                    
                    
                    for (CGICalendarProperty *icalProp in [icalComp properties])
                    {
                                             DDLogPurple(@"%@ - %@",[icalProp name], [icalProp value]);
                        
                        NSString *icalPropName = [icalProp name];
                        
                        if([icalPropName isEqualToString:@"X-APPLE-STRUCTURED-LOCATION"])
                        {
                            NSArray * items = [icalProp.value componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":,"]];
                            if([items.firstObject isEqualToString:@"geo"])
                            {
                                CLLocationDegrees latitutde = [[items objectAtIndex:1] doubleValue];
                                CLLocationDegrees longitude = [[items objectAtIndex:2] doubleValue];
                                
                                CLLocation* geo = [[CLLocation alloc] initWithLatitude:latitutde longitude:longitude];
                                
                                 [iCalDict setObject: geo forKey:@"GEO"];
                            }
                            
                            for(CGICalendarProperty *param in icalProp.parameters)
                            {
                                if([param.name isEqualToString:@"X-TITLE"])
                                {
                                    [iCalDict setObject: [self unescapeString:param.value] forKey:@"LOCATION"];
                                    
                                }
                            }
                        }
                        
                    }
                    
                }
                
                
            }
        }
    }
    
    return iCalDict;
    
}

@end
