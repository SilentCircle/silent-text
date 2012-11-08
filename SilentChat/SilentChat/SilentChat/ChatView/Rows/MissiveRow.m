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

#import "Missive.h"

#import "MissiveRow.h"

#import "Siren.h"
#import "Conversation.h"

#import "STBubbleTableViewCell.h"
#import "NSDate+SCDate.h"
#import "CLLocation+NSDictionary.h"

//#define CLASS_DEBUG 1
#import "DDGMacros.h"

NSString *const kBubbleCellIdentifier = @"BubbleCellIdentifier";
NSString *const kMissive = @"missive";

@interface MissiveRow ()

@property (strong, nonatomic, readonly) STBubbleTableViewCell *scratchCell;
@property (nonatomic, readonly) AuthorType authorType;

@end

@implementation MissiveRow

@dynamic date;
@dynamic height;
@dynamic reuseIdentifier;
@dynamic tableViewCell;

@synthesize missive = _missive;
@synthesize bubble = _bubble;
@synthesize otherBubble = _otherBubble;
@synthesize clockImage = _clockImage;

@synthesize selectedBubble = _selectedBubble;
@synthesize plainTextBubble = _plainTextBubble;

@dynamic scratchCell;
@dynamic authorType;

#pragma mark - Accessor methods.


- (NSDate *) date {
    
    return self.missive.date;
    
} // -date


- (CGFloat) height {
    
    STBubbleTableViewCell *btvc = self.scratchCell;
    
    [btvc prepareForReuse];

    [self configureCell: btvc];
    
    return btvc.height;
    
} // -height


- (NSString *) reuseIdentifier {
    
    return kBubbleCellIdentifier;
    
} // -reuseIdentifier


- (UITableViewCell *) tableViewCell {
    
    return [STBubbleTableViewCell.alloc initWithStyle: UITableViewCellStyleDefault 
                                      reuseIdentifier: self.reuseIdentifier];
    
} // -tableViewCell


#pragma mark - Public methods.


- (STBubbleTableViewCell *) configureBubbleCell: (STBubbleTableViewCell *) cell withSiren: (Siren *) siren {
    
//    DDGDesc(siren);
 
    NSString* shredString = self.missive.shredDate?self.missive.shredDate.whenString:NULL;
    
     cell.textLabel.text  =  shredString
                ?[NSString stringWithFormat:@"%@\n<Burn: %@ >", siren.message, shredString]
                :siren.message;
    
    if(self.missive.flags != 0 )
    {
        if(self.missive.flags & kMissiveFLag_RequestResend)
        {
            cell.textLabel.text = [NSString stringWithFormat:
                                   @"%@\n<Not Decrypted>",cell.textLabel.text ];
        }
        else
        {
            cell.textLabel.text = [NSString stringWithFormat:
                                   @"%@\n<flags:%02X >",cell.textLabel.text, self.missive.flags ];
          
        }
    }
    
    
    if(siren.location)
    {
        NSError *jsonError;
        
        NSDictionary *locInfo = [NSJSONSerialization
                                 JSONObjectWithData:[siren.location dataUsingEncoding:NSUTF8StringEncoding]
                                 options:0 error:&jsonError];
        
        if (jsonError==nil){
            
            double latitude  =  [[locInfo valueForKey:@"latitude"]doubleValue];
            double longitude  = [[locInfo valueForKey:@"longitude"]doubleValue];
            double altitude  =  [[locInfo valueForKey:@"altitude"]doubleValue];
  
            cell.textLabel.text = [NSString stringWithFormat:
                                   @"%@\n<location:(%.2lf, %.2lf, %.2lf) >",
                                   cell.textLabel.text,latitude, longitude, altitude  ];
        }
        
    }
    
    cell.textLabel.font = [UIFont systemFontOfSize:16.0f];
    
    cell.canCopyContents = !siren.fyeo;
    
     return cell;
    
} // -configureBubbleCell:withSiren:


- (UITableViewCell *) configureCell: (UITableViewCell *) cell {
    
    if ([cell isKindOfClass: STBubbleTableViewCell.class]) {
        
        STBubbleTableViewCell *bubbleCell = (STBubbleTableViewCell *)cell;
        
        Siren *siren = self.missive.siren;
        
        bubbleCell = [self configureBubbleCell: bubbleCell withSiren: siren];
        
        bubbleCell.badgeImage = NULL;
        
        bubbleCell.delegate    = self;
        bubbleCell.authorType  = self.authorType;
        
        bubbleCell.bubbleImage = (bubbleCell.authorType == STBubbleTableViewCellAuthorTypeUser ?
                                  self.bubble : self.otherBubble);
        
 //       bubbleCell.badgeImage = (siren.shredAfter)?self.clockImage: NULL;
   
        bubbleCell.bubbleImage = siren.isPlainText ? self.plainTextBubble : bubbleCell.bubbleImage;
        
        bubbleCell.selectedBubbleImage = self.selectedBubble;
         
        cell = bubbleCell;
       }
    return cell;
    
} // -configureCell:


- (id) valueForUndefinedKey: (NSString *) key {
    
    return nil;
    
} // -valueForUndefinedKey:


static STBubbleTableViewCell *_scratchCell = nil;
static dispatch_once_t        _scratchCellGuard = 0;

- (STBubbleTableViewCell *) scratchCell {
    
    dispatch_once(&_scratchCellGuard, ^{ 
        
        _scratchCell = (STBubbleTableViewCell *)self.tableViewCell;
    });
    return _scratchCell;

} // -scratchCell


- (AuthorType) authorType {
    
    XMPPJID *localJID = [XMPPJID jidWithString: self.missive.conversation.localJID];
    
    return ([localJID.bare isEqualToString: [[XMPPJID jidWithString: self.missive.toJID] bare]] ?
            STBubbleTableViewCellAuthorTypeOther : STBubbleTableViewCellAuthorTypeUser);
    
} // -authorType


#pragma mark - STBubbleTableViewCellDelegate methods.


- (void) tappedImageOfCell: (STBubbleTableViewCell *) cell atIndexPath: (NSIndexPath *) indexPath {
    
    DDGTrace();
    
} // -tappedImageOfCell:atIndexPath:

@end
