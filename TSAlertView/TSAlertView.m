//
//  TSAlertView.m
//
//  Created by Nick Hodapp aka Tom Swift on 1/19/11.
//

#import "TSAlertView.h"
#import "TSAlertView+Protected.h"
#import <QuartzCore/QuartzCore.h>
#import "SynthesizeSingleton.h"
#import "MKDUIKeyboardInfo.h"
//
#import "TSAlertOverlayWindow.h"

//#if NS_BLOCKS_AVAILABLE
//#undef NS_BLOCKS_AVAILABLE
//#endif

//static BOOL __TSAlertAnimFlag = NO;

const NSTimeInterval kAlertBoxAnimDuration = 0.1;
const NSTimeInterval kAlertBackgroundAnimDuration = 0.2;

CGFloat kTSAlertView_LeftMargin	= 10.0;
CGFloat kTSAlertView_TopMargin	= 7.0;
CGFloat kTSAlertView_BottomMargin = 7.0;
CGFloat kTSAlertView_RowMargin	= 7.0;
CGFloat kTSAlertView_ColumnMargin = 10.0;

static NSString *const kAlertAnimPulse1   = @"PulsePart1";
static NSString *const kAlertAnimPulse2   = @"PulsePart2";
static NSString *const kAlertAnimShow     = @"Show";
static NSString *const kAlertAnimDismiss1 = @"Dismiss1";
static NSString *const kAlertAnimDismiss2 = @"Dismiss2";

@implementation TSAlertView

@synthesize delegate=_delegate, cancelButtonIndex=_cancelButtonIndex, buttonLayout=_buttonLayout;
@synthesize firstOtherButtonIndex=_firstOtherButtonIndex, width=_width, maxHeight=_maxHeight;
@synthesize usesMessageTextView=_usesMessageTextView, backgroundImage=_backgroundImage;
@synthesize style=_style, activityIndicatorView=_activityIndicatorView, userInfo=_userInfo;

