//
//  SnippetGraphView.m
//  SnippetGraph
//
//  Created by mahboud on 6/5/14.
//  Copyright (c) 2014 BitsOnTheGo. All rights reserved.
//

#import "SnippetGraphView.h"
#import "STLogging.h"

#import "SCDateFormatter.h"
#import "ECPhoneNumberFormatter.h"

// Log levels: off, error, warn, info, verbose

#if DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@implementation SnippetGraphView
{
	unsigned char 	*graphPoints;
	NSInteger		pointsInArray;
	CGFloat 		heightOfWavefrom;
	NSInteger		widthOfWaveform;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
    if (self) {
		[self setup];
	}
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
		[self setup];
    }
    return self;
}

- (void)setup
{
        // Initialization code
	graphPoints = nil;
}

- (void) reset
{
	pointsInArray = 0;
	[self setNeedsDisplay];
}

- (void) addPoint:(CGFloat) newPoint
{
	if (++pointsInArray > widthOfWaveform) {
		pointsInArray = widthOfWaveform;
		for (NSInteger i = 0; i < pointsInArray - 1; i++)
		{
			graphPoints[i] = graphPoints[i + 1];
			
		}
	}
	
	graphPoints[pointsInArray - 1] = newPoint ? (unsigned char) (newPoint * 255.0) : 1;
//	NSLog(@"curlevl : %f, graphpt : %d", newPoint, (unsigned int) graphPoints[pointsInArray - 1]);
	[self setNeedsDisplay];


}

- (void) setGraphWithNativePoints:(unsigned char *) points numOfPoints:(NSInteger) numOfPoints
{
//	if (numOfPoints > widthOfWaveform)
//		pointsInArray = widthOfWaveform;
//	else
//		pointsInArray = numOfPoints;
	pointsInArray = MIN(numOfPoints, widthOfWaveform);

	for (NSInteger i = 0; i < pointsInArray; i++)
		graphPoints[i] = points[i];
	[self setNeedsDisplay];
	
}

- (void) setGraphWithFloatPoints:(CGFloat *) points numOfPoints:(NSInteger) numOfPoints
{
//	if (numOfPoints > widthOfWaveform)
//		pointsInArray = widthOfWaveform;
//	else
//		pointsInArray = numOfPoints;
	pointsInArray = MIN(numOfPoints, widthOfWaveform);
	for (NSInteger i = 0; i < pointsInArray; i++)
		graphPoints[i] = (unsigned char) (points[i] * 255.0);
	[self setNeedsDisplay];
	
}

- (unsigned char *) getNativeGraphPoints: (NSInteger *) numPoints
{
	*numPoints = pointsInArray;
	for (NSInteger i = pointsInArray; i < widthOfWaveform; i++)
		graphPoints[i] = 0;
	return graphPoints;
}
- (void)layoutSubviews
{
	heightOfWavefrom = self.bounds.size.height;
	NSInteger newWidthOfWaveform = self.bounds.size.width;
	char *newGraphPoints = malloc(newWidthOfWaveform);
	if (graphPoints) {
		NSInteger i;
		for (i = 0; i < MIN(pointsInArray, newWidthOfWaveform); i++)
			newGraphPoints[i] = graphPoints[i];
		pointsInArray = i;
		free(graphPoints);
	}
	graphPoints = newGraphPoints;
	widthOfWaveform = newWidthOfWaveform;
	//	[self setNeedsDisplay];
}
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
	
    CGMutablePathRef halfPath = CGPathCreateMutable();
//    CGPathAddLines( halfPath, NULL, graphPoints, number_of_points * 2 );

	for (int k = 0; k < pointsInArray; k++) {
		CGFloat height = (graphPoints[k] / 255.0) * heightOfWavefrom;
		CGFloat loc = widthOfWaveform - pointsInArray + k;
		CGPathMoveToPoint (halfPath, nil, loc, heightOfWavefrom / 2.0 - height / 2.0);
		CGPathAddLineToPoint (halfPath, nil, loc, heightOfWavefrom / 2.0 + height / 2.0);
	}

	// Build the destination path
	//	CGMutablePathRef path = CGPathCreateMutable();
	
	// Transform to fit the waveform ([0,1] range) into the vertical space
	// ([halfHeight,height] range)
//	double halfHeight = floor( self.bounds.size.height / 2.0 );
//	CGAffineTransform xf = CGAffineTransformIdentity;
//	xf = CGAffineTransformTranslate( xf, 0.0, halfHeight );
//	xf = CGAffineTransformScale( xf, 1.0, halfHeight );
	
	// Add the transformed path to the destination path
