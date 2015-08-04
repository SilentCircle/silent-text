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
//
//  BubbleColorsViewController.m
//  SilentText
//
//  Created by mahboud on 7/18/13.
//

#import "BubbleColorsViewController.h"
#import "STBubbleView.h"
#import "OSColor.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "STPreferences.h"
#import "UIImage+Thumbnail.h"
#import "OHAlertView.h"
#import "AddressBookManager.h"
#import "UIImage+Crop.h"
#import "AppTheme.h"

@interface BubbleColorsViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *otherAvatarImageView;
@property (weak, nonatomic) IBOutlet UIImageView *selfAvatarImageView;
@property (weak, nonatomic) IBOutlet UIButton *selfTextButton;
@property (weak, nonatomic) IBOutlet UIButton *selfBubbleButton;
@property (weak, nonatomic) IBOutlet UIButton *otherBubbleButton;
@property (weak, nonatomic) IBOutlet UIButton *otherTextButton;
@property (weak, nonatomic) IBOutlet STBubbleView *otherBubbleView;
@property (weak, nonatomic) IBOutlet STBubbleView *selfBubbleView;
@property (weak, nonatomic) IBOutlet UILabel *selfTextLabel;
@property (weak, nonatomic) IBOutlet UILabel *otherTextLabel;
@property (weak, nonatomic) IBOutlet UIScrollView *mainScrollViewContainer;
@property (weak, nonatomic) IBOutlet UIButton *backgroundTextButton;

@property (nonatomic, copy) void (^actionBlock)(UIColor *color);

@property (nonatomic, strong) NSMutableArray *fileNames;
@property BOOL						pageControlUsed;
@property (strong, nonatomic) UITapGestureRecognizer *tapRecognizer;

@end

@implementation BubbleColorsViewController

static OSColor* kDefaultSelfBubbleColor;
static OSColor* kDefaultSelfBubbleTextColor;
static OSColor* kDefaultOtherBubbleColor;
static OSColor* kDefaultOtherBubbleTextColor;
static OSColor* kDefaultBackgroundTextColor;


- (id)initWithProperNib
{
    kDefaultSelfBubbleColor     = [OSColor colorWithRed:102./255. green:204./255. blue:255./255. alpha:.9];
    kDefaultSelfBubbleTextColor = [OSColor blackColor ];
    kDefaultOtherBubbleColor    = [OSColor lightGrayColor ];
    kDefaultOtherBubbleTextColor= [OSColor blackColor ];
    kDefaultBackgroundTextColor = [OSColor blackColor ];
    
  	if (AppConstants.isIPhone)
		return [self initWithNibName:@"BubbleColorsViewController_iPhone" bundle:nil];
	else
		return [self initWithNibName:@"BubbleColorsViewController_iPad" bundle:nil];
}

//- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
//{
//    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
//    if (self) {
//        // Custom initialization
//    }
//    return self;
//}
- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	
//    self.navigationController.navigationBar.barStyle =  UIBarStyleBlack;
//    self.navigationController.navigationBar.translucent  = YES;
//    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    
    //    self.collectionView.contentInset = UIEdgeInsetsMake(self.navigationController.navigationBar.frame.size.height, 0,0,0);
    
//    self.view.backgroundColor =  [UIColor colorWithWhite: .95 alpha:1];
    
//    self.navigationItem.leftBarButtonItem =  STAppDelegate.settingsButton;

    self.navigationItem.title = NSLocalizedString(@"Appearance", @"Appearance");
	UIBarButtonItem *resetButton = [[UIBarButtonItem alloc]
                                    initWithTitle:NSLocalizedString(@"Reset", @"Reset")
                                    style:UIBarButtonItemStyleBordered
                                    target:self
                                    action:@selector(resetColors)];
	