- (id) init {
	if ( ( self = [super init] ) ) {
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
			self.width = frame.size.width;
			self.maxHeight = frame.size.height;
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
			_firstOtherButtonIndex = [self.buttons count];
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
                         ( titleLabelSize.height ? titleLabelSize.height : 0 ) +
                         kTSAlertView_RowMargin +
                         ( messageViewSize.height ? messageViewSize.height + kTSAlertView_RowMargin : 0 ) +
                         ( inputRowHeight ? inputRowHeight + kTSAlertView_RowMargin : 0 ) +
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
    
    // bottom up
    y = totalHeight - buttonHeight - kTSAlertView_BottomMargin;
    
    // input - immediately above buttons
    if ( self.style == TSAlertViewStyleInput )
    {
      self.inputTextField.frame = CGRectMake(kTSAlertView_LeftMargin, 
                                             y - inputTextFieldSize.height - kTSAlertView_RowMargin, 
                                             inputTextFieldSize.width, 
                                             inputTextFieldSize.height );
      [self addSubview: self.inputTextField];
    }
        
    if ( stacked )
    {
      CGFloat buttonWidth = maxWidth;
      CGRect buttonRect = CGRectMake( kTSAlertView_LeftMargin, y, buttonWidth, buttonHeight );
      
      // cancel button is on buttom...
      if ([self.buttons count]) {
        UIButton *b = [self.buttons objectAtIndex:self.cancelButtonIndex];
        buttonRect.origin.y = y;
        [self addSubview:b];
        b.frame = buttonRect;
        // extra padding above cancel button
        y -= ( buttonHeight + kTSAlertView_RowMargin + ( [self.buttons count] > 1 * kTSAlertView_RowMargin ) );
      }
      
      // go backwards
      for (NSInteger i = [self.buttons count]; i-- > self.cancelButtonIndex + 1; ) {    
        UIButton *b = [self.buttons objectAtIndex:i];
        buttonRect.origin.y = y;  
        b.frame = buttonRect;
        [self addSubview: b];
        y -= buttonHeight + kTSAlertView_RowMargin;
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
}

#if NS_BLOCKS_AVAILABLE == 0
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
    self.transform = CGAffineTransformIdentity;
    [UIView commitAnimations];    
    if ( self.style == TSAlertViewStyleInput )
    {
      [self layoutSubviews];
      [self.inputTextField becomeFirstResponder];
    }
  }
}
#endif

- (CGSize) titleLabelSize
{
  CGSize s = CGSizeZero;
  if (self.titleLabel.text) {
    CGFloat maxWidth = self.width - (kTSAlertView_LeftMargin * 2);
    s = [self.titleLabel.text sizeWithFont: self.titleLabel.font 
                         constrainedToSize: CGSizeMake(maxWidth, FLT_MAX) 
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
                           constrainedToSize: CGSizeMake(maxWidth, FLT_MAX) 
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

- (void) layoutSubviews {
	[self recalcSizeAndLayout: YES];
}

- (void) drawRect:(CGRect)rect {
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
	self.style = TSAlertViewStyleNormal;
	self.width = 0; // set to default
	self.maxHeight = 0; // set to default
	self.buttonLayout = TSAlertViewButtonLayoutNormal;
	self.cancelButtonIndex = -1;
	_firstOtherButtonIndex = -1;
}

- (void) setWidth:(CGFloat) w {
	if ( w <= 0 )
		w = 284;
	_width = MAX( w, self.backgroundImage.size.width );
}

- (CGFloat) width {
	if ( nil == self.superview )
		return _width;
	CGFloat maxWidth = self.superview.bounds.size.width - 20;
	return MIN( _width, maxWidth );
}

- (void) setMaxHeight:(CGFloat) h {
	if ( h <= 0 )
		h = 358;
	_maxHeight = MIN( h, 284 );
}

- (CGFloat) maxHeight {
	if ( nil == self.superview )
		return _maxHeight;
	return MIN( _maxHeight, self.superview.bounds.size.height - 20 );
}

- (void) setStyle:(TSAlertViewStyle)newStyle
{
	if ( self.style != newStyle )
	{
		_style = newStyle;
		
		if ( self.style == TSAlertViewStyleInput )
		{
			// need to watch for keyboard
			[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector( onKeyboardWillShow:) name: UIKeyboardWillShowNotification object: nil];
			[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector( onKeyboardWillHide:) name: UIKeyboardWillHideNotification object: nil];
		}
	}
}

- (void) onKeyboardWillShow: (NSNotification*) note
{
  MKDUIKeyboardInfo *info = [MKDUIKeyboardInfo infoFromKeyboardNotification:note view:self.superview];
	CGRect kbframe = info.end;
	
	if ( CGRectIntersectsRect( self.frame, kbframe) )
	{
		CGPoint c = self.center;
		
    const CGFloat keyboardPad = 10;
//    const CGFloat keyboardPad = 0;
    
		if ( self.frame.size.height > kbframe.origin.y - keyboardPad )
		{
      NSLog(@"%f", kbframe.origin.y);
			self.maxHeight = kbframe.origin.y - keyboardPad;
			[self sizeToFit];
			[self layoutSubviews];
		}
		
		c.y = kbframe.origin.y / 2;
		
#if NS_BLOCKS_AVAILABLE
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
#if NS_BLOCKS_AVAILABLE
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

- (void) setCancelButtonIndex:(NSInteger)buttonIndex
{
	// avoid a NSRange exception
	if ( buttonIndex < 0 || buttonIndex >= (NSInteger) [self.buttons count] )
		return;
	
	_cancelButtonIndex = buttonIndex;
	
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
	
  [[TSAlertOverlayWindow sharedTSAlertOverlayWindow] pop:self 
                                             buttonIndex:buttonIndex 
                                                animated:animated];
}

- (UIWindow*) window { return [super window]; }

- (void) releaseWindow: (int) buttonIndex
{
	if ( [self.delegate respondsToSelector: @selector(alertView:didDismissWithButtonIndex:)] )
	{
		[self.delegate alertView: self didDismissWithButtonIndex: buttonIndex ];
	}
}

- (void) show {
  [[TSAlertOverlayWindow sharedTSAlertOverlayWindow] push:self animated:YES];
}

#pragma mark -
#pragma mark Properties

- (NSMutableArray*) buttons {
	if ( _buttons == nil ) {
		_buttons = [[NSMutableArray alloc] initWithCapacity:4];
	}
	return _buttons;
}

- (NSString*) title { return self.titleLabel.text; }
- (void) setTitle:(NSString *)t { self.titleLabel.text = t; }

- (void) setMessage:(NSString *)t {
	self.messageLabel.text = t;
  //
	self.messageTextView.text = t;
  self.messageTextView.contentSize = [t sizeWithFont:self.messageTextView.font 
                                   constrainedToSize:CGSizeMake(self.messageTextView.frame.size.width, CGFLOAT_MAX) 
                                       lineBreakMode:UILineBreakModeWordWrap];
  self.messageTextView.contentOffset = CGPointZero;
}

- (NSString*) message { return self.messageLabel.text; }

- (UILabel*) messageLabel {
	if ( _messageLabel == nil ) {
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

- (UITextField*) inputTextField {
	if ( _inputTextField == nil ) {
		_inputTextField = [[UITextField alloc] init];
		_inputTextField.borderStyle = UITextBorderStyleRoundedRect;
    _inputTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	}
	return _inputTextField;
}

- (NSInteger) numberOfButtons { return [self.buttons count]; }

- (UITextView*) messageTextView {
	if ( _messageTextView == nil ) {
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

- (UILabel*) titleLabel {
	if ( _titleLabel == nil ) {
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

- (BOOL) isVisible {
	return self.superview != nil;
}

- (void) pulse
{
  if ( self.style == TSAlertViewStyleInput )
  {
    [self layoutSubviews];
    [self.inputTextField becomeFirstResponder];
  }
  
	// pulse animation thanks to:  http://delackner.com/blog/2009/12/mimicking-uialertviews-animated-transition/
  self.transform = CGAffineTransformMakeScale(0.6, 0.6);
#if NS_BLOCKS_AVAILABLE
	[UIView animateWithDuration: kAlertBoxAnimDuration 
                   animations: ^{
                     self.alpha = 1;
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
                     self.alpha = 1;
                     self.transform = CGAffineTransformMakeScale(1.1, 1.1);
                     [UIView commitAnimations];
#endif  
                   }

@end




