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
#import "FakeStream.h"
#import "MessageStream.h"

#import "AppConstants.h"
#import "AppDelegate.h"
#import "STUserManager.h"

#import "STConversation.h"
#import "STMessage.h"
#import "STUser.h"
#import "Siren.h"

#import "YapDatabase.h"
#import "STLogging.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


NSString *const kSomeLocation =
  @"{\"altitude\":574.1026000976562,"
    @"\"horizontalAccuracy\":65,"
    @"\"timestamp\":389395871.061269,"
    @"\"latitude\":42.19844042922207,"
    @"\"longitude\":-122.7096779259368,"
    @"\"verticalAccuracy\":10}";

#define TEST_DAY_CHANGE 0


@interface FakeStream ()
{
	YapDatabaseConnection *backgroundConnection;
	int runCount;
    
    XMPPJID * myJid;
    NSString * myUUID;
 
    NSString *xmppDomain;
	
#if TEST_DAY_CHANGE
	NSDate *date;
#endif
}

@property(atomic, readwrite) BOOL isRunning;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation FakeStream

static FakeStream *sharedInstance;

+ (void)initialize
{
	static BOOL initialized = NO;
    
	if (!initialized)
	{
		initialized = YES;
		sharedInstance = [[FakeStream alloc] init];
	}
}

+ (FakeStream *)sharedInstance
{
	return sharedInstance;
}

@synthesize isRunning = isRunning;

- (id)init
{
	if ((self = [super init]))
	{
		// We can have multiple connections to the database.
		// This way we can write to the database from a background queue,
		// while another queue simultaneously reads from the database.
		//
		// A write won't block a separate connection from reading.
		// So we don't have to worry about blocking the main thread from this component.
		
        self.isRunning = NO;
        
		backgroundConnection = [STDatabaseManager.database newConnection];
		
	#if TEST_DAY_CHANGE
		
		// For testing:
		// Display timestamp when day changes (regardless of elapsed interval between messages)
		
		NSDate *yesterday = [[NSDate date] dateByAddingTimeInterval:(60 * 60 * 24 * -1)];
		
		NSCalendar *calendar = [NSCalendar currentCalendar];
		
		NSUInteger flags = NSYearCalendarUnit   |
		                   NSMonthCalendarUnit  |
		                   NSDayCalendarUnit    |
		                   NSHourCalendarUnit   |
		                   NSMinuteCalendarUnit |
		                   NSSecondCalendarUnit ;
		
		NSDateComponents *dateComponents = [calendar components:flags fromDate:yesterday];
		
		dateComponents.hour = 23;
		dateComponents.minute = 45;
		dateComponents.second = 0;
		
		date = [calendar dateFromComponents:dateComponents];
		
	#endif
        
        NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:kNetworkID_Fake];
        
        xmppDomain = [networkInfo objectForKey:@"xmppDomain"];
        myUUID = NULL;
	}
	return self;
}


- (NSString *)generateUUID
{
	NSString *result = nil;
	
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	if (uuid)
	{
		result = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
		CFRelease(uuid);
	}
	
	return result;
}

- (void)start
{
	self.isRunning = TRUE;
    [self logUsers];
    [self logNext:0];
}

- (void)stop
{
    self.isRunning = FALSE;
	runCount++;
}

