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
//
//  SCTAvatarView.m
//  ST2
//
//  Created by Eric Turner on 8/5/14.
//

#import "SCTAvatarView.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AvatarManager.h"
#import "DatabaseManager.h"
#import "SCimpUtilities.h"
#import "SCTHelpButton.h"
#import "SCTHelpManager.h"
#import "STConversation.h"
#import "STLogging.h"
#import "STPreferences.h"
#import "STPublicKey.h" 
//#import "STScimpState.h"
#import "STUser.h"
// Catetgories
#import "NSString+SCUtilities.h"
#import "UIImage+maskColor.h"
#import "UIImage+Thumbnail.h"


// Log levels: off, error, warn, info, verbose
#if DEBUG && eric_turner
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

static const CGFloat kAvatarDiameter  = 60;


@interface SCTAvatarView ()

@property (nonatomic, weak) IBOutlet UIButton *btnCreatePublicKey;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *createPublicKeySpinner;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *lblDisplayNameTrailingConstraint;

@property (nonatomic, weak, readonly) AppTheme *theme;
@property (nonatomic, weak) IBOutlet UIImageView *userImageView;

// Constraint properties
@property (nonatomic, assign) CGFloat displayNameAvatarCenterYOffset;
@property (nonatomic, assign) CGFloat organizationNameAvatarCenterYOffset;
@property (nonatomic, assign) CGFloat userImageViewCenterYOffset;

@end


@implementation SCTAvatarView


#pragma mark - Layout Utilities

/** 
 * This method positions the displayName and organizationName labels, conditional on their values, i.e.,
 * if there is no organizationName label value, the displayName centerY will be made to match the imageView center
 * This method should be called by the hosting VC (or baseVC) after the data properties are initialized
 */
- (void)layoutTitles
{
    // Find centerY offset for displayName
    // If organizationName is empty, sync displayName label centerY with userImageView centerY
    if ([NSString stringIsNilOrEmpty:_lblOrganizationName.text])
    {
        NSLayoutConstraint *displayNameYConstraint = [self centerYConstraintFor:_lblDisplayName];
        displayNameYConstraint.constant = 0;
        [self setNeedsUpdateConstraints];
    }
}

- (NSLayoutConstraint *)centerYConstraintFor:(id)item
{
    for (NSLayoutConstraint *constraint in self.constraints)
    {
        if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeCenterY) ||
            (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeCenterY))
        {
            return constraint;
        }
    }
    
    return nil;
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Methods
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateAllViews
{
    if (self.conversation.isFakeStream)
    {
        [self layoutForFakeStream];
    }
    else
    {
        [self updateDisplayNameView];
        [self updateOrganizationNameView];
        [self updateUserKeyInfoButton];
        [self layoutTitles];
    }
}

- (void)layoutForFakeStream
{
   NSString* displayName = NSLocalizedString(@"System Messages", @"System Messages label title");
    
    if (IsSTInfoJID(self.conversation.remoteJid))
    {
        displayName = AppConstants.STInfoDisplayName;
    }
    else if (IsOCAVoicemailJID(self.conversation.remoteJid))
    {
        displayName = AppConstants.OCAVoicemailDisplayName;;
    }
    
    // Update avatarView
    self.lblDisplayName.text = displayName;
    self.lblOrganizationName.text = NSLocalizedString(@"Silent Circle", @"Silent Circle label title");
    [self updateAvatarWithDefaultImage];
}

- (void)updateAllViewsWithAvatar:(UIImage *)anImage animated:(BOOL)animated
{
    if (animated)
        [self setAvatarImage:anImage withAnimation:YES];
    else
        _userImageView.image = anImage;
    
    [self updateAllViews];
}


- (void)updateAvatarWithDefaultImage
{
    [self updateAvatarWithDefaultImageWithAnimation:YES];
}

