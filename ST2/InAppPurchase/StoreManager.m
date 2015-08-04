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
//  StoreManager.h
//  SilentText
//
//  Created by Ethan Arutunian on 5/27/14
//

 
#import "StoreManager.h"
#import "SCWebAPIManager.h"
#import "AppConstants.h"
#import "EmbeddedIAPProduct.h"
#import "STLogging.h"
#import "AppDelegate.h"
#import "STUserManager.h"
#import "STLocalUser.h"

// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
static const int ddLogLevel = LOG_LEVEL_INFO; // VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

NSString *const kStoreManager_ProductsLoadedNotification        =  @"kStoreManager_ProductsLoadedNotification";
NSString *const kStoreManager_TransactionCompleteNotification    = @"kStoreManager_TransactionCompleteNotification";


@interface StoreObserver : NSObject <SKPaymentTransactionObserver>

- (void)completeTransaction:(SKPaymentTransaction *)transaction;
- (void)failedTransaction:(SKPaymentTransaction *)transaction;
- (void)restoreTransaction:(SKPaymentTransaction *)transaction;

@end


@implementation StoreObserver


- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
			case SKPaymentTransactionStatePurchasing:
				DDLogVerbose(@"Adding payment to purchasing queue.");
				break;
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
			{
                //				if (transaction.error.code != SKErrorPaymentCancelled)
                //				{
                //					NSString *errorMsg = [transaction.error localizedFailureReason];
                //					if (!errorMsg)
                //						errorMsg = [[transaction error] localizedDescription];
                //				}
                [self failedTransaction:transaction];
                break;
			}
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions
{
}

- (void)completeTransaction:(SKPaymentTransaction *)paymentTransaction
{
    // Once you’ve provided the product, your application must call 'finishTransaction:' to complete the operation.
	// When you call 'finishTransaction:', the transaction is removed from the queue.
	// Your application must ensure that content is provided (or that you’ve recorded the details of the transaction)
 	// before calling 'finishTransaction:'.
	
	// At this point the purchase is successful and Apple has charged the end user.
	// Send off to SC server.
    
   	// lookup the user from payment on the transaction	
	NSString *appStoreHash = paymentTransaction.payment.applicationUsername;
	
	__block STLocalUser *localUser = nil;
	[STDatabaseManager.roDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		localUser = [[DatabaseManager sharedInstance] findUserWithAppStoreHash:appStoreHash transaction:transaction];
		
	} completionBlock:^{
		
		if (!localUser)
		{
			// If the user doesnt exist, just remove the payment, something went really wrong.
			[[SKPaymentQueue defaultQueue] finishTransaction:paymentTransaction];
		}
		else
		{
			// payment complete, Tell Silent Circle you paid for it.
			
			NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
			NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
			NSString *receipt64S = [receipt base64EncodedStringWithOptions:0];
             
			[[STUserManager sharedInstance] recordPaymentWithReceipt:receipt64S
			                                            forLocalUser:localUser
			                                         completionBlock:^ (NSError *error, NSString *uuid)
			{
				NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:3];
				
				[dict setObject:paymentTransaction forKey:@"paymentTransaction"]; // why is this string hard-coded ?
				[dict setObject:localUser.uuid forKey:@"userId"];                 // why is this string hard-coded ?
				
				if (error) {
					[dict setObject:error forKey:@"error"];
				}
				
				// remove these or they will keep on showing up forever
				[[SKPaymentQueue defaultQueue] finishTransaction:paymentTransaction];
				
				[[NSNotificationCenter defaultCenter] postNotificationName:kStoreManager_TransactionCompleteNotification
				                                                    object:dict];
			}];
		}
		
     }];
}

- (void) failedTransaction: (SKPaymentTransaction *)paymentTransaction
{
  
    __block STUser *user = NULL;
    NSString *hashedUserName = paymentTransaction.payment.applicationUsername;
    
     [STDatabaseManager.roDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction)
     {
         user = [[DatabaseManager sharedInstance] findUserWithAppStoreHash:hashedUserName transaction:transaction];
         
     }completionBlock:^{
         
         if(user)
         {
             
             NSDictionary *dict =  @{   @"paymentTransaction":  paymentTransaction,
                                        @"error":               paymentTransaction.error,
                                        @"userId":              user.uuid};
             
             
             
             [[NSNotificationCenter defaultCenter] postNotificationName: kStoreManager_TransactionCompleteNotification
                                                                 object: dict];
          
         }
         // remove these or they will keep on showing up forever
         [[SKPaymentQueue defaultQueue] finishTransaction: paymentTransaction];
         

     }];
    
 }

