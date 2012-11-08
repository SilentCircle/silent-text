/*
Copyright © 2012, Silent Circle
All rights reserved.

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
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#define DEBUG_PASSCODE 0

#import "SettingsViewController.h"
#import "SCProvisoningManager.h"
#import "SCPasscodeManager.h"

#import "ProvisionViewController.h"
#import "PasscodeViewController.h"

#import "SCAccount.h"
#import "XMPPServer.h"
#import "App.h"
#import <SCloud.h>
#import "GeoTracking.h"
 
static NSTimeInterval  kTimeoutTable[] = { 0, 5, 60, 60*5, 60 *15, 60 *60, 60*60*4, DBL_MAX};


NSString* timeOutString (NSTimeInterval elapsed)
{
    
#define kMinute 60
#define kHour  (60 * 60)
    
    if(elapsed == DBL_MAX)
    {
        return [NSString stringWithFormat:NSLS_COMMON_NEVER];
    }
   else if (elapsed == 0) {
        return NSLS_COMMON_NOW;
    }
    else if (elapsed < kMinute) {
        int seconds = (int)(elapsed);
        return [NSString stringWithFormat:NSLS_COMMON_SECONDS, seconds];
        
    }
    else if (elapsed == kMinute) {
        return NSLS_COMMON_MINUTE ;
        
    }
    else if (elapsed < kHour) {
        int mins = (int)(elapsed/kMinute);
        return [NSString stringWithFormat:NSLS_COMMON_MINUTES, mins];
    }
    else if (elapsed == kHour) {
        return  NSLS_COMMON_HOUR ;
        
    }
   else {
        int hours = (int)(elapsed/kHour);
        return [NSString stringWithFormat:NSLS_COMMON_HOURS, hours];
    } 
    
}


@interface SettingsViewController ()
@property (nonatomic, strong)  UIImage *bgImage;
@property (strong, nonatomic) UIActionSheet     *actionSheet;

 
@end

@implementation SettingsViewController
 

NSString *const kGeoTrackingKey = @"GeoTracking";
NSString *const kEnablePasscodeKey = @"Passcode1";
NSString *const kChangePasscodeKey = @"Passcode2";
NSString *const kPasscodeTimeoutKey = @"passcodeTimeout";
NSString *const kPasscodeTimeoutSectionKey = @"passcodeTimeoutSection";
NSString *const kPasscodeDebugingSectionKey = @"passcodeDebuggingSection";

NSString *const kCopyrightSectionKey = @"Copyright";

NSString *const kPrivacySectionKey = @"Privacy";
NSString *const kLicencesSectionKey = @"Licences";

@synthesize bgImage = _bgImage;
@synthesize actionSheet = _actionSheet;

#pragma mark - About
 

 
+ (QRootElement *)createAboutRoot {
 
    App *app = App.sharedApp;
 
    QRootElement *root = [[QRootElement alloc] init];
    root.title = @"About";
    root.grouped = YES;
    
	QSection *subsection = [[QSection alloc] init];
    
    [root addSection:subsection];
	  
    NSBundle *main = NSBundle.mainBundle;
    NSString *version = [main objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    NSString *build   = [main objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
    NSString *appVersion = [NSString stringWithFormat: @"%@ (%@)", version, build];
    
    char scimp_version_string[32];
    SCimpGetVersionString(sizeof(scimp_version_string) , scimp_version_string);
    char scloud_version_string[32];
    SCloudGetVersionString(sizeof(scloud_version_string) , scloud_version_string);
    
    [subsection addElement:[[QLabelElement alloc]
                            initWithTitle:@"Silent Text"
                            Value:appVersion]];
    
    [subsection addElement:[[QLabelElement alloc]
                            initWithTitle:@"SCIMP"
                            Value:[NSString stringWithFormat: @"%s", scimp_version_string]]];
    
    [subsection addElement:[[QLabelElement alloc]
                            initWithTitle:@"SCloud"
                            Value:[NSString stringWithFormat: @"%s", scloud_version_string]]];
    
    
    QSection *subsection2 = [[QSection alloc] init];
    
    [root addSection:subsection2];
    
    [subsection2 addElement:[[QLabelElement alloc]
                             initWithTitle:[[XMPPJID jidWithString: app.currentAccount.username] bare]
                             Value: [app.xmppServer.xmppStream isAuthenticated]?@"✓":@"x"]];
#if DEBUG
/*    [subsection2 addElement:[[QLabelElement alloc]
                             initWithTitle: app.currentAccount.serverDomain
                             Value:  @""]];
    
*/    QTextElement *element2 = [[QTextElement alloc] initWithText: app.pushToken?app.pushToken:@"- none -"];
    
    [subsection2 addElement:element2];


    QButtonElement *myButton = [[QButtonElement alloc] initWithTitle:@"Reset User Settings"];
    myButton.controllerAction = @"handleResetUser:";
    [subsection2 addElement:myButton];
