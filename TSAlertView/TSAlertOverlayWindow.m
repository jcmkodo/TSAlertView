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
#if NS_BLOCKS_AVAILABLE == 0
- (void)animationDidStop:(NSString *)animationID 
                finished:(NSNumber *)finished 
                 context:(void *)context;
#endif
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
    
    self.stack = [NSMutableArray array];   

    // easy stuff...
    self.backgroundColor = [UIColor clearColor];
    
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
}

- (void) resignKeyWindow {
  [self.oldKeyWindow makeKeyWindow];
  self.oldKeyWindow = nil;
  [self release];
  __sharedWindow = nil;
  [super resignKeyWindow];
}

#if __has_feature(objc_arc) == 0
- (void) dealloc {
  NSLog(@"window dealloc\n");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.oldKeyWindow = nil;
  // pre iOS 4, only
  // since there is only one instance, best to reset the pointer here:
	[super dealloc];
}
#endif

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
    //
    TSAlertOverlayWindow *window = self;
    CGRect rect = [self convertRect:window.frame fromView:nil];
    rect = rect;
    
    alert.autoresizingMask = UIViewAutoresizingNone;
    window.autoresizingMask = UIViewAutoresizingNone;
    
    alert.alpha = 0;
    [window addSubview: alert];
    [alert sizeToFit];
    alert.center = CGRectCentrePoint(rect);
    alert.frame = CGRectIntegral( alert.frame );
    
    [window makeKeyAndVisible];
    
    // fade in the window  
    NSArray *context = [[NSArray alloc] initWithObjects:alert, nil];    
    if (anim) {
#if NS_BLOCKS_AVAILABLE
      [UIView animateWithDuration:kAlertBackgroundAnimDuration 
                            delay:0 
                          options:UIViewAnimationOptionCurveEaseIn 
                       animations:^{
                         ow.alpha = 1;
                       } completion:^(BOOL finished) {
                         [self showAlert:alertView];
                       }];
#else
      [UIView beginAnimations:kAlertAnimShow context:context];
      [UIView setAnimationDelegate:self];
      [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
      [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
      [UIView setAnimationDuration:kAlertBackgroundAnimDuration];
      window.gradientView.alpha = 1;
      [UIView commitAnimations];
#endif	
    } else {
      [self animationDidStop:kAlertAnimShow 
                    finished:[NSNumber numberWithBool:YES] 
                     context:context];
    }
  }
}

- (void) hideAlert:(TSAlertView*) alert 
       buttonIndex:(NSNumber*) num 
         finalStep:(BOOL)final
          animated:(BOOL)animated
{
  NSArray *context = [[NSArray alloc] initWithObjects:alert, num, nil];
#ifdef __clang_analyzer__
  // silence false positive
  [context autorelease];
#endif
  
  if (final) {
    // final step - hide the alert itself
    [alert.inputTextField resignFirstResponder];
    
    if (animated) {
      [UIView beginAnimations:kAlertAnimDismiss2 context:(ARC_BRIDGE void*) context];
      [UIView setAnimationDelegate:self];
      [UIView setAnimationDuration:kAlertBackgroundAnimDuration];
      [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
      [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
      alert.alpha = 0;
      [UIView commitAnimations];
    } else {
      [self animationDidStop:kAlertAnimDismiss2 
                    finished:[NSNumber numberWithBool:YES] 
                     context:alert];
    }
    
  } else {
    // first step - fade out the window    
    if ( animated ) {
#if NS_BLOCKS_AVAILABLE
      [UIView animateWithDuration:kAlertBoxAnimDuration 
                            delay:0 
                          options:UIViewAnimationOptionCurveEaseInOut 
                       animations:^{
                         alertView.alpha = 0;
                       } completion:^(BOOL finished) {
                         if ( alertView.style == TSAlertViewStyleInput && [alertView.inputTextField isFirstResponder] ) {
                           [alertView.inputTextField resignFirstResponder];
                         }
                         
                         [UIView animateWithDuration:kAlertBackgroundAnimDuration 
                                               delay:0 
                                             options:UIViewAnimationOptionCurveEaseOut 
                                          animations:^{
                                            [alertView.window resignKeyWindow];
                                            alertView.window.alpha = 0;
                                          } completion:^(BOOL finished) {
                                            [alertView releaseWindow: buttonIndex];
                                            // some other to show?
                                            if ([__TSAlertViewStack count]) {
                                              [self show:[__TSAlertViewStack lastObject]];
                                            }
                                            [self hideDidComplete:alertView];
                                          }];
                       }];
#else
      [UIView beginAnimations:kAlertAnimDismiss1 context:(ARC_BRIDGE void*) context];
      [UIView setAnimationDuration:kAlertBoxAnimDuration];
      [UIView setAnimationDelegate:self];
      [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
      [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];    
      [TSAlertOverlayWindow sharedTSAlertOverlayWindow].gradientView.alpha = 0;
      [UIView commitAnimations];
#endif		
    }
    else {
      [self animationDidStop:kAlertAnimDismiss1 
                    finished:[NSNumber numberWithBool:YES] 
                     context:context];
    } 
  }
}

- (void) pop:(TSAlertView*) alert 
 buttonIndex:(NSUInteger) index 
    animated:(BOOL) animated
{
  if ([self.stack containsObject:alert]) {
    [self.stack removeObject:alert];
    [self hideAlert:alert 
        buttonIndex:[NSNumber numberWithUnsignedInteger:index] 
          finalStep:NO 
           animated:animated];
  }
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
    //    NSAssert(window, @"No window");
    //    [window release];
  }
}

- (void)animationDidStop:(NSString *)animationID 
                finished:(NSNumber *)finished 
                 context:(void *)context
{
  NSArray *animContext = (context != NULL) ? (ARC_BRIDGE NSArray*) context : nil;
  TSAlertView *alertView = [animContext objectAtIndex:0];
  NSNumber *index = ([animContext count] > 1) ? [animContext objectAtIndex:1] : nil;
  
  if ([animationID isEqual:kAlertAnimDismiss1]) {
    [self hideAlert:alertView buttonIndex:index finalStep:YES animated:YES];
  }
  
  else if ([animationID isEqual:kAlertAnimDismiss2]) {
    // delegate call
    if ([alertView.delegate respondsToSelector:@selector(alertView:didDismissWithButtonIndex:)]) {
      [alertView.delegate alertView:alertView didDismissWithButtonIndex:[index unsignedIntegerValue]];
    }
    [alertView removeFromSuperview];
    [self checkStackAnimated:YES];    
  }  
  else if ([animationID isEqual:kAlertAnimShow]) { 
    [alertView pulse];
    [self checkStackAnimated:YES];
    
    alertView.center = alertView.window.center;
  }
  
  // always need to release the context array here:
  [animContext release];
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
	// render the radial gradient behind the alertview
  /*
   #define kLocations (3)
   CGFloat locations[kLocations]	= { 0.0, 0.5, 1.0 };
   CGFloat components[12]	= {	
   1, 1, 1, 0.5,
   0, 0, 0, 0.5,
   0, 0, 0, 0.7	
   };*/
  
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
