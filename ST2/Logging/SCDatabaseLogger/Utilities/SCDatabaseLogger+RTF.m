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
#import "SCDatabaseLogger+RTF.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif


@implementation SCDatabaseLogger (RTF)

/**
 * Writes the given attributed string as a RTF file to the given path.
 *
 * @return
 *     YES if successful.
 *     NO otherwise, in which case the errorPtr parameter will be set (if given).
 *
 * Important: This method does synchronous disk IO.
 * Thus you likely want to invoke this method within a background.
**/
+ (BOOL)exportAttributedString:(NSAttributedString *)attrStr
                  toRTFWithURL:(NSURL *)rtfFileURL
                         error:(NSError **)errorPtr
{
	NSError *error = nil;
	
	NSRange range = (NSRange){
		.location = 0,
		.length = [attrStr length]
	};
	
	NSDictionary *docAttr = @{ NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType};
	
	NSFileWrapper *fileWrapper = [attrStr fileWrapperFromRange:range documentAttributes:docAttr error:&error];
	if (error)
	{
		if (errorPtr) *errorPtr = error;
		return NO;
	}
	
	NSFileWrapperWritingOptions options = NSFileWrapperWritingAtomic;
	
	[fileWrapper writeToURL:rtfFileURL options:options originalContentsURL:nil error:&error];
	
	if (error)
	{
		if (errorPtr) *errorPtr = error;
		return NO;
	}
	else
	{
		return YES;
	}
}

/**
 * Converts the given attributed string to RTF format, and returns the raw RTF as NSData.
 **/
+ (NSData *)convertAttributedString:(NSAttributedString *)attrStr
                     toRTFWithError:(NSError **)errorPtr
{
	NSError *error = nil;
	
	NSRange range = (NSRange){
		.location = 0,
		.length = [attrStr length]
	};
	
	NSDictionary *docAttr = @{ NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType};
	
	NSData *data = [attrStr dataFromRange:range documentAttributes:docAttr error:&error];
	
	if (errorPtr) *errorPtr = error;
	return data;
}

@end
