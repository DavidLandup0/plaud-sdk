//
//  PlaudReactPackage.h
//  ReactNativeDemo
//
//  Created by Plaud Team on 2024/12/19.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTViewManager.h>

@interface PlaudReactPackage : NSObject <RCTBridgeModule>

+ (NSArray<id<RCTBridgeModule>> *)plaudModules;

@end
