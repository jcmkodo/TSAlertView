//
//  TSAlertView.m
//
//  Created by Nick Hodapp aka Tom Swift on 1/19/11.
//

#import "TSAlertView.h"
#import "TSAlertView+Protected.h"
#import <QuartzCore/QuartzCore.h>
#import "CWLSynthesizeSingleton.h"
#import "MKDUIKeyboardInfo.h"
//
#import "TSAlertOverlayWindow.h"

const NSTimeInterval kAlertBoxAnimDuration = 0.1;
const NSTimeInterval kAlertBackgroundAnimDuration = 0.2;

static const CGFloat kDefaultWidth = 284;
static const CGFloat kDefaultHeight = 358;

static const CGFloat kPulseAnimScale1 = 0.6;
static const CGFloat kPulseAnimScale2 = 1.1/0.6;
static const CGFloat kPulseAnimScale3 = 0.9/1.1;
static const CGFloat kPulseAnimScale4 = 1.0/0.9;

static TSAlertViewAppearanceProxy *__appearanceProxy = nil;

CGFloat kTSAlertView_LeftMargin   = 10.0;
CGFloat kTSAlertView_TopMargin    = 7.0;
CGFloat kTSAlertView_BottomMargin = 7.0;
CGFloat kTSAlertView_RowMargin    = 7.0;
CGFloat kTSAlertView_ColumnMargin = 10.0;

@implementation TSAlertViewBase
@synthesize backgroundImage=_backgroundImage;

+ (void) setAppearanceProxy:(TSAlertViewAppearanceProxy *)proxy {
  AtomicRetainedSetToFrom(__appearanceProxy, proxy);
}

+ (TSAlertViewAppearanceProxy*) appearanceProxy { return AtomicAutoreleasedGet(__appearanceProxy); }

+ (id) show {
  TSAlertViewBase *ret = [[[self alloc] initWithFrame:CGRectZero] autorelease];
  [ret show];
  return ret;
}

- (void) awakeFromNib {
  [super awakeFromNib];
  [self TSAlertView_commonInit];
}

- (void) pulse {
  // pulse animation thanks to: http://delackner.com/blog/2009/12/mimicking-uialertviews-animated-transition/
  
  [UIView animateWithDuration:kAlertBoxAnimDuration delay:0 options:0 animations:^{
    self.alpha = 1;
    self.transform = CGAffineTransformScale(self.transform, kPulseAnimScale1, kPulseAnimScale1);
  } completion:^(BOOL finished1) {
    if (finished1) {
      [UIView animateWithDuration:kAlertBoxAnimDuration delay:0 options:0 animations:^{
        self.transform = CGAffineTransformScale(self.transform, kPulseAnimScale2, kPulseAnimScale2);
      } completion:^(BOOL finished2) {
        if (finished2) {
          [UIView animateWithDuration:kAlertBoxAnimDuration delay:0 options:0 animations:^{
            self.transform = CGAffineTransformScale(self.transform, kPulseAnimScale3, kPulseAnimScale3);
          } completion:^(BOOL finished3) {
            if (finished3) {
              [self didCompleteDisplayAnimations];
            }
          }];
        }
      }];
    }
  }];
}

- (void) didCompleteDisplayAnimations {}

- (void) willMoveToSuperview:(UIView *)newSuperview {
  if (newSuperview) {
    [[TSAlertViewBase appearanceProxy] alertViewWillShow:self];
    // may need to redo layout
    [self recalcSizeAndLayout:YES];
  }
  [super willMoveToSuperview:newSuperview];
}

- (void) willMoveToWindow:(UIWindow *)newWindow {
  [[TSAlertViewBase appearanceProxy] alertView:self addedToWindow:newWindow];
  [super willMoveToWindow:newWindow];
}

- (void) show { [ALERT_CONTROLLER push:self animated:YES]; }

- (void) dismiss { [self dismissAnimated:YES]; }

- (BOOL) isVisible { return self.superview != nil; }

