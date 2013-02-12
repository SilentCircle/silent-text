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
//  SCloudViewController.m
//  SilentText
//

#import <MobileCoreServices/MobileCoreServices.h>
#import <MediaPlayer/MediaPlayer.h>

#import <Social/Social.h>
#import <Accounts/Accounts.h>



#import "App.h"
#import "SCloudViewController.h"
#import "ConversationManager.h"
#import "Conversation.h"
#import "Missive.h"
#import "Siren.h"
#import "XMPPJID+AddressBook.h"
#import "SCloudObject.h"
#import "SCloudManager.h"
#import "MBProgressHUD.h"
#import "NSDate+SCDate.h"
#import "UIViewController+SCUtilities.h"
#import "ActivitySilentText.h"
#import "NSNumber+Filesize.h"
#import "GeoViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "NSURL+SCUtilities.h"
#import "UIImage+Thumbnail.h"
#import "App+ApplicationDelegate.h"

#import "MZAlertView.h"

// Apple needs to improve the share menu

#define USE_SHARE_MENU 0


@interface SCloudViewController ()
{
    
}

@property (strong, nonatomic) NSString* scloudKey;
@property (strong, nonatomic) NSString* scloudLocator;
@property (nonatomic) BOOL              canShareItem;

@property (strong, nonatomic)   SCloudObject* scloud;


@property (nonatomic, strong)   MBProgressHUD    *HUD;

@property (nonatomic, strong)   MPMoviePlayerController *moviePlayer;
@property (nonatomic, strong)   UIPopoverController *popover;
@property (nonatomic,strong)    QLPreviewController* previewController;
@property (nonatomic,strong)    UIDocumentInteractionController *uiDocController;
@end

@implementation SCloudViewController

@synthesize scloud          = _scloud;
@synthesize conversation    = _conversation;
@synthesize scloudKey       = _scloudKey;
@synthesize scloudLocator   = _scloudLocator;

#define kSaveModelSelector (@selector(saveImage:))


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.canShareItem  =  NO;
    }
    return self;
}


-(void) refreshScloudObject
{
    Missive *missive = [_missives objectAtIndex:_itemIndex];
    if(missive && missive.managedObjectContext)
    {
        Siren* siren =  missive.siren;
         _scloudLocator = siren.cloudLocator;
        _scloudKey =  siren.cloudKey;
        
        _canShareItem  = !siren.fyeo;
        _scloud = nil;
        _scloud = [[SCloudObject alloc]  initWithLocatorString:_scloudLocator
                                                     keyString:_scloudKey];
        _scloud.scloudDelegate  = self;
        
    }
    else
    {
        NSMutableArray* newMissives = [NSMutableArray arrayWithArray: _missives ];
        
        [newMissives removeObjectAtIndex:_itemIndex];
        _missives = newMissives;
    }
     
     [self.nextBackItem setEnabled:
     (_itemIndex < [_missives count] -1 ) forSegmentAtIndex : 1];
 
    [ self.nextBackItem setEnabled:
     _itemIndex > 0 forSegmentAtIndex : 0];
    
    self.mapButton.enabled = NO;
    self.saveButton.enabled = NO;
}

-(void) displayScloudImage
{

    UISwipeGestureRecognizer *swipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeDetected:)];
    [swipeRecognizer setDirection:(UISwipeGestureRecognizerDirectionLeft|  UISwipeGestureRecognizerDirectionRight)];
    [self.view addGestureRecognizer:swipeRecognizer];
    
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panDetected:)];
    [self.view addGestureRecognizer:panRecognizer];
    
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchDetected:)];
    [self.view addGestureRecognizer:pinchRecognizer];
    
    UIRotationGestureRecognizer *rotationRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotationDetected:)];
    [self.view addGestureRecognizer:rotationRecognizer];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDetected:)];
    tapRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapRecognizer];
    
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressDetected:)];
    [self.view addGestureRecognizer:longPressRecognizer];
    
    swipeRecognizer.delegate = self;
    panRecognizer.delegate = self;
    pinchRecognizer.delegate = self;
    rotationRecognizer.delegate = self;
    longPressRecognizer.delegate = self;
    
    // We don't need a delegate for the tapRecognizer
    
    [self.imageView setImage: [UIImage imageWithData:
                               [NSData dataWithContentsOfFile: _scloud.decryptedFilePath]]];
    
    self.imageView.hidden = NO;
    self.previewView.hidden = YES;
    self.errorView.hidden = YES;
    
}

