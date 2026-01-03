#import "SauceRobotServer.h"
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <GCDWebServer/GCDWebServer.h>
#import <GCDWebServer/GCDWebServerDataResponse.h>
#import <sqlite3.h>

@interface SauceRobotServer ()
@property (nonatomic, strong) GCDWebServer *webServer;
@property (nonatomic, assign) BOOL isServerRunning;
@property (nonatomic, strong) NSString *serverUrl;
@property (nonatomic, strong) NSString *databasePath;
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

    // Start the native iOS HTTP server
    [self startWebServer];

    // Get local IP address
    NSString *localIP = [self getLocalIPAddress];
    if (!localIP) {
      localIP = @"localhost";
    }

    NSString *port = @"8080";
    self.serverUrl = [NSString stringWithFormat:@"http://%@:%@", localIP, port];

    RCTLogInfo(@"Native iOS server started at: %@", self.serverUrl);
    [self sendEventWithName:@"ServerStatusChanged" body:@{@"running": @YES, @"url": self.serverUrl}];

    resolve(@{@"success": @YES, @"serverUrl": self.serverUrl, @"message": @"Native iOS server started successfully"});

  } @catch (NSException *exception) {
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
  // Get database path
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  self.databasePath = [documentsDirectory stringByAppendingPathComponent:@"saucerobot.db"];

  // Create tables if they don't exist
  sqlite3 *db;
  if (sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
    const char *createTableSQL = "CREATE TABLE IF NOT EXISTS recipe (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, ingredients TEXT NOT NULL)";
    char *errorMessage = NULL;

    if (sqlite3_exec(db, createTableSQL, NULL, NULL, &errorMessage) != SQLITE_OK) {
      RCTLogError(@"Failed to create table: %s", errorMessage);
      sqlite3_free(errorMessage);
    }
    sqlite3_close(db);
  }
}

- (void)startWebServer {
  self.webServer = [[GCDWebServer alloc] init];

  // GET /api/recipes - Get all recipes
  [self.webServer addHandlerForMethod:@"GET"
                                 path:@"/api/recipes"
                                 requestClass:[GCDWebServerRequest class]
                            processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
    return [self handleGetRecipes:request];
  }];

  // POST /api/recipes - Create new recipe
  [self.webServer addHandlerForMethod:@"POST"
                                 path:@"/api/recipes"
                                 requestClass:[GCDWebServerDataRequest class]
                            processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
    return [self handleCreateRecipe:(GCDWebServerDataRequest *)request];
  }];

  // PUT /api/recipes/{id} - Update recipe
  [self.webServer addHandlerForMethod:@"PUT"
                                 pathRegex:@"/api/recipes/([0-9]+)"
                                 requestClass:[GCDWebServerDataRequest class]
                            processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
    return [self handleUpdateRecipe:(GCDWebServerDataRequest *)request];
  }];

  // POST /api/recipes/start-sauce/{id} - Start sauce
  [self.webServer addHandlerForMethod:@"POST"
                                 pathRegex:@"/api/recipes/start-sauce/([0-9]+)"
                                 requestClass:[GCDWebServerRequest class]
                            processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
    return [self handleStartSauce:request];
  }];

  // Start server on port 8080
  NSError *error;
  if ([self.webServer startWithPort:8080 bonjourName:nil error:&error]) {
    self.isServerRunning = YES;
    RCTLogInfo(@"GCDWebServer started on port 8080");
  } else {
    RCTLogError(@"Failed to start GCDWebServer: %@", error);
  }
}

- (GCDWebServerResponse *)handleGetRecipes:(GCDWebServerRequest *)request {
  NSMutableArray *recipes = [NSMutableArray array];

  sqlite3 *db;
  if (sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
    sqlite3_stmt *statement;
    const char *query = "SELECT id, name, ingredients FROM recipe";

    if (sqlite3_prepare_v2(db, query, -1, &statement, NULL) == SQLITE_OK) {
      while (sqlite3_step(statement) == SQLITE_ROW) {
        int id = sqlite3_column_int(statement, 0);
        const char *name = (const char *)sqlite3_column_text(statement, 1);
        const char *ingredientsJson = (const char *)sqlite3_column_text(statement, 2);

        NSError *jsonError;
        NSArray *ingredients = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:ingredientsJson length:strlen(ingredientsJson)]
                                                               options:0
                                                                 error:&jsonError];

        NSDictionary *recipe = @{
          @"id": @(id),
          @"name": name ? [NSString stringWithUTF8String:name] : @"",
          @"ingredients": ingredients ?: @[]
        };
        [recipes addObject:recipe];
      }
      sqlite3_finalize(statement);
    }
    sqlite3_close(db);
  }

  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:recipes options:0 error:&error];
  return [[GCDWebServerDataResponse alloc] initWithData:jsonData contentType:@"application/json"];
}

