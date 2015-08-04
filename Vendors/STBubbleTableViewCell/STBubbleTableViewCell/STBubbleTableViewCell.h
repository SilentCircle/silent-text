#import <UIKit/UIKit.h>
#import "STBubbleView.h"

@class STBubbleTableViewCell;

extern const CGFloat kSTBubbleGutterWidth; // Default value: 80.0f.
extern const CGFloat kSTBubbleImageWidth;  // Default value: 50.0f.

typedef enum {
    
	STBubbleTableViewCellAuthorTypeNone = 0,
	STBubbleTableViewCellAuthorTypeUser,
	STBubbleTableViewCellAuthorTypeOther
	
} AuthorType;

@protocol STBubbleTableViewCellDelegate <NSObject>
@optional

#define kTappedImageOfCell  (@selector(tappedImageOfCell:))
- (void) tappedImageOfCell: (STBubbleTableViewCell *) cell;

#define kTappedImageOfAvatar  (@selector(tappedImageOfAvatar:))
- (void) tappedImageOfAvatar: (STBubbleTableViewCell *) cell;
- (void) tappedGeo: (STBubbleTableViewCell *) cell;
- (void) tappedBurn: (STBubbleTableViewCell *) cell;
- (void) tappedFailure: (STBubbleTableViewCell *) cell;
- (void) unhideNavBar;

#define kTappedResendMenu  (@selector(tappedResendMenu:))
- (void) tappedResendMenu: (STBubbleTableViewCell *) cell;

#define kTappedDeleteMenu  (@selector(tappedDeleteMenu:))
- (void) tappedDeleteMenu: (STBubbleTableViewCell *) cell;


#define kTappedForwardMenu  (@selector(tappedForwardMenu:))
- (void) tappedForwardMenu: (STBubbleTableViewCell *) cell;

- (void) resignActiveTextEntryField;

@end

@interface STBubbleTableViewCell : UITableViewCell

@property (unsafe_unretained, nonatomic) id <STBubbleTableViewCellDelegate> delegate;
@property (strong, nonatomic) STBubbleView *bubbleView;
@property (strong, nonatomic) UIImage *bubbleImage;
@property (strong, nonatomic) UIImage *selectedBubbleImage;
@property (nonatomic) AuthorType authorType; // Default value: STBubbleTableViewCellAuthorTypeNone
@property (nonatomic) BOOL canCopyContents;  // Default value: YES
@property (nonatomic, readonly) CGFloat height;
@property (nonatomic) BOOL hasGeo;
@property (nonatomic) BOOL burn;
@property (nonatomic) BOOL failure; 
@property (nonatomic, strong) UITextView *textView;

@property (strong, nonatomic) UIImage *burnImage;
@property (strong, nonatomic) UIImage *geoImage;
@property (strong, nonatomic) UIImage *failureImage;
@property (strong, nonatomic) UIButton *burnButton;
@property (strong, nonatomic) UIButton *geoButton;
@property (strong, nonatomic) UIButton *failureButton;

- (void) setBubbleMediaImage:(UIImage *)mediaImage;
//- (void) setBurn:(BOOL)burn;
//- (void) setGeo:(BOOL)hasGeo;
+(CGFloat) quickHeightForContentViewWithText:(NSString *) text withFont:(UIFont *) font withAvatar:(BOOL) hasAvatar withMaxWidth:(CGFloat)maxWidth;
+(CGFloat) quickHeightForContentViewWithImage:(UIImage *) image withAvatar:(BOOL) hasAvatar;

@end
