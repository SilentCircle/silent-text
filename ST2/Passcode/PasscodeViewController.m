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
//  PasscodeViewController.m
//  SilentText
//

#import <QuartzCore/QuartzCore.h>

#import "AppDelegate.h"
#import "AppConstants.h"
#import "AppTheme.h"
#import "PasscodeViewController.h"
#import "SCPasscodeManager.h"
#import "SCTPasswordTextfield.h"
#import "SilentTextStrings.h"
#import "STLogging.h"


// Log levels: off, error, warn, info, verbose
#if DEBUG && eric_turner
static const int ddLogLevel = LOG_FLAG_INFO | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@interface PasscodeViewController ()

@property (weak, nonatomic) IBOutlet UILabel *prompt;
@property (weak, nonatomic) IBOutlet UIButton *failPrompt;
@property (weak, nonatomic) IBOutlet UIButton *recoveryButton;
@property (weak, nonatomic) IBOutlet UIButton *biometricButton;
@property (weak, nonatomic) IBOutlet UIView *containerView;

#define     kSwipeDown  (@selector(swipeDown:))
- (IBAction) swipeDown: (UISwipeGestureRecognizer *) gestureRecognizer;

#define     kDoneEnteringText  (@selector(userDoneEnteringText:))
-(IBAction)userDoneEnteringText:(id)sender;


@property (nonatomic, readwrite) PasscodeViewControllerMode mode;
@property (nonatomic, readwrite) NSString* passwordCandidate;
@property (nonatomic, readwrite) UIBarButtonItem *nextButton;

@property (nonatomic) int verify_state;

@end;

@implementation PasscodeViewController

@synthesize textfield = _textfield;
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
						   initWithTitle:NSLocalizedString(@"Next", @"Next")
						   style:UIBarButtonItemStylePlain
						   target:self
						   action:kDoneEnteringText];
			
			self.navigationItem.rightBarButtonItem = _nextButton;
			_nextButton.enabled = NO;
			
			[[NSNotificationCenter defaultCenter] addObserver:self 
                                                     selector:@selector(textChanged:) 
                                                         name:@"UITextFieldTextDidChangeNotification" 
                                                       object:_textfield];
			
			
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
    DDLogAutoTrace();
    
    _recoveryButton.hidden =  YES;
    _biometricButton.hidden = YES;
    
	if(_mode != PasscodeViewControllerModeVerify)
	{
		self.navigationItem.leftBarButtonItem =  STAppDelegate.settingsButton;
	}
	
	[super viewDidLoad];
        
	_textfield.rightViewMode = UITextFieldViewModeAlways;
	CGRect frame = CGRectMake(0, 0, 30, 30);
	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	button.frame = frame;
//	self.view.tintColor = [UIApplication sharedApplication].delegate.window.tintColor;
	self.view.tintColor = [UIColor colorWithRed:1.0 green:0.55 blue:0.03 alpha:1.0] ;
	_containerView.layer.cornerRadius = 10.0;    
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
			
			self.navigationItem.title = NSLocalizedString(@"Set Passcode", @"Set Passcode");
			self.navigationItem.rightBarButtonItem = _nextButton;
			
			switch(_verify_state)
		{
			case 1:
				_prompt.text = NSLocalizedString(@"Enter a passcode", @"Enter a passcode");
				_passwordCandidate = @"";
				_textfield.returnKeyType = UIReturnKeyNext;
				break;
			case 2:
				_prompt.text = NSLocalizedString(@"Re-enter your new passcode", @"Re-enter your new passcode");
				_textfield.returnKeyType = UIReturnKeyDone;
				break;
			default:;
		}
			break;
			
			
		case PasscodeViewControllerModeChange:
			
			self.navigationItem.title = NSLocalizedString(@"Change Passcode", @"Change Passcode");
			self.navigationItem.rightBarButtonItem = _nextButton;
			
			switch(_verify_state)
		{
			case 0:
				_prompt.text = NSLocalizedString(@"Enter your old passcode", @"Enter your old passcode");
				_passwordCandidate = @"";
				break;
			case 1:
				_prompt.text = NSLocalizedString(@"Enter your new passcode", @"Enter your new passcode");
				_passwordCandidate = @"";
				break;
			case 2:
				_prompt.text = NSLocalizedString(@"Re-enter your new passcode", @"Re-enter your new passcode");
				break;
			default:;
		}
			break;
			
		case PasscodeViewControllerModeRemove:
			_prompt.text = NSLocalizedString(@"Enter Your Passcode", @"Enter Your Passcode");
			self.navigationItem.title = NSLocalizedString(@"Turn Off Passcode", @"Turn Off Passcode");
			self.navigationItem.rightBarButtonItem = NULL;
			_textfield.returnKeyType = UIReturnKeyDone;
			break;
			
		case PasscodeViewControllerModeVerify:
			_prompt.text = NSLocalizedString(@"Enter Your Passcode", @"Enter Your Passcode");
			self.navigationItem.title = NSLS_COMMON_SILENT_TEXT;
			self.navigationItem.rightBarButtonItem = NULL;
			_textfield.returnKeyType = UIReturnKeyDone;
            
            BOOL hasRecoveryKey =  [STAppDelegate.passcodeManager recoveryKeyBlob] != NULL;
            _recoveryButton.hidden = !hasRecoveryKey;
            
            BOOL hasBioMetric =  [STAppDelegate.passcodeManager hasBioMetricKey] ;
            _biometricButton.hidden = !hasBioMetric;
            
			break;
	}
}

