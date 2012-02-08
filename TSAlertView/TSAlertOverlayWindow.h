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
#if __has_feature(objc_arc)
@property (nonatomic, strong) UIWindow* oldKeyWindow;
@property (nonatomic, weak) UIView *gradientView;
#else
@property (nonatomic, retain) UIWindow* oldKeyWindow;
@property (nonatomic, assign) UIView *gradientView;
#endif

+ (TSAlertOverlayWindow*) sharedTSAlertOverlayWindow;

- (void) push:(TSAlertView*) alert 
     animated:(BOOL)anim;
- (void) pop:(TSAlertView*) alert 
 buttonIndex:(NSUInteger) index 
    animated:(BOOL) anim;

@end
