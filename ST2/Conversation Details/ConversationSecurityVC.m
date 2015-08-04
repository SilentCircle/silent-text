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
#import "ConversationSecurityVC.h"

#import "AppDelegate.h"
#import "AppConstants.h"
#import "AppTheme.h"
#import "DatabaseManager.h"
#import "MessageStreamManager.h"
#import "OHActionSheet.h"
#import "SCimpWrapper.h"
#import "SCTAvatarView.h"
#import "SCTHelpManager.h"
#import "SilentTextStrings.h"
#import "STConversation.h"
#import "STDynamicHeightView.h"
#import "STLogging.h"
#import "STPreferences.h"
#import "SCimpSnapshot.h"
#import "STSymmetricKey.h"
#import "STUser.h"

// Categories
#import "NSDate+SCDate.h"
#import "NSString+SCUtilities.h"


// Log levels: off, error, warn, info, verbose
#if DEBUG && eric_turner
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


/*
 *
 * NOTE: all string localizations for Conversations Details classes titles and Help are in 
 * ConversationsDetailsHelp.strings
 *
 */

#pragma mark - ResetKeys Constants
static NSString * const kRK_titleKey        = @"resetKeys-action.title";
static NSString * const kRK_createNewKey    = @"resetKeys-action.createNewKeys";
static NSString * const kRK_refreshKey      = @"resetKeys-action.refreshKeys";
#define kResetKeys_title     [SCTHelpManager stringForKey:kRK_titleKey     inTable:SCT_CONVERSATION_DETAILS_HELP]
#define kResetKeys_createNew [SCTHelpManager stringForKey:kRK_createNewKey inTable:SCT_CONVERSATION_DETAILS_HELP]
#define kResetKeys_refresh   [SCTHelpManager stringForKey:kRK_refreshKey   inTable:SCT_CONVERSATION_DETAILS_HELP]


@interface ConversationSecurityVC ()

@property (nonatomic, strong) SCimpSnapshot *scimpSnapshot;

// SAS Verified
@property (nonatomic, weak) IBOutlet UISegmentedControl *sasVerfiedSwitch;
- (IBAction)handleSASVerifiedSwitch:(UISegmentedControl *)segCon;

// Labels
@property (nonatomic, weak) IBOutlet UILabel *lblSASPhrase;
@property (nonatomic, weak) IBOutlet UILabel *lblKeyedDate;
@property (nonatomic, weak) IBOutlet UILabel *lblKeyedBy;
@property (nonatomic, weak) IBOutlet UILabel *lblMethod;
@property (nonatomic, weak) IBOutlet UIButton *btnResetKeys;

@property (nonatomic, weak) IBOutlet UIView *horizontalRule2;
@property (nonatomic, weak) IBOutlet UIView *horizontalRule3;

// Utilties
- (NSString *)stringForCipherSuite:(SCimpCipherSuite)cipherSuite;

// Accessors
- (NSDictionary *)scimpStateKeyInfo; // accessor to scimpState.keyInfo
- (NSDictionary *)multiCastInfo;

@end


