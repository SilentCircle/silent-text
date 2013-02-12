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
//  SCloudInfoView.m
//  SilentText
//

#import "SCloudInfoView.h"
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "NSDate+SCDate.h"
#import "NSNumber+Filesize.h"
#import "GeoViewController.h"
#import "NSString+SCUtilities.h"

@interface SCloudInfoView ()

@property (strong, nonatomic)   SCloudObject* scloud;


@end

@implementation SCloudInfoView


- (id)init
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        // Initialization code
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


-(NSString*) metaStringForScloud:(SCloudObject* ) scloud
{
    NSString * metaString = [[NSString alloc]init];
    NSString * mediaType = scloud.mediaType;
    NSDictionary* metaData = scloud.metaData;
    
    NSString* filename = [metaData valueForKey:kSCloudMetaData_FileName];
    
    NSString* datestring = [metaData valueForKey:kSCloudMetaData_Date];
    NSDate* fileDate = datestring? [NSDate dateFromRfc3339String:datestring]:NULL;
    datestring  = fileDate?[fileDate whenString]:NULL;;
    
    NSString* fileSize = [[metaData valueForKey:kSCloudMetaData_FileSize] fileSizeString];
    NSString* durationStr = [metaData valueForKey:kSCloudMetaData_Duration] ;
    NSTimeInterval  duration = [durationStr floatValue];
    
    NSNumber* segments = [metaData valueForKey:kSCloudMetaData_Segments];
    segments = [NSNumber numberWithInt:[segments intValue] + 1];
    
    if(filename) metaString = [metaString stringByAppendingFormat:@"Name: %@\n", filename];
    metaString = [metaString stringByAppendingFormat:@"Type: %@\n", [mediaType UTIname]];
    if(duration) metaString = [metaString stringByAppendingFormat:@"Seconds: %1.1f\n", duration];
     if(datestring) metaString = [metaString stringByAppendingFormat:@"Date: %@\n", datestring];
    if(fileSize) metaString = [metaString stringByAppendingFormat:@"Size: %@\n", fileSize];
    if(segments) metaString = [metaString stringByAppendingFormat:@"Parts: %d\n", [segments unsignedIntValue]];
     
    
    NSString *locatorID = _scloud.locatorString;
    NSUInteger len =  [_scloud.locatorString length];
    if(len > 16)
    {
        locatorID = [NSString stringWithFormat:@"%@\n%@",
                     [_scloud.locatorString substringToIndex: len/2 ],
                     [_scloud.locatorString substringFromIndex:len/2 ]];
       
    }
   
    metaString = [metaString stringByAppendingFormat:@"Scloud: %@\n", locatorID];
    
    
    if ( UTTypeConformsTo( (__bridge CFStringRef)  mediaType, kUTTypeImage))
    {
        NSDictionary* exif =  [metaData valueForKey:kSCloudMetaData_Exif];
        
        
    }
    else  if ([mediaType isEqualToString:(NSString *)kUTTypeMovie] )
    {
      }
    else  if ([mediaType isEqualToString:(NSString *)kUTTypeAudio])
    {
     }
    
    
    return metaString;
}


- (void) unfurlOnView:(UIView*)view under:(UIView*)underview  atPoint:(CGPoint) point
{
	if ([self superview]) {
		[self resetFadeOut];
		return;
	}
    
    self.scloud = [self.delegate getSCloudObject];

#pragma warning VINNIE decide who has permission to upload and delete
    
    BOOL fileOnCloud =  YES; //self.scloud.inCloud;
    
    self.deleteButton.enabled = fileOnCloud;
    self.reloadButton.enabled = YES;
    
    NSDictionary* metaData = _scloud.metaData;
      
    self.metaInfo.text = [self metaStringForScloud:_scloud];
    
	[self.layer setBorderColor:[[UIColor colorWithWhite: 0 alpha:0.5] CGColor]];
	[self.layer setBorderWidth:1.0f];
	// set a background color
	[self.layer setBackgroundColor:[[UIColor colorWithWhite: 0.2 alpha:0.60] CGColor]];
	// give it rounded corners
	[self.layer setCornerRadius:10.0];
	// add a little shadow to make it pop out
	[self.layer setShadowColor:[[UIColor blackColor] CGColor]];
	[self.layer setShadowOpacity:0.75];
     
	CGFloat height = self.frame.size.height;
	self.frame = CGRectMake(0,//point.x - self.frame.size.width/ 2,
							point.y, self.frame.size.width, 0);
	self.alpha = 0.0;
    //	[view addSubview:self];
	[view insertSubview:self belowSubview:underview];
	[UIView animateWithDuration:0.5f
					 animations:^{
						 [self setAlpha:1.0];
						 self.frame = CGRectMake(self.frame.origin.x,
												 point.y - height,
												 self.frame.size.width,
												 height);
						 //			 self.center = CGPointMake(self.center.x, point.y - self.frame.size.height /2);
                         
                         
					 }
					 completion:^(BOOL finished) {
						 [self resetFadeOut];
					 }];
    
}

- (void) resetFadeOut
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
	[self performSelector:@selector(fadeOut) withObject:nil afterDelay:5.];
    
}

- (void) fadeOut
{
	CGFloat height = self.frame.size.height;
	[UIView animateWithDuration:0.5f
					 animations:^{
						 [self setAlpha:0.0];
						 self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + height, self.frame.size.width, 0);
                         
					 }
					 completion:^(BOOL finished) {
						 [self removeFromSuperview];
						 self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + height, self.frame.size.width, height);
					 }];
    
}
- (BOOL) isVisible
{
	return [self superview] ? YES : NO;
}

- (void) hide
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
	[self fadeOut];
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self resetFadeOut];
}


- (IBAction)uploadAction:(id)sender
{
    [self fadeOut];
    
     [self.delegate reloadToCloud:_scloud];
}

- (IBAction)deleteAction:(id)sender
{
    [self fadeOut];
    
    [self.delegate deleteFromCloud:_scloud];
}

- (void) updateInfo
{
    
    BOOL fileOnCloud =  YES; //self.scloud.inCloud;
    
    self.deleteButton.enabled = fileOnCloud;
    self.reloadButton.enabled = YES;
   
}


@end
