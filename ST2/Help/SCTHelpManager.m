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
//  SCTHelpManager.m
//  ST2
//
//  Created by Eric Turner on 7/26/14.
//

#import "SCTHelpManager.h"

@implementation SCTHelpManager

// Tables (.strings files)
NSString * const SCT_DEFAULT_HELP = @"Help";
NSString * const SCT_CONVERSATION_DETAILS_HELP = @"ConversationDetailsHelp";

// Local
static NSString * const kHelpTitle = @"Help.helpTitle";
static NSString * const kHelpTitleWithContext = @"Help.helpTitle-with-context %@";


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Help Content
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * A class method which returns help content text as a string for the given string key.
 *
 * This method passes through the return value of the `stringForKey:inTable:`, passing the default Help tblName.
 *
 * @param aKey The string key for lookup against a localized string value.
 */
+ (NSString *)contentForKey:(NSString *)aKey
{
    return [self stringForKey:aKey inTable:SCT_DEFAULT_HELP];
}

/**
 * A class method which returns help content text as a string for the given string key from .strings file of the 
 * given tblName.
 *
 * @param aKey The string key for lookup against a localized string value.
 * @param tblName The name of the .strings file in which to lookup the value for the given key.
 */
+ (NSString *)contentForKey:(NSString *)aKey inTable:(NSString *)tblName
{
    return [self stringForKey:aKey inTable:tblName];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Help Titles
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * A class method which returns a language-localized "Help" string.
 *
 * @return Localized Help title.
 */
+ (NSString *)simpleHelpTitle {
    NSString *key = kHelpTitle;
    return [[NSBundle mainBundle] localizedStringForKey:key value:key table:SCT_DEFAULT_HELP];
}

/**
 * A class method which returns a language-localized, context-specific, Help title phrase.
 *
 * Example: HelpTitleWithContext(@"Conversation Details") returns "Conversation Details Help" in English, with
 * opportunity for translator to order differently, i.e. (in other language) "Help for Conversation Details", in
 * Help.strings file.
 *
 * @param context A string with which to provide more specific Help context in the returned title string.
 * @return Localized Help title, joined with the given context string.
 */
+ (NSString *)helpTitleWithContext:(NSString *)context {
    NSString *str = [NSString stringWithFormat:NSLocalizedStringFromTable(kHelpTitleWithContext, 
                                                                          SCT_DEFAULT_HELP, 
                                                                          @"{context phrase} Help"), context];
    return str;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Help Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method returns the language-localized string for the given key from the given .strings file for tblName.
 *
 * @param aKey The string key for lookup against a localized string value.
 * @param tblName The .strings filename in which to lookup the given key.
 * @return Langauge-localized string value for the given key
 */
+ (NSString *)stringForKey:(NSString *)key inTable:(NSString *)tblName {
    return [[NSBundle mainBundle] localizedStringForKey:key value:key table:tblName];
}

// unblurred self view image (i.e. contentView - without navbar)
// HelpDetailsVC creates the blurred image from this one
+ (UIImage *)bgImageFromSubView:(UIView *)aView parentView:(UIView *)pView
{
    //screen capture code
    UIGraphicsBeginImageContextWithOptions(aView.frame.size, NO, [UIScreen mainScreen].scale);
    [pView drawViewHierarchyInRect:aView.frame afterScreenUpdates:NO];
    
    UIImage *capturedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return capturedImage;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Localization Reference
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
 * Excerpt from http://www.objc.io/issue-9/string-localization.html
 *
Splitting Up the String File

As we mentioned in the beginning, NSLocalizedString has a few siblings that allow for more control of string 
localization. NSLocalizedStringFromTable takes the key, the table, and the comment as arguments. The table argument
refers to the string table that should be used for this localized string. genstrings will create one strings file per 
table identifier with the file name <table>.strings.

This way, you can split up your strings files into several smaller files. This can be very helpful if you’re working on
a large project or in a bigger team, and it can also make merging regenerated strings files with their existing 
counterparts easier.

Instead of calling:

NSLocalizedStringFromTable(@"home.button.start-run", @"ActivityTracker", @"some comment..")
everywhere, you can make your life a bit easier by defining your own custom string localization functions:

static NSString * LocalizedActivityTrackerString(NSString *key, NSString *comment) {
    return [[NSBundle mainBundle] localizedStringForKey:key value:key table:@"ActivityTracker"];
}

In order to generate the strings file for all usages of this function, you have to call genstrings with the -s option:

find . -name *.m | xargs genstrings -o en.lproj -s LocalizedActivityTrackerString

The -s argument specifies the base name of the localization functions. The previous call will also pick up the 
functions called <base name>FromTable, <base name>FromTableInBundle, and <base name>WithDefaultValue, if you choose to
define and use those.


Localized Format Strings

Often we have to localize strings that contain some data that can only be inserted at runtime. To achieve this, we can
use format strings, and Foundation comes with some gems to make this feature really powerful. (See Daniel’s article for
                                                                                               more details on format strings.)

A simple example would be to display a string like “Run 1 out of 3 completed.” We would build the string like this:

NSString *localizedString = NSLocalizedString(@"activity-profile.label.run %lu out of %lu completed", nil);
self.label.text = [NSString localizedStringWithFormat:localizedString, completedRuns, totalRuns];

Often translations will need to reorder those format specifiers in order to construct a grammatically correct sentence.
Luckily, this can be done easily in the strings file:

"activity-profile.label.run %lu out of %lu completed" = "Von %2$lu Läufen hast du %$1lu absolviert";
*/
/*
 * Also see: http://nshipster.com/nslocalizedstring/
 */


@end
