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
#import "ConversationDetailsBaseVC.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AvatarManager.h"
#import "ConversationViewController.h"
#import "DatabaseManager.h"
#import "HelpDetailsVC.h"
#import "MessagesViewController.h"
#import "NewGroupInfoVC.h"
#import "UserInfoVC.h"
#import "SCTAvatarView.h"
#import "SCTHelpButton.h"
#import "SCTHelpManager.h"
#import "SilentTextStrings.h"
#import "STConversation.h"
#import "STDynamicHeightView.h"
#import "STLogging.h"
#import "STPreferences.h"
#import "STPublicKey.h" 
#import "STSymmetricKey.h"
#import "STUser.h"
// Catetgories
#import "UIImage+ImageEffects.h"
#import "UIImage+maskColor.h"


// Log levels: off, error, warn, info, verbose
#if DEBUG && eric_turner
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


@interface ConversationDetailsBaseVC ()
@end


@implementation ConversationDetailsBaseVC

@synthesize user = _user;


#pragma mark - Init & Dealloc

- (instancetype)initWithProperNib
{   
    DDLogAutoTrace();
    
    NSString *nibName = NSStringFromClass([self class]);
    self = [self initWithNibName:nibName bundle:nil];
    if (!self) return nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(databaseConnectionDidUpdate:)
                                                 name:UIDatabaseConnectionDidUpdateNotification
                                               object:STDatabaseManager];

    return self;
}

- (instancetype)initWithConversation:(STConversation *)convo
{
    DDLogAutoTrace();
    
    self = [self initWithProperNib];
    _conversation = convo;
    
    return self;
}

- (instancetype)initWithUser:(STUser *)aUser
{
    DDLogAutoTrace();
    
    self = [self initWithProperNib];
    _user = [aUser copy];
    
    return self;
}

//ET 12/16/14 DEPRECATED (moved to EditUserInfoVC) ST-871
//- (instancetype)initWithUser:(STUser *)aUser avatarImage:(UIImage *)avImg
//{
//    DDLogAutoTrace();
//    
//    self = [self initWithUser:aUser];
//    _avatarImage = avImg;
//    
//    return self;
//}

- (void)dealloc
{
	DDLogAutoTrace();
    self.navigationController.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
	DDLogAutoTrace();
    
    [super viewDidLoad];
    
    if (_loadAvatarViewFromNib)
    {
        [[NSBundle mainBundle] loadNibNamed:@"SCTAvatarView" owner:self options:nil];
        if (_user)
            [_avatarView updateUser:_user];
        else if (_conversation)
            [_avatarView updateConversation:_conversation];
        
        _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        _avatarView.delegate = self;
        
        UIView *avView = _avatarView;
        [self.avatarContainerView addSubview: avView];
        
        // Pin top/bottom
        NSArray *vConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[avView]|"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:NSDictionaryOfVariableBindings(avView)];
        // Pin sides
        NSArray *hConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[avView]|"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:NSDictionaryOfVariableBindings(avView)];
        [_avatarContainerView addConstraints:vConstraints];
        [_avatarContainerView addConstraints:hConstraints];    
        [_contentView setNeedsUpdateConstraints];
    }
    
    
    self.navigationItem.backBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@" ",@"BLANK TITLE")
                                     style:UIBarButtonItemStylePlain
                                    target:nil
                                    action:nil];

    [self.navigationController.navigationBar 
     setTitleTextAttributes:@{NSForegroundColorAttributeName:self.theme.navBarTitleColor}];