- (void) restoreTransaction: (SKPaymentTransaction *)transaction
{
	// do we need to do anything here?
}

@end;


#define STORE_FAILURE_RETRY_INTERVAL		3

@interface StoreManager(Private)
- (NSDictionary *)allProductsMap;
- (void)_requestSKProductList;
- (void)_retryLoadProducts:(NSTimer *)t;
@end


@implementation StoreManager
{
    StoreObserver *storeObserver;
    
}

static StoreManager *sharedInstance;


+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		sharedInstance = [[StoreManager alloc] init];
        [sharedInstance commonInit];
  	}
}

+ (StoreManager *)sharedInstance
{
	return sharedInstance;
}


-(void)commonInit
{
    
    // Apple recommends adding the Store Observer on App launch
	// store observer watches for any queued transactions to finish
	storeObserver = [[StoreObserver alloc] init];
	[[SKPaymentQueue defaultQueue] addTransactionObserver:storeObserver];

}



#pragma mark - Purchasing

- (void)startPurchaseProductID:(NSString *)productID
                  forLocalUser:(STLocalUser *)localUser
               completionBlock:(StoreManagerCompletionBlock)completion
{
	NSAssert((localUser && localUser.isLocal), @"STLocalUser must be valid");
    
    ProductVO *prodVO = [_allProductsMap objectForKey:productID];
	if (!prodVO)
    {
        if(completion)
			(completion)([STAppDelegate otherError: NSLocalizedString( @"No matching product found.",  @"No matching product found.")], NULL);
        return;
     }
    
 	SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:prodVO.skProduct];
  	 
    // see Apple Notes "Detecting Irregular Activity" to add hashed version of username or user id
    payment.applicationUsername = localUser.appStoreHash;
    
    // start payment process: add the payment to iOS's payment queue
	[[SKPaymentQueue defaultQueue] addPayment:payment];
    
	if (completion)
		(completion)(nil, nil);
}



- (void)recordPaymentTransaction:(SKPaymentTransaction *)transaction
                         forUser:(STUser *)user
                 completionBlock:(StoreManagerCompletionBlock)completion
{
	// payment complement, send the receipt down to the server
    
	NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
	NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
//	NSString *receipt64S = [receipt base64Encoded];
    NSString *receipt64S = [receipt base64EncodedStringWithOptions:0];
    
	[[SCWebAPIManager sharedInstance] recordPaymentReceipt:receipt64S
                                                   forUser:user
                                           completionBlock:^(NSError *error, NSDictionary *infoDict)
    {
                   if(completion)
                       (completion)(error, infoDict);
	}];
    
}

#pragma mark - All Products
- (NSArray *)allActiveProducts
{
	NSMutableArray *resultList = [NSMutableArray arrayWithCapacity:[_allProductsMap count]];
	for (ProductVO *prodVO in [_allProductsMap allValues]) {
		if (prodVO.skProduct != nil)
			[resultList addObject:prodVO];
	}
	return resultList;
}

- (NSArray *)allActiveProductsSortedByPrice
{
	return [[self allActiveProducts] sortedArrayUsingSelector:@selector(compareByPrice:)];
}

- (ProductVO *)productWithTag:(NSNumber *)tag {
	for (ProductVO *prodVO in [_allProductsMap allValues]) {
		if ([prodVO.tag isEqualToNumber:tag])
			return prodVO;
	}
	return nil;
}

