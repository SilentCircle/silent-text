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
//  AddressBookController.m
//  SilentText
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "AddressBookController.h"
#import "XMPPvCardAvatarModule.h"
#import "XMPPServer.h"
#import "App.h"
 
@interface AddressBookController()


typedef enum
{
    kSCAddressBookOperation_Invalid,
    kSCAddressBookOperation_PickVCard,
    kSCAddressBookOperation_Update,
    kSCAddressBookOperation_Create,
    kSCAddressBookOperation_Show,
    
}SCAddressBookOperation ;


@property (nonatomic)   SCAddressBookOperation mode;

 
@end

@implementation AddressBookController
 
        
 
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
    
    self.mode = kSCAddressBookOperation_Invalid;
    
}


-(void) showContactForJID: (XMPPJID*)jid
{
    ABRecordID recordID = [jid addressBookRecordID];
    ABAddressBookRef addressBook = ABAddressBookCreate();

    self.mode = kSCAddressBookOperation_Show;
    
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
  
    self.mode = kSCAddressBookOperation_Invalid;

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
    
    self.mode = kSCAddressBookOperation_Invalid;

}


-(void) createContactWithJID: (XMPPJID *)jid
{
    ABRecordRef aContact = ABPersonCreate();
	CFErrorRef anError = NULL;
  
       
    ABMutableMultiValueRef im = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
    NSMutableDictionary *imDict = [[NSMutableDictionary alloc] init];
 
    self.mode = kSCAddressBookOperation_Create;

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

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person
                                property:(ABPropertyID)property
                              identifier:(ABMultiValueIdentifier)identifier
{
     return NO;
}


- (void)ReturnFromPersonView1{
    
//	[self dismissModalViewControllerAnimated:YES];
    
    [self.navigationController popViewControllerAnimated:YES];
}


- (void)SendContact{
    
//    [self dismissModalViewControllerAnimated:NO];
    [self.navigationController popViewControllerAnimated:YES];
 //   [self dismissModalViewControllerAnimated:YES];
     
 
        [self.delegate didFinishPickingWithVcard:NULL];
}

// Dismisses the people picker and shows the application when users tap Cancel.
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker;
{

 	[self dismissModalViewControllerAnimated:NO];
     [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
    
 /// NONE of this works!
    
    
    [self dismissViewControllerAnimated:YES
      completion:^{
         
            [self.navigationController popViewControllerAnimated:NO];
  
          ABPersonViewController *picker = [[ABPersonViewController alloc] init];
          
          picker.personViewDelegate = self;
          picker.displayedPerson = person;
          
#if 0
          UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
          [self presentModalViewController:navigation animated:YES];
#else
          [self.navigationController pushViewController: picker animated: YES];
#endif
          
          
          picker.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                                     initWithTitle:NSLocalizedString(@"Send",nil)
                                                     style:UIBarButtonItemStyleDone
                                                     target:self
                                                     action:@selector(SendContact)];
          

         // animation to show view controller has completed.
     }];

 	  
    return YES ;
    
    if(self.mode == kSCAddressBookOperation_PickVCard)
    {
         
        ABPersonViewController *picker = [[ABPersonViewController alloc] init];
        
        picker.personViewDelegate = self;
        picker.displayedPerson = person;
           
#if 0
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
        [self presentModalViewController:navigation animated:YES];
#else
        [self.navigationController pushViewController: picker animated: YES];
#endif
        
        
         picker.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                                    initWithTitle:NSLocalizedString(@"Send",nil)
                                                    style:UIBarButtonItemStyleDone
                                                    target:self
                                                    action:@selector(SendContact)];
          
        return YES;
        

    }
    else  if(self.mode == kSCAddressBookOperation_Update)
    {

//    [self.navigationController popViewControllerAnimated:NO];
    

    ABPersonViewController *picker = [[ABPersonViewController alloc] init];
     
    picker.personViewDelegate = self;
    picker.displayedPerson = person;
    // Allow users to edit the person’s information
    picker.allowsEditing = YES;
 
#if 1
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
    [self presentModalViewController:navigation animated:YES];
#else
    [self.navigationController pushViewController: picker animated: YES];
#endif
    
    [picker setEditing:YES];
     [self setEditing:YES animated:YES];
    
    
    picker.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel",nil) style:UIBarButtonItemStyleDone target:self action:@selector(ReturnFromPersonView1)];

    
//    [self presentModalViewController:picker animated:YES];
    return NO;
        
    }
    return NO;

}

-(void) addJIDToContact:  (XMPPJID *)jid
{
    
 	ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
   
    self.mode = kSCAddressBookOperation_Update;

    picker.peoplePickerDelegate = self;
    [self presentModalViewController:picker animated:YES];
 
}

#pragma mark - pick contact vcard
 
-(void) pickContactWithDelagate: (id) aDelagate
{
    self.delegate = aDelagate;
    self.mode = kSCAddressBookOperation_PickVCard;
      
    ABPeoplePickerNavigationController* picker = [[ABPeoplePickerNavigationController alloc] init];
    picker.peoplePickerDelegate = self;
    
    picker.modalPresentationStyle = UIModalPresentationCurrentContext;
    picker.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self presentViewController:picker
                       animated:YES
                     completion:^{
                         
    
                         // animation to show view controller has completed.
                     }];

    
    
    
   
}


@end
