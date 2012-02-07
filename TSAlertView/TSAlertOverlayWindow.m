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
  
@interface TSAlertViewGradientView : UIView
@end

@interface TSAlertOverlayWindow ()
@end

@implementation TSAlertOverlayWindow
@synthesize oldKeyWindow=_oldKeyWindow, gradientView=_gradientView;

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
    // easy stuff...
    self.backgroundColor = [UIColor clearColor];
    //
    self.rootViewController = [[[TSAlertViewController alloc] init] autorelease];
    // backing gradient
    self.gradientView = [[[TSAlertViewGradientView alloc] 
                          initWithFrame:self.rootViewController.view.bounds] autorelease];
    // start hidden
    self.gradientView.alpha = 0;
    [self.rootViewController.view addSubview:self.gradientView];
    
    [self makeKeyAndVisible];
  }  
  return self;
}

- (void) makeKeyAndVisible {
  self.oldKeyWindow = [[UIApplication sharedApplication] keyWindow];
	self.windowLevel = UIWindowLevelAlert;
	[super makeKeyAndVisible];
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
  // pre iOS 4, only
  // since there is only one instance, best to reset the pointer here:
	[super dealloc];
}
#endif

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
