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
#import "ContactsSubViewControllerCell.h"
#import "AppDelegate.h"
#import "AppTheme.h"

@implementation ContactsSubViewControllerCell

@synthesize userId = userId;
@synthesize abRecordID = abRecordID;
@synthesize avatarUrl = avatarUrl;
@synthesize jid = jid;

@synthesize avatarImageView = avatarImageView;
@synthesize nameLabel = nameLabel;
@synthesize meLabel = meLabel;

@synthesize expanded = _bExpanded;

+ (float)cellHeightExpanded:(BOOL)bExpanded {
	return bExpanded ? 70 : 46;
}

- (void)_tintButtonImage:(UIButton *)button imageName:(NSString *)imageName {
	UIImage *image = [[UIImage imageNamed:imageName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[button setImage:image forState:UIControlStateNormal];
	button.tintColor = STAppDelegate.theme.appTintColor;
}

- (void)setExpanded:(BOOL)expanded {
	// setup button tint colors here
	[self _tintButtonImage:_chatButton imageName:@"contact-message_btn.png"];
	[self _tintButtonImage:_phoneButton imageName:@"contact-phone_btn.png"];
	[self _tintButtonImage:_addContactButton imageName:@"contact-add-contact_btn.png"];
	[self _tintButtonImage:_infoButton imageName:@"contact-info_btn.png"];

	_bExpanded = expanded;
	_chatButton.hidden = !expanded;
	_phoneButton.hidden = !expanded;
	_addContactButton.hidden = (!expanded || _isSavedToSilentContacts);
	_infoButton.hidden = (!expanded || !_isSavedToSilentContacts);
}

- (IBAction)chatTapped:(id)sender {
	if ( (_delegate) && ([_delegate respondsToSelector:@selector(contactsCellChatTapped:)]) )
		[_delegate performSelector:@selector(contactsCellChatTapped:) withObject:self];
}

- (IBAction)phoneTapped:(id)sender {
	if ( (_delegate) && ([_delegate respondsToSelector:@selector(contactsCellPhoneTapped:)]) )
		[_delegate performSelector:@selector(contactsCellPhoneTapped:) withObject:self];
}

- (IBAction)addContactTapped:(id)sender {
	if ( (_delegate) && ([_delegate respondsToSelector:@selector(contactsCellAddContactTapped:)]) )
		[_delegate performSelector:@selector(contactsCellAddContactTapped:) withObject:self];
}

- (IBAction)infoTapped:(id)sender {
	if ( (_delegate) && ([_delegate respondsToSelector:@selector(contactsCellInfoTapped:)]) )
		[_delegate performSelector:@selector(contactsCellInfoTapped:) withObject:self];
}

@end
