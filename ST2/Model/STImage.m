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
#import "STImage.h"
#import "YapDatabaseRelationshipEdge.h"

/**
 * Keys for encoding / decoding (to avoid typos)
**/
#define k_version          @"version"
#define k_image            @"thumbnail"
#define k_parentKey        @"parentKey"
#define k_parentCollection @"parentCollection"


@implementation STImage

@synthesize image = image;
@synthesize parentKey = parentKey;
@synthesize parentCollection = parentCollection;

- (id)initWithImage:(UIImage *)inImage
          parentKey:(NSString *)inParentKey
         collection:(NSString *)inParentCollection
{
	if ((self = [super init]))
	{
		image = inImage;
		parentKey = [inParentKey copy];
		parentCollection = [inParentCollection copy];
	}
	return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		int32_t version = [decoder decodeInt32ForKey:k_version];
		
		if (version == 2)
		{
			image = [decoder decodeObjectForKey:k_image];
			parentKey = [decoder decodeObjectForKey:k_parentKey];
			parentCollection = [decoder decodeObjectForKey:k_parentCollection];
        }
		else
		{
			image = [decoder decodeObjectForKey:k_image];
			parentKey = nil;
			parentCollection = nil;
  		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt32:2 forKey:k_version];
	
	[coder encodeObject:image            forKey:k_image];
	[coder encodeObject:parentKey        forKey:k_parentKey];
	[coder encodeObject:parentCollection forKey:k_parentCollection];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	STImage *copy = [super copyWithZone:zone];
	copy->image = image;
	copy->parentKey = parentKey;
	copy->parentCollection = parentCollection;
	
 	return copy;
}

#pragma mark YapDatabaseRelationshipNode Protocol

- (NSArray *)yapDatabaseRelationshipEdges
{
	if (parentKey == nil) return nil;
	
	YapDatabaseRelationshipEdge *edge =
	  [YapDatabaseRelationshipEdge edgeWithName:@"imageOwner"
	                             destinationKey:parentKey
	                                 collection:parentCollection
	                            nodeDeleteRules:YDB_DeleteSourceIfDestinationDeleted];
	return @[ edge ];
}

@end
