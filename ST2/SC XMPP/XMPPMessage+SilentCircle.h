/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

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
#import "XMPPMessage.h"
#import "XMPPMessage+XEP_0033.h"
#import "XMPPJIDSet.h"
#import "Siren.h"

@interface XMPPMessage (SilentCircle)

+ (XMPPMessage *)chatMessageWithSiren:(Siren *)siren to:(XMPPJID *)jid elementID:(NSString *)elementID;
+ (XMPPMessage *)chatMessageWithSiren:(Siren *)siren to:(XMPPJID *)jid elementID:(NSString *)elementID
                                                                            push:(BOOL)push
                                                                           badge:(BOOL)badge;

+ (XMPPMessage *)multicastChatMessageWithSiren:(Siren *)siren
                                            to:(NSArray *)jids // supports both XMPPJID and NSString
                                      threadID:(NSString *)threadID
                                        domain:(NSString *)domain;

+ (XMPPMessage *)multicastChatMessageWithSiren:(Siren *)siren
                                            to:(NSArray *)jids // supports both XMPPJID and NSString
                                      threadID:(NSString *)threadID
                                        domain:(NSString *)domain
                                     elementID:(NSString *)elementID;

@property (nonatomic, readwrite) NSString *threadID;

- (NSDate *)timestamp;

- (BOOL)isChatMessageWithSiren;
- (BOOL)isChatMessageWithPubSiren;

- (void)stripSilentCirclePlaintextDataForIncomingStanza;
- (void)stripSilentCirclePlaintextDataForOutgoingStanza;

@end