#pragma warning ET: How to handle theme colors?
        UIColor *bgColor = [UIColor colorWithWhite:0.95 alpha:1];
        self.view.superview.backgroundColor = bgColor;
        self.view.backgroundColor = bgColor;
        _containerView.backgroundColor = bgColor;
        _scrollView.backgroundColor = bgColor;
        _scrollView.alwaysBounceHorizontal = NO;
        _contentView.backgroundColor = bgColor;
        _avatarContainerView.backgroundColor = bgColor;
        _avatarView.backgroundColor = bgColor;
        
        self.navigationController.navigationBar.backgroundColor = bgColor;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Resizes the popover to fit, if in a popover/popoverPresentationController
    // -- not ready for prime-time:
    // ConversationDetailsVC sizes too short in popover on first load.
    // Current work in RefreshScrollView branch will address this
//    [self resetPopoverSizeIfNeeded]; 
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Header View Layout
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This base class implementation does nothing; subclasses should override with specific view configuration.
 * 
 * Note: subclasses should call super in case this base class implementation is updated.
 */
- (void)updateAllViews
{
    
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Utilities
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSLayoutConstraint *)heightConstraintFor:(UIView *)item
{
	for (NSLayoutConstraint *constraint in item.constraints)
	{
		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeHeight) ||
		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeHeight))
		{
			return constraint;
		}
	}
	
	return nil;
}

- (NSLayoutConstraint *)topConstraintFor:(id)item
{
    for (NSLayoutConstraint *constraint in self.view.constraints)
    {
        if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeTop) ||
            (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeTop))
        {
            return constraint;
        }
    }
    
    return nil;
}

/**
 * This method is queried * by our own code * when creating popover controllers.
 * It is conceptually similar to the deprecated contentSizeForViewInPopover method.
 **/
- (CGSize)preferredPopoverContentSize
{
	DDLogAutoTrace();
	
	// If this method is queried before we've loaded the view, then containerView will be nil.
	// So we make sure the view is loaded first.
	if (![self isViewLoaded]) {
		(void)[self view];
	}
	
//    CGFloat height = self.contentView.frame.size.height;
    CGFloat height = self.containerView.frame.size.height;
    
    // Note: If we just return the height,
    // then in iOS 8 the popover will continually get longer
    // everytime we bring up an action sheet.
    //
    // So its important that we use a calculated height (via intrinsicContentSize).
    
    if ([self.contentView isKindOfClass:[STDynamicHeightView class]])
//    if ([self.containerView isKindOfClass:[STDynamicHeightView class]])
    {
        CGSize size = [(STDynamicHeightView *)self.contentView intrinsicContentSize];
//        CGSize size = [(STDynamicHeightView *)self.containerView intrinsicContentSize];
        if (size.height != UIViewNoIntrinsicMetric)
        {
            height = size.height;
        }
    }
    
 	return CGSizeMake(320, height);
}

/**
 * This method is invoked automatically when the view is displayed in a popover.
 * The popover system uses this method to automatically size the popover accordingly.
 **/
- (CGSize)preferredContentSize
{
    DDLogAutoTrace();
    
    CGSize size = [self preferredPopoverContentSize];
    //	DDLogPink(@"preferredContentSize: %@", NSStringFromCGSize(size));
    
    return size;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - DB Listener / State Change
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//07/30/14 Conversation Notification listener
- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
    NSString *convoId = self.conversation.uuid;
    
    //09/15/14 w/RH: to fix refreshing avatarView in all living VCs when pull to refresh returns
    // ... was using local userID but needs to reference remote user
    NSString *localUserID = self.conversation.userId;
    
    // 09/16/14 VINNIE - you still need to lookup a conversation based on the localuserID
    __block STUser *remoteUser = nil;
    
    [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        remoteUser = [STDatabaseManager findUserWithJID:self.conversation.remoteJid transaction:transaction];
    }];
    NSString *remoteUserId = remoteUser.uuid;
    
    // Conversation Updage
	BOOL conversationChanged = [self.uiDbConnection hasChangeForKey:convoId
                                                     inCollection:localUserID
                                                  inNotifications:notifications];    
    if (conversationChanged)
    {
        [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {            
            self.conversation = [transaction objectForKey:convoId inCollection:localUserID];
        }];
        
        [self.avatarView updateConversation:_conversation];
        [self didChangeState];
        
        return;
    }
    
    // User update
    BOOL userChanged = [self.uiDbConnection hasChangeForKey:remoteUserId 
                                             inCollection:kSCCollection_STUsers 
                                          inNotifications:notifications];
    if (userChanged)
    {
        __block STUser *updatedUser = nil;
        [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            updatedUser = [transaction objectForKey:remoteUserId inCollection:kSCCollection_STUsers];
        }];
        
        self.user = updatedUser;
        
        // Updating the avatarView user causes its lazy-initialized properties to be reset, including the image.
        [self.avatarView updateUser:_user];
        
        [self didChangeState];
    }

}