#endif
    return root;
}

#pragma mark - Licences

+ (QRootElement *)createLicenceRoot {
    static NSString *const kLicenses = @"Licenses";
    static NSString *const kTXT      = @"txt";
    
    NSURL *url = [NSBundle.mainBundle URLForResource: kLicenses withExtension: kTXT];
    NSString *text = [NSString stringWithContentsOfURL: url encoding: NSUTF8StringEncoding error: nil];

    QRootElement *root = [[QRootElement alloc] init];
    root.title = @"Licenses";

    
    QTextElement *element1 = [[QTextElement alloc] initWithText: text];
      element1.font = [UIFont systemFontOfSize:14];
    element1.color = [UIColor whiteColor];
    
    QSection *section1 = [[QSection alloc] init];
    section1.key = kLicencesSectionKey;
    [section1 addElement:element1];
    [root addSection:section1];
    return root;
}
 
#pragma mark - Privacy

+ (QRootElement *)createPrivacyRoot {
    static NSString *const kPrivacy = @"Privacy";
    static NSString *const kTXT      = @"txt";
    
    NSURL *url = [NSBundle.mainBundle URLForResource: kPrivacy withExtension: kTXT];
    NSString *text = [NSString stringWithContentsOfURL: url encoding: NSUTF8StringEncoding error: nil];
    
    QRootElement *root = [[QRootElement alloc] init];
    root.title = @"Privacy Statement";
    
    QTextElement *element1 = [[QTextElement alloc] initWithText: text];
    element1.font = [UIFont systemFontOfSize:14];
    element1.color = [UIColor whiteColor];
    
    QSection *section1 = [[QSection alloc] init];
    section1.key = kPrivacySectionKey;

    [section1 addElement:element1];
    [root addSection:section1];
    return root;
}

#pragma mark - Passcode


 

+ (QRadioElement*)createPasscodeTimeoutButton
{
    App *app = App.sharedApp;
    NSTimeInterval selectedTimeout = app.passcodeManager.passcodeTimeout;

    NSMutableArray  *timeoutText = NSMutableArray.new;
    NSMutableArray  *timeoutValues = NSMutableArray.new;
    
    int selectedIndex = 0;

    int count = sizeof(kTimeoutTable) / sizeof(NSTimeInterval);
    
     for(int index = 0;  index < count;  index++ )
    {
        NSTimeInterval timeout = kTimeoutTable[index];
        if(timeout == selectedTimeout) selectedIndex = index;
        [timeoutText addObject:timeOutString( timeout)];
        [timeoutValues addObject:[NSNumber numberWithDouble: timeout]];
        
    }
   
    QRadioElement *radioElement = [[QRadioElement alloc] initWithItems: timeoutText
                                                               selected: selectedIndex
                                                                 title:@"Require Passcode"];

    radioElement.key = kPasscodeTimeoutKey;
    radioElement.controllerAction = @"handleChangeTimeout:";
     
    return radioElement;
}


+ (QLabelElement *)createPasscodeRoot {
    
    App *app = App.sharedApp;
    BOOL hasPasscode = (app.passcodeManager.hasPasscode);

    QLabelElement *root = [[QLabelElement alloc] init];
    
    root.title = @"Passcode Lock";
    root.grouped = YES;
    root.value = hasPasscode ?@"On":@"Off";
    
    QSection *section1 = [[QSection alloc] init];
     [root addSection:section1];
    
    QButtonElement *button1 = [[QButtonElement alloc] initWithTitle:
                               hasPasscode?@"Turn Passcode Off":@"Turn Passcode On"];
    button1.controllerAction = @"handleEnablePasscode:";
    button1.key = kEnablePasscodeKey;
    
    [section1 addElement:button1];

   if(hasPasscode)
   {
       QButtonElement *button2 = [[QButtonElement alloc] initWithTitle:@"Change Passcode"];
       button2.controllerAction = @"handleChangePasscode:";
       button2.key = kChangePasscodeKey;
       [section1 addElement:button2];
       
   }
    
    QSection *section2 = [[QSection alloc] init];
    section2.key = kPasscodeTimeoutSectionKey;
    [root addSection:section2];
    
    QRadioElement *radioElement = [SettingsViewController createPasscodeTimeoutButton];
    
    [section2 addElement:radioElement];
    
  
#if DEBUG_PASSCODE
    /* debug */
    QSection *section3 = [[QSection alloc] init];
    section3.key = kPasscodeDebugingSectionKey;
    [root addSection:section3];

  /*debug*/
#endif
   
return root;
    
}


