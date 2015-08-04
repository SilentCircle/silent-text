//
//  MWSRadialPopMenu.m
//  PopPlayground
//
//  Created by Eric Turner on 11/1/14.
//  Copyright (c) 2014 Victor Baro. All rights reserved.
//

#import "MWSRadialPopMenu.h"
#import "MWSRadialScrollView.h"
#import "MWSTouchOverlayView.h"
#import "SadunQuartzUtilities.h"
#import <POP.h>
//SC
#import "AppDelegate.h"
#import "AppTheme.h"

// Categories
#import "UIImage+ImageEffects.h"


BOOL const POP_MENU_CENTER = NO;

// private
static CGFloat const kIconDiameter = 45.0f; //60.0f;
static CGFloat const kItemOuterMargin = 18.0f;
static CGFloat const kInterspace = 0.75; //orig
static CGFloat const kPulseFactor = 1.25;
static CGFloat const kDefaultSpringBounciness = 12; //18;
static CGFloat const kDefaultSpringSpeed = 10;

// FOR TESTING SCROLLVIEW in screen center
static BOOL const USE_TOUCHVIEW = !YES; //!POP_MENU_CENTER;

typedef NS_ENUM(NSUInteger, AnimationDirection) {
    kExpand   = 0,
    kContract = 1
};


@interface MWSRadialPopMenu () <POPAnimationDelegate, TouchOverlayDelegate> {

    BOOL _isMenuPresenting;
    BOOL _menuIsPresented;
    BOOL _isItemMenuPresenting;
    BOOL _itemsMenuIsPresented;
    
//    CGFloat _iconsAngleDirection;   // given in the initializer
    CGFloat _itemsInterspace;        // in radians
    CGFloat _itemDiameter;
    CGFloat _itemsInnerMargin;
//    CGFloat _iconOuterMargin = 18.0f;
    
    // From scrollView branch
    CGPoint     _radialCenter;
    CGFloat     _presentationAngle; // given in the initializer
    NSUInteger  _animationCount;
    CGFloat     _topAngleBounds;
    CGFloat     _bottomAngleBounds;
    CGFloat     _units;     // total number of items and spaces - (2*items -1)
    CGFloat     _unitAngle; // totalAngle divided by units

    
    // TouchView gestureRecognizers
    UITapGestureRecognizer *_tapGR;
    UIPanGestureRecognizer *_panGR;
    
    // Base Menu Layer
    CALayer *_baseMenuLayer;
    UIView *_itemsMenuView;
    
    // PresentingView
    CGFloat _contractedSide;
    CGFloat _presentBorderWidth;
    CGFloat _presentCornerRadiusRatio;
    UIColor *_presentBorderColor;
    BOOL _presentViewIsExpanded;
}
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, weak) UIView *presentingView;
@property (nonatomic, weak) UIView *contextView;
@property (nonatomic, strong) MWSTouchOverlayView *touchView;
@end


@implementation MWSRadialPopMenu


- (instancetype)initWithFrame:(CGRect)frame 
                    direction:(CGFloat)directionInRadians 
                    iconArray:(NSArray *)menuItems 
                 presentingView:(UIView *)aView 
                  contextView:(UIView *)cView
{
    CGRect squareFrame = LargeSquareFromRect(frame);
    self = [super initWithFrame:squareFrame];
    if (!self) return nil;
            
    // SELF: 
    self.clipsToBounds = NO; // for expanding layers
    // Configure self to round to _presentingView size (assumes self is under the presentingView)
    CALayer *layer = self.layer;        
    layer.cornerRadius = squareFrame.size.width/2;
    self.backgroundColor = [UIColor clearColor];
    
    // PRESENTING VIEW
    _presentingView = aView;
    _presentBorderWidth = aView.layer.borderWidth;
    _presentCornerRadiusRatio = 1;    
    if (aView.frame.size.width == aView.frame.size.height && aView.layer.cornerRadius > 0) // if square, set the ratio
        _presentCornerRadiusRatio = aView.layer.cornerRadius / aView.frame.size.width;
    _presentBorderColor = [UIColor colorWithCGColor:aView.layer.borderColor];
    _contractedSide = squareFrame.size.width;
    
    _contextView = cView;

//    NSAssert(menuItems.count > 0 && nil != menuItems, @"The items array argument must not be nil or empty");
//    UIImage *icon = _items[0];
//    _itemDiameter = icon.size.width; // must be square
    
    // MENU ICONS
    // Configure iconViews from given icon images
    menuItems = (menuItems) ?: [self scItems]; // silent circle icons
    [self configureItemsWithImages:menuItems];
    
    // Initialize ivars
    [self initializeIvarsWithPresentAngle:directionInRadians];

    // LONG PRESS
//    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]initWithTarget:self
//                                                                                           action:@selector(handleLongPress:)];
//    longPress.minimumPressDuration = 0.25;
//    UIView *theView = (aView) ?: self;
//    [theView addGestureRecognizer:longPress];
    
    // SC demo
    UIButton *btnPresent = (UIButton *)aView;
    [self configurePresentButton:btnPresent];
    
    return self;
}