/**
 * This method is invoked by databaseConnectionDidUpdate and invokes `updateAllViews`
 *
 * This method is invoked by databaseConnectionDidUpdate: when notified of a database connection update, which updates
 * the self conversation object. 
 */
- (void)didChangeState
{
    DDLogAutoTrace();
    // dbConnectionDidUpdate calls this method for changes to conversation or user
    // subclasses should override if special handling required
    [self updateAllViews];
}


#pragma mark - AvatarViewDelegate

- (void)didTapAvatar:(SCTAvatarView *)aView
{
    [self handleAvatarAction:aView];
}

- (void)didTapHelpButton:(SCTHelpButton *)btn
{    
    [self presentHelpWithButton:btn];
}

- (void)didTapConversationButton:(id)sender
{
    [self popOutOfPresentationContainer];
}

/**
 * On iPhone, pops back to the root view controller. On iPad, dismisses the containing popover.
 */
- (void)popOutOfPresentationContainer
{
    id controller = self.presentingController;
    
    if (AppConstants.isIPhone && controller)
    {
        self.navigationController.delegate = nil;
        [self.navigationController popToViewController:(UIViewController *)controller animated:YES];
    }
    else if ([_delegate respondsToSelector:@selector(viewController:needsDismissPopoverAnimated:)])
    {
        [_delegate viewController:self needsDismissPopoverAnimated:YES];
    }
}


+ (void)popToConversation:(NSString *)conversationId
{
    DDLogAutoTrace();
    
    STAppDelegate.conversationViewController.selectedConversationId = conversationId;
    
    if (AppConstants.isIPhone)
    {
        UINavigationController *nav = STAppDelegate.conversationViewController.navigationController;
        
        // Figure out if there's a messagesViewController on the stack.
        
        MessagesViewController *messagesViewController = nil;
        
        NSMutableArray *viewControllers = [nav.viewControllers mutableCopy];
        while ([viewControllers count] > 1)
        {
            UIViewController *viewController = [viewControllers lastObject];
            
            if ([viewController isKindOfClass:[MessagesViewController class]])
            {
                messagesViewController = (MessagesViewController *)viewController;
                break;
            }
            else
            {
                [viewControllers removeLastObject];
            }
        }
        
        // Figure out what the revealController is displaying
        
        BOOL frontIsMain = STAppDelegate.revealController.frontViewController == STAppDelegate.mainViewController;
        
        // Provide the proper animation
        
        if (messagesViewController)
        {
            if (frontIsMain)
            {
                [nav popToViewController:messagesViewController animated:YES];
                messagesViewController.conversationId = conversationId;
            }
            else
            {
                [nav popToViewController:messagesViewController animated:NO];
                messagesViewController.conversationId = conversationId;
                
                //ST-1001: SWRevealController v2.3 update
//                [STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController animated:YES];
                [STAppDelegate.revealController pushFrontViewController:STAppDelegate.mainViewController animated:YES];
            }
        }
        else
        {
            messagesViewController = [STAppDelegate createMessagesViewController];
            messagesViewController.conversationId = conversationId;
            
            if (frontIsMain)
            {
                [nav popToRootViewControllerAnimated:NO];
                [nav pushViewController:messagesViewController animated:NO];
            }
            else
            {
                [nav popToRootViewControllerAnimated:NO];
                [nav pushViewController:messagesViewController animated:NO];
                
                //ST-1001: SWRevealController v2.3 update
//                [STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController animated:YES];
                [STAppDelegate.revealController pushFrontViewController:STAppDelegate.mainViewController animated:YES];
            }
        }
    }
    else
    {
        //ST-1001: SWRevealController v2.3 update
//        [STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController animated:YES];
        [STAppDelegate.revealController pushFrontViewController:STAppDelegate.mainViewController animated:YES];
    }
}

