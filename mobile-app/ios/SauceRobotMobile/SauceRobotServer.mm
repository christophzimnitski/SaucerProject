#import "SauceRobotServer.h"
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

@interface SauceRobotServer ()
@property (nonatomic, strong) NSTask *serverTask;
@property (nonatomic, strong) NSPipe *outputPipe;
@property (nonatomic, strong) NSPipe *errorPipe;
@property (nonatomic, assign) BOOL isServerRunning;
@property (nonatomic, strong) NSString *serverUrl;
@end

@implementation SauceRobotServer

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents {
  return @[@"ServerStatusChanged", @"ServerOutput"];
}

RCT_EXPORT_METHOD(copyServerFiles:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  @try {
    // Get the app bundle path
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *serverJarPath = [bundlePath stringByAppendingPathComponent:@"server.jar"];

    // Get documents directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *destPath = [documentsDirectory stringByAppendingPathComponent:@"server.jar"];

    // Check if file exists in bundle
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:serverJarPath]) {
      reject(@"FILE_NOT_FOUND", @"Server JAR not found in app bundle", nil);
      return;
    }

    // Copy the file
    NSError *error;
    if ([fileManager copyItemAtPath:serverJarPath toPath:destPath error:&error]) {
      RCTLogInfo(@"Server JAR copied successfully to: %@", destPath);
      resolve(@{@"success": @YES, @"path": destPath});
    } else {
      reject(@"COPY_FAILED", [error localizedDescription], error);
    }
  } @catch (NSException *exception) {
    reject(@"EXCEPTION", exception.reason, nil);
  }
}

RCT_EXPORT_METHOD(startServer:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  @try {
    if (self.isServerRunning) {
      resolve(@{@"success": @YES, @"serverUrl": self.serverUrl, @"message": @"Server already running"});
      return;
    }

    // Get documents directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *jarPath = [documentsDirectory stringByAppendingPathComponent:@"server.jar"];

    // Check if JAR exists
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:jarPath]) {
      reject(@"JAR_NOT_FOUND", @"Server JAR not found. Please copy server files first.", nil);
      return;
    }

    // Create data directory
    NSString *dataDir = [documentsDirectory stringByAppendingPathComponent:@"data"];
    if (![fileManager fileExistsAtPath:dataDir]) {
      [fileManager createDirectoryAtPath:dataDir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    // Find Java executable
    NSString *javaPath = @"/usr/bin/java";
    if (![fileManager fileExistsAtPath:javaPath]) {
      // Try alternative locations
      javaPath = @"/System/Library/Frameworks/JavaVM.framework/Versions/Current/Commands/java";
      if (![fileManager fileExistsAtPath:javaPath]) {
        reject(@"JAVA_NOT_FOUND", @"Java executable not found on device", nil);
        return;
      }
    }

    // Set up the task
    self.serverTask = [[NSTask alloc] init];
    [self.serverTask setLaunchPath:javaPath];

    // Build arguments
    NSString *port = @"8080";
    NSArray *arguments = @[
      @"-jar", jarPath,
      @"--spring.profiles.active=mobile",
      [NSString stringWithFormat:@"--server.port=%@", port],
      [NSString stringWithFormat:@"--app.data.dir=%@", dataDir],
      @"--logging.level.com.saucerobot=INFO",
      [NSString stringWithFormat:@"--spring.datasource.url=jdbc:h2:file:%@/saucerobot;AUTO_SERVER=TRUE;DB_CLOSE_ON_EXIT=FALSE", dataDir]
    ];

    [self.serverTask setArguments:arguments];

    // Set up output pipes
    self.outputPipe = [NSPipe pipe];
    self.errorPipe = [NSPipe pipe];
    [self.serverTask setStandardOutput:self.outputPipe];
    [self.serverTask setStandardError:self.errorPipe];

    // Get local IP address
    NSString *localIP = [self getLocalIPAddress];
    if (!localIP) {
      localIP = @"localhost";
    }

    self.serverUrl = [NSString stringWithFormat:@"http://%@:%@", localIP, port];

    // Handle output
    [[self.outputPipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *handle) {
      NSData *data = [handle availableData];
      if (data.length > 0) {
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        RCTLogInfo(@"SERVER OUTPUT: %@", output);
        [self sendEventWithName:@"ServerOutput" body:@{@"output": output, @"type": @"stdout"}];
      }
    }];

    [[self.errorPipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *handle) {
      NSData *data = [handle availableData];
      if (data.length > 0) {
        NSString *error = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        RCTLogError(@"SERVER ERROR: %@", error);
        [self sendEventWithName:@"ServerOutput" body:@{@"output": error, @"type": @"stderr"}];
      }
    }];

    // Set termination handler
    [self.serverTask setTerminationHandler:^(NSTask *task) {
      RCTLogInfo(@"Server task terminated with code: %d", [task terminationStatus]);
      self.isServerRunning = NO;
      [self sendEventWithName:@"ServerStatusChanged" body:@{@"running": @NO, @"exitCode": @([task terminationStatus])}];
    }];

    // Launch the task
    NSError *launchError;
    if ([self.serverTask launchAndReturnError:&launchError]) {
      self.isServerRunning = YES;
      RCTLogInfo(@"Server launched successfully at: %@", self.serverUrl);
      [self sendEventWithName:@"ServerStatusChanged" body:@{@"running": @YES, @"url": self.serverUrl}];

      // Wait a moment for server to start
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        resolve(@{@"success": @YES, @"serverUrl": self.serverUrl, @"message": @"Server started successfully"});
      });
    } else {
      reject(@"LAUNCH_FAILED", [launchError localizedDescription], launchError);
    }

  } @catch (NSException *exception) {
    reject(@"EXCEPTION", exception.reason, nil);
  }
}