// TMP for SC demo
- (void)configurePresentButton:(UIButton *)btn {
//    [btn removeTarget:nil action:nil forControlEvents:UIControlEventAllEvents];
    [btn addTarget:self action:@selector(handleSCDemoTap:) forControlEvents:UIControlEventTouchUpInside];
}

// TMP for SC demo
- (void)handleSCDemoTap:(UIButton *)sender {
    if (_isItemMenuPresenting || _isMenuPresenting)
        return;
    
    if (_itemsMenuIsPresented)
        [self dismissMenu];
    else
        [self presentMenu];
}

- (void)initializeIvarsWithPresentAngle:(CGFloat)angle {

    _itemsInterspace   = kInterspace;
    _itemDiameter      = kIconDiameter;
    _itemsInnerMargin  = _itemDiameter/3;
    _presentationAngle = -3*M_PI_4; //-M_PI_4; // 45° in Quadrant I

//    CGFloat radius = [self itemsRadiusForState:kExpand];
//    CGFloat side = 2*radius;
//    CGFloat circumference = M_PI*side;    
//    _units = _items.count*2 -1;
//    _unitAngle = [self unitAngleArc];
//    
//    _topAngleBounds    = -M_PI/2; // item[0] origin TDC
//    _bottomAngleBounds = M_PI/2;  // item[count] origin BDC

    _animationCount = 0; // animation counter    
}


- (void)handleLongPress:(UILongPressGestureRecognizer *)gr {
    
    switch(gr.state){
        case UIGestureRecognizerStateBegan:
            // Expand the presentingView (btnStart)
            [self pulsePresentingView:kExpand];
            [self presentMenu];            
            break;
            
        case UIGestureRecognizerStateChanged:
//            NSLog(@"Gesture state changed");
            break;
        case UIGestureRecognizerStateCancelled: 
//            NSLog(@"Gesture Cancelled");
            break;
        case UIGestureRecognizerStateEnded:
//            NSLog(@"Gesture Ended");
            break;
        default:
            break;
    }
}


- (void)pop_animationDidStop:(POPAnimation *)anim finished:(BOOL)finished {

    if (finished) {
        // PRESENTING VIEW PULSE
        if ([anim.name isEqualToString:@"pulseViewExpand"] || [anim.name isEqualToString:@"pulseViewContract"]) {
            
            // toggle flag
            _presentViewIsExpanded = ([anim.name isEqualToString:@"pulseViewExpand"]);
            // Log
//            NSLog(@"AnimationDidStop for name: %@", anim.name);
//            NSLog(@"%s \n_presentViewIsExpanded: %@ \ncornerRadius:%1.2f", __PRETTY_FUNCTION__,
//                    (_presentViewIsExpanded)?@"YES":@"NO",_presentingView.layer.cornerRadius);
        } 
        // BASE MENU LAYER
        else if ([anim.name isEqualToString:@"baseMenuExpand"] || [anim.name isEqualToString:@"baseMenuContract"]) {
            
            BOOL isPresented = [anim.name isEqualToString:@"baseMenuExpand"];
            // toggle flags
            _menuIsPresented = isPresented;
            _isMenuPresenting = NO;
            if (NO == isPresented)
                [self dismissBaseMenuLayer];            
        } 
        // ITEMS MENU VIEW
        else if ([anim.name isEqualToString:@"presentItems"] || [anim.name isEqualToString:@"dismissItems"]) {
            _animationCount++;
            if (_animationCount == _items.count) {
                BOOL isPresented = [anim.name isEqualToString:@"presentItems"];
                _itemsMenuIsPresented = isPresented;
                _isItemMenuPresenting = NO;
                _animationCount = 0;
                
                if (NO == isPresented) {
                    [self removeItemsMenuView];
                    
                    if ([_delegate respondsToSelector:@selector(radialMenuDidDismiss)]) {
                        [_delegate radialMenuDidDismiss];
                    }
                }
            }
        }
    }
}

