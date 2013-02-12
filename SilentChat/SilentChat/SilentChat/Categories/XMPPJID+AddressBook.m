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

#import "App.h"

#import "AppConstants.h"
#import "XMPPJID+AddressBook.h"

#pragma mark - SCAddressBookItem

@interface SCAddressBookItem : NSObject
@property (nonatomic, copy)     XMPPJID *jid;
@property (nonatomic) ABRecordID recordID;
@end

@implementation SCAddressBookItem;

@synthesize jid = _jid;

+ (SCAddressBookItem *)itemWithJid:(XMPPJID *)jid recordID:(ABRecordID) recordID
{
    
    SCAddressBookItem *item = [[SCAddressBookItem alloc] init];
    item.recordID = recordID;
    item.jid = [jid copy];
    return item;
}

@end;

#pragma mark - SCAddressBook 

@interface SCAddressBook()

@property (nonatomic) ABAddressBookRef  addressBook;
@property (nonatomic, strong) NSArray   *jidCache;
@property (nonatomic) BOOL              dirty;

@end

@implementation SCAddressBook

void ABExternalChange(ABAddressBookRef addressBook, CFDictionaryRef info, void *context)
{
    SCAddressBook *self = (__bridge SCAddressBook *)context;

    self.dirty = YES;
};

#ifndef __clang_analyzer__

- (SCAddressBook *) init {
	
	self = [super init];
  	
	if (self) {
        
        if (&ABAddressBookCreateWithOptions)
        {
            
            // we're on iOS 6
            self.addressBook =  ABAddressBookCreateWithOptions(NULL, NULL);
            
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            
            ABAddressBookRequestAccessWithCompletion(self.addressBook, ^(bool granted, CFErrorRef error)
                                                     {
                                                         self.dirty = YES;
                                                         dispatch_semaphore_signal(sema);
                                                     });
            
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            dispatch_release(sema);
        }
        else
        {
            // we're on iOS 5
            self.addressBook = ABAddressBookCreate();
            self.dirty = YES;
            
            ABAddressBookRegisterExternalChangeCallback(self.addressBook, ABExternalChange, (__bridge void*) self);
        }
        
    }
   

	return self;
} // init


- (void) dealloc {
    
    if(self.addressBook)
    {
        ABAddressBookUnregisterExternalChangeCallback(self.addressBook, ABExternalChange, (__bridge void*) self);
//        CFRelease(self.addressBook);
    }
 
}
#endif

+ (NSPredicate*) makefindMatchingJidPredicate:  (XMPPJID *)jid
{
    NSPredicate *pred = [NSPredicate predicateWithBlock: ^BOOL(id obj, NSDictionary *bind)
                                    {
                                        SCAddressBookItem *item = (SCAddressBookItem*) obj;
                                        BOOL foundJid =  [item.jid isEqualToJID:jid
                                                                        options:XMPPJIDCompareUser | XMPPJIDCompareDomain];
                                        return foundJid ;
                                    }];
    return pred;
}

+ (NSPredicate*) makefindMatchingABRecordIDPredicate:  (ABRecordID )recordID
{
    NSPredicate *pred = [NSPredicate predicateWithBlock: ^BOOL(id obj, NSDictionary *bind)
                         {
                             SCAddressBookItem *item = (SCAddressBookItem*) obj;
                             BOOL foundit =  item.recordID == recordID ;
                             return foundit ;
                         }];
    return pred;
}

- (SCAddressBookItem*) findItemMatchingABRecordID: (ABRecordID )recordID
{
    return ([ self findItemMatchingABRecordIDInCache:self.jidCache recordID:recordID]);
}

 
- (SCAddressBookItem*) findItemMatchingJid:(XMPPJID *)jid
{
     return ([ self findItemMatchingJidInCache:self.jidCache jid:jid]);
}
 
- (SCAddressBookItem*) findItemMatchingJidInCache:(NSArray*)cache jid:(XMPPJID *)jid
{
    SCAddressBookItem *item = NULL;
          
    NSUInteger index = [cache indexOfObjectPassingTest:
     ^(id obj, NSUInteger idx, BOOL *stop) {
         
         SCAddressBookItem *item = (SCAddressBookItem*) obj;
         
         BOOL foundJid =  [item.jid isEqualToJID:jid
                                         options:XMPPJIDCompareUser | XMPPJIDCompareDomain];
            *stop = foundJid;
          return (foundJid);
      }];
    
    if(index != NSNotFound )
       item = [cache objectAtIndex:index];
    
    return(item);
 }

