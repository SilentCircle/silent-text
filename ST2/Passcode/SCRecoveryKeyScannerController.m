//
//  SCRecoveryKeyScannerController.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 8/19/14.
//  Copyright (c) 2014 Silent Circle LLC. All rights reserved.
//

#import "SCRecoveryKeyScannerController.h"
#import "AppConstants.h"
#import "STSoundManager.h"
#import "AppDelegate.h"
#import "SCPasscodeManager.h"
/////////////////
/*
 Copyright 2013 Scott Logic Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */


@interface SCShapeView : UIView

@property (nonatomic, strong) NSArray *corners;

@end

@interface SCShapeView () {
    CAShapeLayer *_outline;
}
@end

@implementation SCShapeView


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        _outline = [CAShapeLayer new];
        _outline.strokeColor = [[[UIColor redColor] colorWithAlphaComponent:0.8] CGColor];
        _outline.lineWidth = 3.0;
        _outline.fillColor = [[UIColor clearColor] CGColor];
        [self.layer addSublayer:_outline];
    }
    return self;
}

- (void)setCorners:(NSArray *)corners
{
    if(corners != _corners) {
        _corners = corners;
        _outline.path = [[self createPathFromPoints:corners] CGPath];
    }
}

- (UIBezierPath *)createPathFromPoints:(NSArray *)points
{
    UIBezierPath *path = [UIBezierPath new];
    // Start at the first corner
    [path moveToPoint:[[points firstObject] CGPointValue]];
    
    // Now draw lines around the corners
    for (NSUInteger i = 1; i < [points count]; i++) {
        [path addLineToPoint:[points[i] CGPointValue]];
    }
    
    // And join it back to the first corner
    [path addLineToPoint:[[points firstObject] CGPointValue]];
    
    return path;
}

@end



////////////////////////////


@interface SCRecoveryKeyScannerController ()

@property (weak, nonatomic) IBOutlet UIView *containerView;

@property (weak, nonatomic) IBOutlet UIView *viewPreview;
@property (weak, nonatomic) IBOutlet UILabel *lblStatus;

@property (nonatomic, weak) IBOutlet    UIButton* cancelButton;

@property (nonatomic) BOOL isReading;


@property (nonatomic,assign)    id <SCRecoveryKeyScannerControllerDelegate> delegate;

@end

@implementation SCRecoveryKeyScannerController
{
    AVCaptureSession *captureSession;
    AVCaptureVideoPreviewLayer *videoPreviewLayer;
    NSString*       _qrString;
    
    NSDictionary*   _passCodeDict;
    SCShapeView *   _boundingBox;
    NSTimer *       _boxHideTimer;
    
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}



- (id)initWithDelegate: (id)aDelegate
{
	if ((self = [super initWithNibName:@"SCRecoveryKeyScannerController" bundle:nil]))
	{
        
        _delegate = aDelegate;
        
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
	self.navigationItem.title = NSLocalizedString(@"Recovery Key", @"Recovery Key");
	
    self.edgesForExtendedLayout=UIRectEdgeNone;
	self.extendedLayoutIncludesOpaqueBars=NO;
  
    self.view.tintColor = [UIColor colorWithRed:1.0 green:0.55 blue:0.03 alpha:1.0] ;

    _containerView.layer.cornerRadius = 10.0;

    _cancelButton.hidden = ! (_isModal || AppConstants.isIPhone);
    
}

- (void)viewDidAppear:(BOOL)animated
{
 	[super viewDidAppear:animated];
	
    [self startReading];
    
 }


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)cancelButtonTapped:(id)sender
{
    _isReading = NO;
 
    [self dismissViewControllerAnimated:YES completion:nil];

//    
//    if (self.isModal && AppConstants.isIPhone)
//    {
//        [self dismissViewControllerAnimated:YES completion:nil];
//    }
//    else if ([self.delegate respondsToSelector:@selector(scRecoveryKeyScannerController:dismissRecovery:)])
//    {
//            [self.delegate scRecoveryKeyScannerController:self dismissRecovery:NULL];
//    }

 }


#pragma mark - QR bar reading code

- (void)startReading {
    NSError *error;
    
    _passCodeDict = NULL;
    _isReading  = YES;

    // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video
    // as the media type parameter.
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // Get an instance of the AVCaptureDeviceInput class using the previous device object.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    if (!input)
    {
        [self dismissViewControllerAnimated:YES  completion:NULL];
      
         [STAppDelegate showAlertWithTitle:@"Can Not Scan Key" message:error.localizedDescription];

        
        return;
      }
    
 
    // Initialize the captureSession object.
    captureSession = [[AVCaptureSession alloc] init];
    // Set the input device on the capture session.
    [captureSession addInput:input];
    
    
    // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [captureSession addOutput:captureMetadataOutput];
    
    // Create a new serial dispatch queue.
//    dispatch_queue_t dispatchQueue;
//    dispatchQueue = dispatch_queue_create("myQueue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    
    // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
    videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [videoPreviewLayer setFrame:_viewPreview.layer.bounds];
    [_viewPreview.layer addSublayer:videoPreviewLayer];
    
  
    // Add the view to draw the bounding box for the UIView
    _boundingBox = [[SCShapeView alloc] initWithFrame:self.view.bounds];
    _boundingBox.backgroundColor = [UIColor clearColor];
    _boundingBox.hidden = YES;
    [self.view addSubview:_boundingBox];
  
    
    // Start video capture.
    [captureSession startRunning];

    [_lblStatus setText:@"Scanning for QR Code..."];
    
 }


