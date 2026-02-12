#import "MyNativeView.h"
#import <UIKit/UIKit.h>

#if __has_include("TrackerApp72-Swift.h")
#import "TrackerApp72-Swift.h"
#else
#import <TrackerApp72/TrackerApp72-Swift.h>
#endif

static void *kContentOffsetContext = &kContentOffsetContext;
static const double kVisibilityThreshold = 0.70;   // 70% of card must be visible
static const NSTimeInterval kRequiredDuration = 2.0;  // 2 seconds
static const double kExitThreshold = 0.10; 


@interface MyNativeView ()
@property (nonatomic, assign) BOOL swiftAttached;
@property (nonatomic, assign) BOOL hasFiredViewportAppear;
@property (nonatomic, weak) UIScrollView *observedScrollView;
@property (nonatomic, weak) UIScrollView *observedVerticalScrollView;
@property (nonatomic, strong) NSTimer *visibilityDurationTimer;
@end

@implementation MyNativeView

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

- (UIScrollView *)findScrollView {
  UIView *v = self.superview;
  while (v) {
    if ([v isKindOfClass:[UIScrollView class]]) {
      // NSLog(@"[MyNativeView] findScrollView -> found %@", v);
      return (UIScrollView *)v;
    }
    v = v.superview;
  }
  // NSLog(@"[MyNativeView] findScrollView -> nil");
  return nil;
}

/// Find the next scroll view above the given view (for outer/vertical scroll view).
- (UIScrollView *)findScrollViewAboveView:(UIView *)view {
  UIView *v = view.superview;
  while (v) {
    if ([v isKindOfClass:[UIScrollView class]]) {
      NSLog(@"[MyNativeView] findScrollViewAboveView:%@ -> found %@", view, v);
      return (UIScrollView *)v;
    }
    v = v.superview;
  }
  NSLog(@"[MyNativeView] findScrollViewAboveView:%@ -> nil", view);
  return nil;
}

/// Returns the fraction of this view that is visible: (1) within the horizontal scroll viewport and (2) actually on screen (window). Returns 0.0 if off-screen or no scroll view.
- (double)visibleRatioInViewport {
  UIWindow *window = self.window;
  if (!window) {
    // NSLog(@"[MyNativeView] visibleRatioInViewport -> 0.0 (no window)");
    return 0.0;
  }

  UIScrollView *scrollView = [self findScrollView];
  if (!scrollView) {
    // NSLog(@"[MyNativeView] visibleRatioInViewport -> 0.0 (no scrollView)");
    return 0.0;
  }
  UIView *contentView = scrollView.subviews.firstObject;
  if (!contentView) {
    // NSLog(@"[MyNativeView] visibleRatioInViewport -> 0.0 (no contentView)");
    return 0.0;
  }
  CGRect myFrameInContent = [self convertRect:self.bounds toView:contentView];
  CGFloat viewArea = myFrameInContent.size.width * myFrameInContent.size.height;
  if (viewArea <= 0) {
    // NSLog(@"[MyNativeView] visibleRatioInViewport -> 0.0 (viewArea<=0)");
    return 0.0;
  }

  CGRect visibleRect = CGRectMake(
      scrollView.contentOffset.x,
      scrollView.contentOffset.y,
      scrollView.bounds.size.width,
      scrollView.bounds.size.height);
  CGRect intersection = CGRectIntersection(visibleRect, myFrameInContent);
  if (CGRectIsNull(intersection)) {
    // NSLog(@"[MyNativeView] visibleRatioInViewport -> 0.0 (null intersection in scroll)");
    return 0.0;
  }
  CGFloat visibleInScroll = intersection.size.width * intersection.size.height;

  CGRect myFrameInWindow = [self convertRect:self.bounds toView:window];
  CGRect windowBounds = window.bounds;
  CGRect onScreenIntersection = CGRectIntersection(myFrameInWindow, windowBounds);
  if (CGRectIsNull(onScreenIntersection)) {
    // NSLog(@"[MyNativeView] visibleRatioInViewport -> 0.0 (null intersection on screen)");
    return 0.0;
  }
  CGFloat visibleOnScreen = onScreenIntersection.size.width * onScreenIntersection.size.height;

  double ratioInScroll = (double)(visibleInScroll / viewArea);
  double ratioOnScreen = (double)(visibleOnScreen / viewArea);
  double ratio = ratioInScroll < ratioOnScreen ? ratioInScroll : ratioOnScreen;
  NSLog(@"[MyNativeView] visibleRatioInViewport -> %.2f (inScroll=%.2f onScreen=%.2f)", ratio, ratioInScroll, ratioOnScreen);
  return ratio;
}


- (void)fireAppearIfNeeded {
  if (_hasFiredViewportAppear) return;

  _hasFiredViewportAppear = YES;
  [_visibilityDurationTimer invalidate];
  _visibilityDurationTimer = nil;

  if (_onNativeAppear) {
    _onNativeAppear(nil);
  }
}



