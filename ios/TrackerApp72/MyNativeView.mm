
#import "MyNativeView.h"
#import <UIKit/UIKit.h>

// Conditional import to handle different Swift header locations depending on build setup
#if __has_include("TrackerApp72-Swift.h")
#import "TrackerApp72-Swift.h"
#else
#import <TrackerApp72/TrackerApp72-Swift.h>
#endif

// KVO context for scroll offset observation
static void *kContentOffsetContext = &kContentOffsetContext;

// Configuration Constants
static const double kVisibilityThreshold = 0.70;   // View must be 70% visible to start timer
static const NSTimeInterval kRequiredDuration = 2.0;  // Must stay visible for 2 seconds
static const double kExitThreshold = 0.10;        // Must drop below 10% visibility to reset state

@interface MyNativeView ()
@property (nonatomic, assign) BOOL swiftAttached;              // Prevents redundant SwiftUI injections
@property (nonatomic, assign) BOOL hasFiredViewportAppear;     // Tracks if an impression was already sent
@property (nonatomic, weak) UIScrollView *observedScrollView;  // Immediate parent scroll (usually horizontal)
@property (nonatomic, weak) UIScrollView *observedVerticalScrollView; // Outer parent scroll (vertical)
@property (nonatomic, strong) NSTimer *visibilityDurationTimer; // 2s countdown timer
@end

@implementation MyNativeView

/**
 * Standard Cleanup: Stop timers and remove KVO observers to prevent memory leaks or crashes
 * when the view is removed from the hierarchy.
 */
- (void)dealloc {
  NSLog(@"[MyNativeView] dealloc");
  [_visibilityDurationTimer invalidate];
  _visibilityDurationTimer = nil;
  
  if (_observedScrollView) {
    [_observedScrollView removeObserver:self forKeyPath:@"contentOffset" context:kContentOffsetContext];
    _observedScrollView = nil;
  }
  if (_observedVerticalScrollView) {
    [_observedVerticalScrollView removeObserver:self forKeyPath:@"contentOffset" context:kContentOffsetContext];
    _observedVerticalScrollView = nil;
  }
}

/**
 * Traverses up the view hierarchy to find the nearest parent UIScrollView.
 * Typically finds the horizontal 'Shelf' in most feed layouts.
 */
- (UIScrollView *)findScrollView {
  UIView *v = self.superview;
  while (v) {
    if ([v isKindOfClass:[UIScrollView class]]) {
      return (UIScrollView *)v;
    }
    v = v.superview;
  }
  return nil;
}

/**
 * Traverses up the hierarchy starting from a specific view to find a parent UIScrollView.
 * Used to find the outer vertical scroll view (Main Feed) above the horizontal shelf.
 */
- (UIScrollView *)findScrollViewAboveView:(UIView *)view {
  UIView *v = view.superview;
  while (v) {
    if ([v isKindOfClass:[UIScrollView class]]) {
      NSLog(@"[MyNativeView] findScrollViewAboveView:%@ -> found %@", view, v);
      return (UIScrollView *)v;
    }
    v = v.superview;
  }
  return nil;
}

/**
 * The core visibility engine.
 * Calculates what percentage of the view is currently visible to the user,
 * considering both the scroll view's bounds and the physical screen (window) bounds.
 */
- (double)visibleRatioInViewport {
  UIWindow *window = self.window;
  if (!window) return 0.0; // Not on screen

  UIScrollView *scrollView = [self findScrollView];
  if (!scrollView) return 0.0;

  // Assumes content is inside a container or the first subview of the scrollview
  UIView *contentView = scrollView.subviews.firstObject;
  if (!contentView) return 0.0;

  // Calculate the total area of this view
  CGRect myFrameInContent = [self convertRect:self.bounds toView:contentView];
  CGFloat viewArea = myFrameInContent.size.width * myFrameInContent.size.height;
  if (viewArea <= 0) return 0.0;

  // 1. Calculate intersection with the scroll view's visible port
  CGRect visibleRect = CGRectMake(
      scrollView.contentOffset.x,
      scrollView.contentOffset.y,
      scrollView.bounds.size.width,
      scrollView.bounds.size.height);
  CGRect intersection = CGRectIntersection(visibleRect, myFrameInContent);
  if (CGRectIsNull(intersection)) return 0.0;
  CGFloat visibleInScroll = intersection.size.width * intersection.size.height;

  // 2. Calculate intersection with the physical window (screen bounds)
  CGRect myFrameInWindow = [self convertRect:self.bounds toView:window];
  CGRect windowBounds = window.bounds;
  CGRect onScreenIntersection = CGRectIntersection(myFrameInWindow, windowBounds);
  if (CGRectIsNull(onScreenIntersection)) return 0.0;
  CGFloat visibleOnScreen = onScreenIntersection.size.width * onScreenIntersection.size.height;

  // Use the smaller of the two ratios (it must be in the scroll port AND on screen)
  double ratioInScroll = (double)(visibleInScroll / viewArea);
  double ratioOnScreen = (double)(visibleOnScreen / viewArea);
  double ratio = ratioInScroll < ratioOnScreen ? ratioInScroll : ratioOnScreen;

  NSLog(@"[MyNativeView] visibleRatioInViewport -> %.2f", ratio);
  return ratio;
}

/**
 * Final execution of the appear event.
 * Called after the 2-second timer successfully completes.
 */