@implementation ConversationSecurityVC

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Init / Dealloc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)dealloc
{
    DDLogAutoTrace();
    self.navigationController.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View / Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
	DDLogAutoTrace();
	
    CGFloat screenScale = [[UIScreen mainScreen] scale];
	if (screenScale > 1.0)
	{
		// On retina devices, the contentScaleFactor of 2 results in our horizontal rule
		// actually being 2 pixels high. Fix it to be only 1 pixel (0.5 points).
		
		NSLayoutConstraint *heightConstraint;
				
		heightConstraint = [self heightConstraintFor:_horizontalRule2];
		heightConstraint.constant = (heightConstraint.constant / screenScale);
		
		[_horizontalRule2 setNeedsUpdateConstraints];
        
        heightConstraint = [self heightConstraintFor:_horizontalRule3];
		heightConstraint.constant = (heightConstraint.constant / screenScale);
		
		[_horizontalRule3 setNeedsUpdateConstraints];
	}
    
    // Set this flag before calling super
    self.loadAvatarViewFromNib = YES;
    
    [super viewDidLoad];
    
    // Self nav title
    self.navigationItem.title = NSLocalizedString(@"Conversation Security", @"Conversation Security");
    
    [self.avatarView showInfoButtonForClass:[self class]];
    
    [self updateAllViews];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
//    [self resetPopoverSizeIfNeeded];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Update Views
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Updates SAS phrase, keyed time, keyed by, and scimp method labels text from accessor methods. If super `scimpState`
 * property is nil, this method sets labels directly.
 * 
 * Note: this subclass must call super to initialize conversation title and avatar.
 */
- (void)updateAllViews
{ 
    [super updateAllViews];
    
    if (!self.scimpSnapshot)
    {
        _sasVerfiedSwitch.enabled = NO;
        _lblSASPhrase.text = @"";
   		_lblKeyedDate.text = @"";
 		_lblKeyedBy.text = @"";
        _lblMethod.text = NSLocalizedString(@"Not Keyed", @"Method Label text");
    }
    else 
    {
        [self updateVerifiedView];
        [self updateSASView];
        [self updateKeyedDateView];
        [self updateKeyedByView];
        [self updateMethodView];
    }    
}


/**
 * Set SAS Verified "Yes/No" switch position per conversation keyIsVerified state value.
 *
 * Note: the "switch" control enabled state is set with the retun of `canVerify`, which disables the control if
 * scimpState protocolState is not kSCimpState_Ready.
 */
- (void)updateVerifiedView
{
    BOOL switchIsOn = (_sasVerfiedSwitch.selectedSegmentIndex == 1);
    BOOL isVerified = self.scimpSnapshot.isVerified;
    if (isVerified != switchIsOn)
    {
        _sasVerfiedSwitch.selectedSegmentIndex = (isVerified) ? 1 : 0;
    }
    _sasVerfiedSwitch.enabled = [self canVerify];
}

/**
 * Sets the SAS phrase label text and textColor.
 *
 * Note: this method implementation is different from the simpler implementation in `ConversationsDetailsVC` which
 * simply displays a copy-able SAS phrase label if scimpState.sasPhrase is non-nil.
 *
 * This method sets the SAS phrase label text with text and textColors conditional on a scimpState protocolError, or
 * scimpState protocolState values.
 */
- (void)updateSASView
{
    NSString *strError = [self protocolErrorText];
    if (strError)
    {
        _lblSASPhrase.text = strError;
        _lblSASPhrase.textColor = [UIColor redColor];            
    }
    else 
    {
        NSString *sasPhrase = [self sasPhrase];
        if (sasPhrase)
        {
            _lblSASPhrase.text = sasPhrase;
            _lblSASPhrase.textColor = STAppDelegate.theme.appTintColor;                
        }
        else
        {
			SCimpState protocolState = self.scimpSnapshot.protocolState;
            if (protocolState == kSCimpState_Commit ||
                protocolState ==  kSCimpState_DH1   ||
                protocolState ==  kSCimpState_DH2   ||
                protocolState ==  kSCimpState_Confirm)
            {
                _lblSASPhrase.text = NSLocalizedString(@"Keying In Progress", @"SAS Label text");
                _lblSASPhrase.textColor = [UIColor darkGrayColor];
            }
            else
            {
                _lblSASPhrase.text = NSLocalizedString(@"Not Keyed", @"SAS Label text");
                _lblSASPhrase.textColor = [UIColor orangeColor];
            } 
        }
    }
}

/**
 * Updates the `lblKeyedDate` text with the keyed date if any.
 */
- (void)updateKeyedDateView
{
    NSDate *keyedDate = [self keyedDate];
    if (keyedDate)
        _lblKeyedDate.text = [NSString stringWithFormat:@"%@: %@", 
                          NSLocalizedString(@"Keyed", "keyed Date"),
                          [keyedDate whenString]];
    else 
        _lblKeyedDate.text = @"";
}

/**
 * Updates the `lblKeyedBy` text for group or point-to-point conversation "keyed by" data.
 *
 * If group conversation, keyed by is the conversation creator, otherwise, the conversation initiator.
 */
- (void)updateKeyedByView
{
    if (self.conversation.isMulticast)
    {
        _lblKeyedBy.hidden = NO;
        
        NSString *mc_creator = [[self multiCastInfo] objectForKey:@"creator"];
        
        NSRange range = [mc_creator rangeOfString:@"@"];
        if (range.location != NSNotFound)
            mc_creator = [mc_creator substringToIndex:range.location];
        
        NSString *frmt = NSLocalizedString(@"By: %@", "info2Label");
        _lblKeyedBy.text = [NSString stringWithFormat:frmt, mc_creator];
        
    }
    else
    {
        SCimpSnapshot *aScimpSnapshot = self.scimpSnapshot;
        if(aScimpSnapshot.ctxInfo)
        {
            BOOL is_initiator = [[aScimpSnapshot.ctxInfo objectForKey:kSCimpInfoIsInitiator] boolValue];
            
            XMPPJID *keyedByJid = (is_initiator ? self.conversation.localJid : self.conversation.remoteJid);
            if (keyedByJid)
            {
				NSString *keyedBy = [keyedByJid user];
				NSString *frmt = NSLocalizedString(@"By: %@", "info2Label");
                _lblKeyedBy.text = [NSString stringWithFormat:frmt, keyedBy];
                _lblKeyedBy.hidden = NO;
            }
        }
        else
		{
			_lblKeyedBy.text = @"";
		}
	}
}

/**
 * Sets the scimp method label text.
 */
- (void)updateMethodView
{
    NSString *strError = [self protocolErrorText];
    if (strError)
    {
        _lblMethod.text = NSLocalizedString(@"Not Keyed", @"SAS Label text");
    }
    else
    {
        NSString *methodString = @"";
        
        if ([self sasPhrase])
        {
            SCimpMethod scimpMethod      = [self scimpMethod];
            SCimpCipherSuite cipherSuite = [self cipherSuite];
            NSString *scimpSuiteString   = [self stringForCipherSuite:cipherSuite];
            NSString *scimpMethodString  = @"";
            
            if (scimpMethod == kSCimpMethod_DH)
                scimpMethodString = @"SCimp";
            else if (scimpMethod == kSCimpMethod_DHv2)
                scimpMethodString = @"SCimp2";
            else if(scimpMethod == kSCimpMethod_PubKey)
                scimpMethodString = @"Public Key";
            else if(scimpMethod == kSCimpMethod_Symmetric)
                scimpMethodString = @"Group Keys";
            
            methodString = [NSString stringWithFormat:@"%@ %@", scimpMethodString,scimpSuiteString];
        }
        
        _lblMethod.text = methodString;
    }
}

/**
 * This method is called to update conversation details data.
 *
 * This method is invoked by databaseConnectionDidUpdate: when notified of a database update. Self-initializing
 * `scimpState`, and private `conversationUser` and `multiCastUsers`, properties are set to nil. `updateAllViews` is then
 * invoked which results in subclass implementations calling this base class implementation, resulting in all views
 * being refreshed with updated data.
 *
 * @see MessagesViewController
 */
- (void)didChangeState
{
    self.scimpSnapshot = nil;
    [super didChangeState];
    // super calls updateAllViews
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns a string for the given SCimpCipherSuite identifier.
 *
 * 
 * @param cipherSuite The SCimpCipherSuite enum identifier for which to return a descriptive string
 * @return A string for the given SCimpCipherSuite identifier.
 */
- (NSString *)stringForCipherSuite:(SCimpCipherSuite)cipherSuite
{
	switch (cipherSuite)
	{
        case kSCimpCipherSuite_SKEIN_AES256_ECC414          : return @"Non-NIST";
		case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384    : return @"NIST/AES-128";
		case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384 : return @"NIST/AES-256";
		case kSCimpCipherSuite_SKEIN_AES256_ECC384          : return @"SKEIN/AES-256";
		case kSCimpCipherSuite_Symmetric_AES128             : return @"AES-128";
		case kSCimpCipherSuite_Symmetric_AES256             : return @"AES-256";
		default                                             : return @"";
	}
}

/**
 * @return text of the scimpState protocolError, if any.
 */
- (NSString *)protocolErrorText
{
    NSString *txtError = nil;
    // let the mismatch through
    if (IsSCLError(self.scimpSnapshot.protocolError) &&
                    (self.scimpSnapshot.protocolError != kSCLError_SecretsMismatch))
    {
        char errorBuf[256];
        SCCrypto_GetErrorString(self.scimpSnapshot.protocolError, sizeof(errorBuf), errorBuf);
        txtError = [NSString stringWithUTF8String:errorBuf];
    }
    return txtError;
}

/**
 * @return `YES` if scimpState protocolState value is kSCimpState_Ready, otherwise `NO`.
 */
- (BOOL)canVerify
{
    SCimpState protocolState = self.scimpSnapshot.protocolState;
    return (protocolState == kSCimpState_Ready);
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Reset Key
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Messages the ConversationDetailsDelegate (MessagesViewController) delegate callback for button tap.
 * 07/30/14 UPDATE: now calls actionSheet presentation in this class
 *
 * @param sender The "Reset Keys" button
 */
- (IBAction)resetKeysAction:(id)sender
{
	DDLogAutoTrace();
    [self presentResetKeysActionSheet];
}

- (void)presentResetKeysActionSheet
{
    // only allow refresh of keys for conversations that are already keyed with only one device.
    
    BOOL canRefreshKeys = NO;
    if (! self.conversation.isMulticast  && self.conversation.scimpStateIDs.count == 1)
    {
        __block SCimpSnapshot *aScimpSnapshot = NULL;
        
        [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            
            aScimpSnapshot = [transaction objectForKey:self.conversation.scimpStateIDs.anyObject
                                          inCollection:kSCCollection_STScimpState];
        }];
        
        if (aScimpSnapshot)
        {
            canRefreshKeys = (aScimpSnapshot.protocolState == kSCimpState_Ready) && aScimpSnapshot.ctxInfo;
        }
    }

    // we are turning off refresh keys unless you have experimentalFeatures on.
    if(![STPreferences experimentalFeatures])
        canRefreshKeys = NO;
	
    // ET 10/16/14 OHActionSheet update
    [OHActionSheet showFromVC:self
                       inView:self.view 
                        title:kResetKeys_title
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:kResetKeys_createNew
            otherButtonTitles:(canRefreshKeys ? @[kResetKeys_refresh] : nil)
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
     {
         if (sheet.cancelButtonIndex == buttonIndex)
         {
             return;
         }
         else if (sheet.destructiveButtonIndex == buttonIndex)
         {
             [self resetKeys:YES];
         }
         else
         {
             [self resetKeys:NO];
         }
     }];
}

- (void)resetKeys:(BOOL)newKeys
{
	DDLogAutoTrace();
	
	MessageStream *ms = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
	
	NSString *conversationID = self.conversation.uuid;
	[ms forceRekeyConversationID:conversationID completionBlock:NULL];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - SAS Verified
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Handles a selection of the SAS verified segmentedControl "switch", invoking the super setConverationKeyIsVerified
 * method which updates the database conversation instance.
 *
 * @param segCon The `sasVerifiedSwitch` segmentedControl.
 */
- (IBAction)handleSASVerifiedSwitch:(UISegmentedControl *)segCon
{
	DDLogAutoTrace();
	
	BOOL yesno = (segCon.selectedSegmentIndex == 1) ? YES : NO;
	
	if (self.scimpSnapshot.isVerified != yesno)
	{
		STLocalUser *currentUser = STDatabaseManager.currentUser;
		MessageStream *ms = [MessageStreamManager messageStreamForUser:currentUser];
		
		[ms setScimpID:self.scimpSnapshot.uuid isVerified:yesno];
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Accessors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This self-initializing property is derived from the conversation scimpIDs, either from the conversation remoteJid for
 * a point-to-point conversation, or with the single expected instance in a group conversation. This property is the 
 * main data model for subclass fields.
 */
- (SCimpSnapshot *)scimpSnapshot
{
    if (nil == _scimpSnapshot)
    {
        [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            
            XMPPJID *conversationRemoteJID = self.conversation.remoteJid;
            
            for (NSString *scimpID in self.conversation.scimpStateIDs)
            {
                SCimpSnapshot *aScimpSnapshot = [transaction objectForKey:scimpID
				                                             inCollection:kSCCollection_STScimpState];
                if (aScimpSnapshot)
                {
                    // multiCast - there should only be a single scimpState for multiCast conversation
                    if (self.conversation.isMulticast)
                    {
                        _scimpSnapshot = aScimpSnapshot;
                        break;
                    }
                    // p2p - find the remote device we were talking to last.
                    else if ([aScimpSnapshot.remoteJID isEqualToJID:conversationRemoteJID])
                    {
                        _scimpSnapshot = aScimpSnapshot;
                    }
                }
            }
        }];
    }
    return _scimpSnapshot;
}

/**
 * @return An accessor to the conversation symmetricKey keyDict, a data model for conversation security details.
 */
- (NSDictionary *)multiCastInfo
{
    __block NSDictionary *info = nil;
    if (self.conversation.keyLocator)
    {
        [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            STSymmetricKey *multicastKey = [transaction objectForKey:self.conversation.keyLocator 
                                                        inCollection:kSCCollection_STSymmetricKeys];
            info = multicastKey.keyDict;
        }];
        
    }
    return info;
}

/**
 * @return A convenience accessor to the `scimpState` property keyInfo dictionary.
 */
- (NSDictionary *)scimpStateKeyInfo
{
    return self.scimpSnapshot.ctxInfo;
}

- (NSString *)sasPhrase
{
	return self.scimpSnapshot.sasPhrase;
}

- (SCimpMethod)scimpMethod
{
	return self.scimpSnapshot.protocolMethod;
}

- (SCimpCipherSuite)cipherSuite
{
    return self.scimpSnapshot.cipherSuite;
}

- (NSDate *)keyedDate
{
	return self.scimpSnapshot.keyedDate;
}

- (NSDictionary *)keyInfo
{
    return [self scimpStateKeyInfo];
}

@end
