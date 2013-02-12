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
//  SCloudManager.m
//  SilentText
//

#import <SystemConfiguration/SystemConfiguration.h>

#import "AppConstants.h"
#import "App.h"
#import "App+ApplicationDelegate.h"

#import "SCloudSRVResolver.h"

#import "AsyncSCloudOp.h"
#import "AsyncBrokerRequest.h"
#import "AsyncS3downloader.h"
#import "AsyncS3uploader.h"
#import "SCloudManager.h"
#include "SCloud.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

@interface SCloudManager ()

@property (nonatomic, retain)           NSOperationQueue * opQueue;

@property (nonatomic,strong, retain)    SCloudSRVResolver   *srvResolver;
@property (nonatomic)                   dispatch_queue_t    resolverQueue;
@property (nonatomic, retain)           NSURL               *brokerURL;

@end

@implementation SCloudManager
static NSString * OperationsChangedContext = @"OperationsChangedContext";



- (id)init
{
     
	if ((self = [super init]))
	{
          _opQueue = [[NSOperationQueue alloc] init];
        
        // Set to 1 to serialize operations. Comment out for parallel operations.
         [_opQueue setMaxConcurrentOperationCount:4];
        
        [_opQueue addObserver:self
                 forKeyPath:@"operations"
                    options:0
                    context:&OperationsChangedContext];

        _resolverQueue = dispatch_queue_create("broker.silentcircle.com", NULL);
  
    }
	return self;
}

- (void)dealloc
{
    [_opQueue removeObserver:self forKeyPath:@"operations"];
    _opQueue = NULL;
    dispatch_release(_resolverQueue);

}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == &OperationsChangedContext)
    {
        DDGLog(@"Queue size: %d", (int)[[_opQueue operations] count]);
    }
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

-(void) updateSrvCache
{
  
           
        _srvResolver = [[SCloudSRVResolver alloc] initWithdDelegate:self
                                                      delegateQueue:_resolverQueue
                                                      resolverQueue:NULL];

        [_srvResolver startWithSRVName:kSCloudBrokerSRVname timeout:30.0];
    
      
}

-(void) startUploadWithDelagate:(id)aDelegate
                         scloud:(SCloudObject*) scloud
                      burnDelay:(NSUInteger)burnDelay
                          force:(BOOL)force;
{
    NSError* error = NULL;
    
    if(!_brokerURL)
    {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:NSLS_COMMON_CONNECT_FAILED forKey:NSLocalizedDescriptionKey];
        
        error = [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorCannotConnectToHost userInfo:details];
        
    }
    
    if(_brokerURL && (force || ! scloud.inCloud) )
    {
        
        NSDate* shredDate  = (burnDelay == kShredAfterNever)?NULL:[NSDate.date dateByAddingTimeInterval: burnDelay];
        
        NSArray* segments = [SCloudObject segmentsFromLocatorString:scloud.locatorString
                                                          keyString:scloud.keyString
                                                            withError:&error];
         
        AsyncBrokerRequest * operation = [AsyncBrokerRequest.alloc initWithDelegate:self
                                                                          operation:kSCBrokerOperation_Upload
                                                                          brokerURL:_brokerURL
                                                                             scloud:scloud
                                                                           locators:segments
                                                                            dirPath:[App.sharedApp makeDirectory: kDirectoryMediaCache ]
                                                                          shredDate:shredDate
                                                                             object:aDelegate];
        
        
        [_opQueue addOperation:operation];
       
    }
    else
    {
        [aDelegate SCloudUploadDidStart:scloud ];
        [aDelegate SCloudUploadDidCompleteWithError:error scloud:scloud];
    }
 }


-(void) startDownloadWithDelagate:(id)aDelegate  scloud:(SCloudObject*) scloud;
{
      
      AsyncS3downloader * operation = [[AsyncS3downloader alloc  ]initWithDelegate:self
                                                                            scloud:scloud
                                                                     locatorString:NULL
                                                                          object:aDelegate ];
     [_opQueue addOperation:operation];
 }

