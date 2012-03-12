//
//  TSAlertViewOverlayWindow.m
//  Tetsuo
//
//  Created by Jon Crooke on 30/01/2012.
//  Copyright (c) 2012 mkodo. All rights reserved.
//

#import "TSAlertOverlayWindow.h"
#import "TSAlertView+Protected.h"

static TSAlertOverlayWindow *__sharedWindow = nil;

static NSString *const kAlertAnimResize   = @"ResizeAlertView";
static NSString *const kAlertAnimShow     = @"Show";
static NSString *const kAlertAnimDismiss1 = @"Dismiss1";
static NSString *const kAlertAnimDismiss2 = @"Dismiss2";

@interface TSAlertViewGradientView : UIView
@end

@interface TSAlertOverlayWindow ()
#if __has_feature(objc_arc)
//@property (nonatomic, weak) NSMutableArray *stack;
#else
@property (nonatomic, retain) NSMutableArray *stack;
#endif
- (void) hideAlert:(TSAlertView*) alert 
       buttonIndex:(NSNumber*) num 
         finalStep:(BOOL)final
          animated:(BOOL)anim;
- (void) checkStackAnimated:(BOOL)anim;
- (void)statusBarDidChangeOrientation:(NSNotification *)notification;
@end

@implementation TSAlertOverlayWindow
@synthesize oldKeyWindow=_oldKeyWindow, gradientView=_gradientView, stack=_stack;

+ (TSAlertOverlayWindow*) sharedTSAlertOverlayWindow {
  NSAssert([NSThread isMainThread], @"Not main thread");
  if (!__sharedWindow) {
    __sharedWindow = [[TSAlertOverlayWindow alloc] init];
  }
  return __sharedWindow;
}

- (id) initWithFrame:(CGRect)frame { return [self init]; }

- (id) init {
  // always full screen...
  if ((self = [super initWithFrame:[UIScreen mainScreen].bounds])) {
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(statusBarDidChangeOrientation:) 
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification 
                                               object:nil];    
    
    // easy stuff...
    self.backgroundColor = [UIColor clearColor];
    self.stack = [NSMutableArray array];   
    
    // backing gradient
    self.gradientView = [[[TSAlertViewGradientView alloc] initWithFrame:self.bounds] autorelease];
    // start hidden
    self.gradientView.alpha = 0;
    [self addSubview:self.gradientView];
  }  
  return self;
}

- (void)statusBarDidChangeOrientation:(NSNotification *)notification {
  for (UIView *view in self.subviews) {
    if (view != self.gradientView) {
      NSAssert(self.oldKeyWindow.rootViewController.view, @"No view");
      view.transform = self.oldKeyWindow.rootViewController.view.transform;
    }
  }
}

- (void) makeKeyAndVisible {
  if (![self isKeyWindow]) {
    self.oldKeyWindow = [[UIApplication sharedApplication] keyWindow];
    NSAssert(self.oldKeyWindow, @"No old key window");
    self.windowLevel = UIWindowLevelAlert;
    [super makeKeyAndVisible];
  }
  // rotate subviews...
  [self statusBarDidChangeOrientation:nil];
}

- (void) resignKeyWindow {
  [self.oldKeyWindow makeKeyWindow];
  self.oldKeyWindow = nil;
  [self release];
  __sharedWindow = nil;
  [super resignKeyWindow];
}

- (void) dealloc {
  //  NSLog(@"window dealloc\n");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.oldKeyWindow = nil;
  self.stack = nil;
#if __has_feature(objc_arc) == 0
	[super dealloc];
#endif
}

#pragma mark -
#pragma mark

