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
//  STSCloud.h
//  ST2
//
//  Created by Vinnie Moscaritolo on 10/8/13.
//

#import "STDatabaseObject.h"

@interface STSCloud : STDatabaseObject

@property (nonatomic, strong, readonly) NSString * uuid;
@property (nonatomic, strong, readonly) NSString * keyString;
@property (nonatomic, strong, readonly) NSString * userId;

@property (nonatomic, strong, readonly) NSString     * mediaType;
@property (nonatomic, strong, readonly) NSDictionary * metaData;
@property (nonatomic, strong, readonly) NSArray      * segments;
@property (nonatomic, strong, readonly) UIImage      * lowRezThumbnail;

@property (nonatomic, strong, readonly) NSDate       * timestamp;

@property (nonatomic, readonly)         BOOL           isOwnedbyMe;
@property (nonatomic)                   BOOL           dontExpire;
@property (nonatomic, getter = isFyeo)  BOOL           fyeo; // For Your Eyes Only. I.e. no copying text to the clipboard.


@property (nonatomic, strong)           NSString     * displayname;
@property (nonatomic, strong)           NSDate       * unCacheDate;
@property (nonatomic, strong)           UIImage      * preview;    // used for vcards etc

// dynamic properties
@property (nonatomic, strong)           UIImage      * thumbnail;
@property (nonatomic, strong, readonly) NSURL        * thumbnailURL;

- (id)initWithUUID:(NSString *)uuid
         keyString:(NSString *)keyString
            userId:(NSString *)userId
         mediaType:(NSString *)mediaType
          metaData:(NSDictionary *)metaData
          segments:(NSArray *)segments
         timestamp:(NSDate  *)inTimestamp
   lowRezThumbnail:(UIImage *)lowRezThumbnail
       isOwnedbyMe:(BOOL)isOwnedbyMe
        dontExpire:(BOOL)dontExpire
              fyeo:(BOOL)fyeo;


- (BOOL)isCached;   // this is just for the base item, segments might also be missing

- (NSArray *)missingSegments;

- (void)removeFromCache;

- (NSComparisonResult)compareByTimestamp:(STSCloud *)another;

@end
