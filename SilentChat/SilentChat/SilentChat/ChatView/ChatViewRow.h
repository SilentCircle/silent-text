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
//  ChatViewRow.h
//  SilentText
//

#import <UIKit/UIKit.h>

@class ChatViewRow;

@protocol ChatViewRowDelegate <NSObject>
@optional
- (void) unhideNavBar;
- (void) tappedGeo: (ChatViewRow *) cell;

#define kTappedCell  (@selector(tappedCell:))
- (void) tappedCell: (ChatViewRow *) cell;


#define kTappedAvatar  (@selector(tappedAvatar:))
- (void) tappedAvatar: (ChatViewRow *) cell;

#define kTappedResend  (@selector(tappedResend:))
- (void) tappedResend: (ChatViewRow *) cell;

#define kTappedFailure  (@selector(tappedFailure:))
- (void) tappedFailure: (ChatViewRow *) cell;

#define kTappedDeleteRow  (@selector(tappedDeleteRow:))
- (void) tappedDeleteRow: (ChatViewRow *) cell;

#define kTappedForwardRow  (@selector(tappedForwardRow:))
- (void) tappedForwardRow: (ChatViewRow *) cell;

- (void) resignActiveTextEntryField;
@end

@protocol ChatViewRow <NSObject>
@required

@property (unsafe_unretained, nonatomic) id <ChatViewRowDelegate> delegate;

@property (strong, nonatomic, readonly) NSDate *date;
@property (nonatomic, readonly) CGFloat height;
@property (strong, nonatomic, readonly) NSString *reuseIdentifier;
@property (weak,   nonatomic, readonly) UITableViewCell *tableViewCell;
@property (nonatomic) UInt32 indexRow;
   - (UITableViewCell *) configureCell: (UITableViewCell *) cell;
- (id) valueForUndefinedKey: (NSString *) key; // Must return nil.

@end
