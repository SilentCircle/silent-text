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
#import <UIKit/UIKit.h>
#import "ContactsSubViewControllerCell.h"

@interface ContactsSubViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, ContactsSubViewControllerCellDelegate>

/**
 * @param viewName
 *   This is the registered name of the YapDatabaseView that should be used to display contacts.
 *   This should be one of the following:
 *     - Ext_View_SavedContacts - for all saved contacts
 *     - Ext_View_FilteredContacts - for a filtered subset
 *   The parent viewController is responsible for setting up and tearing down the database view.
 * 
 * @param delegate
 *   Optional delegate to respond when something is selected.
**/
- (id)initWithDatabaseViewName:(NSString *)viewName delegate:(id)delegate;

- (void)filterContacts:(NSString *)filter;

- (NSObject *)selectedUser; // may return a PersonSearchResult or STUser

@property (nonatomic, weak, readonly) id delegate;

@property (nonatomic, copy, readonly) NSString *parentViewName;
@property (nonatomic, copy, readonly) NSString *filteredViewName;

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

/**
 * Set this to YES if you want the tableView to always ensure something is selected (if possible).
 * For example, on iPad you may want to set to value to YES if ContactsSubViewController is
 * being used on the lefthand side of a splitView.
 *
 * The default value is NO.
**/
@property (nonatomic, assign, readwrite) BOOL ensuresSelection;

/**
 * Set this to YES if you want the tableView to allow multiple selection.
 * The default value is NO.
**/
@property (nonatomic, assign, readwrite) BOOL usesMultipleSelection;

/**
 * Set this to YES if you want the tableView to allow swipe-to-delete functionality.
 * The default value is NO.
**/
@property (nonatomic, assign, readwrite) BOOL allowsDeletion;

/**
 * You can get and/or set the selected userId.
**/
@property (nonatomic, strong, readwrite) NSString *selectedUserId;

/**
 * Set this to YES if you want the tableView to expand the contact cell when selected.
 * The default value is NO.
 **/
@property (nonatomic, assign, readwrite) BOOL expandsSelectedContact;


/**
 * Set this to YES if you want the tableView to checkmark cells when selected.
 * The default value is NO.
 **/
@property (nonatomic, assign, readwrite) BOOL checkmarkSelectedCells;

/**
 * If multipleSelection is enabled,
 * this method will return all selected userId's.
**/
@property (nonatomic, strong, readwrite) NSArray *selectedUserIds;

@property (nonatomic, strong, readwrite) NSArray *secondaryResultsArray;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol ContactsSubViewControllerDelegate
@optional

- (void)contactsSubViewControllerSelectionDidChange:(ContactsSubViewController *)sender;

@end
