#import "AppDelegate.h"

#import <React/RCTBundleURLProvider.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  // Initialize NowYouSeeReact view tracking (via Swift helper, avoids Swift header import)
  Class LaunchTasks = NSClassFromString(@"LaunchTasks");
  if (LaunchTasks && [LaunchTasks respondsToSelector:@selector(perform)]) {
    [LaunchTasks performSelector:@selector(perform)];
  }

  self.moduleName = @"TrackerApp72";
  // You can add your custom initial props in the dictionary below.
  // They will be passed down to the ViewController used by React Native.
  self.initialProps = @{};

  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}

@end
