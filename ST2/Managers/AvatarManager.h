/*
Copyright (C) 2015, Silent Circle, LLC. All rights reserved.

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
#import <Foundation/Foundation.h>
#import "AddressBookManager.h"
#import "AppTheme.h"
#import "DatabaseManager.h"
#import "STUser.h"


typedef enum {
    kAvatarUsage_None = 0,
	kAvatarUsage_Outgoing,
	kAvatarUsage_Incoming,
} AvatarUsage;


@interface AvatarManager : NSObject

+ (instancetype)sharedInstance;


#pragma mark Square Images

/**
 * This method takes into account the various ways in which a user might have an associated photo:
 * - explicit photo set (avatarFileName)
 * - photo in address book (abRecordID)
**/
- (BOOL)hasImageForUser:(STUser *)user;

/**
 * Synchronously fetches the image for the user.
 *
 * This method is not recommended for use on the main thread, as the disk IO may be slow.
**/
- (UIImage *)imageForUser:(STUser *)user;

/**
 * Asynchronously fetches the image for the associated user.
 * The completionBlock is invoked on the main thread.
**/
- (void)fetchImageForUser:(STUser *)user withCompletionBlock:(void (^)(UIImage*))completionBlock;

/**
 * This method writes the image as an encrypted blob to the file-system (in the blobDirectory),
 * and then updates the corresponding STUser object.
 * 
 * Note: This method automatically downscales the image to be an appropriate size.
 * This saves disk space, and speeds up avatar loading.
 * 
 * @param image
 *   The image to encrypt, and then write to the file system.
 *   This method automatically downscales the image before storing it to disk.
 *
 * @param userID
 *   Corresponds to the STUser.uuid associated with the image.
 *   After the image has been saved to disk, this method updates the STUser.avatarFileName method to match.
 *   The STUser.avatarFileName will be a newly generated UUID.
 * 
 * @param completionBlock (optional)
 *   The completionBlock to be invoked (on the main thread) after the read-write database transaction has completed.
**/
- (void)asyncSetImage:(UIImage *)image
          avatarSource:(AvatarSource)avatarSource
            forUserID:(NSString *)userID
      completionBlock:(dispatch_block_t)completionBlock;


#pragma mark Default Avatars

- (UIImage *)defaultAvatarWithDiameter:(CGFloat)diameter;
- (UIImage *)defaultAvatarScaledToHeight:(CGFloat)height withCornerRadius:(CGFloat)cornerRadius;

- (UIImage *)defaultMultiAvatarImageWithDiameter:(CGFloat)diameter;

- (UIImage *)defaultOCAUserAvatarWithDiameter:(CGFloat)diameter;
- (UIImage *)defaultSilentTextInfoUserAvatarWithDiameter:(CGFloat)diameter;

- (UIImage *)defaultMapImageScaledToHeight:(CGFloat)height;
- (UIImage *)defaultAudioImageScaledToHeight:(CGFloat)height;
- (UIImage *)defaultVCardImageScaledToHeight:(CGFloat)height;
- (UIImage *)defaultVCalendarImageScaledToHeight:(CGFloat)height;
- (UIImage *)defaultFolderImageScaledToHeight:(CGFloat)height;
- (UIImage *)defaultAndroidFileImageScaledToHeight:(CGFloat)height;
- (UIImage *)defaultDocumentFileImageScaledToHeight:(CGFloat)height;

- (UIImage *)defaultImageForMediaType:(NSString *)mediaType scaledToHeight:(CGFloat)height;

#pragma mark ScaledWithCornerRadius Avatar for User

/**
 * Returns whatever is in the cache, even if the item is slightly outdated.
 *
 * @param useDefaultIfUncached
 *   If YES, and there is nothing cached, then return a proper default image.
 *   If NO, then returns nil if nothing is cached.
 *
 * IMPORTANT :
 * The returned image is not guaranteed to be correct.
 * That is, it may be slightly outdated if user's image was recently changed.
 * You must still use the async (fetch) version below, even if this method returns a result.
**/
- (UIImage *)cachedAvatarForUser:(STUser *)userId
                  scaledToHeight:(CGFloat)height
                withCornerRadius:(CGFloat)cornerRadius
                 defaultFallback:(BOOL)useDefaultIfUncached;

