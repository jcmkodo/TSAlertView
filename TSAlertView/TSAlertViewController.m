//
//  TSAlertViewController.m
//  Tetsuo
//
//  Created by Jon Crooke on 30/01/2012.
//  Copyright (c) 2012 mkodo. All rights reserved.
//

#import "TSAlertViewController.h"

static NSString *const kAlertAnimResize = @"ResizeAlertView";

@interface TSAlertViewController ()
- (void)doRotationAnimsOnAlertView:(TSAlertView*)av;
@end

@implementation TSAlertViewController
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

@end