//	self.navigationItem.rightBarButtonItem = resetButton;
    
    if (AppConstants.isIPhone)
    {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"")
                                                                                 style:UIBarButtonItemStylePlain target:self
                                                                                action:@selector(handleActionBarDone)];
		
		
    }

    
	UIEdgeInsets insets = UIEdgeInsetsMake(16, 19, 16, 19);
	UIImage *activeBtnBackground = [[UIImage imageNamed:@"DarkerButton"] resizableImageWithCapInsets: insets];
	[_otherTextButton setBackgroundImage:activeBtnBackground forState:UIControlStateNormal];
	[_otherBubbleButton setBackgroundImage:activeBtnBackground forState:UIControlStateNormal];
	[_selfTextButton setBackgroundImage:activeBtnBackground forState:UIControlStateNormal];
	[_selfBubbleButton setBackgroundImage:activeBtnBackground forState:UIControlStateNormal];
    [_backgroundTextButton setBackgroundImage:activeBtnBackground forState:UIControlStateNormal];
    [_selfTextButton setBackgroundImage:activeBtnBackground forState:UIControlStateNormal];
    [_selfBubbleButton setBackgroundImage:activeBtnBackground forState:UIControlStateNormal];
    [_otherTextButton setBackgroundImage:activeBtnBackground forState:UIControlStateNormal];
    [_otherBubbleButton setBackgroundImage:activeBtnBackground forState:UIControlStateNormal];
    
	[_selfBubbleView reset];
	[_otherBubbleView reset];
	static NSString *const kDefaultAvatarIcon = @"silhouette.png";
	UIImage *defaultImage = [UIImage imageNamed: kDefaultAvatarIcon];
	_otherAvatarImageView.image = [defaultImage newAvatarImage];

    
    UIImage *selfAvatar = NULL;
    if(STDatabaseManager.currentUser)
    {
        selfAvatar = [[DatabaseManager sharedInstance] imageForUser:STDatabaseManager.currentUser];
    
    }
 	if (selfAvatar)
		_selfAvatarImageView.image = [selfAvatar newAvatarImage];
	else
		_selfAvatarImageView.image = [defaultImage newAvatarImage];
	[self setColors];
    
    
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
	CGFloat multiplier = [UIScreen mainScreen].scale;
	CGFloat width = multiplier * contentWidth;
	CGFloat height = multiplier * contentHeight;
	
	for (NSString *fname in _fileNames) {
		NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: fname];
		anImage = [[UIImage alloc] initWithContentsOfFile:path];
		if (anImage) {
  			
			UIImageView *button = [[UIImageView alloc] initWithFrame:CGRectMake(totalWidth, 0, contentWidth, contentHeight)];
			imageSize = anImage.size;
			button.contentMode = UIViewContentModeScaleAspectFill;
			button.clipsToBounds = YES;
			//[button setImage: [anImage crop:CGRectMake(0, 0, contentWidth, contentHeight)]];
			CGRect cropRect = CGRectMake((imageSize.width - width) * 0.5, (imageSize.height - height) * 0.5, width, height);
			[button setImage: [anImage crop:cropRect]];
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
	_bpPageControl.currentPage = [_fileNames indexOfObject: [STPreferences backgroundPattern]];
    
	[self changePageWithAnimation:NO];
    
    
	_pageControlUsed = NO;	// last statement leaves this value as YES
	
	UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bpPress:)];
	[_bpScrollView addGestureRecognizer:tapRecognizer];

}

// deprecated
//- (void)viewDidUnload {
//    [self setBpScrollView:nil];
//    [self setBpPageControl:nil];
//    [self setOtherAvatarImageView:nil];
//    [self setSelfAvatarImageView:nil];
//    [self setOtherBubbleView:nil];
//    [self setSelfBubbleView:nil];
//    [self setSelfTextButton:nil];
//    [self setSelfBubbleButton:nil];
//    [self setOtherBubbleButton:nil];
//    [self setOtherTextButton:nil];
//    [self setSelfTextLabel:nil];
//    [self setOtherTextLabel:nil];
//    [self setMainScrollViewContainer:nil];
//    [super viewDidUnload];
//    
//}


- (void) viewWillAppear:(BOOL)animated
{
	if (AppConstants.isIOS7OrLater) {
        //		self.view.layer.contents = (id) App.sharedApp.background.CGImage;
//		self.view.backgroundColor = [UIColor colorWithPatternImage:App.sharedApp.background];
	}
}
- (void) handleActionBarDone
{
	[self dismissViewControllerAnimated:YES completion:nil];
}