static char *banter[] = {
	"Hello. My name is Inigo Montoya. You killed my father. Prepare to die.",
	"Finish him. Finish him, your way.",
	"Oh good, my way. Thank you Vizzini... what's my way?",
	"Возьмите один из тех пород, получить за валуном, в течение нескольких минут человек в черном прибежит за поворотом, в ту минуту его голова в виду, ударил его со скалой.",
	"My way's not very sportsman-like. ",
	"Why do you wear a mask? Were you burned by acid, or something like that?",
	"لماذا هو مؤخرتي كبيرة جدا؟",
	"أن معتوه تحطمت فقط بريوس له",
	"Oh no, it's just that they're terribly comfortable. I think everyone will be wearing them in the future.",
	"I do not envy you the headache you will have when you awake. But for now, rest well and dream of large women.",
	"I just want you to feel you're doing well.",
	"That Vizzini, he can *fuss*." ,
	"Fuss, fuss... I think he like to scream at *us*.",
	"Probably he means no *harm*. ",
	"He's really very short on *charm*." ,
	"You have a great gift for rhyme." ,
	"Yes, yes, some of the time.",
	"Enough of that.",
	"Fezzik, are there rocks ahead? ",
	"If there are, we all be dead. ",
	"No more rhymes now, I mean it. ",
	"Anybody want a peanut?",
	"I love it when a plan comes together",
	"short",
	"hey guys in our building broke a water pipe today and, as of now, we have no power or water in the building. We definitely train in the semi-dark (we've done it before) but we will have no restrooms.",
	"Hey. What kind of party is this? There's no booze and only one hooker. ",
	"I was a hero to broken robots 'cause I was one of them, but how can I sing about being damaged if I'm not? That's like Christina Aguilera singing Spanish. Ooh, wait! That's it! I'll fake it! ",
	"Your basic bending unit is made of an iron-osmium alloy, but Bender was different. Bender had an 0.04% nickel impurity. ",
	"no",
	NULL
};

static char *displayNames[] = {
	"Inigo Montoya",
	"Vizzini",
	"Fezzik",
	"Борис Баденов",
	"Наташа роковая",
	"Daphne Blake",
    
                "احمد ، الإرهابي الميت",
	"Velma Elizabeth Dinkley",
	"Harvey Birdman",
	"Mr Squiggle",
	"Ron Jeremy",
	"Lisa Ann",
	"Laurence Tureaud",
	"Hannibal Smith",
	"Bender Rodríguez",
	"Master Ken",
 	"Prof. Hubert J. Farnsworth",
	NULL,
};

static char *usernames[] = {
	"Inigo",
	"Vizzini",
	"Fezzik",
	"Борис",
	"Наташа",
	"Daphne",
	"احمد",
	"Velma",
	"Birdman",
	"Squiggle",
	"Ron",
	"bubbles",
	"MRT",
	"Hannibal",
	"Bender",
	"Ameridote",
	"Prof",
	NULL,
};

static NSString *fakeUserName = @"Fake_User";

- (void)logUsers
{
	myJid = [XMPPJID jidWithUser:fakeUserName domain:xmppDomain resource:nil];
	
	NSAssert(myJid != nil, @"Bad fakeUserName or xmppDomain");
	
	__block STUser *myUser = nil;
	[backgroundConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		myUser = [STDatabaseManager findUserWithJID:myJid transaction:transaction];
	}];
	
	if (myUser)
	{
        myUUID = myUser.uuid;
    }
    else
    {
		[[STUserManager sharedInstance] addLocalUserToDB:myJid
		                                       networkID:kNetworkID_Fake
		                                    xmppPassword:@""
		                                          apiKey:@""
		                                        deviceID:@""
		                                    canSendMedia:NO
		                                          enable:NO
		                                 completionBlock:^(NSString *uuid)
		{
			myUUID = uuid;
		}];
    }
    
    int nameCount = (sizeof(usernames) / sizeof(char*)) -1;
    
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
	
	for (int i = 0; i < nameCount; i++)
	{
		NSString *username = [NSString stringWithUTF8String:usernames[i]];
		NSString *displayName = [NSString stringWithUTF8String:displayNames[i]];
		
		NSString *firstName = @"";
		NSString *lastName = @"";
        
		NSArray *components = [displayName componentsSeparatedByCharactersInSet:whitespace];
		if (components.count > 1)
		{
			lastName = [components lastObject];

			NSRange range = NSMakeRange(0, components.count-1);
			firstName = [[components subarrayWithRange:range] componentsJoinedByString:@" "];
        }
        else
		{
			lastName = displayName;
		}
		
		XMPPJID *jid = [XMPPJID jidWithUser:username domain:xmppDomain resource:nil];
		
		STUser *user = [[STUser alloc] initWithUUID:nil networkID:kNetworkID_Fake jid:jid];
		user.hasPhone = NO;
		user.canSendMedia = NO;
		user.web_firstName = firstName;
		user.web_lastName = lastName;
		user.web_compositeName = displayName;
		
		[[STUserManager sharedInstance] addNewUser:user withPubKeys:nil completionBlock:NULL];
	}
}


