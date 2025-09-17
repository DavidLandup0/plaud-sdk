//
//  PlaudSDKModule.m
//  ReactNativeDemo
//
//  Created by Plaud Team on 2024/12/19.
//

#import "PlaudSDKModule.h"
#import <React/RCTLog.h>
@import PlaudDeviceBasicSDK;

@interface PlaudSDKModule ()
@property (nonatomic, assign) BOOL isInitialized;
@end

@implementation PlaudSDKModule

RCT_EXPORT_MODULE(PlaudSDK);

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"onSDKInitialized", @"onSDKError"];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _isInitialized = NO;
    }
    return self;
}

#pragma mark - React Native Methods

RCT_EXPORT_METHOD(initSdk:(id _Nullable)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Plaud iOS SDK initializing with options: %@", options);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Use PlaudDeviceAgent shared singleton
            PlaudDeviceAgent *deviceAgent = [PlaudDeviceAgent shared];
            
            // Extract appKey, appSecret and environment from options if provided (handle null case)
            NSString *appKey = nil;
            NSString *appSecret = nil;
            NSString *environment = nil;
            
            // Handle both null and dictionary cases properly
            if (options && ![options isKindOfClass:[NSNull class]]) {
                if ([options isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *optionsDict = (NSDictionary *)options;
                    appKey = optionsDict[@"appKey"];
                    appSecret = optionsDict[@"appSecret"];
                    environment = optionsDict[@"environment"];
                }
            }
            
            // Use default test credentials if not provided
            if (!appKey || !appSecret) {
                // These are the test credentials from the original demo
                appKey = @"plaud-zoem8KYd-1748487531106";
                appSecret = @"aksk_hAyGDINVTsG3vsob2Shqku3iBqgI7clL";
                RCTLogInfo(@"🍎 Using default test credentials for SDK initialization");
            }
            
            // Determine the correct domain based on environment
            NSString *customDomain = @"platform.plaud.cn"; // Default to China domain
            if (environment) {
                if ([environment isEqualToString:@"US_PROD"]) {
                    customDomain = @"platform.plaud.ai";
                } else if ([environment isEqualToString:@"US_TEST"] || [environment isEqualToString:@"COMMON_TEST"]) {
                    customDomain = @"platform-beta.plaud.ai";
                } else if ([environment isEqualToString:@"CHINA_PROD"]) {
                    customDomain = @"platform.plaud.cn";
                }
            }
            
            // Print the credentials and environment being used for debugging
            RCTLogInfo(@"🔑 SDK Credentials - AppKey: %@", appKey);
            RCTLogInfo(@"🔑 SDK Credentials - AppSecret: %@", appSecret);
            RCTLogInfo(@"🏷️ SDK HostName: ReactNativeDemo");
            RCTLogInfo(@"🎯 SDK BindToken: 123456789");
            RCTLogInfo(@"🌍 SDK Language: en");
            RCTLogInfo(@"🌐 SDK Environment: %@", environment ?: @"default");
            RCTLogInfo(@"🌐 SDK Custom Domain: %@", customDomain);
            
            // Initialize SDK with the correct domain based on environment
            [deviceAgent initSDKWithHostName:@"ReactNativeDemo" 
                                      appKey:appKey
                                   appSecret:appSecret 
                                   bindToken:@"123456789" 
                                       extra:@{@"language": @"en", @"customDomain": customDomain}];
            
            // Log initialization parameters (the SDK will log its actual domain choice)
            RCTLogInfo(@"🌐 SDK Init Parameters - Extra: %@", @{@"language": @"en", @"customDomain": customDomain});
            RCTLogInfo(@"📋 Note: Watch for [PlaudDomainManager] logs to see actual domain used by SDK");
            
            self.isInitialized = YES;
            
            NSDictionary *result = @{
                @"success": @YES,
                @"message": @"Plaud iOS SDK initialized successfully with PlaudDeviceAgent",
                @"platform": @"ios",
                @"appKey": appKey
            };
            
            // Send event
            [self sendEventWithName:@"onSDKInitialized" body:result];
            
            resolve(result);
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"iOS SDK initialization failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            
            NSDictionary *errorResult = @{
                @"success": @NO,
                @"message": errorMessage,
                @"platform": @"ios"
            };
            
            [self sendEventWithName:@"onSDKError" body:errorResult];
            reject(@"INIT_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(getVersion:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        // Get SDK version information
        NSString *sdkVersion = @"1.0.0"; // Replace with actual SDK version
        NSString *buildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
        
        NSDictionary *versionInfo = @{
            @"version": sdkVersion ?: @"unknown",
            @"buildNumber": buildNumber ?: @"unknown",
            @"platform": @"ios"
        };
        
        resolve(versionInfo);
        
    } @catch (NSException *exception) {
        reject(@"VERSION_ERROR", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(isInitialized:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    resolve(@(self.isInitialized));
}

#pragma mark - Private Methods

- (void)configureForChinaProduction
{
    RCTLogInfo(@"📍 Configuring for China Production environment");
    // Configure for China production
    // Set appropriate endpoints and configurations
}

- (void)configureForUSProduction
{
    RCTLogInfo(@"📍 Configuring for US Production environment");
    // Configure for US production
    // Set appropriate endpoints and configurations
}

- (void)configureForUSTest
{
    RCTLogInfo(@"📍 Configuring for US Test environment");
    // Configure for US test
    // Set appropriate endpoints and configurations
}

- (void)configureForCommonTest
{
    RCTLogInfo(@"📍 Configuring for Common Test environment");
    // Configure for common test
    // Set appropriate endpoints and configurations
}

@end
