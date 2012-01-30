//
//  TSAlertView.m
//
//  Created by Nick Hodapp aka Tom Swift on 1/19/11.
//

#import "TSAlertView.h"
#import "TSAlertView+Protected.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/objc-sync.h>
#import <Availability.h>

static NSMutableArray *__TSAlertViewStack = nil;
static BOOL __TSAlertAnimFlag = NO;

static NSString *const kAlertAnimResize   = @"ResizeAlertView";
static NSString *const kAlertAnimPulse1   = @"PulsePart1";
static NSString *const kAlertAnimPulse2   = @"PulsePart2";
static NSString *const kAlertAnimShow     = @"Show";
static NSString *const kAlertAnimDismiss1 = @"Dismiss1";
static NSString *const kAlertAnimDismiss2 = @"Dismiss2";

static const NSTimeInterval kAlertBoxAnimDuration = 0.1;
static const NSTimeInterval kAlertBackgroundAnimDuration = 0.2;

@interface TSAlertOverlayWindow : UIWindow
#if __has_feature(objc_arc)
@property (nonatomic,strong) UIWindow* oldKeyWindow;
#else
@property (nonatomic,retain) UIWindow* oldKeyWindow;
#endif
@end

#pragma mark -

@interface TSAlertViewGradientView : UIView
@end
@implementation TSAlertViewGradientView

- (id) initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
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


#pragma mark -

@implementation  TSAlertOverlayWindow
@synthesize oldKeyWindow;

- (id) initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
  }
  return self;
}

- (void) makeKeyAndVisible
{
  //  NSAssert([[UIApplication sharedApplication] keyWindow], @"No key window");
	self.oldKeyWindow = [[UIApplication sharedApplication] keyWindow];
	self.windowLevel = UIWindowLevelAlert;
	[super makeKeyAndVisible];
}

- (void) resignKeyWindow
{
	[super resignKeyWindow];
	[self.oldKeyWindow makeKeyWindow];
}

#if __has_feature(objc_arc) == 0
- (void) dealloc
{
	self.oldKeyWindow = nil;
	
  //	NSLog( @"TSAlertView: TSAlertOverlayWindow dealloc" );
	
	[super dealloc];
}
#endif

@end

@interface TSAlertViewController : UIViewController
{
}
- (void)doRotationAnimsOnAlertView:(TSAlertView*)av;
@end

@implementation TSAlertViewController
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
	TSAlertView* av = [self.view.subviews lastObject];
	if (!av || ![av isKindOfClass:[TSAlertView class]])
		return;
	// resize the alertview if it wants to make use of any extra space (or needs to contract)
#ifdef NS_BLOCKS_AVAILABLE
	[UIView animateWithDuration:duration 
                   animations:^{ [self doRotationAnimsOnAlertView:av]; }];
