#import "ImpressionTracker.h"
#import "MyNativeView.h"
#import <UIKit/UIKit.h>
#import <React/UIView+React.h>

/**
 * Key-Value Observing context. 
 * Used to distinguish our scroll observations from others in the same class.
 */
static void *kCentralContentOffsetContext = &kCentralContentOffsetContext;

// Business logic constants for "What counts as a view?"
static const double kVisibilityThreshold = 0.70;      // 70% of view must be visible to start the timer
static const NSTimeInterval kRequiredDuration = 2.0;   // View must remain visible for 2 continuous seconds
static const double kExitThreshold = 0.10;             // Reset the impression state if visibility drops below 10%

#pragma mark - TrackedViewState

/**
 * A private helper class that encapsulates the lifecycle state of a specific MyNativeView.
 * This keeps the logic out of the View class itself.
 */
@interface TrackedViewState : NSObject
@property (nonatomic, weak) MyNativeView *view;             // Weak reference to prevent retain cycles with UI
@property (nonatomic, assign) BOOL hasFiredViewportAppear;  // Prevents multiple firings for one impression
@property (nonatomic, strong) NSTimer *visibilityDurationTimer; // The 2-second countdown timer
@end

@implementation TrackedViewState
- (void)dealloc {
    NSLog(@"[ImpressionTracker] Deallocating TrackedViewState for node: %@", _view.reactTag);
    [_visibilityDurationTimer invalidate]; // Clean up timer when the view state is destroyed
}
@end

#pragma mark - ImpressionTracker

@interface ImpressionTracker ()
/**
 * NSMapTable with [Weak -> Strong] configuration.
 * If the MyNativeView is deallocated by the UI, this entry automatically vanishes.
 */
@property (nonatomic, strong) NSMapTable<MyNativeView *, TrackedViewState *> *trackedViews;

/**
 * NSHashTable with [Weak] objects.
 * Holds references to parent scroll views without keeping them alive.
 */
@property (nonatomic, strong) NSHashTable<UIScrollView *> *observedScrollViews;
@end

@implementation ImpressionTracker

/**
 * Singleton Pattern: Ensures one centralized tracker manages all views.
 */
