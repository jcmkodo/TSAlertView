//
//  TSAlertView.h
//
//  Created by Nick Hodapp aka Tom Swift on 1/19/11.
//

#import <UIKit/UIKit.h>

#ifndef __has_feature      // Optional.
#define __has_feature(x) 0 // Compatibility with non-clang compilers.
#endif

#if __has_feature(objc_arc)
#define STRONG_OR_RETAIN strong
#define WEAK_OR_ASSIGN unsafe_unretained
#else
#define STRONG_OR_RETAIN retain
#define WEAK_OR_ASSIGN assign
#endif

typedef enum 
{
	TSAlertViewButtonLayoutNormal,
	TSAlertViewButtonLayoutStacked
	
} TSAlertViewButtonLayout;

typedef enum
{
	TSAlertViewStyleNormal,
	TSAlertViewStyleInput,
	TSAlertViewStyleActivityView,
	
} TSAlertViewStyle;

extern const NSTimeInterval kAlertBoxAnimDuration;
extern const NSTimeInterval kAlertBackgroundAnimDuration;

extern CGFloat kTSAlertView_LeftMargin;
extern CGFloat kTSAlertView_TopMargin;
extern CGFloat kTSAlertView_BottomMargin;
extern CGFloat kTSAlertView_RowMargin;
extern CGFloat kTSAlertView_ColumnMargin;

@class TSAlertViewController, TSAlertView, TSAlertViewAppearanceProxy;

@protocol TSAlertViewDelegate <NSObject>
@optional

// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)alertView:(TSAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;

// Called when we cancel a view (eg. the user clicks the Home button). This is not called when the user clicks the cancel button.
// If not defined in the delegate, we simulate a click in the cancel button
- (void)alertViewCancel:(TSAlertView *)alertView;

- (void)willPresentAlertView:(TSAlertView *)alertView;  // before animation and showing view
- (void)didPresentAlertView:(TSAlertView *)alertView;  // after animation

- (void)alertView:(TSAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex; // before animation and hiding view
- (void)alertView:(TSAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex;  // after animation

@end

/**
 @class Base class for any alert view widgets.
 Has just a background and show/hide anims
 */
@interface TSAlertViewBase : UIView { 
  UIImage *_backgroundImage;
}
@property (nonatomic, STRONG_OR_RETAIN) UIImage* backgroundImage;
@property (nonatomic, readonly, getter=isVisible) BOOL visible;

+ (void) setAppearanceProxy:(TSAlertViewAppearanceProxy*) proxy;
+ (TSAlertViewAppearanceProxy*) appearanceProxy;
+ (id)   show;

- (void) TSAlertView_commonInit;
- (void) show;      /** Animated */
- (void) dismissAnimated:(BOOL) animated;
- (void) dismiss;   /** Animated */

- (void) didCompleteDisplayAnimations;

@end // TSAlertViewBase

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

@interface TSAlertView : TSAlertViewBase
{
	UILabel*				_titleLabel;
	UILabel*				_messageLabel;
	UITextView*				_messageTextView;
	UIImageView*			_messageTextViewMaskImageView;
	UITextField*			_inputTextField;
	NSMutableArray*			_buttons;
}
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *message;
@property (nonatomic) NSInteger cancelButtonIndex;
@property (nonatomic, readonly) NSInteger firstOtherButtonIndex;
@property (nonatomic, readonly) NSInteger numberOfButtons;

@property (nonatomic, assign) TSAlertViewButtonLayout buttonLayout;
@property (nonatomic, assign) BOOL usesMessageTextView;

@property (nonatomic, assign) TSAlertViewStyle style;

@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat maxHeight;

@property (nonatomic, readonly) UIImageView *imageView;
@property (nonatomic, readonly) NSMutableArray *buttons;
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UILabel *messageLabel;
@property (nonatomic, readonly) UITextView *messageTextView;

@property (nonatomic, WEAK_OR_ASSIGN) id <TSAlertViewDelegate> delegate;
@property (nonatomic, STRONG_OR_RETAIN, readonly) UITextField* inputTextField;
@property (nonatomic, STRONG_OR_RETAIN, readonly) UIActivityIndicatorView* activityIndicatorView;
@property (nonatomic, STRONG_OR_RETAIN) id userInfo;

- (id)initWithTitle:(NSString *)title 
            message:(NSString *)message 
           delegate:(id)delegate 
  cancelButtonTitle:(NSString *)cancelButtonTitle 
  otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

- (NSInteger) addButtonWithTitle:(NSString *)title;
- (NSString *) buttonTitleAtIndex:(NSInteger)buttonIndex;
- (void) dismissWithClickedButtonIndex:(NSInteger)buttonIndex 
                              animated:(BOOL)animated;

@end

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

@interface TSAlertViewAppearanceProxy : NSObject
- (void) alertViewWillShow:(TSAlertViewBase*)alertView;
- (void) alertView:(TSAlertViewBase*)alertView 
     addedToWindow:(UIWindow*)window;
@end