- (void) dismissAnimated:(BOOL) animated {
  [ALERT_CONTROLLER pop:self 
            buttonIndex:0 
               animated:animated];
}

#pragma mark

- (id) init {
	if ( ( self = [super init] ) ) {
		[self TSAlertView_commonInit];
	}
	return self;
}

- (id) initWithFrame:(CGRect)frame
{
  frame.origin = CGPointZero;
  frame.size = [self sizeThatFits:CGSizeZero];
  frame = CGRectCenterInRect([UIScreen mainScreen].bounds, frame);
  
	if ( ( self = [super initWithFrame: frame] ) )
	{
		[self TSAlertView_commonInit];
		
		if ( !CGRectIsEmpty( frame ) )
		{
      self.layer.shouldRasterize = YES;
		}
	}
	return self;
}

- (CGSize) sizeThatFits: (CGSize) unused { return CGSizeMake(kDefaultWidth, kDefaultHeight); }

- (void) TSAlertView_commonInit
{
	self.backgroundColor = [UIColor clearColor];
	self.autoresizingMask = (
                           UIViewAutoresizingFlexibleLeftMargin | 
                           UIViewAutoresizingFlexibleRightMargin | 
                           UIViewAutoresizingFlexibleTopMargin | 
                           UIViewAutoresizingFlexibleBottomMargin
                           );
  self.clipsToBounds = YES;
}

- (CGSize) recalcSizeAndLayout: (BOOL) layout {
  return [self sizeThatFits:CGSizeZero];
}

- (void) drawRect:(CGRect)rect {
	[self.backgroundImage drawInRect: rect];
}

@end

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#pragma mark -

@implementation TSAlertView

@synthesize delegate=_delegate, imageView=_imageView, width=_width, maxHeight=_maxHeight;
@synthesize cancelButtonIndex=_cancelButtonIndex, buttonLayout=_buttonLayout;
@synthesize firstOtherButtonIndex=_firstOtherButtonIndex, usesMessageTextView=_usesMessageTextView;
@synthesize style=_style, activityIndicatorView=_activityIndicatorView, userInfo=_userInfo;
@synthesize customView = _customView;

