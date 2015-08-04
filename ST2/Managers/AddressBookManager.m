/*
Copyright (C) 2015, Silent Circle, LLC. All rights reserved.

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
#import "AddressBookManager.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "STLogging.h"
#import "STUser.h"
#import "STLocalUser.h"
#import "XMPPJID.h"
#import "NSDate+SCDate.h"

#import "YapCache.h"

#import <AddressBook/AddressBook.h>

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

NSString *const NOTIFICATION_ADDRESSBOOK_UPDATED = @"addressBookUpdated";

NSString *const kABInfoKey_abRecordID    = @"abRecordID";
NSString *const kABInfoKey_firstName     = @"first_name";
NSString *const kABInfoKey_lastName      = @"last_name";
NSString *const kABInfoKey_compositeName = @"composite_name";
NSString *const kABInfoKey_organization  = @"organization";
NSString *const kABInfoKey_displayName   = @"display_name";
NSString *const kABInfoKey_notes         = @"notes";
NSString *const kABInfoKey_modDate       = @"modDate";
NSString *const kABInfoKey_jid           = @"jid";


@interface AddressBookManager () {
@private
	dispatch_queue_t roQueue;
	dispatch_queue_t rwQueue;
	
	ABAddressBookRef addressBook;
	
	YapCache *imageCache;
    
    NSDictionary *scUserDict; // Key = jid.bareJID, Value = NSDictionary with kABInfoKey_X values
	
	NSDate *lastUpdate;
}

@property (atomic, assign, readwrite) BOOL ready;
@end

@interface ABEntry ()

- (id)initWithABRecordID:(ABRecordID)abRecordID name:(NSString *)name;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation AddressBookManager

static AddressBookManager *sharedInstance;

void ABExternalChangeCB(ABAddressBookRef addressBook, CFDictionaryRef info, void *context)
{
	[sharedInstance updateAddressBookUsers];
}

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[AddressBookManager alloc] init];
	});
}

+ (instancetype)sharedInstance
{
	return sharedInstance;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Instance
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize ready;

- (id)init
{
	NSAssert(sharedInstance == nil, @"Must use sharedInstance singleton");
	
	if ((self = [super init]))
	{
		roQueue = dispatch_queue_create("STAddressBookManager-ro", DISPATCH_QUEUE_SERIAL);
		rwQueue = dispatch_queue_create("STAddressBookManager-rw", DISPATCH_QUEUE_SERIAL);
		
		imageCache = [[YapCache alloc] initWithCountLimit:30];
		imageCache.allowedKeyClasses = [NSSet setWithObject:[NSNumber class]];
		imageCache.allowedObjectClasses = [NSSet setWithObject:[UIImage class]];
		
		scUserDict = [[NSDictionary alloc] init];
   		
		[self configureAddressBook];
		
		#if TARGET_OS_IPHONE
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(didReceiveMemoryWarning:)
		                                             name:UIApplicationDidReceiveMemoryWarningNotification
		                                           object:nil];
		#endif
	}
	return self;
}

- (void)dealloc
{
	if (addressBook)
	{
		ABAddressBookUnregisterExternalChangeCallback(addressBook, ABExternalChangeCB, NULL);
		CFRelease(addressBook);
		addressBook = NULL;
	}
}

#if TARGET_OS_IPHONE
- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
	// Flush the imageCache, which is the largest usage of memory within this class.
	// Remember: the imageCache is not thread-safe, and is designed to only be acccessed from within the roQueue.
	
	dispatch_async(roQueue, ^{
		
		[imageCache removeAllObjects];
	});
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup & Updates
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)configureAddressBook
{
	dispatch_async(rwQueue, ^{
	
		CFErrorRef err = NULL;
		ABAddressBookRef _addressBook = ABAddressBookCreateWithOptions(NULL, &err);
		
		if (_addressBook == NULL)
		{
			DDLogWarn(@"Error creating addressBookRef: %@", (__bridge NSError *)err);
			if (err) CFRelease(err);
			return;
		}
		
		ABAddressBookRequestAccessWithCompletion(_addressBook, ^(bool granted, CFErrorRef error) {
			
			// Note: ABAddressBook doesn't guarantee execution of this block on any particular thread.
            // but IOS seems to need the ABAddressBookRegisterExternalChangeCallback to happen on main thread.
			
			if (granted)
			{
                [self updateAddressBookUsers:_addressBook];
                
				dispatch_async(dispatch_get_main_queue(), ^{
					ABAddressBookRegisterExternalChangeCallback(_addressBook, ABExternalChangeCB, NULL);
				});
			}
		});
	});
}


- (void)updateAddressBookUsers
{
    [self updateAddressBookUsers:NULL];
}

- (void)updateAddressBookUsers:(ABAddressBookRef)inAddressBook
{
	dispatch_async(rwQueue, ^{ @autoreleasepool {
		
		__block ABAddressBookRef _addressBook = inAddressBook;
        __block NSMutableDictionary* _scUserDict = [NSMutableDictionary dictionary];
	
        NSSet *supportedXmppDomains = [AppConstants supportedXmppDomains];
        
		dispatch_sync(roQueue, ^{
			
			if (_addressBook == NULL)
				_addressBook = addressBook;
			
			// Disable the roQueue from using the addressBook.
			// All methods will return nil until our update has finished.
			
			addressBook = NULL;
			[imageCache removeAllObjects];
		});
		
		if (_addressBook == NULL) return; // from_block
		
		// Since we dont know which user(s) changed in the address book,
		// we have to check them all.
		//
		// We also need to uncache all the images too.
		// This was done above, within the roQueue, since the imageCache can only
		// be accessed from within the roQueue.
        
        // walk list of STUsers and find all who arelinked by abRecordID
        
		YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
		[rwDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
			NSMutableDictionary *updates = [NSMutableDictionary dictionary];
			
            // Walk entire AddressBook and check for matches for any linked users.
			
            NSArray *allPeople = (__bridge_transfer NSArray*)ABAddressBookCopyArrayOfAllPeople(_addressBook);
            for (id peep in allPeople)
            {
                ABRecordRef person = (__bridge ABRecordRef) peep;
                
                XMPPJID* foundJid = NULL;
                
                // check IM addresses for JID match
				ABMultiValueRef im = ABRecordCopyValue(person, kABPersonInstantMessageProperty);
                
                CFIndex im_count = ABMultiValueGetCount( im );
                
				for (int k=0; k < im_count; k++)
				{
					NSDictionary *dict = (__bridge_transfer NSDictionary *)ABMultiValueCopyValueAtIndex(im, k);
                    
                    // check for JID = IM user with key of silent circle
                    NSString* IMname = [dict valueForKey:(NSString*)kABPersonInstantMessageServiceKey];
                    if(IMname) {
                        if ([IMname  caseInsensitiveCompare:kABPersonInstantMessageServiceSilentText] == NSOrderedSame )
                        {
                            NSString*  scname = [dict valueForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                            NSRange range = [scname rangeOfString:@"@"];
                            if (range.location == NSNotFound)
                            {
                                foundJid = [XMPPJID jidWithUser:scname domain:kDefaultAccountDomain resource:nil];
                            }
                            else
                            {
                                foundJid = [XMPPJID jidWithString:scname];
                            }
                            
                         }
                        
                        // check for JID = IM user with jabber
                        else if([IMname isEqualToString: (NSString *)kABPersonInstantMessageServiceJabber ])
                        {
                            NSString *jab = [dict objectForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                            NSString *thisDomain = [[jab componentsSeparatedByString:@"@"] lastObject];
                            
							if ([supportedXmppDomains containsObject:thisDomain])
							{
								foundJid = [XMPPJID jidWithString: jab];
							}
                        }
                    }
                    
					if (foundJid)
					{
						ABRecordID abRecordID = ABRecordGetRecordID(person);
						NSString *firstName =
						  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
						NSString *lastName =
						  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
						NSString *compositeName =
						  (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
						NSString *organization =
						  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonOrganizationProperty);
						NSString *notes =
						  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonNoteProperty);
						NSDate *lastModDate =
						  (__bridge_transfer NSDate *)ABRecordCopyValue(person, kABPersonModificationDateProperty);
                        
                        // search the STUsers to find any matching jids
                        
						STUser *user = [STDatabaseManager findUserWithJID:foundJid transaction:transaction];
						if (user && (user.abRecordID == kABRecordInvalidID))
						{
							NSDictionary *updateInfo = @{
							  kABInfoKey_abRecordID    : [NSNumber numberWithInt:abRecordID],
							  kABInfoKey_firstName     : firstName     ?: @"",
							  kABInfoKey_lastName      : lastName      ?: @"",
							  kABInfoKey_compositeName : compositeName ?: @"",
							  kABInfoKey_organization  : organization  ?: @"",
							  kABInfoKey_notes         : notes         ?: @"",
							  kABInfoKey_jid           : user.jid,
							  @"abLinked"              : @(YES),
							};
							
							[updates setObject:updateInfo forKey:user.uuid];
						}
                        
                        NSString *displayName = @"";
                        
                        if (compositeName && compositeName.length > 0)
                        {
                            displayName = compositeName;
                        }
                        else if ([firstName length] > 0 || ([lastName length] > 0))
                        {
                            if (([firstName length] > 0) && ([lastName length] > 0))
                            {
                                displayName =  [NSString stringWithFormat:@"%@ %@", firstName, lastName];
                            }
                            else if ([firstName length] > 0)
                            {
                                displayName = firstName;
                            }
                            else
                            {
                                displayName = lastName;
                            }
                        }
                        if([displayName length] == 0)
                            displayName = foundJid.bare;
                        
                        NSDictionary* info = @{
						  kABInfoKey_abRecordID    : [NSNumber numberWithInt:abRecordID],
						  kABInfoKey_firstName     : firstName     ?: @"",
						  kABInfoKey_lastName      : lastName      ?: @"",
						  kABInfoKey_compositeName : compositeName ?: @"",
						  kABInfoKey_displayName   : displayName   ?: @"",
						  kABInfoKey_organization  : organization  ?: @"",
						  kABInfoKey_notes         : notes         ?: @"",
						  kABInfoKey_modDate       : lastModDate   ?: [NSDate distantPast],
						  kABInfoKey_jid           : foundJid.bare,
						}; // no uuid for these records
                        
						[_scUserDict setObject:info forKey:[foundJid bareJID]];
                    }
                }
                
				if (im) {
                    CFRelease(im);
				}
				
            } // end for (id peep in allPeople)

			NSArray *allSCUsers = [_scUserDict allValues];
            
			[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
			                                      usingBlock:^(NSString *key, id object, BOOL *stop)
			{
				__unsafe_unretained STUser *user = (STUser *)object;
				
				if (user.abRecordID == kABRecordInvalidID)
				{
					return;// continue (next record in enumeration)
				}
				
				ABRecordRef person = ABAddressBookGetPersonWithRecordID(_addressBook, user.abRecordID);
				if (!person)
				{
					// record was invalid or deleted
					NSDictionary *updateInfo = @{ @"deleted":@(YES) };
					[updates setObject:updateInfo forKey:user.uuid];
				}
				else
				{
					NSString *firstName =
					  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
					NSString *lastName =
					  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
					NSString *compositeName =
					  (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
					NSString *organization =
					  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonOrganizationProperty);
					NSString *notes =
					  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonNoteProperty);
					NSDate *lastModDate =
					  (__bridge_transfer NSDate *) ABRecordCopyValue(person, kABPersonModificationDateProperty);
					
					ABRecordID abRecordID = ABRecordGetRecordID(person);
					NSString *displayName = @"";
					
					BOOL firstNameChanged =
					  firstName ? ![firstName isEqualToString:user.ab_firstName]
                        : (user.ab_firstName != nil) && (user.ab_firstName.length);
					BOOL lastNameChanged =
					  lastName ? ![lastName isEqualToString:user.ab_lastName]
                        : (user.ab_lastName != nil) && (user.ab_lastName.length);
					BOOL compositeNameChanged =
                        compositeName ? ![compositeName isEqualToString:user.ab_compositeName]
                        : (user.ab_compositeName != nil)&& (user.ab_compositeName.length);
					BOOL organizationChanged =
					  organization ? ![organization isEqualToString:user.ab_organization]
                        : (user.ab_organization != nil) && (user.ab_organization.length);
                    BOOL notesChanged =
                      notes ? ![notes isEqualToString:user.ab_notes]
                        : (user.ab_notes != nil) && (user.ab_notes.length);
					
					
//					NSPredicate *fiterABRecord = [NSPredicate predicateWithFormat:@"abRecordID = %d",abRecordID ];
//					NSArray *filteredABUsers = [allSCUsers filteredArrayUsingPredicate:fiterABRecord];
					
					NSPredicate *JidFilter = [NSPredicate predicateWithFormat:@"jid = %@",user.jid ];
					NSArray *usermatchingJid = [allSCUsers filteredArrayUsingPredicate:JidFilter];
					NSDictionary* newABinfo = usermatchingJid.count? [usermatchingJid firstObject]:nil;
                        
                    ABRecordID newABrecord = newABinfo
                      ? [[newABinfo objectForKey:kABInfoKey_abRecordID] intValue] : kABRecordInvalidID;
                        
                    BOOL abRecordChanged = (newABrecord != abRecordID) && user.isAutomaticallyLinkedToAB;
                        
                    BOOL somethingElseChanged = [lastModDate isAfter:user.lastUpdated];
                    
					if (firstNameChanged || lastNameChanged || compositeNameChanged
                        || organizationChanged || notesChanged || abRecordChanged || somethingElseChanged)
					{
						// Info changed.
						// We need to update the user in the database. (but outside enumeration)
						
						NSDictionary *updateInfo = @{
						  kABInfoKey_firstName     : firstName     ?: @"",
						  kABInfoKey_lastName      : lastName      ?: @"",
						  kABInfoKey_compositeName : compositeName ?: @"",
						  kABInfoKey_organization  : organization  ?: @"",
                          kABInfoKey_notes         : notes         ?: @"",
                          kABInfoKey_abRecordID    : abRecordChanged ? @(newABrecord) : @(user.abRecordID),
                        };
						
                        [updates setObject:updateInfo forKey:user.uuid];
					}
					else
					{
						// Nothing changed, but image might have.
						// So just touch the user.
                        [transaction touchObjectForKey:key inCollection:kSCCollection_STUsers];
                    }
                    
                    
                    if (compositeName && compositeName.length > 0)
                    {
                        displayName = compositeName;
                    }
                    else if ([firstName length] > 0 || ([lastName length] > 0))
                    {
                        if (([firstName length] > 0) && ([lastName length] > 0))
                        {
                            displayName =  [NSString stringWithFormat:@"%@ %@", firstName, lastName];
                        }
                        else if ([firstName length] > 0)
                        {
                            displayName = firstName;
                        }
                        else
                        {
                            displayName = lastName;
                        }
                    }
					
                    if ([displayName length] == 0)
						displayName = user.jid.user;
					
					NSDictionary *abInfo = @{
					  kABInfoKey_abRecordID    : abRecordChanged ? @(newABrecord) : @(user.abRecordID),
					  kABInfoKey_firstName     : firstName      ?: @"",
					  kABInfoKey_lastName      : lastName       ?: @"",
					  kABInfoKey_compositeName : compositeName  ?: @"",
					  kABInfoKey_displayName   : displayName    ?: @"",
					  kABInfoKey_organization  : organization   ?: @"",
					  kABInfoKey_notes         : notes          ?: @"",
					  @"uuid"                  : user.uuid
					};
					
					[_scUserDict setObject:abInfo forKey:[user.jid bareJID]];
				}
			}];
            
            // update any effected STUser Records
            
			[updates enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
				
				__unsafe_unretained NSString *userId = (NSString *)key;
				__unsafe_unretained NSDictionary *info = (NSDictionary *)obj;
				
				STUser *user = [transaction objectForKey:userId inCollection:kSCCollection_STUsers];
				
				user = [user copy];
                
                if([info objectForKey:@"deleted"])
                {
                    user.abRecordID = kABRecordInvalidID;
                    user.isAutomaticallyLinkedToAB = NO;
                }
                
                if([info objectForKey:kABInfoKey_abRecordID])
                {
                    ABRecordID abRecordID = [[info objectForKey:kABInfoKey_abRecordID] intValue];
                    user.abRecordID = abRecordID;
                    
                    if([info objectForKey:@"abLinked"])
                         user.isAutomaticallyLinkedToAB = YES;
                    
                    if(abRecordID == kABRecordInvalidID)
                        user.isAutomaticallyLinkedToAB = NO;
                }
 
				user.ab_firstName     = [info objectForKey:kABInfoKey_firstName];
				user.ab_lastName      = [info objectForKey:kABInfoKey_lastName];
				user.ab_compositeName = [info objectForKey:kABInfoKey_compositeName];
				user.ab_organization  = [info objectForKey:kABInfoKey_organization];
				user.ab_notes         = [info objectForKey:kABInfoKey_notes];
				user.lastUpdated      = [NSDate date];
                
				[transaction setObject:user forKey:user.uuid inCollection:kSCCollection_STUsers];
			}];
		}];
 		
		// And we're done.
		// So now reset the addressBook ivar.
		
		dispatch_async(roQueue, ^{
			
			// Re-enable the roQueue to use the addressBook.
			
			addressBook = _addressBook;
            scUserDict =  _scUserDict;
			
			lastUpdate = [NSDate date];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_ADDRESSBOOK_UPDATED
                                                                object:nil
                                                              userInfo:NULL];
		});
	}});
}


- (void)updateUser:(NSString *)userId withABRecordID:(ABRecordID)abRecordID isLinkedByAB:(BOOL)isLinkedByAB
{
	__block BOOL failed = NO;
	
	__block NSString *firstName = nil;
	__block NSString *lastName = nil;
	__block NSString *compositeName = nil;
	__block NSString *organization = nil;
	__block NSString *notes = nil;
	
	if (abRecordID != kABRecordInvalidID)
	{
		dispatch_sync(roQueue, ^{ @autoreleasepool {
			
			if (addressBook == NULL) // Not ready, or mid-update
			{
				failed = YES;
			}
			else
			{
				ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, abRecordID);
			
				firstName     = (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
				lastName      = (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
				compositeName = (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
				organization  = (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonOrganizationProperty);
        	    notes         = (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonNoteProperty);
                
			}
 		}});
	}
	
	if (failed) return;
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STUser *user = [transaction objectForKey:userId inCollection:kSCCollection_STUsers];
		if (user)
		{
			user = [user copy];
			user.abRecordID = abRecordID;
 			
			if (abRecordID == kABRecordInvalidID)
			{
 				user.ab_firstName     = nil;
				user.ab_lastName      = nil;
				user.ab_compositeName = nil;
				user.ab_organization  = nil;
				user.ab_notes         = nil;
                user.isAutomaticallyLinkedToAB = NO;
 			}
			else
			{
				user.ab_firstName     = firstName;
				user.ab_lastName      = lastName;
				user.ab_compositeName = compositeName;
				user.ab_organization  = organization;
				user.ab_notes           = notes;
                user.isAutomaticallyLinkedToAB = isLinkedByAB;
			}
			
			[transaction setObject:user forKey:userId inCollection:kSCCollection_STUsers];
		}
	}];
}

- (NSDictionary *)infoForABRecordID:(ABRecordID)abRecordID
{
	if (abRecordID == kABRecordInvalidID) return nil;
	
	__block NSMutableDictionary *info = nil;
	
	dispatch_sync(roQueue, ^{ @autoreleasepool {
		
		if (addressBook == NULL)
		{
			// Not ready, or mid-update
		}
		else
		{
			ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, abRecordID);
			
			NSString *firstName =
			  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
			NSString *lastName =
			  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
			NSString *compositeName =
			  (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
			NSString *organization =
			  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonOrganizationProperty);
			NSString *notes =
			  (__bridge_transfer NSString *)ABRecordCopyValue(person, kABPersonNoteProperty);
			
			info = [NSMutableDictionary dictionaryWithCapacity:6];
			
			info[kABInfoKey_abRecordID] = @(abRecordID);
			
			if (firstName)
				info[kABInfoKey_firstName] = firstName;
			if (lastName)
				info[kABInfoKey_lastName] = lastName;
			if (compositeName)
				info[kABInfoKey_compositeName] = compositeName;
			if (organization)
				info[kABInfoKey_organization] = organization;
			if (notes)
				info[kABInfoKey_notes] = notes;
		}
	}});
	
	return info;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Images
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (UIImage *)imageForJID:(XMPPJID *)jid
{
	UIImage *image = nil;
	
	NSDictionary *info = [self infoForSilentCircleJID:jid];
	if(info)
	{
		ABRecordID abRecordID = [[info objectForKey:kABInfoKey_abRecordID] intValue];
		image = [self imageForABRecordID:abRecordID];
	}
	
	return image;
}

- (UIImage *)imageForJidStr:(NSString *)jidStr
{
	return [self imageForJID:[XMPPJID jidWithString:jidStr]];
}

- (UIImage *)imageForABRecordID:(ABRecordID)abRecordID
{
	if (abRecordID == kABRecordInvalidID) return nil;
	
	__block UIImage *image = nil;
	
	dispatch_sync(roQueue, ^{ @autoreleasepool {
		
		image = [imageCache objectForKey:@(abRecordID)];
		if (image) {
			return; // from block
		}
		
		if (addressBook == NULL) return; // Not ready, or mid-update
		
		ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, abRecordID);
        if (person)
		{
			NSData *imageData = (__bridge_transfer NSData *)
			    ABPersonCopyImageDataWithFormat(person, kABPersonImageFormatThumbnail);
			
			if (imageData)
				image = [UIImage imageWithData:imageData];
			
			if (image) {
				[imageCache setObject:image forKey:@(abRecordID)];
			}
		}
	}});
	
	return image;
}

- (BOOL)hasImageForJID:(XMPPJID *)jid
{
	BOOL hasImage = NO;
	
	NSDictionary *info = [self infoForSilentCircleJID:jid];
	if(info)
	{
		ABRecordID abRecordID = [[info objectForKey:kABInfoKey_abRecordID] intValue];
		hasImage = [self hasImageForABRecordID:abRecordID];
	}
	
	return hasImage;
}

- (BOOL)hasImageForJidStr:(NSString *)jidStr
{
	return [self hasImageForJID:[XMPPJID jidWithString:jidStr]];
}

- (BOOL)hasImageForABRecordID:(ABRecordID)abRecordID
{
	if (abRecordID == kABRecordInvalidID) return NO;
	
	__block BOOL hasImage = NO;
	
	dispatch_sync(roQueue, ^{ @autoreleasepool {
		
		if ([imageCache containsKey:@(abRecordID)])
		{
			hasImage = YES;
			return; // from block
		}
		
		if (addressBook == NULL) return; // Not ready, or mid-update
		
		ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, abRecordID);
        if (person)
		{
			hasImage = ABPersonHasImageData(person);
		}
	}});
	
	return hasImage;
}

- (NSDate *)lastUpdate
{
	__block NSDate *result = nil;
	
	dispatch_sync(roQueue, ^{
		
		result = lastUpdate;
	});
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns an NSDictionary with info from the Address Book for the given jid.
 *
 * Use the constants defined at the top of AddressBookManager.h for the dictionary keys.
 * They all start with "kABInfoKey_".
**/
- (NSDictionary *)infoForSilentCircleJID:(XMPPJID *)jid
{
	__block NSDictionary *result = nil;
	
	dispatch_sync(roQueue, ^{
		
		result = [scUserDict objectForKey:[jid bareJID]];
	});
	
	return result;
}

