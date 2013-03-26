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
//  STFwdViewController.m
//  SilentText
//

#import "App.h"
#import "App+Model.h"
#import "ConversationManager.h"
#import "XMPPJID.h"
#import "XMPPJID+AddressBook.h"
#import "ConversationViewTableCell.h"

#import "STFwdViewController.h"


@interface fwdTableItem : NSObject

@property (nonatomic, copy) NSString *nameString;
@property (nonatomic, copy)  XMPPJID *jid;
@end

@implementation fwdTableItem;

@synthesize nameString = _nameString;
@synthesize jid = _jid;

+ (fwdTableItem *)itemWithJid:(XMPPJID *)jid username:(NSString *)nameString
{
    
    fwdTableItem *item = [[fwdTableItem alloc] init];
    item.jid = [jid copy];
    item.nameString = [nameString copy];
    return item;
}

@end;

static NSString *const kAvatarIcon = @"avatar"; //@"silhouette";


@interface STFwdViewController ()
@property (nonatomic, strong) XMPPJID     *selectedJid;
@property (nonatomic, strong) NSArray     *jidArray;
@property (nonatomic, strong) NSArray     *allItems;

@property (nonatomic, retain) UIImage     *avatarImage;
@property (nonatomic, copy)     Siren       *siren;

@property  (nonatomic) BOOL inFWDController;
@end

@implementation STFwdViewController

 @synthesize selectedJid     = _selectedJid;
@synthesize jidArray        = _jidArray;



/* this controller gets used in two ways,
 1) as a standalone controller from the Forward text menu   - inFWDController = YES
 2) as a part of the UIactivity dialog when IOS is asked to open the file with Silent Text - inFWDController = NO
 */


-(id)initWithSiren:(Siren *)siren {
    if (!(self = [super initWithNibName:@"STFwdViewPushedController" bundle:nil])) return nil;

    self.siren = siren;
    self.avatarImage =  [UIImage imageNamed: kAvatarIcon];
    self.toolBar.hidden = YES;
    _inFWDController = YES;
    
    self.navigationItem.title = NSLocalizedString(@"Forward to", @"Forward to");

    self.navigationItem.rightBarButtonItem =
    [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                target:self
                                                action:@selector(fwdButtonItem:)];
    
    self.navigationItem.rightBarButtonItem.enabled = NO;

    return self;
    
}

-(id)initWithImage:(UIImage *)imageObject {
    if (!(self = [super initWithNibName:@"STFwdViewController" bundle:nil])) return nil;
    
    UIImage *exportImage = imageObject; // [UIImage imageWithCGImage:imageObject.CGImage scale:imageObject.scale orientation:UIImageOrientationUp];
    
    _inFWDController = NO;
    
    self.toolBar.hidden = NO;
   self.inputImage = exportImage;
      self.avatarImage =  [UIImage imageNamed: kAvatarIcon];

    
    return self;
}



- (void)viewDidLoad
{
    App *app = App.sharedApp;
    [super viewDidLoad];
    
    self.promptLabel.text = self.prompt;
    self.imageView.image = self.inputImage;
    self.selectedJid = NULL;
    
    NSMutableArray *items =  [[NSMutableArray alloc] init];
    
    self.jidArray = [app.conversationManager JIDs];
    
    for(XMPPJID* jid in self.jidArray)
    {
        if(![jid isEqualToJID:app.currentJID options:XMPPJIDCompareBare])
        {
            fwdTableItem * item = [fwdTableItem itemWithJid: jid username: [jid addressBookName]];
            [items addObject:item];
        }
    }
    
    NSArray *sortedItems = [items sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        fwdTableItem *itemA = (fwdTableItem*)a;
        fwdTableItem * itemB = (fwdTableItem*)b;
        
        NSString *first =  itemA.nameString? itemA.nameString: itemA.jid.user ;
        NSString *second =  itemB.nameString? itemB.nameString: itemB.jid.user ;
         return [first localizedCompare:second];
    }];
    
    self.allItems = sortedItems;
    [self.tableView reloadData];
    
    if(!_inFWDController)
        [self.sendButton setEnabled:NO];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

 
-(IBAction)cancelButtonAction
{
    [self.delegate selectedJid:NULL];
}
 

-(IBAction)fwdButtonAction
{
    if(!_selectedJid) return;
    
     if(_delegate && [_delegate respondsToSelector:@selector(selectedJid:)])
     [_delegate selectedJid: [self.selectedJid copy]];

}


- (IBAction) fwdButtonItem: (UIBarButtonItem *) sender
{
    
    if(!_selectedJid) return;
    
    if(_delegate && [_delegate respondsToSelector:@selector(selectedJid:withSiren:)])
        [_delegate selectedJid: [self.selectedJid copy] withSiren:_siren];
    
    [self.navigationController popViewControllerAnimated:YES];
}


#pragma mark - Table view data source
 
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

#pragma mark  - Table view

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    NSInteger rows = 0;
    
 rows = [self.allItems count];
        
    return rows;
}
// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    
    ConversationViewTableCell *cell = (ConversationViewTableCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[ConversationViewTableCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
 
   
    fwdTableItem*  item = [self.allItems objectAtIndex:indexPath.row];
     
    cell.titleString = item.nameString? item.nameString: item.jid.user;
    cell.subTitleString = item.nameString?[item.jid bare]:@"";
   
    UIImage* userAvatar =  [XMPPJID userAvatarWithJIDString: item.jid.bare];
    if(!userAvatar) userAvatar = self.avatarImage;
    
    cell.avatar  = userAvatar;
    
    return cell;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    fwdTableItem * item = [self.allItems objectAtIndex:indexPath.row];
    
    
    if(_inFWDController)
        self.navigationItem.rightBarButtonItem.enabled = YES;
    else
        [self.sendButton setEnabled:YES];



    self.selectedJid = item.jid;
  
}


@end
