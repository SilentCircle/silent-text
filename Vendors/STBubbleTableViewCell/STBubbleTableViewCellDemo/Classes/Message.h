//
//  Message.h
//  STBubbleTableViewCellDemo
//
//  Created by Cedric Vandendriessche on 18/04/12.
//  Copyright 2011 FreshCreations. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Message : NSObject {
	NSString *message;
	UIImage *avatar;
}

+ (id)messageWithString:(NSString *)msg;
+ (id)messageWithString:(NSString *)msg image:(UIImage *)img;

- (id)initWithString:(NSString *)msg;
- (id)initWithString:(NSString *)msg image:(UIImage *)img;

@property (nonatomic, copy) NSString *message;
@property (nonatomic, strong) UIImage *avatar;

@end