RCT_EXPORT_METHOD(stopServer:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  @try {
    if (self.serverTask && [self.serverTask isRunning]) {
      [self.serverTask terminate];
      self.isServerRunning = NO;
      RCTLogInfo(@"Server stopped");
      [self sendEventWithName:@"ServerStatusChanged" body:@{@"running": @NO}];
      resolve(@{@"success": @YES, @"message": @"Server stopped successfully"});
    } else {
      resolve(@{@"success": @YES, @"message": @"Server was not running"});
    }
  } @catch (NSException *exception) {
    reject(@"EXCEPTION", exception.reason, nil);
  }
}

RCT_EXPORT_METHOD(getServerStatus:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  resolve(@{
    @"isRunning": @(self.isServerRunning),
    @"serverUrl": self.serverUrl ?: [NSNull null]
  });
}

- (NSString *)getLocalIPAddress {
  @try {
    // Get all network interfaces
    NSArray *interfaces = (__bridge_transfer NSArray *)SCNetworkInterfaceCopyAll();

    for (id interface in interfaces) {
      SCNetworkInterfaceRef interfaceRef = (__bridge SCNetworkInterfaceRef)interface;
      CFStringRef bsdName = SCNetworkInterfaceGetBSDName(interfaceRef);

      if (bsdName) {
        NSString *interfaceName = (__bridge NSString *)bsdName;

        // Get IPv4 addresses for this interface
        NSArray *addresses = [self getIPAddressesForInterface:interfaceName];

        for (NSString *address in addresses) {
          // Return first non-loopback IPv4 address
          if (![address hasPrefix:@"127."] && [self isValidIPv4Address:address]) {
            return address;
          }
        }
      }
    }

    return @"localhost";
  } @catch (NSException *exception) {
    RCTLogError(@"Error getting local IP: %@", exception.reason);
    return @"localhost";
  }
}

- (NSArray *)getIPAddressesForInterface:(NSString *)interfaceName {
  NSMutableArray *addresses = [NSMutableArray array];

  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;

  if (getifaddrs(&interfaces) == 0) {
    temp_addr = interfaces;
    while (temp_addr != NULL) {
      if (temp_addr->ifa_addr->sa_family == AF_INET) {
        NSString *ifa_name = [NSString stringWithUTF8String:temp_addr->ifa_name];
        if ([ifa_name isEqualToString:interfaceName]) {
          struct sockaddr_in *addr = (struct sockaddr_in *)temp_addr->ifa_addr;
          char addrBuf[INET_ADDRSTRLEN];
          if (inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
            [addresses addObject:[NSString stringWithUTF8String:addrBuf]];
          }
        }
      }
      temp_addr = temp_addr->ifa_next;
    }
  }

  freeifaddrs(interfaces);
  return addresses;
}

- (BOOL)isValidIPv4Address:(NSString *)address {
  NSArray *components = [address componentsSeparatedByString:@"."];
  if ([components count] != 4) {
    return NO;
  }

  for (NSString *component in components) {
    int value = [component intValue];
    if (value < 0 || value > 255) {
      return NO;
    }
  }

  return YES;
}

- (void)dealloc {
  if (self.serverTask && [self.serverTask isRunning]) {
    [self.serverTask terminate];
  }
}

@end
