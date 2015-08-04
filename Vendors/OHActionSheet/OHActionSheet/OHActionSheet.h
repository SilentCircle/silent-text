//
//  UIActionSheetEx.h
//  AliSoftware
//
//  Created by Olivier on 23/01/11.
//  Copyright 2011 AliSoftware. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * ET 10/16/14
 * This OHActionSheet class originally supported passing a completion block to an instance
 * of UIActionSheet, which eliminated the necessity of having to implement the UIActionSheetDelegate
 * protocol in view controllers to separately handle an actionSheet button press.
 *
 * The current implementation of this class has been repurposed to preserve the original UIActionSheet
 * functionality for iOS 7, and as a wrapper for UIAlertController functionality for iOS 8. This encapsulates
 * os-specific handling, abstracting it from view controllers.
 *
 * ## Usage
 *
 * The showFromVC:inView:title:cancelButtonTitle:destructiveButtonTitle:otherButtonTitles:completion:
 * should be used by a view controller ONLY from within a popover, or on iPhone, to present an actionSheet-style
 * UIAlertController (iOS 8).
 * This method should NOT be used when a view controller is presented in both popover and splitView contexts,
 * such as UserInfoVC and EditUserInfoVC. It should be used where an actionSheet presentation from the
 * bottom of the context view will be the ONLY presentation. Otherwise a crash will result.
 *
 * The showFromRect:sourceVC:inView:arrowDirection:title:cancelButtonTitle:destructiveButtonTitle:otherButtonTitles:completion:
 * may be used when presenting an actionSheet from within a popover, and when presenting an actionSheet in a popover
 * pointing to a button or view rect. The "arrowDirection:" parameter may be passed 0, which presents an actionSheet
 * from the bottom of the view, just as calling the previous method; passing any other UIPopoverArrowDirection will
 * present an action sheet in a popover.
 *
 * The original initWithTitle:cancelButtonTitle:destructiveButtonTitle:otherButtonTitles:completion: initializer
 * is invoked in all cases by the new public constructor/presentation methods; the use of an instance returned by 
 * this initializer for general use outside the new public methods is not supported for iOS 7/8 combined functionality.
 * Use at your own risk.
**/
@interface OHActionSheet : UIActionSheet

typedef void (^OHActionSheetButtonHandler)(OHActionSheet* sheet,NSInteger buttonIndex);
@property (nonatomic, copy) OHActionSheetButtonHandler buttonHandler;

#pragma mark Instance Initializer

- (instancetype)initWithTitle:(NSString*)title
            cancelButtonTitle:(NSString *)cancelButtonTitle
       destructiveButtonTitle:(NSString *)destructiveButtonTitle
            otherButtonTitles:(NSArray *)otherButtonTitles
                   completion:(OHActionSheetButtonHandler)completionBlock;


#pragma mark - New Public Class Constructors (iOS 7/8)

// Note that this class method presents an OHActionSheet instance for iOS 7
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
          completion:(OHActionSheetButtonHandler)completionBlock;

+ (void)showFromVC:(UIViewController *)vc
            inView:(UIView*)view
             title:(NSString*)title
 cancelButtonTitle:(NSString *)cancelButtonTitle
destructiveButtonTitle:(NSString *)destructiveButtonTitle
 otherButtonTitles:(NSArray *)otherButtonTitles
        completion:(OHActionSheetButtonHandler)completionBlock;

#pragma mark DEPRECATED Public Class Constructors
/*
+(void)showSheetFromRect:(CGRect)rect
                  inView:(UIView*)view
                   title:(NSString*)title
       cancelButtonTitle:(NSString *)cancelButtonTitle
  destructiveButtonTitle:(NSString *)destructiveButtonTitle
       otherButtonTitles:(NSArray *)otherButtonTitles
              completion:(OHActionSheetButtonHandler)completionBlock;

+(void)showSheetInView:(UIView*)view
				 title:(NSString*)title
	 cancelButtonTitle:(NSString *)cancelButtonTitle
destructiveButtonTitle:(NSString *)destructiveButtonTitle
	 otherButtonTitles:(NSArray *)otherButtonTitles
			completion:(OHActionSheetButtonHandler)completionBlock;
*/
/////////////////////////////////////////////////////////////////////////////

-(void)showInView:(UIView*)view;

/** ET 09/08/14: DEPRECATE to simplify iOS8 Workaround category - this method was not called anywhere in the app.
 * Show the ActionSheet that will dismiss after timeoutInSeconds seconds, by simulating a tap on the timeoutButtonIndex button after this delay.
 *
 * This method uses the @"(Dismissed in %lus)" timeout message format by default.
 *
-(void)showInView:(UIView*)view withTimeout:(unsigned long)timeoutInSeconds timeoutButtonIndex:(NSInteger)timeoutButtonIndex;
*/

/** ET 09/08/14: DEPRECATE to simplify iOS8 Workaround category - this method was not called anywhere in the app.
 * Show the ActionSheet that will dismiss after timeoutInSeconds seconds, by simulating a tap on the timeoutButtonIndex button after this delay.
 *
 * The countDownMessageFormat is a string containing a %lu placeholder to customize the countdown message displayed in the ActionSheet.
 * If countDownMessageFormat is nil, no countdown message is added to the sheet title.
 *
-(void)showInView:(UIView*)view withTimeout:(unsigned long)timeoutInSeconds
timeoutButtonIndex:(NSInteger)timeoutButtonIndex timeoutMessageFormat:(NSString*)countDownMessageFormat;
*/
 
@end