- (void)fireAppearIfNeeded {
  if (_hasFiredViewportAppear) return;

  _hasFiredViewportAppear = YES; // Mark as fired for this 'entry'
  [_visibilityDurationTimer invalidate];
  _visibilityDurationTimer = nil;

  // Trigger the React Native / Swift callback
  if (_onNativeAppear) {
    _onNativeAppear(nil);
  }
}

/**
 * Orchestrates the 'Hysteresis' (Buffer) logic.
 * - If > 70%: Starts timer to fire impression.
 * - If < 10%: Resets state so the view can be tracked again.
 * - Between 10-70%: Does nothing (Neutral Zone to prevent flickering).
 */
- (void)checkVisibilityAndUpdateTimer {
  double ratio = [self visibleRatioInViewport];

  // LOGIC 1: VIEW IS VISIBLE ENOUGH TO TRACK
  if (ratio >= kVisibilityThreshold) {
    if (_hasFiredViewportAppear) return; // Already tracked, wait for exit

    // If we aren't already counting down, start the 2s timer
    if (!_visibilityDurationTimer) {
      NSLog(@"[MyNativeView] Threshold met (%.2f). Starting timer.", ratio);
      __weak __typeof(self) weakSelf = self;
      _visibilityDurationTimer = [NSTimer scheduledTimerWithTimeInterval:kRequiredDuration
                                                                  repeats:NO
                                                                    block:^(NSTimer * _Nonnull timer) {
        [weakSelf fireAppearIfNeeded];
      }];
      // Ensure timer runs even during scrolling
      [[NSRunLoop mainRunLoop] addTimer:_visibilityDurationTimer forMode:NSRunLoopCommonModes];
    }
  } 
  // LOGIC 2: VIEW HAS EXITED THE VIEWPORT (Below 10%)
  else if (ratio < kExitThreshold) {
    // Cancel any pending timer if they scrolled away before 2s
    if (_visibilityDurationTimer) {
      NSLog(@"[MyNativeView] Left threshold before 2s elapsed. Timer cancelled.");
      [_visibilityDurationTimer invalidate];
      _visibilityDurationTimer = nil;
    }

    // THE BUFFER RESET: Re-arm the view to track a brand new impression
    if (_hasFiredViewportAppear) {
      NSLog(@"[MyNativeView] View exited (%.2f). Re-arming for next impression.", ratio);
      _hasFiredViewportAppear = NO;
    }
  }
  // LOGIC 3: NEUTRAL ZONE (Avoids 'flickering' between 10% and 70%)
  else {
    if (!_hasFiredViewportAppear && _visibilityDurationTimer) {
        // If they drop below 70% but stay above 10%, we pause the timer
        [_visibilityDurationTimer invalidate];
        _visibilityDurationTimer = nil;
    }
  }
}

/**
 * KVO Observer: Listens for contentOffset changes in parent scroll views.
 * Every time the user scrolls, we re-check visibility.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if (context == kContentOffsetContext && [keyPath isEqualToString:@"contentOffset"]) {
    __weak __typeof(self) weakSelf = self;
    // Dispatch to main queue to ensure UI calculations are accurate
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf checkVisibilityAndUpdateTimer];
    });
    return;
  }
  [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

/**
 * Called when the internal SwiftUI bridge signals the view is ready.
 * Initializes KVO observers for both horizontal and vertical scrolling.
 */
- (void)whenSwiftAppearFires {
  NSLog(@"[MyNativeView] whenSwiftAppearFires");
  if (!_onNativeAppear) return;
  
  [self checkVisibilityAndUpdateTimer];
  
  // Set up horizontal scroll observer
  UIScrollView *scrollView = [self findScrollView];
  if (scrollView && !_observedScrollView) {
    _observedScrollView = scrollView;
    [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:kContentOffsetContext];
  }
  
  // Set up vertical scroll observer (the parent feed)
  UIScrollView *verticalScrollView = [self findScrollViewAboveView:scrollView ?: self];
  if (verticalScrollView && verticalScrollView != scrollView && !_observedVerticalScrollView) {
    _observedVerticalScrollView = verticalScrollView;
    [verticalScrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:kContentOffsetContext];
  }
}

/**
 * React Native Prop Setter: Triggers SwiftUI attachment when the callback is provided.
 */
- (void)setOnNativeAppear:(RCTDirectEventBlock)onNativeAppear {
  _onNativeAppear = onNativeAppear;
  if (onNativeAppear && !_swiftAttached && self.bounds.size.width > 0) {
    [self attachSwiftUIIfNeeded];
  }
}

/**
 * UIKit Lifecycle: Ensures SwiftUI is attached once the view has a valid size.
 */
- (void)layoutSubviews {
  [super layoutSubviews];
  if (_onNativeAppear && !_swiftAttached && self.bounds.size.width > 0) {
    [self attachSwiftUIIfNeeded];
  }
  // Perform a visibility check on layout to catch views already on screen at start
  if (_onNativeAppear && _observedScrollView && !_hasFiredViewportAppear) {
    [self checkVisibilityAndUpdateTimer];
  }
}

/**
 * Bridges the UIKit container with the SwiftUI content.
 * Prevents multiple attachments via the _swiftAttached flag.
 */
- (void)attachSwiftUIIfNeeded {
  if (_swiftAttached) return;
  
  _swiftAttached = YES;
  __weak __typeof(self) weakSelf = self;
  [MyNativeViewBridge attachSwiftUITo:self
                        onAppearBlock:^{
                          __strong __typeof(weakSelf) strongSelf = weakSelf;
                          if (strongSelf) {
                            [strongSelf whenSwiftAppearFires];
                          }
                        }];
}

@end