#import "SauceRobotServer.h"
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <GCDWebServer/GCDWebServer.h>
#import <GCDWebServer/GCDWebServerDataRequest.h>
#import <GCDWebServer/GCDWebServerDataResponse.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/CaptiveNetwork.h>

@interface SauceRobotServer ()
@property (nonatomic, strong) GCDWebServer *webServer;
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
    // Initialize database instead of copying JAR
    [self initializeDatabase];
    RCTLogInfo(@"Database initialized successfully");
    resolve(@{@"success": @YES, @"message": @"Database initialized"});
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

    RCTLogInfo(@"🚀 Attempting to start embedded HTTP server...");

    // GCDWebServer MUST be initialized on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
      @try {
        // Start the native iOS HTTP server
        [self startWebServer];

        if (self.isServerRunning) {
          RCTLogInfo(@"✅ Embedded HTTP server started successfully at: %@", self.serverUrl);
          [self sendEventWithName:@"ServerStatusChanged" body:@{@"running": @YES, @"url": self.serverUrl}];

          resolve(@{@"success": @YES, @"serverUrl": self.serverUrl, @"message": @"Native iOS server started successfully"});
        } else {
          RCTLogError(@"❌ GCDWebServer failed to start");
          reject(@"server_error", @"GCDWebServer failed to start", nil);
        }
      } @catch (NSException *exception) {
        RCTLogError(@"EXCEPTION starting server: %@", exception.reason);
        reject(@"EXCEPTION", exception.reason, nil);
      }
    });

  } @catch (NSException *exception) {
    RCTLogError(@"EXCEPTION dispatching to main thread: %@", exception.reason);
    reject(@"EXCEPTION", exception.reason, nil);
  }
}

RCT_EXPORT_METHOD(stopServer:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  @try {
    if (self.webServer && self.webServer.isRunning) {
      [self.webServer stop];
      self.isServerRunning = NO;
      RCTLogInfo(@"Native server stopped");
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

// Database and Server Implementation
- (void)initializeDatabase {
  // Initialize NSUserDefaults for data storage (replaces SQLite)
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  // Initialize recipes array if it doesn't exist
  if (![defaults objectForKey:@"recipes"]) {
    // Add some default recipes to match the original app
    NSArray *defaultRecipes = @[
      @{@"id": @1, @"name": @"Classic Tomato Sauce", @"ingredients": @[@"Tomatoes", @"Garlic", @"Basil", @"Olive Oil", @"Salt"]},
      @{@"id": @2, @"name": @"Pesto Sauce", @"ingredients": @[@"Basil", @"Pine Nuts", @"Parmesan Cheese", @"Garlic", @"Olive Oil"]},
      @{@"id": @3, @"name": @"Alfredo Sauce", @"ingredients": @[@"Heavy Cream", @"Butter", @"Parmesan Cheese", @"Garlic", @"Black Pepper"]}
    ];
    [defaults setObject:defaultRecipes forKey:@"recipes"];
    [defaults setInteger:4 forKey:@"nextRecipeId"]; // Next ID after defaults
    [defaults synchronize];
  }

  RCTLogInfo(@"Data storage initialized successfully");
}

- (void)startWebServer {
  RCTLogInfo(@"Initializing GCDWebServer...");

  // Initialize GCDWebServer
  self.webServer = [[GCDWebServer alloc] init];
  if (!self.webServer) {
    RCTLogError(@"Failed to initialize GCDWebServer");
    return;
  }

  // Add a simple test endpoint
  [self.webServer addHandlerForMethod:@"GET"
                                 path:@"/test"
                                 requestClass:[GCDWebServerRequest class]
                            processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    RCTLogInfo(@"✅ Test endpoint called - server is responding!");
    NSDictionary *response = @{@"status": @"ok", @"message": @"Sauce Robot server is running"};
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:0 error:&error];
    return [[GCDWebServerDataResponse alloc] initWithData:jsonData contentType:@"application/json"];
#pragma clang diagnostic pop
  }];

  // Serve static React files
  NSString *frontendPath = [[NSBundle mainBundle] pathForResource:@"frontend" ofType:nil];
  if (frontendPath) {
    [self.webServer addGETHandlerForBasePath:@"/" directoryPath:frontendPath indexFilename:@"index.html" cacheAge:3600 allowRangeRequests:YES];
    RCTLogInfo(@"✅ Serving React frontend from: %@", frontendPath);
  } else {
    RCTLogError(@"❌ Frontend path not found in bundle");
  }

  // GET /api/recipes - Get all recipes
  [self.webServer addHandlerForMethod:@"GET"
                                 path:@"/api/recipes"
                                 requestClass:[GCDWebServerRequest class]
                            processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    return [self handleGetRecipes:request];
#pragma clang diagnostic pop
  }];

  // POST /api/recipes - Create new recipe
  [self.webServer addHandlerForMethod:@"POST"
                                 path:@"/api/recipes"
                                 requestClass:[GCDWebServerDataRequest class]
                            processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    return [self handleCreateRecipe:(GCDWebServerDataRequest *)request];
#pragma clang diagnostic pop
  }];

  // PUT /api/recipes/{id} - Update recipe
  [self.webServer addHandlerForMethod:@"PUT"
                                 pathRegex:@"/api/recipes/([0-9]+)"
                                 requestClass:[GCDWebServerDataRequest class]
                            processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    return [self handleUpdateRecipe:(GCDWebServerDataRequest *)request];
#pragma clang diagnostic pop
  }];

  // POST /api/recipes/start-sauce/{id} - Start sauce
  [self.webServer addHandlerForMethod:@"POST"
                                 pathRegex:@"/api/recipes/start-sauce/([0-9]+)"
                                 requestClass:[GCDWebServerRequest class]
                            processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    return [self handleStartSauce:request];
#pragma clang diagnostic pop
  }];

  // Start server on port 8080
  RCTLogInfo(@"🚀 Attempting to start embedded HTTP server on port 8080...");

  // Try different ports if 8080 is busy
  NSArray *portsToTry = @[@8080, @8081, @8082, @8083];
  BOOL serverStarted = NO;

  for (NSNumber *port in portsToTry) {
    RCTLogInfo(@"Trying port %@...", port);
    if ([self.webServer startWithPort:[port intValue] bonjourName:nil]) {
      self.isServerRunning = YES;
      self.serverUrl = [NSString stringWithFormat:@"http://localhost:%@", port];
      RCTLogInfo(@"✅ Embedded HTTP server started successfully on port %@", port);
      RCTLogInfo(@"✅ Server accessible at: %@", self.serverUrl);
      serverStarted = YES;
      break;
    }
  }

  if (!serverStarted) {
    RCTLogError(@"❌ Failed to start embedded HTTP server on any port");
  }
}