- (void) viewWillAppear: (BOOL) animated {
    DDLogAutoTrace();
    
	_textfield.text = @"";
	_passwordCandidate = @"";
	_failPrompt.hidden =  YES;
	_failPrompt.titleLabel.textAlignment = NSTextAlignmentCenter;
	_failPrompt.titleLabel.adjustsFontSizeToFitWidth = TRUE;
	[self refreshMode];

	[super viewWillAppear: animated];    
}

- (void) viewDidAppear: (BOOL) animated {
    DDLogAutoTrace();
	[super viewDidAppear: animated];
        
	[_textfield becomeFirstResponder];    
}

- (void)viewWillDisappear:(BOOL)animated {
    DDLogAutoTrace();
    [super viewWillDisappear:animated];

    [self prepareForBackground];
}

- (void) viewDidDisappear: (BOOL) animated {
    
	// erase old passphrase
	
	[super viewDidDisappear: animated];	
}

#pragma mark - Backgrounding Methods

- (void)prepareForBackground {
    [_textfield resignFirstResponder];
    _textfield.text = nil;    
}

#pragma mark - Textfield Methods

- (IBAction)editingDidEnd:(id)sender {
	[self userDoneEnteringText:sender];
}
- (IBAction)didEndOnExit:(id)sender {
	[self userDoneEnteringText:sender];
}

-(IBAction)userDoneEnteringText:(id)sender
{
	BOOL       dismiss = FALSE;
    NSError* error = NULL;
    
	if(_textfield.text.length == 0)
		return;
	
	switch(_verify_state)
	{
		case 0:
			if([STAppDelegate.passcodeManager unlockWithPassphrase: _textfield.text
                                                  passPhraseSource: kPassPhraseSource_Keyboard
                                                             error: &error] )
			{
				if(_mode == PasscodeViewControllerModeChange)
				{
					_verify_state+=1;
					_textfield.text = @"";
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
					[STAppDelegate.passcodeManager removePassphraseWithPassPhraseSource:kPassPhraseSource_Unknown
                                                                                  error:&error];
					dismiss = YES;
					break;
				}
			}
			else
			{
				NSInteger   failedTries = STAppDelegate.passcodeManager.failedTries;
				
    
				/*  there is no way to dismiss on app verify */
				if(failedTries >= MAX_TRIES
				   && (_mode != PasscodeViewControllerModeVerify))
				{
					dismiss = YES;
				}
				else
				{
					_failPrompt.titleLabel.text =
					[NSString stringWithFormat:@"%d %@ %@", (int) failedTries,
					 NSLocalizedString(@"failed passcode", @"failed passcode"),
					 failedTries > 1 ?
					 NSLocalizedString(@"attempts", @"attempts") : NSLocalizedString(@"attempt", @"attempt")];
					[_failPrompt setHidden:NO];
					_textfield.text = @"";
				}
			}
			break;
			
		case 1:
			_passwordCandidate = _textfield.text;
			_textfield.text = @"";
			_verify_state+=1;
			[self refreshMode];
			[_textfield becomeFirstResponder];
			break;
			
		case 2:
		case 3:
			if([_passwordCandidate isEqualToString: _textfield.text])
			{
				[STAppDelegate.passcodeManager updatePassphrase: _textfield.text  error:&error];
				_textfield.text = @"";
				_passwordCandidate = @"";
				dismiss = TRUE;
			}
			else
			{
				if(_verify_state == 2)
				{
					[_failPrompt setHidden:NO];
					_failPrompt.titleLabel.text = NSLocalizedString(@"Passcodes did not match. Try again.", @"Passcodes did not match. Try again.");
					_verify_state = 3;
					
				}
				else
				{
					[_failPrompt setHidden:YES];
					_failPrompt.titleLabel.text = @"";
					_verify_state = 1;
					
				}
				_textfield.text = @"";
				[self refreshMode];
			}
			
			break;
		default:;
	}
	
	
	if(dismiss)
	{
		if(_mode == PasscodeViewControllerModeVerify)
		{
             
			if( !_isRootView )
            {
                [self dismissViewControllerAnimated:NO completion:NULL];
            }
            // When presented by AppDelegate _isRootView is set YES
            // dismiss keyboard when verified
            else {
                [_textfield resignFirstResponder];
            }			
        }
		else
		{
			[_textfield resignFirstResponder];
//			if (_actionBlock)
//				_actionBlock();
 		}
	}
	
}

