//
//  UIActionSheetEx.m
//  AliSoftware
//
//  Created by Olivier on 23/01/11.
//  Copyright 2011 AliSoftware. All rights reserved.
//

#import "OHActionSheet.h"
#import "AppConstants.h"
#import "NSString+SCUtilities.h"


@interface OHActionSheet () <UIActionSheetDelegate> @end


@implementation OHActionSheet
//@synthesize buttonHandler = _buttonHandler; // ET declared in .h


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Initializer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ET 10/16/14
// NOTE: this original initializer is invoked in all cases by the new public constructor/presentation methods;
// the use of an instance returned by this initializer for general use outside the new public methods is not 
// supported for iOS 7/8 combined functionality.
// Use at your own risk.
- (instancetype)initWithTitle:(NSString*)title
            cancelButtonTitle:(NSString *)cancelButtonTitle
       destructiveButtonTitle:(NSString *)destructiveButtonTitle
            otherButtonTitles:(NSArray *)otherButtonTitles
                   completion:(OHActionSheetButtonHandler)completionBlock;
{
    // Note: need to send at least the first button because if the otherButtonTitles parameter is nil, 
    // self.firstOtherButtonIndex will be -1
    NSString *firstOther = nil;
    if (otherButtonTitles && otherButtonTitles.count > 0) 
        firstOther = otherButtonTitles[0];
    
    self = [super initWithTitle:title 
                       delegate:self
              cancelButtonTitle:nil
         destructiveButtonTitle:destructiveButtonTitle
              otherButtonTitles:firstOther, nil];
    
    if (self != nil) {
        for(NSInteger idx = 1; idx < otherButtonTitles.count; ++idx) {
            [self addButtonWithTitle: [otherButtonTitles objectAtIndex:idx] ];
        }
        
        // added this because sometimes an actionSheet was being created with an empty cancel button
        if (cancelButtonTitle) {
            [self addButtonWithTitle:cancelButtonTitle];
            self.cancelButtonIndex = self.numberOfButtons - 1;
        }
        
        self.buttonHandler = completionBlock;
    }
    
    return self;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - New Public Methods (iOS 8)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// This class method presents an OHActionSheet instance for iOS 7
// and a UIAlertController instance for iOS 8
// On iOS 8 iPad, an actionSheet-style alertController may be presented in
// a popover if arrowDirection is greater than 0, 
// and is otherwise presented as an actionSheet.
+ (void)showFromRect:(CGRect)rect
            sourceVC:(UIViewController *)vc
              inView:(UIView*)view
      arrowDirection:(UIPopoverArrowDirection)arrowDirection
               title:(NSString*)title   
   cancelButtonTitle:(NSString *)cancelButtonTitle
destructiveButtonTitle:(NSString *)destructiveButtonTitle
   otherButtonTitles:(NSArray *)otherButtonTitles
          completion:(OHActionSheetButtonHandler)completionBlock
{

    OHActionSheet *sheet = [[self alloc] initWithTitle:title
                                     cancelButtonTitle:cancelButtonTitle
                                destructiveButtonTitle:destructiveButtonTitle
                                     otherButtonTitles:otherButtonTitles
                                            completion:completionBlock];

    if (AppConstants.isIOS8OrLater)
    {
        UIAlertController *ac = [self alertControllerFromActionSheet:sheet];

        // All invocations of this method must pass a UIPopoverArrowDirection argument.
        // If passed 0, the actionSheet-style alertController will be presented as is.
        //
        // In a number of cases, view controllers presenting actionSheets from
        // within a popover in some app contexts must present the actionSheets as
        // popovers in other contexts, e.g. UserInfoVC and EditInfoVC are themselves
        // within popovers in the Conversation context but not so in the Contacts context.
        // Similarly with CreateAccount and Login VCs.
        // In those cases this method is called with arrowDirection = 0 for actionSheet
        // and a popoverArrowDirection otherwise.
        if (arrowDirection > 0)
        {            
            ac.modalPresentationStyle = UIModalPresentationPopover;
            UIPopoverPresentationController *ppc = ac.popoverPresentationController;
            ppc.permittedArrowDirections = arrowDirection;
            ppc.sourceView = view;
            ppc.sourceRect = rect;
        }
        [vc presentViewController:ac animated:YES completion:nil];
    }
    else
    {
        // This fixes the non-functioning Cancel button for iPhone actionSheet, 
        // logged by the system with this error:
        //
        // "Presenting action sheet clipped by its superview. Some controls might not respond to touches. 
        // On iPhone try -[UIActionSheet showFromTabBar:] or -[UIActionSheet showFromToolbar:] 
        // instead of -[UIActionSheet showInView:]."
        if (AppConstants.isIPhone) 
        {            
            view = [UIApplication sharedApplication].keyWindow;
        }
        
        [sheet showFromRect:rect inView:view animated:YES];
    }
}

// This class method presents an OHActionSheet instance for iOS 7
// and a UIAlertController instance for iOS 8.
// Note that on iOS 8 iPad, an actionSheet-style alertController presented by a
// view controller not in a popover will crash. 
// Use the above method to present an actionSheet in a popover.
+ (void)showFromVC:(UIViewController *)vc
            inView:(UIView*)view
             title:(NSString*)title
 cancelButtonTitle:(NSString *)cancelButtonTitle
destructiveButtonTitle:(NSString *)destructiveButtonTitle
 otherButtonTitles:(NSArray *)otherButtonTitles
        completion:(OHActionSheetButtonHandler)completionBlock
{

    OHActionSheet *sheet = [[self alloc] initWithTitle:title
                                     cancelButtonTitle:cancelButtonTitle
                                destructiveButtonTitle:destructiveButtonTitle
                                     otherButtonTitles:otherButtonTitles
                                            completion:completionBlock];

    if (AppConstants.isIOS8OrLater)
    {
        UIAlertController *ac = [self alertControllerFromActionSheet:sheet];
        [vc presentViewController:ac animated:YES completion:nil];
    }
    else
    {
        [sheet showInView:view];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - iOS 8 Workaround Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// iOS 8 ONLY
// Returns a UIAlertController, given an OHActionSheet instance.
+ (UIAlertController *)alertControllerFromActionSheet:(OHActionSheet *)aSheet
{    
    UIAlertController *alertCon = [UIAlertController alertControllerWithTitle:nil 
                                                                      message:aSheet.title 
                                                               preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSInteger nactions = [aSheet numberOfButtons];
    int i = 0;
    while (i < nactions)
    {
        NSString *button_title = [aSheet buttonTitleAtIndex:i];
        UIAlertActionStyle style = UIAlertActionStyleDefault;
        if (i == [aSheet cancelButtonIndex])
        {
            style = UIAlertActionStyleCancel; //UIAlertActionStyleDefault;
        }
        else if ( i == [aSheet destructiveButtonIndex])
        {
            style = UIAlertActionStyleDestructive;
        }
        
        UIAlertAction *newAction = [UIAlertAction actionWithTitle:button_title 
                                                            style:style 
                                                          handler:^(UIAlertAction *action) {
                                                              
                                                              [aSheet.delegate actionSheet:aSheet 
                                                                 didDismissWithButtonIndex:i];
                                                          }];
        
        [alertCon addAction:newAction];
        i++;
    }
    
    return alertCon;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - DEPRECATED Public Constructors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//+(void)showSheetInView:(UIView*)view
//                 title:(NSString*)title
//     cancelButtonTitle:(NSString *)cancelButtonTitle
//destructiveButtonTitle:(NSString *)destructiveButtonTitle
//     otherButtonTitles:(NSArray *)otherButtonTitles
//            completion:(OHActionSheetButtonHandler)completionBlock
//{
//    OHActionSheet* sheet = [[self alloc] initWithTitle:title
//                                     cancelButtonTitle:cancelButtonTitle
//                                destructiveButtonTitle:destructiveButtonTitle
//                                     otherButtonTitles:otherButtonTitles
//                                            completion:completionBlock];
//    
//    [sheet showInView:view];
//    
//#if ! __has_feature(objc_arc)
//    [sheet autorelease];
//#endif
//    
//}
//
//+(void)showSheetFromRect:(CGRect)rect
//                  inView:(UIView*)view
//                   title:(NSString*)title
//       cancelButtonTitle:(NSString *)cancelButtonTitle
//  destructiveButtonTitle:(NSString *)destructiveButtonTitle
//       otherButtonTitles:(NSArray *)otherButtonTitles
//              completion:(OHActionSheetButtonHandler)completionBlock
//{
//    OHActionSheet* sheet = [[self alloc] initWithTitle:title
//                                     cancelButtonTitle:cancelButtonTitle
//                                destructiveButtonTitle:destructiveButtonTitle
//                                     otherButtonTitles:otherButtonTitles
//                                            completion:completionBlock];
//        
//    [sheet showFromRect:rect inView:view animated:YES];
//    
//#if ! __has_feature(objc_arc)
//    [sheet autorelease];
//#endif
//    
//}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//// DEPRECATE: Pass zeroRect to present from bottom of view in popover
//// NOTE: iOS 8 ONLY
//+ (void) showSheet:(UIAlertController *)ac withVC:(UIViewController *)vc inView:(UIView *)inView fromRect:(CGRect)rect
//{
////    if (AppConstants.isIPad)
////    {
////        UIPopoverArrowDirection arrowDirections =  UIPopoverArrowDirectionAny;
////        
////        // if no rect, then put in proportial to the view
////        if (CGRectEqualToRect(rect, CGRectZero))
////        {
////            // ET 10/15/14 DEPRECATE effort to position at screen bottom
//////            CGSize viewSize = inView.frame.size;
//////            CGFloat sheetH = [self heightForSheet:ac];
//////            NSLog(@"\n\tsheetH:%1.2f alertCon.view:%@", sheetH, ac.view);
//////            //
//////            CGFloat sheetY = CGRectGetHeight(inView.frame) - (sheetH / 2);
//////            rect = CGRectMake(viewSize.width / 2 - 1, sheetY, 2, 1);
////            
////            // no arrows
////            arrowDirections =  0;
////         }
////        
////        UIPopoverController*  popoverController = [[UIPopoverController alloc] initWithContentViewController:ac];
////            
////        [popoverController presentPopoverFromRect:rect
////                                           inView:inView
////                         permittedArrowDirections:arrowDirections
////                                         animated:YES];
////    }
////    else  // for iphone
//       [vc presentViewController:ac animated:YES completion:nil];
//}
//
//
//// These calculations are from farting around with the different presentations in current iOS 8 popovers,
//// rather than an understanding of how the damn thing is sized by the system.
//+ (CGFloat)heightForSheet:(UIAlertController *)ac
//{
//    CGFloat btnH = 28.0f;
//    NSUInteger btnCount = ac.actions.count;
//    CGFloat f = btnH * btnCount;
//  
//    if ([ac.message isNotEmpty]) {
//        // Add height for message top height
//        f += 60; //44;
//        // Add height for addtional message lines
//        NSUInteger lines = [self linesInString:ac.message];
//        if (lines > 1)
//            f += (lines - 1) * 8;
//    }
//    
//    return f;
//}
//
//// something like 44 char lines is the string width in 320 popover view width
//+ (NSUInteger)linesInString:(NSString *)str
//{
//    return ceil(str.length / 44); 
//}
//
//// should only be used when looking for a cancel button in an iOS 8 popover presentation
//+ (BOOL)alertConHasCancelAction:(UIAlertController *)ac
//{
//    for (UIAlertAction *action in ac.actions)
//    {
//        if (action.style == UIAlertActionStyleCancel) {
//            return YES;
//        }
//    }
//    return NO;
//}


#pragma mark - UIActionSheetDelegate
-(void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (self.buttonHandler) {
        self.buttonHandler(self,buttonIndex);
    }
}



/////////////////////////////////////////////////////////////////////////////
#pragma mark - Public Methods

-(void)showInView:(UIView *)view
{
    if ([view isKindOfClass:[UITabBar class]]) {
        [self showFromTabBar:(UITabBar*)view];
    } else if ([view isKindOfClass:[UIToolbar class]]) {
        [self showFromToolbar:(UIToolbar*)view];
    } else {
        [super showInView:view];
    }
}

/* ET 09/08/14: DEPRECATE to simplify iOS8 Workaround category - these methods were not called anywhere in the app.
 *
-(void)showInView:(UIView*)view withTimeout:(unsigned long)timeoutInSeconds timeoutButtonIndex:(NSInteger)timeoutButtonIndex
{
    [self showInView:view withTimeout:timeoutInSeconds timeoutButtonIndex:timeoutButtonIndex timeoutMessageFormat:@"(Dismissed in %lus)"];
}

-(void)showInView:(UIView*)view withTimeout:(unsigned long)timeoutInSeconds
timeoutButtonIndex:(NSInteger)timeoutButtonIndex timeoutMessageFormat:(NSString*)countDownMessageFormat
{
    __block dispatch_source_t timer = nil;
    __block unsigned long countDown = timeoutInSeconds;
    
    // Add some timer sugar to the completion handler
    OHActionSheetButtonHandler finalHandler = [self.buttonHandler copy];
    self.buttonHandler = ^(OHActionSheet* bhSheet, NSInteger bhButtonIndex)
    {
        // Cancel and release timer
        dispatch_source_cancel(timer);
#if ! __has_feature(objc_arc)
        dispatch_release(timer);
#endif
        timer = nil;
        
        // Execute final handler
        finalHandler(bhSheet, bhButtonIndex);
    };
#if ! __has_feature(objc_arc)
    [finalHandler release];
#endif
    
    NSString* baseMessage = self.title;
    dispatch_block_t updateMessage = countDownMessageFormat ? ^{
        self.title = [NSString stringWithFormat:@"%@\n\n%@", baseMessage, [NSString stringWithFormat:countDownMessageFormat, countDown]];
    } : ^{ // NOOP };
    updateMessage();
    
    // Schedule timer every second to update message. When timer reach zero, dismiss the alert
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC), 1*NSEC_PER_SEC, 0.1*NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        --countDown;
        updateMessage();
        if (countDown <= 0)
        {
            [self dismissWithClickedButtonIndex:timeoutButtonIndex animated:YES];
        }
    });
    
    // Show the alert and start the timer now
    [self showInView:view];
    
    dispatch_resume(timer);
}
*/

/////////////////////////////////////////////////////////////////////////////
#pragma mark - Memory Mgmt


#if ! __has_feature(objc_arc)
- (void)dealloc {
    [_buttonHandler release];
    [super dealloc];
}
#endif

@end