- (void)popToConversation:(NSString *)conversationId {
	[ConversationDetailsBaseVC popToConversation:conversationId];
	if (!AppConstants.isIPhone) {
		if ([_delegate respondsToSelector:@selector(viewController:needsDismissPopoverAnimated:)]) {
			[_delegate viewController:self needsDismissPopoverAnimated:YES];
		}
	}
}

#pragma mark - Avatar Action

/**
 * This method messages the ConversationDetailsDelegate when avatar, title, or subtitle, is tapped.
 *
 * Note: results vary according to device. For iPhone, the delegate pushes an instance of groupInfoVC or
 * userInfoVC onto the navigation stack.
 *
 * @param sender The tap gesture recognizer on the header view avatar imageView, title label, or subtitle label.
 */
- (void)handleAvatarAction:(SCTAvatarView *)aView
{
	DDLogAutoTrace();
    
    // Do push on a VC if this is a system messages "conversation"
    if (_conversation.isFakeStream)
        return;
    
    UIViewController *vc = nil; // ET new
    if (_conversation.multicastJidSet.count)
        vc = [self newGroupInfoVC];
    else
        vc = [self newUserInfoVC];
    
    if (vc)
        [self navigateToViewController:vc];
}

// Generic for both the GroupInfoVC controller delegate row tap, and p2p convo user vc
- (UserInfoVC *)newUserInfoVC
{
    UserInfoVC *userInfoVC = [[UserInfoVC alloc] initWithUser:self.user];    
    userInfoVC.conversation = self.conversation;
    userInfoVC.presentingController = self.presentingController;
    userInfoVC.delegate = self.delegate;

    userInfoVC.isInPopover = (AppConstants.isIPhone) ? NO : YES;
    return userInfoVC;
}


#pragma mark - GroupViewController/Delegate Methods

- (NewGroupInfoVC *)newGroupInfoVC
{
    NewGroupInfoVC *groupInfoVC = [[NewGroupInfoVC alloc] initWithProperNib];
    groupInfoVC.conversation = self.conversation;
    groupInfoVC.groupAvatarImage = self.avatarView.avatarImage;
    groupInfoVC.participantsTitle = self.avatarView.lblOrganizationName.text;
    groupInfoVC.multiCastUsers = self.avatarView.multiCastUsers;
    
    groupInfoVC.isInPopover = (AppConstants.isIPhone) ? NO : YES;
    groupInfoVC.delegate = (id) _delegate;
    return groupInfoVC;
}


/**
 * This method instantiates a conversation security details view controller and pushes it onto the nav stack.
 *
 * The navigationController delegate, if any, is cached in the `cachedNavDelegate` property and restored in the
 * navigationController:willShowViewController:animated: method.
 *
 * Note: the security details VC delegate (MessagesViewController) is set with the self delegate instance for 
 * delegate callbacks related to encryption, e.g. resetting keys.
 *
 * @see NavigationControllerDelegate Methods
 */
- (void)navigateToViewController:(UIViewController *)vc
{
    _cachedNavDelegate = self.navigationController.delegate;
    self.navigationController.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
    if ([vc respondsToSelector:@selector(presentingController)])
    {
        [vc setValue:_presentingController forKey:@"presentingController"];
    }
}

#pragma mark NavigationControllerDelegate Methods

