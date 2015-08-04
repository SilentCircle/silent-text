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
//
//  NSDictionary+vCard.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 11/18/13.
//

#import "AppConstants.h"
#import "NSDictionary+vCard.h"
#import <AddressBook/AddressBook.h>

@implementation NSDictionary (vCard)


+ (NSArray *)peopleFromvCardData:(NSData *)vCardDataIn
{
    NSMutableArray* result = [NSMutableArray array];

    @autoreleasepool {
        
        NSArray* vCardPeople = (__bridge NSArray*)ABPersonCreatePeopleInSourceWithVCardRepresentation(NULL, (__bridge CFDataRef)vCardDataIn);
        
        
        for (NSUInteger i = 0; i < [vCardPeople count]; i++)
        {
            ABRecordRef person = (__bridge ABRecordRef)[vCardPeople objectAtIndex:i];
            NSArray *people = [NSArray arrayWithObject:(__bridge id)(person)];
            
            NSString *userName = NULL;
            NSString *userJid = NULL;
            
            NSString *firstName =
            (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
            NSString *lastName =
            (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
            NSString *compositeName =
            (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
            NSString *organization =
            (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonOrganizationProperty);
            NSData *imageData =
            (__bridge_transfer NSData *)  ABPersonCopyImageDataWithFormat(person, kABPersonImageFormatThumbnail);
            NSData *vCardData =
            (__bridge_transfer NSData *)  ABPersonCreateVCardRepresentationWithPeople((__bridge CFArrayRef)people);
            
            NSMutableDictionary *info = @{
                                          @"firstName"     : firstName     ?: @"",
                                          @"lastName"      : lastName      ?: @"",
                                          @"compositeName" : compositeName ?: @"",
                                          @"organization"  : organization  ?: @"",
                                          @"vCard"         : vCardData     ?: [[NSData alloc]init],
                                          }.mutableCopy;
            
            if(imageData)
                [info setObject:[UIImage imageWithData:imageData] forKey:@"thumbNail"];
            
            ABMultiValueRef phones = (ABMultiValueRef)ABRecordCopyValue(person, kABPersonPhoneProperty);
            if(phones)
            {
                for (int i=0; i < ABMultiValueGetCount(phones); i++)
                {
                    NSString* label = (__bridge_transfer NSString *) ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(phones, i));
                    NSString* phone = (__bridge_transfer NSString *) ABMultiValueCopyValueAtIndex(phones, i);
                    NSString* key = [NSString stringWithFormat:@"phone_%@",  label ];
                    [info setObject:phone forKey:key];
                }
                CFRelease(phones);
 
            }

            
            // check IM addresses for JID match
            ABMutableMultiValueRef im = ABRecordCopyValue(person, kABPersonInstantMessageProperty);
            if(im)
            {
                for (int k=0; k< ABMultiValueGetCount(im) && !userName; k++ )
                {
                    NSDictionary *dict = (__bridge_transfer NSDictionary *)ABMultiValueCopyValueAtIndex(im, k);
                    
                    // check for JID = IM user with key of silent circle
                    NSString* IMname = [dict valueForKey:(NSString*)kABPersonInstantMessageServiceKey];
                    if(IMname && [IMname  caseInsensitiveCompare:kABPersonInstantMessageServiceSilentText] == NSOrderedSame )
                    {
                        NSString* thisJid = [dict valueForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                        
                        NSArray* parts = [thisJid componentsSeparatedByString:@"@"];
                        
                        if(parts.count > 1)
                        {
                            userJid = thisJid;
                        }
                        else
                        {
                            userJid =[NSString stringWithFormat:@"%@@%@", thisJid, kDefaultAccountDomain];
                            
                        }
                        break;
                    }
                    else if([[dict valueForKey:(NSString*)kABPersonInstantMessageServiceKey]
                             isEqualToString: (NSString*) kABPersonInstantMessageServiceJabber ])
                    {
                        NSString*  jab = [dict valueForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                        NSString *domain = [[jab componentsSeparatedByString:@"@"] lastObject];
                        
                        if(domain && [domain isEqualToString:kDefaultAccountDomain])
                        {
                            userJid = [dict valueForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                            break;
                        }
                    }
                }
                CFRelease(im);
            }
  
            if(!userName || !userJid )
            {
                ABMutableMultiValueRef email = ABRecordCopyValue(person, kABPersonEmailProperty);
                if(email)
                {
                    for (int k=0; k< ABMultiValueGetCount( email ); k++ )
                    {
                        NSString *email_name = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(email, k);
                        email_name = [email_name stringByReplacingOccurrencesOfString:@"<" withString:@""];
                        email_name = [email_name stringByReplacingOccurrencesOfString:@">" withString:@""];
                        NSString *domain = [[email_name componentsSeparatedByString:@"@"] lastObject];
                        
                        if(domain && [domain isEqualToString:kDefaultAccountDomain])
                        {
                            userName = [[email_name componentsSeparatedByString:@"@"] objectAtIndex:0];
                            break;
                        }
                    }
                    CFRelease(email);
                   
                }
              }
            
        
            
            if(userName)
                [info setObject:userName forKey:@"userName"];
          
            if(userJid)
                [info setObject:userJid forKey:@"jid"];
            
            if(!userName && userJid)
            {
                NSRange range = [userJid rangeOfString:@"@"];
                if (range.location != NSNotFound)
                    userName = [userJid substringToIndex:range.location];
                [info setObject:userName forKey:@"userName"];
            }
            
            
            
            // parse looking for X-SILENTCIRCLE-INFO
            NSString *notes =
            (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonNoteProperty);
            
            if(notes)
            {
                NSScanner *scanner = [NSScanner scannerWithString:notes];
                NSCharacterSet *newLine = [NSCharacterSet newlineCharacterSet];
                NSString *currentLine = nil;
                NSString *tag = nil;
                NSString *value = nil;
                
                [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@":"]];
                
                while (![scanner isAtEnd])
                {
                    //Obtain the field
                    if([scanner scanUpToString:@":" intoString:&currentLine]) {
                         tag = [currentLine stringByTrimmingCharactersInSet: newLine];
                    }
                    
                    //Obtain the value.
                    if([scanner scanUpToCharactersFromSet:newLine intoString:&currentLine])
                    {
                        value = currentLine;
                    }
                    
                    if([tag isEqualToString:@"X-SILENTCIRCLE-INFO"] && value.length)
                    {
                        NSData *jsonData = [[NSData alloc] initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters];
                        if(jsonData)
                        {
                            NSDictionary *jsonDict = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
                          if(jsonDict)
                          {
                              [info setObject:jsonDict forKey:@"X-SILENTCIRCLE-INFO"];
                              break;
                          }
                      }
                        
                     }
                  }
             }
            
            
            [result addObject:info];
        }
        
    }
    return result;
}


@end