-(void) displayScloudMovie
{
    
    NSURL *movieURL = [NSURL fileURLWithPath:_scloud.decryptedFilePath isDirectory:NO ];
    
    _moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:movieURL];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:_moviePlayer];
    
    _moviePlayer.controlStyle = MPMovieControlStyleDefault;
    _moviePlayer.shouldAutoplay = YES;
    
    [[_moviePlayer view] setFrame:[self.view bounds]]; // Frame must match parent view
    
    [self.view addSubview:[_moviePlayer view]];
    
    [_moviePlayer setFullscreen:YES animated:YES];
    //    [_moviePlayer play];
    
    self.imageView.hidden = NO;
    self.previewView.hidden = YES;

}


-(void) refreshView
{
    __block NSError * error;
    
    self.errorView.hidden = YES;
    if(!_scloud) return;
    
    _pageNumberItem.title = [NSString stringWithFormat:@"%d of %d", _itemIndex + 1, [_missives count]];
  
    
    if(self.scloud.isDownloading)
    {
        [self performSelector:@selector(refreshView) withObject:nil afterDelay:1];
        return;
    }
    if(!self.scloud.isCached)
    {
         self.navigationItem.rightBarButtonItem = nil;
        
        self.navigationItem.title =
        [NSString stringWithFormat:@"%@: %@", @"SCloud",[_scloudLocator substringFromIndex:[_scloudLocator length] - 8] ];
        
        // code here to download from cloud using _scloudLocator
        [self.imageView setImage: [UIImage imageNamed: @"reload"]];
        
        if(!_HUD)
        {
            _HUD = [[MBProgressHUD alloc] initWithView:self.view];
            [self.view addSubview:_HUD];
        }
        
        _HUD.mode = MBProgressHUDModeDeterminate;
        _HUD.labelText = [NSString stringWithFormat:@"downloading file"];
        [_HUD show:YES];
        
        [App.sharedApp.scloudManager startDownloadWithDelagate:self scloud:self.scloud ];
        return;
    }
    
    if(self.scloud.isCached)
    {
        if(!_HUD)
        {
            _HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
          //  _HUD = [[MBProgressHUD alloc] initWithView:self.view];
           // [self.view addSubview:_HUD];
        }
        
        _HUD.labelText = @"Decrypting";
        _HUD.mode = MBProgressHUDModeAnnularDeterminate;
        
        [_HUD showAnimated:YES whileExecutingBlock:^{
            
            [_scloud decryptCachedFileUsingKeyString: _scloudKey withError:&error];
            
        } completionBlock:^{
            
            [_HUD removeFromSuperview];
            _HUD = NULL;
            
            if(error == nil && _scloud.decryptedFilePath)
            {
                NSDictionary* metaData = _scloud.metaData;
                NSString* filename = [metaData valueForKey:kSCloudMetaData_FileName];
                
                NSDate*  mediaDate = [NSDate dateFromRfc3339String:  [metaData valueForKey:kSCloudMetaData_Date]];
                
                
                self.mapButton.enabled = (metaData
                                          && [metaData valueForKey:kSCloudMetaData_GPS] )?YES:NO;

                self.errorView.hidden = YES;
                
                if(_scloud.mediaType)
                {
                    NSString * mediaType = _scloud.mediaType;
                    NSString * mediaTypeString;
                         
                    self.saveButton.enabled = 
                    _canShareItem && (
                        ( UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeImage))
                    ||  ( UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeMovie)));
                    
                    
                    if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeImage))
                    {
                         mediaTypeString = NSLS_COMMON_IMAGE;
                    }
                    else if (UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeMovie))
                    {
                        mediaTypeString = NSLS_COMMON_MOVIE;
                    }
                    else if (UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeAudio))
                    {
                         mediaTypeString = NSLS_COMMON_AUDIO;
                    }
   
#define ST173_BUG 0
#if ST173_BUG
                    //*  fix for 2X issues on Ipad  ST-173 */
                    
                    NSString * device = [UIDevice currentDevice].model;
                    bool isiPad  = [device hasPrefix:@"iPad"];

                      if (UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeMovie)
                       && isiPad)
                    {
                        _previewController = NULL;
                   
      
                        UIImage* thumbnail = [[NSURL fileURLWithPath:_scloud.decryptedFilePath] movieImage];
    //];
                                
                          [self.imageView setImage: thumbnail];
                        
                        self.imageView.hidden = NO;
                        self.previewView.hidden = YES;
                        
                        
                        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                        action:@selector(movieTapped:)];
                        tapRecognizer.numberOfTapsRequired = 1;
                        [self.view addGestureRecognizer:tapRecognizer];

                  }
                      else 
                    