//	CGPathAddPath( path, &xf, halfPath );
//
//	// Transform to fit the waveform ([0,1] range) into the vertical space
//	// ([0,halfHeight] range), flipping the Y axis
//	xf = CGAffineTransformIdentity;
//	xf = CGAffineTransformTranslate( xf, 0.0, halfHeight );
//	xf = CGAffineTransformScale( xf, 1.0, -halfHeight );
//	
//	// Add the transformed path to the destination path
//	CGPathAddPath( path, &xf, halfPath );
//	
//	CGPathRelease( halfPath ); // clean up!
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetShouldAntialias (context, NO);
	CGContextSetLineWidth(context,0.5);
	CGContextSetAlpha(context, 1.0);
	
    CGContextSetStrokeColorWithColor(context,
                                     _waveColor.CGColor);
 	
//	CGContextSetFillColorWithColor(context, [UIColor yellowColor].CGColor);
//	CGContextDrawPath(context, kCGPathFillStroke);
//	CGContextMoveToPoint(context, midX, minY);
//	CGContextAddArcToPoint(context, maxX, minY, maxX, midY, cornerRadius);
//	CGContextAddArcToPoint(context, maxX, maxY, midX, maxY, cornerRadius);
//	CGContextAddArcToPoint(context, minX, maxY, minX, midY, cornerRadius);
//	CGContextAddLineToPoint(context, minX, midY + calloutRadius / 2);
//	CGContextAddLineToPoint(context, minX - calloutRadius / 2, midY);
//	CGContextAddLineToPoint(context, minX, midY - calloutRadius / 2);
//	CGContextAddArcToPoint(context, minX, minY, midX, minY, cornerRadius);
	
	
//	CGContextClosePath(context);
//	//	CGContextStrokePath(context);
//	CGContextDrawPath(context, kCGPathFillStroke);
	
	
//	CGMutablePathRef line = CGPathCreateMutable();
//    CGContextSetStrokeColorWithColor(context,
//                                     [UIColor redColor].CGColor);
//	CGPathMoveToPoint(line, nil, 0, 0.5*self.bounds.size.height);
//	CGPathAddLineToPoint(line, nil, 300, 0.5*self.bounds.size.height);
//	CGContextAddPath(context, line);
//	CGContextSetLineWidth(context, 0.5);
//	CGContextStrokePath(context);
//
//	CGMutablePathRef line2 = CGPathCreateMutable();
//	CGContextSetStrokeColorWithColor(context,
//                                     [UIColor blueColor].CGColor);
//	CGPathMoveToPoint(line2, nil, 0, 0.5*self.bounds.size.height - 5);
//	CGPathAddLineToPoint(line2, nil, 300, 0.5*self.bounds.size.height - 5);
//	CGContextAddPath(context, line2);
//	CGContextSetLineWidth(context, 1.0);
//	CGContextStrokePath(context);
//	
//	CGMutablePathRef line3 = CGPathCreateMutable();
//	CGContextSetStrokeColorWithColor(context,
//                                     [UIColor blueColor].CGColor);
//	CGPathMoveToPoint(line3, nil, 0, 0.5*self.bounds.size.height + 5);
//	CGPathAddLineToPoint(line3, nil, 300, 0.5*self.bounds.size.height + 5);
//	CGContextAddPath(context, line3);
//	CGContextSetLineWidth(context, 0.25);
//	CGContextStrokePath(context);
	
	
	CGContextAddPath(context, halfPath);
	CGContextStrokePath(context);
	//CGContextDrawPath(context, kCGPathFillStroke);

	UIGraphicsEndImageContext();
	CGPathRelease(halfPath);
//	CGPathRelease(line);
//	CGPathRelease(line2);
//	CGPathRelease(line3);


}


