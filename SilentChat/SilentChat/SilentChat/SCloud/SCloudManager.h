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
//  SCloudManager.h
//  SilentText
// 

#import <Foundation/Foundation.h>
#import "SCloudObject.h"
#import "AsyncBrokerRequest.h"
#import "AsyncS3downloader.h"
#import "AsyncS3uploader.h"
#import "AsyncS3delete.h"
#import "AsyncSCloudOp.h"
#import "SCloudSRVResolver.h"

 
@protocol SCloudManagerDelegate;


@interface SCloudManager : NSObject <
                            AsyncSCloudOpDelegate,
                            AsyncS3downloaderDelegate,
                            AsyncS3uploaderDelegate,
                            AsyncS3deleteDelegate,
                            SCloudSRVResolverDelegate>

-(void) updateSrvCache;

-(void) startDownloadWithDelagate:(id)aDelegate scloud:(SCloudObject*) scloud;

-(void) startUploadWithDelagate:(id)aDelegate
                              scloud:(SCloudObject*) scloud
                           burnDelay:(NSUInteger)burnDelay
                               force:(BOOL)force;

-(void) startDeleteWithDelagate:(id)aDelegate
                         scloud:(SCloudObject*) scloud;

@end

@protocol SCloudManagerDelegate <NSObject>
@required

@optional

- (void)SCloudBrokerDidCompleteWithError:(NSError *)error scloud:(SCloudObject*) scloud ;

- (void)SCloudUploadDidStart:(SCloudObject*) scloud;
- (void)SCloudUploading:(SCloudObject*) scloud totalBytes:(NSNumber*)totalBytes;

- (void)SCloudUploadProgress:(float)progress scloud:(SCloudObject*) scloud;
- (void)SCloudUploadDidCompleteWithError:(NSError *)error scloud:(SCloudObject*) scloud;

- (void)SCloudDeleteDidStart:(SCloudObject*) scloud;
- (void)SCloudDeleteDidCompleteWithError:(NSError *)error scloud:(SCloudObject*) scloud;

- (void)SCloudDownloadDidStart:(SCloudObject*) scloud  segments:(NSUInteger)segments;
- (void)SCloudDownloadProgress:(float)progress scloud:(SCloudObject*) scloud;;
- (void)SCloudDownloadDidCompleteWithError:(NSError *)error scloud:(SCloudObject*) scloud;




@end
