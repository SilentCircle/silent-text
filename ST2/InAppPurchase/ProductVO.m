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
//
//  ProductVO.m
//  SilentText
//
//  Created by Ethan Arutunian on 5/27/14
//

#import "ProductVO.h"
#import "NSDictionaryExtras.h"

@implementation ProductVO

- (ProductVO *)initWithDict:(NSDictionary *)dict; {
    // NOTE: this is a sample response from API
    // TODO: Actual response Not Yet Implemented
	self.tag = [dict safeNumberForKey:@"id"];
	self.productID = [dict safeStringForKey:@"ios_product_id"];
	self.iconImageURL = [dict safeStringForKey:@"icon_url"];

	// localized title, localized description, price, etc. will come from Apple SKProduct
	//self.title = [dict safeStringForKey:@"description"];
	//self.description = [dict safeStringForKey:@"description"];
	//self.price = [dict safeNumberForKey:@"price"];
	return self;
}

- (ProductVO *)initWithSKProduct:(SKProduct *)skProductIn tag:(NSNumber *)tag
{
	if ( (self = [super init]) != nil) {
		self.tag = tag;
		[self setSKProduct:skProductIn];
	}
	return self;
}

- (void)setSKProduct:(SKProduct *)skProductIn {
	self.skProduct = skProductIn;
	if (self.productID == nil)
		self.productID = _skProduct.productIdentifier;
	if (![self.productID isEqualToString:_skProduct.productIdentifier])
		NSLog(@"ProductID from iTunes Store (%@) is not what is expected (%@)", _skProduct.productIdentifier, self.productID);
}

- (NSComparisonResult)compareByPrice:(ProductVO *)otherProduct {
	return [self.skProduct.price compare:otherProduct.skProduct.price];
}

- (NSString *)displayPrice
{
	if (self.skProduct.price && self.skProduct.priceLocale)	{
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
		[numberFormatter setLocale:self.skProduct.priceLocale];
		NSString *tmpString = [numberFormatter stringFromNumber:self.skProduct.price];
 		return tmpString;
	} else if (self.skProduct.price)
		return [NSString stringWithFormat:@"%1.2lf", [self.skProduct.price doubleValue]];
	return @"";
}

- (NSString *)displayTitle {
	return ( (_skProduct) && (_skProduct.localizedTitle) ) ? _skProduct.localizedTitle : @"";
}

- (NSString *)displayDescription {
	return ( (_skProduct) && (_skProduct.localizedDescription) ) ? _skProduct.localizedDescription : @"";
}

@end