- (void)logNext:(int)i
{
	if (!self.isRunning) return;
    if (i >= 1000) return;
    
	int banterCount = (sizeof(banter)/sizeof(char*)) -1;
	int banterItem = i % banterCount;
		
	BOOL isShredable = (i > 30);
//	BOOL isShredable = YES;
	
	if (YES) // From multiple users
	{
		int nameCount = (sizeof(usernames)/sizeof(char*)) -1;
		int nameItem = i % nameCount;
		
		NSString *username = [NSString stringWithUTF8String:usernames[nameItem]];
		XMPPJID *jid = [XMPPJID jidWithUser:username domain:xmppDomain resource:nil];
		
		[self logMessage:[NSString stringWithUTF8String:banter[banterItem]]
			    localJID:myJid
			   remoteJID:jid
		      isOutgoing:(i%3)
		     isShredable:isShredable];
	}
	else // Continual messages from a single user
	{
		NSString *username = [NSString stringWithUTF8String:usernames[0]];
		XMPPJID *jid = [XMPPJID jidWithUser:username domain:xmppDomain resource:nil];
		
		[self logMessage:[NSString stringWithUTF8String:banter[banterItem]]
		        localJID:myJid
		       remoteJID:jid
		      isOutgoing:(i%3)
		     isShredable:isShredable];
	}
	
	int prevRunCount = runCount;

	double delayInSeconds = 0.5;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
		
		if (prevRunCount == runCount)
		{
			[self logNext:(i+1)];
		}
	});
}

- (void)logMessage:(NSString *)msg
          localJID:(XMPPJID *)localJID
         remoteJID:(XMPPJID *)remoteJID
        isOutgoing:(int)isOutgoing
       isShredable:(BOOL)isShredable
{
	if (myUUID == nil) return;
	
	NSString *conversationId = [MessageStream conversationIDForLocalJid:localJID remoteJid:remoteJID];
	
	__block STConversation *conversation = nil;
	__block STMessage *message = nil;
	
	[backgroundConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
	 	
		conversation = [transaction objectForKey:conversationId inCollection:myUUID];
		if (conversation == nil)
		{
			conversation = [[STConversation alloc] initWithUUID:conversationId
			                                        localUserID:myUUID
			                                           localJID:localJID
			                                          remoteJID:remoteJID];

			conversation.isFakeStream = YES;
			conversation.hidden = NO;
		}

		Siren *siren = Siren.new;
		siren.message = msg;
	//	siren.location = kSomeLocation;
		siren.shredAfter = isShredable ? (60 * 60) /* one hour */ : 0;
		
		NSString *messageId = [XMPPStream generateUUID];
		
	#if TEST_DAY_CHANGE
		NSDate *timestamp = date;
		date = [date dateByAddingTimeInterval:60];
	#else
		NSDate *timestamp = [NSDate date];
	#endif
		
		message = [[STMessage alloc] initWithUUID:messageId
		                           conversationId:conversationId
		                                   userId:myUUID
                                             from:(isOutgoing ? [localJID bareJID] : remoteJID)
                                               to:(isOutgoing ? [remoteJID bareJID] : [localJID bareJID])
                                        withSiren:siren
                                        timestamp:timestamp
                                       isOutgoing:isOutgoing];
	
		message.isVerified = NO;
		message.sendDate = [NSDate date];
        
		// Use this to force the burn timer immediately
		// (as opposed to starting the burn timer after you view it in MessagesViewController)
	//	if (siren.shredAfter > 0) {
	//		message.shredDate = [NSDate dateWithTimeIntervalSinceNow:siren.shredAfter];
	//	}
		
		[transaction setObject:message
		                forKey:message.uuid
		          inCollection:message.conversationId];
	}];
}

@end