- (void)presentMenu {
    if (USE_TOUCHVIEW)
        [self presentTouchOverlayView];
    
    [self scaleBaseMenuView:kExpand];
    [self configureItemsViewForState:kExpand];
    [self animateItems:kExpand];
}

- (void)dismissMenu {
    [self scaleBaseMenuView:kContract];
    [self animateItems:kContract];
    [self dismissTouchOverlayView];
    [self pulsePresentingView:kContract];
}


#pragma mark - BaseMenuLayer
- (void)scaleBaseMenuView:(AnimationDirection)direction {
    NSLog(@"%s called",__PRETTY_FUNCTION__);
    
    if (_isMenuPresenting)
        return;
    
    _isMenuPresenting = YES;
    NSString *animName = (kExpand == direction) ? @"baseMenuExpand" : @"baseMenuContract";
    NSTimeInterval duration = (kExpand == direction) ? 0.15 : 0.25;
    
    CGPoint baseCenter = [self centerPoint];
    CGRect finishRect = [self baseMenuRectForState:direction center:baseCenter];
    
    if (NO == [self.layer.sublayers containsObject:_baseMenuLayer]) {
                
        CGFloat radius = [self baseMenuRadiusForState:direction];

        _baseMenuLayer = [CALayer layer];
        _baseMenuLayer.frame = finishRect; // required
        _baseMenuLayer.backgroundColor = [UIColor clearColor].CGColor;

//        if (NO == POP_MENU_CENTER) {
            // Blurred radial background
            CGRect blurFrame = [self baseMenuRectForState:kExpand center:baseCenter];
            blurFrame = [self convertRect:blurFrame toCoordinateSpace:_contextView];

            // clip to a contextView coordinate path
            UIBezierPath *path = [self bezierPathWithFrame:blurFrame radius:radius];
            MovePathToPoint(path, (CGPoint){ .x = 0, .y = 0 });
            CGRect blurRect = PathBoundingBox(path);

            UIGraphicsBeginImageContextWithOptions(blurRect.size, NO, 0);
            
            [path clipToPath];

            BOOL result = [_contextView drawViewHierarchyInRect:blurFrame afterScreenUpdates:YES];        
            UIImage *snapImg = UIGraphicsGetImageFromCurrentImageContext();
      
            if (result) {            
                // blur
                UIImage *blurredImg = [snapImg applyDarkEffect];
                [blurredImg drawInRect: blurRect];
                
//                Gradient *rainbow = [Gradient rainbow];
//                DrawGradientOverTexture(path, blurredImg, rainbow, 0.5);
                EmbossPath(path, WHITE_LEVEL(0, 0.5), 2, 2);
                
                UIImage *bgImg = UIGraphicsGetImageFromCurrentImageContext();
                _baseMenuLayer.contents = (id)bgImg.CGImage;
            }
            else
                NSLog(@"drawViewHierarchyInRect failed");
          
            UIGraphicsEndImageContext();
//        }
        
        // Log
//        CGPoint center = [self centerPoint];
//        NSLog(@"%s \nbaseMenuEndFrame:%@ \nlayerCenter:%@", __PRETTY_FUNCTION__,
//              NSStringFromCGRect(outerRect), 
//              NSStringFromCGPoint(center));

        // Add to self view
        [self.layer insertSublayer:_baseMenuLayer atIndex:0];
        
        // Start from CGSizeZero
        CGRect startRect = finishRect;
        startRect.size = CGSizeZero;
        _baseMenuLayer.bounds = startRect;
    }
        
    // Basic (linear) scale animation
    POPBasicAnimation *scaleSize = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerSize];
    scaleSize.delegate = self;
    scaleSize.duration = duration;
    scaleSize.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    scaleSize.toValue = [NSValue valueWithCGSize:finishRect.size];
    scaleSize.name = animName;
    [_baseMenuLayer pop_addAnimation:scaleSize forKey:animName];

}

