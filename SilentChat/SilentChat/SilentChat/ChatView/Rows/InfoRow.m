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
//  InfoRow.m
//  SilentText
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif


#import "InfoRow.h"
#import "XMPPJID.h"
#import "InfoEntry.h"
#import "Conversation.h"
#import "AppConstants.h"
#import "XMPPJID+AddressBook.h"
#import <QuartzCore/QuartzCore.h>

#import "NSDate+SCDate.h"
#define CLASS_DEBUG 0
#import "DDGMacros.h"


NSString *const kInfoEntry = @"infoEntry";
NSString *const kInfoCellIdentifier = @"InfoCellIdentifier";

@implementation InfoRow

@dynamic date;
@dynamic height;
@dynamic reuseIdentifier;
@dynamic tableViewCell;

@synthesize infoEntry = _infoEntry;
@synthesize delegate = _delegate;
@synthesize indexRow = _indexRow;


#pragma mark - ChatViewRow and accessor methods.


- (CGFloat) height {
	
	return 40.0f;
	
} // -height


- (NSDate *) date {
	
	return self.infoEntry.date;
	
} // -date


- (NSString *) reuseIdentifier {
	
	return kInfoCellIdentifier;
	
} // -reuseIdentifier


- (UITableViewCell *) tableViewCell {
	
	return [UITableViewCell.alloc initWithStyle: UITableViewCellStyleDefault
								reuseIdentifier: self.reuseIdentifier];
	
} // -tableViewCell


- (UITableViewCell *) configureCell: (UITableViewCell *) cell {
	DDGTrace();
	NSDictionary * info = self.infoEntry.info;
	
	CGRect bounds = cell.contentView.bounds;
	
	bounds.size.height = self.height;
	
	cell.contentView.bounds = bounds;
	cell.textLabel.frame    = bounds;
	cell.textLabel.textAlignment = UITextAlignmentCenter;
	cell.contentView.backgroundColor = UIColor.clearColor;
	cell.textLabel.backgroundColor = UIColor.clearColor;
	cell.textLabel.font = [UIFont systemFontOfSize: 14.0];
	cell.textLabel.textColor = UIColor.lightGrayColor;
//	cell.textLabel.layer.backgroundColor = [UIColor darkGrayColor].CGColor;
//	cell.textLabel.layer.cornerRadius = 5.0;

	if(info)
	{
		XMPPJID* remoteJid = [XMPPJID jidWithString: [info objectForKey: kInfoEntryJID ]];
		
		cell.textLabel.text  =
		[NSString stringWithFormat:@"Connected to %@", remoteJid.resource?remoteJid.resource:@"Unknown"];
	}
	
	return cell;
	
} // -configureCell:

@end
