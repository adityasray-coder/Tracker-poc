
#import "MyNativeView.h"
#import "ImpressionTracker.h"
#import <UIKit/UIKit.h>

// Conditional import to handle different Swift header locations depending on build setup
#if __has_include("TrackerApp72-Swift.h")
#import "TrackerApp72-Swift.h"
#else
#import <TrackerApp72/TrackerApp72-Swift.h>
#endif

@interface MyNativeView ()
@property (nonatomic, assign) BOOL swiftAttached; // Prevents redundant SwiftUI injections
@end

@implementation MyNativeView

/**
 * Cleanup: Unregister from the centralized ImpressionTracker.
 */
- (void)dealloc {
  NSLog(@"[MyNativeView] dealloc");
  [[ImpressionTracker shared] unregisterView:self];
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
}

/**
 * Called when the internal SwiftUI bridge signals the view is ready.
 * Registers with the centralized ImpressionTracker for visibility tracking.
 */
- (void)whenSwiftAppearFires {
  NSLog(@"[MyNativeView] whenSwiftAppearFires");
  if (!_onNativeAppear) return;

  [[ImpressionTracker shared] registerView:self];
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
