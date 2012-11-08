/*
Copyright © 2012, Silent Circle
All rights reserved.

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
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "App.h"
#import "SCPasscodeManager.h"
#import "PasscodeViewController.h"

#import <QuartzCore/QuartzCore.h>

@interface PasscodeViewController ()

@property (nonatomic, readwrite) PasscodeViewControllerMode mode;
@property (nonatomic, readwrite) NSString* passwordCandidate;
@property (nonatomic, readwrite) UIBarButtonItem *nextButton;

@property (nonatomic) int verify_state;

@end;

@implementation PasscodeViewController


@synthesize textView = _textView;
@synthesize prompt = _prompt;
@synthesize failPrompt = _failPrompt;
@synthesize nextButton = _nextButton;
@synthesize mode = _mode;
@synthesize verify_state = _verify_state;
@synthesize passwordCandidate = _passwordCandidate;
 


#define MAX_TRIES 4

- (id)initWithNibName:(NSString *)nib bundle:(NSBundle *)bundle mode:(PasscodeViewControllerMode)mode
{    
    
	if (self = [super initWithNibName:nib bundle:bundle])
    {
        _mode = mode;
        _verify_state = (mode == PasscodeViewControllerModeCreate)?1:0;
        _passwordCandidate = @"";
        
        if(mode != PasscodeViewControllerModeVerify)
        {
            _nextButton = [[UIBarButtonItem alloc]
                           initWithTitle:@"Next"
                           style:UIBarButtonItemStyleBordered
                           target:self
                           action:kDoneEnteringText];
            
            self.navigationItem.rightBarButtonItem = _nextButton;
            _nextButton.enabled = NO;
             
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textChanged:) name:@"UITextFieldTextDidChangeNotification" object:_textView];
            
 
        }
        else
            _nextButton = NULL;
       
  	}
	return self;
}

- (void)dealloc {
     
    [[NSNotificationCenter defaultCenter] removeObserver: self];

  }


- (void)viewDidLoad
{
    [super viewDidLoad];
   
     
}

- (void)viewDidUnload
{
    _passwordCandidate = @"";
    [super viewDidUnload];
}

- (void) refreshMode
{
     
    
    switch(_mode)
    {
        case PasscodeViewControllerModeCreate:
            
            self.navigationItem.title = @"Set Passcode";
            self.navigationItem.rightBarButtonItem = _nextButton;
            
            switch(_verify_state)
            {
                case 1:
                    _prompt.text = @"Enter a passcode";
                    _passwordCandidate = @"";
                    break;
                case 2:
                    _prompt.text = @"Re-enter your new passcode";
                    break;
                default:;
            }
            break;
     
                 
        case PasscodeViewControllerModeChange:
            
            self.navigationItem.title = @"Change Passcode";
            self.navigationItem.rightBarButtonItem = _nextButton;
         
            switch(_verify_state)
            {
                case 0:
                    _prompt.text = @"Enter your old passcode";
                    _passwordCandidate = @"";
                    break;
                case 1:
                    _prompt.text = @"Enter your new passcode";
                    _passwordCandidate = @"";
                    break;
                case 2:
                    _prompt.text = @"Re-enter your new passcode";
                    break;
                default:;
            }
            break;
            
        case PasscodeViewControllerModeRemove:
            _prompt.text = @"Enter your passcode";
            self.navigationItem.title = @"Turn Off Passcode";
            self.navigationItem.rightBarButtonItem = NULL;
            break;
            
        case PasscodeViewControllerModeVerify:
            _prompt.text = @"Enter your passcode";
            self.navigationItem.title = NSLS_COMMON_SILENT_TEXT;
            self.navigationItem.rightBarButtonItem = NULL;
            break;
    }
}

- (void) viewWillAppear: (BOOL) animated {
    
    _textView.text = @"";
    _passwordCandidate = @"";
    _failPrompt.hidden =  YES;
    _failPrompt.titleLabel.textAlignment = UITextAlignmentCenter;
    _failPrompt.titleLabel.adjustsFontSizeToFitWidth = TRUE;
    [self refreshMode];
    
    [super viewWillAppear: animated];
    

}

- (void) viewDidAppear: (BOOL) animated {
    
    [super viewDidAppear: animated];
    [_textView becomeFirstResponder];
    
} // -viewDidAppear:

- (void) viewDidDisappear: (BOOL) animated {
    
 // erase old passphrase
    
	[super viewDidDisappear: animated];
    
} // -viewDidDisappear:


-(IBAction)userDoneEnteringText:(id)sender
{
    App         *app    = App.sharedApp;
    BOOL       dismiss = FALSE;
    NSError     *error = NULL;
    if(_textView.text.length == 0)
        return;
      
    switch(_verify_state)
    {
        case 0:
            if( [app.passcodeManager unlockWithPassphrase: _textView.text error:&error] )
            {
                if(_mode == PasscodeViewControllerModeChange)
                {
                    _verify_state+=1;
                    _textView.text = @"";
                    [_failPrompt setHidden:YES];
                    [self refreshMode];
                   break;
                }
                else if(_mode == PasscodeViewControllerModeVerify)
                {
                    dismiss = YES; 
                }
                else if(_mode == PasscodeViewControllerModeRemove)
                {
                    [app.passcodeManager removePassphraseWithError:&error];
                    dismiss = YES;
                    break;
                }
            }
            else
            {
                NSInteger   failedTries = app.passcodeManager.failedTries;
                
                /*  there is no way to dismiss on app verify */
                if(failedTries >= MAX_TRIES
                   && (_mode != PasscodeViewControllerModeVerify))
                {
                         dismiss = YES;
                }
                else
                {
                    _failPrompt.titleLabel.text =
                    [NSString stringWithFormat:@"%d failed passscode attempt%s",
                     failedTries, failedTries > 1?"s":""];
                    [_failPrompt setHidden:NO];
                    _textView.text = @"";
                }
            }
            break;
            
        case 1:
            _passwordCandidate = _textView.text;
            _textView.text = @"";
            _verify_state+=1;
            [self refreshMode];
            break;
            
        case 2:
        case 3:
            if([_passwordCandidate isEqualToString: _textView.text ])
               {
                   [app.passcodeManager updatePassphraseKey: _textView.text error:&error];
                   _textView.text = @"";
                    _passwordCandidate = @"";
                   dismiss = TRUE;
                }
               else
               {
                   if(_verify_state == 2)
                   {
                       [_failPrompt setHidden:NO];
                       _failPrompt.titleLabel.text = @"Passcodes did not match, Try again.";
                       _verify_state = 3;
                       
                   }
                   else
                   {
                       [_failPrompt setHidden:YES];
                       _failPrompt.titleLabel.text = @"";
                       _verify_state = 1;
                       
                   }
                    _textView.text = @"";
                   [self refreshMode];
                }
            
             break;
        default:;
    }
    
           
    if(dismiss)
    {
         if(_mode == PasscodeViewControllerModeVerify)
         {
            [self dismissModalViewControllerAnimated:YES]; 
         }
        else
        {
            [_textView resignFirstResponder];
            [self.navigationController popViewControllerAnimated:NO];
           
        }
    }
     
}

#pragma mark - Textfield customization methods.

- (void)textChanged:(NSNotification *)note {
    
    if(_nextButton)
        _nextButton.enabled = _textView.text.length > 0;
}


#pragma mark - UIInterfaceOrientation methods.


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}



#pragma mark - UISwipeGestureRecognizer methods.

- (IBAction) swipeDown: (UISwipeGestureRecognizer *) gestureRecognizer {

	if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        
        [_textView resignFirstResponder];
	}
    
} // -longPress:

 
@end
