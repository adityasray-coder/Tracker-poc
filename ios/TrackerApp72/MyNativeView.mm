#import "MyNativeView.h"

#if __has_include("TrackerApp72-Swift.h")
#import "TrackerApp72-Swift.h"
#else
#import <TrackerApp72/TrackerApp72-Swift.h>
#endif

@interface MyNativeView ()
@property (nonatomic, assign) BOOL swiftAttached;
@end

@implementation MyNativeView

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
                          if (strongSelf.onNativeAppear) {
                            strongSelf.onNativeAppear(nil);
                          }
                        }];
}

@end
