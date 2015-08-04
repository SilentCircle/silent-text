//
//  MWSRadialScrollView.m
//  MWSRadialMenuDemo
//
//  Created by Eric Turner on 11/15/14.
//  Copyright (c) 2014 MagicWave Software, LLC. All rights reserved.
//


#import "MWSRadialScrollView.h"
#import <POP.h>


static CGFloat const kItemDiameter = 60.0f;
//static CGFloat const kPulseFactor = 1.25;
static CGFloat const kDefaultSpringBounciness = 12; //18;
static CGFloat const kDefaultSpringSpeed = 10;
static CGFloat const kInterspace = 0.8;
//static CGFloat const kInterspaceMAX = 0.8;
//static CGFloat const kSpinFactor = 0.000025;

typedef NS_ENUM(NSUInteger, AnimationDirection) {
    kPresent    = 0,
    kDismiss    = 1
};


@interface MWSRadialScrollView () <MWSRadialScrollViewDelegate>

@end

@implementation MWSRadialScrollView
{
    NSArray     *_items;
    NSUInteger  _animationCount;
    CGFloat     _itemInterspace; // in radians
    CGFloat     _presentationAngle; // given in the initializer
    CGPoint     _radialCenter;
    CGFloat     _boundsTop;    
    CGFloat     _boundsBottom;
    CGFloat     _midX;
    CGFloat     _midY;
    CGFloat     _boundsLeft;
    CGFloat     _boundsRight;
    CGFloat     _prevOffsetY;
    
//    CGFloat     _currentAngle;
//    CGFloat     _arcIncrement;
    CGFloat     _topAngleBounds;
    CGFloat     _bottomAngleBounds;
    CGFloat     _units;     // total number of items and spaces - (2*items -1)
    CGFloat     _unitAngle; // totalAngle divided by units
    
    __weak id<MWSRadialScrollViewDelegate>  _privateDelegate;
}

- (instancetype)initWithFrame:(CGRect)frame items:(NSArray *)items directionAngle:(CGFloat)angle {
    
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    _items = items;
    
    // The popMenu calculates the self frame large enough to fully encompass the items, which
    // when otherwise calculated as the diameter of the items circle intersects the top/sides/bottom
    // items midway.
    // itemRadiusForState:kPresent returns the given frame side value by the item diameter to acheive 
    // the radius describing a circle fully enclosed by the self frame rect, 
    // i.e. frame.size.width - kItemDiameter. This gives us the fully enclosed, outside-to-outside
    // items "box".
    // Then we pad 1/2 kItemDiameter to the contentSize.height so that we have a little scroll padding.
//    CGFloat side = 2*[self itemRadiusForState:kPresent];
////    self.contentSize = (CGSize){ .width = side, .height = side+kItemDiameter + kItemDiameter/2 }; 
//    self.contentSize = (CGSize){ .width = side, .height = sqrt( side*side + side*side ) };
//    
//    _itemInterspace = kInterspace;
//    _units = _items.count*2 -1;
//    _unitAngle = [self unitAngleArc];
//    _presentationAngle = angle; // Q1 45° (popMenu has adjusted for spacing)
////    _currentAngle = angle;
////    _arcIncrement = [self arcMultiple];
//    _topAngleBounds    = M_PI/2;   // item[0] origin TDC
//    _bottomAngleBounds = -3*M_PI/2; // item[count] origin BDC
//    
//    _radialCenter = (CGPoint){ .x = CGRectGetHeight(self.frame) / 2, .y = CGRectGetHeight(self.frame) / 2 };
//    _midX = CGRectGetMidX(self.bounds);
//    _midY = CGRectGetMidY(self.bounds); //-self.contentSize.height / 2;
//    _boundsTop = 0; //(CGPoint){ .x = self.center.x, .y = 0 };
//    //negative because topY is zero
//    // kItemDiameter less than actual bottom because we're testing/moving frame origin
//    _boundsBottom = CGRectGetHeight(self.bounds) - kItemDiameter; //-self.contentSize.height - kItemDiameter;
//    _boundsLeft  = 0;
//    _boundsRight = CGRectGetWidth(self.bounds) - kItemDiameter;
//    _prevOffsetY = self.contentOffset.y;
//    
//    // Initialize animation counter
//    _animationCount = 0;
    
    [self initializeIvarsWithPresentAngle:angle];
    
    // Set to no so that the spring animation which will briefly bounce the items 
    // outside the self bounds will not clip them
    self.clipsToBounds = NO;
    
    return self;
}

