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
//  BackgroundPickerViewController.m
//  SilentText
//

#import "BackgroundPickerViewController.h"
#import "App+ApplicationDelegate.h"
#import <QuartzCore/QuartzCore.h>

@interface UIImage (Crop)
- (UIImage *)crop:(CGRect)rect;
@end
@implementation UIImage (Crop)
- (UIImage *)crop:(CGRect)rect {
	// Create bitmap image from original image data,
	// using rectangle to specify desired crop area
	CGImageRef croppedImageRef = CGImageCreateWithImageInRect([self CGImage], CGRectMake(rect.origin.x, [self size].width - rect.origin.x - rect.size.width, rect.size.width, rect.size.height));
	UIImage *croppedImage = [UIImage imageWithCGImage:croppedImageRef scale:self.scale orientation:[self imageOrientation]];
	CGImageRelease(croppedImageRef);
//	NSLog(@"Orientation was %d and is %d", [self imageOrientation], [croppedImage imageOrientation]);
	//	croppedImage = [croppedImage makeUpOrientation];
	//	NSLog(@"After makeUp it is %d ", [croppedImage imageOrientation]);
	return croppedImage;
}
@end
@interface BackgroundPickerViewController ()
@property (nonatomic, strong) NSMutableArray *fileNames;
@property BOOL						pageControlUsed;
@property (strong, nonatomic) UITapGestureRecognizer *tapRecognizer;

@end

@implementation BackgroundPickerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.navigationItem.title = NSLocalizedString(@"Select a Wallpaper", @"Select a Wallpaper");

    // Do any additional setup after loading the view from its nib.
	short numberOfStyles = 0;
	CGFloat totalWidth = 0;
	CGFloat contentWidth = _bpScrollView.frame.size.width;
	CGFloat contentHeight = _bpScrollView.frame.size.height;
	CGSize imageSize;
	UIImage *anImage;

	self.fileNames = [[NSMutableArray alloc] initWithCapacity:30];
	NSArray *allArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[NSBundle mainBundle] resourcePath] error:nil];
	[allArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if (([[obj pathExtension] isEqualToString:@"jpg"] || [[obj pathExtension] isEqualToString:@"png"]) && [obj hasPrefix:@"Wallp-"])
			[_fileNames addObject:obj];
	}];
//	_bpScrollView.layer.borderColor = [UIColor orangeColor].CGColor;
//	_bpScrollView.layer.borderWidth = 1.0;

	for (NSString *fname in _fileNames) {
		NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: fname];
		anImage = [[UIImage alloc] initWithContentsOfFile:path];
		if (anImage) {			
//			UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(totalWidth, 0, contentWidth, contentHeight)];
//			imageSize = anImage.size;
//			button.contentMode = UIViewContentModeScaleAspectFill;
//			[button setImage: [anImage crop:CGRectMake((imageSize.width - contentWidth) * 0.5, (imageSize.height - contentHeight) * 0.5, contentWidth, contentHeight)] forState:UIControlStateNormal];
//			button.tag = numberOfStyles;
//			[button addTarget:self action:@selector(bpPress:) forControlEvents:UIControlEventTouchUpInside];
//		button.layer.borderColor = [UIColor whiteColor].CGColor;
//		button.layer.borderWidth = 1.0;
			
			UIImageView *button = [[UIImageView alloc] initWithFrame:CGRectMake(totalWidth, 0, contentWidth, contentHeight)];
			imageSize = anImage.size;
			button.contentMode = UIViewContentModeCenter;
			button.clipsToBounds = YES;
			//[button setImage: [anImage crop:CGRectMake(0, 0, contentWidth, contentHeight)]];
			[button setImage: [anImage crop:CGRectMake((imageSize.width - contentWidth) * 0.5, (imageSize.height - contentHeight) * 0.5, contentWidth, contentHeight)]];
			button.tag = numberOfStyles;
//			[button addTarget:self action:@selector(bpPress:) forControlEvents:UIControlEventTouchUpInside];
			button.layer.borderColor = [UIColor grayColor].CGColor;
			button.layer.borderWidth = 1.0;

			
			totalWidth += contentWidth;
			[_bpScrollView addSubview:button];
			numberOfStyles++;
			if (numberOfStyles > 20) break;
		}
	}
	
	_bpScrollView.contentSize = CGSizeMake(totalWidth, contentHeight);
	_bpScrollView.pagingEnabled = YES;
	_bpScrollView.showsHorizontalScrollIndicator = YES;
	_bpScrollView.showsVerticalScrollIndicator = NO;
	_bpScrollView.scrollsToTop = NO;
	
	_bpPageControl.numberOfPages = numberOfStyles;
//	_bpPageControl.currentPage = [_fileNames indexOfObject:settings.sheetStyleName];
	[self changePageWithAnimation:NO];
	_pageControlUsed = NO;	// last statement leaves this value as YES
	
	UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bpPress:)];
	[_bpScrollView addGestureRecognizer:tapRecognizer];

}
- (void) showSheetSelectorAnimationDidEnd:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	[_bpScrollView flashScrollIndicators];
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
	CGFloat pageWidth = _bpScrollView.frame.size.width;
	int page = floor((_bpScrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
	_bpPageControl.currentPage = page;
}
// At the end of scroll animation, reset the boolean used when scrolls originate from the UIPageControl
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	_pageControlUsed = NO;
}
- (void)changePageWithAnimation:(BOOL) yesNo
{
	int page = _bpPageControl.currentPage;
	
	// update the scroll view to the appropriate page
	CGRect frame = _bpScrollView.frame;
	frame.origin.x = frame.size.width * page;
	frame.origin.y = 0;
	// Set the boolean used when scrolls originate from the UIPageControl. See scrollViewDidScroll: above.
	_pageControlUsed = YES;
#if 1	// this was not working before, and now it works
	[_bpScrollView scrollRectToVisible:frame animated:yesNo];
#else
	// !!!: The alternate way of auto scrolling
	CGPoint point = frame.origin;
	if (![bpScrollView pointInside:point withEvent:nil]) {
		point.y = 0;
		int x = bpScrollView.contentSize.width - bpScrollView.bounds.size.width + bpScrollView.contentInset.right;
		if (point.x > x)
			point.x = x;
		[bpScrollView setContentOffset:point animated:yesNo];
	}
#endif
	
	
}
- (IBAction)changePage:(id)sender {
	[self changePageWithAnimation:YES];
}
- (void) bpPress:(id) sender
{
	App *delegate = (App *) [[UIApplication sharedApplication] delegate];
	[delegate setBackground: [_fileNames objectAtIndex:_bpPageControl.currentPage]];

//	[self.delegate updateViewAfterChanges];
	
}

//- (void) removeSheetSelectorAnimationDidEnd
//{
//	NSArray *tempArray = [NSArray arrayWithArray:bpScrollView.subviews];
//	for (UIButton *button in tempArray) {
//		if ([button isKindOfClass:[UIButton class]]) {
//			[button removeFromSuperview];
//		}
//	}
//	[sheetStyleSelectorView removeFromSuperview];
//	[styleNames	release];
//}

//}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    [self setBpScrollView:nil];
    [self setBpPageControl:nil];
    [super viewDidUnload];
}
@end

