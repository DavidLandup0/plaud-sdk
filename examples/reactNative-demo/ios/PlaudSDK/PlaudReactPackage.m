//
//  PlaudReactPackage.m
//  ReactNativeDemo
//
//  Created by Plaud Team on 2024/12/19.
//

#import "PlaudReactPackage.h"
#import "PlaudSDKModule.h"
#import "PlaudBluetoothModule.h"
#import "PlaudRecordingModule.h" 
#import "PlaudFileManagerModule.h"
#import "PlaudUploadModule.h"
#import "PlaudPermissionModule.h"
#import "PlaudEnvironmentModule.h"

@implementation PlaudReactPackage

RCT_EXPORT_MODULE();

+ (NSArray<id<RCTBridgeModule>> *)plaudModules
{
    return @[
        [[PlaudSDKModule alloc] init],
        [[PlaudBluetoothModule alloc] init],
        [[PlaudRecordingModule alloc] init],
        [[PlaudFileManagerModule alloc] init],
        [[PlaudUploadModule alloc] init],
        [[PlaudPermissionModule alloc] init],
        [[PlaudEnvironmentModule alloc] init]
    ];
}

@end