+ (UIImage *)thumbnailImageForSirenAudio: (Siren*) siren
                               frameSize: (CGSize) frameSize
                                   color: (UIColor *) color
{
    UIImage *image = NULL;
    
    // just some random data for a waveform
    static uint8_t  defaultWaveForm[] =
    {0x87, 0xf3, 0x11, 0x57, 0xd3, 0x48, 0x86, 0xa8, 0x81, 0x84, 0xdc, 0xaf, 0x18, 0x5a, 0x6a, 0x86,
        0xbb, 0x8a, 0xea, 0xbc, 0x7a, 0xfc, 0x59, 0xaa, 0x89, 0xa7, 0x72, 0xce, 0x32, 0xd6, 0x46, 0x4d,
        0xa3, 0x8b, 0x68, 0x48, 0x73, 0x5f, 0x3f, 0x49, 0xbc, 0x0e, 0x9d, 0xbd, 0x12, 0xba, 0x0c, 0x35,
        0xb9, 0x8c, 0x3f, 0x2e, 0x7f, 0x03, 0xab, 0x00, 0x30, 0x08, 0x03, 0xb8, 0x62, 0x3e, 0xfd, 0x9d};
    
    if(siren)
    {
        NSData* waveData = siren.waveform
        ? siren.waveform:
        [NSData dataWithBytes:defaultWaveForm length:sizeof(defaultWaveForm)  ];
        
        NSUInteger pointsInArray = waveData.length;
        uint8_t  *graphPoints = (UInt8*)waveData.bytes;
        
        float graphHeight = frameSize.height -10  ;  // no margin on height
        
        float leftMargin = 10;
        float rightMargin = 10;
        float graphDurationtMargin = 10;    // between graph and duration
        float maxGraphPoints = 60;
        
        NSString* durationText = @"??:??";
        
        if(siren.duration)
        {
            NSDateFormatter* durationFormatter =  [SCDateFormatter localizedDateFormatterFromTemplate:@"mmss"];
            durationText = [durationFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: siren.duration.doubleValue]];
        }
        
        UIFont *titleFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        
        NSMutableParagraphStyle *titleStyle = [[NSMutableParagraphStyle alloc] init];
        titleStyle.lineBreakMode = NSLineBreakByTruncatingTail;
        titleStyle.alignment = NSTextAlignmentCenter;
        
        NSDictionary *attributes = @{
                                     NSFontAttributeName: titleFont,
                                     NSParagraphStyleAttributeName: titleStyle,
                                     NSForegroundColorAttributeName: color,
                                     };
        
        CGSize textRectSize = [durationText sizeWithAttributes:attributes];
        
        float graphPointsWidth = pointsInArray < maxGraphPoints ? maxGraphPoints : pointsInArray;
        float frameWidth = leftMargin + graphPointsWidth + graphDurationtMargin + textRectSize.width + rightMargin;
       
        // correct if calulated width is larger than what we asked for
        if(frameWidth > frameSize.width)
        {
            float diff = frameWidth - frameSize.width;
            graphPointsWidth -=diff;
            frameWidth -=diff;
        }

        CGSize newFrameSize = (CGSize) { .width = frameWidth,
            .height = frameSize.height};
        
        CGRect textRect = (CGRect){
            .origin.x = frameWidth- textRectSize.width - leftMargin,
            .origin.y = (newFrameSize.height - textRectSize.height ) / 2,      // I want text vert centered
            .size.width = textRectSize.width,
            .size.height = textRectSize.height + 5
        };
        
        float graphWidth  = frameWidth - rightMargin - graphDurationtMargin  - textRectSize.width - leftMargin;
        
        CGRect graphRect = (CGRect){
            .origin.x = leftMargin,
            .origin.y =  (newFrameSize.height - graphHeight)/2,
            .size.width = graphWidth,
            .size.height = graphHeight
        };
        
        
        UIGraphicsBeginImageContextWithOptions(newFrameSize, NO, 0);
        
        
        // draw the duration text
        [durationText drawInRect:textRect withAttributes:attributes];
        
        CGMutablePathRef graphPath = CGPathCreateMutable();
        for (int k = 0; k < pointsInArray; k++)
        {
            uint8_t sample = graphPoints[k];
            
            //              sample = k*2;  // debugging
            
            CGFloat height = (sample / 255.0) * graphRect.size.height;
            CGFloat xloc = graphRect.origin.x +   (graphPointsWidth / pointsInArray )  * k ;
            
            CGPathMoveToPoint (graphPath, nil, xloc, graphRect.origin.y+ (graphRect.size.height / 2) - height/2.0);
            CGPathAddLineToPoint (graphPath, nil, xloc, graphRect.origin.y+ (graphRect.size.height / 2) - height/2.0 + height );
        }
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetShouldAntialias (context, NO);
        CGContextSetLineWidth(context,0.5);
        CGContextSetAlpha(context, 1.0);
        
        CGContextSetStrokeColorWithColor(context,  color.CGColor);
        CGContextAddPath(context, graphPath);
        CGContextStrokePath(context);
        
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        CGPathRelease(graphPath);
        
    }
    
    return image;
    
}



