//
//  TSAlertView+Protected.h
//  Tetsuo
//
//  Created by Jon Crooke on 23/01/2012.
//  Copyright (c) 2012 mkodo. All rights reserved.
//

@interface TSAlertView ()
@property (nonatomic, readonly) NSMutableArray *buttons;
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UILabel *messageLabel;
@property (nonatomic, readonly) UITextView *messageTextView;

- (void) TSAlertView_commonInit;
- (void) releaseWindow: (int) buttonIndex;
- (CGSize) titleLabelSize;
- (CGSize) messageLabelSize;
- (CGSize) inputTextFieldSize;
- (CGSize) buttonsAreaSize_Stacked;
- (CGSize) buttonsAreaSize_SideBySide;
- (CGSize) recalcSizeAndLayout: (BOOL) layout;
- (UIImageView*) messageTextViewMaskView;
//
- (void) onKeyboardDidShow: (NSNotification*) note;
- (void) onKeyboardWillHide: (NSNotification*) note;
- (void) onButtonPress: (id) sender;
- (void) pulse;

//- (void) animationWaitLoopForSelectorNamed:(NSString*)selName;

#if NS_BLOCKS_AVAILABLE == 0
- (void)animationDidStop:(NSString *)animationID 
                finished:(NSNumber *)finished 
                 context:(void *)context;
#endif
//+ (void)animationDidStop:(NSString *)animationID 
//                finished:(NSNumber *)finished 
//                 context:(void *)context;

@end
