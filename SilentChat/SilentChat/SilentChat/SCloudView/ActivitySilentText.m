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
//  ActivitySilentText.m
//  SilentText
//

#import "App.h"
#import "ActivitySilentText.h"
#import "Siren.h"
#import "Missive.h"
#import "ConversationManager.h"
#import "XMPPServer.h"
#import "XMPPMessage+SilentCircle.h"

@interface ActivitySilentText ()

@property (nonatomic, strong) STFwdViewController *fwdController;
@property (nonatomic, strong) UIImage *shareImage;
@property (nonatomic, strong) Siren *siren;
@end

@implementation ActivitySilentText


- (NSString *)activityType {
    return @"UIActivityTypePostToInstagram";
}

- (NSString *)activityTitle {
    return @"Silent Text";
}

- (UIImage *)activityImage {
    
      return [UIImage imageNamed:@"silentextactivity.png"];
}


- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    
    for (UIActivityItemProvider *item in activityItems) {
        if ([item isKindOfClass:[Siren class]])
        {
         // required the Siren object
            return YES;
         }
        
    }
       return NO;
}


- (void)prepareWithActivityItems:(NSArray *)activityItems {
    for (id item in activityItems) {
        if ([item isKindOfClass:[UIImage class]])
        {
            self.shareImage  = item;
        }
        else if ([item isKindOfClass:[Siren class]])
        {
            self.siren = item;
        }
        
        else if ([item isKindOfClass:[NSString class]])
        {

        }
        else if ([item isKindOfClass:[NSURL class]]) {
        
        }
//        else NSLog(@"Unknown item type %@", item);
    }
}


- (UIViewController *)activityViewController {
    
    
    if (!self.fwdController)
    {
        self.fwdController = [[STFwdViewController alloc] initWithImage:self.shareImage];
        self.fwdController.delegate = self;
        self.fwdController.prompt = @"Select a silent text user to forward this image to.";

       }
     return self.fwdController;
    
}

- (void) selectedJid:(XMPPJID *)remoteJID 
{
    if(remoteJID)
    {
        App *app = App.sharedApp;
        Conversation *conversation = [app.conversationManager conversationForLocalJid: app.currentJID
                                                                            remoteJid: remoteJID];
        
        XMPPMessage *xmppMessage = [self.siren chatMessageToJID: remoteJID];
        
        Missive *missive = [Missive insertMissiveForXMPPMessage: xmppMessage
                                         inManagedObjectContext: conversation.managedObjectContext
                                                  withEncryptor: conversation.encryptor];
        conversation.date = missive.date;
        missive.conversation   = conversation; // Trigger the insert into the table view.

        XMPPStream * xmppStream = app.xmppServer.xmppStream;
        [xmppStream sendElement: xmppMessage];
    }
    
    [self activityDidFinish:YES];
    
}

- (void)performActivity {
    
      [self activityDidFinish:NO];
    
}


-(void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application {
    [self activityDidFinish:YES];
}


@end