#pragma mark - actions


-(void)handleEnablePasscode:(QElement *)element{
   
    App *app = App.sharedApp;
    BOOL hasPasscode = (app.passcodeManager.hasPasscode);

    PasscodeViewController *pvc = [PasscodeViewController.alloc
                                   initWithNibName: @"PasscodeViewController"
                                   bundle: nil
                                   mode:hasPasscode
                                   ?PasscodeViewControllerModeRemove
                                   :PasscodeViewControllerModeCreate];

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel",nil)
                                                                                style:UIBarButtonItemStyleBordered
                                                                            target:nil
                                                                           action:nil];

    [self.navigationController pushViewController: pvc animated: YES];
  
 }


-(void)handleChangePasscode:(QElement *)element{
    
    
    PasscodeViewController *pvc = [PasscodeViewController.alloc
                                   initWithNibName: @"PasscodeViewController"
                                   bundle: nil
                                   mode: PasscodeViewControllerModeChange];
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel",nil)
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:nil
                                                                            action:nil];
 [self.navigationController pushViewController: pvc animated: YES];

}

#define NSLS_COMMON_RESET_USER @"Reset User Settings"
#define NSLS_COMMON_RESET_USER_DESCRIPTION @"This will delete all Silent Text user settings. Requiring you to re-activate your account"

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *choice = [actionSheet buttonTitleAtIndex:buttonIndex];
    
    if ([choice isEqualToString:NSLS_COMMON_RESET_USER])
    {
        
        [SCProvisoning resetProvisioning];
        ProvisionViewController *pvc = [ProvisionViewController.alloc initWithNibName: nil bundle: nil];
        
        [self.navigationController presentViewController: pvc
                                                animated: YES
                                              completion: ^{ [self.navigationController popViewControllerAnimated: NO]; }];
    }

}

-(void)handleResetUser:(QElement *)element{

    
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle:NSLS_COMMON_RESET_USER_DESCRIPTION
                                  delegate:self
                                  cancelButtonTitle:NSLS_COMMON_CANCEL
                                  destructiveButtonTitle:NSLS_COMMON_RESET_USER
                                  otherButtonTitles: nil ];
    
    [actionSheet showInView:self.view ];

}

-(void)handleChangeTracking:(QElement *)element{
 
   QBooleanElement* sw = (QBooleanElement*) element;
    App *app = App.sharedApp;
   app.geoTracking.tracking = sw.boolValue;
    
}
-(void)handleChangeTimeout:(QElement *)element{
    
    QRadioElement* radio = (QRadioElement*) element;
    App *app = App.sharedApp;
     
    app.passcodeManager.passcodeTimeout  = kTimeoutTable[ radio.selected ];
    
}



-(void)handleUnlockPasscode:(QElement *)element{
    
    
    PasscodeViewController *pvc = [PasscodeViewController.alloc
                                   initWithNibName: @"PasscodeViewController"
                                   bundle: nil
                                   mode: PasscodeViewControllerModeVerify];
    
    UINavigationController *navigation =
            [[UINavigationController alloc] initWithRootViewController:pvc];
    
    [self presentModalViewController:navigation animated:YES];
   
    [self refreshElements];

}


-(void)handleLockPasscode:(QElement *)element{
    
    App *app = App.sharedApp;

    [app.passcodeManager lock];
    [self refreshElements];
     
}


#pragma mark - settings form