- (void)navigationController:(UINavigationController *)navigationController 
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (viewController == self)
    {
        navigationController.delegate = _cachedNavDelegate;
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Help
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
 * Called by SCTAvatarViewDelegate callback to present Help controller
 * 
 * Configure SCTHelpButton in IB with titleKey == HelpFileName.html
 */
- (void)presentHelpWithButton:(SCTHelpButton *)btn
{
    // Do not navigate to a help view unless the sender button has a titleKey value (set in IB)
    if (! [btn isKindOfClass:[SCTHelpButton class]] || nil == btn.titleKey)
    {   
        return;
    }

    self.navigationItem.backBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@" ",@"BLANK TITLE")
                                     style:UIBarButtonItemStylePlain
                                    target:nil
                                    action:nil];

    NSString *localizedHTMLFilename = [SCTHelpManager stringForKey:btn.contentKey inTable:SCT_CONVERSATION_DETAILS_HELP];
    HelpDetailsVC *vc = [[HelpDetailsVC alloc] initWithName:localizedHTMLFilename
                                                    bgImage:[SCTHelpManager bgImageFromSubView:_containerView 
                                                                                    parentView:self.view]];
    
    if (self.navigationController.delegate != self)
    {
        self.cachedNavDelegate = self.navigationController.delegate;
        self.navigationController.delegate = self;
    }
    [self.navigationController pushViewController:vc animated:YES];
    
    vc.navigationItem.title = [SCTHelpManager stringForKey:btn.titleKey inTable:SCT_CONVERSATION_DETAILS_HELP];
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    id<UIViewControllerAnimatedTransitioning> animator = nil; // returning nil results in default navigation transition
    
    Class helpClass = [HelpDetailsVC class];
    if ([fromVC isKindOfClass:helpClass] || [toVC isKindOfClass:helpClass])
    {
        animator = self;
    }
    
    return animator;
}


- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext 
{
//    return 0.75f;
    return 0.5f;
}

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext 
{
    UIView *containerView = [transitionContext containerView];
    
    
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    [containerView addSubview:fromVC.view];
    
    UIViewController *toVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    [containerView addSubview:toVC.view];

    UIViewAnimationOptions animationOption = ([fromVC isKindOfClass:[HelpDetailsVC class]]) ?
                            UIViewAnimationOptionTransitionCrossDissolve : UIViewAnimationOptionTransitionNone;
    
    [UIView transitionFromView:fromVC.view
                        toView:toVC.view
                      duration:[self transitionDuration:transitionContext]
                       options:animationOption
                    completion:^(BOOL finished) {
                        [transitionContext completeTransition:YES];
                    }];
}


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

- (YapDatabaseConnection *)uiDbConnection
{
    return STDatabaseManager.uiDatabaseConnection;
}

- (AppTheme *)theme 
{
    return STAppDelegate.theme;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Popover Resizing Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isPresentedIniOS7Popover
{
    BOOL isiOS7Popover = [self.presentingController isKindOfClass:[UIPopoverController class]];
    return isiOS7Popover;
}

- (BOOL)isPresentedIniOS8Popover
{
    BOOL isiOS8Popover = [self.presentingController respondsToSelector:@selector(popoverPresentationController)];
    return isiOS8Popover;
}

// Should only be called by resetPopoverSizeIfNeeded which does the if-iOS7/8-inPopover check
- (void)resetPreferredContentSize
{
    if ([self isPresentedIniOS7Popover])
    {
        [self setPreferredContentSize:[self preferredContentSize]];
        [(UIPopoverController *)self.presentingController setPopoverContentSize:self.preferredContentSize 
                                                                       animated:YES];
    }
    else
        [self.presentingController setPreferredContentSize:[self preferredContentSize]];
}

- (void)resetPopoverSizeIfNeeded
{
    if ([self isPresentedIniOS7Popover] || [self isPresentedIniOS8Popover])
        [self resetPreferredContentSize]; 
}

@end
