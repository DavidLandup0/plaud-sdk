//
//  PlaudFileManagerModule.h
//  ReactNativeDemo
//
//  Created by Plaud Team on 2024/12/19.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <PlaudDeviceBasicSDK/PlaudDeviceBasicSDK.h>

@interface PlaudFileManagerModule : RCTEventEmitter <RCTBridgeModule, PlaudDeviceAgentProtocol>

@end