- (void)dismissBaseMenuLayer {
    [_baseMenuLayer removeFromSuperlayer];
    _baseMenuLayer = nil;
}


#pragma mark - Base Layer Utilities

- (CGFloat)baseMenuRadiusForState:(AnimationDirection)direction {
    if (kContract == direction)
        return _contractedSide / 2;
    
    CGFloat r = [self itemsRadiusForState:direction];   
    r += _itemDiameter/2 + kItemOuterMargin;
    return r;
}

- (CGSize)baseMenuSizeForState:(AnimationDirection)direction {
    CGFloat sideSize = [self baseMenuRadiusForState:direction] * 2;
    CGSize  endSize  = (CGSize){ .width = sideSize, .height = sideSize };
    return  endSize;
}

- (CGRect)baseMenuRectForState:(AnimationDirection)direction center:(CGPoint)ptCenter {
    CGRect endFrame = RectAroundCenter(ptCenter, [self baseMenuSizeForState:direction]);
    return endFrame;
}
// Used by baseMenu and baseMenu point detection
- (UIBezierPath *)bezierPathWithFrame:(CGRect)aFrame radius:(CGFloat)aRadius {
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:aFrame cornerRadius:aRadius];
    return path;
}


#pragma mark - Item Menu Animations
- (void)animateItems:(AnimationDirection)direction {
    NSLog(@"%s called",__PRETTY_FUNCTION__);
    
    BOOL expand = (kExpand == direction);
    if (_itemsMenuIsPresented && expand)
        return;
    
    _isItemMenuPresenting = YES;
    NSString *animName = (expand) ? @"presentItems" : @"dismissItems";
    
    CGSize endSize = (CGSize){ .width = _itemDiameter, .height = _itemDiameter };
    CGPoint center = _radialCenter;
    
    if (expand) {
        for (UIImageView *itemView in _items) {
            if (![_itemsMenuView.subviews containsObject:itemView]) {
                CGSize startSize = CGSizeZero;
                CGRect startFrame = (CGRect){ center, startSize };
                itemView.frame = startFrame;
                
                [_itemsMenuView addSubview:itemView];
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

- (CGFloat)itemsRadiusForState:(AnimationDirection)direction {
    CGFloat r = _contractedSide / 2; // contracted is 1/2 contractedSide
    if (kExpand == direction) {
        // the radius describes the half of a side of a rect which will intersect the
        // top/sides/bottom icons midway. So we make the radius big enough to enclose
        // the items fully, so that the scrollview can define its contentView in terms
        // of its frame size.
//        r = kIconDiameter/2 + kIconInnerMargin + kIconDiameter; // orig
//        CGFloat outset = _itemDiameter/2;
//        r = _itemDiameter/2 + _itemsInnerMargin + _itemDiameter + outset;
        r = (_contractedSide*kPulseFactor)/2 + _itemsInnerMargin + _itemDiameter;
    }
    return r;
}

- (CGFloat)angleForItemAtIndex:(NSUInteger)idx {
//    CGFloat interSpace = _itemsInterspace;
//    CGFloat totalAngle = (_items.count - 1) * _itemsInterspace;
//    CGFloat startAngle = _presentationAngle - totalAngle / 2;
//    CGFloat retAngle = startAngle + idx * interSpace;
    CGFloat retAngle = _presentationAngle + idx * _itemsInterspace;

    return retAngle;
}

//#pragma warning start/stop angle not correct - crashes
//- (CGFloat)angleForItemAtIndex:(NSUInteger)idx delta:(CGFloat)delta {
//    CGFloat totalAngle = [self totalSpacesArc];
////    CGFloat deltaInc = //(delta > 0) ? _arcIncrement / delta : 0;
//    CGFloat testAngle = (_presentationAngle + delta) - (totalAngle / 2); // apply the delta and test for bounds
//    // positive delta (scrolling DOWN) is clockwise
//    CGFloat deltaAngle = (idx == 0 && testAngle < _bottomAngleBounds) ? testAngle : 0;    // DOWN: test bottom bounds
//    // negative delta (scrolling UP) is counterclockwise
//    deltaAngle = (idx == _items.count -1 && testAngle > _topAngleBounds) ? testAngle : 0; // UP: test top bounds
////    CGFloat totalAngle = [self totalSpacesArc]; //(_items.count - 1) * _itemInterspace;
////    CGFloat startAngle = _presentationAngle - totalAngle / 2; //M_PI - (totalAngle / 2);
//    CGFloat startAngle = _presentationAngle - totalAngle / 2; //_currentAngle + deltaInc - totalAngle / 2;
//    CGFloat retAngle = startAngle + deltaAngle + idx * _itemsInterspace;
//    
//    // Log
////    NSLog(@"%s\ninterSpace: %1.2f \ntotalAngle: %1.2f \nstartAngle: %1.2f \nangleForItemAtIndex[%d]: %1.2f",
////          __PRETTY_FUNCTION__,interSpace,totalAngle,startAngle,idx,retAngle);
//    
//    return retAngle;
//}

// This should only be called for an expansion
// (h+rcosθ,k+rsinθ), where (h,k) == center, r == radius, θ == angle
//
// @param delta A value in radians, positive or negative, by which to rotate the angle
// - a zero value means apply no delta
- (CGPoint)pointForItemAtIndex:(NSUInteger)idx delta:(CGFloat)delta {
//    CGFloat angle = [self angleForItemAtIndex:idx delta:delta];
    CGFloat angle = [self angleForItemAtIndex:idx];
    CGPoint center = _radialCenter;
    CGFloat radius = [self itemsRadiusForState:kExpand];
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
    CGFloat items = _items.count * _itemDiameter;
    return items;
}

// in radians
// approximate since we're using diameters/spaces and not radians to calculate
- (CGFloat)totalSpacesArc {
    CGFloat spaces = (_items.count - 1) * _itemsInterspace;
    return spaces;
}

- (CGFloat)itemsTotalAngle {
    CGFloat totalAngle = (_items.count - 1) * _itemsInterspace;
    return totalAngle;
}

#pragma mark - Items Menu View
- (void)configureItemsViewForState:(AnimationDirection)direction {
    if (nil == _itemsMenuView) {
        
        CGFloat iconRadius = [self itemsRadiusForState:kExpand];
        CGPoint selfCenter = [self centerPoint];
        CGPoint origin = (CGPoint){ .x = selfCenter.x - iconRadius, .y = selfCenter.y - iconRadius };
        CGRect frame = (CGRect){ origin, (CGSize){ .width = iconRadius*2, .height = iconRadius*2 } };

        UIView *view = [[UIView alloc] initWithFrame:frame];
        
        // TEST: display the scrollView centered in the VC view while developing MWSRadialScrollView
        // because as self subview, outside the self bounds, scroll touches are not received, even
        // without the touchOverlayView.
        if (POP_MENU_CENTER) {
            // TEST
//            view.backgroundColor = [UIColor colorWithRed:128.0/255.0 green:0 blue:0 alpha:0.5];
            view.backgroundColor = [UIColor clearColor];
            view.center = self.superview.superview.center;
            [self.superview.superview addSubview:view];
        }
        else {
            [self addSubview:view];
        }
        
        _itemsMenuView = view;
        
        _radialCenter = (CGPoint){ .x = CGRectGetHeight(frame) / 2, .y = CGRectGetHeight(frame) / 2 };
    }
}

- (void)removeItemsMenuView {
    [_itemsMenuView removeFromSuperview];
    _itemsMenuView = nil;
}

- (NSArray *)scItems {
    return @[[UIImage imageNamed:@"paperclip"],
             [UIImage imageNamed:@"camera"],
             [UIImage imageNamed:@"microphone"],
             [UIImage imageNamed:@"flame_off"],
             [UIImage imageNamed:@"map_off"],
             [UIImage imageNamed:@"fyeo-off"],             
             [UIImage imageNamed:@"SilentPhone_CircleIcon30"]];
}

#pragma mark - General Utilities

// Returns a rect of the given size, with origin centered in the given rect
// Uses Sadun Quartz Pack Geometry utilities
- (CGRect)rectWithSize:(CGSize)aSize centeredWithRect:(CGRect)aRect {
    CGPoint center = RectGetCenter(aRect);
    CGRect retRect = RectAroundCenter(center, aSize);
    return retRect;
}


// This will go away in favor of MWSRadialMenuItems
// Configure the icon images given in initialization into imageViews in the __items array
- (void)configureItemsWithImages:(NSArray *)images {    
    NSMutableArray *tmpArray = @[].mutableCopy;
    for (UIImage *image in images) {
        UIImageView *itemView = [[UIImageView alloc]initWithImage:image];
        // For SC
        itemView.frame = (CGRect){ CGPointZero, (CGSize){ .width = kIconDiameter, .height = kIconDiameter } };
//        CALayer *layer = itemView.layer;
//        layer.cornerRadius = kIconDiameter/2;
//        layer.borderWidth  = 2.0;
//        layer.borderColor  = [UIColor whiteColor].CGColor;
        
        [tmpArray addObject:itemView];
    }
    _items = [NSArray arrayWithArray:tmpArray];
}


#pragma Point and Conversion

// Converts from touchView to superview coordinates
// (I think I remember that this is because) the self frame is never enlarged. Note that MWSViewController
// initializes self with the _presentingView.frame (a 44 point square UIButton).
// Since all of the visible menu is outside self bounds, we calculate touch points in the superview
// coordinate space.
- (CGPoint)pointFromTouchPoint:(CGPoint)ptTouch {
    CGPoint point = [_touchView convertPoint:ptTouch toCoordinateSpace:self.superview];
    
    // Log
    NSLog(@"%s \noverlay point: %@ \nconverted point: %@", __PRETTY_FUNCTION__, 
          NSStringFromCGPoint(ptTouch), NSStringFromCGPoint(point));
    
    return point;
}

// pt expected to be in self coordinates
- (BOOL)pointInsideBaseMenu:(CGPoint)pt {
    CGPoint superCenter = [self superCenterPoint];
    CGRect endFrame = [self baseMenuRectForState:kExpand center:superCenter];
    UIBezierPath *path = [self bezierPathWithFrame:endFrame radius:[self baseMenuRadiusForState:kExpand]]; 
    
    // Log
    BOOL isInside = [path containsPoint:pt];
    NSLog(@"%s \nbaseMenuFrame: %@ \npoint: %@ \nisInside: %@", __PRETTY_FUNCTION__, 
          NSStringFromCGRect(endFrame), NSStringFromCGPoint(pt), (isInside)?@"YES":@"NO");
    
    return [path containsPoint:pt];
}

// Note the disparity between the pointInsideBaseMenu, which expects its given point to have
// already been converted from touchView to superview coordinates, and this method, which
// does the conversion from touchView to scrollView coordinates.
// Needs fixing?
//- (BOOL)pointInsideScrollView:(CGPoint)ptTouch {
//    CGPoint point = [_touchView convertPoint:ptTouch toCoordinateSpace:_scrollView];
//    BOOL isInside = CGRectContainsPoint(_scrollView.bounds, point);
//    return isInside;
//}



- (CGPoint)centerPoint {
    CGFloat halfSide = _contractedSide / 2;
    CGPoint center = (CGPoint){.x = halfSide, .y = halfSide};
    return center;
}

- (CGPoint)superCenterPoint {
    CGPoint sPt = [self convertPoint:[self centerPoint] toCoordinateSpace:self.superview];
    return sPt;
}


#pragma mark - TouchView Methods

- (void)presentTouchOverlayView {
    NSLog(@"%s called",__PRETTY_FUNCTION__);
    
    if (nil == _touchView) {
        MWSTouchOverlayView *touchesView = [[MWSTouchOverlayView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        touchesView.delegate = self;
        [self.window addSubview:touchesView];
        
        //TEST
//        touchesView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:255.0 alpha:0.5];
        touchesView.backgroundColor = [UIColor clearColor];
    
        UITapGestureRecognizer *gr = [[UITapGestureRecognizer alloc] initWithTarget:self 
                                                                             action:@selector(handleTouchViewTap:)];
        gr.numberOfTapsRequired = 1;
        gr.numberOfTouchesRequired = 1;
        [touchesView addGestureRecognizer:gr];
        _tapGR = gr;
        _touchView = touchesView;
    }
}

#pragma mark - Pan Gesture Methods

// Only handle gesture recognizer ivars
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // Only receive the touch if in the scrollview area
    if ([gestureRecognizer isEqual:_panGR]) {
        CGPoint touchViewPoint = [touch locationInView:_touchView];
//        BOOL shouldRecieve = [self pointInsideScrollView:touchViewPoint];
        BOOL shouldRecieve = [self pointInsideBaseMenu:touchViewPoint];
        return shouldRecieve;
    }
    else if ([gestureRecognizer isEqual:_tapGR]) { 
        return YES;
    }
    return NO;
}

//- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
////    NSLog(@"%s called",__PRETTY_FUNCTION__);
//}
//
//- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
////    NSLog(@"%s called",__PRETTY_FUNCTION__);
//}
//
//- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
////    NSLog(@"%s called",__PRETTY_FUNCTION__);
//}
//
//- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
////    NSLog(@"%s called",__PRETTY_FUNCTION__);
//}


- (void)dismissTouchOverlayView {
    NSLog(@"%s called",__PRETTY_FUNCTION__);
    [_touchView removeFromSuperview];
    _touchView = nil;
}


// Convert tapGesture point from overlayView to self view coordinates
// - pass converted tap point for shouldDismiss
- (void)handleTouchViewTap:(UITapGestureRecognizer *)tGR {
    
    if (NO == [tGR isEqual:_tapGR]) {
        return;
    }
    
    NSLog(@"%s called", __PRETTY_FUNCTION__);    
    
    CGPoint touchViewPoint = [_tapGR locationInView:_touchView];
    CGPoint testPoint = [self pointFromTouchPoint:touchViewPoint];
    
    switch(_tapGR.state){
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            break;
        case UIGestureRecognizerStateCancelled: 
        case UIGestureRecognizerStateEnded: {
            
            if (NO == [self pointInsideBaseMenu:testPoint]) {
                [self dismissMenu];
            }
        }    
            break;
        default:
            break;
    }
}

// Convert tapGesture point from overlayView to self view coordinates
// - pass converted tap point for shouldDismiss
- (void)handleTouchViewPan:(UIPanGestureRecognizer *)pGR {
    
    if (NO == [pGR isEqual:_panGR]) {
        return;
    }
    
    NSLog(@"%s called", __PRETTY_FUNCTION__);    
    
//    CGPoint touchViewPoint = [_panGR locationInView:_touchView];
////    CGPoint testPoint = [self pointFromTouchPoint:touchViewPoint];
//    if (NO == [self pointInsideScrollView:touchViewPoint])
//        return;
    
    switch(_tapGR.state){
        case UIGestureRecognizerStateBegan:
            
            break;
        case UIGestureRecognizerStateChanged:
            
            break;
        case UIGestureRecognizerStateCancelled: 
            
            break;
        case UIGestureRecognizerStateEnded: {

            break;
        }    
            break;
        default:
            break;
    }
}


#pragma mark - Pulse PresentingView

- (void)pulsePresentingView:(AnimationDirection)direction {
    
    BOOL expand = (direction == kExpand);
    if (_menuIsPresented && expand)
        return;
    
    // Animate scale layer
    CGSize startSize = _presentingView.frame.size;
    CGFloat factor = (expand) ? kPulseFactor : _contractedSide / startSize.width;
    CGSize endSize = SizeScaleByFactor(startSize, factor);
    [self addBoundsSpringAnimationToLayer:_presentingView.layer 
                                     size:endSize
                                     name: (expand) ? @"pulseViewExpand" : @"pulseViewContract"];
    // Animate cornerRadius
    CGFloat endSide = (expand) ?  kPulseFactor * _contractedSide : _contractedSide;
    CGFloat endRadius = _presentCornerRadiusRatio * endSide;
    [self addCornerRadiusSpringAnimationToView:_presentingView 
                                        radius:endRadius 
                                          name:(expand) ? @"pulseCornerRadiusExpand" : @"pulseCornerRadiusContract"];
}


// POPLayerBounds spring animation applied to given layer with given finish size, with animation name identifier
// Used by pulsePresentingView
- (void)addBoundsSpringAnimationToLayer:(CALayer *)aLayer size:(CGSize)aSize name:(NSString *)animName {
    // Only Square
    if (NO == RectIsSquare(aLayer.frame)) 
        return;
    
    POPSpringAnimation *anim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerBounds];
    anim.delegate = self;
    CGRect toRect = [self rectWithSize:aSize centeredWithRect:aLayer.frame];
    anim.toValue = [NSValue valueWithCGRect:toRect];
    anim.springBounciness = kDefaultSpringBounciness;
    anim.springSpeed = kDefaultSpringSpeed;
    anim.name = animName;
    [aLayer pop_addAnimation:anim forKey:animName];
}

// POPLayerCornerRadius spring animation applied to given view with given finish corner radius value, 
// with animation name identifier.
// Used by pulsePresentingView
- (void)addCornerRadiusSpringAnimationToView:(UIView *)aView radius:(CGFloat)aRadius name:(NSString *)animName {
    POPSpringAnimation *anim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerCornerRadius];
    anim.delegate = self;
    anim.toValue = @(aRadius);
    anim.springBounciness = kDefaultSpringBounciness;
    anim.springSpeed = kDefaultSpringSpeed;
    anim.name = animName;
    [aView.layer pop_addAnimation:anim forKey:animName];
}

// POPLayerBorderColor basic animation applies given bgColor to given view over given duration
// UNUSED
- (void)animateBasicBorderColor:(UIColor *)toColor view:(UIView *)aView duration:(NSTimeInterval)duration {    
    POPBasicAnimation *borderColorAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerBorderColor];
    borderColorAnim.duration = 0.3;
    borderColorAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    borderColorAnim.toValue = (__bridge id)toColor.CGColor;
    borderColorAnim.name = @"borderColorAnim";
    [aView.layer pop_addAnimation:borderColorAnim forKey:kPOPLayerBorderColor];
}


#pragma mark - Logging

- (void)logAllWithLabel:(NSString *)prefix {
//    CALayer *baseLayer = _baseMenuLayer;
//    NSLog(@"\n%@\nbaseLayer.frame:%@ baseLayer.center:%@ baseLayer.anchorPoint:%@", prefix,
//          NSStringFromCGRect(baseLayer.frame), 
//          NSStringFromCGPoint(baseLayer.center),
//          NSStringFromCGPoint(baseLayer.anchorPoint)
//    );
}


#pragma mark - Cleanup Utilities

- (void)cleanupAllLayersAndSubviews {

//    [self removeSubLayersFromLayer:self.layer];
    
//    NSMutableArray *subViews = [NSMutableArray arrayWithArray:self.subviews];
    [self.subviews enumerateObjectsUsingBlock:^(UIView *subView, NSUInteger idx, BOOL *stop) {
//        [self removeSubLayersFromLayer:subView.layer];
        [subView removeFromSuperview];
//        [subViews removeObject:subView];
//        subView = nil;
    }];
    
    [self removeSubLayersFromLayer:self.layer];
}

- (void)removeSubLayersFromLayer:(CALayer *)layer {
//    NSMutableArray *subLayers = [NSMutableArray arrayWithArray:layer.sublayers];
    [layer.sublayers enumerateObjectsUsingBlock:^(CALayer *sub, NSUInteger idx, BOOL *stop) {
        [sub removeFromSuperlayer];
//        [subLayers removeObject:sub];
//        sub = nil;
    }];
}

@end
