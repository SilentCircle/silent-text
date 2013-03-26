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



#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import <Security/Security.h>

#import "SCKeychainItem.h"
 
 
@interface SCKeychainItem ()

@property (strong, nonatomic) NSDictionary *keychainItem;

- (NSMutableDictionary *) defaultQuery;

@end


@implementation SCKeychainItem

#pragma mark -

- (SCKeychainItem *) initWithService: (NSString *) serviceName {
	 	
 	
	self = [super init];
	
	if (self) {
		
		if (serviceName && [serviceName length]) {
			
			self.serviceName = serviceName;
			self.keychainItem  = [self keychainItemFromKeychain];
		}
	}
	
	return self;
	
}



- (NSData *) data {
    
    return [self.keychainItem objectForKey: (__bridge id) kSecValueData];
    
} 


- (void) setData: (NSData *) data {
    
	OSStatus err  = noErr;
	
	NSMutableDictionary *params = nil;
	NSMutableDictionary *query  = nil;
    
    query = [NSMutableDictionary dictionaryWithDictionary: [self defaultQuery]];
    
    if (self.data && data) { // Update the BLOB.
        
		params = NSMutableDictionary.new;
		
		[params setObject: data forKey: (__bridge id) kSecValueData];
		
		err = SecItemUpdate((__bridge CFDictionaryRef) query, (__bridge CFDictionaryRef) params);
		
		// Store the data in the query to make a keychainItem.
		[query setObject: data forKey: (__bridge id) kSecValueData];
    }
    else if (data) { // Create the BLOB.
        
		[query setObject: data forKey: (__bridge id) kSecValueData];
        
		err = SecItemAdd((__bridge CFDictionaryRef) query, (CFTypeRef *) NULL);
    }
    else { // Delete the BLOB.
        
        [self deleteItem];
    }
	// A keychainItem == the query + data.
	self.keychainItem = query;
	
	NSAssert(err == noErr, @"Could not set keychain item.");
    
} 



- (void) deleteItem
{
    
    NSDictionary *defaultQuery = self.defaultQuery;
    
    OSStatus err = SecItemDelete((__bridge CFDictionaryRef) defaultQuery);
    
    if (err && err != errSecItemNotFound) {
        
        NSAssert(NO, @"Could  not delete keychain item.");
        
        return;
    }
    self.keychainItem = defaultQuery;  

}



#pragma mark -

- (NSDictionary *) keychainItemFromKeychain {
	
 	
	CFTypeRef result = nil;
	
	OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef) self.query, &result);
	
	if (err) {
		
		// Return the default values as the answer.
		return [self defaultQuery];
	}
	// Return the saved data from the Keychain.
	return (__bridge_transfer NSDictionary *)result;
	
} 



- (NSMutableDictionary *) defaultQuery {
		
	// Start with a fresh dictionary.
	NSMutableDictionary *query = NSMutableDictionary.new;
	
    // Default attributes for keychain answer.
	[query setObject: (__bridge id) kSecClassGenericPassword forKey: (__bridge id) kSecClass];
    [query setObject: self.serviceName                       forKey: (__bridge id) kSecAttrService];
    
	return query;
	
} 

- (NSDictionary *) query {
	
	// Begin Keychain search setup.
	NSMutableDictionary *query = [self defaultQuery];
	
	// Return all of the attributes.
	[query setObject: (id) kCFBooleanTrue forKey: (__bridge id) kSecReturnAttributes];
	
	// Return the data.
	[query setObject: (id) kCFBooleanTrue forKey: (__bridge id) kSecReturnData];
	
	return query;
	
}

@end