-(void)loadAllProducts
{
#if !LOAD_IAP_PRODUCTS_FROM_SERVER
    // products are embedded in the App
	_allProductsMap = [[NSMutableDictionary alloc] initWithCapacity:10];
	EmbeddedProductResponse *mockResponse = [EmbeddedProductResponse responseWithDefaultProductList];
	for (EmbeddedIAPProduct *product in mockResponse.products) {
		[_allProductsMap setObject:[product toProductVO] forKey:product.productIdentifier];
	}
    
	// now load Store Kit products active on iTunes
	[self _requestSKProductList];
#else
    // NOT IMPLEMENTED
	// load products via SC Web API
    // the following is SAMPLE code (not tested)
	[[SCWebAPIManager sharedInstance] loadAllProductsWithCompletionBlock:^(NSError *error, NSDictionary *infoDict) {
		if (![infoDict isKindOfClass:[NSArray class]])
			return;
		
		NSArray *productListIn = (NSArray *)infoDict;
		
		_allProductsMap = [[NSMutableDictionary alloc] initWithCapacity:[productListIn count]];
		DDLogVerbose(@"-- StoreManager: Products Received");
		for (ProductVO *productVO in productListIn)
			[_allProductsMap setObject:productVO forKey:productVO.productID];
        
		// now load Store Kit products active on iTunes
		[self _requestSKProductList];
	}];
#endif
}

- (void)_requestSKProductList
{
    NSSet *productList = [NSSet setWithArray:[_allProductsMap allKeys]];
    if (_newProductList)
        productList = [productList setByAddingObjectsFromSet:_newProductList];
    
#if !TARGET_IPHONE_SIMULATOR
	_productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productList];
	_productRequest.delegate = self;
	[_productRequest start];
#else
	[self productsRequest:nil didReceiveResponse:[EmbeddedProductResponse responseWithDefaultProductList]];
#endif
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	//[UIApplication sharedApplication].networkActivityIndicatorVisible = false;

	_productRequest = nil;
	
    NSArray *allProducts = response.products;
	if (allProducts == nil)
	{
		DDLogVerbose(@"No products were found at iTunes Store!");
	}

	NSMutableDictionary *finalProductsMap = [[NSMutableDictionary alloc] initWithCapacity:[allProducts count]];
	
	BOOL gotProducts = NO;
	for (SKProduct *skProduct in allProducts) {
		// here's how you format the price:
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
		[numberFormatter setLocale:skProduct.priceLocale];
		NSString *formattedPrice = [numberFormatter stringFromNumber:skProduct.price];
		DDLogVerbose(@"\nProduct title: %@\n\tdescription: %@\n\tprice: %@ (%@)\n\tproduct ID: %@\n", skProduct.localizedTitle, skProduct.localizedDescription, formattedPrice, [skProduct.priceLocale localeIdentifier], skProduct.productIdentifier);

		gotProducts = YES;
		
		ProductVO *existingProduct = [_allProductsMap valueForKey:skProduct.productIdentifier];
		if (existingProduct == nil) {// || [existingProduct wasModifiedOnServer]) {
			// this was not a product returned
			DDLogVerbose(@"AppStore provided product that we do not recognize (skipping): %@", skProduct.productIdentifier);
			continue;
		}
		else
			[existingProduct setSKProduct:skProduct];
		[finalProductsMap setObject:existingProduct forKey:skProduct.productIdentifier];
	}
	
	if (!gotProducts)
		DDLogVerbose(@"AppStore did not return any products!");

	_allProductsMap = finalProductsMap;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kStoreManager_ProductsLoadedNotification object:self];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
	//[UIApplication sharedApplication].networkActivityIndicatorVisible = false;

	if (request == _productRequest)
	{
		_productRequest = nil;
	}

	DDLogVerbose(@"SKRequest failed: %@ - retry in %d seconds", error, STORE_FAILURE_RETRY_INTERVAL);
#if !TARGET_IPHONE_SIMULATOR
	// try again
	[NSTimer scheduledTimerWithTimeInterval:STORE_FAILURE_RETRY_INTERVAL
									target:self 
									selector:@selector(_retryLoadProducts:)
									userInfo:nil
									repeats:NO];
#endif
}

- (void)requestDidFinish:(SKRequest *)request
{
	//[UIApplication sharedApplication].networkActivityIndicatorVisible = false;
	DDLogVerbose(@"Request finished.");
}

- (void)_retryLoadProducts:(NSTimer *)t
{
	[self _requestSKProductList];
}


@end
