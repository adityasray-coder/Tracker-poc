#import <UIKit/UIKit.h>

@class MyNativeView;

/**
 * Centralized singleton that manages impression tracking for all MyNativeView instances.
 * Instead of each view independently observing scroll views via KVO, this tracker
 * observes each scroll view exactly once and batch-computes visibility for all
 * registered views in a single loop per scroll frame.
 */
@interface ImpressionTracker : NSObject

+ (instancetype)shared;

/// Register a view to be tracked. The tracker will automatically
/// discover and observe its parent scroll views.
- (void)registerView:(MyNativeView *)view;

/// Unregister a view (call on dealloc or when tracking is no longer needed).
- (void)unregisterView:(MyNativeView *)view;

@end
