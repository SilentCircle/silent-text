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
//  ImportViewController.m
//  SilentText
//

#import "ImportViewController.h"
#import "App.h"
#import "GeoTracking.h"

#import "Siren.h"
#import "SCloud.h"
#import "SCloudManager.h"

#import "Missive.h"
#import "ConversationManager.h"
#import "ConversationViewController.h"
#import "ChatViewController.h"
#import "XMPPServer.h"
#import "XMPPMessage+SilentCircle.h"
#import "CLLocation+NSDictionary.h"
#import "NSDate+SCDate.h"
#import "UIImage+Thumbnail.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "NSNumber+Filesize.h"
#import "MZAlertView.h"
#import "NSURL+SCUtilities.h"


@interface ImportViewController ()

@property (nonatomic, readwrite) NSURL* url;
@property  (nonatomic,retain)   STFwdViewController* fwc;

@property  (nonatomic,retain)   UIImage*        thumbnail;
@property (nonatomic, strong)   MBProgressHUD*  HUD;
@property  (nonatomic,retain)   Siren*          siren;
@property  (nonatomic,retain)   XMPPJID*        remoteJID;
 
@end

@implementation ImportViewController
 


- (id)initWithNibNameAndURL:(NSString *)nib bundle:(NSBundle *)bundle url:(NSURL*)url
{
    
	if (self = [super initWithNibName:nib bundle:bundle])
    {
        _url = url;
        _siren = NULL;
        
        
        //    dont forget to delete it
        

  	}
	return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



-(void) viewWillAppear: (BOOL) animated {
    
    [super viewWillAppear: animated];
    
    self.navigationItem.title = NSLocalizedString(@"Forward File", @"Forward File");
  
  if(!self.fwc)
  {
    
    _thumbnail = [_url thumbNail];
        
    self.fwc = [[STFwdViewController alloc] initWithImage:_thumbnail];
    self.fwc.delegate = self;
    self.fwc.prompt =
        [NSString stringWithFormat: @"Select a silent text user to forward %@ to.",
                                                [[_url path] lastPathComponent]];
    
    
    [self.view addSubview:self.fwc.view];
  }
    
  //    [self.navigationController pushViewController:fwc animated:NO];


} // -viewWillAppear:


-(void) viewWillDisappear:(BOOL)animated
{
    self.fwc = NULL;
    _siren = NULL;
    _remoteJID = NULL;
    _HUD = NULL;
    
}

#pragma mark - Utility

-(void) removeProgress
{
	
	[self.HUD removeFromSuperview];
	self.HUD = nil;
	
}

-( void) closeDialog
{
    [self dismissModalViewControllerAnimated:YES];
}

-(void) sendMessage
{
    if(_siren)
    {
        XMPPMessage *xmppMessage = [_siren chatMessageToJID: _remoteJID];
        
        if (xmppMessage) {
            
            App *app = App.sharedApp;
            
            Conversation *conversation = [app.conversationManager conversationForLocalJid: app.currentJID
                                                                                remoteJid: _remoteJID];
            
            
            Missive *missive = [Missive insertMissiveForXMPPMessage: xmppMessage
                                             inManagedObjectContext: conversation.managedObjectContext
                                                      withEncryptor: conversation.encryptor];
            conversation.date = missive.date;
            missive.conversation   = conversation; // Trigger the insert into the table view.
            
            
            
            XMPPStream * xmppStream = app.xmppServer.xmppStream;
            [xmppStream sendElement: xmppMessage];
        }
    }
    
    _siren = NULL;
    _remoteJID = NULL;

}


#pragma mark - STFwdViewDelegate methods

- (void) sendSCloudObject: (SCloudObject*) scloud toJid:(XMPPJID *)remoteJID
{
    App *app = App.sharedApp;
    uint32_t burnDelay = kShredAfterNever;
    
    _remoteJID = remoteJID;
    
    Conversation *conversation = [app.conversationManager conversationForLocalJid: app.currentJID
                                                                        remoteJid: remoteJID];
    
    _siren = Siren.new;
    _siren.conversationID =  conversation.scppID;
    _siren.mediaType = scloud.mediaType;
    _siren.thumbnail  = UIImageJPEGRepresentation(scloud.thumbnail, 0.4);
    
    _siren.cloudKey =  scloud.keyString;
    _siren.cloudLocator =  scloud.locatorString;
    
    _siren.fyeo           =  conversation.isFyeo;
    
     if(conversation.burnFlag && (conversation.shredAfter  >0 ))
    {
        burnDelay  = conversation.shredAfter;
        _siren.shredAfter =  burnDelay;
    }
    
    if(app.geoTracking.allowTracking
       && app.geoTracking.isTracking
       && conversation.isTracking)
    {
        // insert tracking info
        CLLocation* location = app.geoTracking.location;
        if(location)
        {
            NSString* locString = [location JSONString];
            _siren.location   =  locString;
        }
    }
    
    self.HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.HUD.mode = MBProgressHUDModeIndeterminate;
    self.HUD.labelText = @"Starting Upload…";
    
    [app.scloudManager startUploadWithDelagate:self
                                        scloud:scloud
                                     burnDelay:_siren.shredAfter
                                         force:NO ];
    
        
}
- (void) selectedJid:(XMPPJID *)remoteJID
{
    __block SCloudObject    *scloud     = NULL;
    __block NSError         *error      = NULL;
    __block NSData          *mediaData    = NULL;
    __block NSMutableDictionary *mediaInfo = NULL;
  
    if(remoteJID)
    {
        _HUD = [[MBProgressHUD alloc] initWithView:self.view];
        [self.view addSubview:_HUD];
        _HUD.mode = MBProgressHUDModeAnnularDeterminate;

        mediaInfo = [[NSMutableDictionary alloc] init];
        
        NSString *localizedName = NULL;
        [_url getResourceValue:&localizedName forKey:NSURLLocalizedNameKey error:NULL];
        [mediaInfo setObject:localizedName forKey: kSCloudMetaData_FileName];
   
        NSString *mediaType = NULL;
        [_url getResourceValue:&mediaType forKey:NSURLTypeIdentifierKey error:NULL];
        [mediaInfo setObject:mediaType forKey: kSCloudMetaData_MediaType];

        NSDate* mediaDate = NULL;
        [_url getResourceValue:&mediaDate forKey:NSURLCreationDateKey error:NULL];
        [mediaInfo setObject: [mediaDate rfc3339String] forKey:kSCloudMetaData_Date];
        
          
        mediaData = [NSData dataWithContentsOfURL:_url options:NSDataReadingMappedIfSafe error:&error];
        
        
        scloud =  [[SCloudObject alloc] initWithDelegate:self
                                                    data:mediaData
                                                metaData:mediaInfo
                                               mediaType:mediaType
                                           contextString:App.sharedApp.currentJID.bare];
        scloud.thumbnail = _thumbnail;
     
        _HUD.labelText = [NSString stringWithFormat:NSLS_COMMON_PREPARING, [[_url path] lastPathComponent]];
        
        [_HUD showAnimated:YES whileExecutingBlock:^{
            
            if(mediaData && mediaInfo); // force to retain data and info
            
            [scloud saveToCacheWithError:&error];
        } completionBlock:^{
            [_HUD removeFromSuperview];
               
            if(error)
            {
                scloud = NULL;
            }
            else
            {
                [self sendSCloudObject: scloud toJid:remoteJID];
            }
        }];
   
    }
    else
    {
        [self dismissModalViewControllerAnimated:YES];

    }

     
  
}

#pragma mark -
#pragma mark SCloudManagerDelegate methods


- (void)SCloudBrokerDidCompleteWithError:(NSError *)error scloud:(SCloudObject*) scloud
{
    if(error)
	{
        [self SCloudUploadDidCompleteWithError: error scloud:scloud];
        
    }
    
}

- (void)SCloudUploadDidStart:(SCloudObject*) scloud
{
 	
}

- (void)SCloudUploading:(SCloudObject*) scloud totalBytes:(NSNumber*)totalBytes
{
    _HUD.labelText =  [NSString stringWithFormat:@"Uploading %@…", [totalBytes fileSizeString]];
    
    _HUD.mode = MBProgressHUDModeDeterminate;
    
}

- (void)SCloudUploadProgress:(float)progress scloud:(SCloudObject*) scloud
{
 	_HUD.progress = progress;
	
}


- (void)SCloudUploadDidCompleteWithError:(NSError *)error scloud:(SCloudObject*) scloud
{
   	if(error)
	{
		[self removeProgress];
           
		MZAlertView *alert = [[MZAlertView alloc]
							  initWithTitle: @"Upload failed"
							  message: error.localizedDescription
							  delegate: self
							  cancelButtonTitle:@"Cancel"
							  otherButtonTitles:@"Try Again", @"Send Anyways", nil];
        
		[alert show];
		
        [alert setActionBlock: ^(NSInteger buttonPressed, NSString *alertText){
            switch(buttonPressed)
            {
                case 1:
                {
                    
                    [App.sharedApp.scloudManager startUploadWithDelagate:self
                                                        scloud:scloud
                                                     burnDelay:_siren.shredAfter
                                                         force:NO];
  
                }
                break;
                
                case 2:
                {
                    [self sendMessage];
                    [self closeDialog];
                }
                    break;
                    
                default:
                    [self closeDialog];
             }
            
        }];
        [alert show];
        
	}
	else
	{
 		_HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
		_HUD.mode = MBProgressHUDModeCustomView;
		_HUD.labelText = @"Completed";
		
        [self sendMessage];

		[self performSelector:@selector(removeProgress) withObject:NULL afterDelay:2.0];
        [self performSelector:@selector(closeDialog) withObject:NULL afterDelay:2.1];
       
    }
}

#pragma mark -
#pragma mark SCloudObjectDelegate methods

- (void)scloudObject:(SCloudObject *)sender calculatingKeysDidStart:(NSString*) mediaType
{
}

- (void)scloudObject:(SCloudObject *)sender calculatingKeysProgress:(float) progress
{
    self.HUD.progress = progress;
}

- (void)scloudObject:(SCloudObject *)sender calculatingKeysDidCompleteWithError:(NSError *)error
{
}

- (void)scloudObject:(SCloudObject *)sender encryptingDidStart:(NSString*) mediaType
{
//    _HUD.mode = MBProgressHUDModeIndeterminate;
//    _HUD.labelText = @"Encrypting";
    
}

- (void)scloudObject:(SCloudObject *)sender encryptingProgress:(float) progress
{
    
}
- (void)scloudObject:(SCloudObject *)sender encryptingDidCompleteWithError:(NSError *)error
{
    [[NSFileManager defaultManager] removeItemAtURL:self.url error:NULL];
 
}




@end