- (void)updateAvatarWithDefaultImageWithAnimation:(BOOL)animated
{
    UIImage *img = nil;
    if (_conversation.isMulticast)
    {
        img = [[AvatarManager sharedInstance] defaultMultiAvatarImageWithDiameter:kAvatarDiameter];
    }
    else
    {
        if (IsSTInfoJID(_conversation.remoteJid))
            img = [[AvatarManager sharedInstance] defaultSilentTextInfoUserAvatarWithDiameter:kAvatarDiameter];
        else if (IsOCAVoicemailJID(_conversation.remoteJid))
            img = [[AvatarManager sharedInstance] defaultOCAUserAvatarWithDiameter:kAvatarDiameter];
          else
            img = [[AvatarManager sharedInstance] defaultAvatarWithDiameter:kAvatarDiameter];
    }
    
    if (animated)
        [self setAvatarImage:img withAnimation:animated];
    else    
        _userImageView.image = img;
}

/**
 * Updates `userImageView` avatar image.
 */
- (void)updateAvatar
{
//    if (_conversation.isMulticast)
//        [self updateGroupAvatar];
//    else
//        [self updateUserAvatar];
    [self updateAvatarImage];
}

/**
 * Updates `lblDisplayName` text.
 */
- (void)updateDisplayNameView
{
    _lblDisplayName.text = [self titleForDisplayName];
    BOOL useGray = (_user.hasExtendedDisplayName        && 
                    _user.sc_compositeName.length == 0  && 
                    _user.sc_firstName.length == 0      && 
                    _user.sc_lastName.length == 0       && 
                    _user.web_compositeName.length == 0 && 
                    _user.web_firstName.length == 0     && 
                    _user.web_lastName.length == 0      && 
                    _user.abRecordID != kABRecordInvalidID
                    );
    _lblDisplayName.textColor = (useGray) ? [UIColor grayColor] : [UIColor blackColor];
}

- (void)updateOrganizationNameView
{
    _lblOrganizationName.text = [self titleForOrganization];
    // From UserInfoVC
    BOOL useGray = (_user.organization.length && 
                    _user.sc_organization.length == 0 && 
                    _user.abRecordID != kABRecordInvalidID);
    _lblOrganizationName.textColor = (useGray) ? [UIColor grayColor] : [UIColor blackColor];
}


- (void)updateUserKeyInfoButton
{
    NSString *aUserId = self.user.uuid;
    if (nil == aUserId)
        return;
    
    __block STUser      *aUser    = nil;
    __block STPublicKey *aUserKey = nil;
        
    [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        aUser = [transaction objectForKey:aUserId inCollection:kSCCollection_STUsers];
        
        if (aUser && aUser.currentKeyID)
        {
            aUserKey = [transaction objectForKey:aUser.currentKeyID inCollection:kSCCollection_STPublicKeys];
        }
		
		// Get out of a database transaction ASAP.
		// I.e. Don't do a bunch of UI stuff within a database transaction.
    }];
	
	if (aUserKey)
	{
		UIImage *keyButtonImage = NULL;
		
		if (aUserKey.isExpired)
		{
			keyButtonImage = [[UIImage imageNamed:@"X-circled"]
							  maskWithColor:[UIColor colorWithRed:1.0 green:.5 blue: 0 alpha:.6 ]];
			[_btnKeyInfo setImage:keyButtonImage forState:UIControlStateNormal];
			[_btnKeyInfo setHidden:NO];
			
		}
		else
		{
			SCKeyContextRef keyContext = kInvalidSCKeyContextRef;
			SCKey_Deserialize(aUserKey.keyJSON, &keyContext);
			
			SCKeySuite suite = kSCKeySuite_Invalid;
			SCKeyGetProperty(keyContext, kSCKeyProp_SCKeySuite, NULL,  &suite, sizeof(SCKeySuite), NULL);
			
			if (SCKeyContextRefIsValid(keyContext))
			{
				SCKeyFree(keyContext);
			}
			
			
			if (suite == kSCKeySuite_ECC414)
				keyButtonImage = [aUserKey.continuityVerified
								  ?[UIImage imageNamed:@"starred-checkmark"]
								  :[UIImage imageNamed:@"checkmark-circled"]
								  maskWithColor:[UIColor colorWithRed:0 green:.7 blue: 0 alpha:.6 ]];
			
			else if (suite == kSCKeySuite_ECC384)
				keyButtonImage = [aUserKey.continuityVerified
								  ?[UIImage imageNamed:@"starred-checkmark"]
								  :[UIImage imageNamed:@"checkmark-circled"]
								  maskWithColor:[UIColor colorWithRed:0 green:0 blue: 0.7 alpha:.6 ]];
			else
				keyButtonImage = [[UIImage imageNamed:@"X-circled"]
								  maskWithColor:[UIColor colorWithRed:0 green:0 blue: 0. alpha:.6 ]];
			
		}
		
		[_btnKeyInfo setImage:keyButtonImage forState:UIControlStateNormal];
		
		[_btnKeyInfo setHidden:NO];
	}
	else
	{
		[_btnKeyInfo setHidden:YES];
	}
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Utilities
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * @return Text for `lblDisplayName`: conversation title for group conversation; user displayName, otherwise.
 */
