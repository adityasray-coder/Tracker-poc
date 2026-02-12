#import "MyNativeView.h"
#import <UIKit/UIKit.h>

#if __has_include("TrackerApp72-Swift.h")
#import "TrackerApp72-Swift.h"
#else
#import <TrackerApp72/TrackerApp72-Swift.h>
#endif

static void *kContentOffsetContext = &kContentOffsetContext;

@interface MyNativeView ()
@property (nonatomic, assign) BOOL swiftAttached;
@property (nonatomic, assign) BOOL hasFiredViewportAppear;
@property (nonatomic, weak) UIScrollView *observedScrollView;
@end

@implementation MyNativeView

- (void)dealloc {
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

- (BOOL)isInViewport {
  UIScrollView *scrollView = [self findScrollView];
  if (!scrollView) return YES;
  UIView *contentView = scrollView.subviews.firstObject;
  if (!contentView) return YES;
  CGRect myFrameInContent = [self convertRect:self.bounds toView:contentView];
  CGRect visibleRect = CGRectMake(
      scrollView.contentOffset.x,
      scrollView.contentOffset.y,
      scrollView.bounds.size.width,
      scrollView.bounds.size.height);
  return CGRectIntersectsRect(visibleRect, myFrameInContent);
}

- (void)checkVisibilityAndFireIfNeeded {
  if (_hasFiredViewportAppear || !_onNativeAppear) return;
  if (![self isInViewport]) return;

  _hasFiredViewportAppear = YES;
  if (_observedScrollView) {
    [_observedScrollView removeObserver:self forKeyPath:@"contentOffset" context:kContentOffsetContext];
    _observedScrollView = nil;
  }
  _onNativeAppear(nil);
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if (context == kContentOffsetContext && [keyPath isEqualToString:@"contentOffset"]) {
    [self checkVisibilityAndFireIfNeeded];
    return;
  }
  [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)whenSwiftAppearFires {
  if (!_onNativeAppear) return;
  [self checkVisibilityAndFireIfNeeded];
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
