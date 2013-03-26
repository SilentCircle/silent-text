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
//  MissiveRow.m
//  SilentText
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import <MobileCoreServices/MobileCoreServices.h>
#include "SCpubTypes.h"



#import "Missive.h"

#import "MissiveRow.h"

#import "Siren.h"
#import "Conversation.h"

#import "STBubbleTableViewCell.h"
#import "NSDate+SCDate.h"
#import "CLLocation+NSDictionary.h"
#import "XMPPJID+AddressBook.h"
#import <QuartzCore/QuartzCore.h>

//#define CLASS_DEBUG 1
#import "DDGMacros.h"

NSString *const kBubbleCellIdentifier = @"BubbleCellIdentifier";
NSString *const kMissive = @"missive";
static NSString *const kAvatarIcon = @"avatar"; //@"silhouette";

@interface MissiveRow ()

@property (strong, nonatomic, readonly) STBubbleTableViewCell *scratchCell;

@end

#define kBubbleCellFont [UIFont systemFontOfSize:16.0f]
@implementation MissiveRow

@dynamic date;
@dynamic height;
@dynamic reuseIdentifier;
@dynamic tableViewCell;

@synthesize delegate = _delegate;
@synthesize indexRow = _indexRow;

@dynamic scratchCell;

#pragma mark - Accessor methods.


- (NSDate *) date {
	
	return self.missive.date;
	
} // -date


- (CGFloat) height {
	DDGTrace();
	Siren *siren = self.missive.siren;
	NSData *thumb = siren.thumbnail;
	if (thumb)
		return [STBubbleTableViewCell quickHeightForContentViewWithImage:[UIImage imageWithData: thumb]
															  withAvatar:YES];
	else
		return [STBubbleTableViewCell quickHeightForContentViewWithText:(siren.message ? siren.message : @"")//[NSString stringWithFormat:@"%ld: %@", self.indexRow, (siren.message ? siren.message : @"")]
															   withFont:kBubbleCellFont
															 withAvatar:YES
														   withMaxWidth:self.parentView.bounds.size.width];
	
	//    STBubbleTableViewCell *btvc = self.scratchCell;
	//
	//    [btvc prepareForReuse];
	//
	//	[self configureCell: btvc];
	//
	//    return btvc.height;
	
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
	
	DDGDesc(siren);
	cell.authorType  = self.authorType;
	
	cell.textView.text =  (siren.message ? siren.message : @"");
	//	cell.textView.text =  [NSString stringWithFormat:@"%ld: %@", self.indexRow, (siren.message ? siren.message : @"")];
	//	cell.textLabel.text =  siren.message ? [siren.message stringByAppendingString:@"            "] : @"";
	if(!siren.isValid)
	{
		cell.textView.text = [ cell.textView.text stringByAppendingFormat:
							  @"\n<Decryption Error>"];
		
	}
	
	//	NSString* shredString = self.missive.shredDate?self.missive.shredDate.whenString:NULL;
	//	if(shredString)
	//	{
	//		cell.textLabel.text = [ cell.textLabel.text stringByAppendingFormat:
	//							   @"\n<Burn: %@ >",shredString];
	//		[cell setBurn: YES];
	//    }
	//
	
	if(self.missive.shredDate)
	{
		[cell setBurn: YES];
	}
	//	[cell setBurn: self.missive.shredDate ? YES : NO];
	
	if(BitTst(self.missive.flags,kMissiveFLag_RequestResend))
	{
		[cell setFailure: YES];
	}
	//	[cell setFailure:BitTst(self.missive.flags,kMissiveFLag_RequestResend) ? YES : NO ];
	
	if(siren.location)
	{
		[cell setHasGeo: YES];
	}
	//	[cell setHasGeo: siren.location ? YES : NO];
	
	
	NSData *thumbnail = siren.thumbnail;
	
	if(thumbnail)
	{
		UIImage*  image = [UIImage imageWithData: thumbnail];
NSLog(@"thumbnail size is %@", NSStringFromCGSize(image.size));
		if(siren.mediaType)
		{
			cell.bubbleView.mediaImage = image;
		}
	}
	
	if(siren.vcard)
	{
		UIImage*  image = siren.thumbnail? [UIImage imageWithData: thumbnail] : [UIImage imageNamed:@"vcard.png"];
		cell.bubbleView.mediaImage = image;
	}
	
	cell.canCopyContents = !siren.fyeo;
	
	cell.textView.font = kBubbleCellFont;
	
	return cell;
	
} // -configureBubbleCell:withSiren:


- (UITableViewCell *) configureCell: (UITableViewCell *) cell {
	if ([cell isKindOfClass: STBubbleTableViewCell.class]) {
		DDGTrace();
		STBubbleTableViewCell *bubbleCell = (STBubbleTableViewCell *)cell;
		//        [cell prepareForReuse];
		Siren *siren = self.missive.siren;
		
		bubbleCell = [self configureBubbleCell: bubbleCell withSiren: siren];
		
		//        bubbleCell.badgeImage = NULL;
		
		bubbleCell.delegate    = self;
		bubbleCell.authorType  = self.authorType;
		
        bubbleCell.imageView.image = (self.authorType == STBubbleTableViewCellAuthorTypeUser)?self.authorImage:self.remoteImage;
     	
		bubbleCell.bubbleImage = (bubbleCell.authorType == STBubbleTableViewCellAuthorTypeUser) ? self.bubble : self.otherBubble;
		
		//       bubbleCell.badgeImage = (siren.shredAfter)?self.clockImage: NULL;
		
		bubbleCell.bubbleImage = siren.isPlainText ? self.plainTextBubble : bubbleCell.bubbleImage;
		
		bubbleCell.selectedBubbleImage = (bubbleCell.authorType == STBubbleTableViewCellAuthorTypeUser) ? self.selectedBubble : self.otherSelectedBubble;
		
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

 

#pragma mark - STBubbleTableViewCellDelegate methods.
- (void) unhideNavBar
{
	[_delegate unhideNavBar];
	
}
- (void) tappedBurn: (STBubbleTableViewCell *) cell
{
	UILabel *burnTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 24)];
	NSString* shredString = self.missive.shredDate?self.missive.shredDate.whenString:NULL;
	burnTimeLabel.text = [NSString stringWithFormat:@" %@: %@ ", NSLocalizedString(@"Burn",@"Burn"), shredString];
	burnTimeLabel.textColor = [UIColor whiteColor];
	burnTimeLabel.textAlignment = UITextAlignmentCenter;
	burnTimeLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
	burnTimeLabel.adjustsFontSizeToFitWidth = YES;
	burnTimeLabel.layer.cornerRadius = 5.0;
	burnTimeLabel.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:0.65];
	burnTimeLabel.center = cell.bubbleView.center;
	CGRect frame = burnTimeLabel.frame;
	burnTimeLabel.frame = CGRectMake(frame.origin.x, cell.burnButton.frame.origin.y - frame.size.height, frame.size.width, frame.size.height);
	[cell.contentView addSubview:burnTimeLabel];
	
	[UIView animateWithDuration:0.25f
					 animations:^{
						 [burnTimeLabel setAlpha:1.0];
					 }
					 completion:^(BOOL finished) {
						 [UIView animateWithDuration:0.5f
											   delay:1.5
											 options:0
										  animations:^{
											  [burnTimeLabel setAlpha:0.0];
											  
										  }
										  completion:^(BOOL finished) {
											  [burnTimeLabel removeFromSuperview];
										  }];
					 }];
	
	
}
- (void) tappedGeo: (STBubbleTableViewCell *) cell
{
	if([_delegate respondsToSelector: @selector(tappedGeo:)]) {
		
		[_delegate tappedGeo: (ChatViewRow*) self];
	}
	
	
}
- (void) tappedFailure: (STBubbleTableViewCell *) cell
{
	if([_delegate respondsToSelector: @selector(tappedFailure:)]) {
		
		[_delegate tappedFailure: (ChatViewRow*) self];
	}
}

- (void) tappedImageOfCell: (STBubbleTableViewCell *) cell
{
	
	if([_delegate respondsToSelector: kTappedCell]) {
		
		[_delegate tappedCell: (ChatViewRow*) self];
	}
	
}
- (void) tappedImageOfAvatar: (STBubbleTableViewCell *) cell
{
	
	if([_delegate respondsToSelector: kTappedAvatar]) {
		
		[_delegate tappedAvatar: (ChatViewRow*) self];
	}
	
}

- (void) tappedResendMenu: (STBubbleTableViewCell *) cell
{
	
	if([_delegate respondsToSelector: kTappedResend]) {
		
		[_delegate tappedResend: (ChatViewRow*) self];
	}
}

- (void) tappedDeleteMenu:(STBubbleTableViewCell *)cell
{
	
	if([_delegate respondsToSelector: kTappedDeleteRow]) {
		
		[_delegate tappedDeleteRow: (ChatViewRow*) self];
	}
}


- (void) tappedForwardMenu: (STBubbleTableViewCell *) cell
{
	
	if([_delegate respondsToSelector: kTappedForwardRow]) {
		
		[_delegate tappedForwardRow: (ChatViewRow*) self];
	}
}

- (void) resignActiveTextEntryField
{
	if([_delegate respondsToSelector: @selector(resignActiveTextEntryField)]) {
		
		[_delegate resignActiveTextEntryField];
	}
}


@end