+ (QRootElement *)createSettingsForm
{
    App *app = App.sharedApp;

    QRootElement *form = [[QRootElement alloc] init];
    QRootElement  *locationElement = NULL;
    
    form.grouped = YES;
    form.controllerName = @"SettingsViewController";
    form.title = NSLS_COMMON_SETTINGS;
   
	QSection *section1 = [[QSection alloc] init];
     
    [section1 addElement: [self createPasscodeRoot]];
     
    if(app.geoTracking.allowTracking )
    {
        locationElement = [[QBooleanElement alloc] initWithTitle: @"Location Services" BoolValue: app.geoTracking.isTracking ];
        locationElement.controllerAction = @"handleChangeTracking:";
        
     }
    else
    {
        locationElement = [[QLabelElement alloc] initWithTitle: @"Location Services" Value:@"Disabled" ];
    }
	
    locationElement.key = kGeoTrackingKey;
    [section1 addElement:locationElement];
    [form addSection:section1];
	    
    QSection *subsection2 = [[QSection alloc] init];
    [subsection2 addElement: [self createAboutRoot]];
    [subsection2 addElement: [self createPrivacyRoot]];
    [subsection2 addElement: [self createLicenceRoot]];
    [form addSection:subsection2];
    
    QSection *subsection3 = [[QSection alloc] init];
    subsection3.key = kCopyrightSectionKey;
    [form addSection:subsection3];
     
 //   subsection2.footer = @"Copyright © 2012,\n Silent Circle, LLC, All Rights Reserved.";

    return form;
}

- (void)setQuickDialogTableView:(QuickDialogTableView *)aQuickDialogTableView {
    [super setQuickDialogTableView:aQuickDialogTableView];
    
    
    if(!self.bgImage)
    {
        self.bgImage = [UIImage  imageNamed:@"logoicon"];
    }
    
     self.quickDialogTableView.bounces = YES;
    self.quickDialogTableView.styleProvider = self;
//    self.quickDialogTableView.separatorColor = [UIColor blackColor];
    self.quickDialogTableView.backgroundView  = [[UIView alloc] initWithFrame:self.view.frame];
	//    self.quickDialogTableView.backgroundView  = [[UIImageView alloc] initWithImage:self.bgImage];
	self.quickDialogTableView.backgroundView.backgroundColor = [UIColor blackColor];
//	self.quickDialogTableView.backgroundView.frame = self.view.frame;
//	self.quickDialogTableView.backgroundView.contentMode = UIViewContentModeBottom;
	//    self.quickDialogTableView.backgroundView.contentMode = UIViewContentModeScaleToFill;

}
 
-(void) cell:(UITableViewCell *)cell willAppearForElement:(QElement *)element atIndexPath:(NSIndexPath *)indexPath
{
 //   QElement *passTS  =  [self.root elementWithKey:kPasscodeTimeoutKey];

 
   if( [element isKindOfClass:[QRadioItemElement class]])
    {
        cell.backgroundColor  = [UIColor whiteColor];
        
        
    }
 }

-(void) sectionFooterWillAppearForSection:(QSection *)section atIndex:(NSInteger)indexPath
{
    
    QSection *copyrightSection  =  [self.root sectionWithKey:kCopyrightSectionKey];

    if(section == copyrightSection)
    {
        UILabel* label = NULL;
        
        label = [[UILabel alloc] initWithFrame:CGRectMake( 0,  0 , 300, 60)];
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor orangeColor];
        label.lineBreakMode = UILineBreakModeWordWrap;
        label.numberOfLines = 2;
        label.font = [UIFont boldSystemFontOfSize:14];
        label.textAlignment = UITextAlignmentCenter;
        label.text = @"Copyright © 2012,\n Silent Circle, All Rights Reserved.";
		label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

		UIImageView	*logo = [[UIImageView alloc] initWithImage:self.bgImage];
		logo.backgroundColor = [UIColor clearColor];
		logo.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

		UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, label.frame.size.width, label.frame.size.height + logo.frame.size.height + 10)];
		label.center = footerView.center;
		label.frame = CGRectMake(label.frame.origin.x, 0, label.frame.size.width, label.frame.size.height);
		logo.center = footerView.center;
		logo.frame = CGRectMake(logo.frame.origin.x, footerView.frame.size.height - logo.frame.size.height, logo.frame.size.width, logo.frame.size.height);
		[footerView addSubview:logo];
		[footerView addSubview:label];
        section.footerView = footerView;
    }
    
}

  
- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) toInterfaceOrientation {
    
    return YES;//(toInterfaceOrientation == UIInterfaceOrientationPortrait);
    
} // -shouldAutorotateToInterfaceOrientation:



- (void) refreshElements
{
    QEntryElement *geoEntry  = (QEntryElement *) [self.root elementWithKey:kGeoTrackingKey];
    QEntryElement *pass1Entry  = (QEntryElement *) [self.root elementWithKey:kEnablePasscodeKey];
    QEntryElement *pass2Entry  = (QEntryElement *) [self.root elementWithKey:kChangePasscodeKey];
    QSection *passTS  =  [self.root sectionWithKey:kPasscodeTimeoutSectionKey];
     
    App *app = App.sharedApp;
    
    if(pass1Entry || pass2Entry)
    {
        BOOL hasPasscode = (app.passcodeManager.hasPasscode);
        QSection *section = pass1Entry.parentSection;
        QLabelElement *root  = (QLabelElement*) section.rootElement;
        root.value = hasPasscode ?@"On":@"Off";
        
        if(pass1Entry)
        {
            pass1Entry.title = hasPasscode?@"Turn Passcode Off":@"Turn Passcode On" ;
        }
           
        if(hasPasscode)
        {
            QButtonElement *button2 = [[QButtonElement alloc] initWithTitle:@"Change Passcode"];
            button2.controllerAction = @"handleChangePasscode:";
            button2.key = kChangePasscodeKey;
            
            if(pass2Entry)
            {
                int index = [section indexOfElement: pass2Entry];
                [section.elements replaceObjectAtIndex:index  withObject:button2];
            }
            else
            {
                [section.elements addObject: button2];
            }
            
            [passTS.elements removeAllObjects];
            QRadioElement *radioElement = [SettingsViewController createPasscodeTimeoutButton];
            [passTS addElement:radioElement];
     
        }
        else
        {
            if(pass2Entry)
            {
                int index = [section indexOfElement: pass2Entry];
                [section.elements removeObjectAtIndex: index ];
            }
            
            [passTS.elements removeAllObjects];
               
        }
    }
    if(geoEntry)
    {
        QRootElement  *locationElement = NULL;
        QSection *section = geoEntry.parentSection;
        if(section.elements)
        {
            
            if(app.geoTracking.allowTracking)
            {
                locationElement = [[QBooleanElement alloc] initWithTitle: @"Location Services" BoolValue: app.geoTracking.isTracking ];
                locationElement.controllerAction = @"handleChangeTracking:";
            }
            else
            {
                locationElement = [[QLabelElement alloc] initWithTitle: @"Location Services" Value:@"Disabled" ];
                app.geoTracking.tracking = NO;
            }
            
            locationElement.key = kGeoTrackingKey;
            locationElement.parentSection = section;
            int index = [section indexOfElement: geoEntry];
            
            [section.elements replaceObjectAtIndex:index  withObject:locationElement];
            
        }
    }
     
#if DEBUG_PASSCODE
    {
        QSection *dpSection  =  [self.root sectionWithKey:kPasscodeDebugingSectionKey];

        [dpSection.elements removeAllObjects];
        if(app.passcodeManager.hasPasscode)
        {
            QButtonElement *test = NULL;
            if(app.passcodeManager.isLocked)
            {
                test = [[QButtonElement alloc]  initWithTitle: @"Unlock"];
                test.controllerAction = @"handleUnlockPasscode:";
                                                        
            }
            else
            {
                test = [[QButtonElement alloc] initWithTitle: @"Lock"];
                test.controllerAction = @"handleLockPasscode:";
                
            }
              [dpSection addElement:test];
          
        }
  
    }
#endif
    
    [self.quickDialogTableView reloadData];
    
}

#define kBecomeActive  (@selector(becomeActive:))
- (void) becomeActive: (NSNotification *) notification
{
    [self refreshElements];
}

-(void) loadView
{
    [super loadView];
      
}


- (void)viewWillAppear:(BOOL)animated {
#warning: I'm commenting this out since I i don't think it is needed.  No?  Any reason why this code is needed???
	
	
// stupid hacker to get around quickdialog bugs
    //   if(!self.quickDialogTableView.backgroundView)
//   {
//       self.quickDialogTableView.backgroundView  = [[UIImageView alloc] initWithImage:self.bgImage];
//       self.quickDialogTableView.backgroundView.contentMode = UIViewContentModeScaleToFill;
//    }

    [self refreshElements];
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    
    //    [self.searchBar becomeFirstResponder];
    [super viewDidAppear:animated];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver: self
           selector:  kBecomeActive
               name: UIApplicationDidBecomeActiveNotification
             object: nil];
    
}

- (void)viewDidDisappear:(BOOL)animated {
    
      [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    
}


@end