#endif
                          // lets try this by letting quicklooks handle the items first
                
                  if ([QLPreviewController canPreviewItem:[NSURL fileURLWithPath:_scloud.decryptedFilePath]])
                    {
                        // When user taps a row, create the preview controller
                        QLPreviewController *pvc = [[QLPreviewController alloc] init];
                        pvc.dataSource = self;
                        pvc.delegate = self;
                        pvc.currentPreviewItemIndex = 0;
                        
                        //set the frame from the parent view
                        CGFloat w= self.previewView.frame.size.width;
                        CGFloat h= self.previewView.frame.size.height;
                        pvc.view.frame = CGRectMake(0, 0,w, h);
                        
                        //save a reference to the preview controller in an ivar
                        self.previewController = pvc;
                        
                        //refresh the preview controller
                        self.imageView.hidden = YES;
                        self.previewView.hidden = NO;
                        [self.previewView  addSubview:pvc.view];

                        [pvc reloadData];
                        [[pvc view]setNeedsLayout];
                        [[pvc view ]setNeedsDisplay];
                        [pvc refreshCurrentPreviewItem];
                        
  
                    }
                    else if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeImage))
                    {
                        _previewController = NULL;
                        [self displayScloudImage];
                            
                    }
                     else if (UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeAudio))
                     {
                        _previewController = NULL;
                    }
                    else
                    {
                        _previewController = NULL;

                        [self.imageView setImage: [UIImage imageNamed: @"reload"]];

                        NSString* error_message = [NSString stringWithFormat:
                                                   @"This device has no method to display files of type \"%@\"",
                                                   [_scloud.decryptedFilePath pathExtension] ];
                        
                        
                        self.errorView.text = error_message;
                        self.errorView.font = [UIFont boldSystemFontOfSize: 18.0];
                        self.errorView.textColor = UIColor.whiteColor;

                        self.errorView.hidden = NO;
                        self.imageView.hidden = NO;
       
                    }
                      
                    self.navigationItem.title = filename  ?filename : [NSString stringWithFormat:@"%@: %@", mediaTypeString,
                                                                        [_scloudLocator substringToIndex:8]];
                    
                    // share is only available on IOS 6
#if USE_SHARE_MENU
                   if( NSClassFromString(@"UIActivityViewController"))
#else
                    if( NSClassFromString(@"UIDocumentInteractionController"))
#endif
                    {
                    
                        self.navigationItem.rightBarButtonItem =
                                            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                          target:self action:@selector(shareItem:)];
                        
                        [self.navigationItem.rightBarButtonItem setEnabled: self.canShareItem];
                    }
                }
            }
        }];
    }
}

#pragma mark - View management

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    [self.nextBackItem setSelectedSegmentIndex:UISegmentedControlNoSegment];
    self.nextBackItem.momentary = YES;
    
    self.navigationItem.backBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:[XMPPJID userNameWithJIDString: self.conversation.remoteJID]
                                     style:UIBarButtonItemStyleBordered
                                    target:nil
                                    action:nil];
     
    if(!_scloud)
    {
      [self refreshScloudObject];
        
    }
   
    [self refreshView];
    
}


- (void) viewDidAppear: (BOOL) animated {
    
    [App.sharedApp.conversationManager  removeDelegate: self];
    [App.sharedApp.conversationManager  addDelegate: self delegateQueue: dispatch_get_main_queue()];
    
    if(!_scloud)
    {
        [self refreshScloudObject];
        [self refreshView];
   }
 }

- (void) viewDidDisappear:(BOOL)animated  {
    
    _pageNumberItem = nil;
    _scloud = nil;
    _scloudKey = nil;
    _scloudLocator = nil;
    _moviePlayer = nil;
    _imageView = nil;
    _previewController = nil;
    
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    
    [App.sharedApp flushScloudCache];
     
    [nc removeObserver: self];
    
    [App.sharedApp.conversationManager setDelegate:nil];

    [super viewDidDisappear: animated];

}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}





// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    //return (interfaceOrientation == UIInterfaceOrientationPortrait);
    return YES;
}

- (void) moviePlayBackDidFinish:(NSNotification*)notification {
    
    MPMoviePlayerController *moviePlayer = [notification object];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:MPMoviePlayerPlaybackDidFinishNotification
                                                  object:moviePlayer];
    
    if ([moviePlayer
         respondsToSelector:@selector(setFullscreen:animated:)])
    {
 //        [_moviePlayer setFullscreen:NO animated:YES];
//        [moviePlayer.view removeFromSuperview];
    }

}


#pragma mark - Gesture Recognizers


- (void)movieTapped:(UITapGestureRecognizer *)tapRecognizer
{
    
    CGPoint pressLocation = [tapRecognizer locationInView:self.imageView];
   
}


- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}


- (void)swipeDetected:(UISwipeGestureRecognizer *)swipeRecognizer
{
    CGPoint location = [swipeRecognizer locationInView:self.view];
     
    if (swipeRecognizer.direction == UISwipeGestureRecognizerDirectionLeft) {
        
        if(_itemIndex < [_missives count] -1 )
            _itemIndex += 1;
     }
    else
    {
        if(_itemIndex > 0)
            _itemIndex -= 1;

    }
    
       [self refreshScloudObject];
    [self refreshView];
    
}

- (void)panDetected:(UIPanGestureRecognizer *)panRecognizer
{
    CGPoint translation = [panRecognizer translationInView:self.view];
    CGPoint imageViewPosition = self.imageView.center;
    imageViewPosition.x += translation.x;
    imageViewPosition.y += translation.y;
    
    self.imageView.center = imageViewPosition;
    [panRecognizer setTranslation:CGPointZero inView:self.view];
}

- (void)pinchDetected:(UIPinchGestureRecognizer *)pinchRecognizer
{
    CGFloat scale = pinchRecognizer.scale;
    self.imageView.transform = CGAffineTransformScale(self.imageView.transform, scale, scale);
    pinchRecognizer.scale = 1.0;
}

- (void)rotationDetected:(UIRotationGestureRecognizer *)rotationRecognizer
{
    CGFloat angle = rotationRecognizer.rotation;
    self.imageView.transform = CGAffineTransformRotate(self.imageView.transform, angle);
    rotationRecognizer.rotation = 0.0;
}




- (void)tapDetected:(UITapGestureRecognizer *)tapRecognizer
{
    [UIView animateWithDuration:0.25 animations:^{
        self.imageView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
        self.imageView.transform = CGAffineTransformIdentity;
    }];
}

- (void) longPressDetected: (UILongPressGestureRecognizer *) gestureRecognizer {
		
	if(gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        
            
			UIMenuController *menuController = [UIMenuController sharedMenuController];
            [self  becomeFirstResponder];
        
            CGPoint pressLocation = [gestureRecognizer locationInView:self.view];
              UIMenuController* menu = [UIMenuController sharedMenuController];
            
            UIMenuItem *menuItem = [[UIMenuItem alloc] initWithTitle:@"do something" action:@selector(doSomething:)];
        
            [menuController setMenuItems:[NSArray arrayWithObject:menuItem]];
      
            CGRect minRect;
            minRect.origin = pressLocation;
        
            [menu setTargetRect:minRect inView:self.view];
            [menuController setMenuVisible:YES animated:YES];
			
            [NSNotificationCenter.defaultCenter addObserver: self
                                                   selector: @selector(willHideMenuController:)
                                                       name: UIMenuControllerWillHideMenuNotification
                                                     object: nil];
            

        }
        

    
} // -longPress:


#pragma mark - UIMenuController methods


- (BOOL) canPerformAction: (SEL) selector withSender: (id) sender {
    
    if ( selector == @selector( copy: )  && self.imageView)
    {
       
        return YES;
    }
    if ( selector == @selector( doSomething: )  && self.imageView)
    {
        
        return YES;
    }

   	
    return NO;
    
} // -canPerformAction:withSender:


- (BOOL) canBecomeFirstResponder {
  	
    return YES;
    
} // -canBecomeFirstResponder




- (void) doSomething: (id) sender {
    
   	
    
} // -doSomething:

- (void) copy: (id) sender {
    
    if(self.imageView)
        [UIPasteboard generalPasteboard].image = self.imageView.image;
  	
     
} // -copy:


