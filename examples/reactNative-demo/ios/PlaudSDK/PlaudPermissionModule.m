//
//  PlaudPermissionModule.m
//  ReactNativeDemo
//
//  Created by Plaud Team on 2024/12/19.
//

#import "PlaudPermissionModule.h"
#import <React/RCTLog.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>

@implementation PlaudPermissionModule

RCT_EXPORT_MODULE(PlaudPermissionModule);

RCT_EXPORT_METHOD(checkPermissions:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"[iOS] PlaudPermissionModule checkPermissions called");
    
    @try {
        NSMutableDictionary *permissions = [NSMutableDictionary dictionary];
        
        // Check microphone permission
        AVAudioSessionRecordPermission micPermission = [[AVAudioSession sharedInstance] recordPermission];
        [permissions setObject:@(micPermission == AVAudioSessionRecordPermissionGranted) forKey:@"microphone"];
        
        // Check Bluetooth permission (iOS 13+)
        if (@available(iOS 13.0, *)) {
            CBManagerAuthorization bluetoothAuth = [CBCentralManager authorization];
            [permissions setObject:@(bluetoothAuth == CBManagerAuthorizationAllowedAlways) forKey:@"bluetooth"];
        } else {
            [permissions setObject:@YES forKey:@"bluetooth"]; // Always granted on older iOS
        }
        
        // Check location permission
        CLAuthorizationStatus locationStatus = [CLLocationManager authorizationStatus];
        BOOL locationGranted = (locationStatus == kCLAuthorizationStatusAuthorizedWhenInUse ||
                               locationStatus == kCLAuthorizationStatusAuthorizedAlways);
        [permissions setObject:@(locationGranted) forKey:@"location"];
        
        resolve(permissions);
        
    } @catch (NSException *exception) {
        RCTLogError(@"[iOS] PlaudPermissionModule checkPermissions error: %@", exception.reason);
        reject(@"PERMISSION_CHECK_ERROR", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(requestPermissions:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"[iOS] PlaudPermissionModule requestPermissions called");
    
    @try {
        // Request microphone permission
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                RCTLogInfo(@"[iOS] Microphone permission granted: %@", granted ? @"YES" : @"NO");
                
                // For simplicity, just resolve with microphone permission result
                // In a real implementation, you'd also request location permission
                NSDictionary *result = @{
                    @"success": @(granted),
                    @"microphone": @(granted),
                    @"message": granted ? @"Permissions granted" : @"Microphone permission denied"
                };
                
                resolve(result);
            });
        }];
        
    } @catch (NSException *exception) {
        RCTLogError(@"[iOS] PlaudPermissionModule requestPermissions error: %@", exception.reason);
        reject(@"PERMISSION_REQUEST_ERROR", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(openSettings:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"[iOS] PlaudPermissionModule openSettings called");
    
    @try {
        NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        
        if ([[UIApplication sharedApplication] canOpenURL:settingsURL]) {
            [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:^(BOOL success) {
                resolve(@{@"success": @(success)});
            }];
        } else {
            resolve(@{@"success": @NO, @"message": @"Cannot open settings"});
        }
        
    } @catch (NSException *exception) {
        RCTLogError(@"[iOS] PlaudPermissionModule openSettings error: %@", exception.reason);
        reject(@"OPEN_SETTINGS_ERROR", exception.reason, nil);
    }
}

@end