- (void)checkVisibilityAndUpdateTimer {
  double ratio = [self visibleRatioInViewport];

  // 1. CHECK FOR IMPRESSION TRIGGER (70%+)
  if (ratio >= kVisibilityThreshold) {
    if (_hasFiredViewportAppear) {
      // Already tracked this time; do nothing until they scroll away
      return;
    }

    if (!_visibilityDurationTimer) {
      NSLog(@"[MyNativeView] Threshold met (%.2f). Starting timer.", ratio);
      __weak __typeof(self) weakSelf = self;
      _visibilityDurationTimer = [NSTimer scheduledTimerWithTimeInterval:kRequiredDuration
                                                                  repeats:NO
                                                                    block:^(NSTimer * _Nonnull timer) {
        [weakSelf fireAppearIfNeeded];
      }];
      [[NSRunLoop mainRunLoop] addTimer:_visibilityDurationTimer forMode:NSRunLoopCommonModes];
    }
  } 
  // 2. CHECK FOR RESET (Below 10%)
  else if (ratio < kExitThreshold) {
    // If the timer was running but they scrolled away too fast, cancel it
    if (_visibilityDurationTimer) {
      NSLog(@"[MyNativeView] Left threshold before 2s elapsed. Timer cancelled.");
      [_visibilityDurationTimer invalidate];
      _visibilityDurationTimer = nil;
    }

    // This is the Hysteresis: Only reset 'hasFired' once it's mostly gone
    if (_hasFiredViewportAppear) {
      NSLog(@"[MyNativeView] View exited (%.2f). Re-arming for next impression.", ratio);
      _hasFiredViewportAppear = NO;
    }
  }
  // 3. NEUTRAL ZONE (10% - 69%)
  else {
    // If they are in the middle, we don't trigger NEW impressions, 
    // and we don't RESET old ones. We just stay in the current state.
    if (!_hasFiredViewportAppear && _visibilityDurationTimer) {
        NSLog(@"[MyNativeView] Dropped into neutral zone. Cancelling pending timer.");
        [_visibilityDurationTimer invalidate];
        _visibilityDurationTimer = nil;
    }
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if (context == kContentOffsetContext && [keyPath isEqualToString:@"contentOffset"]) {
    NSLog(@"[MyNativeView] observeValueForKeyPath contentOffset, dispatching checkVisibilityAndUpdateTimer");
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf checkVisibilityAndUpdateTimer];
    });
    return;
  }
  [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)whenSwiftAppearFires {
  NSLog(@"[MyNativeView] whenSwiftAppearFires");
  if (!_onNativeAppear) return;
  [self checkVisibilityAndUpdateTimer];
  if (_hasFiredViewportAppear) {
    NSLog(@"[MyNativeView] whenSwiftAppearFires hasFired already, skipping observer setup");
    return;
  }
  UIScrollView *scrollView = [self findScrollView];
  if (scrollView && !_observedScrollView) {
    _observedScrollView = scrollView;
    [scrollView addObserver:self
                 forKeyPath:@"contentOffset"
                    options:NSKeyValueObservingOptionNew
                    context:kContentOffsetContext];
    NSLog(@"[MyNativeView] whenSwiftAppearFires added horizontal scroll observer");
  }
  UIScrollView *verticalScrollView = [self findScrollViewAboveView:scrollView ?: self];
  if (verticalScrollView && verticalScrollView != scrollView && !_observedVerticalScrollView) {
    _observedVerticalScrollView = verticalScrollView;
    [verticalScrollView addObserver:self
                         forKeyPath:@"contentOffset"
                            options:NSKeyValueObservingOptionNew
                            context:kContentOffsetContext];
    NSLog(@"[MyNativeView] whenSwiftAppearFires added vertical scroll observer");
  }
}

- (void)setOnNativeAppear:(RCTDirectEventBlock)onNativeAppear {
  NSLog(@"[MyNativeView] setOnNativeAppear (callback=%d)", onNativeAppear != nil);
  _onNativeAppear = onNativeAppear;
  if (onNativeAppear && !_swiftAttached && self.bounds.size.width > 0) {
    [self attachSwiftUIIfNeeded];
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  if (_onNativeAppear && !_swiftAttached && self.bounds.size.width > 0) {
    [self attachSwiftUIIfNeeded];
  }
  if (_onNativeAppear && _observedScrollView && !_hasFiredViewportAppear) {
    NSLog(@"[MyNativeView] layoutSubviews calling checkVisibilityAndUpdateTimer");
    [self checkVisibilityAndUpdateTimer];
  }
}

- (void)attachSwiftUIIfNeeded {
  if (_swiftAttached) {
    NSLog(@"[MyNativeView] attachSwiftUIIfNeeded skipped (already attached)");
    return;
  }
  NSLog(@"[MyNativeView] attachSwiftUIIfNeeded attaching SwiftUI");
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
