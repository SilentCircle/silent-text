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
//  AppThemePickerPhoneViewController.m
//  ST2
//
//  Created by mahboud on 1/21/14.
//

#import "AppTheme.h"
#import "AppThemeView.h"
#import "AppThemePickerPhoneViewController.h"

@interface AppThemePickerPhoneViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIPageControl *pageControl;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
- (IBAction)changePage:(id)sender;

@end

@implementation AppThemePickerPhoneViewController {
	BOOL _pageControlUsed;

}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (BOOL) shouldAutorotate
{
	return NO;
}


- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait;
}
- (UIImage *) snapshot:(UIView *) view
{
	UIImage *image;
	UIGraphicsBeginImageContext(view.frame.size);
	//new iOS 7 method to snapshot
	//	BOOL gotit = [view drawViewHierarchyInRect:view.frame afterScreenUpdates:YES];
	[view.layer renderInContext:UIGraphicsGetCurrentContext()];
	image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

	self.automaticallyAdjustsScrollViewInsets = NO;
//	self.navigationItem.title = NSLocalizedString(@"Themes", @"Themes label");
	self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                  target:self
                                                  action:@selector(handleActionBarDone)];
    
     
    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                  target:self
                                                  action:@selector(handleActionBarCancel)];
}

- (void)viewDidLayoutSubviews {
//- (void)viewWillAppear:(BOOL)animated {
//	[super viewWillAppear:animated];
	[super viewDidLayoutSubviews];
	
	short numberOfStyles = [AppTheme count];
	const CGFloat horiz_spacing = 40.0;
	CGFloat totalWidth = 0;
	CGFloat contentWidth = _scrollView.frame.size.width - horiz_spacing;
	CGFloat contentHeight = _scrollView.frame.size.height;
//	_scrollView.frame = CGRectMake(0, _scrollView.frame.origin.y, _scrollView.frame.size.width, contentHeight);
	NSString *currName = [AppTheme getSelectedKey];
	NSArray *allNames = [AppTheme getAllThemeKeys];
	for (NSString *name in [AppTheme getAllThemeKeys]) {
		UIView	*themedView = [[AppThemeView alloc] initWithThemeName: name andTheme:[AppTheme getThemeByKey:name]];
		themedView.layer.borderColor = [UIColor grayColor].CGColor;
		themedView.layer.borderWidth = 1.0;
		themedView.layer.cornerRadius = 5.0;
		themedView.clipsToBounds = YES;

		UIImage *anImage = [self snapshot: themedView];
		if (anImage) {
			UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(totalWidth + horiz_spacing/2.0, 0, contentWidth, contentHeight)];
			imageView.contentMode = UIViewContentModeScaleAspectFit;
//			button.clipsToBounds = YES;
			//[button setImage: [anImage crop:CGRectMake(0, 0, contentWidth, contentHeight)]];
			[imageView setImage: anImage];
			imageView.tag = numberOfStyles;
			imageView.layer.shadowColor = [UIColor whiteColor].CGColor;
			imageView.layer.shadowRadius = 10.0;
			imageView.layer.shadowOpacity = 0.5;
			imageView.layer.shadowOffset = CGSizeZero;

//			[button addTarget:self action:@selector(bpPress:) forControlEvents:UIControlEventTouchUpInside];
//			button.layer.borderColor = [UIColor grayColor].CGColor;
//			button.layer.borderWidth = 1.0;
            
			totalWidth += contentWidth + horiz_spacing;
			[_scrollView addSubview:imageView];
            
            //ET 01/30/15 - Add gesture recognizer to dismiss when theme imageView is tapped
            imageView.userInteractionEnabled = YES;
            UITapGestureRecognizer *gr = [[UITapGestureRecognizer alloc] initWithTarget:self 
                                                                                 action:@selector(handleActionBarDone)];
            imageView.gestureRecognizers = @[gr];
		}
	}
	_scrollView.contentSize = CGSizeMake(totalWidth, contentHeight);
	_scrollView.pagingEnabled = YES;
	_scrollView.showsHorizontalScrollIndicator = YES;
	_scrollView.showsVerticalScrollIndicator = NO;
	_scrollView.scrollsToTop = NO;
	NSLog(@"scroll: %@", _scrollView);
	_pageControl.numberOfPages = numberOfStyles;
	_pageControl.currentPage = [allNames indexOfObject:currName];
	[self changePageWithAnimation:NO];
   	_pageControlUsed = NO;	// last statement leaves this value as YES
}


- (void)viewDidDisappear:(BOOL)animated {
	// remove the imageviews that we add in viewWillAppear
	for (UIView *subview in _scrollView.subviews) {
		if ( (subview.tag > 0) && ([subview isKindOfClass:[UIImageView class]]) )
			[subview removeFromSuperview];
	}
}

//
//- (void)updateViewConstraints
//{
//	[super updateViewConstraints];
//	NSLog(@"scroll: %@", _scrollView);
//}

- (void)handleActionBarCancel
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleActionBarDone
{
    NSString* themeKey  = [AppTheme getThemeKeyForIndex:_pageControl.currentPage];
	[AppTheme selectWithKey: themeKey];       // actually turn the theme
    [AppTheme setSelectedKey:themeKey];   // set it in prefs

	[self dismissViewControllerAnimated:YES completion:nil];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	// We don't want a "feedback loop" between the UIPageControl and the scroll delegate in
	// which a scroll event generated from the user hitting the page control triggers updates from
	// the delegate method. We use a boolean to disable the delegate logic when the page control is used.
	if (_pageControlUsed) {
		// do nothing - the scroll was initiated from the page control, not the user dragging
		return;
	}
	// Switch the indicator when more than 50% of the previous/next page is visible
	CGFloat pageWidth = _scrollView.frame.size.width;
	int page = floor((_scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
	_pageControl.currentPage = page;
}
// At the end of scroll animation, reset the boolean used when scrolls originate from the UIPageControl
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	_pageControlUsed = NO;
}

- (void)changePageWithAnimation:(BOOL) yesNo
{
	NSInteger page = _pageControl.currentPage;
	
	// update the scroll view to the appropriate page
	CGRect frame = _scrollView.frame;
	frame.origin.x = frame.size.width * page;
	frame.origin.y = 0;
	// Set the boolean used when scrolls originate from the UIPageControl. See scrollViewDidScroll: above.
	_pageControlUsed = YES;
	[_scrollView scrollRectToVisible:frame animated:yesNo];
	
	
}

- (IBAction)changePage:(id)sender {
	[self changePageWithAnimation:YES];
}
@end