- (GCDWebServerResponse *)handleGetRecipes:(GCDWebServerRequest *)request {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *recipes = [defaults objectForKey:@"recipes"];

  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:recipes ?: @[] options:0 error:&error];
  return [[GCDWebServerDataResponse alloc] initWithData:jsonData contentType:@"application/json"];
}

- (GCDWebServerResponse *)handleCreateRecipe:(GCDWebServerRequest *)request {
  GCDWebServerDataRequest *dataRequest = (GCDWebServerDataRequest *)request;
  NSError *jsonError;
  NSDictionary *recipeData = [NSJSONSerialization JSONObjectWithData:dataRequest.data options:0 error:&jsonError];

  if (!recipeData) {
    return [[GCDWebServerResponse alloc] initWithStatusCode:400];
  }

  NSString *name = recipeData[@"name"];
  NSArray *ingredients = recipeData[@"ingredients"];

  if (!name || !ingredients) {
    return [[GCDWebServerResponse alloc] initWithStatusCode:400];
  }

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  // Get current recipes and next ID
  NSMutableArray *recipes = [[defaults objectForKey:@"recipes"] mutableCopy] ?: [NSMutableArray array];
  NSInteger nextId = [defaults integerForKey:@"nextRecipeId"];

  // Create new recipe
  NSDictionary *newRecipe = @{
    @"id": @(nextId),
    @"name": name,
    @"ingredients": ingredients
  };

  [recipes addObject:newRecipe];

  // Save back to defaults
  [defaults setObject:recipes forKey:@"recipes"];
  [defaults setInteger:nextId + 1 forKey:@"nextRecipeId"];
  [defaults synchronize];

  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:newRecipe options:0 error:&error];
  return [[GCDWebServerDataResponse alloc] initWithData:jsonData contentType:@"application/json"];
}