-(void) startDeleteWithDelagate:(id)aDelegate
                         scloud:(SCloudObject*) scloud

{
    NSError* error = NULL;
    
    NSArray* segments = [SCloudObject segmentsFromLocatorString:scloud.locatorString
                                                      keyString:scloud.keyString
                                                      withError:&error];
   
    AsyncBrokerRequest * operation = [[AsyncBrokerRequest alloc  ]initWithDelegate:self
                                                                         operation:kSCBrokerOperation_Delete
                                                                         brokerURL:_brokerURL
                                                                            scloud:scloud
                                                                          locators:segments
                                                                           dirPath:NULL
                                                                         shredDate:NULL
                                                                            object:aDelegate ];

    [_opQueue addOperation:operation];
}

#pragma mark - SCloudSRVResolver methods

- (void)srvResolver:(SCloudSRVResolver *)sender didResolveRecords:(NSArray *)srvResults
{
    BOOL found = NO;
    
    if (sender != _srvResolver) return;
 	
    for(ScloudSRVRecord* srvRecord in srvResults)
    {
     
        NSString *srvHost = srvRecord.target;
		UInt16      srvPort = srvRecord.port;
        
        SCNetworkReachabilityRef reachabilityRef = SCNetworkReachabilityCreateWithName(NULL, [srvHost UTF8String]);
        if(reachabilityRef!= NULL)
        {
            
            SCNetworkReachabilityFlags flags;
            if (SCNetworkReachabilityGetFlags(reachabilityRef, &flags)
                && (flags & kSCNetworkReachabilityFlagsReachable))
            {
                _brokerURL = (srvPort == 443)
                    ? [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/broker/", srvHost]] 
                    : [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%d/broker/", srvHost, srvPort]];
                 found = TRUE;
            }
          
                
            CFRelease(reachabilityRef);
        }
        if(found) break;
    }

     
    if(!found)
       _brokerURL = [NSURL URLWithString:@"https://accounts.silentcircle.com/broker/"];
}


- (void)srvResolver:(SCloudSRVResolver *)sender didNotResolveDueToError:(NSError *)error
{
    if (sender != _srvResolver) return;
    
    _brokerURL = NULL;
    
}


#pragma mark - AsyncBrokerRequest methods
- (void)AsyncBrokerRequest:(AsyncBrokerRequest *)sender operationDidStart:(SCBrokerOperation)operation 

{
      if(sender.userObject)
      {
          if(operation == kSCBrokerOperation_Upload)
          {
              if([sender.userObject respondsToSelector:@selector(SCloudUploadDidStart:)])
              {
                  [sender.userObject SCloudUploadDidStart:sender.scloud];
              }
 
          }
          else if(operation == kSCBrokerOperation_Delete)
          {
              if([sender.userObject respondsToSelector:@selector(SCloudDeleteDidStart:)])
              {
                  [sender.userObject SCloudDeleteDidStart:sender.scloud];
              }
             
          }
       }
}

- (void)AsyncBrokerRequest:(AsyncBrokerRequest *)sender operationCompletedWithWithError:(NSError *)error
                 operation:(SCBrokerOperation)brokerOp
                totalBytes:(size_t)totalBytes
                      info:(NSDictionary*)info
{
    SCloudObject*  scloud = sender.scloud;
    
    if(error)
    {
        if(sender.userObject && [sender.userObject respondsToSelector:@selector(SCloudBrokerDidCompleteWithError:scloud:)])
        {
            [sender.userObject SCloudBrokerDidCompleteWithError:error scloud:sender.scloud];
        }
        
    }
    else
    {
       NSString* dirPath = [App.sharedApp makeDirectory: kDirectoryMediaCache ];
         
        if( sender.userObject
           && brokerOp == kSCBrokerOperation_Upload
           &&[sender.userObject respondsToSelector:@selector(SCloudUploading:totalBytes:)])
        {
            [sender.userObject SCloudUploading:sender.scloud totalBytes:[NSNumber numberWithLong:totalBytes]];
        }
        
        // since we spawn off so manty tasks we use the master op to track when they are done
        
        AsyncSCloudOp *masterOp = [AsyncSCloudOp.alloc initWithDelegate:self
                                                                 scloud:scloud
                                                   bytesExpectedToWrite:totalBytes
                                                                 object:sender.userObject];
         
        [info enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent
                                                 usingBlock:^(id key, id object, BOOL *stop) {
                 
                                                     NSOperation * operation = NULL;
                                                     NSString* locatorString = key;
                                                     NSString* signedURL = object;
                                                    
                                                    if(brokerOp == kSCBrokerOperation_Upload)
                                                     {
                                                         NSString *filePath = [dirPath stringByAppendingPathComponent:locatorString];
                                                         
                                                         operation= [[AsyncS3uploader alloc  ]initWithDelegate:self
                                                                                                 locatorString:locatorString
                                                                                                      filePath:filePath
                                                                                                     urlString:signedURL
                                                                                                        object:masterOp ];
                                                         [masterOp addDependency:operation];

                     
                                                     }
                                                     else if(brokerOp == kSCBrokerOperation_Delete)
                                                     {
                                                         operation= [[AsyncS3delete alloc  ]initWithDelegate:self
                                                                                               locatorString:locatorString
                                                                                                   urlString:signedURL
                                                                                                       object:sender.userObject ];
                                                         [masterOp addDependency:operation];

                     
                                                     }
                                                     if(operation)
                                                         [_opQueue addOperation:operation];
                                             }];
        
        
        [_opQueue addOperation:masterOp];
         
      }
}

#pragma mark - AsyncSCloudOp methods

- (void)AsyncSCloudOp:(AsyncSCloudOp *)sender opDidCompleteWithError:(NSError *)error 
{
    if(sender.uploading)
    {
        if( sender.userObject && [sender.userObject respondsToSelector:@selector(SCloudUploadDidCompleteWithError:scloud:)])
        {
            [sender.userObject SCloudUploadDidCompleteWithError:error scloud:sender.scloud];
        }
    }
    else
    {
        if(sender.userObject && [sender.userObject respondsToSelector:@selector(SCloudDownloadDidCompleteWithError:scloud:)])
        {
            [sender.userObject SCloudDownloadDidCompleteWithError:error scloud:sender.scloud];
        }

    }
}

- (void)AsyncSCloudOp:(AsyncSCloudOp *)sender uploadProgress:(float) progress   
{
    if(sender.uploading)
    {
        if(sender.userObject  && [sender.userObject respondsToSelector:@selector(SCloudUploadProgress:scloud:)])
        {
            [sender.userObject SCloudUploadProgress:progress scloud:sender.scloud];
        }
    }
    else
    {
        if(sender.userObject  && [sender.userObject respondsToSelector:@selector(SCloudDownloadProgress:scloud:)])
        {
            [sender.userObject SCloudDownloadProgress:progress scloud:sender.scloud];
        }
        
    }
    
}


#pragma mark - AsyncS3uploader methods

- (void)AsyncS3uploader:(AsyncS3uploader *)sender uploadDidStart:(NSString*)locatorString 
{
 
    DDGLog(@"upload start %@", locatorString);
    
    
}
- (void)AsyncS3uploader:(AsyncS3uploader *)sender uploadProgress:(NSNumber *)bytesWritten 
{
    if(sender.userObject  && [sender.userObject respondsToSelector:@selector(updateProgress:)])
    {
        [sender.userObject updateProgress:bytesWritten];
    }

}
- (void)AsyncS3uploader:(AsyncS3uploader *)sender uploadDidCompleteWithError:(NSError *)error 
{
    DDGLog(@"upload compelete %@", sender.locatorString);
    
    if(sender.userObject  && [sender.userObject respondsToSelector:@selector(didCompleteWithError:locatorString:)])
    {
        [sender.userObject didCompleteWithError:error locatorString:sender.locatorString];
    }

  }

#pragma mark - AsyncS3delete methods
 
- (void)AsyncS3delete:(AsyncS3delete *)sender deleteDidStart:(NSString*) locator
{
    if(sender.userObject && [sender.userObject respondsToSelector:@selector(SCloudDeleteDidStart:)])
    {
//        [sender.userObject SCloudDeleteDidStart: locator];
    }
    
}
- (void)AsyncS3delete:(AsyncS3delete *)sender deleteDidCompleteWithError:(NSError *)error
{
    
    if(sender.userObject  && [sender.userObject respondsToSelector:@selector(SCloudDeleteDidCompleteWithError:locator:)])
    {
//        [sender.userObject SCloudDeleteDidCompleteWithError:error locator:sender.locatorString];
    }
   
}

#pragma mark - AsyncS3downloader methods

- (void)AsyncS3downloader:(AsyncS3downloader *)sender downloadDidStart:(NSString*) locator
                 fileSize:(NSNumber*)fileSize
               statusCode:(NSInteger)statusCode
{
 
    
    DDGLog(@"download start %@", locator);
}
- (void)AsyncS3downloader:(AsyncS3downloader *)sender downloadProgress:(float) progress
{
 //   if(sender.userObject  && [sender.userObject respondsToSelector:@selector(SCloudDownloadProgress:locator:)])
    {
//        [sender.userObject SCloudDownloadProgress:progress  locator:sender.scloud.locatorString];
    }
    
}
- (void)AsyncS3downloader:(AsyncS3downloader *)sender downloadDidCompleteWithError:(NSError *)error
{
    if(error)
    {
        if(sender.scloud && sender.userObject && [sender.userObject respondsToSelector:@selector(SCloudDownloadDidCompleteWithError:scloud:)])
        {
            [sender.userObject SCloudDownloadDidCompleteWithError:error scloud:sender.scloud];
        }

    }
    else if(sender.scloud)
    {
        NSError*  err = NULL;
        
        NSArray* segments = [SCloudObject segmentsFromLocatorString:sender.scloud.locatorString
                                                          keyString:sender.scloud.keyString
                                                          withError:&err];
        
        
        NSMutableArray* segmentsToDownload = NSMutableArray.alloc.init;
        
        
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString* dirPath = [App.sharedApp makeDirectory: kDirectoryMediaCache ];
        
        
        for(NSString* segment in segments)
        {
            NSString*  filePath = [dirPath stringByAppendingPathComponent: segment];
            
            if(![sender.scloud.locatorString isEqualToString:segment] && ![fm fileExistsAtPath:filePath])
                [segmentsToDownload addObject:segment];
            
        }
        
        if(sender.userObject && [sender.userObject respondsToSelector:@selector(SCloudDownloadDidStart:segments:)])
        {
            [sender.userObject SCloudDownloadDidStart:sender.scloud segments:[segmentsToDownload count] ];
        }
        
        
        // since we spawn off so manty tasks we use the master op to track when they are done
        
        AsyncSCloudOp *masterOp = [AsyncSCloudOp.alloc initWithDelegate:self
                                                                 scloud:sender.scloud
                                                 segmentsExpectedToRead: [segmentsToDownload count]
                                                                 object:sender.userObject];
        
        
        [segmentsToDownload enumerateObjectsWithOptions:NSEnumerationConcurrent
                                             usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
         {
             NSOperation * operation = NULL;
             NSString* locatorString = obj;
             
             operation = [[AsyncS3downloader alloc  ]initWithDelegate:self
                                                               scloud:NULL
                                                        locatorString:locatorString
                                                               object:masterOp ];
             if(operation)
             {
                 [masterOp addDependency:operation];
                 [_opQueue addOperation:operation];
             }
         }];
        
        [_opQueue addOperation:masterOp];
    }
    else
    {
        DDGLog(@"segment download complete %@", sender.scloud.locatorString);
        
        if(sender.userObject  && [sender.userObject respondsToSelector:@selector(segmentDownload)])
        {
            [sender.userObject segmentDownload];
        }
    }
    
    
}

@end

