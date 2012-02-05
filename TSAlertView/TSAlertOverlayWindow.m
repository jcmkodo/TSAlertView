//
//  TSAlertViewOverlayWindow.m
//  Tetsuo
//
//  Created by Jon Crooke on 30/01/2012.
//  Copyright (c) 2012 mkodo. All rights reserved.
//

#import "TSAlertOverlayWindow.h"
#import "TSAlertViewController.h"
#import "TSAlertView+Protected.h"

static TSAlertOverlayWindow *__sharedWindow = nil;
  
@interface TSAlertOverlayWindow ()
@end

@implementation  TSAlertOverlayWindow
@synthesize oldKeyWindow=_oldKeyWindow, gradientView=_gradientView;

+ (TSAlertOverlayWindow*) sharedTSAlertOverlayWindow {
  NSAssert([NSThread isMainThread], @"Not main thread");
  if (!__sharedWindow) {
    __sharedWindow = [[TSAlertOverlayWindow alloc] init];
  }
  return __sharedWindow;
}

- (id) init {
  // always full screen...
  CGRect frame = [UIScreen mainScreen].bounds;
  if ((self = [super initWithFrame:frame])) {
    // easy stuff...
    self.backgroundColor = [UIColor clearColor];
  }  
  return self;
}

- (void) layoutSubviews {
  [super layoutSubviews];
  self.gradientView.frame = [TSAlertViewController sharedTSAlertViewController].view.bounds;
}

- (void) makeKeyAndVisible {
  self.oldKeyWindow = [[UIApplication sharedApplication] keyWindow];
	self.windowLevel = UIWindowLevelAlert;
	[super makeKeyAndVisible];
}

- (id) initWithFrame:(CGRect)frame { return [self init]; }

#if __has_feature(objc_arc) == 0
- (void) dealloc {
  NSLog(@"Window dealloc");
  // since there is only one instance, best to reset the pointer here:
  __sharedWindow = nil;
  self.oldKeyWindow = nil;
  // clear the view controller
  [[[[TSAlertViewController sharedTSAlertViewController] view] subviews] 
   makeObjectsPerformSelector:@selector(removeFromSuperview)];
  //
	[super dealloc];
}
#endif



- (id) retain {
  id ret = [super retain];
  NSLog(@"Retain %d", [self retainCount]);
  return ret;
}

- (oneway void) release {
  [super release];
  NSLog(@"release %d", [self retainCount]);
  return;
}

@end