+ (UIImage *)thumbnailImageForSirenVoiceMail: (Siren*) siren
                               frameSize: (CGSize) frameSize
                                   color: (UIColor *) color
{
    UIImage *image = NULL;
    
    if(siren)
    {
        
        NSString* durationText = @"??:??";
        NSString* callerIDtext = @"";
        NSString* callerIDName = @"";
        
        float topMargin = 10;
        float leftMargin = 10;
        float rightMargin = 10;
        
        UIImage* vmImage = [UIImage imageNamed: @"voicemail"] ;
        CGSize vmImageSize =  {40, 20};
        
        if( siren.callerIdNumber)
        {
            ECPhoneNumberFormatter *formatter = [[ECPhoneNumberFormatter alloc] init];
            callerIDtext = [formatter stringForObjectValue:siren.callerIdNumber];
          }
        
        
        if(siren.duration)
        {
            NSDateFormatter* durationFormatter =  [SCDateFormatter localizedDateFormatterFromTemplate:@"mmss"];
            durationText = [durationFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: siren.duration.doubleValue]];
        }
        
        if(siren.callerIdName)
        {
            callerIDName = siren.callerIdName;
        }
        
//        callerIDName = @"";
//        callerIDtext = @"";
        
        UIFont *titleFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        
        NSMutableParagraphStyle *titleStyle = [[NSMutableParagraphStyle alloc] init];
        titleStyle.lineBreakMode = NSLineBreakByTruncatingTail;
        titleStyle.alignment = NSTextAlignmentCenter;
        
        NSDictionary *attributes = @{
                                     NSFontAttributeName: titleFont,
                                     NSParagraphStyleAttributeName: titleStyle,
                                     NSForegroundColorAttributeName: color,
                                     };
        
        CGSize durationRectSize = [durationText sizeWithAttributes:attributes];
        CGSize callerIDRectSize = [callerIDtext sizeWithAttributes:attributes];
        CGSize callerIDNameRectSize = [callerIDName sizeWithAttributes:attributes];
        
        float widestWidth = MAX(vmImageSize.width + durationRectSize.width + 10 , callerIDRectSize.width);
        widestWidth = MAX(widestWidth, callerIDNameRectSize.width);
        
        float frameWidth = leftMargin + widestWidth + rightMargin;
        float topLineHeight =  MAX(durationRectSize.height, vmImageSize.height);
        
        float topLine =  topMargin ;
        float midLine =  topLine +  topLineHeight + 5;
        float bottomLine =  midLine +  callerIDNameRectSize.height + 5;
        
        float frameHeight = topMargin + topLineHeight
                + (callerIDName.length?callerIDNameRectSize.height + 5: 0)
                + (callerIDtext.length?callerIDRectSize.height + 5: 0)
                + topMargin ;
        
        CGSize newFrameSize = (CGSize) { .width = frameWidth,
            .height = frameHeight};
        
        CGRect textRect = (CGRect){
            .origin.x = frameWidth- durationRectSize.width - leftMargin,
            .origin.y = topLine  ,
            .size.width = durationRectSize.width,
            .size.height = durationRectSize.height
        };
        
        CGRect vmRect = (CGRect){
            .origin.x = leftMargin,
            .origin.y =   topLine,
            .size.width = vmImageSize.width,
            .size.height = vmImageSize.height
        };

        CGRect callerIDNameRect = (CGRect){
            .origin.x = frameWidth- callerIDNameRectSize.width - leftMargin,
            .origin.y = midLine  ,
            .size.width = callerIDNameRectSize.width,
            .size.height = callerIDNameRectSize.height
        };

        
        CGRect callerIDRect = (CGRect){
            .origin.x = frameWidth- callerIDRectSize.width - leftMargin,
            .origin.y = callerIDName.length?  bottomLine:midLine,
            .size.width = callerIDRectSize.width,
            .size.height = callerIDRectSize.height
        };
    
        UIGraphicsBeginImageContextWithOptions(newFrameSize, NO, 0);
  
        // draw   text
        [durationText drawInRect:textRect withAttributes:attributes];
        [callerIDName drawInRect:callerIDNameRect withAttributes:attributes];
        [callerIDtext drawInRect:callerIDRect withAttributes:attributes];

        
        [color set];
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextClipToMask(context, vmRect, [vmImage CGImage]);
        CGContextFillRect(context, vmRect);
        
        
//        CGContextRef context = UIGraphicsGetCurrentContext();
//        CGContextSetShouldAntialias (context, NO);
//        CGContextSetLineWidth(context,0.5);
//        CGContextSetAlpha(context, 1.0);
//        
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
    }
    
    return image;
  
}

@end
