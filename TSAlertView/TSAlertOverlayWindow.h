//
//  TSAlertViewOverlayWindow.h
//  Tetsuo
//
//  Created by Jon Crooke on 30/01/2012.
//  Copyright (c) 2012 mkodo. All rights reserved.
//

#import <UIKit/UIKit.h>

#define ALERT_CONTROLLER (TSAlertViewController*) [[TSAlertOverlayWindow sharedTSAlertOverlayWindow] rootViewController]

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
/** Pre iOS4 compatibility... */
- (UIViewController*) rootViewController;

@end
