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
//  SCAddressBookController.m
//  SilentText
//

#import "App.h"
#import "AppConstants.h"
#import "SCAddressBookController.h"
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "MBProgressHUD.h"
#import "MZAlertView.h"

@interface SCAddressBookController ()



@property (nonatomic, strong) id <SCAddresssBoookControllerDelegate> delegate;

@property (nonatomic, retain)   NSString* vCardPath;
@property (nonatomic,strong)    QLPreviewController* previewController;
@property (nonatomic, strong)   MBProgressHUD    *HUD;

@end;

@implementation SCAddressBookController
 
 
- (void)viewDidLoad {
    
    _vCardPath  = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    _vCardPath = [[_vCardPath stringByAppendingPathComponent: kDirectorySCloudCache] stringByAppendingPathComponent:@"vCard.vcf"];

    [super viewDidLoad];
}


- (void)viewDidUnload {
    
    [self removeVCardFile];
  
    _vCardPath = NULL;
    _previewController = NULL;
    [super viewDidUnload];
}


#pragma mark - create new contact info of JID

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

-(NSString*) createVCardwithJid: (XMPPJID*)jid
{
   
    NSString* const vCardTemplate =  @
                            "BEGIN:VCARD\n"
                            "VERSION:3.0\n"
                            "N:;;;;\n"
                            "FN:%@\n"
                            "item1.EMAIL;type=INTERNET;type=pref:%@\n"
                            "item1.X-ABLabel:silent circle\n"
                            "END:VCARD\n";
    
    NSString* vCard = [NSString stringWithFormat:vCardTemplate, jid.bare, jid.bare];
    
    return vCard;
}

-(void) createContactWithJID: (XMPPJID *)jid
{
#if 1
    NSString* vCard = [self createVCardwithJid:jid];
    
    [self showContactForVCard: vCard];
 
#else
      ABRecordRef aContact = ABPersonCreate();
	CFErrorRef anError = NULL;
    NSString* email_address = [NSString stringWithFormat:@"%@@%@", jid.user, kDefaultAccountDomain];
    
    ABMutableMultiValueRef emailMultiValue = ABMultiValueCreateMutable(kABPersonEmailProperty);
    ABMultiValueAddValueAndLabel(emailMultiValue,(__bridge CFTypeRef)  email_address, (CFStringRef)@"Silent Circle", NULL);
    ABRecordSetValue(aContact, kABPersonEmailProperty, emailMultiValue, &anError);
    
    if (anError == NULL)
    {
        ABNewPersonViewController *picker = [[ABNewPersonViewController alloc] init];
        picker.newPersonViewDelegate = self;
        picker.displayedPerson = aContact;
        
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
        [self presentModalViewController:navigation animated:YES];
    }
    
    CFRelease(emailMultiValue);
    CFRelease(aContact);
#endif
}



#pragma mark - Display the existing contact info of JID

// Does not allow users to perform default actions such as emailing a contact, when they select a contact property.
// in the case of the jabberID we dont allow it it.

- (BOOL)personViewController:(ABPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person
					property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifierForValue
{
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
            
            
            picker.personViewDelegate = self;
            picker.displayedPerson = person;
            
            // Allow users to edit the person’s information
            picker.allowsEditing = YES;
            picker.allowsActions = YES;
            
            UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
            navigation.navigationBar.barStyle = UIBarStyleBlack;
            navigation.navigationBar.translucent = NO;
          
            picker.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
                                                       initWithTitle:NSLocalizedString(@"Back",nil)
                                                       style:UIBarButtonItemStyleBordered
                                                       target:self
                                                       action:@selector(ReturnFromPersonView)];
     
              [self presentModalViewController:navigation animated:YES];
            
        }
    }
    
    CFRelease(addressBook);
}



#pragma mark - Display the existing contact info of JID


-(void) sendContactSCloudWithDelegate: (id) aDelagate;
{
    self.delegate = aDelagate;
    
    ABPeoplePickerNavigationController* picker = [[ABPeoplePickerNavigationController alloc] init];
    picker.peoplePickerDelegate = self;
    
    //    picker.modalPresentationStyle = UIModalPresentationCurrentContext;
    //    picker.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self presentViewController:picker
                       animated:YES
                     completion: NULL];
    
}


// Called after a value has been selected by the user.
// Return YES if you want default action to be performed.
// Return NO to do nothing (the delegate is responsible for dismissing the peoplePicker).
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
    return NO;
}


- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker;
{
    
 	[self dismissModalViewControllerAnimated:NO];
    [self.navigationController popViewControllerAnimated:YES];
}
 
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
     
    if(![_delegate respondsToSelector: @selector(didFinishPickingWithScloud:name:image:)])
        return NO;

    NSString* username =  (__bridge_transfer NSString*) ABRecordCopyCompositeName(person);
    
   if(!username) username = @"No Name";
     
    MZAlertView *alert = [[MZAlertView alloc] initWithTitle:@"Send Contact"
                                                    message:
                          [NSString stringWithFormat:@"Send Contact info for %@", username]
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"OK", nil];
    
    
    [alert setActionBlock: ^(NSInteger buttonPressed, NSString *alertText){
        if (buttonPressed == 1) {
            
            UIImage* image = NULL;

            if(ABPersonHasImageData(person))
            {
                CFDataRef imageData = ABPersonCopyImageDataWithFormat(person,kABPersonImageFormatThumbnail);
                image =  imageData?[UIImage imageWithData:(__bridge_transfer NSData*) imageData]:nil;
            }
            
            CFDataRef vCardDataRef = ABPersonCreateVCardRepresentationWithPeople((__bridge CFArrayRef)[NSArray arrayWithObject:(__bridge id)(person)]);
            
            if (vCardDataRef)
            {
                __block SCloudObject    *scloud     = NULL;
                __block NSError         *error      = NULL;
                __block NSData          *theData    = (__bridge NSData*)vCardDataRef;
                __block NSDictionary    *theInfo    =  [NSDictionary dictionaryWithObjectsAndKeys:
                                                        (__bridge NSString*) kUTTypeVCard,kSCloudMetaData_MediaType,
                                                        username , kSCloudMetaData_FileName,
                                                        nil];
                
                scloud =  [[SCloudObject alloc] initWithDelegate:self
                                                            data:theData
                                                        metaData:theInfo
                                                       mediaType:(__bridge NSString*) kUTTypeVCard
                                                   contextString:App.sharedApp.currentJID.bare ];
                
                
                _HUD = [[MBProgressHUD alloc] initWithView:peoplePicker.view];
                [peoplePicker.view addSubview:_HUD];
                _HUD.mode = MBProgressHUDModeAnnularDeterminate;
                _HUD.labelText = [NSString stringWithFormat:NSLS_COMMON_PREPARING, NSLS_COMMON_CONTACT];
                
                [_HUD showAnimated:YES whileExecutingBlock:^{
                    
                    if(theData && theInfo); // force to retain data and info
                    
                    [scloud saveToCacheWithError:&error];
                    
                } completionBlock:^{
                    
                    [_HUD removeFromSuperview];
                    
                    [self dismissModalViewControllerAnimated:YES];
                    [self.navigationController popViewControllerAnimated:YES];
                    CFRelease(vCardDataRef);
                    
                    if(error)
                    {
                        scloud = NULL;
                    }
                    else
                    {
                        [_delegate didFinishPickingWithScloud:scloud name:username image:image];
                    }
                }];
                
                
            }
            else
            {
                [self dismissModalViewControllerAnimated:YES];
                [self.navigationController popViewControllerAnimated:YES];
            }
          
            }
        }];
    [alert show];
        
    return NO;
}

-(void) removeVCardFile
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    
    if( _vCardPath && [fm fileExistsAtPath:_vCardPath])
        [fm removeItemAtPath:_vCardPath error:&error];
    
    
}



-(void) showContactForVCard: (NSString*)vCard
{
    NSError *error;
    
    [self removeVCardFile];
    
    if([vCard writeToFile:_vCardPath atomically:YES encoding:NSUTF8StringEncoding error:&error])
    {
        // When user taps a row, create the preview controller
        QLPreviewController *pvc = [[QLPreviewController alloc] init];
        pvc.dataSource = self;
        pvc.delegate = self;
        pvc.currentPreviewItemIndex = 0;
        
        //set the frame from the parent view
        CGFloat w= self.previewView.frame.size.width;
        CGFloat h= self.previewView.frame.size.height;
        pvc.view.frame = CGRectMake(0, 0,w, h);
        
        //save a reference to the preview controller in an ivar
        self.previewController = pvc;
        
        //refresh the preview controller
        self.previewView.hidden = NO;
        [self.previewView  addSubview:pvc.view];
        
        [pvc reloadData];
        [[pvc view]setNeedsLayout];
        [[pvc view ]setNeedsDisplay];
        [pvc refreshCurrentPreviewItem];
        
        self.navigationItem.title = NSLS_COMMON_IMPORT_CONTACT;

    };

}


#pragma mark - Preview Controller

 
/*---------------------------------------------------------------------------
 *
 *--------------------------------------------------------------------------*/
- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller
{
	return 1;
}

/*---------------------------------------------------------------------------
 *
 *--------------------------------------------------------------------------*/
- (id <QLPreviewItem>)previewController: (QLPreviewController *)controller previewItemAtIndex:(NSInteger)index
{
    
	return [NSURL fileURLWithPath:_vCardPath];
}

#pragma mark -
#pragma mark SCloudObjectDelegate methods

- (void)scloudObject:(SCloudObject *)sender calculatingKeysDidStart:(NSString*) mediaType
{
    _HUD.mode = MBProgressHUDModeIndeterminate;
}

- (void)scloudObject:(SCloudObject *)sender calculatingKeysProgress:(float) progress
{
    self.HUD.progress = progress;
}

- (void)scloudObject:(SCloudObject *)sender calculatingKeysDidCompleteWithError:(NSError *)error
{
}

- (void)scloudObject:(SCloudObject *)sender encryptingDidStart:(NSString*) mediaType
{
    _HUD.mode = MBProgressHUDModeIndeterminate;
    _HUD.labelText = @"Encrypting";
    
}

- (void)scloudObject:(SCloudObject *)sender encryptingProgress:(float) progress
{
    self.HUD.progress = progress;
    
}
- (void)scloudObject:(SCloudObject *)sender encryptingDidCompleteWithError:(NSError *)error
{
    
}


 
@end