- (void) willHideMenuController: (NSNotification *) notification {
    
      
	[NSNotificationCenter.defaultCenter removeObserver: self
                                                  name: UIMenuControllerWillHideMenuNotification
                                                object: nil];
    
} // -willHideMenuController:


#pragma mark -
#pragma mark ConversationManager methods

- (void)conversationmanager:(ConversationManager *)sender didReceiveSirenFrom:(XMPPJID *)from siren:(Siren *)siren
{
    
    NSString *name = [from addressBookName];
    name = name && ![name isEqualToString: @""] ? name : [from user];
       
    if(siren.requestBurn)
    {
        [self displayMessageBannerFrom:name message:NSLS_COMMON_MESSAGE_REDACTED withIcon:[UIImage imageNamed:@"flame_btn"]];
        
    }
    else if(siren.message)
    {
        [self displayMessageBannerFrom:name message:siren.message withIcon:App.sharedApp.bannerImage];
        
    }
    
}


#pragma mark - SCloudManagerDelegate methods
- (void)SCloudBrokerDidCompleteWithError:(NSError *)error scloud:(SCloudObject*) scloud 
{
    if(error)
	{
		[self removeProgress];
		
		UIAlertView *alert = [[UIAlertView alloc]
							  initWithTitle: @"Upload failed"
							  message: error.localizedDescription
							  delegate: nil
							  cancelButtonTitle:@"OK"
							  otherButtonTitles:nil];
		[alert show];
		
	}
       
}

- (void)SCloudUploadDidStart:(SCloudObject*) scloud
{
 	
}


- (void)SCloudUploading:(SCloudObject*) scloud totalBytes:(NSNumber*)totalBytes;
{
    _HUD.labelText =  [NSString stringWithFormat:@"Uploading %@ file…", [totalBytes fileSizeString]];
    
    _HUD.mode = MBProgressHUDModeDeterminate;
    
}


- (void)SCloudUploadProgress:(float)progress scloud:(SCloudObject*) scloud
{
	//	[self progress: (progress*100) withMessage:locatorString];
//    NSLog(@"Progess %0.2f", progress);
	
	_HUD.progress = progress;
	
}


- (void)SCloudUploadDidCompleteWithError:(NSError *)error scloud:(SCloudObject*) scloud
{
    [_scloud refresh];
    
	if(error)
	{
		[self removeProgress];
		
		UIAlertView *alert = [[UIAlertView alloc]
							  initWithTitle: @"Upload failed"
							  message: error.localizedDescription
							  delegate: nil
							  cancelButtonTitle:@"OK"
							  otherButtonTitles:nil];
		[alert show];
		
	}
	else
	{
		
		_HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
		_HUD.mode = MBProgressHUDModeCustomView;
		_HUD.labelText = @"Completed";
		
		[self performSelector:@selector(removeProgress) withObject:NULL afterDelay:2.0];
		
	}
}


-(void) removeProgress
{
	
	[self.HUD removeFromSuperview];
	self.HUD = nil;
	
}


- (void)SCloudDownloadDidStart:(SCloudObject *)scloud  segments:(NSUInteger*)segments 
{
    if(segments > 0)
        _HUD.labelText = [NSString stringWithFormat:@"downloading %d parts", (unsigned int) segments];
}

- (void)SCloudDownloadProgress:(float)progress scloud:(SCloudObject *)scloud
{
    _HUD.progress = progress;
 
}

- (void)SCloudDownloadDidCompleteWithError:(NSError *)error scloud:(SCloudObject *)scloud
{
    
    if(!error)
    {
                
       _HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
        _HUD.mode = MBProgressHUDModeCustomView;
        _HUD.labelText = @"Downloaded";
        [self performSelector:@selector(removeProgress) withObject:NULL afterDelay:2.0];
        [self refreshView];
   
    }
    else
    {
		[self removeProgress];

        [[[UIAlertView alloc] initWithTitle:@"SCLOUD download failed"
                                    message:error.localizedDescription
                                   delegate:nil
                          cancelButtonTitle:NSLS_COMMON_OK
                          otherButtonTitles:nil] show];
    
    }
}


- (void)SCloudDeleteDidStart:(NSString*) locator
{
 
}

