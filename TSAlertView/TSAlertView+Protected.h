//
//  TSAlertView+Protected.h
//  Tetsuo
//
//  Created by Jon Crooke on 20/01/2012.
//  Copyright (c) 2012 mkodo. All rights reserved.
//

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
@end