#else
  [UIView beginAnimations:kAlertAnimResize context:NULL];
  [UIView setAnimationDelegate:self];
  [UIView setAnimationDuration:duration];
  [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
  [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
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

#if __has_feature(objc_arc) == 0
- (void) dealloc
{
  //	NSLog( @"TSAlertView: TSAlertViewController dealloc" );
	[super dealloc];
}
#endif

@end


@implementation TSAlertView

@synthesize delegate;
@synthesize cancelButtonIndex;
@synthesize firstOtherButtonIndex;
@synthesize buttonLayout;
@synthesize width;
@synthesize maxHeight;
@synthesize usesMessageTextView;
@synthesize backgroundImage = _backgroundImage;
@synthesize style;
@synthesize activityIndicatorView=_activityIndicatorView;
@synthesize userInfo=_userInfo;

const CGFloat kTSAlertView_LeftMargin	= 10.0;
const CGFloat kTSAlertView_TopMargin	= 16.0;
const CGFloat kTSAlertView_BottomMargin = 15.0;
const CGFloat kTSAlertView_RowMargin	= 7.0;
const CGFloat kTSAlertView_ColumnMargin = 10.0;

+ (void) initialize {
  if (self == [TSAlertView class]) {
    __TSAlertViewStack = [[NSMutableArray alloc] init];
  }
}

- (id) init 
{
	if ( ( self = [super init] ) )
	{
		[self TSAlertView_commonInit];
	}
	return self;
}

- (id) initWithFrame:(CGRect)frame
{
	if ( ( self = [super initWithFrame: frame] ) )
	{
		[self TSAlertView_commonInit];
		
		if ( !CGRectIsEmpty( frame ) )
		{
			width = frame.size.width;
			maxHeight = frame.size.height;
		}
	}
	return self;
}

- (id) initWithTitle: (NSString *) t message: (NSString *) m delegate: (id) d cancelButtonTitle: (NSString *) cancelButtonTitle otherButtonTitles: (NSString *) otherButtonTitles, ...
{
	if ( (self = [super init] ) ) // will call into initWithFrame, thus TSAlertView_commonInit is called
	{
		self.title = t;
		self.message = m;
		self.delegate = d;
		
		if ( nil != cancelButtonTitle )
		{
			[self addButtonWithTitle: cancelButtonTitle ];
		}
		
		if ( nil != otherButtonTitles )
		{
			firstOtherButtonIndex = [self.buttons count];
			[self addButtonWithTitle: otherButtonTitles ];
			
			va_list args;
			va_start(args, otherButtonTitles);
			
			id arg;
			while ( nil != ( arg = va_arg( args, id ) ) ) 
			{
				if ( ![arg isKindOfClass: [NSString class] ] )
					return nil;
				
				[self addButtonWithTitle: (NSString*)arg ];
			}
		}
    
    self.cancelButtonIndex = 0;
	}
	
	return self;
}

- (CGSize) sizeThatFits: (CGSize) unused 
{
	CGSize s = [self recalcSizeAndLayout: NO];
	return s;
}

- (void) layoutSubviews
{
	[self recalcSizeAndLayout: YES];
}

- (void) drawRect:(CGRect)rect
{
	[self.backgroundImage drawInRect: rect];
}

- (void)dealloc 
{
  [[NSNotificationCenter defaultCenter] removeObserver: self ];
  
#if __has_feature(objc_arc) == 0
	[_backgroundImage release];
	[_buttons release];
	[_titleLabel release];
	[_messageLabel release];
	[_messageTextView release];
	[_messageTextViewMaskImageView release];
  [_userInfo release];
	
	//NSLog( @"TSAlertView: TSAlertOverlayWindow dealloc" );
	
  [super dealloc];
#endif
}


- (void) TSAlertView_commonInit
{
	self.backgroundColor = [UIColor clearColor];
	self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin; 
  self.clipsToBounds = YES;
	
	// defaults:
	style = TSAlertViewStyleNormal;
	self.width = 0; // set to default
	self.maxHeight = 0; // set to default
	buttonLayout = TSAlertViewButtonLayoutNormal;
	cancelButtonIndex = -1;
	firstOtherButtonIndex = -1;
}

- (void) setWidth:(CGFloat) w
{
	if ( w <= 0 )
		w = 284;
	
	width = MAX( w, self.backgroundImage.size.width );
}

- (CGFloat) width
{
	if ( nil == self.superview )
		return width;
	
	CGFloat maxWidth = self.superview.bounds.size.width - 20;
	
	return MIN( width, maxWidth );
}

- (void) setMaxHeight:(CGFloat) h
{
	if ( h <= 0 )
		h = 358;
	
	maxHeight = MAX( h, 284 );
}

- (CGFloat) maxHeight
{
	if ( nil == self.superview )
		return maxHeight;
	
	return MIN( maxHeight, self.superview.bounds.size.height - 20 );
}

- (void) setStyle:(TSAlertViewStyle)newStyle
{
	if ( style != newStyle )
	{
		style = newStyle;
		
		if ( style == TSAlertViewStyleInput )
		{
			// need to watch for keyboard
			[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector( onKeyboardWillShow:) name: UIKeyboardWillShowNotification object: nil];
			[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector( onKeyboardWillHide:) name: UIKeyboardWillHideNotification object: nil];
		}
	}
}

- (void) onKeyboardWillShow: (NSNotification*) note
{
	NSValue* v = [note.userInfo objectForKey: UIKeyboardFrameEndUserInfoKey];
	CGRect kbframe = [v CGRectValue];
	kbframe = [self.superview convertRect: kbframe fromView: nil];
	
	if ( CGRectIntersectsRect( self.frame, kbframe) )
	{
		CGPoint c = self.center;
		
    //    const CGFloat keyboardPad = 20;
    const CGFloat keyboardPad = 0;
    
		if ( self.frame.size.height > kbframe.origin.y - keyboardPad )
		{
			self.maxHeight = kbframe.origin.y - keyboardPad;
			[self sizeToFit];
			[self layoutSubviews];
		}
		
		c.y = kbframe.origin.y / 2;
		
#ifdef NS_BLOCKS_AVAILABLE
		[UIView animateWithDuration: kAlertBoxAnimDuration 
                     animations: ^{
                       self.center = c;
                       self.frame = CGRectIntegral(self.frame);
                     }];
#else
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:kAlertBoxAnimDuration];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    self.center = c;
    self.frame = CGRectIntegral(self.frame);
    [UIView commitAnimations];    
#endif
	}
}

- (void) onKeyboardWillHide: (NSNotification*) note
{
#ifdef NS_BLOCKS_AVAILABLE
	[UIView animateWithDuration: kAlertBoxAnimDuration 
                   animations: ^{
                     self.center = CGPointMake( CGRectGetMidX( self.superview.bounds ), CGRectGetMidY( self.superview.bounds ));
                     self.frame = CGRectIntegral(self.frame);
                   }];
#else
  [UIView beginAnimations:nil context:NULL];
  [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
  [UIView setAnimationDuration:kAlertBoxAnimDuration];
  self.center = CGPointMake( CGRectGetMidX( self.superview.bounds ), CGRectGetMidY( self.superview.bounds ));
  self.frame = CGRectIntegral(self.frame);
  [UIView commitAnimations];    
#endif
}

- (NSMutableArray*) buttons
{
	if ( _buttons == nil )
	{
		_buttons = [[NSMutableArray alloc] initWithCapacity:4];
	}
	
	return _buttons;
}

- (UILabel*) titleLabel
{
	if ( _titleLabel == nil )
	{
		_titleLabel = [[UILabel alloc] init];
		_titleLabel.font = [UIFont boldSystemFontOfSize: 18];
    _titleLabel.shadowColor = [UIColor blackColor];
    _titleLabel.shadowOffset = CGSizeMake(0, -1);
		_titleLabel.backgroundColor = [UIColor clearColor];
		_titleLabel.textColor = [UIColor whiteColor];
		_titleLabel.textAlignment = UITextAlignmentCenter;
		_titleLabel.lineBreakMode = UILineBreakModeWordWrap;
		_titleLabel.numberOfLines = 0;
	}
	
	return _titleLabel;
}

- (UILabel*) messageLabel
{
	if ( _messageLabel == nil )
	{
		_messageLabel = [[UILabel alloc] init];
		_messageLabel.font = [UIFont systemFontOfSize: 16];
		_messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.shadowColor = [UIColor blackColor];
    _messageLabel.shadowOffset = CGSizeMake(0, -1);
		_messageLabel.textColor = [UIColor whiteColor];
		_messageLabel.textAlignment = UITextAlignmentCenter;
		_messageLabel.lineBreakMode = UILineBreakModeWordWrap;
		_messageLabel.numberOfLines = 0;
	}
	
	return _messageLabel;
}

- (UITextView*) messageTextView
{
	if ( _messageTextView == nil )
	{
		_messageTextView = [[UITextView alloc] init];
		_messageTextView.editable = NO;
		_messageTextView.font = [UIFont systemFontOfSize: 16];
		_messageTextView.backgroundColor = [UIColor whiteColor];
		_messageTextView.textColor = [UIColor darkTextColor];
		_messageTextView.textAlignment = UITextAlignmentLeft;
		_messageTextView.bounces = YES;
		_messageTextView.alwaysBounceVertical = YES;
		_messageTextView.layer.cornerRadius = 5;
    _messageTextView.contentInset = UIEdgeInsetsMake(-6, -3, -6, -3);
	}
	
	return _messageTextView;
}

- (UIImageView*) messageTextViewMaskView
{
	if ( _messageTextViewMaskImageView == nil )
	{
		UIImage* shadowImage = [[UIImage imageNamed:@"TSAlertViewListShadow.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:7];
		
		_messageTextViewMaskImageView = [[UIImageView alloc] initWithImage: shadowImage];
		_messageTextViewMaskImageView.userInteractionEnabled = NO;
		_messageTextViewMaskImageView.layer.masksToBounds = YES;
		_messageTextViewMaskImageView.layer.cornerRadius = 6;
	}
	return _messageTextViewMaskImageView;
}

- (UITextField*) inputTextField
{
	if ( _inputTextField == nil )
	{
		_inputTextField = [[UITextField alloc] init];
		_inputTextField.borderStyle = UITextBorderStyleRoundedRect;
    _inputTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	}
	
	return _inputTextField;
}

- (UIActivityIndicatorView*) activityIndicatorView {
  if (_activityIndicatorView == nil) {
    _activityIndicatorView = [[UIActivityIndicatorView alloc] 
                              initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [_activityIndicatorView setHidesWhenStopped:YES];
    [_activityIndicatorView startAnimating];
  }
  return _activityIndicatorView;
}

- (UIImage*) backgroundImage
{
	if ( _backgroundImage == nil )
	{
		self.backgroundImage = [[UIImage imageNamed: @"TSAlertViewSheetBackground.png"] stretchableImageWithLeftCapWidth: 15 topCapHeight: 30];
	}
	
	return _backgroundImage;
}

- (void) setTitle:(NSString *)t {
	self.titleLabel.text = t;
}

- (NSString*) title 
{
	return self.titleLabel.text;
}

- (void) setMessage:(NSString *)t
{
	self.messageLabel.text = t;
  //
	self.messageTextView.text = t;
  self.messageTextView.contentSize = [t sizeWithFont:self.messageTextView.font 
                                   constrainedToSize:CGSizeMake(self.messageTextView.frame.size.width, CGFLOAT_MAX) 
                                       lineBreakMode:UILineBreakModeWordWrap];
  self.messageTextView.contentOffset = CGPointZero;
}

- (NSString*) message  
{
	return self.messageLabel.text;
}

- (NSInteger) numberOfButtons
{
	return [self.buttons count];
}

- (void) setCancelButtonIndex:(NSInteger)buttonIndex
{
	// avoid a NSRange exception
	if ( buttonIndex < 0 || buttonIndex >= (NSInteger) [self.buttons count] )
		return;
	
	cancelButtonIndex = buttonIndex;
	
  // only do this for multiple buttons...
  if ([self.buttons count] != 1) {
    UIButton* b = [self.buttons objectAtIndex: buttonIndex];
    
    UIImage* buttonBgNormal = [UIImage imageNamed: @"TSAlertViewSheetDefaultButton.png"];
    buttonBgNormal = [buttonBgNormal stretchableImageWithLeftCapWidth: buttonBgNormal.size.width / 2.0 topCapHeight: buttonBgNormal.size.height / 2.0];
    [b setBackgroundImage: buttonBgNormal forState: UIControlStateNormal];
    
    UIImage* buttonBgPressed = [UIImage imageNamed: @"TSAlertViewSheetButtonPress.png"];
    buttonBgPressed = [buttonBgPressed stretchableImageWithLeftCapWidth: buttonBgPressed.size.width / 2.0 topCapHeight: buttonBgPressed.size.height / 2.0];
    [b setBackgroundImage: buttonBgPressed forState: UIControlStateHighlighted];
  }
}

- (BOOL) isVisible
{
	return self.superview != nil;
}

- (NSInteger) addButtonWithTitle: (NSString *) t
{
	UIButton* b = [UIButton buttonWithType: UIButtonTypeCustom];
	[b setTitle: t forState: UIControlStateNormal];
  b.titleLabel.font = [UIFont boldSystemFontOfSize:18];
  b.titleLabel.shadowColor = [UIColor blackColor];
  b.titleLabel.shadowOffset = CGSizeMake(0, -1);
	
	UIImage* buttonBgNormal = [UIImage imageNamed: @"TSAlertViewSheetButton.png"];
	buttonBgNormal = [buttonBgNormal stretchableImageWithLeftCapWidth: buttonBgNormal.size.width / 2.0 topCapHeight: buttonBgNormal.size.height / 2.0];
	[b setBackgroundImage: buttonBgNormal forState: UIControlStateNormal];
	
	UIImage* buttonBgPressed = [UIImage imageNamed: @"TSAlertViewSheetButtonPress.png"];
	buttonBgPressed = [buttonBgPressed stretchableImageWithLeftCapWidth: buttonBgPressed.size.width / 2.0 topCapHeight: buttonBgPressed.size.height / 2.0];
	[b setBackgroundImage: buttonBgPressed forState: UIControlStateHighlighted];
	
	[b addTarget: self action: @selector(onButtonPress:) forControlEvents: UIControlEventTouchUpInside];
	
	[self.buttons addObject: b];
	
	[self setNeedsLayout];
	
	return self.buttons.count-1;
}

- (NSString *) buttonTitleAtIndex:(NSInteger)buttonIndex
{
	// avoid a NSRange exception
	if ( buttonIndex < 0 || buttonIndex >= (NSInteger) [self.buttons count] )
		return nil;
	
	UIButton* b = [self.buttons objectAtIndex: buttonIndex];
	
	return [b titleForState: UIControlStateNormal];
}

- (void) dismissWithClickedButtonIndex: (NSInteger)buttonIndex animated: (BOOL) animated
{	
	if ( [self.delegate respondsToSelector: @selector(alertView:willDismissWithButtonIndex:)] )
	{
		[self.delegate alertView: self willDismissWithButtonIndex: buttonIndex ];
	}
	
  [[self class] pop:self buttonIndex:buttonIndex animated:animated];
}

- (UIWindow*) window { return [super window]; }

- (void) releaseWindow: (int) buttonIndex
{
	if ( [self.delegate respondsToSelector: @selector(alertView:didDismissWithButtonIndex:)] )
	{
		[self.delegate alertView: self didDismissWithButtonIndex: buttonIndex ];
	}
	
	// the one place we release the window we allocated in "show"
	// this will propogate releases to us (TSAlertView), and our TSAlertViewController
	
#if __has_feature(objc_arc) == 0
  /**
   This silences the false positive on the window
   ONLY compiles when analysing!
   */
#ifndef __clang_analyzer__
	[self.window release];
#endif
#endif
}

- (void) animationWaitLoopForSelectorNamed:(NSString*)selName 
{
  while (__TSAlertAnimFlag == YES) {
    [self performSelector:_cmd withObject:selName afterDelay:.1];
  }  
  [self performSelectorOnMainThread:NSSelectorFromString(selName) 
                         withObject:nil 
                      waitUntilDone:NO];
}

- (void) show {
  if (__TSAlertAnimFlag == YES) {
    [self performSelectorInBackground:@selector(animationWaitLoopForSelectorNamed:) 
                           withObject:NSStringFromSelector(_cmd)];
    return;
  }
  __TSAlertAnimFlag = YES;
  //	[[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode beforeDate:[NSDate date]];
  [[self class] push:self];
}

+ (void) show:(TSAlertView*)alertView 
{
  TSAlertViewController* avc = [[TSAlertViewController alloc] init];
#if __has_feature(objc_arc) == 0
  [avc autorelease];
#endif
  
	avc.view.backgroundColor = [UIColor clearColor];
	
	// $important - the window is released only when the user clicks an alert view button
  CGRect rect = [UIScreen mainScreen].bounds;
  
	TSAlertOverlayWindow* ow = [[TSAlertOverlayWindow alloc] initWithFrame:rect];
  /**
   This silences the false positive on the window
   ONLY compiles when analysing!
   */
#ifdef __clang_analyzer__
  [ow autorelease];
#endif
  
	ow.alpha = 0.0;
	ow.backgroundColor = [UIColor clearColor];
  
  TSAlertViewGradientView *gradient = [[TSAlertViewGradientView alloc] initWithFrame:rect];
  [ow addSubview:gradient];
  [gradient release];
  
  // add and pulse the alertview
	// add the alertview
  alertView.hidden = YES;
	[avc.view addSubview: alertView];
	[alertView sizeToFit];
	alertView.center = CGPointMake( CGRectGetMidX( avc.view.bounds ), CGRectGetMidY( avc.view.bounds ) );;
	alertView.frame = CGRectIntegral( alertView.frame );
  
#ifdef __IPHONE_4_0
	ow.rootViewController = avc;
#else
  [ow addSubview:avc];
#endif
  
	[ow makeKeyAndVisible];
	
	// fade in the window  
#ifdef NS_BLOCKS_AVAILABLE
  [UIView animateWithDuration:kAlertBackgroundAnimDuration 
                        delay:0 
                      options:UIViewAnimationOptionCurveEaseIn 
                   animations:^{
                     ow.alpha = 1;
                   } completion:^(BOOL finished) {
                     [self showAlert:alertView];
                   }];
#else
  // alert will be released when the animation stops
  [alertView retain];
  [UIView beginAnimations:kAlertAnimShow context:alertView];
  //
  [UIView setAnimationDelegate:self];
  [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
  [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
  [UIView setAnimationDuration:kAlertBackgroundAnimDuration];
  ow.alpha = 1;
  [UIView commitAnimations];
#endif	
}

+ (void) showAlert:(TSAlertView*)alertView {
  // pulse anim
  alertView.hidden = NO;
	[alertView pulse];
}

+ (void) hide:(TSAlertView*)alertView 
  buttonIndex:(NSUInteger)buttonIndex 
     animated:(BOOL)animated
{
  // always resign
  [alertView.inputTextField resignFirstResponder];
  
  if ( animated )
	{
#ifdef NS_BLOCKS_AVAILABLE
    [UIView animateWithDuration:kAlertBoxAnimDuration 
                          delay:0 
                        options:UIViewAnimationOptionCurveEaseInOut 
                     animations:^{
                       alertView.alpha = 0;
                     } completion:^(BOOL finished) {
                       if ( alertView.style == TSAlertViewStyleInput && [alertView.inputTextField isFirstResponder] ) {
                         [alertView.inputTextField resignFirstResponder];
                       }
                       
                       [UIView animateWithDuration:kAlertBackgroundAnimDuration 
                                             delay:0 
                                           options:UIViewAnimationOptionCurveEaseOut 
                                        animations:^{
                                          [alertView.window resignKeyWindow];
                                          alertView.window.alpha = 0;
                                        } completion:^(BOOL finished) {
                                          [alertView releaseWindow: buttonIndex];
                                          // some other to show?
                                          if ([__TSAlertViewStack count]) {
                                            [self show:[__TSAlertViewStack lastObject]];
                                          }
                                          [self hideDidComplete:alertView];
                                        }];
                     }];
#else
    [UIView beginAnimations:kAlertAnimDismiss1 
                    context:(ARC_BRIDGE void*) [[NSArray alloc] initWithObjects:
                                                alertView, 
                                                [NSNumber numberWithInteger:buttonIndex],
                                                nil]];
    [UIView setAnimationDuration:kAlertBoxAnimDuration];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
    [[[alertView.window subviews] objectAtIndex:0] setAlpha:0];
		[UIView commitAnimations];
#endif		
	}
	else
	{
		[alertView.window resignKeyWindow];
		[alertView releaseWindow: buttonIndex];
	}
}

+ (void) push:(TSAlertView*)alertView
{
  TSAlertView *hideView = nil;
  
  // any alerts to pop first?
  if ([__TSAlertViewStack count]) {
    hideView = [__TSAlertViewStack lastObject];
  } 
  
  // always add to stack
  [__TSAlertViewStack addObject:alertView];
  
  if (hideView) {
    // hide always non-animated
    [self hide:hideView buttonIndex:[hideView cancelButtonIndex] animated:NO];
  } 
  
  // show the new view
  [self show:alertView];    
}

+ (void) pop:(TSAlertView*)alertView 
 buttonIndex:(NSUInteger)index 
    animated:(BOOL)animated
{
  // might get called when this alert isn't top of the stack...
  if ([__TSAlertViewStack lastObject] == alertView) {
    id alert = [[__TSAlertViewStack lastObject] retain];
    [__TSAlertViewStack removeLastObject];
    [self hide:alertView buttonIndex:index animated:animated];  
    [alert release];
  }
}

#ifndef NS_BLOCKS_AVAILABLE
- (void)animationDidStop:(NSString *)animationID 
                finished:(NSNumber *)finished 
                 context:(void *)context
{
  if ([animationID isEqual:kAlertAnimPulse1]) {
    [UIView beginAnimations:kAlertAnimPulse2 context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationDuration:1.0/15.0];
    self.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [UIView commitAnimations];
  }
  if ([animationID isEqual:kAlertAnimPulse2]) {
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelegate:[TSAlertView class]];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationDuration:1.0/7.5];
    [UIView setAnimationDidStopSelector:@selector(showDidComplete:)];
    self.transform = CGAffineTransformIdentity;
    [UIView commitAnimations];    
    if ( self.style == TSAlertViewStyleInput )
    {
      [self layoutSubviews];
      [self.inputTextField becomeFirstResponder];
    }
  }
  if ([animationID isEqual:kAlertAnimDismiss1]) {
    [self releaseWindow:[(ARC_BRIDGE NSNumber*) context integerValue]];
    [TSAlertView dismissDidComplete:nil];
  }  
}

+ (void) showDidComplete:(TSAlertView*)alert { 
  __TSAlertAnimFlag = NO;
}

+ (void) dismissDidComplete:(TSAlertView*)alert { 
  //  [__TSAlertAnimLock unlock]; 
}

+ (void)animationDidStop:(NSString *)animationID 
                finished:(NSNumber *)finished 
                 context:(void *)context
{
  if ([animationID isEqual:kAlertAnimShow]) {
    [self showAlert:context];
    // was retained before animation began...
    [(id) context release];
  }
  
  if ([animationID isEqual:kAlertAnimDismiss1]) 
  {
    NSArray *array = (ARC_BRIDGE NSArray*) context;
    TSAlertView *alertView = [array objectAtIndex:0];
    
    if ( alertView.style == TSAlertViewStyleInput && [alertView.inputTextField isFirstResponder] ) {
      [alertView.inputTextField resignFirstResponder];
    }
    
    [UIView beginAnimations:kAlertAnimDismiss2 context:context];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDuration:kAlertBackgroundAnimDuration];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
    alertView.alpha = 0;
    [UIView commitAnimations];
  }
  
  if ([animationID isEqual:kAlertAnimDismiss2]) 
  {
    NSArray *array = (ARC_BRIDGE NSArray*) context;
    TSAlertView *alertView = [array objectAtIndex:0];
    NSNumber *buttonIndex = [array objectAtIndex:1];
    
    [alertView.window resignKeyWindow];
    [alertView releaseWindow:[buttonIndex unsignedIntegerValue]];
    
#if __has_feature(objc_arc) == 0
    // array can't be autoreleased...
    [array release];
#endif 
    
    // some other to show?
    if ([__TSAlertViewStack count]) {
      [self showAlert:[__TSAlertViewStack lastObject]];
    }
  }
}

#endif

- (void) pulse
{
  if ( self.style == TSAlertViewStyleInput )
  {
    [self layoutSubviews];
    [self.inputTextField becomeFirstResponder];
  }
  
	// pulse animation thanks to:  http://delackner.com/blog/2009/12/mimicking-uialertviews-animated-transition/
  self.transform = CGAffineTransformMakeScale(0.6, 0.6);
#ifdef NS_BLOCKS_AVAILABLE
	[UIView animateWithDuration: kAlertBoxAnimDuration 
                   animations: ^{
                     self.transform = CGAffineTransformMakeScale(1.1, 1.1);
                   }
                   completion: ^(BOOL finished){
                     [UIView animateWithDuration:1.0/15.0
                                      animations: ^{
                                        self.transform = CGAffineTransformMakeScale(0.9, 0.9);
                                      }
                                      completion: ^(BOOL finished) {
                                        [UIView animateWithDuration:(NSTimeInterval)duration 
                                                         animations:(void (^)(void))animations 
                                                         completion:(void (^)(BOOL finished))completion
                                         
                                         [UIView animateWithDuration:1.0/7.5
                                                          animations: ^{
                                                            self.transform = CGAffineTransformIdentity;
                                                            if ( self.style == TSAlertViewStyleInput )
                                                            {
                                                              [self layoutSubviews];
                                                              [self.inputTextField becomeFirstResponder];
                                                            }
                                                          } 
                                                          completion: ^ {
                                                            [TSAlertView showDidComplete:self];
                                                          }];
                                         }];
                                      }];
#else
                     [UIView beginAnimations:kAlertAnimPulse1 context:NULL];
                     [UIView setAnimationDelegate:self];
                     [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
                     [UIView setAnimationDuration:kAlertBoxAnimDuration];
                     [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
                     [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
                     self.transform = CGAffineTransformMakeScale(1.1, 1.1);
                     [UIView commitAnimations];
#endif  
                   }
   
   - (void) onButtonPress: (id) sender
   {
     int buttonIndex = [_buttons indexOfObjectIdenticalTo: sender];
     
     if ( [self.delegate respondsToSelector: @selector(alertView:clickedButtonAtIndex:)] )
     {
       [self.delegate alertView: self clickedButtonAtIndex: buttonIndex ];
     }
     
     if ( buttonIndex == self.cancelButtonIndex )
     {
       if ( [self.delegate respondsToSelector: @selector(alertViewCancel:)] )
       {
         [self.delegate alertViewCancel: self ];
       }	
     }
     
     [self dismissWithClickedButtonIndex: buttonIndex  animated: YES];
   }
   
   - (CGSize) recalcSizeAndLayout: (BOOL) layout
   {
     BOOL	stacked = !(self.buttonLayout == TSAlertViewButtonLayoutNormal && [self.buttons count] == 2 );
     
     CGFloat maxWidth = self.width - (kTSAlertView_LeftMargin * 2);
     
     CGSize  titleLabelSize = [self titleLabelSize];
     CGSize  messageViewSize = [self messageLabelSize];
     CGSize  inputTextFieldSize = [self inputTextFieldSize];
     CGSize  buttonsAreaSize = stacked ? [self buttonsAreaSize_Stacked] : [self buttonsAreaSize_SideBySide];
     
     CGFloat inputRowHeight = ( 
                               self.style == TSAlertViewStyleInput ? 
                               inputTextFieldSize.height + kTSAlertView_RowMargin : 
                               0
                               );
     if (self.style == TSAlertViewStyleActivityView) {
       inputRowHeight += self.activityIndicatorView.frame.size.height;
     }
     
     CGFloat totalHeight = (
                            kTSAlertView_TopMargin + 
                            titleLabelSize.height + 
                            kTSAlertView_RowMargin + 
                            messageViewSize.height + 
                            inputRowHeight + 
                            kTSAlertView_RowMargin + 
                            buttonsAreaSize.height + 
                            kTSAlertView_BottomMargin
                            );
     
     // extra if multiple stacked buttons...
     if (stacked && [self.buttons count] > 1) {
       totalHeight += 2 * kTSAlertView_RowMargin;
     }
     
     // when no buttons, leaves more space
     if (![self.buttons count]) {
       CGSize s = [self.inputTextField sizeThatFits: CGSizeZero];
       totalHeight += s.height + kTSAlertView_TopMargin;
     }
     
     if ( totalHeight > self.maxHeight )
     {
       // too tall - we'll condense by using a textView (with scrolling) for the message
       
       totalHeight -= messageViewSize.height;
       //$$what if it's still too tall?
       messageViewSize.height = self.maxHeight - totalHeight;
       
       totalHeight = self.maxHeight;
       
       self.usesMessageTextView = YES;
     } else {
       self.usesMessageTextView = NO;
     }
     
     if ( layout )
     {
       // title
       CGFloat y = kTSAlertView_TopMargin;
       if ( self.title != nil )
       {
         self.titleLabel.frame = CGRectMake( kTSAlertView_LeftMargin, y, titleLabelSize.width, titleLabelSize.height );
         [self addSubview: self.titleLabel];
         y += titleLabelSize.height + kTSAlertView_RowMargin;
       }
       
       // message
       if ( self.message != nil )
       {
         if ( self.usesMessageTextView )
         {
           [self.messageLabel removeFromSuperview];
           //
           self.messageTextView.frame = CGRectMake(kTSAlertView_LeftMargin, 
                                                   y, 
                                                   messageViewSize.width, 
                                                   messageViewSize.height + 10
                                                   );
           [self addSubview: self.messageTextView];
           y += messageViewSize.height + kTSAlertView_RowMargin;
           
           UIImageView* maskImageView = [self messageTextViewMaskView];
           maskImageView.frame = self.messageTextView.frame;
           [self addSubview: maskImageView];
         }
         else
         {
           [self.messageTextView removeFromSuperview];
           [[self messageTextViewMaskView] removeFromSuperview];
           //
           self.messageLabel.frame = CGRectMake( kTSAlertView_LeftMargin, y, messageViewSize.width, messageViewSize.height );
           [self addSubview: self.messageLabel];
           y += messageViewSize.height + kTSAlertView_RowMargin;
         }
       }
       
       // input
       if ( self.style == TSAlertViewStyleInput )
       {
         self.inputTextField.frame = CGRectMake( kTSAlertView_LeftMargin, y, inputTextFieldSize.width, inputTextFieldSize.height );
         [self addSubview: self.inputTextField];
         y += inputTextFieldSize.height + kTSAlertView_RowMargin;
       }
       
       // activity
       if (self.style == TSAlertViewStyleActivityView) {
         self.activityIndicatorView.center = CGPointMake(kTSAlertView_LeftMargin + inputTextFieldSize.width / 2, 
                                                         y + inputTextFieldSize.height / 2);
         [self addSubview:self.activityIndicatorView];
         y += self.activityIndicatorView.frame.size.height + kTSAlertView_RowMargin;
       }
       
       // buttons
       CGFloat buttonHeight = (
                               [self.buttons count] ? 
                               [[self.buttons objectAtIndex:0] sizeThatFits: CGSizeZero].height :
                               0
                               );
       y += 10;
       
       if ( stacked )
       {
         CGFloat buttonWidth = maxWidth;
         CGRect buttonRect = CGRectMake( kTSAlertView_LeftMargin, y, buttonWidth, buttonHeight );
         
         for (NSUInteger i = self.cancelButtonIndex + 1; i < [self.buttons count]; ++i) {
           UIButton *b = [self.buttons objectAtIndex:i];
           b.frame = buttonRect;
           [self addSubview: b];
           y += buttonHeight + kTSAlertView_RowMargin;
           buttonRect.origin.y = y;
         }
         
         // cancel button is on buttom...
         if ([self.buttons count]) {
           UIButton *b = [self.buttons objectAtIndex:self.cancelButtonIndex];
           y += [self.buttons count] > 1 ? 2 * kTSAlertView_RowMargin : 0;
           buttonRect.origin.y = y;
           [self addSubview:b];
           b.frame = buttonRect;
         }
         
       }
       else
       {
         CGFloat buttonWidth = (maxWidth - kTSAlertView_ColumnMargin) / 2.0;
         CGFloat x = kTSAlertView_LeftMargin;
         for ( UIButton* b in self.buttons )
         {
           b.frame = CGRectMake( x, y, buttonWidth, buttonHeight );
           [self addSubview: b];
           x += buttonWidth + kTSAlertView_ColumnMargin;
         }
       }
       
     }
     
     return CGSizeMake( self.width, totalHeight + 10 );
     //return CGSizeMake( self.width, totalHeight );
   }
   
   - (CGSize) titleLabelSize
   {
     CGSize s = CGSizeZero;
     if (self.titleLabel.text) {
       CGFloat maxWidth = self.width - (kTSAlertView_LeftMargin * 2);
       s = [self.titleLabel.text sizeWithFont: self.titleLabel.font 
                            constrainedToSize: CGSizeMake(maxWidth, 1000) 
                                lineBreakMode: self.titleLabel.lineBreakMode];
       if ( s.width < maxWidth )
         s.width = maxWidth;
     }
     
     return s;
   }
   
   - (CGSize) messageLabelSize
   {
     CGSize s = CGSizeZero;
     if (self.messageLabel.text) {
       CGFloat maxWidth = self.width - (kTSAlertView_LeftMargin * 2);
       s = [self.messageLabel.text sizeWithFont: self.messageLabel.font 
                              constrainedToSize: CGSizeMake(maxWidth, 1000) 
                                  lineBreakMode: self.messageLabel.lineBreakMode];
       if ( s.width < maxWidth )
         s.width = maxWidth;
     }
     return s;
   }
   
   - (CGSize) inputTextFieldSize
   {
     if ( self.style == TSAlertViewStyleNormal)
       return CGSizeZero;
     
     CGFloat maxWidth = self.width - (kTSAlertView_LeftMargin * 2);
     
     CGSize s = [self.inputTextField sizeThatFits: CGSizeZero];
     
     return CGSizeMake( maxWidth, s.height );
   }
   
   - (CGSize) buttonsAreaSize_SideBySide
   {
     CGFloat maxWidth = self.width - (kTSAlertView_LeftMargin * 2);
     
     CGSize bs = [[self.buttons objectAtIndex:0] sizeThatFits: CGSizeZero];
     
     bs.width = maxWidth;
     
     return bs;
   }
   
   - (CGSize) buttonsAreaSize_Stacked
   {
     CGFloat maxWidth = self.width - (kTSAlertView_LeftMargin * 2);
     int buttonCount = [self.buttons count];
     
     CGSize bs = CGSizeZero;
     if ([self.buttons count]) {
       bs = [[self.buttons objectAtIndex:0] sizeThatFits: CGSizeZero];
     }
     
     bs.width = maxWidth;
     
     bs.height = (bs.height * buttonCount) + (kTSAlertView_RowMargin * (buttonCount-1));
     
     return bs;
   }
   
   @end
   
   
   
   