/**
 * Async fetch routine.
 * This method should always be used, even if the cachedAvatar method returns a result.
**/
- (void)fetchAvatarForUser:(STUser *)user
            scaledToHeight:(CGFloat)height
          withCornerRadius:(CGFloat)cornerRadius
           completionBlock:(void (^)(UIImage*))completionBlock;

#pragma mark Rounded Avatar for User

/**
 * Returns whatever is in the cache, even if the item is slightly outdated.
 *
 * @param useDefaultIfUncached
 *   If YES, and there is nothing cached, then return a proper default image.
 *   If NO, then returns nil if nothing is cached.
 *
 * IMPORTANT :
 * The returned image is not guaranteed to be correct.
 * That is, it may be slightly outdated if user's image was recently changed.
 * You must still use the async (fetch) version below, even if this method returns a result.
**/
- (UIImage *)cachedAvatarForUser:(STUser *)userId
                    withDiameter:(CGFloat)diameter
                           theme:(AppTheme *)theme
                           usage:(AvatarUsage)usage
                 defaultFallback:(BOOL)useDefaultIfUncached;

/**
 * Async fetch routine.
 * This method should always be used, even if the cachedAvatar method returns a result.
**/
- (void)fetchAvatarForUser:(STUser *)user
              withDiameter:(CGFloat)diameter
                     theme:(AppTheme *)theme
                     usage:(AvatarUsage)usage
           completionBlock:(void (^)(UIImage*))completionBlock;

#pragma mark Rounded Avatar for UserID

/**
 * Returns whatever is in the cache, even if the item is slightly outdated.
 *
 * @param useDefaultIfUncached
 *   If YES, and there is nothing cached, then return a proper default image.
 *   If NO, then returns nil if nothing is cached.
 *
 * IMPORTANT :
 * The returned image is not guaranteed to be correct.
 * That is, it may be slightly outdated if user's image was recently changed.
 * You must still use the async (fetch) version below, even if this method returns a result.
**/
- (UIImage *)cachedAvatarForUserId:(NSString *)userId
                      withDiameter:(CGFloat)diameter
                             theme:(AppTheme *)theme
                             usage:(AvatarUsage)usage
                   defaultFallback:(BOOL)useDefaultIfUncached;

/**
 * Async fetch routine.
 * This method should always be used, even if the cachedAvatar method returns a result.
**/
- (void)fetchAvatarForUserId:(NSString *)userId
                withDiameter:(CGFloat)diameter
                       theme:(AppTheme *)theme
                       usage:(AvatarUsage)usage
             completionBlock:(void (^)(UIImage*))completionBlock;

#pragma mark Rounded Avatar for ABRecordID

/**
 * Returns whatever is in the cache, even if the item is slightly outdated.
 * 
 * @param useDefaultIfUncached
 *   If YES, and there is nothing cached, then return a proper default image.
 *   If NO, then returns nil if nothing is cached.
 *
 * IMPORTANT :
 * The returned image is not guaranteed to be correct.
 * That is, it may be slightly outdated if user's image was recently changed.
 * You must still use the async (fetch) version below, even if this method returns a result.
**/
- (UIImage *)cachedAvatarForABRecordID:(ABRecordID)abRecordID
                          withDiameter:(CGFloat)diameter
                                 theme:(AppTheme *)theme
                                 usage:(AvatarUsage)usage
                       defaultFallback:(BOOL)useDefaultIfUncached;

/**
 * Async fetch routine.
 * This method should always be used, even if the cachedAvatar method returns a result.
**/
- (void)fetchAvatarForABRecordID:(ABRecordID)abRecordID
                    withDiameter:(CGFloat)diameter
						   theme:(AppTheme *)theme
                           usage:(AvatarUsage)usage
                 completionBlock:(void (^)(UIImage*))completionBlock;


#pragma mark Rounded Avatar for URL

