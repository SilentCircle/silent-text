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
//  NewConversationView.m
//  ST2
//
//  Created by Vinnie Moscaritolo on 8/6/13.
//

#import "AppDelegate.h"
#import "AppConstants.h"
#import "PKRevealController.h"
#import "XMPPJID.h"
#import "STUser.h"
#import "MessageStream.h"
#import "SCAccountsWebAPIManager.h"
#import "SilentTextStrings.h"
#import "MessagesViewController.h"
#import "ConversationViewController.h"
#import "STPreferences.h"
#import "STLogging.h"

#import "STConversation.h"
#import "STUser.h"

#import "HPGrowingTextView.h"

#import "YapCollectionsDatabase.h"
#import "YapCollectionsDatabaseView.h"
#import "SCAccountsWebAPIManager.h"

#import "NewConversationViewController.h"
#import "TITokenField.h"
#import "XMPPJID.h"
#import "YRDropdownView.h"
#import "STUser.h"


// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && vinnie_moscaritolo
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

@interface UIColor (SCUtilities)


@end
@implementation UIColor (SCUtilities)

+ (UIColor *)publicKeyColor {
	return [UIColor colorWithRed:0.216 green:0.373 blue:0.965 alpha:1];
}

+ (UIColor *)inDBColor {
	return [UIColor colorWithRed:0. green:0. blue:0.965 alpha:1];
}

+ (UIColor *)dhKeyColor {
	return [UIColor colorWithRed:0.333 green:0.741 blue:0.235 alpha:1];
}

+ (UIColor *)notfoundColor {
	return [UIColor colorWithRed:1 green:0.15 blue:0.15 alpha:1];
}

+ (UIColor *)notAllowedColor {
	return [UIColor colorWithRed:1 green:0.15 blue:0.0 alpha:1];
}

@end

 

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark  - NewConversationViewController
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface NewConversationViewController ()

@end


@implementation NewConversationViewController
{
    YapCollectionsDatabaseConnection *backgroundConnection;

    NSString            *thisConversationID;
    
    UIView              *topView;
    UIView              *alertView;
	TITokenFieldView *  tokenFieldView;
    CGFloat             keyboardHeight;
     
    NSDictionary        *userNameDict;
    NSString*           localJidStr;

	HPGrowingTextView   *growingTextView;
	UITextView          *tempTextView;
    UIButton            *sendButton;
    
    NSMutableDictionary *recipientDict;
 	YapCollectionsDatabaseConnection *roDatabaseConnection; // Read-Only connection (for main thread)
    
    
}

@synthesize inputView = inputView;
@synthesize netDomain = netDomain;

- (id)initWithProperNib
{
	if (AppConstants.isIPhone)
    	return [self initWithNibName:@"NewConversationView_iPhone" bundle:nil];
	else
		return [self initWithNibName:@"NewConversationView_iPad" bundle:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        
        backgroundConnection = [[STAppDelegate database] newConnection];
        
        YapCollectionsDatabase *database = [STAppDelegate database];
        roDatabaseConnection = [database newConnection];
    }
    return self;
}


