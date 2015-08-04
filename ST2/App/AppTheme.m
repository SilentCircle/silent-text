/*
Copyright (C) 2013-2015, Silent Circle, LLC. All rights reserved.

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
#import "STPreferences.h"

#import "AppTheme.h"
#import "AppDelegate.h"
#import "DatabaseManager.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "UIImage+ImageEffects.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_WARN;

static NSMutableDictionary *appThemeDictionary;
static NSArray *keys;
static NSString *selectedName;

@implementation AppTheme


+ (void)initialize
{
	appThemeDictionary = [NSMutableDictionary dictionaryWithCapacity:10];
	
	if (YES)
	{
		NSString *localizedName = NSLocalizedString(@"Blue", @"Blue");
		NSString *themeKeyID = @"0";
		
		UIColor *selfColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0]; // blue
 		UIColor *otherColor = [UIColor colorWithWhite:0.0 alpha:1.0]; // black
		
		appThemeDictionary[themeKeyID] =
		
			[[AppTheme alloc] initWithBackground: nil
			                plainBackgroundColor: [UIColor colorWithRed:0.941 green:0.944 blue:0.949 alpha:1.000]
			                     selfBubbleColor: [selfColor colorWithAlphaComponent:0.7]
			                       selfTextColor: [UIColor whiteColor]
			              selfLinkTextAttributes: @{ NSForegroundColorAttributeName: [UIColor blueColor],
				                                     NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
			                                       }
			               selfBubbleBorderColor: selfColor
			               selfAvatarBorderColor: selfColor
			                    otherBubbleColor: [otherColor colorWithAlphaComponent:0.1]
			                otherBubbleTextColor: otherColor
			             otherLinkTextAttributes: @{ NSForegroundColorAttributeName: [UIColor blueColor],
			                                         NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
			                                       }
			              otherBubbleBorderColor: [otherColor colorWithAlphaComponent:0.1]
			              otherAvatarBorderColor: otherColor
			          bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
			                 backgroundTextColor: [UIColor purpleColor]
			               messageLabelTextColor: [UIColor darkGrayColor]
			                 messageLabelBGColor: [[UIColor blackColor] colorWithAlphaComponent:0.05]
			               conversationBodyColor: [UIColor blackColor]
			             conversationHeaderColor: selfColor
			                  messageHeaderColor: [UIColor colorWithWhite:0.0 alpha:1.0]
			                       navBarIsBlack: NO
			                 navBarIsTranslucent: NO
			                         navBarColor: [UIColor colorWithRed:0.912 green:0.924 blue:0.949 alpha:1.000]
			                    navBarTitleColor: selfColor
			                        appTintColor: selfColor
			                   chatOptionsIsDark: NO
			                scrollerColorIsWhite: NO
			                               keyID: themeKeyID
			                       localizedName: localizedName];
	}
	
	if (YES)
	{
		NSString *localizedName = NSLocalizedString(@"Orange", @"Orange");
		NSString *themeKeyID = @"1";
		
		UIColor *selfColor = [UIColor colorWithRed:1.0 green:0.5 blue:0.0 alpha:1.0]; // orange
		UIColor *otherColor = [UIColor colorWithWhite:0.0 alpha:1.0]; // black
		
		appThemeDictionary[themeKeyID] =
		
			[[AppTheme alloc] initWithBackground: nil
			                plainBackgroundColor: [UIColor colorWithRed:0.98 green:0.94 blue:0.91 alpha:1.0]
			                     selfBubbleColor: [selfColor colorWithAlphaComponent:0.08]
			                       selfTextColor: selfColor
			              selfLinkTextAttributes: @{ NSForegroundColorAttributeName: [UIColor blueColor],
			                                         NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
			                                       }
			               selfBubbleBorderColor: selfColor
			               selfAvatarBorderColor: selfColor
			                    otherBubbleColor: [otherColor colorWithAlphaComponent:0.1]
			                otherBubbleTextColor: otherColor
			             otherLinkTextAttributes: @{ NSForegroundColorAttributeName: [UIColor blueColor],
			                                         NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
			                                       }
			              otherBubbleBorderColor: otherColor
			              otherAvatarBorderColor: otherColor
			          bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
			                 backgroundTextColor: [UIColor purpleColor]  // what does this affect?
			               messageLabelTextColor: [UIColor darkGrayColor]
			                 messageLabelBGColor: [[UIColor blackColor] colorWithAlphaComponent:0.05]
			               conversationBodyColor: [UIColor blackColor]
			             conversationHeaderColor: selfColor
			                  messageHeaderColor: [UIColor colorWithWhite:0.0 alpha:1.0]
			                       navBarIsBlack: NO
			                 navBarIsTranslucent: YES
			                         navBarColor: selfColor
			                    navBarTitleColor: [UIColor blackColor]
			                        appTintColor: selfColor
			                   chatOptionsIsDark: NO
			                scrollerColorIsWhite: NO
			                               keyID: themeKeyID
			                       localizedName: localizedName];
	}

    
	UIColor *selfColor = [UIColor colorWithRed:1.0 green:0.78 blue:0.18 alpha:1.0]; // yellow
	UIColor *otherColor = [UIColor colorWithRed:1.0 green:0.78 blue:0.18 alpha:1.0]; // yellow
    NSInteger themeIDNumber = 3;
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: nil
												 plainBackgroundColor: [UIColor colorWithRed:0.07 green:0.05 blue:0.0 alpha:1.0]
													  selfBubbleColor: [selfColor colorWithAlphaComponent:0.03]
														selfTextColor: selfColor
                                               selfLinkTextAttributes:  @{NSForegroundColorAttributeName:[UIColor colorWithRed:0.96 green:0.93 blue:0.0 alpha:1.0], NSUnderlineStyleAttributeName:[NSNumber numberWithInt:NSUnderlineStyleSingle]}
                                                selfBubbleBorderColor: selfColor
                                                selfAvatarBorderColor: selfColor
													 otherBubbleColor: [UIColor clearColor]
												 otherBubbleTextColor: [UIColor colorWithWhite:1.0 alpha:0.85]
											  otherLinkTextAttributes:  @{NSForegroundColorAttributeName:[UIColor colorWithRed:0.96 green:0.93 blue:0.0 alpha:1.0], NSUnderlineStyleAttributeName:[NSNumber numberWithInt:NSUnderlineStyleSingle]}
                                               otherBubbleBorderColor: otherColor
											   otherAvatarBorderColor: otherColor
                                         bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor colorWithRed:1.0 green:0.78 blue:0.18 alpha:0.1]
												messageLabelTextColor: [UIColor colorWithRed:1.0 green:0.78 blue:0.18 alpha:0.5]
                                                  messageLabelBGColor: [UIColor colorWithWhite:0.0 alpha:0.05]
												conversationBodyColor: [UIColor whiteColor]
											  conversationHeaderColor: [UIColor colorWithRed:1.0 green:0.78 blue:0.18 alpha:1.0]
												   messageHeaderColor: [UIColor blackColor]
														navBarIsBlack: YES
												  navBarIsTranslucent: NO
														  navBarColor: [UIColor blackColor]
													 navBarTitleColor: [UIColor colorWithRed:1.0 green:0.78 blue:0.18 alpha:1.0]
														 appTintColor: [UIColor colorWithRed:1.0 green:0.78 blue:0.18 alpha:1.0]
													chatOptionsIsDark: YES
												 scrollerColorIsWhite: YES
                                                             keyID: @(themeIDNumber).stringValue
 														localizedName: NSLocalizedString(@"Yellow", @"Yellow")]
						  forKey:@(themeIDNumber).stringValue];
    

    
    themeIDNumber = 4;
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: nil
												 plainBackgroundColor:  [UIColor colorWithWhite: 0.0 alpha: 1.0]
													  selfBubbleColor: [UIColor colorWithWhite: 0.25 alpha: 0.9]
														selfTextColor: [UIColor whiteColor]
                                               selfLinkTextAttributes:  @{NSForegroundColorAttributeName:[UIColor lightGrayColor]}
                                                 selfBubbleBorderColor: [UIColor clearColor]
                                                selfAvatarBorderColor: [UIColor colorWithRed:0.1 green:0.7 blue:0.1 alpha:1.0]
                                                      otherBubbleColor: [UIColor colorWithWhite: 0.67 alpha: 0.9]
												 otherBubbleTextColor: [UIColor blackColor]
                                               otherLinkTextAttributes:  @{NSForegroundColorAttributeName:[UIColor blueColor]}
                                                 otherBubbleBorderColor: [UIColor clearColor]
                                                otherAvatarBorderColor: [UIColor colorWithRed:0.1 green:0.7 blue:0.1 alpha:1.0]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor whiteColor]
                                                messageLabelTextColor: [UIColor colorWithRed: 0.0 green: 0.8 blue: 0.0 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor whiteColor]
											  conversationHeaderColor: [UIColor whiteColor]
												   messageHeaderColor: [UIColor whiteColor]
														navBarIsBlack: YES
												  navBarIsTranslucent: YES
                                                          navBarColor: [UIColor blackColor]
													 navBarTitleColor: [UIColor colorWithRed:0.1 green:0.7 blue:0.1 alpha:1.0]
														 appTintColor: [UIColor colorWithRed: 0.0 green: 0.8 blue: 0.0 alpha: 1.0]
                                                    chatOptionsIsDark: YES
  												 scrollerColorIsWhite: YES
                                                              keyID: @(themeIDNumber).stringValue
 														localizedName: NSLocalizedString(@"Green", @"Green")]
						  forKey:@(themeIDNumber).stringValue];
	
#if 0
    [appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: @"Wallp-linen.jpg"
												 plainBackgroundColor: nil
													  selfBubbleColor: [UIColor colorWithRed: 0.0 green: 0.5 blue: 1 alpha: 0.8]
														selfTextColor: [UIColor whiteColor]
                                               selfLinkTextAttributes:  @{NSForegroundColorAttributeName:[UIColor blackColor]}
                                                selfBubbleBorderColor: [UIColor clearColor]
                                                selfAvatarBorderColor: [UIColor colorWithRed: 0.4 green: 0.8 blue: 1 alpha: 0.9]
 												 otherBubbleColor: [UIColor colorWithWhite: 0.67 alpha: 0.9]
												 otherBubbleTextColor: [UIColor blackColor]
                                               otherLinkTextAttributes:  nil
                                            otherBubbleBorderColor: [UIColor clearColor]
                                               otherAvatarBorderColor: [UIColor blackColor]
                                            bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
												messageLabelTextColor: [UIColor colorWithWhite: 0.50 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor blackColor]
											  conversationHeaderColor: [UIColor blackColor]
												   messageHeaderColor: [UIColor blackColor]
														navBarIsBlack: YES
												  navBarIsTranslucent: YES
                                                          navBarColor: [UIColor blackColor]
													 navBarTitleColor: nil
														 appTintColor: nil
													chatOptionsIsDark: YES
 												 scrollerColorIsWhite: NO
														localizedName: NSLocalizedString(@"msg", @"msg")]
						  forKey: @"msg"];

  	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: @"Parchment_Paper.jpg"
												 plainBackgroundColor: nil
													  selfBubbleColor: [UIColor colorWithRed: 0.97 green: 0.78 blue: 0.38 alpha: 0.5]
														selfTextColor: [UIColor blackColor]
                                                selfBubbleBorderColor: [UIColor blackColor]
													 otherBubbleColor: [UIColor colorWithRed: 0.78 green: 0.50 blue: 0.20 alpha: 0.5]
												 otherBubbleTextColor: [UIColor blackColor]
                                               otherBubbleBorderColor: [UIColor blackColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
                                                  messageLabelTextColor: [UIColor colorWithRed: 0.55 green: 0.16 blue: 0.05 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor blackColor]
											  conversationHeaderColor: [UIColor blackColor]
												   messageHeaderColor: [UIColor blackColor]
														navBarIsBlack: NO
												  navBarIsTranslucent: YES
                                                            navBarColor: [UIColor whiteColor]
													 navBarTitleColor: nil
														 appTintColor: [UIColor colorWithRed: 0.79 green: 0.29 blue: 0.17 alpha: 1.0]
													chatOptionsIsDark: YES
 												 scrollerColorIsWhite: NO
														localizedName: NSLocalizedString(@"Old World", @"Old World")]
						  forKey: @"Old World"];
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: nil
												 plainBackgroundColor: [UIColor colorWithRed: 0.16 green: 0.17 blue: 0.21 alpha: 1.0]
													  selfBubbleColor: [UIColor colorWithWhite: 0.25 alpha: 0.9]
														selfTextColor: [UIColor whiteColor]
                                                selfBubbleBorderColor: [UIColor blackColor]
                                                     otherBubbleColor: [UIColor colorWithWhite: 0.67 alpha: 0.9]
												 otherBubbleTextColor: [UIColor blackColor]
                                               otherBubbleBorderColor: [UIColor blackColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor whiteColor]
                                                messageLabelTextColor: [UIColor colorWithWhite:0.75 alpha:1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor whiteColor]
											  conversationHeaderColor: [UIColor whiteColor]
												   messageHeaderColor: [UIColor whiteColor]
														navBarIsBlack: YES
												  navBarIsTranslucent: YES
                                                          navBarColor: [UIColor whiteColor]
 													 navBarTitleColor: nil
														 appTintColor: [UIColor orangeColor]
													chatOptionsIsDark: YES
												 scrollerColorIsWhite: YES
														localizedName: NSLocalizedString(@"Dusk", @"Dusk")]
						  forKey:@"Dusk"];
 
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: @"clear_night_sky.jpg"
												 plainBackgroundColor: [UIColor blackColor]
													  selfBubbleColor: [UIColor colorWithWhite: 0.25 alpha: 0.9]
														selfTextColor: [UIColor whiteColor]
                                                selfBubbleBorderColor: [UIColor whiteColor]
                                                     otherBubbleColor: [UIColor colorWithWhite: 0.67 alpha: 0.9]
												 otherBubbleTextColor: [UIColor whiteColor]
                                               otherBubbleBorderColor: [UIColor blackColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
                                                messageLabelTextColor: [UIColor colorWithWhite: 0.50 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor whiteColor]
											  conversationHeaderColor: [UIColor whiteColor]
												   messageHeaderColor: [UIColor whiteColor]
														navBarIsBlack: YES
												  navBarIsTranslucent: YES
                                                          navBarColor: [UIColor whiteColor]
 													 navBarTitleColor: nil
														 appTintColor: nil
                                                    chatOptionsIsDark: YES
												 scrollerColorIsWhite: YES
														localizedName: NSLocalizedString(@"Night", @"Night")]
						  forKey:@"Night"];
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: @"sand@2x.jpg"
												 plainBackgroundColor: [UIColor colorWithRed: 0.88 green: 0.75 blue: 0.53 alpha: 1.0]
													  selfBubbleColor: [UIColor colorWithRed: 0.52 green: 0.33 blue: 0.23 alpha: 0.9]
														selfTextColor: [UIColor whiteColor]
                                                selfBubbleBorderColor: [UIColor blackColor]
                                                     otherBubbleColor: [UIColor colorWithRed: 0.97 green: 0.93 blue: 0.87 alpha: 0.9]
												 otherBubbleTextColor: [UIColor blackColor]
                                               otherBubbleBorderColor: [UIColor blackColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
                                                messageLabelTextColor: [UIColor whiteColor]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor blackColor]
											  conversationHeaderColor: [UIColor blackColor]
												   messageHeaderColor: [UIColor blackColor]
														navBarIsBlack: NO
												  navBarIsTranslucent: YES
                                                           navBarColor: [UIColor blackColor]
 													 navBarTitleColor: nil
														 appTintColor: nil
                                                    chatOptionsIsDark: YES
												 scrollerColorIsWhite: NO
														localizedName: NSLocalizedString(@"Beach", @"Beach")]
						  forKey:@"Beach"];
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: @"blue-gradient.jpeg"
												 plainBackgroundColor: nil
													  selfBubbleColor: [UIColor colorWithRed: 0.03 green: 0.25 blue: 0.50 alpha: 0.9]
														selfTextColor: [UIColor whiteColor]
                                                selfBubbleBorderColor: [UIColor blackColor]
                                                     otherBubbleColor: [UIColor colorWithWhite: 0.67 alpha: 0.9]
												 otherBubbleTextColor: [UIColor blackColor]
                                               otherBubbleBorderColor: [UIColor blackColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
                                                messageLabelTextColor: [UIColor colorWithWhite: 0.8 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor whiteColor]
											  conversationHeaderColor: [UIColor whiteColor]
												   messageHeaderColor: [UIColor whiteColor]
														navBarIsBlack: NO
												  navBarIsTranslucent: YES
                                                          navBarColor: [UIColor whiteColor]
 													 navBarTitleColor: nil
														 appTintColor: nil
                                                    chatOptionsIsDark: YES
 												 scrollerColorIsWhite: YES
														localizedName: NSLocalizedString(@"Twilight", @"Twilight")]
						  forKey:@"Twilight"];
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: @"wispysky@2x.jpg"
												 plainBackgroundColor: nil
													  selfBubbleColor: [UIColor colorWithRed: 0.4 green: 0.8 blue: 1 alpha: 0.8]
														selfTextColor: [UIColor blackColor]
                                                selfBubbleBorderColor: [UIColor whiteColor]
                                                     otherBubbleColor: [UIColor colorWithWhite: 0.9 alpha: 0.8]
												 otherBubbleTextColor: [UIColor blackColor]
                                               otherBubbleBorderColor: [UIColor whiteColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
                                                messageLabelTextColor: [UIColor colorWithWhite: 0.25 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor blackColor]
											  conversationHeaderColor: [UIColor blackColor]
												   messageHeaderColor: [UIColor blackColor]
														navBarIsBlack: NO
												  navBarIsTranslucent: YES
                                                          navBarColor: [UIColor blackColor]
 													 navBarTitleColor: nil
														 appTintColor: nil
                                                    chatOptionsIsDark: YES
												 scrollerColorIsWhite: YES
														localizedName: NSLocalizedString(@"Blue Sky", @"Blue Sky")]
						  forKey:@"Blue Sky"];
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: nil
												 plainBackgroundColor: [UIColor whiteColor]
													  selfBubbleColor: [UIColor colorWithWhite: 0.24 alpha: 0.9]
														selfTextColor: [UIColor whiteColor]
                                                selfBubbleBorderColor: [UIColor whiteColor]
                                                     otherBubbleColor: [UIColor colorWithWhite: 0.87 alpha: 0.9]
												 otherBubbleTextColor: [UIColor blackColor]
                                               otherBubbleBorderColor: [UIColor whiteColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
                                                messageLabelTextColor: [UIColor colorWithWhite: 0.50 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor blackColor]
											  conversationHeaderColor: [UIColor blackColor]
												   messageHeaderColor: [UIColor blackColor]
														navBarIsBlack: YES
												  navBarIsTranslucent: NO
                                                          navBarColor: [UIColor whiteColor]
 													 navBarTitleColor: nil
														 appTintColor: nil
                                                    chatOptionsIsDark: YES
												 scrollerColorIsWhite: NO
														localizedName: NSLocalizedString(@"Black & White", @"Black & White")]
						  forKey:@"Black & White"];
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: @"white-construction-paper.jpg"
												 plainBackgroundColor: [UIColor whiteColor]
													  selfBubbleColor: [UIColor colorWithWhite: 0.14 alpha: 0.2]
														selfTextColor: [UIColor whiteColor]
                                                selfBubbleBorderColor: [UIColor blackColor]
                                                     otherBubbleColor: [UIColor colorWithWhite: 0.87 alpha: 0.2]
												 otherBubbleTextColor: [UIColor blackColor]
                                               otherBubbleBorderColor: [UIColor blackColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
                                                messageLabelTextColor: [UIColor colorWithWhite: 0.50 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor blackColor]
											  conversationHeaderColor: [UIColor blackColor]
												   messageHeaderColor: [UIColor blackColor]
														navBarIsBlack: NO
												  navBarIsTranslucent: NO
                                                          navBarColor: [UIColor whiteColor]
 													 navBarTitleColor: nil
														 appTintColor: nil
                                                    chatOptionsIsDark: YES
												 scrollerColorIsWhite: NO
														localizedName: NSLocalizedString(@"Paper", @"Paper")]
						  forKey:@"Paper"];
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: nil
												 plainBackgroundColor: [UIColor blackColor]
													  selfBubbleColor: [UIColor colorWithWhite: 0.8 alpha: 0.9]
														selfTextColor: [UIColor blackColor]
                                                selfBubbleBorderColor: [UIColor blackColor]
                                                     otherBubbleColor: [UIColor colorWithWhite: 0.4 alpha: 0.9]
												 otherBubbleTextColor: [UIColor whiteColor]
                                               otherBubbleBorderColor: [UIColor blackColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor whiteColor]
                                                messageLabelTextColor: [UIColor colorWithWhite: 0.75 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor whiteColor]
											  conversationHeaderColor: [UIColor whiteColor]
												   messageHeaderColor: [UIColor whiteColor]
														navBarIsBlack: NO
												  navBarIsTranslucent: NO
                                                          navBarColor: [UIColor whiteColor]
 													 navBarTitleColor: nil
														 appTintColor: nil
                                                    chatOptionsIsDark: YES
												 scrollerColorIsWhite: YES
														localizedName: NSLocalizedString(@"White & Black", @"White & Black")]
						  forKey:@"White & Black"];
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: nil
												 plainBackgroundColor: [UIColor colorWithRed: 1.0 green: 0.99 blue: 0.92 alpha: 1.0]
													  selfBubbleColor: [UIColor colorWithRed: 1.00 green: 0.84 blue: 0.19 alpha: 0.9]
														selfTextColor: [UIColor blackColor]
                                                selfBubbleBorderColor: [UIColor blackColor]
                                                     otherBubbleColor: [UIColor colorWithRed: 1.00 green: 0.96 blue: 0.52 alpha: 0.9]
												 otherBubbleTextColor: [UIColor blackColor]
                                               otherBubbleBorderColor: [UIColor blackColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
                                                messageLabelTextColor: [UIColor colorWithRed: .93 green: .61 blue: .16 alpha: 0.9]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor blackColor]
											  conversationHeaderColor: [UIColor blackColor]
												   messageHeaderColor: [UIColor blackColor]
														navBarIsBlack: NO
												  navBarIsTranslucent: YES
                                                          navBarColor: [UIColor whiteColor]
 													 navBarTitleColor: nil
														 appTintColor: nil
                                                    chatOptionsIsDark: YES
 												 scrollerColorIsWhite: NO
														localizedName: NSLocalizedString(@"Daylight", @"Daylight")]
						  forKey:@"Daylight"];
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: @"pink.jpeg"
												 plainBackgroundColor: [UIColor colorWithRed:0.86 green:.23 blue:.75 alpha:1.0]
													  selfBubbleColor: [UIColor colorWithRed: 1 green: .45 blue: 0.78 alpha: 0.9]
														selfTextColor: [UIColor blackColor]
                                                selfBubbleBorderColor: [UIColor blackColor]
                                                     otherBubbleColor: [UIColor colorWithRed: 0.88 green: 0.67 blue: 0.77 alpha: 0.9]
												 otherBubbleTextColor: [UIColor blackColor]
                                               otherBubbleBorderColor: [UIColor blackColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
                                                messageLabelTextColor: [UIColor colorWithWhite: 0.75 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor whiteColor]
											  conversationHeaderColor: [UIColor whiteColor]
												   messageHeaderColor: [UIColor whiteColor]
														navBarIsBlack: NO
												  navBarIsTranslucent: YES
                                                          navBarColor: [UIColor whiteColor]
 													 navBarTitleColor: nil
														 appTintColor: nil
                                                    chatOptionsIsDark: YES
 												 scrollerColorIsWhite: NO
														localizedName: NSLocalizedString(@"Emily Pink", @"Other 1")]
						  forKey:@"Emily Pink"];
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: @"Blue.jpg"
												 plainBackgroundColor: [UIColor colorWithRed:0.15 green:0.90 blue:0.92 alpha:1.0]
													  selfBubbleColor: [UIColor colorWithRed: .13 green: 0.65 blue: 0.78 alpha: 0.9]
														selfTextColor: [UIColor whiteColor]
                                                selfBubbleBorderColor: [UIColor blackColor]
                                                     otherBubbleColor: [UIColor colorWithRed: 0.25 green: 0.50 blue: 0.66 alpha: 0.9]
												 otherBubbleTextColor: [UIColor whiteColor]
                                               otherBubbleBorderColor: [UIColor blackColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
                                                messageLabelTextColor: [UIColor colorWithRed: 0.50 green: 0.50 blue: 0.50 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor colorWithWhite:0.2 alpha:1.0]
											  conversationHeaderColor: [UIColor colorWithWhite:0.2 alpha:1.0]
												   messageHeaderColor: [UIColor colorWithWhite:0.2 alpha:1.0]
														navBarIsBlack: YES
												  navBarIsTranslucent: YES
                                                          navBarColor: [UIColor whiteColor]
 													 navBarTitleColor: nil
														 appTintColor: nil
                                                    chatOptionsIsDark: YES
 												 scrollerColorIsWhite: YES
														localizedName: NSLocalizedString(@"Emily Blue", @"Other 2")]
						  forKey:@"Emily Blue"];
	
	[appThemeDictionary setValue:[[AppTheme alloc] initWithBackground: @"green.jpeg"
												 plainBackgroundColor: [UIColor colorWithRed:0.28 green:0.90 blue:0.62 alpha:1.0]
													  selfBubbleColor: [UIColor colorWithRed: .24 green: .80 blue: 0.54 alpha: 0.9]
														selfTextColor: [UIColor whiteColor]
                                                selfBubbleBorderColor: [UIColor blackColor]
                                                     otherBubbleColor: [UIColor colorWithRed: 0.20 green: 0.68 blue: 0.46 alpha: 0.9]
												 otherBubbleTextColor: [UIColor whiteColor]
                                               otherBubbleBorderColor: [UIColor blackColor]
                                           bubbleSelectionBorderColor: [UIColor colorWithRed:0.0 green:0.20 blue:0.9 alpha:0.8]
                                                  backgroundTextColor: [UIColor blackColor]
                                                messageLabelTextColor: [UIColor colorWithRed: 0.50 green: 0.50 blue: 0.50 alpha: 1.0]
                                                  messageLabelBGColor: [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.15]
												conversationBodyColor: [UIColor colorWithRed: .20 green: 0.68 blue: 0.46 alpha: 1.0]
											  conversationHeaderColor: [UIColor colorWithRed: .20 green: 0.68 blue: 0.46 alpha: 1.0]
												   messageHeaderColor: [UIColor colorWithRed: .20 green: 0.68 blue: 0.46 alpha: 1.0]
														navBarIsBlack: YES
												  navBarIsTranslucent: YES
                                                          navBarColor: [UIColor whiteColor]
 													 navBarTitleColor: nil
														 appTintColor: nil
                                                    chatOptionsIsDark: YES
  											 scrollerColorIsWhite: NO
														localizedName: NSLocalizedString(@"Emily Green", @"Other 2")]
						  forKey:@"Emily Green"];

#endif
    
	keys = [[appThemeDictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
	
	//
	//
	//	static dispatch_once_t onceToken;
	//	dispatch_once(&onceToken, ^{
	//
	//		sharedInstance = [[AppTheme alloc] init];
	//	});
}
//
//+ (instancetype)sharedInstance
//{
//	return sharedInstance;
//}



+ (NSInteger) count
{
	return appThemeDictionary.count;
}

+ (NSString *) getThemeKeyForIndex:(NSInteger) index
{
	return keys[index];
}

+ (NSArray *) getAllThemeKeys
{
	return keys;
}

+ (NSString *) getSelectedKey {
    
    NSString* name = [STPreferences appThemeNameForAccount: STDatabaseManager.currentUser.uuid];
    return name;

}
+ (void) setSelectedKey:(NSString *) key
{
      [STPreferences setAppThemeName:key forAccount: STDatabaseManager.currentUser.uuid];
}

+ (instancetype) getThemeBySelectedKey
{
    NSString* themeKey = [self getSelectedKey];
    AppTheme* theme = appThemeDictionary[themeKey];
	
    if (!theme)
    {
		DDLogError(@"getThemeBySelectedKey failed for key %@", themeKey);
    }
    
    if(!theme)
        theme = appThemeDictionary[[ keys firstObject] ];
    
    return theme;
}
+ (instancetype) getThemeByKey:(NSString *) key
{
	return appThemeDictionary[key];
}


+ (void) selectWithKey:(NSString *) key
{
	
	AppTheme *theme = [AppTheme getThemeByKey:key];
    if(!theme)
    {
        key = keys.firstObject;
        theme = [AppTheme getThemeByKey:key];
    }

    
	[[NSNotificationCenter defaultCenter] postNotificationName:kAppThemeChangeNotification object:nil userInfo:@{kNotificationUserInfoTheme:theme, kNotificationUserInfoName:key}];
}
- (instancetype) initWithBackground: backGroundImageFileName
			   plainBackgroundColor: (UIColor *) plainBackgroundColor
					selfBubbleColor: (UIColor *) selfBubbleColor
					  selfTextColor: (UIColor *) selfTextColor
             selfLinkTextAttributes: (NSDictionary*)selfLinkTextAttributes
              selfBubbleBorderColor: (UIColor *) selfBubbleBorderColor
              selfAvatarBorderColor: (UIColor *) selfAvatarBorderColor
 				   otherBubbleColor: (UIColor *) otherBubbleColor
			   otherBubbleTextColor: (UIColor *) otherBubbleTextColor
            otherLinkTextAttributes: (NSDictionary*)otherLinkTextAttributes
             otherBubbleBorderColor: (UIColor *) otherBubbleBorderColor
             otherAvatarBorderColor: (UIColor *) otherAvatarBorderColor
         bubbleSelectionBorderColor: (UIColor *) bubbleSelectionBorderColor
 				backgroundTextColor: (UIColor *) backgroundTextColor
              messageLabelTextColor: (UIColor *) messageLabelTextColor
                messageLabelBGColor: (UIColor *) messageLabelBGColor
 			  conversationBodyColor: (UIColor *) conversationBodyColor
			conversationHeaderColor: (UIColor *) conversationHeaderColor
				 messageHeaderColor: (UIColor *) messageHeaderColor
					  navBarIsBlack: (BOOL) navBarIsBlack
				navBarIsTranslucent: (BOOL) navBarIsTranslucent
                        navBarColor: (UIColor *) navBarColor
				   navBarTitleColor: (UIColor *) navBarTitleColor
					   appTintColor: (UIColor *) appTintColor
				  chatOptionsIsDark: (BOOL) chatOptionsIsDark
			   scrollerColorIsWhite: (BOOL) scrollerColorIsWhite
                           keyID:  (NSString*) keyID
					  localizedName: (NSString*)localizedName
{
	if (self) {
 		_backgroundImageFileName = backGroundImageFileName;
		_plainBackgroundColor = plainBackgroundColor;
		_selfBubbleColor = selfBubbleColor;
		_selfBubbleTextColor = selfTextColor;
        _selfBubbleBorderColor = selfBubbleBorderColor;
        _selfAvatarBorderColor = selfAvatarBorderColor;
		_otherBubbleColor = otherBubbleColor;
		_otherBubbleTextColor = otherBubbleTextColor;
        _otherBubbleBorderColor= otherBubbleBorderColor;
        _otherAvatarBorderColor = otherAvatarBorderColor;
        _bubbleSelectionBorderColor = bubbleSelectionBorderColor;
		_backgroundTextColor = backgroundTextColor;
		_messageLabelTextColor = messageLabelTextColor;
        _messageLabelBGColor = messageLabelBGColor;
		_navBarIsBlack = navBarIsBlack;
		_navBarIsTranslucent = navBarIsTranslucent;
		_navBarColor = navBarColor;
		_navBarTitleColor = navBarTitleColor;
		_conversationBodyColor = conversationBodyColor;
		_conversationHeaderColor = conversationHeaderColor;
		_messageHeaderColor = messageHeaderColor;
		_appTintColor = appTintColor;
		_chatOptionsIsDark = chatOptionsIsDark;
		_scrollerColorIsWhite = scrollerColorIsWhite;
		_localizedName = localizedName;
        _themeKey = keyID;
        
        _selfLinkTextAttributes  = selfLinkTextAttributes?:appTintColor?@{NSForegroundColorAttributeName:appTintColor}:nil;
        _otherLinkTextAttributes  = otherLinkTextAttributes?:appTintColor?@{NSForegroundColorAttributeName:appTintColor}:nil;

        
	}
	return self;
}

- (UIImage *) backgroundImage
{
	return [UIImage imageWithCGImage:[[UIImage imageNamed:_backgroundImageFileName] CGImage]
												   scale:2.0
											 orientation:UIImageOrientationUp];

}
- (UIColor *) backgroundColor
{
	if (_backgroundImageFileName) {
		return [UIColor colorWithPatternImage:[self backgroundImage]];
	}
	else
		return _plainBackgroundColor;
}

- (UIColor *) blurredBackgroundColor
{
	if (_backgroundImageFileName) {
		
		return [UIColor colorWithPatternImage:[[self backgroundImage] applyBlurWithRadius:3 tintColor:[UIColor colorWithWhite:0.0 alpha:0.10] saturationDeltaFactor:1.0 maskImage:nil]];
	}
	else
		return _plainBackgroundColor;
}
//
//- (UIColor *) backgroundImage
//{
//	if (_backgroundImageFileName) {
//		return [UIColor colorWithPatternImage:[UIImage imageNamed:_backgroundImageFileName]];
//	}
//	else
//		return _plainBackgroundColor;
//}
//
//- (UIColor *) blurredBackgroundImage
//{
//	if (_backgroundImageFileName) {
//		return [UIColor colorWithPatternImage:[[UIImage imageNamed:_backgroundImageFileName] applyBlurWithRadius:3 tintColor:[UIColor colorWithWhite:1.0 alpha:0.15] saturationDeltaFactor:1.0 maskImage:nil]];
//	}
//	else
//		return _plainBackgroundColor;
//}
@end
