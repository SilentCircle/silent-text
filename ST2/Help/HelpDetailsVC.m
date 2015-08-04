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
//  HelpDetailsVC.m
//  ST2
//
//  Created by Eric Turner on 7/16/14.
//

#import "HelpDetailsVC.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "STLogging.h"
// Catetgories
#import "UIColor+Expanded.h"
#import "UIImage+ImageEffects.h"


@interface HelpDetailsVC () <UITextViewDelegate>
@property (nonatomic, strong) NSURL *privateURL;
@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) UIImage *bgImage;
@property (nonatomic, strong) UIImage *blurredImg;
@property (nonatomic, weak, readonly) AppTheme *theme;
@end

@implementation HelpDetailsVC


#pragma mark - Initialization
- (instancetype)initWithURL:(NSURL *)aUrl
{
    self = [[HelpDetailsVC alloc] initWithNibName:NSStringFromClass([self class]) bundle:nil];
    if (!self) { return nil; }
    
    _privateURL = aUrl;
    _webView.delegate = self;
    
    return self;
}

- (instancetype)initWithName:(NSString *)aName
{
    return [self initWithName:aName bgImage:nil];
}

- (instancetype)initWithName:(NSString *)aName bgImage:(UIImage *)bgImg
{
    self = [[HelpDetailsVC alloc] initWithNibName:NSStringFromClass([self class]) bundle:nil];
    if (!self) { return nil; }
    
    _privateURL = [[NSBundle mainBundle] URLForResource:aName withExtension:@"html"];
    _bgImage = bgImg;
    
    return self;    
}

#pragma mark - Views Layout
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.navigationController.navigationBar.isTranslucent)
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    [_webView setBackgroundColor:[UIColor clearColor]];
    [_webView setOpaque:NO];
    _webView.delegate = self;
    
    // bgImage is passed into the initializer; it is the unblurred parent view
    if (_bgImage)
    {
        // Store a blurred copy for fade-in in viewDidLoad
        _blurredImg = [_bgImage applyLightEffect];
        // Set the parent view image in the background imageView
        _imageView.image = _bgImage;
    }
    
    // Create Help HTML with CSS from localized Help file content
    NSMutableString *fullHTML = [NSMutableString string];
    NSString *strHeader = [NSString stringWithFormat:@"<!doctype html>\n<html>\n<head>\n%@\n</head>\n<body>",
                           [self strCSS]];
    
    [fullHTML appendString:strHeader];
    
    /* Conditionally insert a div of class "top-area", defined in the strCSS method:
     * If the current theme uses a translucent navbar, we space the html downward to compensate.
     * Attempts at resetting edgesForExtendedLayout and transluscent = NO did not work because of the 
     * image sleight-of-hand which starts with the image of the parent VC view, then cross-dissolves to
     * the blurred image. These attempts jerked the initial image downward before fading to blur.
     */
    BOOL useSpace = self.navigationController.navigationBar.isTranslucent;
    if (useSpace)
    {
        [fullHTML appendString:@"\n<div class=\"top-area\"> </div>\n"];
    }
    
    NSError *error = nil;
    NSString *baseHTML = [NSString stringWithContentsOfURL:_privateURL
                                                  encoding:NSUTF8StringEncoding 
                                                     error:&error];
    if (error)
    {
        DDLogRed(@"HTML Help content parsing error: %@", [error localizedDescription]);
    }
        
    [fullHTML appendString:baseHTML];
    
    NSString *strFooter = @"\n</body>\n</html>";
    [fullHTML appendString:strFooter];
    
    [_webView loadHTMLString:fullHTML baseURL:_privateURL];
//    DDLogCyan(@"%@", fullHTML);
    
    // Make webView transparent for fade-in in viewDidLoad
    _webView.alpha = 0;
}

- (void)viewDidAppear:(BOOL)animated
{
    // orig
    [UIView transitionWithView:self.view
                      duration:0.15
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self.imageView.image = _blurredImg;
                    } 
                    completion:^(BOOL finished) {
                        [UIView animateWithDuration:0.25 animations:^{
                            _webView.alpha = 1;
                        }];
                    }
     ];
}

- (NSString *)strCSS
{
    NSString *linkColor = [self.theme.appTintColor hexStringValue];
    NSString *visitedLinkColor = [[self.theme.appTintColor colorByDarkeningTo:0.65] hexStringValue];
    NSString *css = [NSString stringWithFormat:@"\n<style>\na:link {\ncolor: #%@\n}\na:visited {\ncolor: #%@\n}\n</style>\n",
                     linkColor, visitedLinkColor];

    return css;
}

- (AppTheme *)theme 
{
    return STAppDelegate.theme;
}


#pragma mark - UIWebViewDelegate Methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)aRequest navigationType:(UIWebViewNavigationType)aType
{
    // Only follow local links in the Help file
    if ([@"file" isEqualToString:aRequest.URL.scheme])
    {
        DDLogLightGray(@"request: %@", aRequest);
        return YES; 
    }
    
    // Otherwise, launch Safari/iTunes/Other
    [[UIApplication sharedApplication] openURL:aRequest.URL];
    return NO; 
}


#pragma mark - UIViewController Methods
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end

//http://stackoverflow.com/questions/2899699/uiwebview-open-links-in-safari
//- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)aRequest navigationType:(UIWebViewNavigationType)aType
//{
//    DDLogLightGray(@"Tapped Link request: %@", aRequest);
//    DDLogCyan(@"URL.scheme: %@", aRequest.URL.scheme);
//    static NSString *regexp = @"^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9])[.])+([A-Za-z]|[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9])$";
//    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regexp];
//    
//    if ([predicate evaluateWithObject:aRequest.URL.host]) {
//        [[UIApplication sharedApplication] openURL:aRequest.URL];
//        DDLogRed(@"Tapped Link: return NO");
//        return NO; 
//    }
//    DDLogGreen(@"Tapped Link: return YES");
//    return YES; 
//}
