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
//  ViewController.m
//  SCcrypto optest
//
//  Created by Vinnie Moscaritolo on 10/22/14.
//
//

#import "OptestViewController.h"

@interface OptestViewController ()

@property (nonatomic, weak) IBOutlet UITextView *myTextView;

@end

@implementation OptestViewController


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self.navigationController setNavigationBarHidden:NO animated:NO];

    if (self.navigationController.navigationBar.isTranslucent)
        [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    self.navigationItem.title = NSLocalizedString(@"SCcrypto Optest", @"SCcrypto Optest");

    self.navigationItem.leftBarButtonItem =
		  [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Test", @"Test")
                                           style:UIBarButtonItemStylePlain
                                          target:self
                                          action:@selector(testButtonTapped:)];

     [self clearContent];
}



- (void) viewWillAppear:(BOOL)animated
{
    
}

 
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)testButtonTapped:(id)sender
{
    [self clearContent];
};


-(void)updateContent:(NSString *)content {
    
    CGPoint pt = _myTextView.contentOffset;
    
    //write text
    _myTextView.text = [NSString stringWithFormat:@"%@%@",_myTextView.text,content];
    
    //tell view to scroll if necessary
    [_myTextView setContentOffset:pt animated:NO];
    [_myTextView scrollRangeToVisible:NSMakeRange(_myTextView.text.length, 0)];
    
}


-(void)clearContent {
    [_myTextView setText:@""];
}  


@end