- (void)presentItems {
    [self animateItems:kPresent];
}


- (void)dismissItems {
    [self animateItems:kDismiss];
}


#pragma mark - Item Menu Animations

- (void)animateItems:(AnimationDirection)direction {
    NSLog(@"%s called",__PRETTY_FUNCTION__);
    
    BOOL expand = (kPresent == direction);
//    if (_itemMenuIsPresented && expand)
//        return;
    
//    _isItemMenuPresenting = YES;
    NSString *animName = (expand) ? @"presentItems" : @"dismissItems";
    
//    CGPoint center  = [self centerPoint];
//    CGPoint center = (CGPoint){ .x = 0, .y = centerY };
//    CGFloat diameter = (expand) ? kItemDiameter : _contractedSide;
//    CGSize endSize = (CGSize){ .width = diameter, .height = diameter };
//
//    if (expand) {
//        for (UIImageView *itemView in _items) {
//            if (![self.subviews containsObject:itemView]) {                
////                CGSize startSize = (CGSize){ .width = kItemDiameter, .height = kItemDiameter };
//                CGSize startSize = (CGSize){ .width = _contractedSide, .height = _contractedSide };
//                CGPoint center = [self centerPoint];
//                CGRect startFrame = (CGRect){ center, startSize };
//                itemView.frame = startFrame;
//                
//                [self addSubview:itemView];
//            }
//        }
//    }
    
//    CGFloat diameter = (expand) ? kItemDiameter : _contractedSide;
    CGSize endSize = (CGSize){ .width = kItemDiameter, .height = kItemDiameter };
    CGPoint center = _radialCenter; //[self radialCenter];
    
    if (expand) {
        for (UIImageView *itemView in _items) {
            if (![self.subviews containsObject:itemView]) {
                CGSize startSize = CGSizeZero;
                CGRect startFrame = (CGRect){ center, startSize };
                itemView.frame = startFrame;
                
                [self addSubview:itemView];
            }
        }
    }


    for (NSUInteger itemIdx=0; itemIdx < _items.count; itemIdx++) {
        
        UIImageView *itemView = _items[itemIdx];
        CGPoint position = (expand) ? [self pointForItemAtIndex:itemIdx delta:0] : center;
        
        // Log
//        NSLog(@"%s item[%d] position:%@",__PRETTY_FUNCTION__, itemIdx, NSStringFromCGPoint(position));
        
        // Spring animate expand to position
        if (expand) {
            POPSpringAnimation *push = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerPosition];
            push.delegate = self;
            push.toValue = [NSValue valueWithCGPoint:position];
            push.springBounciness = kDefaultSpringBounciness;
            push.springSpeed = kDefaultSpringSpeed;
            push.name = animName;
            [itemView pop_addAnimation:push forKey:animName];
        }
        // Basic/linear animate to contract back to center
        else  {
            POPBasicAnimation *pull = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPosition];
            pull.delegate = self;
            pull.toValue = [NSValue valueWithCGPoint:position];
            pull.duration = 0.15;
            pull.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
            pull.name = animName;
            [itemView pop_addAnimation:pull forKey:animName]; 
        }
        
        // Scale item to endSize
        POPBasicAnimation *scale = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerSize];
        scale.toValue = [NSValue valueWithCGSize:endSize];
        scale.duration = 0.15;
        scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        [itemView pop_addAnimation:scale forKey:@"scaleItemSize"]; 
    }
}

#pragma mark - Item Menu Utilities

