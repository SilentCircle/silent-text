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
#import <Foundation/Foundation.h>
#import <AddressBook/ABRecord.h>

@class ContactsSubViewControllerCell;

@protocol ContactsSubViewControllerCellDelegate <NSObject>
@required
- (void)contactsCellChatTapped:(ContactsSubViewControllerCell *)cell;
// NYI:
// - (void)contactsCellFavoriteTapped:(ContactsSubViewControllerCell *)cell;
- (void)contactsCellPhoneTapped:(ContactsSubViewControllerCell *)cell;
- (void)contactsCellAddContactTapped:(ContactsSubViewControllerCell *)cell;
- (void)contactsCellInfoTapped:(ContactsSubViewControllerCell *)cell;
@end

@interface ContactsSubViewControllerCell : UITableViewCell

@property (nonatomic, assign) NSObject<ContactsSubViewControllerCellDelegate> *delegate;

@property (nonatomic, strong) NSString *userId;
@property (nonatomic, assign) ABRecordID abRecordID;
@property (nonatomic, strong) NSString *avatarUrl;
@property (nonatomic, strong) NSString *jid;

@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) BOOL isSavedToSilentContacts;

@property (nonatomic, weak, readwrite) IBOutlet UIImageView *avatarImageView;
@property (nonatomic, weak, readwrite) IBOutlet UILabel *nameLabel;
@property (nonatomic, weak, readwrite) IBOutlet UILabel *meLabel;
@property (weak, nonatomic) IBOutlet UIImageView *companyIconImageView;

@property (weak, nonatomic) IBOutlet UIButton *chatButton;
@property (weak, nonatomic) IBOutlet UIButton *phoneButton;
@property (weak, nonatomic) IBOutlet UIButton *addContactButton;
@property (weak, nonatomic) IBOutlet UIButton *infoButton;

- (IBAction)chatTapped:(id)sender;
- (IBAction)phoneTapped:(id)sender;
- (IBAction)addContactTapped:(id)sender;
- (IBAction)infoTapped:(id)sender;

+ (float)cellHeightExpanded:(BOOL)bExpanded;

@end
