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
//  XMPPMessage+SilentCircle.m
//  SilentText
//

#import "AppConstants.h"
#import "XMPPMessage+SilentCircle.h"

#import "NSXMLElement+XMPP.h"
#import "XMPPElement+Delay.h"
#import "NSDate+XMPPDateTimeProfiles.h"
#import "XMPPDateTimeProfiles.h"

@implementation XMPPMessage (SilentCircle)

- (BOOL) isChatMessageWithSiren {
    
	if ([self isChatMessage]) {
        
		return (BOOL)[self elementForName: kSCPPSiren xmlns: kSCPPNameSpace];
	}
	return NO;

} // -isChatMessageWithSiren



- (NSDate*) addTimestamp {
    
    NSDate *timestamp = [self delayedDeliveryDate];
    if (!timestamp)
        timestamp = [[NSDate alloc] init];
    
    NSXMLElement *timestampElement = [NSXMLElement elementWithName:kSCPPTimestamp xmlns:kSCPPNameSpace];
    [self addChild:timestampElement];
    [timestampElement setStringValue:[timestamp xmppDateTimeString]];

    return timestamp;
}

- (NSDate*) timestamp {
    
    NSDate *date = nil;
    NSXMLElement  *timestampElement =  [self elementForName: kSCPPTimestamp xmlns: kSCPPNameSpace];
  
    if(timestampElement)
    {
        date =  [XMPPDateTimeProfiles parseDateTime: [timestampElement stringValue]];
     }
    
    return date;
}


@end