- (void)initializeIvarsWithPresentAngle:(CGFloat)angle {
// 45° in Quadrant I
//    CGFloat presentAngle = -M_PI/4;
//    // adjust for interspace
//    presentAngle += _iconInterspace / 2;
//    return presentAngle;
    
    _presentationAngle = angle; // Q1 45° from popMenu
    _itemInterspace = kInterspace;

    CGFloat radius = [self itemRadiusForState:kPresent];
    CGFloat side = 2*radius;
//    CGFloat circumference = M_PI*side;
    self.contentSize = (CGSize){ .width = side, .height = sqrt( side*side + side*side ) };
    
    _itemInterspace = kInterspace;
    _units = _items.count*2 -1;
    _unitAngle = [self unitAngleArc];
    
    _topAngleBounds    = -M_PI/2; // item[0] origin TDC
    _bottomAngleBounds = M_PI/2;  // item[count] origin BDC
    
    _radialCenter = (CGPoint){ .x = CGRectGetHeight(self.frame) / 2, .y = CGRectGetHeight(self.frame) / 2 };
//    _midX = CGRectGetMidX(self.bounds);
//    _midY = CGRectGetMidY(self.bounds); //-self.contentSize.height / 2;
//    _boundsTop = 0; //(CGPoint){ .x = self.center.x, .y = 0 };
//    //negative because topY is zero
//    // kItemDiameter less than actual bottom because we're testing/moving frame origin
//    _boundsBottom = CGRectGetHeight(self.bounds) - kItemDiameter; //-self.contentSize.height - kItemDiameter;
//    _boundsLeft  = 0;
//    _boundsRight = CGRectGetWidth(self.bounds) - kItemDiameter;
    _prevOffsetY = self.contentOffset.y;
    _animationCount = 0; // animation counter
    
}

- (CGFloat)itemRadiusForState:(AnimationDirection)direction {
    CGFloat r = 0; // _contractedSide / 2; // contracted is 1/2 contractedSide
    if (kPresent == direction) {
        // 1/2 contracted side + 2x kItemDiameter - 1/2 kItemDiamter
//        r += (1.5 * kItemDiameter);
        CGFloat inset = kItemDiameter;
        r = (self.frame.size.width - inset) / 2;
    }
    return r;
}

#pragma warning start/stop angle not correct - crashes
- (CGFloat)angleForItemAtIndex:(NSUInteger)idx delta:(CGFloat)delta {
    CGFloat totalAngle = [self totalSpacesArc];
//    CGFloat deltaInc = //(delta > 0) ? _arcIncrement / delta : 0;
    CGFloat testAngle = (_presentationAngle + delta) - (totalAngle / 2); // apply the delta and test for bounds
    // positive delta (scrolling DOWN) is clockwise
    CGFloat deltaAngle = (idx == 0 && testAngle < _bottomAngleBounds) ? testAngle : 0;    // DOWN: test bottom bounds
    // negative delta (scrolling UP) is counterclockwise
    deltaAngle = (idx == _items.count -1 && testAngle > _topAngleBounds) ? testAngle : 0; // UP: test top bounds
//    CGFloat totalAngle = [self totalSpacesArc]; //(_items.count - 1) * _itemInterspace;
//    CGFloat startAngle = _presentationAngle - totalAngle / 2; //M_PI - (totalAngle / 2);
    CGFloat startAngle = _presentationAngle - totalAngle / 2; //_currentAngle + deltaInc - totalAngle / 2;
    CGFloat retAngle = startAngle + deltaAngle + idx * _itemInterspace;
    
// Log
//    NSLog(@"%s\ninterSpace: %1.2f \ntotalAngle: %1.2f \nstartAngle: %1.2f \nangleForItemAtIndex[%d]: %1.2f",
//          __PRETTY_FUNCTION__,interSpace,totalAngle,startAngle,idx,retAngle);
    
    return retAngle;
}

// This should only be called for an expansion
// (h+rcosθ,k+rsinθ), where (h,k) == center, r == radius, θ == angle
//
// @param delta A value in radians, positive or negative, by which to rotate the angle
// - a zero value means apply no delta
- (CGPoint)pointForItemAtIndex:(NSUInteger)idx delta:(CGFloat)delta {
    CGFloat angle = [self angleForItemAtIndex:idx delta:delta];
    CGPoint center = _radialCenter; //[self radialCenter];
    CGFloat radius = [self itemRadiusForState:kPresent];
    CGPoint point  = (CGPoint){ 
        .x = center.x + radius * cosf(angle),
        .y = center.y + radius * sinf(angle) 
    };
    return point;
}

