//
//  SnippetGraphView.h
//  SnippetGraph
//
//  Created by mahboud on 6/5/14.
//  Copyright (c) 2014 BitsOnTheGo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Siren.h"

@interface SnippetGraphView : UIView
@property (nonatomic, strong) UIColor *waveColor;

- (void) addPoint:(CGFloat) newPoint;
- (void) setGraphWithNativePoints:(unsigned char *) points numOfPoints:(NSInteger) numOfPoints;
- (void) setGraphWithFloatPoints:(CGFloat *) points numOfPoints:(NSInteger) numOfPoints;
- (unsigned char *) getNativeGraphPoints: (NSInteger *) numPoints;
- (void) reset;


+ (UIImage *)thumbnailImageForSirenAudio: (Siren*) siren
                               frameSize: (CGSize) frameSize
                                   color: (UIColor *)color;

+ (UIImage *)thumbnailImageForSirenVoiceMail: (Siren*) siren
                                   frameSize: (CGSize) frameSize
                                       color: (UIColor *) color;

@end