+ (instancetype)shared {
    static ImpressionTracker *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ImpressionTracker alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSLog(@"[ImpressionTracker] Initializing Singleton");
        _trackedViews = [NSMapTable weakToStrongObjectsMapTable];
        _observedScrollViews = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

#pragma mark - Registration

/**
 * Adds a view to the tracking system. Usually called from the View's 'didMoveToWindow'.
 */
- (void)registerView:(MyNativeView *)view {
    NSLog(@"[ImpressionTracker] registerView called for node: %@", view.reactTag);
    
    // Safety check: Don't register the same view twice
    if ([self.trackedViews objectForKey:view]) {
        NSLog(@"[ImpressionTracker] Node %@ is already registered. Skipping.", view.reactTag);
        return;
    }

    // Initialize the state container for this view
    TrackedViewState *state = [TrackedViewState new];
    state.view = view;
    [self.trackedViews setObject:state forKey:view];

    // 1. Find all parent scroll views to listen for movement
    [self ensureObservingScrollViewsForView:view];
    
    // 2. Immediate check in case the view is already on screen
    [self checkVisibilityForView:view state:state];
}

/**
 * Removes a view from tracking. Usually called from the View's 'willMoveToWindow:nil'.
 */
- (void)unregisterView:(MyNativeView *)view {
    NSLog(@"[ImpressionTracker] unregisterView called for node: %@", view.reactTag);
    TrackedViewState *state = [self.trackedViews objectForKey:view];
    if (state) {
        if (state.visibilityDurationTimer) {
            NSLog(@"[ImpressionTracker] Invalidating active timer during unregistration for node: %@", view.reactTag);
            [state.visibilityDurationTimer invalidate];
            state.visibilityDurationTimer = nil;
        }
    }
    [self.trackedViews removeObjectForKey:view];
    
    // Cleanup: Stop observing scroll views that no longer contain any tracked items
    [self cleanupUnusedScrollViewObservers];
}

#pragma mark - Scroll View Discovery & KVO

/**
 * Walks up the view hierarchy to find every UIScrollView that could affect this view's visibility.
 */
- (void)ensureObservingScrollViewsForView:(UIView *)view {
    NSLog(@"[ImpressionTracker] Scanning hierarchy for scroll views from node: %@", view.reactTag);
    UIView *current = view.superview;
    while (current) {
        if ([current isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)current;
            // Only add KVO if we aren't already watching this specific scroll view
            if (![self.observedScrollViews containsObject:scrollView]) {
                [self.observedScrollViews addObject:scrollView];
                [scrollView addObserver:self
                             forKeyPath:@"contentOffset"
                                options:NSKeyValueObservingOptionNew
                                context:kCentralContentOffsetContext];
                NSLog(@"[ImpressionTracker] New ScrollView detected. Now observing: %@", scrollView);
            }
        }
        current = current.superview;
    }
}

/**
 * Performance Optimization: Stops KVO on scroll views that are no longer "parents" 
 * of any currently registered views.
 */
- (void)cleanupUnusedScrollViewObservers {
    NSLog(@"[ImpressionTracker] Running cleanup for unused scroll observers...");
    NSMutableArray<UIScrollView *> *toRemove = [NSMutableArray array];

    for (UIScrollView *scrollView in self.observedScrollViews) {
        if (!scrollView) continue;

        BOOL hasTrackedDescendant = NO;
        for (MyNativeView *view in self.trackedViews.keyEnumerator) {
            if (view && [view isDescendantOfView:scrollView]) {
                hasTrackedDescendant = YES;
                break;
            }
        }

        if (!hasTrackedDescendant) {
            [toRemove addObject:scrollView];
        }
    }

    for (UIScrollView *scrollView in toRemove) {
        NSLog(@"[ImpressionTracker] Removing KVO observer from unused scroll view: %@", scrollView);
        [scrollView removeObserver:self forKeyPath:@"contentOffset" context:kCentralContentOffsetContext];
        [self.observedScrollViews removeObject:scrollView];
    }
}

#pragma mark - KVO Handler

/**
 * Fired whenever a user scrolls. 
 * Dispatches a batch check to see which views became visible/hidden.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (context == kCentralContentOffsetContext) {
        // Debounce/Batch: Move to the main queue to process visibility once per frame
        dispatch_async(dispatch_get_main_queue(), ^{
            [self checkAllTrackedViews];
        });
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - Batch Visibility Check

/**
 * Iterates through all registered views to update their visibility state.
 */
- (void)checkAllTrackedViews {
    for (MyNativeView *view in self.trackedViews.keyEnumerator) {
        TrackedViewState *state = [self.trackedViews objectForKey:view];
        if (view && state) {
            [self checkVisibilityForView:view state:state];
        }
    }
}

#pragma mark - Visibility Calculation

/**
 * Geometric Math: Calculates the percentage of the view visible to the user.
 * It considers both the ScrollView's clipping bounds and the Screen's bounds.
 */
- (double)visibleRatioForView:(UIView *)view {
    UIWindow *window = view.window;
    if (!window) return 0.0;

    UIScrollView *scrollView = [self nearestScrollViewForView:view];
    if (!scrollView) return 0.0;

    // We assume the first subview of the scrollview is the 'Content View' container
    UIView *contentView = scrollView.subviews.firstObject;
    if (!contentView) return 0.0;

    // 1. Get view's rect relative to the scrollable content area
    CGRect myFrameInContent = [view convertRect:view.bounds toView:contentView];
    CGFloat viewArea = myFrameInContent.size.width * myFrameInContent.size.height;
    if (viewArea <= 0) return 0.0;

    // 2. Intersect with the ScrollView's visible viewport
    CGRect visibleRect = CGRectMake(scrollView.contentOffset.x, scrollView.contentOffset.y,
                                    scrollView.bounds.size.width, scrollView.bounds.size.height);
    CGRect intersection = CGRectIntersection(visibleRect, myFrameInContent);
    if (CGRectIsNull(intersection)) return 0.0;
    CGFloat visibleInScroll = intersection.size.width * intersection.size.height;

    // 3. Intersect with the physical Window (in case it's clipped by a notch or overlay)
    CGRect myFrameInWindow = [view convertRect:view.bounds toView:window];
    CGRect onScreenIntersection = CGRectIntersection(myFrameInWindow, window.bounds);
    if (CGRectIsNull(onScreenIntersection)) return 0.0;
    CGFloat visibleOnScreen = onScreenIntersection.size.width * onScreenIntersection.size.height;

    // The result is the smaller of the two intersections (must be in scroll bounds AND on screen)
    double ratio = fmin((double)(visibleInScroll / viewArea), (double)(visibleOnScreen / viewArea));
    return ratio;
}

- (UIScrollView *)nearestScrollViewForView:(UIView *)view {
    UIView *current = view.superview;
    while (current) {
        if ([current isKindOfClass:[UIScrollView class]]) return (UIScrollView *)current;
        current = current.superview;
    }
    return nil;
}

#pragma mark - Hysteresis State Machine

/**
 * The core logic loop. Decides if we should start a timer, fire an event, or reset.
 */
- (void)checkVisibilityForView:(MyNativeView *)view state:(TrackedViewState *)state {
    double ratio = [self visibleRatioForView:view];

    // CASE 1: View is visible enough to start counting
    if (ratio >= kVisibilityThreshold) {
        if (state.hasFiredViewportAppear) return; // Already counted for this impression cycle

        if (!state.visibilityDurationTimer) {
            NSLog(@"[ImpressionTracker] Node %@ reached %.0f%% visibility. Starting 2s timer.", view.reactTag, ratio * 100);
            __weak TrackedViewState *weakState = state;
            __weak MyNativeView *weakView = view;
            
            // Start 2-second timer
            state.visibilityDurationTimer = [NSTimer scheduledTimerWithTimeInterval:kRequiredDuration
                                                                             repeats:NO
                                                                               block:^(NSTimer *timer) {
                [self fireImpressionForState:weakState view:weakView];
            }];
            
            // Crucial: Add timer to 'CommonModes' so it doesn't pause during scrolling
            [[NSRunLoop mainRunLoop] addTimer:state.visibilityDurationTimer forMode:NSRunLoopCommonModes];
        }
    }
    // CASE 2: View has scrolled away significantly
    else if (ratio < kExitThreshold) {
        // If they scroll away before the 2s timer finishes, cancel the timer
        if (state.visibilityDurationTimer) {
            NSLog(@"[ImpressionTracker] Node %@ dropped below exit threshold (%.0f%%). Timer invalidated.", view.reactTag, ratio * 100);
            [state.visibilityDurationTimer invalidate];
            state.visibilityDurationTimer = nil;
        }

        // Reset the flag so the view can be "seen" again for a new impression
        if (state.hasFiredViewportAppear) {
            NSLog(@"[ImpressionTracker] Node %@ exited screen (%.0f%%). Re-arming for next impression.", view.reactTag, ratio * 100);
            state.hasFiredViewportAppear = NO;
        }
    }
    // CASE 3: The Neutral Zone (10% to 70%)
    else {
        // If they drop out of the 70% threshold but stay above 10%, we pause the countdown
        if (!state.hasFiredViewportAppear && state.visibilityDurationTimer) {
            NSLog(@"[ImpressionTracker] Node %@ in neutral zone (%.0f%%). Stopping timer.", view.reactTag, ratio * 100);
            [state.visibilityDurationTimer invalidate];
            state.visibilityDurationTimer = nil;
        }
    }
}

/**
 * Fired when the timer successfully reaches 2 seconds.
 */
- (void)fireImpressionForState:(TrackedViewState *)state view:(MyNativeView *)view {
    if (!state || state.hasFiredViewportAppear) return;

    state.hasFiredViewportAppear = YES;
    [state.visibilityDurationTimer invalidate];
    state.visibilityDurationTimer = nil;

    NSLog(@"[ImpressionTracker] SUCCESS: 2s threshold met for node %@. Sending callback to JS.", view.reactTag);

    // Communicate back to the React Native JS layer
    if (view.onNativeAppear) {
        view.onNativeAppear(nil);
    }
}

@end