- (NSString *)titleForDisplayName
{
//    if (_conversation)
//    {
        if (_conversation.isMulticast)
        {
            NSCharacterSet *charSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
            if ([[_conversation.title stringByTrimmingCharactersInSet:charSet] length] > 0)
            {
                return _conversation.title;
            }
            
            return NSLocalizedString(@"Group Conversation", @"Group Conversation");
//        }
//        else
//        {
//            if (self.user.displayName)
//            {
//                return self.user.displayName;
//            }
//        }
    }

    return self.user.displayName;
}

/**
 * @return Text for `lblOrganizationName`: group conversation participants string, or user name.
 */
- (NSString *)titleForOrganization
{
    NSString *title = nil;
    if (_conversation.isMulticast)
    {
        NSUInteger selfUser = 1;
        NSString *str = [NSString stringWithFormat:@"%lu participants", (unsigned long)self.multiCastUsers.count + selfUser];
        title = NSLocalizedString(str, @"{number of conversation} participants");
    }
    else
    {
        title = self.user.organization;
    }
    
    return title;
}

// btnCreatePublicKey should be hidden in IB by default
// VCs wishing to display the button should call this method (Security details / UserInfo VC)
- (void)showCreatePublicKeyButton
{
    UIButton *pubKeyButton = _btnCreatePublicKey;
    UIImage *icon = [UIImage imageNamed:@"refresh_key"];
    UIImage *tintIcon = [icon maskWithColor:self.theme.appTintColor];
    [pubKeyButton setImage:tintIcon forState:UIControlStateNormal];
    pubKeyButton.hidden = NO;
    pubKeyButton.userInteractionEnabled = YES;    
}

- (void)hideCreatePublicKeyButton
{
    _btnCreatePublicKey.hidden = YES;
}

// 1. hide btnCreatePublicKey, 2. unhide spinner, 3. start spinner
- (void)startCreatePublicKeySpinner
{
    [self hideCreatePublicKeyButton];
    _createPublicKeySpinner.hidden = NO;
    [_createPublicKeySpinner startAnimating];
}

// 1. stop spinner, 2. hide spinner, 3. show btnCreatePublicKey
- (void)stopCreatePublicKeySpinner
{
    [_createPublicKeySpinner stopAnimating];
    _createPublicKeySpinner.hidden = YES;
    [self showCreatePublicKeyButton];
}

/** 
 * Localized Help content is derived from the key/values defined in ConversationDetailsHelp.strings (the strings table),
 * the keys to which are attributes of an SCTHelpButton instance. This method sets the keys for Help content lookup 
 * derived from the class argument (expected to be the calling instance class).
 *
 * The keys naming convention: [class name].Help.title / [class name].Help.content, for example, 
 * ConversationDetailsVC.Help.title / ConversationDetailsVC.Help.content.
 *
 * These two strings are keys for lookup in the ConversationDetailsHelp.strings to the VC title and the HTML content
 * filename without extension, e.g., the "conversationDetails.Help.contentKey" key returns "ConversationDetailsHelp" 
 * which is returned by [SCTHelpManager stringForKey:btn.contentKey inTable:SCT_CONVERSATION_DETAILS_HELP] as 
 * "ConversationDetailsHelp.html". ConversationDetailsBaseVC initializes a HelpDetailsVC instance with the two key 
 * values from the SCTHelpButton.
 *
 * @param class The Class struct of the calling instance.
 */
