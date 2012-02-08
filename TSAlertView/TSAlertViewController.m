//
//  TSAlertViewController.m
//  Tetsuo
//
//  Created by Jon Crooke on 30/01/2012.
//  Copyright (c) 2012 mkodo. All rights reserved.
//

#import "TSAlertViewController.h"
#import "TSAlertOverlayWindow.h"
#import "TSAlertView+Protected.h"
#import "SynthesizeSingleton.h"

#import "UIApplication+MKDAdditions.h"

static NSString *const kAlertAnimResize   = @"ResizeAlertView";
static NSString *const kAlertAnimShow     = @"Show";
static NSString *const kAlertAnimDismiss1 = @"Dismiss1";
static NSString *const kAlertAnimDismiss2 = @"Dismiss2";

@interface TSAlertViewController ()
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
//- (void)doRotationAnimsOnAlertView:(TSAlertView*)av;
@end

@implementation TSAlertViewController
@synthesize stack=_stack;

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  if ((self = [super initWithNibName:nil bundle:nil])) {
    self.stack = [NSMutableArray array];   
    self.view.backgroundColor = [UIColor clearColor];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.autoresizesSubviews = YES;
  }
  return self;
}

- (id) init { return [self initWithNibName:nil bundle:nil]; }

- (void)dealloc {
  NSLog(@"View controller dealloc");
  self.stack = nil;
  [super dealloc];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
  // need to check with the original window... can only do this on ios 4+
  UIWindow *window = [(TSAlertOverlayWindow*) self.view.window oldKeyWindow];
  if (window) {
    return [window.rootViewController shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
  }
  // rely on app supported orientations...
  return [[UIApplication sharedApplication] supportsOrientation:toInterfaceOrientation];
}

#pragma mark -

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
    //
    TSAlertOverlayWindow *window = [TSAlertOverlayWindow sharedTSAlertOverlayWindow];
    [window.rootViewController.view addSubview: alert];
    [alert sizeToFit];
    alert.center = CGPointMake( CGRectGetMidX( window.bounds ), CGRectGetMidY( window.bounds ) );
    alert.frame = CGRectIntegral( alert.frame );
        
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
  }
  
  // always need to release the context array here:
  [animContext release];
}

@end
