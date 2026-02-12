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

@interface MyNativeView ()
@property (nonatomic, assign) BOOL swiftAttached;
@property (nonatomic, assign) BOOL hasFiredViewportAppear;
@property (nonatomic, weak) UIScrollView *observedScrollView;
@property (nonatomic, strong) NSTimer *visibilityDurationTimer;
@end

@implementation MyNativeView

- (void)dealloc {
  [_visibilityDurationTimer invalidate];
  _visibilityDurationTimer = nil;
  if (_observedScrollView) {
    [_observedScrollView removeObserver:self forKeyPath:@"contentOffset" context:kContentOffsetContext];
    _observedScrollView = nil;
  }
}

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

/// Returns the fraction of this view that is visible within the scroll viewport (0.0 to 1.0). Returns 1.0 if no scroll view.
- (double)visibleRatioInViewport {
  UIScrollView *scrollView = [self findScrollView];
  if (!scrollView) return 1.0;
  UIView *contentView = scrollView.subviews.firstObject;
  if (!contentView) return 1.0;
  CGRect myFrameInContent = [self convertRect:self.bounds toView:contentView];
  CGRect visibleRect = CGRectMake(
      scrollView.contentOffset.x,
      scrollView.contentOffset.y,
      scrollView.bounds.size.width,
      scrollView.bounds.size.height);
  CGRect intersection = CGRectIntersection(visibleRect, myFrameInContent);
  if (CGRectIsNull(intersection)) return 0.0;
  CGFloat viewArea = myFrameInContent.size.width * myFrameInContent.size.height;
  if (viewArea <= 0) return 0.0;
  CGFloat visibleArea = intersection.size.width * intersection.size.height;
  return (double)(visibleArea / viewArea);
}

- (void)fireAppearIfNeeded {
  if (_hasFiredViewportAppear || !_onNativeAppear) return;

  _hasFiredViewportAppear = YES;
  [_visibilityDurationTimer invalidate];
  _visibilityDurationTimer = nil;
  if (_observedScrollView) {
    [_observedScrollView removeObserver:self forKeyPath:@"contentOffset" context:kContentOffsetContext];
    _observedScrollView = nil;
  }
  _onNativeAppear(nil);
}

- (void)checkVisibilityAndUpdateTimer {
  if (_hasFiredViewportAppear || !_onNativeAppear) return;

  double ratio = [self visibleRatioInViewport];

  if (ratio >= kVisibilityThreshold) {
    if (!_visibilityDurationTimer) {
      __weak __typeof(self) weakSelf = self;
      _visibilityDurationTimer = [NSTimer scheduledTimerWithTimeInterval:kRequiredDuration
                                                                  repeats:NO
                                                                    block:^(NSTimer * _Nonnull timer) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
          [strongSelf fireAppearIfNeeded];
        }
      }];
      [[NSRunLoop mainRunLoop] addTimer:_visibilityDurationTimer forMode:NSRunLoopCommonModes];
    }
  } else {
    [_visibilityDurationTimer invalidate];
    _visibilityDurationTimer = nil;
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if (context == kContentOffsetContext && [keyPath isEqualToString:@"contentOffset"]) {
    [self checkVisibilityAndUpdateTimer];
    return;
  }
  [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)whenSwiftAppearFires {
  if (!_onNativeAppear) return;
  [self checkVisibilityAndUpdateTimer];
  if (_hasFiredViewportAppear) return;
  UIScrollView *scrollView = [self findScrollView];
  if (scrollView && !_observedScrollView) {
    _observedScrollView = scrollView;
    [scrollView addObserver:self
                 forKeyPath:@"contentOffset"
                    options:NSKeyValueObservingOptionNew
                    context:kContentOffsetContext];
  }
}

- (void)setOnNativeAppear:(RCTDirectEventBlock)onNativeAppear {
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
}

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
