//
//  TSAlertViewOverlayWindow.m
//  Tetsuo
//
//  Created by Jon Crooke on 30/01/2012.
//  Copyright (c) 2012 mkodo. All rights reserved.
//

#import "TSAlertOverlayWindow.h"
#import "TSAlertViewGradientView.h"
#import "TSAlertViewController.h"
#import "TSAlertView+Protected.h"

static TSAlertOverlayWindow *__sharedWindow = nil;

static NSString *const kAlertAnimShow     = @"Show";
static NSString *const kAlertAnimDismiss1 = @"Dismiss1";
static NSString *const kAlertAnimDismiss2 = @"Dismiss2";

@interface TSAlertOverlayWindow ()
#if __has_feature(objc_arc)
@property (nonatomic, weak) NSMutableArray *stack;
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
@end

@implementation  TSAlertOverlayWindow
@synthesize oldKeyWindow=_oldKeyWindow, viewController=_viewController, gradient=_gradient, stack=_stack;

+ (TSAlertOverlayWindow*) sharedTSAlertOverlayWindow {
  if (!__sharedWindow) {
    __sharedWindow = [[TSAlertOverlayWindow alloc] init];
  }
  return __sharedWindow;
}

- (id) init {
  // always full screen...
  CGRect frame = [UIScreen mainScreen].bounds;
  if ((self = [super initWithFrame:frame])) {
    self.stack = [NSMutableArray array];
    
    self.viewController = [[[TSAlertViewController alloc] init] autorelease];
    self.viewController.view.backgroundColor = [UIColor clearColor];
    
    self.backgroundColor = [UIColor clearColor];
    
    self.gradient = [[[TSAlertViewGradientView alloc] initWithFrame:frame] autorelease];
    self.gradient.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.viewController.view addSubview:self.gradient];
    
    if ([self respondsToSelector:@selector(setRootViewController:)]) {
      self.rootViewController = self.viewController;
    } else {  
      [self addSubview:self.viewController.view];
    }
  }
  
  return self;
}

- (void) makeKeyAndVisible {
  self.oldKeyWindow = [[UIApplication sharedApplication] keyWindow];
	self.windowLevel = UIWindowLevelAlert;
	[super makeKeyAndVisible];
}

- (void) resignKeyWindow {
	[super resignKeyWindow];
	[self.oldKeyWindow makeKeyWindow];
  self.oldKeyWindow = nil;
}

- (id) initWithFrame:(CGRect)frame { return [self init]; }

#if __has_feature(objc_arc) == 0
- (void) dealloc {
	self.stack = nil;
  self.oldKeyWindow = nil;
	[super dealloc];
}
#endif

- (void) push:(TSAlertView*) alert animated:(BOOL)anim {
  // current top of the stack...
  TSAlertView *top = [self.stack top];
  // add the new alert...
  [self.stack addObject:alert];
  
  if (top && top != alert) {
    // hide first
    [self hideAlert:top buttonIndex:nil finalStep:NO animated:anim];
  } else {
    alert.alpha = 0;
    [self.viewController.view addSubview: alert];
    [alert sizeToFit];
    alert.center = CGPointMake( CGRectGetMidX( self.viewController.view.bounds ), 
                               CGRectGetMidY( self.viewController.view.bounds ) );
    alert.frame = CGRectIntegral( alert.frame );
    
    //
    self.gradient.alpha = 0;
    if (![self isKeyWindow]) {
      [self makeKeyAndVisible];
    }  
    
    // fade in the window  
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
      [UIView beginAnimations:kAlertAnimShow context:NULL];
      [UIView setAnimationDelegate:self];
      [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
      [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
      [UIView setAnimationDuration:kAlertBackgroundAnimDuration];
      self.gradient.alpha = 1;
      [UIView commitAnimations];
#endif	
    } else {
      [self animationDidStop:kAlertAnimShow 
                    finished:[NSNumber numberWithBool:YES] 
                     context:NULL];
    }
  }
}

- (void) hideAlert:(TSAlertView*) alert 
       buttonIndex:(NSNumber*) num 
         finalStep:(BOOL)final
          animated:(BOOL)animated
{
  if (final) {
    // final step - hide the alert itself
    [alert.inputTextField resignFirstResponder];
    
    if (animated) {
      [UIView beginAnimations:kAlertAnimDismiss2 context:alert];
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
    NSArray *context = [[NSArray alloc] initWithObjects:alert, num, nil];
    
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
      self.gradient.alpha = 0;
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
      [alert pulse];
    } else {
      [self push:alert animated:anim];
    }
  } else {
    // nothing on stack
    [self release];
    [self resignKeyWindow];
    __sharedWindow = nil;
  }
}

- (void)animationDidStop:(NSString *)animationID 
                finished:(NSNumber *)finished 
                 context:(void *)context
{
  if ([animationID isEqual:kAlertAnimDismiss1]) {
    NSArray *array = (ARC_BRIDGE NSArray*) context;
    TSAlertView *alertView = [array objectAtIndex:0];
    // has button index?
    NSNumber *index = nil;
    if ([array count] > 1) {
      index = [array objectAtIndex:1];
    }
    [self hideAlert:alertView buttonIndex:index finalStep:YES animated:YES];
  }
  
  else if ([animationID isEqual:kAlertAnimDismiss2]) {
    TSAlertView *alert = (TSAlertView*) context;
    [alert removeFromSuperview];
    [self checkStackAnimated:YES];    
  }  
  else if ([animationID isEqual:kAlertAnimShow]) { 
    [self checkStackAnimated:YES];
  }
}


@end