- (id) initWithTitle: (NSString *) t 
             message: (NSString *) m 
            delegate: (id) d 
   cancelButtonTitle: (NSString *) cancelButtonTitle 
   otherButtonTitles: (NSString *) otherButtonTitles, ...
{
	if ( (self = [super init] ) ) // will call into initWithFrame, thus TSAlertView_commonInit is called
	{
    if (!UNIT_TESTS_RUNNING) {
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
  }
  
  return self;
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

#pragma mark Sizing

- (void) setWidth:(CGFloat) w {
	if ( w <= 0 )
		w = kDefaultWidth;
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
		h = kDefaultHeight;
	_maxHeight = MIN( h, kDefaultWidth );
}

- (CGFloat) maxHeight {
	if ( nil == self.superview )
		return _maxHeight;
	return MIN( _maxHeight, self.superview.bounds.size.height - 20 );
}

- (CGSize) sizeThatFits: (CGSize) unused {
	CGSize s = [self recalcSizeAndLayout: NO];
	return s;
}

#pragma mark -

- (CGSize) recalcSizeAndLayout: (BOOL) layout
{
  BOOL	stacked = !(self.buttonLayout == TSAlertViewButtonLayoutNormal && [self.buttons count] == 2 );
  
  CGFloat maxWidth = self.width - (kTSAlertView_LeftMargin * 2);
  
  CGSize  imageSize = [self imageSize];
  CGSize  titleLabelSize = [self titleLabelSize];
  CGSize  messageViewSize = [self messageLabelSize];
  CGSize  inputTextFieldSize = [self inputTextFieldSize];
  CGSize  buttonsAreaSize = stacked ? [self buttonsAreaSize_Stacked] : [self buttonsAreaSize_SideBySide];
  
  // accessories
  UIView *accessory = nil;
  CGSize accessorySize = CGSizeZero;
  CGFloat accessoryHeight = 0;
  CGFloat accessoryWidth = 0;
  switch (self.style) {
    case TSAlertViewStyleInput:
      accessory = self.inputTextField;
      accessorySize = inputTextFieldSize;
      accessoryHeight = accessorySize.height;
      break;
    case TSAlertViewStyleActivityView:
      accessory = self.activityIndicatorView;
      accessorySize = self.activityIndicatorView.frame.size;
      accessoryHeight = accessorySize.height + kTSAlertView_RowMargin / 2;
      break;
    case TSAlertViewStyleCustomView:
      NSAssert(nil != self.customView, @"The custom alert style must have a custom view associated with it!");
      accessory = self.customView;
      accessorySize = self.customView.frame.size;
      accessoryHeight = accessorySize.height + kTSAlertView_RowMargin / 2;
      accessoryWidth = self.customView.frame.size.width;
    default:
      break;
  }
  
  CGFloat totalHeight = 0;
  CGFloat totalWidth = 0;
  if(accessoryWidth > self.width)
  {
    totalWidth = accessoryWidth;
  }
  else
  {
    totalWidth = self.width;
  }
  
  // easier to debug as a big ugly list...
  totalHeight += kTSAlertView_TopMargin;
  totalHeight += imageSize.height + ( imageSize.height ? kTSAlertView_RowMargin : 0 );  // image
  totalHeight += ( titleLabelSize.height ? titleLabelSize.height : 0 );                 // title
  totalHeight += ( imageSize.height || titleLabelSize.height ) ? kTSAlertView_RowMargin : 0;
  totalHeight += ( messageViewSize.height ? messageViewSize.height + kTSAlertView_RowMargin : 0 );
  totalHeight += ( accessorySize.height ? accessoryHeight + kTSAlertView_RowMargin : 0 );
  totalHeight += buttonsAreaSize.height;
  totalHeight += kTSAlertView_BottomMargin;
  
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
    CGFloat y = kTSAlertView_TopMargin;
    
    // image
    if ( self.imageView.image ) {
      self.imageView.frame = CGRectMake(0, y, self.bounds.size.width, imageSize.height);
      [self addSubview:self.imageView];
      y += imageSize.height + kTSAlertView_RowMargin;
    }
    
    // title
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
    
    // buttons
    CGFloat buttonHeight = (
                            [self.buttons count] ? 
                            [[self.buttons objectAtIndex:0] sizeThatFits: CGSizeZero].height :
                            0
                            );
    
    // bottom up
    CGFloat buttonBottom = totalHeight - kTSAlertView_BottomMargin;
    CGFloat buttonTop = buttonBottom - buttonsAreaSize.height;
    
    // centre accessories
    if (accessory) {
      CGRect frame = accessory.frame;
      frame.origin = CGPointMake(totalWidth / 2 - accessorySize.width / 2, 
                                 ( buttonTop - y ) / 2 - accessoryHeight / 2 + y );
      frame.size = accessorySize;
      accessory.frame = frame;
      [self addSubview:accessory];
    }
    
    // do buttons from bottom up
    y = buttonBottom - buttonHeight;
    
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
  
  return CGSizeMake(totalWidth + 10, totalHeight + 10);
}

- (CGSize) imageSize {
  return self.imageView.image.size;
}

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
  
  bs.height = (
               (bs.height * buttonCount) + 
               (kTSAlertView_RowMargin * MAX(0, buttonCount - 1)) +
               ( ( [self.buttons count] > 1 ) * kTSAlertView_RowMargin)  // extra padding about cancel
               );
  
  return bs;
}

- (void) layoutSubviews {
	[self recalcSizeAndLayout: YES];
}

- (void)dealloc {
  [self cleanup];
  
#if __has_feature(objc_arc) == 0
  [_titleLabel release];
  [_messageLabel release];
  [_messageTextView release];
  [_messageTextViewMaskImageView release];
  [_inputTextField release];
  [_buttons release];
  [_imageView release];
  [_backgroundImage release];
  
  [super dealloc];
#endif
}

- (void) TSAlertView_commonInit
{
  [super TSAlertView_commonInit];
  
	self.style = TSAlertViewStyleNormal;
	self.buttonLayout = TSAlertViewButtonLayoutNormal;
	self.cancelButtonIndex = -1;
	_firstOtherButtonIndex = -1;
  
  // defaults:
	self.width = 0; // set to default
	self.maxHeight = 0; // set to default
}

- (void) setStyle:(TSAlertViewStyle)newStyle
{
	if ( self.style != newStyle )
	{
		_style = newStyle;
		
		if ( self.style == TSAlertViewStyleInput )
		{
			// need to watch for keyboard
			[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector( onKeyboardDidShow:) name: UIKeyboardDidShowNotification object: nil];
			[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector( onKeyboardWillHide:) name: UIKeyboardWillHideNotification object: nil];
		}
	}
}

- (void) onKeyboardDidShow: (NSNotification*) note {
  // convert keyboard rect to window coordinates
  CGRect keyRect = [[[note userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];  
  CGRect rect = [[UIScreen mainScreen] bounds];
  CGRect discard;
  
  switch ([[UIApplication sharedApplication] statusBarOrientation]) {
    case UIInterfaceOrientationPortrait:
      CGRectDivide(rect, &rect, &discard, keyRect.origin.y, CGRectMinYEdge);
      break;
    case UIInterfaceOrientationPortraitUpsideDown:
      CGRectDivide(rect, &discard, &rect, keyRect.size.height, CGRectMinYEdge);
      break;
    case UIInterfaceOrientationLandscapeLeft:
      CGRectDivide(rect, &rect, &discard, keyRect.origin.x, CGRectMinXEdge);
      break;
    case UIInterfaceOrientationLandscapeRight:
      CGRectDivide(rect, &discard, &rect, keyRect.size.width, CGRectMinXEdge);
      break;
  }
  
  CGRect viewRect = [self convertRect:rect fromView:nil];
  const CGFloat keyboardPad = 10;
  if ( self.frame.size.height > viewRect.size.height - keyboardPad )
  {
    self.maxHeight = viewRect.size.height - keyboardPad;
    [self sizeToFit];
    [self layoutSubviews];
  }
  
  [UIView animateWithDuration: kAlertBoxAnimDuration 
                   animations: ^{ self.center = CGRectCentrePoint(rect); }];
}

- (void) onKeyboardWillHide: (NSNotification*) note
{
	[UIView animateWithDuration: kAlertBoxAnimDuration 
                   animations: ^{
                     self.center = CGPointMake( CGRectGetMidX( self.superview.bounds ), CGRectGetMidY( self.superview.bounds ));
                     self.frame = CGRectIntegral(self.frame);
                   }];
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
	
  [ALERT_CONTROLLER pop:self 
            buttonIndex:buttonIndex 
               animated:animated];
}

- (void) releaseWindow: (int) buttonIndex
{
	if ( [self.delegate respondsToSelector: @selector(alertView:didDismissWithButtonIndex:)] )
	{
		[self.delegate alertView: self didDismissWithButtonIndex: buttonIndex ];
	}
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

- (UIImageView*) imageView {
  if ( !_imageView ) {
    _imageView = [[UIImageView alloc] init];
    _imageView.contentMode = UIViewContentModeCenter;
  }
  return _imageView;
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

- (void) pulse
{
  if ( self.style == TSAlertViewStyleInput )
  {
    [self layoutSubviews];
    [self.inputTextField becomeFirstResponder];
  }
  
  [super pulse];
}

@end

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#pragma mark -

@implementation TSAlertViewAppearanceProxy

- (void) alertViewWillShow:(TSAlertViewBase*)alertView {
  NSLog(@"Subclass me!");
  [self doesNotRecognizeSelector:_cmd];
}

- (void) alertView:(TSAlertViewBase*)alertView 
     addedToWindow:(UIWindow*)window 
{
  NSLog(@"Subclass me!");
  [self doesNotRecognizeSelector:_cmd];
}

@end



