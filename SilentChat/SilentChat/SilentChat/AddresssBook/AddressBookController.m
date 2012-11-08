/*
Copyright © 2012, Silent Circle
All rights reserved.

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
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
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

#import "AddressBookController.h"
#import "XMPPvCardAvatarModule.h"
#import "XMPPServer.h"
#import "App.h"


@interface AddressBookController()

 
@end

@implementation AddressBookController
 
// ugly code to walk the address book looking for jabber ID

#pragma mark - Address book utilities
       
 
#pragma mark - Display the existing contact info of JID 

// Does not allow users to perform default actions such as emailing a contact, when they select a contact property.
 // in the case of the jabberID we dont allow it it.

- (BOOL)personViewController:(ABPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person 
					property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifierForValue
{
    
    if(property == kABPersonInstantMessageProperty) {
          return NO;
    }
    
	return YES;
}



- (void)ReturnFromPersonView{
    
	[self dismissModalViewControllerAnimated:YES];
    
    [self.navigationController popViewControllerAnimated:YES];
}


-(void) showContactForJID: (XMPPJID*)jid
{
    ABRecordID recordID = [jid addressBookRecordID];
    ABAddressBookRef addressBook = ABAddressBookCreate();
    
    if(recordID != kABRecordInvalidID)
    {
        ABRecordRef person =  ABAddressBookGetPersonWithRecordID(addressBook, recordID);
        if(person)
        {
            ABPersonViewController *picker = [[ABPersonViewController alloc] init];
            
            picker.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back",nil) style:UIBarButtonItemStyleDone target:self action:@selector(ReturnFromPersonView)];
            
            picker.personViewDelegate = self;
            picker.displayedPerson = person;
            // Allow users to edit the person’s information
            picker.allowsEditing = YES;
            picker.allowsActions = YES;
            
            UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
            
            [self presentModalViewController:navigation animated:YES];
            
        }
    }
    
    CFRelease(addressBook);
}

 #pragma mark - Create a new contact with this JID

// Dismisses the picker when users are done creating a contact or adding the displayed person properties to an existing contact. 

- (void)unknownPersonViewController:(ABUnknownPersonViewController *)unknownPersonView didResolveToPerson:(ABRecordRef)person
{
	[self dismissModalViewControllerAnimated:YES];
}


// Does not allow users to perform default actions such as emailing a contact, when they select a contact property.
// in the case of the jabberID we dont allow it it.

- (BOOL)unknownPersonViewController:(ABUnknownPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
	return NO;
}


 // Dismisses the new-person view controller. 
- (void)newPersonViewController:(ABNewPersonViewController *)newPersonViewController didCompleteWithNewPerson:(ABRecordRef)person
{
	[self dismissModalViewControllerAnimated:YES];
    [self.navigationController popViewControllerAnimated: YES];
    
    
}


-(void) createContactWithJID: (XMPPJID *)jid
{
    ABRecordRef aContact = ABPersonCreate();
	CFErrorRef anError = NULL;

#if 0
    
// I'd like to use the vard to prefill some of the information here if possible, but
// the best way would be to import the vCard directly using ABPersonCreatePeopleInSourceWithVCardRepresentation
 //  XMPPvCardTemp *  vCard =  [App.sharedApp.xmppServer.xmppvCardTempModule fetchvCardTempForJID: jid];
//  NSString* title = vCard.title;
//  NSString* name = vCard.formattedName;
   
    NSData *photoData = [App.sharedApp.xmppServer.xmppvCardAvatarModule photoDataForJID: jid];
    UIImage* image = photoData ? [UIImage imageWithData: photoData] : [UIImage imageNamed: @"defaultPerson"];
    
    NSData *localData = UIImagePNGRepresentation(image);   
    
    CFDataRef cfLocalData = CFDataCreate(NULL, [localData bytes], [localData length]);
    if(cfLocalData){ 
        ABPersonSetImageData(aContact, cfLocalData, nil);
           CFRelease(cfLocalData);
    }
#endif
  
       
    ABMutableMultiValueRef im = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
    NSMutableDictionary *imDict = [[NSMutableDictionary alloc] init];
 
#pragma warning "should we default to jabber or silent cricle service?"
    
    //  should we default to jabber or silent cricle service?
#if 0
    [imDict setObject:(NSString*)kABPersonInstantMessageServiceJabber forKey:(NSString*) kABPersonInstantMessageServiceKey];
     [imDict setObject:jid.bare  forKey:(NSString*)kABPersonInstantMessageUsernameKey];
#else
    [imDict setObject:(NSString*)kABPersonInstantMessageServiceSilentText forKey:(NSString*) kABPersonInstantMessageServiceKey];
    [imDict setObject:jid.user  forKey:(NSString*)kABPersonInstantMessageUsernameKey];
#endif
    
    ABMultiValueAddValueAndLabel(im, (__bridge CFTypeRef) imDict, kABOtherLabel, NULL);
     
    ABRecordSetValue(aContact, kABPersonInstantMessageProperty, im, &anError);
    if (anError == NULL)
    {
        ABNewPersonViewController *picker = [[ABNewPersonViewController alloc] init];
        picker.newPersonViewDelegate = self;
        picker.displayedPerson = aContact;
         
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
        [self presentModalViewController:navigation animated:YES];
     }
    CFRelease(aContact);
    CFRelease(im);
}


#pragma mark - Add to existing contact
 
- (void)ReturnFromPersonView1{
    
	[self dismissModalViewControllerAnimated:YES];
    
     [self.navigationController popViewControllerAnimated:YES];
}


// Displays the information of a selected person
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person
{

    [self dismissModalViewControllerAnimated:NO];
    [self.navigationController popViewControllerAnimated:NO];
  
  
#if 1
    
    ABPersonViewController *picker = [[ABPersonViewController alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
    
    picker.personViewDelegate = self;
    picker.displayedPerson = person;
    picker.allowsEditing = YES;
    
    
    [self presentModalViewController:navigation animated:YES];
    
    [picker setEditing:YES];
    
//    picker.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel",nil) style:UIBarButtonItemStyleDone target:self action:@selector(ReturnFromPersonView1)];
    
  //  [self setEditing:YES animated:YES];
    
    
 /*   NSString * jid = @"foo@silentcircle.org";
  	CFErrorRef anError = NULL;
    
    ABMutableMultiValueRef im = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
    NSMutableDictionary *imDict = [[NSMutableDictionary alloc] init];
    
    [imDict setObject:(NSString*)kABPersonInstantMessageServiceJabber forKey:(NSString*) kABPersonInstantMessageServiceKey];
    [imDict setObject:jid  forKey:(NSString*)kABPersonInstantMessageUsernameKey];
    
    ABMultiValueAddValueAndLabel(im, (__bridge CFTypeRef) imDict, kABOtherLabel, NULL);
    
    ABRecordSetValue(person, kABPersonInstantMessageProperty, im, &anError);
    
    if( anError == NULL)
    {
        ABPersonViewController *picker = [[ABPersonViewController alloc] init];
        
//        picker.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel",nil) style:UIBarButtonItemStyleDone target:self action:@selector(ReturnFromPersonView1)];
        
        picker.personViewDelegate = self;
        picker.displayedPerson = person;
        
        picker.allowsEditing = YES;
        picker.allowsActions = YES;
        
        
        //  [picker setHighlightedItemForProperty:kABPersonInstantMessageProperty withIdentifier:(ABMultiValueIdentifier)1];
        
        
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
        
        [self presentModalViewController:navigation animated:YES];
 
 //       [picker setEditing:YES];
        CFRelease(im);

        return YES;
    }
    else
 */
 
    
#endif
    
    return NO;
    
}


// Does not allow users to perform default actions such as dialing a phone number, when they select a person property.
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person 
								property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
    
	return YES;

}


// Dismisses the people picker and shows the application when users tap Cancel. 
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker;
{
	[self dismissModalViewControllerAnimated:YES];
   [self.navigationController popViewControllerAnimated:YES];
}


-(void) addJIDToContact:  (XMPPJID *)jid
{
    
 	ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
    
  	// Display only a person's IM property
	NSArray *displayedItems = [NSArray arrayWithObjects:[NSNumber numberWithInt:kABPersonInstantMessageProperty]  
							   , nil];
 
//    picker.displayedProperties = displayedItems;
    picker.peoplePickerDelegate = self;
  
     
    [self presentModalViewController:picker animated:YES];
 
}


@end