- (GCDWebServerResponse *)handleUpdateRecipe:(GCDWebServerRequest *)request {
  GCDWebServerDataRequest *dataRequest = (GCDWebServerDataRequest *)request;
  NSError *jsonError;
  NSDictionary *recipeData = [NSJSONSerialization JSONObjectWithData:dataRequest.data options:0 error:&jsonError];

  if (!recipeData) {
    return [[GCDWebServerResponse alloc] initWithStatusCode:400];
  }

  // Extract ID from URL regex match
  NSString *path = request.path;
  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"/api/recipes/([0-9]+)" options:0 error:nil];
  NSTextCheckingResult *match = [regex firstMatchInString:path options:0 range:NSMakeRange(0, path.length)];

  if (!match || match.numberOfRanges < 2) {
    return [[GCDWebServerResponse alloc] initWithStatusCode:400];
  }

  NSString *idString = [path substringWithRange:[match rangeAtIndex:1]];
  NSInteger recipeId = [idString integerValue];

  NSString *name = recipeData[@"name"];
  NSArray *ingredients = recipeData[@"ingredients"];

  if (!name || !ingredients) {
    return [[GCDWebServerResponse alloc] initWithStatusCode:400];
  }

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *recipes = [[defaults objectForKey:@"recipes"] mutableCopy] ?: [NSMutableArray array];

  // Find and update the recipe
  NSDictionary *updatedRecipe = nil;
  for (NSInteger i = 0; i < recipes.count; i++) {
    NSDictionary *recipe = recipes[i];
    if ([recipe[@"id"] integerValue] == recipeId) {
      updatedRecipe = @{
        @"id": @(recipeId),
        @"name": name,
        @"ingredients": ingredients
      };
      [recipes replaceObjectAtIndex:i withObject:updatedRecipe];
      break;
    }
  }

  if (updatedRecipe) {
    [defaults setObject:recipes forKey:@"recipes"];
    [defaults synchronize];

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:updatedRecipe options:0 error:&error];
    return [[GCDWebServerDataResponse alloc] initWithData:jsonData contentType:@"application/json"];
  } else {
    return [[GCDWebServerResponse alloc] initWithStatusCode:404];
  }
}

- (GCDWebServerResponse *)handleStartSauce:(GCDWebServerRequest *)request {
  // Extract ID from URL regex match
  NSString *path = request.path;
  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"/api/recipes/start-sauce/([0-9]+)" options:0 error:nil];
  NSTextCheckingResult *match = [regex firstMatchInString:path options:0 range:NSMakeRange(0, path.length)];

  if (!match || match.numberOfRanges < 2) {
    return [[GCDWebServerResponse alloc] initWithStatusCode:400];
  }

  NSString *idString = [path substringWithRange:[match rangeAtIndex:1]];
  NSInteger recipeId = [idString integerValue];

  // Get recipe name from NSUserDefaults
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *recipes = [defaults objectForKey:@"recipes"];

  NSString *recipeName = @"Unknown Recipe";
  for (NSDictionary *recipe in recipes) {
    if ([recipe[@"id"] integerValue] == recipeId) {
      recipeName = recipe[@"name"] ?: @"Unknown Recipe";
      break;
    }
  }

  NSString *message = [NSString stringWithFormat:@"%@ is being made...", recipeName];
  NSDictionary *response = @{@"message": message};

  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:0 error:&error];
  return [[GCDWebServerDataResponse alloc] initWithData:jsonData contentType:@"application/json"];
}

- (NSString *)getLocalIPAddress {
  @try {
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;

    // Get list of network interfaces
    success = getifaddrs(&interfaces);
    if (success == 0) {
      temp_addr = interfaces;
      while (temp_addr != NULL) {
        if (temp_addr->ifa_addr->sa_family == AF_INET) {
          // Check if it's not a loopback address
          NSString *address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
          if (![address hasPrefix:@"127."]) {
            freeifaddrs(interfaces);
            return address;
          }
        }
        temp_addr = temp_addr->ifa_next;
      }
      freeifaddrs(interfaces);
    }

    return @"localhost";
  } @catch (NSException *exception) {
    RCTLogError(@"Error getting local IP: %@", exception.reason);
    return @"localhost";
  }
}

- (void)dealloc {
  if (self.webServer && self.webServer.isRunning) {
    [self.webServer stop];
  }
}

@end
