//
//  PlaudEnvironmentModule.m
//  ReactNativeDemo
//
//  Created by Plaud Team on 2024/12/19.
//

#import "PlaudEnvironmentModule.h"
#import <React/RCTLog.h>

@implementation PlaudEnvironmentModule

RCT_EXPORT_MODULE(PlaudEnvironmentModule);

// Environment constants
static NSString *const ENV_DEVELOPMENT = @"development";
static NSString *const ENV_TEST = @"test";
static NSString *const ENV_PRODUCTION = @"production";

// Current environment - default to development
static NSString *currentEnvironment = nil;

+ (void)initialize {
    if (self == [PlaudEnvironmentModule class]) {
        currentEnvironment = ENV_DEVELOPMENT;
    }
}

RCT_EXPORT_METHOD(getCurrentEnvironment:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"[iOS] PlaudEnvironmentModule getCurrentEnvironment called");
    
    NSDictionary *config = [self getConfigForEnvironment:currentEnvironment];
    resolve(config);
}

RCT_EXPORT_METHOD(getAllEnvironments:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"[iOS] PlaudEnvironmentModule getAllEnvironments called");
    
    NSArray *environments = @[
        [self getConfigForEnvironment:ENV_DEVELOPMENT],
        [self getConfigForEnvironment:ENV_TEST],
        [self getConfigForEnvironment:ENV_PRODUCTION]
    ];
    
    resolve(environments);
}

RCT_EXPORT_METHOD(setEnvironment:(NSString *)envName
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"[iOS] PlaudEnvironmentModule setEnvironment called with: %@", envName);
    
    NSString *normalizedEnv = [envName lowercaseString];
    
    if ([normalizedEnv isEqualToString:@"development"] || [normalizedEnv isEqualToString:@"dev"]) {
        currentEnvironment = ENV_DEVELOPMENT;
    } else if ([normalizedEnv isEqualToString:@"test"]) {
        currentEnvironment = ENV_TEST;
    } else if ([normalizedEnv isEqualToString:@"production"] || [normalizedEnv isEqualToString:@"prod"]) {
        currentEnvironment = ENV_PRODUCTION;
    } else {
        reject(@"INVALID_ENV", [NSString stringWithFormat:@"Invalid environment name: %@", envName], nil);
        return;
    }
    
    NSDictionary *config = [self getConfigForEnvironment:currentEnvironment];
    NSMutableDictionary *result = [config mutableCopy];
    [result setObject:@YES forKey:@"success"];
    [result setObject:[NSString stringWithFormat:@"Environment switched to %@", config[@"displayName"]] forKey:@"message"];
    
    resolve(result);
}

- (NSDictionary *)getConfigForEnvironment:(NSString *)environment {
    if ([environment isEqualToString:ENV_DEVELOPMENT]) {
        return @{
            @"name": ENV_DEVELOPMENT,
            @"displayName": @"美国生产环境",
            @"baseUrl": @"https://platform.plaud.ai",
            @"appKey": @"plaud-rVDQilOD-1749538697969",
            @"appSecret": @"oCQjl2U5TQxOHvd1sMLNJ3qIzNgbcZbh"
        };
    } else if ([environment isEqualToString:ENV_TEST]) {
        return @{
            @"name": ENV_TEST,
            @"displayName": @"测试环境",
            @"baseUrl": @"https://platform-test.plaud.ai",
            @"appKey": @"plaud-test-key",
            @"appSecret": @"plaud-test-secret"
        };
    } else if ([environment isEqualToString:ENV_PRODUCTION]) {
        return @{
            @"name": ENV_PRODUCTION,
            @"displayName": @"生产环境",
            @"baseUrl": @"https://platform.plaud.ai",
            @"appKey": @"plaud-prod-key",
            @"appSecret": @"plaud-prod-secret"
        };
    }
    
    // Default to development
    return @{
        @"name": ENV_DEVELOPMENT,
        @"displayName": @"开发环境",
        @"baseUrl": @"https://platform-dev.plaud.ai",
        @"appKey": @"plaud-dev-key",
        @"appSecret": @"plaud-dev-secret"
    };
}

@end