- (void)SCloudDeleteDidCompleteWithError:(NSError *)error locator:(NSString*)locatorString
{
    [_scloud refresh];
    
    if(!error)
    {
        _HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
        _HUD.mode = MBProgressHUDModeCustomView;
        _HUD.labelText = @"Deleted";
        [self performSelector:@selector(removeProgress) withObject:NULL afterDelay:2.0];
   }
    else
    {
        [self removeProgress];
        
        [[[UIAlertView alloc] initWithTitle:@"SCLOUD delete failed"
                                    message:error.localizedDescription
                                   delegate:nil
                          cancelButtonTitle:NSLS_COMMON_OK
                          otherButtonTitles:nil] show];
        
    }
}


#pragma mark -
#pragma mark SCloudObjectDelegate methods

- (void)scloudObject:(SCloudObject *)sender decryptingDidStart:(BOOL) foo
{

}

- (void)scloudObject:(SCloudObject *)sender decryptingProgress:(float) progress
{
   self.HUD.progress = progress;
}

- (void)scloudObject:(SCloudObject *)sender decryptingDidCompleteWithError:(NSError *)error
{
    
    if(error && sender
       && [error.domain isEqualToString: kSCErrorDomain]
       &&  error.code == kSCLError_ResourceUnavailable
       && sender.missingSegments
       && sender.missingSegments.count > 0)
    {
 
        [self performSelectorOnMainThread:@selector(downloadMissingParts) withObject:nil waitUntilDone:NO];
    }
        
 }


-(void)downloadMissingParts
{
   
    MZAlertView *alert = [[MZAlertView alloc] initWithTitle:@"Download missing parts"
                                                    message:@"Some parts of the file were missing, do you wish to download them now?"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"OK", nil];
    
    
    [alert setActionBlock: ^(NSInteger buttonPressed, NSString *alertText){
         if (buttonPressed == 0)
         {
             
             [self.navigationController popViewControllerAnimated:YES];
             
        }
        else if (buttonPressed == 1) {
            _HUD = NULL;

            _HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            
            _HUD.mode = MBProgressHUDModeDeterminate;
            _HUD.labelText = [NSString stringWithFormat:@"downloading missing parts"];
            [_HUD show:YES];
            
            [App.sharedApp.scloudManager startDownloadWithDelagate:self scloud:self.scloud ];
            
        } 
        
    }];
    [alert show];
    

}


- (void)scloudObject:(SCloudObject *)sender updatedInfo:(NSError *)error
{
    if( self.civ  &&  [self.civ superview])
        [self.civ updateInfo];
    
}

#pragma mark -
#pragma mark Action methods
 
-(IBAction) nextBackAction:(id) sender
{
    UISegmentedControl* control = sender;
     
    NSUInteger  item = [control selectedSegmentIndex];
   
    if(item == 0)
    {
        _itemIndex -= 1;
    } else if(item == 1)
    {
        _itemIndex += 1;
    }
    
    [self.civ hide];

    [self refreshScloudObject];
    [self refreshView];
   
}



-(IBAction) infoAction:(id) sender
{
    if ([self.civ superview]) {
		[self.civ fadeOut];
		return;
	}
	
	if (!self.civ)
		[[NSBundle mainBundle] loadNibNamed:@"SCloudInfoView" owner:self options:nil];
	self.civ.delegate = self;
    
 //   [_scloud refresh];

 	[self.civ unfurlOnView:self.view under:self.toolBar atPoint:CGPointMake(30., self.toolBar.frame.origin.y)];

}
- (IBAction)saveAction:(id)sender
{
    
    NSArray* SCmetaData = [NSArray arrayWithObjects:kSCloudMetaData_MediaType, kSCloudMetaData_FileName, kSCloudMetaData_FileSize, kSCloudMetaData_MediaType_Segment, kSCloudMetaData_Segments, nil];
    
    NSMutableDictionary* metaDict = [NSMutableDictionary dictionaryWithDictionary:_scloud.metaData];
    
    [metaDict removeObjectsForKeys: SCmetaData];
    
    if(!_HUD)
    {
        _HUD = [[MBProgressHUD alloc] initWithView:self.view];
        [self.view addSubview:_HUD];
    }
    
    _HUD.mode = MBProgressHUDModeIndeterminate;
    _HUD.labelText = [NSString stringWithFormat:@"saving"];
    [_HUD show:YES];
    
    ALAssetsLibrary* library = [[ALAssetsLibrary alloc] init];
    
     NSString * mediaType = _scloud.mediaType;

    if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeImage))
    {
    
        NSData *data = [NSData dataWithContentsOfFile:_scloud.decryptedFilePath ];
 
        [library writeImageDataToSavedPhotosAlbum:data
                                         metadata:metaDict
                                  completionBlock:^(NSURL *assetURL, NSError *error) {
                                      _HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
                                      _HUD.mode = MBProgressHUDModeCustomView;
                                      _HUD.labelText = @"Saved";
                                      [self performSelector:@selector(removeProgress) withObject:NULL afterDelay:2.0];
                                  }];
        
    }
    else if(UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeMovie))
    {
        NSURL * movieURL = [NSURL fileURLWithPath:_scloud.decryptedFilePath ];
        
        if([library videoAtPathIsCompatibleWithSavedPhotosAlbum:movieURL])
        {
            [library writeVideoAtPathToSavedPhotosAlbum:movieURL
                                      completionBlock:^(NSURL *assetURL, NSError *error) {
                                          _HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
                                          _HUD.mode = MBProgressHUDModeCustomView;
                                          _HUD.labelText = @"Saved";
                                          [self performSelector:@selector(removeProgress) withObject:NULL afterDelay:2.0];
                                      }];
        }
        else
        {
 //           _HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
            _HUD.mode = MBProgressHUDModeText;
            _HUD.labelText = @"Can Not Save Movie";
            [self performSelector:@selector(removeProgress) withObject:NULL afterDelay:2.0];
            
        }
        
    }
    

    
}

