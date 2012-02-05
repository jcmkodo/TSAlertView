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

static NSString *const kAlertAnimResize   = @"ResizeAlertView";
static NSString *const kAlertAnimShow     = @"Show";
static NSString *const kAlertAnimDismiss1 = @"Dismiss1";
static NSString *const kAlertAnimDismiss2 = @"Dismiss2";

@interface TSAlertViewGradientView : UIView
@end

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
- (void)doRotationAnimsOnAlertView:(TSAlertView*)av;
@end

@implementation TSAlertViewController
@synthesize stack=_stack;

SYNTHESIZE_SINGLETON_FOR_CLASS(TSAlertViewController)

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  if ((self = [super initWithNibName:nil bundle:nil])) {
    self.view.backgroundColor = [UIColor clearColor];
    self.stack = [NSMutableArray array];    
    
    UIView *gradient = [[[TSAlertViewGradientView alloc] initWithFrame:self.view.bounds] autorelease];
    [self.view addSubview:gradient];
    
    // add to the window
    [[TSAlertOverlayWindow sharedTSAlertOverlayWindow] addSubview:self.view];
  }
  return self;
}

- (id) init { return [self initWithNibName:nil bundle:nil]; }

- (void)dealloc {
  self.stack = nil;
  [super dealloc];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
	TSAlertView* av = [self.view.subviews lastObject];
	if (!av || ![av isKindOfClass:[TSAlertView class]])
		return;
	// resize the alertview if it wants to make use of any extra space (or needs to contract)
#if NS_BLOCKS_AVAILABLE
	[UIView animateWithDuration:duration 
                   animations:^{ [self doRotationAnimsOnAlertView:av]; }];
#else
  [UIView beginAnimations:kAlertAnimResize context:NULL];
  [UIView setAnimationDelegate:self];
  [UIView setAnimationDuration:duration];
  [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
  //  [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
  [self doRotationAnimsOnAlertView:av];
  [UIView commitAnimations];
#endif
}

- (void)doRotationAnimsOnAlertView:(TSAlertView*)av { 
  [av sizeToFit];
  CGRect bounds = av.superview.bounds;
  av.center = CGPointMake( CGRectGetMidX( bounds ), CGRectGetMidY( bounds ) );
  av.frame = CGRectIntegral( av.frame ); 
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
    UIView *view = [TSAlertViewController sharedTSAlertViewController].view;
    [view addSubview: alert];
    [alert sizeToFit];
    alert.center = CGPointMake( CGRectGetMidX( [TSAlertViewController sharedTSAlertViewController].view.bounds ), 
                               CGRectGetMidY( [TSAlertViewController sharedTSAlertViewController].view.bounds ) );
    alert.frame = CGRectIntegral( alert.frame );
    
    //
    TSAlertOverlayWindow *window = (TSAlertOverlayWindow*) view.window;
    NSAssert(window, @"No window");
    
    window.gradientView.alpha = 0;
    if (![window isKeyWindow]) {
      [window makeKeyAndVisible];
    }  
    
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
  TSAlertOverlayWindow *window = (TSAlertOverlayWindow*) alert.window;
  NSAssert(window, @"No window");
  
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
      window.gradientView.alpha = 0;
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
    TSAlertOverlayWindow *window = (TSAlertOverlayWindow*) self.view.window;
    NSAssert(window, @"No window");
    [window.oldKeyWindow makeKeyWindow];
    [window release];
    //    [__sharedWindow release];
    //    __sharedWindow = nil;
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

#pragma mark -

@implementation TSAlertViewGradientView

- (id) initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
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