- (void) resetColors
{
    
    [OHAlertView showAlertWithTitle:NSLocalizedString(@"Reset to Default Colors?",@"Reset to Default Colors?")
                            message:@""
                       cancelButton:NSLocalizedString(@"Cancel", @"Cancel")
                           okButton:NSLocalizedString(@"OK", @"OK")
                      buttonHandler:^(OHAlertView* alert, NSInteger buttonIndex)
     {
         if (buttonIndex == alert.cancelButtonIndex) {
             
         } else {
             [BubbleColorsViewController resetColors];
             [self setColors];
             
         }
     }];

 	
}
+ (void) resetColors
{
    [STPreferences setSelfBubbleColor:kDefaultSelfBubbleColor];
    [STPreferences setOtherBubbleColor:kDefaultOtherBubbleColor];
    [STPreferences setSelfBubbleTextColor:kDefaultSelfBubbleTextColor];
    [STPreferences setOtherBubbleTextColor:kDefaultOtherBubbleTextColor];
    [STPreferences setBackgroundTextColor:kDefaultBackgroundTextColor];
     
}

- (void) setColors
{
	_selfBubbleView.bubbleColor = [STPreferences selfBubbleColor];
	_selfBubbleView.authorTypeSelf = YES;
	_selfTextLabel.textColor = [STPreferences selfBubbleTextColor];
	[_selfBubbleView setNeedsDisplay];
    
	_otherBubbleView.bubbleColor = [STPreferences otherBubbleColor];
	_otherBubbleView.authorTypeSelf = NO;
	_otherTextLabel.textColor =  [STPreferences otherBubbleTextColor];
    
    [_backgroundTextButton setTitleColor:[STPreferences backgroundTextColor] forState:UIControlStateNormal];
	[_otherBubbleView setNeedsDisplay];
    
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)handleButton:(id)sender {
    
    
    //	BubbleColorsViewController *bcvc = [BubbleColorsViewController.alloc initWithNibName: @"BubbleColorsViewController" bundle: nil];
    //
    //	[self.navigationController pushViewController: bcvc animated: YES];

     InfColorPickerController* picker = [ InfColorPickerController colorPickerViewController ];
	if (sender == (id) _selfBubbleButton) {
		_actionBlock = ^(UIColor *color){
			[STPreferences setSelfBubbleColor:color];
            
		};
		picker.sourceColor = _selfBubbleView.bubbleColor;
	}
	else if (sender == (id) _otherBubbleButton) {
		_actionBlock = ^(UIColor *color){
            [STPreferences setOtherBubbleColor:color];
		};
		picker.sourceColor = _otherBubbleView.bubbleColor;
	}
	else if (sender == (id) _selfTextButton) {
		_actionBlock = ^(UIColor *color){
            [STPreferences setSelfBubbleTextColor:color];
		};
		picker.sourceColor = _selfTextLabel.textColor;
	}
	else if (sender == (id) _otherTextButton) {
		_actionBlock = ^(UIColor *color){
            [STPreferences setOtherBubbleTextColor:color];
			
		};
		picker.sourceColor = _otherTextLabel.textColor;
	}
  	else if (sender == (id) _backgroundTextButton) {
		_actionBlock = ^(UIColor *color){
            [STPreferences setBackgroundTextColor:color];
		};
		picker.sourceColor = _otherTextLabel.textColor;
        
        
	}
  
    
    
	picker.delegate = self;
	//[self.navigationController pushViewController: picker animated: YES];
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc]
									 initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
									 target: self
									 action: @selector(dismissModal)];
	
	picker.navigationItem.leftBarButtonItem = cancelButton;
    
	[self.navigationController pushViewController: picker animated: YES];
    
    //	[ picker presentModallyOverViewController: self ];
    
}
//------------------------------------------------------------------------------

- (void) colorPickerControllerDidFinish: (InfColorPickerController*) picker
{
	_actionBlock(picker.resultColor);
	[self setColors];
	[self.navigationController popViewControllerAnimated: YES];
}

//------------------------------------------------------------------------------
- (void) dismissModal {
	[self.navigationController popViewControllerAnimated: YES];
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
    
    [STPreferences setBackgroundPattern:[_fileNames objectAtIndex:_bpPageControl.currentPage]];
	[STAppDelegate applyAppearance];

//	if (app.isRunningiOS7) {
//        //		self.view.layer.contents = (id) App.sharedApp.background.CGImage;
//		self.view.backgroundColor = [UIColor colorWithPatternImage:App.sharedApp.background];
//	}
	
    
    //	[self.delegate updateViewAfterChanges];
	
}



@end
