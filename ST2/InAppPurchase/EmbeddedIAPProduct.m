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
//  EmbeddedIAPProduct.m
//  SilentText
//
//  Created by Ethan Arutunian on 5/27/14
//

#import "EmbeddedIAPProduct.h"

@implementation EmbeddedProductResponse
@synthesize products;

+ (EmbeddedProductResponse *)responseWithDefaultProductList {
	EmbeddedIAPProduct *p1 = [EmbeddedIAPProduct productWithID:@"SC_SUBSCRIBE_1_MON" tag:@0 title:@"1 Month" description:@"" price:[NSDecimalNumber decimalNumberWithString:@"9.99"]];
    // Example: how to add a second product:
    // EmbeddedIAPProduct *p2 = [EmbeddedIAPProduct productWithID:@"SC_SUBSCRIBE_12_MO" tag:@1 title:@"1 Year" description:@"" price:[NSDecimalNumber decimalNumberWithString:@"99.99"]];
    // NSArray *productList = [NSArray arrayWithObjects:p1, p2, nil];
	NSArray *productList = [NSArray arrayWithObject:p1];
    
	EmbeddedProductResponse *resp = [[EmbeddedProductResponse alloc] init];
	resp.products = productList;
	return resp;
}

@end

@implementation EmbeddedIAPProduct
@synthesize localizedTitle;
@synthesize localizedDescription;
@synthesize price;
@synthesize priceLocale;
@synthesize productIdentifier;
@synthesize tag;

+ (EmbeddedIAPProduct *)productWithID:(NSString *)productID tag:(NSNumber *)tag title:(NSString *)title description:(NSString *)description price:(NSDecimalNumber *)price {
	EmbeddedIAPProduct *prod = [[EmbeddedIAPProduct alloc] init];
	prod.productIdentifier = productID;
	prod.localizedTitle = title;
	prod.localizedDescription = description;
	prod.price = price;
	prod.priceLocale = [NSLocale currentLocale];
	prod.tag = tag;
	return prod; // [prod autorelease];
}

- (ProductVO *)toProductVO {
	ProductVO *productVO = [[ProductVO alloc] initWithSKProduct:(SKProduct *)self tag:self.tag]; // fake it
	return productVO;
}

@end
