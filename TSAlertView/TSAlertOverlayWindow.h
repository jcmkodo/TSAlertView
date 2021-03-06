//
//  TSAlertViewOverlayWindow.h
//  Tetsuo
//
//  Created by Jon Crooke on 30/01/2012.
//  Copyright (c) 2012 mkodo. All rights reserved.
//

#import <UIKit/UIKit.h>

#define ALERT_CONTROLLER (TSAlertOverlayWindow*) [TSAlertOverlayWindow sharedTSAlertOverlayWindow]

@class TSAlertViewController, TSAlertViewGradientView;

@interface TSAlertOverlayWindow : UIWindow
@property (nonatomic, STRONG_OR_RETAIN) UIWindow* oldKeyWindow;
@property (nonatomic, STRONG_OR_RETAIN) UIView *gradientView;

+ (TSAlertOverlayWindow*) sharedTSAlertOverlayWindow;

- (void) push:(TSAlertViewBase*) alert 
     animated:(BOOL)anim;
- (void) pop:(TSAlertViewBase*) alert 
 buttonIndex:(NSUInteger) index 
    animated:(BOOL) anim;

@end