- (void)setupInputTextView
{
	CGRect inputFrame = inputView.frame;
	
	CGFloat sendButtonWidth = 63;
	CGFloat sendButtonPaddingLeft = 3;  // Between button and right edge
	CGFloat sendButtonPaddingRight = 3; // Between button and text entry
	
	CGFloat optionsButtonSize = 25;
	CGFloat optionsButtonPaddingLeft = 5;  // Between button and left edge
	CGFloat optionsButtonPaddingRight = 5; // Between button and text entry
	
	CGRect sendButtonFrame;
	sendButtonFrame.origin.x = inputFrame.size.width - (sendButtonPaddingRight * 2);
	sendButtonFrame.origin.y = 8;
	sendButtonFrame.size.width = sendButtonWidth;
	sendButtonFrame.size.height = 27;
	
	CGRect optionsButtonFrame;
	optionsButtonFrame.origin.x = optionsButtonPaddingLeft;
	optionsButtonFrame.origin.y = 8;
	optionsButtonFrame.size = CGSizeMake(optionsButtonSize, optionsButtonSize);
	
	CGFloat entryImageWidth = inputFrame.size.width -
    optionsButtonPaddingLeft - optionsButtonSize - optionsButtonPaddingRight -
    sendButtonPaddingLeft - sendButtonWidth - sendButtonPaddingRight;
	
	CGRect entryImageFrame;
	entryImageFrame.origin.x = optionsButtonPaddingLeft + optionsButtonSize + optionsButtonPaddingRight;
	entryImageFrame.origin.y = 0;
	entryImageFrame.size.width = entryImageWidth;
	entryImageFrame.size.height = 40;
	
	CGRect textViewFrame;
	textViewFrame.origin.x = entryImageFrame.origin.x;
	textViewFrame.origin.y = entryImageFrame.origin.y + 3;
	textViewFrame.size.width  = entryImageFrame.size.width - 5;
	textViewFrame.size.height = entryImageFrame.size.height - 6;
	
    growingTextView = [[HPGrowingTextView alloc] initWithFrame:textViewFrame];
	growingTextView.contentInset = UIEdgeInsetsMake(0, 5, 0, 5);
    
	growingTextView.minNumberOfLines = 1;
	growingTextView.maxNumberOfLines = 6;
	growingTextView.returnKeyType = UIReturnKeyDefault;
	growingTextView.font = [UIFont systemFontOfSize:15.0f];
	growingTextView.delegate = self;
	growingTextView.internalTextView.scrollIndicatorInsets = UIEdgeInsetsMake(5, 0, 5, 0);
	growingTextView.backgroundColor = [UIColor whiteColor];
	growingTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	UIImage *rawEntryBackground = [UIImage imageNamed:@"MessageEntryInputField.png"];
	UIImage *entryBackground = [rawEntryBackground stretchableImageWithLeftCapWidth:13 topCapHeight:22];
	UIImageView *entryImageView = [[UIImageView alloc] initWithImage:entryBackground];
	entryImageView.frame = entryImageFrame;
	entryImageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
	UIImage *rawBackground = [UIImage imageNamed:@"MessageEntryBackground.png"];
	UIImage *background = [rawBackground stretchableImageWithLeftCapWidth:13 topCapHeight:22];
	UIImageView *imageView = [[UIImageView alloc] initWithImage:background];
	imageView.frame = CGRectMake(0, 0, inputView.frame.size.width, inputView.frame.size.height);
	imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	
	UIImage *rawOptionsButtonBgImage = [UIImage imageNamed:@"chatoptions"];
    UIImage *optionsButtonBgImage = [rawOptionsButtonBgImage stretchableImageWithLeftCapWidth:13 topCapHeight:0];
   	UIButton *optionsButton = [UIButton buttonWithType:UIButtonTypeCustom];
	optionsButton.frame = optionsButtonFrame;
	optionsButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
 	[optionsButton addTarget:self action:@selector(chatOptionsPress:) forControlEvents:UIControlEventTouchUpInside];
	[optionsButton setBackgroundImage:optionsButtonBgImage forState:UIControlStateNormal];
	
	tempTextView = [[UITextView alloc] initWithFrame:CGRectZero];
	tempTextView.hidden = YES;
	tempTextView.delegate = self;
	
	[inputView addSubview:tempTextView];
	[inputView addSubview:imageView];
	[inputView addSubview:growingTextView];
	[inputView addSubview:entryImageView];
	[inputView addSubview:optionsButton];
    
//    self.tableView.contentInset = UIEdgeInsetsMake(self.navigationController.navigationBar.frame.size.height, 0,0,0);
    
	UIImage *rawSendBtnBg = [UIImage imageNamed:@"MessageEntrySendButton.png"];
	UIImage *sendBtnBg = [rawSendBtnBg stretchableImageWithLeftCapWidth:13 topCapHeight:0];
    
	UIImage *rawSelectedSendBtnBg = [UIImage imageNamed:@"MessageEntrySendButtonPressed.png"];
	UIImage *selectedSendBtnBg = [rawSelectedSendBtnBg stretchableImageWithLeftCapWidth:13 topCapHeight:0];
    
	sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
	sendButton.frame = CGRectMake(inputView.frame.size.width - 69, 8, 63, 27);
	sendButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
	[sendButton setTitle:@"Send" forState:UIControlStateNormal];
    
	[sendButton setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.4] forState:UIControlStateNormal];
	sendButton.titleLabel.shadowOffset = CGSizeMake (0.0, -1.0);
	sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:18.0f];
    
	[sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[sendButton addTarget:self action:@selector(sendButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	[sendButton setBackgroundImage:sendBtnBg forState:UIControlStateNormal];
	[sendButton setBackgroundImage:selectedSendBtnBg forState:UIControlStateSelected];
	
	sendButton.enabled = NO;;
	[inputView addSubview:sendButton];
    
}


- (void) setUpTopView
{
    CGSize statusbarsize = [UIApplication sharedApplication].statusBarFrame.size;
    size_t height_offset = self.navigationController.navigationBar.frame.size.height + MIN(statusbarsize.height, statusbarsize.width);

    CGRect inputFrame = CGRectMake(0,
                              height_offset,
                              self.navigationController.navigationBar.frame.size.width,
                              40);
  
    topView = [[UIView alloc] initWithFrame:inputFrame];
    topView.backgroundColor = [UIColor whiteColor] ;
  
    [self.view addSubview:topView];
    
  	tokenFieldView = [[TITokenFieldView alloc] initWithFrame:topView.bounds];
    
   [tokenFieldView setSourceArray:[userNameDict allKeys]];
    
	[topView addSubview:tokenFieldView];
	
	[tokenFieldView.tokenField setDelegate:self];
	[tokenFieldView.tokenField addTarget:self
                                  action:@selector(tokenFieldFrameDidChange:)
                        forControlEvents:(UIControlEvents)TITokenFieldControlEventFrameDidChange];
	[tokenFieldView.tokenField setTokenizingCharacters:[NSCharacterSet characterSetWithCharactersInString:@",;."]]; // Default is a comma
    [tokenFieldView.tokenField setPromptText:@"To:"];
	[tokenFieldView.tokenField setPlaceholder:@"Type a name"];
	
	UIButton * addButton = [UIButton buttonWithType:UIButtonTypeContactAdd];
	[addButton addTarget:self action:@selector(showContactsPicker:) forControlEvents:UIControlEventTouchUpInside];
	[tokenFieldView.tokenField setRightView:addButton];
	[tokenFieldView.tokenField addTarget:self action:@selector(tokenFieldChangedEditing:) forControlEvents:UIControlEventEditingDidBegin];
	[tokenFieldView.tokenField addTarget:self action:@selector(tokenFieldChangedEditing:) forControlEvents:UIControlEventEditingDidEnd];
	
 	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	
	// You can call this on either the view on the field.
	// They both do the same thing.
	[tokenFieldView becomeFirstResponder];

    
    
}
- (void) setUpAlertView
{
      
    alertView = [[UIView alloc] init];
    [self alertFrameDidChange];
    
  //  [tokenFieldView.contentView addSubview:alertView];
    [self.view insertSubview:alertView belowSubview: tokenFieldView.contentView ];

}

-(void) alertFrameDidChange
{
    
    CGRect inputFrame = inputView.frame;

    CGFloat top = tokenFieldView.tokenField.frame.size.height + self.navigationController.navigationBar.frame.size.height;
    
    CGRect alertFrame = CGRectMake(0 ,
                                   top + 1,
                                   self.navigationController.navigationBar.frame.size.width,
                                   inputFrame.origin.y - top  -2);
    
    alertView.frame = alertFrame;
   
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
 
    self.navigationController.navigationBar.barStyle =  UIBarStyleBlack;
    self.navigationController.navigationBar.translucent  = YES;
    self.navigationController.navigationBar.tintColor = [STPreferences navItemTintColor];
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Wallp-linen.jpg"]];
    
    userNameDict = [[NSDictionary alloc]init];
    
    recipientDict = [[NSMutableDictionary alloc]init];
    
    thisConversationID = [STPreferences composingConversationIdForUserId:STAppDelegate.currentUser.uuid];
    
    [self reloadTableItems];
    [self setUpTopView];
    [self setupInputTextView];
    [self setUpAlertView];

    
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(yapDatabaseModified:)
	                                             name:YapDatabaseModifiedNotification
	                                           object:[STAppDelegate database]];
	
      self.title = @"New Message";
 }

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{

    localJidStr = STAppDelegate.currentUser.jid;
    
    NSString *pendingTypedMessage = [STPreferences pendingTypedMessageForConversationId:thisConversationID];
	[growingTextView setText:pendingTypedMessage];

    [tokenFieldView.tokenField removeAllTokens];
   
    NSDictionary* recips = [STPreferences pendingRecipientsConversationId:thisConversationID];
    
    for (NSString * jidName in recips)
    {
//        SCimpMethod scimpMethod =  [[recips objectForKey:jidName] integerValue];
        
        NSString* displayName = [userNameDict objectForKey:jidName];
        if(!displayName)
        {
            
            NSRange range = [jidName rangeOfString:@"@"];
            displayName = [jidName substringToIndex:range.location];
         }
          
        [tokenFieldView.tokenField addTokenWithTitle:displayName representedObject:jidName ];
     }
    
}

-(void) viewDidAppear:(BOOL)animated
{
    if(AppConstants.isIPhone)
    {
        [self updateBackBarButton];
    }
    
}

- (void)viewWillDisappear:(BOOL)animated
{
   	NSString *pendingTypedMessage = [growingTextView text];
	[STPreferences setPendingTypedMessage:pendingTypedMessage forConversationId:thisConversationID];

    [STPreferences setPendingRecipients:recipientDict forConversationId:thisConversationID];

}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateBackBarButton
{
 	__block NSUInteger unreadCount = 0;
	
	[roDatabaseConnection readWithBlock:^(YapCollectionsDatabaseReadTransaction *transaction) {
		
		// Enumerate over all the conversationIds for the user
		[transaction enumerateKeysInCollection:STAppDelegate.currentUser.uuid usingBlock:^(NSString *aConversationId, BOOL *stop) {
			
 			unreadCount += [[transaction ext:@"unread"] numberOfKeysInGroup:aConversationId];
 		}];
	}];
    
    [[STAppDelegate conversationViewController] setMessageViewBackButtonCount:unreadCount];
}


- (void)yapDatabaseModified:(NSNotification *)notification
{
	// Since the database was modified, we want to jump to the latest snapshot.
	// At the same time, grab all the associated modification notifications.
	
	NSArray *notifications = [roDatabaseConnection beginLongLivedReadTransaction];
	
	
	// Update back button with new unread count (if it may have changed)
	
	if ([[roDatabaseConnection ext:@"unread"] hasChangesForNotifications:notifications])
	{
		[self updateBackBarButton];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark  - actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)sendButtonTapped:(HPGrowingTextView*)sender
{
	DDLogVerbose(@"sendButtonTapped:");
    
    if ([[growingTextView internalTextView] isFirstResponder])
    {
		// Here's what we want:
		//
		// When the send key is pressed,
		// the textview should automatically accept any suggested autocorrection before sending the message.
		// This is how the SMS app does it, as well as any other textfield in iOS.
		// However, in order to get this functionality, the textview has to end editing.
		// And the only way to do that is to have it resign first responder.
		// But this would make the keyboard disappear which isn't what we want.
		//
		// So our solution is to have another hidden text view become first responder.
		// This way we don't have to deal with all the keyboardWillHide/keyboardWillShow stuff.
		// And as soon as our growingTextView has ended editing and we've sent our message,
		// then we have the growingTextView become first responder again.
		
		[tempTextView becomeFirstResponder];
	}
     
     
	if (growingTextView.text.length > 0)
	{
		if (STAppDelegate.currentUser)
		{
			MessageStream* ms = [STAppDelegate.messageStreams objectForKey:STAppDelegate.currentUser.uuid];
            
            NSArray* recpients = [recipientDict allKeys];
            __block NSString* message = growingTextView.text.copy;
            
            __block  Siren *siren = NULL;
            siren = Siren.new;
            siren.message = growingTextView.text;
            
             if(recpients.count == 1)
            {
             
                NSString * conversationId =  [ms conversationIDWithJidName: [recpients objectAtIndex:0 ]];
                if(!conversationId)
                {
                     [ms createConversationWithJid: [recpients objectAtIndex:0] 
                                  completionBlock:^(NSString *newConID, NSError *error)
                    {
                        if(!error)
                        {
                            [ms sendSiren:siren forConversationID:newConID createMessage:YES];
                             message = NULL;
                            
                            [self popToConversation:newConID];
                            
                        }
                    }];
                }
                else
                {
                    [ms sendSiren:siren forConversationID:conversationId createMessage:YES];
                    message = NULL;
                    
                    [self popToConversation:conversationId];
                }
            }
            else if(recpients.count > 1)
            {
                   
                [ms createConversationWithJids: recpients 
                              completionBlock:^(NSString *newConID, NSError *error)
                 {
                     if(!error)
                     {
                         [ms sendSiren:siren forConversationID:newConID createMessage:YES];
                         message = NULL;
                         
                         [self popToConversation:newConID];
                         
                     }
                 }];

            }
            
 		}
	}
    
    [recipientDict removeAllObjects  ];
    [tokenFieldView.tokenField removeAllTokens];
    growingTextView.text = @"";
}



- (void)popToConversation:(NSString *)conversationId
{
	STAppDelegate.conversationViewController.selectedConversationId = conversationId;
	
	if (AppConstants.isIPhone)
	{
		MessagesViewController *messagesViewController = [STAppDelegate createMessagesViewController];
		messagesViewController.conversationId = conversationId;
		
        UINavigationController* nc = STAppDelegate.conversationViewController.navigationController;
        [nc popViewControllerAnimated: NO];
        [nc pushViewController:messagesViewController animated:YES];
    }
    else
    {
        [STAppDelegate.conversationViewController deleteConversation:thisConversationID];
    }
}

- (void)showContactsPicker:(id)sender {
	
	// Show some kind of contacts picker in here.
	// For now, here's how to add and customize tokens.
	return;
//
////	TIToken * token = [tokenFieldView.tokenField addTokenWithTitle:[userNames objectAtIndex:(arc4random() % userNames.count)]];
//	[token setAccessoryType:TITokenAccessoryTypeDisclosureIndicator];
//	// If the size of the token might change, it's a good idea to layout again.
//	[tokenFieldView.tokenField layoutTokensAnimated:YES];
//	
//	NSUInteger tokenCount = tokenFieldView.tokenField.tokens.count;
//	[token setTintColor:((tokenCount % 3) == 0 ? [TIToken redTintColor] : ((tokenCount % 2) == 0 ? [TIToken greenTintColor] : [TIToken blueTintColor]))];
}


- (void) reloadTableItems
{
    
    NSMutableDictionary* dict  = [[NSMutableDictionary alloc]init];
    STUser* currentUser = STAppDelegate.currentUser;
    
    [roDatabaseConnection  readWithBlock:^(YapCollectionsDatabaseReadTransaction *transaction) {
        [transaction enumerateKeysAndObjectsInCollection: kSCCollection_STUsers
                                              usingBlock:^(NSString *key, id object, BOOL *stop)
         {
             STUser* user = (STUser*) object;
             XMPPJID *jid = [XMPPJID jidWithString:user.jid];
             
             if(! [currentUser.jid isEqualToString: user.jid])
             {
                  if([jid.domain isEqualToString:netDomain])
                      [dict setValue:  user.displayName forKey:user.jid];
             }
             
         }];
    }];
  
    userNameDict = dict;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark chat Options
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (void)chatOptionsPress:(id)sender
{
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark  - Keyboard
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)keyboardWillShow:(NSNotification *)notification {
	
	CGRect keyboardRect = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	keyboardHeight = keyboardRect.size.height > keyboardRect.size.width ? keyboardRect.size.width : keyboardRect.size.height;
	[self resizeViews];
}

- (void)keyboardWillHide:(NSNotification *)notification {
	keyboardHeight = 0;
	[self resizeViews];
}

- (void)resizeViews {
    int tabBarOffset = self.tabBarController == nil ?  0 : self.tabBarController.tabBar.frame.size.height;
	[tokenFieldView setFrame:((CGRect){tokenFieldView.frame.origin, {self.view.bounds.size.width, self.view.bounds.size.height + tabBarOffset - keyboardHeight}})];
//	[_messageView setFrame:tokenFieldView.contentView.bounds];
    
    CGRect inputFrame = inputView.frame;
	
    CGFloat additional =36; //self.navigationController.navigationBar.frame.size.height;
    
	CGRect newInputFrame = (CGRect){
		.origin.x = 0,
		.origin.y = self.view.frame.size.height  -  keyboardHeight  -  additional  ,
		.size.width = self.view.frame.size.width,
		.size.height = inputFrame.size.height,
	};
	
 	inputView.frame = newInputFrame;
 }

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - GrowingTextView
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)growingTextView:(HPGrowingTextView *)sender
       willChangeHeight:(float)height
          withAnimation:(void (^*)(void))animationBlockPtr
             completion:(void (^*)(BOOL))completionBlockPtr
{
	DDLogAutoTrace();
	
	void (^animationBlock)(void) = nil;
	void (^completionBlock)(BOOL) = nil;
	
	float diff = (height - growingTextView.frame.size.height);

	CGRect inputFrame = inputView.frame;
	inputFrame.origin.y    -= diff;
	inputFrame.size.height += diff;
	
	animationBlock = ^{
		
		inputView.frame = inputFrame;
	};

    [self alertFrameDidChange];
	
	if (animationBlockPtr) *animationBlockPtr = [animationBlock copy];
	if (completionBlockPtr) *completionBlockPtr = [completionBlock copy];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark  - TITokenField
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)tokenFieldFrameDidChange:(TITokenField *)tokenField {
       
    [self alertFrameDidChange];
    
}

-(void) verifyToken:(TIToken *)token tokenText:(NSString*) tokenText
{
    __block STUser* user = NULL;
    
    if(token.accessoryType == TITokenAccessoryTypeActivityIndicator)
        return;
    
    NSDate* expireTime = [[NSDate date]  dateByAddingTimeInterval: -60.];
    
    NSString* jidName = token.representedObject;
    
    NSRange range = [jidName rangeOfString:@"@"];
   __block NSString* userName = [jidName substringToIndex:range.location];
    
    if(!userName)
    {
        userName = tokenText;
        jidName = [userName stringByAppendingFormat:@"@%@", netDomain];
    }
    
    if([localJidStr isEqualToString:jidName])
    {
        [token setTintColor: [UIColor notAllowedColor]];
        [token setAccessoryType: TITokenAccessoryTypeAlertIndicator];

        [tokenFieldView.tokenField layoutTokensAnimated:NO];
        
        if([[recipientDict objectForKey:jidName] isEqualToNumber: @(kSCimpMethod_Invalid)] )
        {
            NSString * errorMsg = NSLS_COMMON_INVALID_USER;
            NSString * errorDetail = NSLS_COMMON_INVALID_SELF_USER_DETAIL;
                 
            [YRDropdownView showDropdownInView:alertView
                                         title:errorMsg
                                        detail:errorDetail
                                         image:[UIImage imageNamed:@"dropdown-alert"]
                                      animated:YES
                                     hideAfter:3];
            
        }
        [recipientDict setObject:@(kSCimpMethod_Invalid) forKey:jidName];
   
        return;
    }

    [token setTintColor: [UIColor grayColor]];

    // check to see if the we have a recent entry in our database.

    [backgroundConnection asyncReadWithBlock:^(YapCollectionsDatabaseReadTransaction *transaction) {
        
        [transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
                                              usingBlock:^(NSString *key, id object, BOOL *stop)
         {
             if([jidName isEqualToString:((STUser*)object).jid])
             {
                 user = (STUser*) object;
                 
                 if(user.lastUpdated &&  ([user.lastUpdated compare:expireTime] != NSOrderedDescending))
                 {
                     user  = NULL;
                 }
                 
                 *stop = YES;
             }
         }];
        
    }completionBlock:^{
        
        if(user)  // if it's in our database then set the color
        {
            [token setTintColor:[UIColor inDBColor]];
            [recipientDict setObject:@(kSCimpMethod_PubKey) forKey:jidName];
            sendButton.enabled = [self checkRecipients];
            
        }
        else
        {
            // look up if this is a valid user from server.
            
            [token setAccessoryType: TITokenAccessoryTypeActivityIndicator];
            
              [[SCAccountsWebAPIManager sharedInstance] getUserInfo:userName
                                                          forUser:STAppDelegate.currentUser
                                                 completionBlock:^(NSError *error, NSDictionary *infoDict) {
                                                      
                                                      [token setAccessoryType:TITokenAccessoryTypeNone];
                                                      [tokenFieldView.tokenField layoutTokensAnimated: NO];
                                                      
                                                      if(!error && infoDict)
                                                      {
                                                          
                                                          NSArray* pubKeysArray =  [infoDict objectForKey:@"keys"] ;
                                                          NSDictionary  *permissions = [infoDict objectForKey:@"permissions"];
                                                          
                                                          BOOL hasPhone = NO;
                                                          BOOL canSendMedia = YES;
                                                          
                                                          if(permissions)
                                                          {
                                                              
                                                              if([permissions objectForKey:@"silent_phone"])
                                                                  hasPhone = [[permissions objectForKey:@"silent_phone"] boolValue];
                                                              
                                                              if([permissions objectForKey:@"can_send_media"])
                                                                  canSendMedia = [[permissions objectForKey:@"can_send_media"] boolValue];
                                                          }
                                                          
                                                          
                                                          NSString* lastName = [infoDict objectForKey:@"last_name"];
                                                          NSString* firstName = [infoDict objectForKey:@"first_name"];
                                                          
                                                          if(pubKeysArray && pubKeysArray.count)
                                                          {
                                                              [STAppDelegate addRemoteUserToDB: jidName
                                                                                  pubKeysArray: pubKeysArray
                                                                                      hasPhone: hasPhone
                                                                                  canSendMedia: canSendMedia
                                                                                     firstName: firstName
                                                                                      lastName: lastName
                                                                               completionBlock: NULL];
                                                              
                                                              [token setTintColor:[UIColor publicKeyColor]];
                                                              [recipientDict setObject:@(kSCimpMethod_PubKey) forKey:jidName];
                                                              
                                                          }
                                                          else
                                                          {
                                                              [token setTintColor:[UIColor dhKeyColor]];
                                                              [recipientDict setObject:@(kSCimpMethod_DH) forKey:jidName];
                                                              
                                                          }
                                                      }
                                                      else
                                                      {
                                                          [token setTintColor:[UIColor notfoundColor]];
                                                          [token setAccessoryType: TITokenAccessoryTypeAlertIndicator];
                                                          
                                                          [tokenFieldView.tokenField layoutTokensAnimated:NO];
                                                          
                                                          if([[recipientDict objectForKey:jidName] isEqualToNumber: @(kSCimpMethod_Invalid)] )
                                                          {
                                                              NSString * errorMsg = NSLS_COMMON_CONNECT_FAILED;
                                                              NSString * errorDetail = NSLS_COMMON_CONNECT_DETAIL;
                                                              
                                                              if(error.code == 404)
                                                              {
                                                                  errorMsg = NSLS_COMMON_INVALID_USER;
                                                                  errorDetail = [NSString stringWithFormat:NSLS_COMMON_INVALID_USER_DETAIL, userName ];
                                                              }
                                                              
                                                               [YRDropdownView showDropdownInView:alertView
                                                                                           title:errorMsg
                                                                                          detail:errorDetail
                                                                                           image:[UIImage imageNamed:@"dropdown-alert"]
                                                                                        animated:YES
                                                                                       hideAfter:3];
                                                                                                                             
                                                          }
                                                          [recipientDict setObject:@(kSCimpMethod_Invalid) forKey:jidName];
                                                          
                                                      }
                                                      
                                                      sendButton.enabled = [self checkRecipients];
                                                      
                                                  }];
            
            
        }
        
    }];
    
}

- (void)tokenField:(TITokenField *)tokenField didHitAlertToken:(TIToken *)token;
{
    DDLogVerbose(@"didHitAlertToken: %@", token.title);
    
    [self verifyToken:token  tokenText: token.title];
    
}

- (void)tokenField:(TITokenField *)tokenField didAddToken:(TIToken *)token;
{
    DDLogVerbose(@"didAddToken: %@", token.representedObject);
    
    [self verifyToken:token  tokenText:[tokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
  
}


- (BOOL) checkRecipients
{
    BOOL isOK = FALSE;
    
    NSArray* badJids =  [recipientDict allKeysForObject:@(kSCimpMethod_Invalid) ];
    
    if(badJids.count == 0)
    {
        if(recipientDict.count > 1)
        {
            NSArray* nonPKJids =  [recipientDict allKeysForObject:@(kSCimpMethod_DH) ];
            isOK = (nonPKJids.count == 0);
            
        }
        else
        {
            isOK = TRUE;
        }
  
    }
        
    return isOK;
}

- (BOOL)tokenField:(TITokenField *)tokenField willRemoveToken:(TIToken *)token {
	
    NSString* jidName = token.representedObject;
    
    if(!jidName)
        jidName = [token.title stringByAppendingFormat:@"@%@", netDomain];
      
    [recipientDict removeObjectForKey:jidName];
    
 	 sendButton.enabled = [self checkRecipients];
	return YES;
}

 
- (void)tokenFieldChangedEditing:(TITokenField *)tokenField {
    
 	// There's some kind of annoying bug where UITextFieldViewModeWhile/UnlessEditing doesn't do anything.
	[tokenField setRightViewMode:(tokenField.editing ? UITextFieldViewModeAlways : UITextFieldViewModeNever)];
}

 
- (void)textViewDidChange:(UITextView *)textView {
	
	CGFloat oldHeight = tokenFieldView.frame.size.height - tokenFieldView.tokenField.frame.size.height;
	CGFloat newHeight = textView.contentSize.height + textView.font.lineHeight;
	
	CGRect newTextFrame = textView.frame;
	newTextFrame.size = textView.contentSize;
	newTextFrame.size.height = newHeight;
	
	CGRect newFrame = tokenFieldView.contentView.frame;
	newFrame.size.height = newHeight;
	
	if (newHeight < oldHeight){
		newTextFrame.size.height = oldHeight;
		newFrame.size.height = oldHeight;
	}
    
	[tokenFieldView.contentView setFrame:newFrame];
	[textView setFrame:newTextFrame];
	[tokenFieldView updateContentSize];
}

 - (NSString *)tokenField:(TITokenField *)tokenField displayStringForRepresentedObject:(id)object
{
    NSString* jidString = object;
    
    NSString* displayName = [userNameDict objectForKey:jidString];
    
    return displayName?displayName:@"";

}


- (NSString *)tokenField:(TITokenField *)tokenField searchResultStringForRepresentedObject:(id)object
{
    NSString* jidString = object;
    NSRange range = [jidString rangeOfString:@"@"];
    NSString* userName = [jidString substringToIndex:range.location];
    NSString* displayName = [userNameDict objectForKey:jidString];
    
    NSString*  	searchString = [tokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    
    BOOL foundJid =  ([userName rangeOfString:searchString
                                      options:NSLiteralSearch].length == searchString.length);
                       
    BOOL foundName = ([displayName rangeOfString:searchString
                                         options:NSCaseInsensitiveSearch].length == searchString.length);
                       
                       
    return (foundJid || foundName)?displayName: @"";

}
- (NSString *)tokenField:(TITokenField *)tokenField searchResultSubtitleForRepresentedObject:(id)object
{
    NSString* jidString = object;
    NSRange range = [jidString rangeOfString:@"@"];
    NSString* userName = [jidString substringToIndex:range.location];
     
    NSString*  	searchString = [tokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    
    BOOL foundJid =  ([userName rangeOfString:searchString
                                      options:NSLiteralSearch].length == searchString.length);
     
    
    return (foundJid )?jidString: @"";
 
}




@end