- (GCDWebServerResponse *)handleCreateRecipe:(GCDWebServerDataRequest *)request {
  NSError *jsonError;
  NSDictionary *recipeData = [NSJSONSerialization JSONObjectWithData:request.data options:0 error:&jsonError];

  if (!recipeData) {
    return [[GCDWebServerResponse alloc] initWithStatusCode:400];
  }

  NSString *name = recipeData[@"name"];
  NSArray *ingredients = recipeData[@"ingredients"];

  NSError *ingredientsError;
  NSData *ingredientsJsonData = [NSJSONSerialization dataWithJSONObject:ingredients options:0 error:&ingredientsError];

  if (!ingredientsJsonData) {
    return [[GCDWebServerResponse alloc] initWithStatusCode:400];
  }

  NSString *ingredientsJson = [[NSString alloc] initWithData:ingredientsJsonData encoding:NSUTF8StringEncoding];

  sqlite3 *db;
  NSDictionary *result = nil;

  if (sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
    sqlite3_stmt *statement;
    const char *insertSQL = "INSERT INTO recipe (name, ingredients) VALUES (?, ?)";

    if (sqlite3_prepare_v2(db, insertSQL, -1, &statement, NULL) == SQLITE_OK) {
      sqlite3_bind_text(statement, 1, [name UTF8String], -1, SQLITE_TRANSIENT);
      sqlite3_bind_text(statement, 2, [ingredientsJson UTF8String], -1, SQLITE_TRANSIENT);

      if (sqlite3_step(statement) == SQLITE_DONE) {
        long long lastId = sqlite3_last_insert_rowid(db);
        result = @{
          @"id": @(lastId),
          @"name": name,
          @"ingredients": ingredients
        };
      }
      sqlite3_finalize(statement);
    }
    sqlite3_close(db);
  }

  if (result) {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:&error];
    return [[GCDWebServerDataResponse alloc] initWithData:jsonData contentType:@"application/json"];
  } else {
    return [[GCDWebServerResponse alloc] initWithStatusCode:500];
  }
}

- (GCDWebServerResponse *)handleUpdateRecipe:(GCDWebServerDataRequest *)request {
  NSError *jsonError;
  NSDictionary *recipeData = [NSJSONSerialization JSONObjectWithData:request.data options:0 error:&jsonError];

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

  NSError *ingredientsError;
  NSData *ingredientsJsonData = [NSJSONSerialization dataWithJSONObject:ingredients options:0 error:&ingredientsError];

  if (!ingredientsJsonData) {
    return [[GCDWebServerResponse alloc] initWithStatusCode:400];
  }

  NSString *ingredientsJson = [[NSString alloc] initWithData:ingredientsJsonData encoding:NSUTF8StringEncoding];

  sqlite3 *db;
  NSDictionary *result = nil;

  if (sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
    sqlite3_stmt *statement;
    const char *updateSQL = "UPDATE recipe SET name = ?, ingredients = ? WHERE id = ?";

    if (sqlite3_prepare_v2(db, updateSQL, -1, &statement, NULL) == SQLITE_OK) {
      sqlite3_bind_text(statement, 1, [name UTF8String], -1, SQLITE_TRANSIENT);
      sqlite3_bind_text(statement, 2, [ingredientsJson UTF8String], -1, SQLITE_TRANSIENT);
      sqlite3_bind_int(statement, 3, (int)recipeId);

      if (sqlite3_step(statement) == SQLITE_DONE) {
        result = @{
          @"id": @(recipeId),
          @"name": name,
          @"ingredients": ingredients
        };
      }
      sqlite3_finalize(statement);
    }
    sqlite3_close(db);
  }

  if (result) {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:&error];
    return [[GCDWebServerDataResponse alloc] initWithData:jsonData contentType:@"application/json"];
  } else {
    return [[GCDWebServerResponse alloc] initWithStatusCode:500];
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

  // Get recipe name from database
  sqlite3 *db;
  NSString *recipeName = nil;

  if (sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK) {
    sqlite3_stmt *statement;
    const char *query = "SELECT name FROM recipe WHERE id = ?";

    if (sqlite3_prepare_v2(db, query, -1, &statement, NULL) == SQLITE_OK) {
      sqlite3_bind_int(statement, 1, (int)recipeId);

      if (sqlite3_step(statement) == SQLITE_ROW) {
        const char *name = (const char *)sqlite3_column_text(statement, 0);
        recipeName = name ? [NSString stringWithUTF8String:name] : @"Unknown Recipe";
      }
      sqlite3_finalize(statement);
    }
    sqlite3_close(db);
  }

  NSString *message = [NSString stringWithFormat:@"%@ is being made...", recipeName ?: @"Recipe"];
  NSDictionary *response = @{@"message": message};

  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:0 error:&error];
  return [[GCDWebServerDataResponse alloc] initWithData:jsonData contentType:@"application/json"];
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
