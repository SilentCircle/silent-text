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
#import <Foundation/Foundation.h>

#import "S3DownloadOperation.h"
#import "S3DeleteOperation.h"
#import "AsyncSCloudOp.h"
#import "S3UploadSession.h"

@class STUser;
@class STLocalUser;
@class SCloudObject;
@class Siren;
@class STUser;


typedef void (^SCloudManagerCompletionBlock)(NSError *error, NSDictionary* infoDict);

extern NSString *const NOTIFICATION_SCLOUD_OPERATION;

extern NSString *const NOTIFICATION_SCLOUD_BROKER_REQUEST;
extern NSString *const NOTIFICATION_SCLOUD_BROKER_COMPLETE;

extern NSString *const NOTIFICATION_SCLOUD_UPLOAD_PROGRESS;
extern NSString *const NOTIFICATION_SCLOUD_UPLOAD_COMPLETE;
extern NSString *const NOTIFICATION_SCLOUD_UPLOAD_RETRY;
extern NSString *const NOTIFICATION_SCLOUD_UPLOAD_FAILED;

extern NSString *const NOTIFICATION_SCLOUD_DOWNLOAD_START;
extern NSString *const NOTIFICATION_SCLOUD_DOWNLOAD_PROGRESS;
extern NSString *const NOTIFICATION_SCLOUD_DOWNLOAD_COMPLETE;

extern NSString *const NOTIFICATION_SCLOUD_ENCRYPT_START;
extern NSString *const NOTIFICATION_SCLOUD_ENCRYPT_PROGRESS;
extern NSString *const NOTIFICATION_SCLOUD_ENCRYPT_COMPLETE;

extern NSString *const NOTIFICATION_SCLOUD_GPS_START;
extern NSString *const NOTIFICATION_SCLOUD_GPS_COMPLETE;


@interface SCloudManager : NSObject < AsyncSCloudOpDelegate,
                                      S3DownloadOperationDelegate,
                                      S3DeleteOperationDelegate,
                                      S3UploadSessionDelegate>

+ (SCloudManager *)sharedInstance;

- (NSDictionary *)statusForIdentfier:(id)identifier;

- (void)startUploadForLocalUser:(STLocalUser *)localUser
                         scloud:(SCloudObject *)scloud
                      burnDelay:(NSUInteger)burnDelay
                     identifier:(id)identifier
                completionBlock:(SCloudManagerCompletionBlock)completion;


- (void)startDownloadWithScloud:(SCloudObject*) scloud
                   fullDownload:(BOOL)fullDownload
                     identifier:(id)identifier
                completionBlock:(SCloudManagerCompletionBlock)completion;


- (void)startEncryptwithScloud:(SCloudObject *)scloud
                     withSiren:(Siren *)siren
                    fromUserID:(NSString *)userID
                conversationID:(NSString *)conID
                     messageID:(NSString *)messageID
               completionBlock:(SCloudManagerCompletionBlock)completeBlock;


// for GPS notifications
- (void)startGPSwithIdentfier:(id)identifier;
- (void)stopGPSwithIdentfier:(id)identifier;

@end