-(void)stopReading{
    // Stop video capture and make the capture session object nil.
    [captureSession stopRunning];
    captureSession = nil;
    
    // Remove the video preview layer from the viewPreview view's layer.
    [videoPreviewLayer removeFromSuperlayer];
}


-(BOOL) unlockWithPassCodeInfo:(NSDictionary*)info
{
    BOOL result = NO;
    
    NSString* passCode = [info objectForKey:@"passCode"];
    NSString* keyHash = [info objectForKey:@"keyHash"];
 
    if (passCode.length
        && keyHash.length
        &&[self.delegate respondsToSelector:@selector(scRecoveryKeyScannerController:didScanKey:keyHash:)])
    {
       result = [self.delegate scRecoveryKeyScannerController:self didScanKey:passCode keyHash:keyHash];
    }
   
    return result;
    
}

- (void)foundQRcode:(id)sender
{
    // Hide the box and remove the decoded text
    _boundingBox.hidden = YES;
    _lblStatus.text = @"";
   
    if(_passCodeDict)
    {
        [self stopReading];
        
        NSString* passCode = [_passCodeDict objectForKey:@"passCode"];
        NSString* keyHash = [_passCodeDict objectForKey:@"keyHash"];
        
        if(self.isInPopover)
        {
            if ([self.delegate respondsToSelector:@selector(scRecoveryKeyScannerController:dismissRecovery:)])
            {
                [self.delegate scRecoveryKeyScannerController:self dismissRecovery:NULL];
            }
            if ([self.delegate respondsToSelector:@selector(scRecoveryKeyScannerController:unLockWithKey:keyHash:)])
            {
                [self.delegate scRecoveryKeyScannerController:self unLockWithKey:passCode keyHash:keyHash];
            }
            _passCodeDict = NULL;

        }
        else
        {
            [self dismissViewControllerAnimated:NO completion:^{
                
                if ([self.delegate respondsToSelector:@selector(scRecoveryKeyScannerController:unLockWithKey:keyHash:)])
                {
                    [self.delegate scRecoveryKeyScannerController:self unLockWithKey:passCode keyHash:keyHash];
                }
                
                _passCodeDict = NULL;
            }];
 
        }
      }
 }

- (void)startOverlayHideTimer
{
    // Cancel it if we're already running
    if(_boxHideTimer) {
        [_boxHideTimer invalidate];
    }
    
    // Restart it to hide the overlay when it fires
    _boxHideTimer = [NSTimer scheduledTimerWithTimeInterval:0.4
                                                     target:self
                                                   selector:@selector(foundQRcode:)
                                                   userInfo:nil
                                                    repeats:NO];
}


- (NSArray *)translatePoints:(NSArray *)points fromView:(UIView *)fromView toView:(UIView *)toView
{
    NSMutableArray *translatedPoints = [NSMutableArray new];
    
    // The points are provided in a dictionary with keys X and Y
    for (NSDictionary *point in points) {
        // Let's turn them into CGPoints
        CGPoint pointValue = CGPointMake([point[@"X"] floatValue], [point[@"Y"] floatValue]);
        // Now translate from one view to the other
        CGPoint translatedPoint = [fromView convertPoint:pointValue toView:toView];
        // Box them up and add to the array
        [translatedPoints addObject:[NSValue valueWithCGPoint:translatedPoint]];
    }
    
    return [translatedPoints copy];
}


#pragma mark - AVCaptureMetadataOutputObjectsDelegate method implementation

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects
      fromConnection:(AVCaptureConnection *)connection
{
    
    for (AVMetadataObject *metadata in metadataObjects)
    {
      if ([metadata.type isEqualToString:AVMetadataObjectTypeQRCode])
      {
          
          // Transform the meta-data coordinates to screen coords
          AVMetadataMachineReadableCodeObject *transformed
                        = (AVMetadataMachineReadableCodeObject *)[videoPreviewLayer transformedMetadataObjectForMetadataObject:metadata];
        
          // Update the frame on the _boundingBox view, and show it
          _boundingBox.frame = transformed.bounds;
          _boundingBox.hidden = NO;
          
          // Now convert the corners array into CGPoints in the coordinate system
          //  of the bounding box itself
          NSArray *translatedCorners = [self translatePoints:transformed.corners
                                                    fromView:self.viewPreview
                                                      toView:_boundingBox];
          
          // Set the corners array
          _boundingBox.corners = translatedCorners;
          
          
          // Start the timer which will hide the overlay
          [self startOverlayHideTimer];
          
          
          // only do this once
          if(_isReading)
          {
              NSDictionary* dict = [SCPasscodeManager recoveryKeyComponentsFromCode:transformed.stringValue];
              if([self unlockWithPassCodeInfo:dict])
              {
                  _isReading = NO;
                  
                  // Update the view with the decoded text
                  _lblStatus.text = @"key found";
                  
                  // remember the passcode
                  _passCodeDict  = dict;
                  
                  // play beep sound
                  [[STSoundManager sharedInstance] playBeepSound];
                  
                  // stop capture
                  [captureSession stopRunning];
                  
              }
              else
              {
                  _lblStatus.text = @"these are not the droids I am looking for..";
                  
              }
              
          }
       }
     }
 
}

@end