- (void)showInfoButtonForClass:(Class)class
{
    if (NULL == class)
    {
        _btnHelpInfo.hidden = YES;
        return;
    }
    NSString *strClass = NSStringFromClass(class);
    NSString *prefix = [NSString stringWithFormat:@"%@.Help", strClass];
    _btnHelpInfo.titleKey = [NSString stringWithFormat:@"%@.title", prefix];
    _btnHelpInfo.contentKey = [NSString stringWithFormat:@"%@.content", prefix];
    _btnHelpInfo.hidden = NO;
}

#pragma mark - Actions

- (IBAction)handleAvatarTap:(id)sender
{
    if ([_delegate respondsToSelector:@selector(didTapAvatar:)])
    {
        [_delegate didTapAvatar:self];
    }
}

- (IBAction)keyInfoTapped:(id)sender
{
    DDLogCInfo(@"%sThis method not yet implemented",__PRETTY_FUNCTION__);
}

- (IBAction)handleHelpTap:(SCTHelpButton *)btn
{
    if ([_delegate respondsToSelector:@selector(didTapHelpButton:)])
    {
        [_delegate didTapHelpButton:btn];
    }
}

- (IBAction)handleCreatePublicKeyTap:(id)sender
{
    if ([_delegate respondsToSelector:@selector(didTapCreatePublicKey:)])
    {
        [_delegate didTapCreatePublicKey:sender];
    }
}

