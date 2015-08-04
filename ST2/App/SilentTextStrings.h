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
//  SilentTextStrings.h
//  SilentText
//

#ifndef SilentText_SilentTextStrings_h
#define SilentText_SilentTextStrings_h

#define NSLS_TEST_TEXT NSLocalizedString(@"testText", @"Localized TEST text for testing")

//
#define NSLS_COMMON_CANCEL NSLocalizedString(@"Cancel", @"Cancel an alert window")
#define NSLS_COMMON_TURN_ON NSLocalizedString(@"Turn On", @"Turn On")
#define NSLS_COMMON_TURN_OFF NSLocalizedString(@"Turn Off", @"Turn Off")

#define NSLS_COMMON_DND_OFF NSLocalizedString(@"Notifications sent without delay", @"Notifications sent without delay")
#define NSLS_COMMON_FOR_1HR NSLocalizedString(@"For 1 hour", @"For 1 hour")
#define NSLS_COMMON_UNTIL_8AM NSLocalizedString(@"Until 8am", @"Until 8am")
#define NSLS_FOREVER NSLocalizedString(@"Indefinitely", @"Indefinitely")

//
//
#define NSLS_COMMON_OK NSLocalizedString(@"OK", @"Accept the dialog")
//
#define NSLS_COMMON_SILENT_TEXT NSLocalizedString(@"SILENT TEXT", @"Conversation view Title")
//
//#define NSLS_COMMON_SETTINGS NSLocalizedString(@"Settings", @"Settings view Title")
//
//#define NSLS_COMMON_ACTIVATE NSLocalizedString(@"ACTIVATE", @"ACTIVATE")
//
#define NSLS_COMMON_GO_OFFLINE NSLocalizedString(@"Go Offline", @"Go Offline")
#define NSLS_COMMON_GO_ONLINE NSLocalizedString(@"Connect", @"Connect")
#define NSLS_USER_DEACTIVATE NSLocalizedString(@"Deauthorize", @"Deauthorize")
#define NSLS_USER_ACTIVATE NSLocalizedString(@"Authorize", @"Authorize")
//
//#define NSLS_COMMON_SEND NSLocalizedString(@"Send", @"For sending a message")
//  
//#define NSLS_COMMON_VERSION NSLocalizedString(@"Version", @"when displaying version numbers such as 1.0.0")
//
#define NSLS_COMMON_SIGN_UP NSLocalizedString(@"SIGN UP", @"Create a new account")
//
//#define NSLS_COMMON_BURN_NOTICE NSLocalizedString(@"Burn Notice", @"Burn Notice")
// 
//#define NSLS_COMMON_VERIFYING NSLocalizedString(@"Verifying…", @"Verifying...")
//
//#define NSLS_COMMON_VERIFYING_USER NSLocalizedString(@"Verifying %@…", @"verifying a particular user")
//
//#define NSLS_COMMON_NEW_CONTACT NSLocalizedString(@"New Contact", @"New Contact")
//
#define NSLS_COMMON_INVALID_USER NSLocalizedString(@"Invalid User Name", @"Invalid User Name")
//
#define NSLS_COMMON_INVALID_USER_DETAIL NSLocalizedString(@"\"%@\" is not a valid Silent Circle user name", @"%@ does not have a silent text account")
//
#define NSLS_COMMON_INVALID_SELF_USER_DETAIL NSLocalizedString(@"You can not send a message to yourself", @"You can not send a message to yourself")
//
//
#define NSLS_COMMON_INVALID_FEATURE NSLocalizedString(@"Feature not available", @"Feature not available")
//
#define NSLS_COMMON_COMING_SOON_FEATURE NSLocalizedString(@"This function is not available yet, stay tuned for a later version", @"Feature not availableyet ")
//
//
#define NSLS_COMMON_MULTICAST_NOT_SUPPORTED NSLocalizedString(@"You can not send messages to more than one recipient", @"ou can not send messages to more than one recipient")
//
//#define NSLS_COMMON_SAS_REQUEST NSLocalizedString(@"Accept Re-Key", @"Accept Re-Key")
//
//#define NSLS_COMMON_SAS_REQUEST_DETAIL NSLocalizedString(@"%@ wishes to rekey\nSAS: %@", @"Accept Re-Key")
//
#define NSLS_COMMON_PROVISION_ERROR NSLocalizedString(@"Unable to activate Silent Text", @"Unable to activate Silent Text")
//
#define NSLS_COMMON_PROVISION_ERROR_DETAIL NSLocalizedString(@"Please contact Silent Circle customer support with error code: \"%@\".",\
@"Please contact Silent Circle customer support with error code: \"%@\".")
//
#define NSLS_COMMON_DELETE_USER NSLocalizedString(@"Delete User", @"Delete User")
//
#define NSLS_COMMON_DELETE NSLocalizedString(@"Delete", @"Delete")
//
#define NSLS_COMMON_ACTIVATING NSLocalizedString(@"Activating…", @"Activating…")
#define NSLS_COMMON_AUTHORIZING NSLocalizedString(@"Authorizing…", @"Authorizing…")
//#define NSLS_COMMON_LOGGING_IN NSLocalizedString(@"Logging In…", @"Logging In…")
//
//#define NSLS_COMMON_SECONDS NSLocalizedString(@"After %d seconds", @"After %d seconds")
//#define NSLS_COMMON_MINUTE NSLocalizedString(@"After 1 minute", @"After 1 minute")
//#define NSLS_COMMON_MINUTES NSLocalizedString(@"After %d minutes", @"After %d minutes")
//#define NSLS_COMMON_HOUR NSLocalizedString(@"After 1 hour", @"After 1 hour")
//#define NSLS_COMMON_HOURS NSLocalizedString(@"After %d hours", @"After %d hours")
//#define NSLS_COMMON_NOW NSLocalizedString(@"Immediately", @"Immediately")
//#define NSLS_COMMON_NEVER NSLocalizedString(@"Never", @"Never")
//
#define NSLS_COMMON_NOT_AUTHORIZED  NSLocalizedString(@"Authentication Failed", @"Authentication Failed")
// 
// 
#define NSLS_COMMON_CONNECT_FAILED NSLocalizedString(@"Unable to connect to server.", @"Unable to connect to server.")
#define NSLS_COMMON_CONNECT_DETAIL NSLocalizedString(@"Please check your network connections.", @"Please check your network connections.")
//
//#define NSLS_COMMON_CERT_FAILED  NSLocalizedString(@"Certificate match error -- please update to the latest version of Silent Text", @"Certificate match error -- please update to the latest version of Silent Text")
//
////  New Strings , need to be updated.
//#define NSLS_COMMON_CLEAR_ALL NSLocalizedString(@"Clear", @"Clear")
//
//
#define NSLS_COMMON_SEND_ENCLOSURE NSLocalizedString(@"Send file from", @"Send File")
//
#define NSLS_COMMON_SEND_CONTACT NSLocalizedString(@"Contacts", @"Contacts")
#define NSLS_COMMON_SEND_PHOTO NSLocalizedString(@"Photo Library", @"Photo")
#define NSLS_COMMON_SEND_ITUNES NSLocalizedString(@"From iTunes", @"iTunes")
//
//
//#define NSLS_COMMON_ADD_CONTACT NSLocalizedString(@"Add Contact", @"Add Contact")
//#define NSLS_COMMON_SHOW_CONTACT NSLocalizedString(@"Show Contact", @"Show Contact")
//
//#define NSLS_COMMON_IMPORT_CONTACT NSLocalizedString(@"Import Contact", @"Import Contact")
//
//#define NSLS_COMMON_TAKE_PHOTO NSLocalizedString(@"Take Photo or Video", @"Take Photo or Video")
//
//#define NSLS_COMMON_CHOOSE_AUDIO NSLocalizedString(@"Record Message", @"Record Message")
//
#define NSLS_COMMON_CLEAR_CONVERSATION NSLocalizedString(@"Clear Conversation", @"Clear Conversation")
#define NSLS_COMMON_CLEAR_MESSAGE NSLocalizedString(@"Clear Message", @"Clear Message")
//
//#define NSLS_COMMON_KEYS_READY NSLocalizedString(@"Conversation Secured", @"Conversation Secured")
//#define NSLS_COMMON_KEYS_ESTABLISHING NSLocalizedString(@"Establishing Keys", @"Establishing Keys")
//#define NSLS_COMMON_KEYS_ESTABLISHED NSLocalizedString(@"Established Keys", @"Established Keys")
//#define NSLS_COMMON_KEYS_ERROR NSLocalizedString(@"Failed to Secure Conversation", @"Failed to Secure Conversation")
//
#define NSLS_COMMON_REFRESH_KEYS NSLocalizedString(@"Refresh Keys", @"Refresh Keys")
#define NSLS_COMMON_RESET_KEYS_TEXT NSLocalizedString(@"Reset the encryption keys", @"Reset the encryption keys")
#define NSLS_COMMON_NEW_KEYS NSLocalizedString(@"Make New Keys", @"Make New Keys")
#define NSLS_COMMON_NEW_KEY NSLocalizedString(@"Make New Key", @"Make New Key")
//
#define NSLS_COMMON_PREPARING NSLocalizedString(@"Preparing %@", @"Preparing Movie, Image or Audio")
//#define NSLS_COMMON_MOVIE NSLocalizedString(@"Movie", @"Movie")
//#define NSLS_COMMON_IMAGE NSLocalizedString(@"Image", @"Image")
#define NSLS_COMMON_AUDIO NSLocalizedString(@"Audio", @"Audio")
#define NSLS_COMMON_CONTACT NSLocalizedString(@"Contact", @"Contact")
//#define NSLS_COMMON_DOCUMENT NSLocalizedString(@"Document", @"Document")
//
//
#define NSLS_COMMON_UNABLE_TO_DECRYPT NSLocalizedString(@"The recipient was not able to decrypt your message. Tap \"Try Again\" to resend this message.",  @"The recipient was not able to decrypt your message. Tap \"Try Again\" to resend this message.")
//
#define NSLS_COMMON_UNABLE_TO_DECRYPT_MULTI NSLocalizedString(@"One of the recipients was not able to decrypt your message. Tap \"Try Again\" to rekey the conversation and resend this message.", @"One of the recipients was not able to decrypt your message. Tap \"Try Again\" to rekey the conversation and resend this message.")
//
#define NSLS_COMMON_TRY_AGAIN NSLocalizedString(@"Try Again", @"Try Again")
#define NSLS_COMMON_IGNORE NSLocalizedString(@"Ignore", @"Ignore")
//
#define NSLS_COMMON_ERASING NSLocalizedString(@"Erasing Media Cache", @"Erasing Media Cache")
#define NSLS_COMMON_COMPLETED NSLocalizedString(@"Completed", @"Completed")
//
//#define NSLS_COMMON_KEYING_INFOMRATIONAL NSLocalizedString(@"Waiting for recipient to complete the keying process", @"Waiting for recipient to complete the keying process")
//
//#define NSLS_COMMON_MESSAGE_REDACTED NSLocalizedString(@"Message redacted", @"Message redacted")
//
#define NSLS_COMMON_ON NSLocalizedString(@"On", @"On")
#define NSLS_COMMON_OFF NSLocalizedString(@"Off", @"Off")

/* Erics test 08-14-14 */
#define NSLS_COMMON_MYTEST NSLocalizedString(@"Erics test", @"A test of the localization script by Eric")

#endif
