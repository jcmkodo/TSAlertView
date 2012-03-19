//
//  TSAlertView+Protected.h
//  Tetsuo
//
//  Created by Jon Crooke on 23/01/2012.
//  Copyright (c) 2012 mkodo. All rights reserved.
//

@interface TSAlertViewBase ()
- (void) pulse;
- (CGSize) recalcSizeAndLayout: (BOOL) layout;
@end

@interface TSAlertView ()
@property (nonatomic, readonly) NSMutableArray *buttons;
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UILabel *messageLabel;
@property (nonatomic, readonly) UITextView *messageTextView;

- (void) releaseWindow: (int) buttonIndex;
- (CGSize) titleLabelSize;
- (CGSize) messageLabelSize;
- (CGSize) inputTextFieldSize;
- (CGSize) buttonsAreaSize_Stacked;
- (CGSize) buttonsAreaSize_SideBySide;
- (UIImageView*) messageTextViewMaskView;
//
- (void) onKeyboardDidShow: (NSNotification*) note;
- (void) onKeyboardWillHide: (NSNotification*) note;
- (void) onButtonPress: (id) sender;

@end
