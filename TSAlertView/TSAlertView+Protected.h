//
//  TSAlertView+Protected.h
//  Tetsuo
//
//  Created by Jon Crooke on 23/01/2012.
//  Copyright (c) 2012 mkodo. All rights reserved.
//

//#ifndef NS_BLOCKS_AVAILABLE
//#error Requires Blocks!
//#endif

#if __has_feature(objc_arc)
#define ARC_BRIDGE ARC_BRIDGE
#else
#define ARC_BRIDGE
#endif

#if __has_feature(objc_arc)
#error ARC not yet supported
#endif

#ifdef NS_BLOCKS_AVAILABLE
#undef NS_BLOCKS_AVAILABLE

#endif

@interface TSAlertView ()
@property (nonatomic, readonly) NSMutableArray* buttons;
@property (nonatomic, readonly) UILabel* titleLabel;
@property (nonatomic, readonly) UILabel* messageLabel;
@property (nonatomic, readonly) UITextView* messageTextView;
- (void) TSAlertView_commonInit;
- (void) releaseWindow: (int) buttonIndex;
- (void) pulse;
- (CGSize) titleLabelSize;
- (CGSize) messageLabelSize;
- (CGSize) inputTextFieldSize;
- (CGSize) buttonsAreaSize_Stacked;
- (CGSize) buttonsAreaSize_SideBySide;
- (CGSize) recalcSizeAndLayout: (BOOL) layout;
//
- (void) onKeyboardWillShow: (NSNotification*) note;
- (void) onKeyboardWillHide: (NSNotification*) note;
- (void) onButtonPress: (id) sender;
#ifndef NS_BLOCKS_AVAILABLE
- (void)animationDidStop:(NSString *)animationID 
                finished:(NSNumber *)finished 
                 context:(void *)context;
+ (void)animationDidStop:(NSString *)animationID 
                finished:(NSNumber *)finished 
                 context:(void *)context;
#endif
// Stack
+ (void) show:(TSAlertView*)alertView;
+ (void) hide:(TSAlertView*)alertView 
  buttonIndex:(NSUInteger)index 
     animated:(BOOL)animated;
+ (void) push:(TSAlertView*)alertView;
+ (void) pop:(TSAlertView*)alertView 
 buttonIndex:(NSUInteger)index 
    animated:(BOOL)animated;
// More authentic animation...
+ (void) showAlert:(TSAlertView*)alert;
//
+ (void) showDidComplete:(TSAlertView*)alert;
+ (void) dismissDidComplete:(TSAlertView*)alert;
//
- (void) animationWaitLoopForSelectorNamed:(NSString*)selName;
@end