- (SCAddressBookItem*) findItemMatchingABRecordIDInCache:(NSArray*)cache recordID:(ABRecordID )recordID
{
    SCAddressBookItem *item = NULL;
    
    NSUInteger index = [cache indexOfObjectPassingTest:
                        ^(id obj, NSUInteger idx, BOOL *stop) {
                            
                            SCAddressBookItem *item = (SCAddressBookItem*) obj;
                            BOOL foundit =  item.recordID == recordID ;
                            *stop = foundit;
                            return (foundit);
                        }];
    
    if(index != NSNotFound )
        item = [cache objectAtIndex:index];
    
    return(item);
}

 
- (void) addJidtoCache:(NSMutableArray*)cache  jid:(XMPPJID *)jid recordID:(ABRecordID) recordID
{
     
    if([[cache filteredArrayUsingPredicate:
                [SCAddressBook makefindMatchingJidPredicate: jid]] count] == 0 )
    {
        SCAddressBookItem* item = [SCAddressBookItem itemWithJid:jid recordID:recordID ];
        [cache addObject: item];
    }
    
}
- (BOOL) needsReload
{
    return self.dirty;
}

- (void) reload
{
    if(!self.addressBook)
        return;

    NSMutableArray* cache = [[NSMutableArray alloc] init];
    
    ABAddressBookRevert(self.addressBook);
   
    NSArray *allPeople = (__bridge_transfer NSArray*)ABAddressBookCopyArrayOfAllPeople(self.addressBook);
    
    int count = [allPeople count];
    
    if(allPeople)
    {
        for (int i=0; i < count; i++ )
        {
            ABRecordRef person = (__bridge ABRecordRef)[allPeople objectAtIndex:i];
            
            // check IM addresses for JID match
            ABMutableMultiValueRef im = ABRecordCopyValue(person, kABPersonInstantMessageProperty);
            
            CFIndex im_count = ABMultiValueGetCount( im );
            
            for (int k=0; k< im_count; k++ )
            {
                NSDictionary *dict = (__bridge_transfer NSDictionary *)ABMultiValueCopyValueAtIndex(im, k);
                
                // check for JID = IM user with key of silent circle
                NSString* IMname = [dict valueForKey:(NSString*)kABPersonInstantMessageServiceKey];
                if(IMname && [IMname  caseInsensitiveCompare:kABPersonInstantMessageServiceSilentText] == NSOrderedSame )
                {
                    NSString*  scname = [dict valueForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                    XMPPJID* jid  = [XMPPJID jidWithUser:scname domain:kDefaultAccountDomain resource:nil];
                    
                    if( ![self findItemMatchingJidInCache:cache  jid:jid])
                         [self addJidtoCache:cache jid:jid recordID:ABRecordGetRecordID(person) ];
                 }
                
                // check for JID = IM user with jabber
                else if([[dict valueForKey:(NSString*)kABPersonInstantMessageServiceKey]
                         isEqualToString: (NSString*) kABPersonInstantMessageServiceJabber ])
                {
                    NSString*  jab = [dict valueForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                    
                    NSString *domain = [[jab componentsSeparatedByString:@"@"] lastObject];
                    
                    if(domain && [domain isEqualToString:kDefaultAccountDomain])
                    {
                        NSString*  jidName = [dict valueForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                        XMPPJID* jid = [XMPPJID jidWithString: jidName];
                        
                        if( ![self findItemMatchingJidInCache:cache  jid:jid])
                            [self addJidtoCache:cache jid:jid recordID:ABRecordGetRecordID(person) ];
                  }
                }
            }
            CFRelease(im);
            
            // check if Email address matches JID
            
            ABMutableMultiValueRef email = ABRecordCopyValue(person, kABPersonEmailProperty);
            CFIndex email_count = ABMultiValueGetCount( email );
            
            for (int k=0; k< email_count; k++ )
            {
                NSString *email_name = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(email, k);
                email_name = [email_name stringByReplacingOccurrencesOfString:@"<" withString:@""];
                email_name = [email_name stringByReplacingOccurrencesOfString:@">" withString:@""];
                NSString *domain = [[email_name componentsSeparatedByString:@"@"] lastObject];
 
                if(domain && [domain isEqualToString:kDefaultAccountDomain])
                {
                    NSString *userName = [[email_name componentsSeparatedByString:@"@"] objectAtIndex:0];
                    
                    XMPPJID* jid = [XMPPJID jidWithUser:userName domain:kDefaultAccountDomain resource:nil];
                    
                    if( ![self findItemMatchingJidInCache:cache  jid:jid])
                        [self addJidtoCache:cache jid:jid recordID:ABRecordGetRecordID(person) ];
                }
            }
            CFRelease(email);
            
            // check for silent phone number
            
            ABMutableMultiValueRef phones = ABRecordCopyValue(person, kABPersonPhoneProperty);
            
            CFIndex phone_count = ABMultiValueGetCount( phones );
            
            for (int k=0; k< phone_count; k++ )
            {
                NSString* label = (__bridge_transfer NSString *)ABMultiValueCopyLabelAtIndex(phones, k);
                
                if(([label caseInsensitiveCompare:kABPersonPhoneSilentPhoneLabel] == NSOrderedSame))
                {
                    NSString* phoneNumber = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(phones, k);
                    
                    XMPPJID* jid = [XMPPJID jidWithUser:phoneNumber domain:kDefaultAccountDomain resource:nil];
                    
                    if( ![self findItemMatchingABRecordIDInCache:cache recordID:ABRecordGetRecordID(person)])
                        [self addJidtoCache:cache jid:jid recordID:ABRecordGetRecordID(person) ];

                }
                
            }
            CFRelease(phones);

         }
    }
    
    self.dirty = NO;
    self.jidCache = cache;
 }

@end


#pragma mark - NSStringMailDeliveryEmailAdditions

@implementation NSString(NSStringMailDeliveryEmailAdditions)

- (NSString *)domain
{
	NSString *address = self;
	if (!address.length) return nil;
	
	NSString *domain = [[address componentsSeparatedByString:@"@"] lastObject];
	NSArray *components = [domain componentsSeparatedByString:@"."];
	if ([components count] > 2)
	{
		return [NSString stringWithFormat:@"%@.%@", [components objectAtIndex:0], [components objectAtIndex:1]];
	}
	
	return domain;
}
 
@end

#pragma mark - XMPPJID


@implementation XMPPJID (AddressBook)

#define RecordIDisValid(rec) (rec != kABRecordInvalidID)

-(ABRecordID) addressBookRecordID
{
    App *app = App.sharedApp;
    ABRecordID  recordID = kABRecordInvalidID;
    SCAddressBookItem* item  = [app.addressBook findItemMatchingJid: self];
     if(item)
    {
         recordID  = item.recordID;
    }
    
    return recordID;
    
}


+(NSArray*)  silentCircleJids
{
    NSMutableArray * jidArray = [[NSMutableArray alloc] init];
    
    ABAddressBookRef addressBook = ABAddressBookCreate();
    if(!addressBook)
        return (NSArray.alloc.init);
    
    NSArray *allPeople = (__bridge_transfer NSArray*)ABAddressBookCopyArrayOfAllPeople(addressBook);
    
    int count = [allPeople count];
    
    if(allPeople)
    {
        for (int i=0; i < count; i++ )
        {
            ABRecordRef person = (__bridge ABRecordRef)[allPeople objectAtIndex:i];
            
            // check IM addresses for JID match
            ABMutableMultiValueRef im = ABRecordCopyValue(person, kABPersonInstantMessageProperty);
            
            CFIndex im_count = ABMultiValueGetCount( im );
            
            for (int k=0; k< im_count; k++ )
            {
                NSDictionary *dict = (__bridge_transfer NSDictionary *)ABMultiValueCopyValueAtIndex(im, k);
                
                // check for JID = IM user with key of silent circle
                NSString* IMname = [dict valueForKey:(NSString*)kABPersonInstantMessageServiceKey];
                if(IMname && [IMname  caseInsensitiveCompare:kABPersonInstantMessageServiceSilentText] == NSOrderedSame )
                {
                    NSString*  scname = [dict valueForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                    XMPPJID* jid = [XMPPJID jidWithUser:scname domain:kDefaultAccountDomain resource:nil];
                    
                    if( ! [jidArray containsObject:jid])
                        [jidArray addObject:jid];
                }
                
                // check for JID = IM user with jabber
                else if([[dict valueForKey:(NSString*)kABPersonInstantMessageServiceKey]
                         isEqualToString: (NSString*) kABPersonInstantMessageServiceJabber ])
                {
                    NSString*  jab = [dict valueForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                    
                    NSString *domain = [[jab componentsSeparatedByString:@"@"] lastObject];
                    
                    if(domain && [domain isEqualToString:kDefaultAccountDomain])
                    {
                        NSString*  jidName = [dict valueForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                        XMPPJID* jid = [XMPPJID jidWithString: jidName];
                        
                        if( ! [jidArray containsObject:jid])
                            [jidArray addObject:jid];
                    }
                }
                
            }
            CFRelease(im);
            
            // check if Email address matches JID
            
            ABMutableMultiValueRef email = ABRecordCopyValue(person, kABPersonEmailProperty);
            CFIndex email_count = ABMultiValueGetCount( email );
            
            for (int k=0; k< email_count; k++ )
            {
                NSString *email_name = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(email, k);
                email_name = [email_name stringByReplacingOccurrencesOfString:@"<" withString:@""];
                email_name = [email_name stringByReplacingOccurrencesOfString:@">" withString:@""];

                NSString *domain = [[email_name componentsSeparatedByString:@"@"] lastObject];
                
                if(domain && [domain isEqualToString:kDefaultAccountDomain])
                {
                    NSString *userName = [[email_name componentsSeparatedByString:@"@"] objectAtIndex:0];
                    
                    XMPPJID* jid = [XMPPJID jidWithUser:userName domain:kDefaultAccountDomain resource:nil];
                    
                    if( ! [jidArray containsObject:jid])
                        [jidArray addObject:jid];
                }
            }
            CFRelease(email);

        }
    }
    CFRelease(addressBook);
    
    return jidArray;
}



-(BOOL) isInAddressBook
{
    return ([self addressBookRecordID] != kABRecordInvalidID);

}

-(NSString*) addressBookName;
{
    ABRecordID recordID = [self addressBookRecordID];
    NSString* username = NULL;
    
    if(recordID != kABRecordInvalidID)
    {
        App *app = App.sharedApp;
        
        ABRecordRef person =  ABAddressBookGetPersonWithRecordID(app.addressBook.addressBook, recordID);
        username =  (__bridge_transfer NSString*) ABRecordCopyCompositeName(person);
    }
    
     return username;
}

-(UIImage*) addressBookImage;
{
    ABRecordID recordID = [self addressBookRecordID];
      UIImage* image = nil;
    
    if(recordID != kABRecordInvalidID)
    {
        App *app = App.sharedApp;
        ABRecordRef person =  ABAddressBookGetPersonWithRecordID(app.addressBook.addressBook, recordID);
        
        if(ABPersonHasImageData(person))
        {
            CFDataRef imageData = ABPersonCopyImageDataWithFormat(person,kABPersonImageFormatThumbnail);
           
            image =  imageData?[UIImage imageWithData:(__bridge_transfer NSData*) imageData]:nil;
             
        }
    }
    
     return image;
}

+(NSString*) userNameWithJIDString: (NSString*) jidString
{
    XMPPJID *jid = [XMPPJID jidWithString: jidString];
    NSString *name = [jid addressBookName];
    name = name && ![name isEqualToString: @""] ? name : [jid user];
    
    return name;
}

+(UIImage*) userAvatarWithJIDString: (NSString*) jidString
{
    XMPPJID *jid = [XMPPJID jidWithString: jidString];
    UIImage *image = [jid addressBookImage];
      
    return image;
}




-(NSString*) silentPhoneNumber
{
    ABRecordID recordID = [self addressBookRecordID];
    NSString* phoneNumber = NULL;
    
    if(recordID != kABRecordInvalidID)
    {
        App *app = App.sharedApp;

        ABRecordRef person =  ABAddressBookGetPersonWithRecordID(app.addressBook.addressBook, recordID);
        
        ABMutableMultiValueRef phones = ABRecordCopyValue(person, kABPersonPhoneProperty);
        
        CFIndex phone_count = ABMultiValueGetCount( phones );
        
        for (int k=0; k< phone_count; k++ )
        {
            NSString* label = (__bridge_transfer NSString *)ABMultiValueCopyLabelAtIndex(phones, k);
            
             if(([label caseInsensitiveCompare:kABPersonPhoneSilentPhoneLabel] == NSOrderedSame))
            {
                phoneNumber = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(phones, k);
                break;
            }
            
        }
        CFRelease(phones);
         
    }
      
    return (phoneNumber);
    
}
 @end