- (void)textChanged:(NSNotification *)note {
	
	if(_nextButton)
		_nextButton.enabled = _textfield.text.length > 0;
}


#pragma mark - UIInterfaceOrientation methods.

- (NSUInteger)supportedInterfaceOrientations
{
	if (AppConstants.isIPad)
		return UIInterfaceOrientationMaskAll; // (interfaceOrientation == UIInterfaceOrientationPortrait);
	else
		return UIInterfaceOrientationMaskPortrait;
	
}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
//	
//	if (AppConstants.isIPad)
//		return YES; // (interfaceOrientation == UIInterfaceOrientationPortrait);
//	else
//		return NO;
//}



#pragma mark - UISwipeGestureRecognizer methods.

- (IBAction) swipeDown: (UISwipeGestureRecognizer *) gestureRecognizer {
	
	if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
		
		[_textfield resignFirstResponder];
	}
	
} // -longPress:


#pragma mark - recovery

- (IBAction)recoveryHit:(id)sender
{
    SCRecoveryKeyScannerController* rsc  = [[SCRecoveryKeyScannerController alloc] initWithDelegate:self];
    rsc.isModal = YES;
    
    [self presentViewController:rsc animated:NO completion: NULL];
    
}


- (IBAction)biometricHit:(id)sender
{
    NSError * error = NULL;
    
    if( [STAppDelegate.passcodeManager unlockWithBiometricKeyWithPrompt:NSLocalizedString(@"Unlock with Touch ID", nil)
                                                              error:&error])
    {
        
        if( !_isRootView )
        {
            [self dismissViewControllerAnimated:NO completion:NULL];
            
        }
        
    }
    else
    {
       
    }
    
}


#pragma mark - SCRecoveryKeyScannerController methods

//- (void)scRecoveryKeyScannerController:(SCRecoveryKeyScannerController *)sender dismissRecoveryKeyScannerView:(NSError*)error
//{
//    [self dismissViewControllerAnimated:NO completion:NULL];
//}

- (BOOL)scRecoveryKeyScannerController:(SCRecoveryKeyScannerController *)sender
                            didScanKey:(NSString*)recoveryKey
                               keyHash:(NSString*)recoveryKeyHash
{
    NSError         *error  = NULL;
    BOOL success     = NO;
    
    NSDictionary* dict = [STAppDelegate.passcodeManager recoveryKeyDictionary ];
    if(dict)
    {
   
        NSString* keyHash = [ dict objectForKey:@"keyHash"];
        
        if([keyHash isEqualToString:recoveryKeyHash])
        {
            
            [STAppDelegate.passcodeManager unlockStorageBlobWithPassphase: recoveryKey
                                                                  passPhraseSource: kPassPhraseSource_Recovery
                                                                   error: &error];
            
            if(!error)
                success = YES;
            
        }
    }
    return success;
}

- (void)scRecoveryKeyScannerController:(SCRecoveryKeyScannerController *)sender
                         unLockWithKey:(NSString*)recoveryKey
                               keyHash:(NSString*)recoveryKeyHash
{
    
    NSError         *error  = NULL;
    BOOL success     = NO;
    
    NSDictionary* dict = [STAppDelegate.passcodeManager recoveryKeyDictionary ];
    if(dict)
    {
        
        NSString* keyHash = [ dict objectForKey:@"keyHash"];
        
        if([keyHash isEqualToString:recoveryKeyHash])
        {
            
            [STAppDelegate.passcodeManager unlockWithPassphrase: recoveryKey
                                                         passPhraseSource: kPassPhraseSource_Recovery
                                                                    error: &error];
            
            if(!error)
                success = YES;
            
        }
    }

    if(success)
    {
        if( !_isRootView )
        {
            [self dismissViewControllerAnimated:NO completion:NULL];
            
        }
    
    }
 
}


- (void)scRecoveryKeyScannerController:(SCRecoveryKeyScannerController *)sender dismissRecovery:(NSError*)error
{
        [self dismissViewControllerAnimated:YES completion:nil];
  
}



@end
