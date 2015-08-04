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
//  NSDictionary+SCDictionary.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 11/1/13.
//

#import "NSDictionary+SCDictionary.h"
#import "NSString+SCUtilities.h"

@implementation NSDictionary (SCDictionary)


- (void )filterEntriesFromMetaDataTo:(NSMutableDictionary *) metaDict
{
    
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        //NSLog(key);
        // these are the types seen today.  We don't like MakerApple
        //DPIHeight
        //{Exif}
        //{MakerApple}
        //DPIWidth
        //Orientation
        //{TIFF}
        if ([key isEqualToString:@"{Exif}"] ||
            [key isEqualToString:@"DPIHeight"] ||
            [key isEqualToString:@"DPIWidth"] ||
            [key isEqualToString:@"PixelHeight"] ||
            [key isEqualToString:@"PixelWidth"] ||
            [key isEqualToString:@"Depth"] ||
            [key isEqualToString:@"ColorModel"] ||
            [key isEqualToString:@"Orientation"] ||
            [key isEqualToString:@"{GPS}"] ||
            [key isEqualToString:@"{TIFF}"] ||
            [key isEqualToString:@"{PNG}"])
            [metaDict setObject:self[key] forKey:key];
    }];
  
}



+ (NSDictionary *) parameterDictionaryFromURL:(NSURL *)url schemeKey:(NSString*)schemeKey usingScheme:(NSString*)scheme
{
    NSMutableDictionary *parameterDictionary = [[NSMutableDictionary alloc] init];
    
    if ([[url scheme] isEqualToString:scheme]) {
        NSString *mailtoParameterString = [[url absoluteString] substringFromIndex:[scheme length]+1];
        NSUInteger questionMarkLocation = [mailtoParameterString rangeOfString:@"?"].location;
        [parameterDictionary setObject:[mailtoParameterString substringToIndex:questionMarkLocation] forKey:schemeKey];
        
        if (questionMarkLocation != NSNotFound) {
            NSString *parameterString = [mailtoParameterString substringFromIndex:questionMarkLocation + 1];
            NSArray *keyValuePairs = [parameterString componentsSeparatedByString:@"&"];
            for (NSString *queryString in keyValuePairs) {
                NSArray *keyValuePair = [queryString componentsSeparatedByString:@"="];
                if (keyValuePair.count == 2)
                    [parameterDictionary setObject:[[keyValuePair objectAtIndex:1] urlDecodedString] forKey:[[keyValuePair objectAtIndex:0] urlDecodedString]];
            }
        }
    }
    else {
        NSString *parameterString = [url parameterString];
        NSArray *keyValuePairs = [parameterString componentsSeparatedByString:@"&"];
        for (NSString *queryString in keyValuePairs) {
            NSArray *keyValuePair = [queryString componentsSeparatedByString:@"="];
            if (keyValuePair.count == 2)
                [parameterDictionary setObject:[[keyValuePair objectAtIndex:1] urlDecodedString] forKey:[[keyValuePair objectAtIndex:0] urlDecodedString]];
        }
    }
    
    return [parameterDictionary copy];
}

 
@end