- (IBAction)handleConversationTap:(id)sender
{
    if ([_delegate respondsToSelector:@selector(didTapConversationButton:)])
    {
        [_delegate didTapConversationButton:sender];
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Update Data Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateConversation:(STConversation *)convo
{
    self.conversation = convo;
    self.user = nil;
    self.multiCastUsers = nil;
    [self updateAvatar];
    [self updateAllViews];
}

- (void)updateUser:(STUser *)aUser
{
    self.user = aUser;
    [self updateAvatar];
    [self updateAllViews];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Avatar Methods
#pragma mark  
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//ET06/21/15 
// ST897 - Collapse several avatar update methods to use new
// + AvatarManager cachedOrDefaultAvatarForConversation:user:diameter:theme:usage:

- (void)updateAvatarImage
{
    // fetch avatar if not system or voicemail conversation
    if (IsSTInfoJID(_conversation.remoteJid) || IsOCAVoicemailJID(_conversation.remoteJid))
    {
        [self updateAvatarWithDefaultImage];
    }
    else if (_conversation.isMulticast)
    {
        [[AvatarManager sharedInstance] fetchMultiAvatarForUsers:self.multiCastUsers
                                                    withDiameter:kAvatarDiameter 
                                                           theme:self.theme 
                                                           usage:kAvatarUsage_None 
                                                 completionBlock:^(UIImage *multiAvatar)
         {
             UIImage *img = nil;
             if (multiAvatar)
                 img = multiAvatar;
             else
                 img = [AvatarManager cachedOrDefaultAvatarForConversation:_conversation 
                                                                      user:nil 
                                                                  diameter:kAvatarDiameter 
                                                                     theme:self.theme 
                                                                     usage:kAvatarUsage_None];
             _userImageView.image = img;
         }];
    }
    else
    {
        [[AvatarManager sharedInstance] fetchAvatarForUser:self.user
                                              withDiameter:kAvatarDiameter
                                                     theme:self.theme 
                                                     usage:kAvatarUsage_None 
                                           completionBlock:^(UIImage *avatar) {
                                               
                                               UIImage *img = nil;
                                               if (avatar)
                                                   img = avatar;
                                               else
                                                   img = [AvatarManager cachedOrDefaultAvatarForConversation:_conversation 
                                                                                                        user:self.user
                                                                                                    diameter:kAvatarDiameter 
                                                                                                       theme:self.theme 
                                                                                                       usage:kAvatarUsage_None];
                                               _userImageView.image = img;
                                           }];
    }
}
#pragma mark Single Avatar Methods

/**
 * Invokes a method to update the avatar image for a point-to-point conversation, conditional on the conversationUser.
 *
 * This method takes an avatar identifier returned from `[AvatarManager avatarIdForUser:]`. If the identifier is string,
 * the `updateAvatarWithUserId:` is invoked, otherwise, the `user` is assumed to be a pseudo user and
 * `updateAvatarWithAbRecordId:` is invoked.
 *
- (void)updateUserAvatar
{
    // Fake stream handling:
	if (IsSTInfoJID(_conversation.remoteJid))
    {
        UIImage *avatarImage = [[AvatarManager sharedInstance] 
                                defaultSilentTextInfoUserAvatarWithDiameter:kAvatarDiameter];

        [self setAvatarImage:avatarImage withAnimation:YES];
        return;
    }
    
    id identifier = [[AvatarManager sharedInstance] avatarIdForUser:self.user];
    
    if ([identifier isKindOfClass:[NSString class]])
    {
        [self updateAvatarWithUserId:self.user.uuid];
    }
    else if ([identifier isKindOfClass:[NSNumber class]])
    {
        [self updateAvatarWithAbRecordId:[(NSNumber *)identifier intValue]];
    }
    // error or user is nil
    else 
    {
        DDLogError(@"%s ERROR: Unsupported Avatar identifier", __PRETTY_FUNCTION__);
        // edge case, remote user doesn't have user record in DB, (probably deleted)        
//        UIImage *avatar =  [[AvatarManager sharedInstance] defaultAvatarWithDiameter:kAvatarDiameter];
//        avatar = [avatar avatarImageWithDiameter:kAvatarDiameter usingColor:self.theme.appTintColor];        
//        _userImageView.image = avatar;
        _userImageView.image = [self defaultAvatarImageWithRingColor:nil]; // nil for default ringColor
    }
}
*/
/**
 * Updates the header view avatar image for a point-to-point conversation.
 *
 * This method first sets the avatar imageView with a cached avatar image, then invokes
 * `fetchAvatarForUserId:withDiameter:theme:usage:completionBlock:` with the given user id string. The imageView is
 * updated with the returned image in the method's completion block.
 *
 * @param aUserId The user.uuid string with which to fetch the avatar image.
 *
- (void)updateAvatarWithUserId:(NSString *)aUserId
{
    __block UIImage *avatarImage = [[AvatarManager sharedInstance] cachedAvatarForUserId:aUserId
                                                                            withDiameter:kAvatarDiameter
                                                                                   theme:self.theme
                                                                                   usage:kAvatarUsage_None];
    [[AvatarManager sharedInstance] fetchAvatarForUserId:aUserId
                                            withDiameter:kAvatarDiameter
                                                   theme:self.theme
                                                   usage:kAvatarUsage_None
                                         completionBlock:^(UIImage *avatar)
     {
         
         // 10
         // The cached image may be outdated and a recent webAPI fetch found a nil image.
         // Handle a nil image by setting with a default avatar
         avatarImage = (avatar) ?: [self defaultAvatarImageWithRingColor:nil];         
         [self setAvatarImage:avatarImage ];
     }];
}
*/
/**
 * Updates the header view avatar image for a point-to-point conversation.
 *
 * This method first sets the avatar imageView with a cached avatar image, then invokes
 * `fetchAvatarForABRecordID:withDiameter:theme:usage:completionBlock:` with the given abRecordId. The imageView is
 * updated with the returned image in the method's completion block.
 *
 * @param abRecordId The ABRecordID enum identifier with which to fetch the avatar image.
 *
- (void)updateAvatarWithAbRecordId:(ABRecordID)abRecordId
{
    __block UIImage *avatarImage = [[AvatarManager sharedInstance] cachedAvatarForABRecordID:abRecordId
                                                                                withDiameter:kAvatarDiameter
                                                                                       theme:self.theme
                                                                                       usage:kAvatarUsage_None];
    [[AvatarManager sharedInstance] fetchAvatarForABRecordID:abRecordId
                                                withDiameter:kAvatarDiameter
                                                       theme:self.theme
                                                       usage:kAvatarUsage_None
                                             completionBlock:^(UIImage *avatar)
     {
         if (avatar)
             avatarImage = avatar;
         
         [self setAvatarImage:avatarImage withAnimation:YES];
     }];
}
*/
/*
- (UIImage *)defaultAvatarImageWithRingColor:(UIColor *)ringColor
{
    // If passed nil, default to current theme tintColor
    ringColor = (ringColor) ?: self.theme.appTintColor;
    UIImage *avatar =  [[AvatarManager sharedInstance] defaultAvatarWithDiameter:kAvatarDiameter];
    avatar = [avatar avatarImageWithDiameter:kAvatarDiameter usingColor:ringColor];
    return avatar;
}
*/

//08/14/14 an interface for directly updating the image, without re-initializing user(s) data
- (UIImage *)avatarImage
{
    return _userImageView.image;
}

- (void)setAvatarImage:(UIImage *)anImage
{
    if (anImage == _userImageView.image)
        return;

    _userImageView.image = anImage;
}

- (void)setAvatarImage:(UIImage *)anImage withAnimation:(BOOL)animated
{
        //ET 10/14/14 DEPRECATE animation
    [self setAvatarImage:anImage];
    
//    if (anImage == _userImageView.image)
//        return;
//    
//    NSTimeInterval fadeOut = (animated && _userImageView.image) ? 0.35 : 0;
//    NSTimeInterval fadeIn = (animated) ? 0.25 : 0;
//    [UIView animateWithDuration:fadeOut 
//                     animations:^{
//                         _userImageView.alpha = 0.0;
//                     } 
//                     completion:^(BOOL finished) {
//                         [UIView animateWithDuration:fadeIn 
//                                          animations:^{
//                                              _userImageView.image = anImage;
//                                              _userImageView.alpha = 1.0;
//                         }];
//                     }];
    
}

#pragma mark Group Avatar Methods

/**
 * Updates the avatar image for a group conversation.
 *
- (void)updateGroupAvatar
{
    //08/15/14 use new AvatarManager method encapsulating the front/back avatarId accessors
    [[AvatarManager sharedInstance] fetchMultiAvatarForUsers:self.multiCastUsers
                                                withDiameter:kAvatarDiameter 
                                                       theme:self.theme 
                                                       usage:kAvatarUsage_None 
                                             completionBlock:^(UIImage *multiAvatar)
	{
		UIImage *img = nil;
		if (multiAvatar)
			img = multiAvatar;
		else
			img = [[AvatarManager sharedInstance] defaultMultiAvatarImageWithDiameter:kAvatarDiameter];
		
		_userImageView.image = img;
	}];
}
*/

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// END AVATAR METHODS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Accessors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This accessor initializes the user property ivar from the database with a user matching the conversation.remoteJid,
 * if the conversation is not nil and not multiCast; otherwise, passes through the ivar.
 */
- (STUser *)user
{
    if (nil == _user)
    {
        if (_conversation && !_conversation.isMulticast)
        {
            [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
				_user = [[DatabaseManager sharedInstance] findUserWithJID:_conversation.remoteJid
				                                              transaction:transaction];
            }];
            
            if (nil == _user)
                _user = [[DatabaseManager sharedInstance] tempUserWithJID:_conversation.remoteJid];
        }
    }
    return _user;
}

/**
 * This property is an array of STUser instances, self-initialized by querying the the database with the conversation
 * multicastJidSet. If a database user is not found for the multicastJid, a pseudo user is initialized and its 
 * abRecordId and isAutomaticallyLinkedToAB properties set. `multiCastUsers` instances are used to fetch a multiAvatar
 * composite image for a group conversation header view.
 */
- (NSArray *)multiCastUsers
{
    if (_conversation.isMulticast && nil == _multiCastUsers)
    {
        [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            _multiCastUsers = [STDatabaseManager multiCastUsersForConversation:_conversation withTransaction:transaction];
        }];
    }
    
    return _multiCastUsers;
}

// For popover in EditUserInfo / Contacts / iPad
- (CGRect)avatarImageRect
{
    return _userImageView.frame;
}

- (AppTheme *)theme 
{
    return STAppDelegate.theme;
}


@end
