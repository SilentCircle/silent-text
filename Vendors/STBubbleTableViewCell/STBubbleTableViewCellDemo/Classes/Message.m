//
//  Message.m
//  STBubbleTableViewCellDemo
//
//  Created by Cedric Vandendriessche on 18/04/12.
//  Copyright 2011 FreshCreations. All rights reserved.
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "Message.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

@implementation Message

@synthesize message, avatar;

+ (id)messageWithString:(NSString *)msg {
	return [Message messageWithString:msg image:nil];
}

+ (id)messageWithString:(NSString *)msg image:(UIImage *)img {
	Message *aMessage = [[Message alloc] initWithString:msg image:img];
	return aMessage;
}

- (id)initWithString:(NSString *)msg {
	return [self initWithString:msg image:nil];
}

- (id)initWithString:(NSString *)msg image:(UIImage *)img {
	self = [super init];
	if(self)
	{
		self.message = msg;
		self.avatar = img;
	}
	return self;
}


@end