- (NSDictionary *)infoForSilentCircleJidStr:(NSString *)jidStr
{
	return [self infoForSilentCircleJID:[XMPPJID jidWithString:jidStr]];
}

- (NSArray *)SilentCircleJids
{
	__block NSArray *result = nil;
	
	dispatch_sync(roQueue, ^{
		
		result = scUserDict ? [scUserDict allKeys] : @[];
	});
	
	return result;
}

- (NSArray *)SilentCircleJidsForCurrentUser
{
	STLocalUser *currentUser = STDatabaseManager.currentUser;
	NSDictionary *netInfo = [AppConstants.SilentCircleNetworkInfo objectForKey:currentUser.networkID];
	if (netInfo == nil)
	{
		return @[];
	}
	
	NSString *domain = [netInfo objectForKey:@"xmppDomain"];
	
	__block NSMutableArray *filteredArray = nil;
	
	dispatch_sync(roQueue, ^{ @autoreleasepool {
		
		filteredArray = [NSMutableArray arrayWithCapacity:[scUserDict count]];
		
		for (XMPPJID *jid in scUserDict)
        {
			if ([jid.domain isEqualToString:domain]) {
				[filteredArray addObject:jid];
			}
		}
	}});
    
    return filteredArray;
}

- (NSArray *)allEntries
{
	__block NSArray *result = nil;
	
	dispatch_sync(roQueue, ^{ @autoreleasepool {
	
		if (addressBook == NULL) return; // Not ready, or mid-update
	
#if 0
		ABRecordRef source = ABAddressBookCopyDefaultSource(addressBook);
        
		NSArray *people = (__bridge_transfer NSArray *)
        ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering(addressBook, source, kABPersonSortByFirstName);

#else
        
        NSMutableArray *people = [((__bridge_transfer NSArray *) ABAddressBookCopyArrayOfAllPeople(addressBook)) mutableCopy] ;
        
        [people sortUsingComparator:(NSComparator) ^(ABRecordRef *person1Ref, ABRecordRef *person2Ref) {
            CFComparisonResult comparisonResult = ABPersonComparePeopleByName(person1Ref, person2Ref, ABPersonGetSortOrdering());
            if (comparisonResult == kCFCompareLessThan) return NSOrderedAscending;
            if (comparisonResult == kCFCompareGreaterThan) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        
#endif
		NSMutableArray *entries = [NSMutableArray arrayWithCapacity:[people count]];
		
		for (NSUInteger i = 0; i < [people count]; i++)
		{
			ABRecordRef person = (__bridge ABRecordRef)[people objectAtIndex:i];
  	         
			ABRecordID abRecordID = ABRecordGetRecordID(person);
			
			NSString *name = (__bridge_transfer NSString *)ABRecordCopyCompositeName(person);
			if (name == nil)
			{
                NSSet *supportedXmppDomains = [AppConstants supportedXmppDomains];
                
                // check IM addresses for JID match
                ABMutableMultiValueRef im = ABRecordCopyValue(person, kABPersonInstantMessageProperty);
                CFIndex im_count = ABMultiValueGetCount( im );
                
                XMPPJID* foundJid = NULL;
                
                for (int k=0; k< im_count; k++ )
                {
                    NSDictionary *dict = (__bridge_transfer NSDictionary *)ABMultiValueCopyValueAtIndex(im, k);
                    
                    // check for JID = IM user with key of silent circle
                    NSString* IMname = [dict valueForKey:(NSString*)kABPersonInstantMessageServiceKey];
                    if(IMname) {
                        if ([IMname  caseInsensitiveCompare:kABPersonInstantMessageServiceSilentText] == NSOrderedSame )
                        {
                            NSString*  scname = [dict valueForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                            NSRange range = [scname rangeOfString:@"@"];
                            if (range.location == NSNotFound)
                            {
                                foundJid = [XMPPJID jidWithUser:scname domain:kDefaultAccountDomain resource:nil];
                            }
                            else
                            {
                                foundJid = [XMPPJID jidWithString:scname];
                            }
                            
                        }
                        
                        // check for JID = IM user with jabber
                        else if([IMname isEqualToString: (NSString *)kABPersonInstantMessageServiceJabber ])
                        {
                            NSString *jab = [dict objectForKey:(NSString*)kABPersonInstantMessageUsernameKey];
                            NSString *thisDomain = [[jab componentsSeparatedByString:@"@"] lastObject];
                            
							if ([supportedXmppDomains containsObject:thisDomain])
							{
								foundJid = [XMPPJID jidWithString: jab];
							}
                        }
                    }

                }
                
                if (im)
                    CFRelease(im);
                
                if(foundJid)
                {
                    if([foundJid.domain isEqualToString:kDefaultAccountDomain])
                        name = foundJid.user;
                    else
                        name = foundJid.bare;
                    
                }
                else
                {
                    ABMutableMultiValueRef multi = ABRecordCopyValue(person, kABPersonEmailProperty);
                    name = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(multi, 0);
                    
                    if (multi)
                        CFRelease(multi);
   
                }
                
            }
			
			ABEntry *entry = [[ABEntry alloc] initWithABRecordID:abRecordID name:name];
			
			[entries addObject:entry];
		}
		
		result = [entries copy];
	}});
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark vCard
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSData *)vCardDataForABRecordID:(ABRecordID)abRecordID
{
	__block NSData *data = nil;
	
	dispatch_sync(roQueue, ^{ @autoreleasepool {
		
		if (addressBook == NULL) return; // Not ready, or mid-update
	
		ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, abRecordID);
		if (person)
		{
			NSArray *people = [NSArray arrayWithObject:(__bridge id)(person)];
			
			data = (__bridge_transfer NSData *)
			    ABPersonCreateVCardRepresentationWithPeople((__bridge CFArrayRef)people);
		}
	}});
	
	return data;
}


- (void)addvCardToAddressBook:(NSData *)vCard completion:(void (^)(BOOL success))completionBlock
{
	DDLogAutoTrace();
	
	// ARC note:
	//
	// Any method named XxCreateXx() returns a retained object that must be released.
	// We want ARC to automatically release it for use, so we need to "transfer" the retained object into ARC.
	
	NSArray *vCardPeople = (__bridge_transfer NSArray *)
	  ABPersonCreatePeopleInSourceWithVCardRepresentation(NULL, (__bridge CFDataRef)vCard);
	
	// We do NOT use the existing addressBook ivar.
	//
	// ABAddressBookRef instances are NOT thread-safe.
	// So rather than skirt around this issue using queues,
	// it's simpler (and more concurrent) to simply create our own instance.
	
	CFErrorRef err = NULL;
	ABAddressBookRef ab = ABAddressBookCreateWithOptions(NULL, &err);
	
	if (ab == NULL)
	{
		DDLogWarn(@"Error creating addressBookRef: %@", (__bridge NSError *)err);
		if (err) CFRelease(err);
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (completionBlock) {
				completionBlock(NO);
			}
		});
		return;
	}
	
	ABAddressBookRequestAccessWithCompletion(ab, ^(bool granted, CFErrorRef accessError) { @autoreleasepool {
		
		// Note: ABAddressBook doesn't guarantee execution of this block on any particular thread.
		
		BOOL success = YES;
		
		if (!granted)
		{
			success = NO;
		}
		else // if (granted)
		{
			for (NSUInteger i = 0; i < [vCardPeople count]; i++)
			{
				ABRecordRef person = (__bridge ABRecordRef)[vCardPeople objectAtIndex:i];
				
				CFErrorRef error = NULL;
				if (!ABAddressBookAddRecord(addressBook, person, &error))
				{
					DDLogWarn(@"%@ - ABAddressBookAddRecord returned error: %@",
					          THIS_METHOD, (__bridge NSError *)error);
					
					if (error) CFRelease(error); // yes
					
					success = NO;
					break;
				}
			}
			
			if (success)
			{
				CFErrorRef error = NULL;
				if (!ABAddressBookSave(addressBook, &error))
				{
					DDLogWarn(@"%@ - ABAddressBookSave returned error: %@",
					          THIS_METHOD, (__bridge NSError *)error);
					
					if (error) CFRelease(error); // yup
					
					success = NO;
				}
			}
		}
		
		if (success)
		{
			[self updateAddressBookUsers];
		}
		
		CFRelease(ab);
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (completionBlock) {
				completionBlock(success);
			}
		});
		
	}}); // end ABAddressBookRequestAccessWithCompletion
}
        
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation ABEntry

@synthesize abRecordID;
@synthesize name;

- (id)initWithABRecordID:(ABRecordID)inAbRecordID name:(NSString *)inName
{
	if ((self = [super init]))
	{
		abRecordID = inAbRecordID;
		name = inName?inName:@"";
	}
	return self;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation ABInfoEntry

@synthesize abRecordID;
@synthesize name;
@synthesize jidStr;

- (id)initWithABRecordID:(ABRecordID)inAbRecordID name:(NSString *)inName jidStr:(NSString *)inJidStr
{
	if ((self = [super init]))
	{
		abRecordID = inAbRecordID;
		name = inName;
        jidStr = inJidStr;
	}
	return self;
}

@end
