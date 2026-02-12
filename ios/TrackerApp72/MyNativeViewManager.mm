#import <React/RCTViewManager.h>
#import "MyNativeView.h"

@interface MyNativeViewManager : RCTViewManager
@end

@implementation MyNativeViewManager

RCT_EXPORT_MODULE(MyNativeView)

- (UIView *)view {
  return [MyNativeView new];
}

RCT_EXPORT_VIEW_PROPERTY(onNativeAppear, RCTDirectEventBlock)

@end
