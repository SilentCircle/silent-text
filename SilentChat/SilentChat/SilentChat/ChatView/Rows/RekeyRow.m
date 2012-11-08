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

#import "SCimpLogEntry.h"
#include "SCpubTypes.h"

#import "RekeyRow.h"

#import "NSDate+SCDate.h"

NSString *const kLogEntry = @"logEntry";
NSString *const kRekeyCellIdentifier = @"RekeyCellIdentifier";

@implementation RekeyRow

@dynamic date;
@dynamic height;
@dynamic reuseIdentifier;
@dynamic tableViewCell;

@synthesize logEntry = _logEntry;

#pragma mark - ChatViewRow and accessor methods.

- (NSDate *) date {
    
    return self.logEntry.date;
    
} // -date


- (CGFloat) height {
    
    return 20.0f;
    
} // -height


- (NSString *) reuseIdentifier {
    
    return kRekeyCellIdentifier;
    
} // -reuseIdentifier


- (UITableViewCell *) tableViewCell {
    
    return [UITableViewCell.alloc initWithStyle: UITableViewCellStyleDefault 
                                reuseIdentifier: self.reuseIdentifier];
    
} // -tableViewCell


- (UITableViewCell *) configureCell: (UITableViewCell *) cell {
    
    CGRect bounds = cell.contentView.bounds;
  
    NSDictionary *info = self.logEntry.info;

    bounds.size.height = self.height;
 
    cell.contentView.bounds = bounds;
    cell.textLabel.frame    = bounds;
    cell.textLabel.textAlignment = UITextAlignmentCenter;
    cell.textLabel.textColor = UIColor.orangeColor;
    cell.textLabel.font = [UIFont systemFontOfSize: 12.0];
    
    if(self.logEntry.error == kSCLError_NoErr)
    {
        NSString *SAS  = [info valueForKey:@"SAS"];
        
        cell.textLabel.textColor = UIColor.orangeColor;
        cell.textLabel.font = [UIFont systemFontOfSize: 12.0];
        cell.textLabel.text = [NSString stringWithFormat: @"-- Rekey: %@ -- %@",  SAS, [self.date whenString]];
       
    }
    else
    {
        cell.textLabel.textColor = UIColor.orangeColor;
        cell.textLabel.font = [UIFont systemFontOfSize: 12.0];
        cell.textLabel.text = [NSString stringWithFormat: @"-- Error: %d, %@ --  %@",
                               self.logEntry.error, self.logEntry.errorString,  [self.date whenString ]];
    }
     
    
    
    
    
    return cell;
    
} // -configureCell:

@end
