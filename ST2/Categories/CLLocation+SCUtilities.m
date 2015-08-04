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
//  CLLocation+SCUtilities.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 8/5/14.
//

#import "CLLocation+SCUtilities.h"

@implementation CLLocation (SCUtilities)



-(NSString *) altitudeString
{
    const double FT_PER_M  = 3.2808399;
    
    NSString* result =  @"-";
    
    if (self.verticalAccuracy > 0)
    {
        NSLocale *locale = [NSLocale currentLocale];
        BOOL isMetric = [[locale objectForKey:NSLocaleUsesMetricSystem] boolValue];
        
        static NSString *pm_str;
        
        if (pm_str == nil)
            pm_str = [[NSString alloc] initWithUTF8String:"\302\261"];
        
        if (isMetric)
        {
            if (self.verticalAccuracy == 0)
                result =  [NSString stringWithFormat:@"%dm", (int) round (self.altitude)];
            else
            {
                result =   [NSString stringWithFormat:@"%dm %@%gm",
                            (int) round (self.altitude), pm_str, round (self.verticalAccuracy)];
            }
        }
        else
        {
            if (self.verticalAccuracy == 0)
                result =   [NSString stringWithFormat:@"%dft", (int) (self.altitude * FT_PER_M)];
            else
            {
                result =   [NSString stringWithFormat:@"%dft %@%gft",
                            (int) round (self.altitude * FT_PER_M), pm_str,
                            round (self.verticalAccuracy * FT_PER_M)];
            }
        }
        
    }
    
    return result;
    
};

@end