/**
 * Returns the item if in the cache.
 *
 * @param useDefaultIfUncached
 *   If YES, and there is nothing cached, then return a proper default image.
 *   If NO, then returns nil if nothing is cached.
 *
 * NOTE : The avatar represented by an avatarURL shouldn't change.
 *        Thus this API differs from others in that, if there's a cached version,
 *        then there's no need to do an async fetch for an "up-to-date" version.
 *        Doing so would just cause unnecessary overhead.
**/
- (UIImage *)cachedAvatarForURL:(NSString *)relativeAvatarUrl
                      networkID:(NSString *)networkID
                   withDiameter:(CGFloat)diameter
                          theme:(AppTheme *)theme
                          usage:(AvatarUsage)usage
                defaultFallback:(BOOL)useDefaultIfUncached;

/**
 * Only use this method if the avatar isn't already cached.
**/
- (void)downloadAvatarForURL:(NSString *)relativeAvatarUrl
                   networkID:(NSString *)networkID
                withDiameter:(CGFloat)diameter
                       theme:(AppTheme *)theme
                       usage:(AvatarUsage)usage
             completionBlock:(void (^)(UIImage*))completionBlock;


#pragma mark Multi Avatar

/** TO DEPRECATE (see ConversationViewController)
 * Use this method to aynchronously fetch a multi avatar.
 *
 * The front parameter can be either a userId (NSString) or an abRecordID (NSNumber).
 * The back parameter can be either a userId (NSString) or an abRecordID (NSNumber).
**/
- (void)fetchMultiAvatarForFront:(id)front // if NSString -> userId; if NSNumber -> abRecordID
                            back:(id)back  // if NSString -> userId; if NSNumber -> abRecordID
                    withDiameter:(CGFloat)diameter
                           theme:(AppTheme *)theme
                           usage:(AvatarUsage)usage
                completionBlock:(void (^)(UIImage*avatar))completionBlock;


/** ET 08/15/14 (refactored with RH from fetchMultiAvatarForFront:back:withDiameter:theme:usage:completionBlock:)
 * Use this method to aynchronously fetch a composite multiAvatar image for the given multiCast users array.
 *
 * Implemented as a complement to `[DatabaseManager multiCastUsersForConversation:withTransaction:]` method, which
 * initializes an array of Silent Contacts users or temporary pseudo-users for a given multiCast conversation, to
 * return a composite avatar image in the given completion block.
 *
 * This method is used by ConversationDetailsVC, ConversationDetailsSecurityVC, and GroupUserInfoVC classes to display
 * a multiCast conversation avatar image.
 *
 * @param users An array of users, some of which may not be database users, with which to derive 
 *  front and back avatar images for the return composite image.
 * @param diameter The diameter of the return image
 * @param theme The them from which to derive the tintColor for image border
 * @param usage A usage enum value (ET: I don't know what this is yet...)
 * @param completionBlock An objective-C block to execute with the return image
 */
- (void)fetchMultiAvatarForUsers:(NSArray *)users 
                    withDiameter:(CGFloat)diameter
                           theme:(AppTheme *)theme
                           usage:(AvatarUsage)usage
                 completionBlock:(void (^)(UIImage *multiAvatar))completionBlock;

//ET 06/20/15 Testing
+ (UIImage *)cachedOrDefaultAvatarForConversation:(STConversation *)convo
                                             user:(STUser *)user
                                         diameter:(CGFloat)diameter
                                            theme:(AppTheme *)theme
                                            usage:(AvatarUsage)usage;

/**
 * Returns an identifier for an avatar image for a given user. 
 *
 * If the given user is a non-temp user, then user.uuid is returned;
 * Otherwise, user.abRecordId is returned, boxed in an NSNumber.
 *
 * Note: This method is used as a helper for the `fetchMultiAvatarForUsers:withDiameter:theme:usage:completionBlock:`
 * method.
 *
 * @param aUser A user instance for which to return an avatarId
 * @return an identifier for an avatar image for the given user. 
 */
- (id)avatarIdForUser:(STUser *)aUser;

@end