- (IBAction)mapAction:(id)sender
{
    
    NSDictionary* locInfo =  [_scloud.metaData valueForKey:kSCloudMetaData_GPS];
    
    NSString* datestring = [_scloud.metaData valueForKey:kSCloudMetaData_Date];
    NSDate* fileDate = datestring? [NSDate dateFromRfc3339String:datestring]:NULL;
    
    NSString* filename = [_scloud.metaData valueForKey:kSCloudMetaData_FileName];
    
    if(locInfo)
    {
        double latitude  =  [[locInfo valueForKey:@"Latitude"]doubleValue];
        double longitude  = [[locInfo valueForKey:@"Longitude"]doubleValue];
        double altitude  = [[locInfo valueForKey:@"Altitude"]doubleValue];
        NSString* LongitudeRef =  [locInfo valueForKey:@"LongitudeRef"];
        NSString* LatitudeRef =  [locInfo valueForKey:@"LatitudeRef"];
        
        if(!LongitudeRef || ![LongitudeRef isEqualToString:@"E"])
            longitude = - longitude;
        
        if(!LatitudeRef || ![LatitudeRef isEqualToString:@"N"])
            latitude = - latitude;
        
        CLLocationCoordinate2D theCoordinate;
        theCoordinate.latitude = latitude;
        theCoordinate.longitude = longitude;
        
        GeoViewController *geovc = [GeoViewController.alloc initWithNibName: @"GeoViewController" bundle: nil];
        
        [self.navigationController pushViewController: geovc animated: YES];
        [geovc setCoord: theCoordinate withName:filename andTime:fileDate andAltitude:altitude];
    }
    
	
}

