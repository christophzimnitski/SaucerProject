#import "AppDelegate.h"
#import "SauceRobotServer.h"

@implementation AppDelegate

- (NSString *)moduleName
{
  return @"sauce-robot-mobile";
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  // Initialize the SauceRobotServer when app starts
  [[SauceRobotServer alloc] init];

  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
