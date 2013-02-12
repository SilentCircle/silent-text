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
//  RekeyRow.m
//  SilentText
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "SCimpLogEntry.h"
#import "AppConstants.h"
#import "Conversation.h"
#include "SCpubTypes.h"

#import "RekeyRow.h"
//#import <QuartzCore/QuartzCore.h>

#import "NSDate+SCDate.h"
//#define CLASS_DEBUG 0
#import "DDGMacros.h"

NSString *const kLogEntry = @"logEntry";
NSString *const kRekeyCellIdentifier = @"RekeyCellIdentifier";

@interface RekeyRow()

@property (strong, nonatomic) UITableViewCell* cell;
@property (strong, nonatomic) UITapGestureRecognizer *tapRecognizer;

@end

@implementation RekeyRow


@dynamic date;
@dynamic height;
@dynamic reuseIdentifier;
@dynamic tableViewCell;

@synthesize logEntry = _logEntry;
@synthesize delegate = _delegate;
@synthesize indexRow = _indexRow;

#pragma mark - ChatViewRow and accessor methods.

- (NSDate *) date {
    
    return self.logEntry.date;
    
} // -date


- (CGFloat) height {
    
    return 30.0f;
    
} // -height


- (NSString *) reuseIdentifier {
    
    return kRekeyCellIdentifier;
    
} // -reuseIdentifier


- (UITableViewCell *) tableViewCell {
    
    UITableViewCell* cell =  [UITableViewCell.alloc initWithStyle: UITableViewCellStyleDefault
                                reuseIdentifier: self.reuseIdentifier];
    
     
    return cell;
    
} // -tableViewCell

-(void) dealloc
{
    if(_tapRecognizer)
        [self.cell.contentView removeGestureRecognizer: _tapRecognizer];
    _tapRecognizer = NULL;
  
}
 


- (UITableViewCell *) configureCell: (UITableViewCell *) cell {
	DDGTrace();
    if(!cell) return nil;
    
    CGRect bounds = cell.contentView.bounds;
    CGRect iconRect =  CGRectMake(18, 5, 20, 20);
    CGFloat offset = iconRect.origin.x + iconRect.size.width;
    bounds.size.height = self.height;
    CGRect textRect =  bounds;
    textRect.origin.x +=offset;
    textRect.size.width -=offset;

    NSNumber *number = nil;
    NSDictionary *info = self.logEntry.info;
    NSString* logType =  [info valueForKey:kSCimpLogEntryType];
    UIImage *keyImage = nil;
  
    cell.contentView.bounds = bounds;
    cell.indentationLevel = 1;
    cell.indentationWidth = offset;
    
//  cell.textLabel.frame  =  textRect;
    cell.textLabel.textAlignment = UITextAlignmentLeft;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.userInteractionEnabled  = YES;
    cell.textLabel.textColor = UIColor.orangeColor;
    cell.textLabel.font = [UIFont italicSystemFontOfSize: 14.0];
//	cell.textLabel.backgroundColor = [UIColor darkGrayColor];
//	cell.textLabel.layer.cornerRadius = 5.0;

    _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [cell.contentView addGestureRecognizer:_tapRecognizer];
    
    _cell = cell;
    
    if(logType)
    {
        if([logType isEqualToString:kSCimpLogEntryTransition])
        {
            
            ConversationState state = kSCimpState_Init;
            NSString *msg = nil;
            
            if ((number = [info valueForKey:kSCIMPInfoTransition])) {
                state = number.unsignedIntValue;
            }
            
            switch (state)
            {
                case kConversationState_Commit:
                case kConversationState_DH1:
                    keyImage = [UIImage imageNamed:@"key2"];
                    msg = NSLS_COMMON_KEYS_ESTABLISHING;
                    break;
                    
                case kConversationState_DH2:
                case kConversationState_Confirm:
                    keyImage = [UIImage imageNamed:@"key3"];
                    msg = NSLS_COMMON_KEYS_ESTABLISHED;
                    break;
                    
                case kConversationState_Ready:
                    cell.textLabel.textColor = UIColor.whiteColor;
                    msg = NSLS_COMMON_KEYS_READY;
                    break;
                    
                case kConversationState_Error:
                    cell.textLabel.textColor = UIColor.redColor;
                    keyImage = [UIImage imageNamed:@"attention"];
                     msg = NSLS_COMMON_KEYS_ERROR;
                    break;
                    
                default:  ;
                    cell.textLabel.textColor = UIColor.redColor;
                     msg = @"<ERROR>";
                    break;
            }
 
                cell.textLabel.text = [NSString stringWithFormat: @"%@",  msg];
         }
        else if([logType isEqualToString:kSCimpLogEntrySecure])
        {
            BOOL secretsMatch = NO;
            BOOL has_secret  = NO;
            
            if ((number = [info valueForKey:kSCIMPInfoCSMatch])) {
                secretsMatch = number.boolValue;
            }
            
   
            if ((number = [info valueForKey:kSCIMPInfoHasCS])) {
                has_secret = number.boolValue;
            }

              
            keyImage = [UIImage imageNamed:@"key4"];
            cell.textLabel.text = [NSString stringWithFormat: @"%@:",NSLS_COMMON_KEYS_READY];
            
            if(secretsMatch && has_secret)
                cell.textLabel.textColor = UIColor.greenColor;


        }
        else if([logType isEqualToString:kSCimpLogEntryWarning])
        {
            cell.textLabel.textColor = UIColor.orangeColor;
            cell.textLabel.text = [NSString stringWithFormat: @"-- Warning: %d, %@ --  %@",
                                   self.logEntry.error, self.logEntry.errorString,  [self.date whenString ]];

        }
        
        else if([logType isEqualToString:kSCimpLogEntryError])
        {
            cell.textLabel.textColor = UIColor.orangeColor;
            cell.textLabel.text = [NSString stringWithFormat: @"-- Error: %d, %@ --  %@",
                                   self.logEntry.error, self.logEntry.errorString,  [self.date whenString ]];
 
        }
        
        if(keyImage)
        {
            UIImageView *keyImageView = [[UIImageView alloc] initWithImage:keyImage];
            [keyImageView setFrame:iconRect];
            [cell.contentView addSubview:keyImageView];
         }
  
    }
    return cell;
    
} // -configureCell:


- (void) tap: (UITapGestureRecognizer *) gestureRecognizer {
  
    if([_delegate respondsToSelector: kTappedCell]) {
        
        [_delegate tappedCell: (ChatViewRow*) self];
        
    }

#if 0
    CGPoint hitPoint = [gestureRecognizer locationInView:_cell];
    CGRect iconRect =  CGRectMake(18, 5, 20, 20);

    if(CGRectContainsPoint (iconRect,  hitPoint)
        && [_delegate respondsToSelector: kTappedCell]) {
             
            [_delegate tappedCell: (ChatViewRow*) self];
        return;
       }
#endif
    
}

@end