- (CGFloat)arcMultiple {
    CGFloat total = [self totalArcItemsAndSpaces];
    CGFloat m = total / (_items.count + (_items.count -1));
    return m;
}

- (CGFloat)unitAngleArc {
    CGFloat total = [self totalArcItemsAndSpaces];
    CGFloat unitAngle = total / (2*total - 1); // total arc divided by items+spaces (2*items+spaces - 1)
    return unitAngle;
}

// in radians
// approximate since we're using diameters/spaces and not radians to calculate
- (CGFloat)totalArcItemsAndSpaces {
    CGFloat total = [self totalItemsArc] + [self totalSpacesArc];
    return total;
}

// in radians
// approximate since we're using diameters/spaces and not radians to calculate
- (CGFloat)totalItemsArc {
    CGFloat items = _items.count * kItemDiameter;
    return items;
}

// in radians
// approximate since we're using diameters/spaces and not radians to calculate
- (CGFloat)totalSpacesArc {
    CGFloat spaces = (_items.count - 1) * _itemInterspace;
    return spaces;
}

#pragma mark - Scrolling

- (void)positionItemsForScrollEvent {
    NSString *currOffsetStr = NSStringFromCGPoint(self.contentOffset);
    NSLog(@"%s\n\ncontentOffset: %@",__PRETTY_FUNCTION__, currOffsetStr);
    
    
    // NOTE: scrolling DOWN means increasing NEGATIVE y - UP means toward zero
    CGFloat currentY = self.contentOffset.y;
    __block CGFloat delta = abs(currentY - _prevOffsetY);
//    CGFloat delta = currentY - _prevOffsetY;
    BOOL pullingDown = _prevOffsetY > currentY;//delta < 0;
    
    NSLog(@"\n\n-------------------------------------------------------------------------------\n\n");
    
    NSLog(@"\n\ncurrentOffset:%@\ndelta(%1.2f) = currentY(%1.2f) - _prevOffsetY(%1.2f) - %@\n\n",
          currOffsetStr, delta, currentY, _prevOffsetY, (pullingDown)?@"Going DOWN":@"Going UP");
    
    [_items enumerateObjectsUsingBlock:^(UIView *item, NSUInteger idx, BOOL *stop) {
        // negative delta/angle (clockwise) for pulling down; positive delta/angle for counterclockwise
        delta = (pullingDown) ? 1/delta : -1/delta;
        CGPoint center = [self pointForItemAtIndex:idx delta:delta];
        item.center = center;
    }];
}


#pragma mark - POP Animation Delegate

- (void)pop_animationDidStop:(POPAnimation *)anim finished:(BOOL)finished {
    
    if (finished) {
        if ([anim.name isEqualToString:@"presentItems"]) {
            if ([self.delegate respondsToSelector:@selector(radialScrollViewDidFinishPresenting)]) {
                _animationCount++;
                if (_animationCount == _items.count) {
                    [self.delegate radialScrollViewDidFinishPresenting];
                    _animationCount = 0;
                }
            }
        }
        else if ([anim.name isEqualToString:@"dismissItems"]) {
            if ([self.delegate respondsToSelector:@selector(radialScrollViewDidFinishDismissing)]) {
                [self.delegate radialScrollViewDidFinishDismissing];
            }            
        }
    }
}

#pragma mark - Delegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//    NSLog(@"%s called",__PRETTY_FUNCTION__);
    [self positionItemsForScrollEvent];
}

- (void)radialScrollViewDidFinishPresenting {
    if ([_privateDelegate respondsToSelector:@selector(radialScrollViewDidFinishPresenting)]) {
        [_privateDelegate radialScrollViewDidFinishPresenting];
    }
}

- (void)radialScrollViewDidFinishDismissing {
    if ([_privateDelegate respondsToSelector:@selector(radialScrollViewDidFinishDismissing)]) {
        [_privateDelegate radialScrollViewDidFinishDismissing];
    }
}

// Override setter to swizzle the private delegate
- (void)setDelegate:(id<MWSRadialScrollViewDelegate>)aDelegate {
    [super setDelegate:self];
    if (aDelegate != self) {
        _privateDelegate = aDelegate;
    }
}

@end
    