- (void) push:(TSAlertView*) alert animated:(BOOL)anim {
  // current top of the stack...
  TSAlertView *top = [self.stack top];
  // add the new alert...
  [self.stack addObject:alert];
  
  if (top && top != alert) {
    // hide first
    [self hideAlert:top buttonIndex:nil finalStep:NO animated:anim];
  } else {
    CGRect rect = [self convertRect:self.frame fromView:nil];
    alert.alpha = 0;
    [self addSubview: alert];
    [alert sizeToFit];
    alert.center = CGRectCentrePoint(rect);
    alert.frame = CGRectIntegral( alert.frame );
    
    [self makeKeyAndVisible];
    
    // fade in the window  
    [UIView animateWithDuration:anim ? kAlertBackgroundAnimDuration : 0
                          delay:0 
                        options:UIViewAnimationOptionCurveEaseIn 
                     animations:^
     {
       self.gradientView.alpha = 1;
       if (alert.window) {
         alert.center = alert.window.center;
       }
     } completion:^(BOOL finished) {
       [alert pulse];
       [self checkStackAnimated:YES];          
     }];
  }
}

- (void) hideAlert:(TSAlertView*) alert 
       buttonIndex:(NSNumber*) num 
         finalStep:(BOOL)final
          animated:(BOOL)animated
{
#ifdef __clang_analyzer__
  // silence false positive
  [context autorelease];
#endif
  
  if (final) {
    // final step - hide the alert itself
    [alert.inputTextField resignFirstResponder];
    
    [UIView animateWithDuration:animated ? kAlertBackgroundAnimDuration : 0
                          delay:0 
                        options:UIViewAnimationOptionCurveEaseIn 
                     animations:^
     {
       alert.alpha = 0;
       
     } completion:^(BOOL finished) {
       // delegate call
       if ([alert.delegate respondsToSelector:@selector(alertView:didDismissWithButtonIndex:)]) {
         [alert.delegate alertView:alert didDismissWithButtonIndex:[num unsignedIntegerValue]];
       }
       [alert removeFromSuperview];
       [self checkStackAnimated:YES];    
     }];    
    
  } else {
    // first step - fade out the window    
    [UIView animateWithDuration:animated ? kAlertBoxAnimDuration : 0
                          delay:0 
                        options:UIViewAnimationOptionCurveEaseInOut 
                     animations:^
     {
       [TSAlertOverlayWindow sharedTSAlertOverlayWindow].gradientView.alpha = 0;
     } completion:^(BOOL finished) {
       [self hideAlert:alert buttonIndex:num finalStep:YES animated:YES];
     }];
  }
}

- (void) pop:(TSAlertView*) alert 
 buttonIndex:(NSUInteger) index 
    animated:(BOOL) animated
{
  id top = [[self.stack top] retain];
  [self.stack removeObject:alert];
  // don't need to show anything unless this is the top...
  if (top == alert) {
    [self hideAlert:alert 
        buttonIndex:[NSNumber numberWithUnsignedInteger:index] 
          finalStep:NO 
           animated:animated];    
  }
  [top release];
}

- (void) checkStackAnimated:(BOOL)anim {
  // check the stack
  if ([self.stack count]) {
    TSAlertView *alert = [self.stack lastObject];
    // may need to be added, or pulsed
    if (alert.superview) {
    } else {
      [self push:alert animated:anim];
    }
  } else {
    // nothing on stack - get rid of the window
    TSAlertOverlayWindow *window = [TSAlertOverlayWindow sharedTSAlertOverlayWindow];
    [window.oldKeyWindow makeKeyWindow];
  }
}

@end


#pragma mark -

@implementation TSAlertViewGradientView

- (id) initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.contentMode = UIViewContentModeScaleToFill;
  }
  return self;
}

- (void) drawRect: (CGRect) rect
{
#define kLocations (2)
  CGFloat locations[kLocations]	= { 0.0, 1.0 	};
	CGFloat components[] = {	
    0, 0, 0, 0.0,
		0, 0, 0, 0.7	
  };
  
	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
	CGGradientRef backgroundGradient = CGGradientCreateWithColorComponents(colorspace, 
                                                                         components, 
                                                                         locations, 
                                                                         kLocations);
	CGColorSpaceRelease(colorspace);
  
  CGFloat width  = self.frame.size.width;
	CGFloat height = self.frame.size.height;
	CGContextDrawRadialGradient(UIGraphicsGetCurrentContext(), 
                              backgroundGradient, 
                              CGPointMake(width/2, height/2), 
                              0,
                              CGPointMake(width/2, height/2), 
                              hypotf(width/2, height/2),
                              0);
  
	CGGradientRelease(backgroundGradient);
}

@end