- (IBAction) shareItem: (UIBarButtonItem *) sender {
    
#if USE_SHARE_MENU
    if (self.popover) {
        if ([self.popover isPopoverVisible]) {
            return;
        } else {
            [self.popover dismissPopoverAnimated:YES];
            self.popover = nil;
        }
    }
    
    ActivitySilentText *silentTextActivity = [[ActivitySilentText alloc] init];
    
    NSString *textItem = @"Sent with Silent Text https://itunes.apple.com/us/app/silent-text/id554312568";
    
    //   NSString *textToShare = @"Learn iOS6 Social Framework integration";
    
    UIImage *imageToShare  = NULL;
    
    if(_previewController)
    {
        if(_scloud.mediaType
           && (UTTypeConformsTo( (__bridge CFStringRef)  _scloud.mediaType, kUTTypeImage))
           && _scloud.decryptedFilePath)
            imageToShare = [UIImage imageWithData:[NSData dataWithContentsOfFile: _scloud.decryptedFilePath]];
        
    }
    else
        imageToShare = self.imageView.image;
    
    NSMutableArray *activityItems = [[NSMutableArray alloc]  initWithObjects:textItem,imageToShare, nil];
    if(activityItems.count == 0)
        return;
    
    
    Siren* siren = NULL;
    Missive *missive = [_missives objectAtIndex:_itemIndex];
    if(missive)
    {
        siren =  [missive.siren copy];
        [activityItems addObject: siren];
    }
    
    NSArray *applicationActivities = @[silentTextActivity];
    
    // screw Weibo
    NSArray *excludeActivities = @[UIActivityTypePostToWeibo];
    
    UIActivityViewController *activityController =  [[UIActivityViewController alloc] initWithActivityItems:activityItems
                                                                                      applicationActivities:applicationActivities];
    
    activityController.excludedActivityTypes = excludeActivities;
    activityController.completionHandler =
    ^(NSString *activityType, BOOL completed)
    {
//        NSLog(@" activityType: %@", activityType);
//        NSLog(@" completed: %i", completed);
    };
    
    
    // switch for iPhone and iPad.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.popover = [[UIPopoverController alloc] initWithContentViewController:activityController];
        self.popover.delegate = self;
        [self.popover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        [self presentViewController:activityController animated:YES completion:^{
        }];
    }
#else
    
    NSURL* fileURL =  [NSURL fileURLWithPath:_scloud.decryptedFilePath];
    
    if (!_uiDocController)
    {
        _uiDocController =  [UIDocumentInteractionController interactionControllerWithURL: fileURL];
    }
    else
    {
        _uiDocController.URL = fileURL;
    }

    
     _uiDocController.UTI = _scloud.mediaType;
    
    if(! [_uiDocController presentOptionsMenuFromBarButtonItem:sender animated:YES])
    {
    }
    
#endif
    
}



#pragma mark - SCloudInfoViewDelegate methods  

- (SCloudObject*) getSCloudObject;
{
    return _scloud;
     
}

- (UINavigationController*) getNavController
{
    return self.navigationController;
}

- (void) deleteFromCloud: (SCloudObject*)scloud
{
     MZAlertView *alert = [[MZAlertView alloc] initWithTitle:@"Delete from Scloud"
                                                    message:@"this will permanently delete the file from the Scloud server"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"OK", nil];
    

     [alert setActionBlock: ^(NSInteger buttonPressed, NSString *alertText){
        if (buttonPressed == 1) {
            
            if(!_HUD)
            {
                _HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
                //_HUD = [[MBProgressHUD alloc] initWithView:self.view];
               // [self.view addSubview:_HUD];
            }
           _HUD.mode = MBProgressHUDModeIndeterminate;
            _HUD.labelText = [NSString stringWithFormat:@"Deleting file" ];
            [_HUD show:YES];

            [App.sharedApp.scloudManager startDeleteWithDelagate:self scloud:self.scloud];
       
        }
        
    }];
    [alert show];

}
- (void) reloadToCloud: (SCloudObject*)scloud
{
     uint32_t burnDelay = kShredAfterNever;
    
      
  //  BOOL shouldBurn = BitTst(_conversation.flags, kConversationFLag_Burn);
    if(_conversation.burnFlag && (_conversation.shredAfter  >0 ))
    {
        burnDelay  = _conversation.shredAfter;
    }
    
    MZAlertView *alert = [[MZAlertView alloc] initWithTitle:@"Reload to Scloud"
                                                    message:@"Reload the file back to the Scloud server"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"OK", nil];
    
    
    [alert setActionBlock: ^(NSInteger buttonPressed, NSString *alertText){
        if (buttonPressed == 1) {
            
            if(!_HUD)
            {
                _HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
                //_HUD = [[MBProgressHUD alloc] initWithView:self.view];
                //[self.view addSubview:_HUD];
            }
           _HUD.mode = MBProgressHUDModeIndeterminate;
            _HUD.labelText = [NSString stringWithFormat:@"Uploading file" ];
            [_HUD show:YES];
            
            [App.sharedApp.scloudManager startUploadWithDelagate:self
                                                          scloud:scloud
                                                       burnDelay:burnDelay
                                                           force:YES];
            
        }
        
    }];
    [alert show];
  
    
    
}


 #pragma mark - Preview Controller

/*---------------------------------------------------------------------------
 *
 *--------------------------------------------------------------------------*/
- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller
{
	return 1;
}

/*---------------------------------------------------------------------------
 *
 *--------------------------------------------------------------------------*/
- (id <QLPreviewItem>)previewController: (QLPreviewController *)controller previewItemAtIndex:(NSInteger)index
{
	    
	return [NSURL fileURLWithPath:_scloud.decryptedFilePath];
}




 
@end
