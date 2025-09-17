//
//  PlaudBluetoothModule.m
//  ReactNativeDemo
//
//  Created by Plaud Team on 2024/12/19.
//

#import "PlaudBluetoothModule.h"
#import <React/RCTLog.h>
@import PlaudDeviceBasicSDK;
@import PenBleSDK;

@interface PlaudBluetoothModule () <PlaudDeviceAgentProtocol>
@property (nonatomic, strong) NSMutableArray<BleDevice *> *discoveredDevices;
@property (nonatomic, strong) BleDevice *connectedDevice;
@property (nonatomic, strong) BleDevice *connectingDevice; // 正在连接的设备
@property (nonatomic, assign) BOOL isScanning;
// 实时设备状态缓存
@property (nonatomic, strong) NSMutableDictionary *deviceStateInfo;
@property (nonatomic, strong) NSMutableDictionary *storageInfo;
@property (nonatomic, strong) NSMutableDictionary *batteryInfo;

// 连接完成状态跟踪
@property (nonatomic, assign) BOOL hasReceivedDeviceState;
@property (nonatomic, assign) BOOL hasReceivedBatteryInfo;
@property (nonatomic, assign) BOOL hasReceivedStorageInfo;
@property (nonatomic, assign) BOOL hasReceivedFileList;

// 私有方法声明
- (NSDictionary *)deviceToDictionary:(BleDevice *)device;
- (void)fetchAllDeviceInfoAfterConnection;
- (void)checkConnectionCompletionStatus;
- (void)resetConnectionCompletionFlags;

@end

@implementation PlaudBluetoothModule

RCT_EXPORT_MODULE(PlaudBluetooth);

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[
        @"onDeviceFound",
        @"onDeviceConnected", 
        @"onDeviceDisconnected",
        @"onConnectionStatusChanged",
        @"onScanStarted",
        @"onScanStopped",
        @"onFileListUpdated",
        @"onDeviceStateChanged",
        @"onStorageInfoUpdated",
        @"onBatteryInfoUpdated",
        @"onRecordingStart",
        @"onRecordingStop",
        @"onRecordingPause",
        @"onRecordingResume"
    ];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // 不在初始化时设置delegate，将在startScan时设置
        _discoveredDevices = [NSMutableArray array];
        _isScanning = NO;
        _connectedDevice = nil;
        _connectingDevice = nil;
        
        // 初始化实时状态缓存
        _deviceStateInfo = [[NSMutableDictionary alloc] init];
        _storageInfo = [[NSMutableDictionary alloc] init];
        _batteryInfo = [[NSMutableDictionary alloc] init];
        
        // 初始化连接完成状态标志
        [self resetConnectionCompletionFlags];
    }
    return self;
}

#pragma mark - React Native Methods

RCT_EXPORT_METHOD(startScan:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Starting Bluetooth scan");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (self.isScanning) {
                resolve(@{
                    @"success": @YES,
                    @"scanning": @YES,
                    @"message": @"Already scanning"
                });
                return;
            }
            
            // Clear previous results
            [self.discoveredDevices removeAllObjects];
            
            // 关键修复：设置当前模块为唯一delegate
            [PlaudDeviceAgent shared].delegate = self;
            RCTLogInfo(@"🍎 Set PlaudBluetoothModule as PRIMARY DELEGATE for all events");
            NSLog(@"[RN] 📱 Bluetooth module set as primary delegate");
            
            // Start scanning
            [[PlaudDeviceAgent shared] startScan];
            self.isScanning = YES;
            
            [self sendEventWithName:@"onScanStarted" body:@{
                @"scanning": @YES,
                @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
            }];
            
            resolve(@{
                @"success": @YES,
                @"scanning": @YES,
                @"message": @"Bluetooth scan started"
            });
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Start scan failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"SCAN_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(stopScan:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Stopping Bluetooth scan");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [[PlaudDeviceAgent shared] stopScan];
            self.isScanning = NO;
            
            [self sendEventWithName:@"onScanStopped" body:@{
                @"scanning": @NO,
                @"devicesFound": @(self.discoveredDevices.count),
                @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
            }];
            
            resolve(@{
                @"success": @YES,
                @"scanning": @NO,
                @"message": @"Bluetooth scan stopped"
            });
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Stop scan failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"SCAN_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(connect:(NSString *)serialNumber
                  token:(NSString *)token
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Connecting to device with serialNumber: %@, token: %@", serialNumber, token);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Find device by serialNumber
            BleDevice *targetDevice = nil;
            for (BleDevice *device in self.discoveredDevices) {
                if ([device.serialNumber isEqualToString:serialNumber]) {
                    targetDevice = device;
                    break;
                }
            }
            
            if (!targetDevice) {
                reject(@"DEVICE_NOT_FOUND", @"Device not found in scan results", nil);
                return;
            }
            
            // Set self as delegate for connection events
            [PlaudDeviceAgent shared].delegate = self;
            RCTLogInfo(@"🍎 Set PlaudBluetoothModule as PRIMARY DELEGATE for connection and all events");
            NSLog(@"[RN] 🔗 Device delegate configured for connection");
            
            // Connect to device with serialNumber as deviceToken (this overrides the default bindToken)
            [[PlaudDeviceAgent shared] connectBleDeviceWithBleDevice:targetDevice deviceToken:targetDevice.serialNumber];
            
            // Note: The actual connection result will be reported via delegate methods
            resolve(@{
                @"success": @YES,
                @"message": @"Connection request sent",
                @"serialNumber": serialNumber,
                @"deviceId": targetDevice.uuid
            });
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Connect device failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"CONNECT_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(refreshDeviceInfo:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Manually refreshing device info");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.connectedDevice) {
                resolve(@{
                    @"success": @NO,
                    @"message": @"No device connected"
                });
                return;
            }
            
            // 主动获取设备状态信息
            [[PlaudDeviceAgent shared] getState];
            
            // 主动获取存储信息
            [[PlaudDeviceAgent shared] getStorage];
            
            // 主动获取充电状态信息
            [[PlaudDeviceAgent shared] getChargingState];
            
            resolve(@{
                @"success": @YES,
                @"message": @"Device info refresh requested"
            });
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Refresh device info failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"REFRESH_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(connectDevice:(NSString *)deviceId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Connecting to device: %@", deviceId);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Find device in discovered devices
            BleDevice *targetDevice = nil;
            for (BleDevice *device in self.discoveredDevices) {
                if ([device.uuid isEqualToString:deviceId]) {
                    targetDevice = device;
                    break;
                }
            }
            
            if (!targetDevice) {
                reject(@"DEVICE_NOT_FOUND", @"Device not found in scan results", nil);
                return;
            }
            
            // Set self as delegate for connection events
            [PlaudDeviceAgent shared].delegate = self;
            RCTLogInfo(@"🍎 Set PlaudBluetoothModule as delegate for connection");
            
            // 保存正在连接的设备引用
            self.connectingDevice = targetDevice;
            RCTLogInfo(@"🍎 Saved connecting device: %@", targetDevice.serialNumber);
            
            // Connect to device with serialNumber as deviceToken (this overrides the default bindToken)
            [[PlaudDeviceAgent shared] connectBleDeviceWithBleDevice:targetDevice deviceToken:targetDevice.serialNumber];
            
            // Note: The actual connection result will be reported via delegate methods
            resolve(@{
                @"success": @YES,
                @"message": @"Connection request sent",
                @"deviceId": deviceId
            });
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Connect device failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"CONNECT_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(disconnect:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Disconnecting current device");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.connectedDevice) {
                resolve(@{
                    @"success": @YES,
                    @"connected": @NO,
                    @"message": @"No device connected"
                });
                return;
            }
            
            [[PlaudDeviceAgent shared] disconnect];
            
            resolve(@{
                @"success": @YES,
                @"message": @"Disconnect request sent"
            });
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Disconnect device failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"DISCONNECT_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(disconnectDevice:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Disconnecting current device");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.connectedDevice) {
                resolve(@{
                    @"success": @YES,
                    @"connected": @NO,
                    @"message": @"No device connected"
                });
                return;
            }
            
            [[PlaudDeviceAgent shared] disconnect];
            
            resolve(@{
                @"success": @YES,
                @"message": @"Disconnect request sent"
            });
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Disconnect device failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"DISCONNECT_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(getConnectionStatus:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        BOOL isConnected = (self.connectedDevice != nil);
        NSDictionary *device = isConnected ? [self deviceToDictionary:self.connectedDevice] : nil;
        
        resolve(@{
            @"success": @YES,
            @"connected": @(isConnected),
            @"device": device ?: [NSNull null]
        });
        
    } @catch (NSException *exception) {
        reject(@"STATUS_ERROR", exception.reason, nil);
    }
}

RCT_EXPORT_METHOD(getConnectedDevice:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if (self.connectedDevice) {
            resolve(@{
                @"success": @YES,
                @"connected": @YES,
                @"device": [self deviceToDictionary:self.connectedDevice]
            });
        } else {
            resolve(@{
                @"success": @YES,
                @"connected": @NO,
                @"device": [NSNull null]
            });
        }
        
    } @catch (NSException *exception) {
        reject(@"DEVICE_ERROR", exception.reason, nil);
    }
}

#pragma mark - PlaudDeviceAgentProtocol

// 录音开始回调 - 参考原生demo的确切方法签名
- (void)bleRecordStartWithSessionId:(NSInteger)sessionId 
                              start:(NSInteger)start 
                             status:(NSInteger)status 
                              scene:(NSInteger)scene 
                          startTime:(NSInteger)startTime 
                             reason:(NSInteger)reason
{
    NSLog(@"[RN] 🎙️ Recording started - sessionId:%ld scene:%ld reason:%ld", 
          (long)sessionId, (long)scene, (long)reason);
    
    // 发送录音开始通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudRecordingStarted" 
                                                        object:nil
                                                      userInfo:@{
                                                          @"sessionId": @(sessionId),
                                                          @"start": @(start),
                                                          @"status": @(status),
                                                          @"scene": @(scene),
                                                          @"startTime": @(startTime),
                                                          @"reason": @(reason),
                                                          @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
                                                      }];
    
    // 测试事件发送
    [self sendEventWithName:@"onRecordingStart" body:@{
        @"sessionId": @(sessionId),
        @"start": @(start),
        @"status": @(status),
        @"scene": @(scene),
        @"startTime": @(startTime),
        @"reason": @(reason),
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    }];
}

- (void)bleRecordStopWithSessionId:(NSInteger)sessionId 
                            reason:(NSInteger)reason 
                         fileExist:(BOOL)fileExist 
                          fileSize:(NSInteger)fileSize
{
    NSLog(@"[RN] 🛑 Recording stopped - sessionId:%ld reason:%ld fileExist:%@", 
          (long)sessionId, (long)reason, fileExist ? @"YES" : @"NO");
    
    // 发送录音结束通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudRecordingStopped" 
                                                        object:nil
                                                      userInfo:@{
                                                          @"sessionId": @(sessionId),
                                                          @"reason": @(reason),
                                                          @"fileExist": @(fileExist),
                                                          @"fileSize": @(fileSize),
                                                          @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
                                                      }];
}

- (void)bleRecordPauseWithSessionId:(NSInteger)sessionId 
                             reason:(NSInteger)reason 
                          fileExist:(BOOL)fileExist 
                           fileSize:(NSInteger)fileSize
{
    NSLog(@"[RN] ⏸️ Recording paused - sessionId:%ld reason:%ld", 
          (long)sessionId, (long)reason);
    
    // 发送录音暂停通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudRecordingPaused" 
                                                        object:nil
                                                      userInfo:@{
                                                          @"sessionId": @(sessionId),
                                                          @"reason": @(reason),
                                                          @"fileExist": @(fileExist),
                                                          @"fileSize": @(fileSize),
                                                          @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
                                                      }];
}

- (void)bleRecordResumeWithSessionId:(NSInteger)sessionId 
                               start:(NSInteger)start 
                              status:(NSInteger)status 
                               scene:(NSInteger)scene 
                           startTime:(NSInteger)startTime
{
    NSLog(@"[RN] ▶️ Recording resumed - sessionId:%ld scene:%ld", 
          (long)sessionId, (long)scene);
    
    // 发送录音恢复通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudRecordingResumed" 
                                                        object:nil
                                                      userInfo:@{
                                                          @"sessionId": @(sessionId),
                                                          @"start": @(start),
                                                          @"status": @(status),
                                                          @"scene": @(scene),
                                                          @"startTime": @(startTime),
                                                          @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
                                                      }];
}

- (void)bleScanResultWithBleDevices:(NSArray<BleDevice *> *)bleDevices
{
    RCTLogInfo(@"🍎 Found %lu devices", (unsigned long)bleDevices.count);
    
    for (BleDevice *device in bleDevices) {
        // Check if device already exists
        BOOL exists = NO;
        for (BleDevice *existingDevice in self.discoveredDevices) {
            if ([existingDevice.uuid isEqualToString:device.uuid]) {
                exists = YES;
                break;
            }
        }
        
        if (!exists) {
            [self.discoveredDevices addObject:device];
            
            // Send device found event
            [self sendEventWithName:@"onDeviceFound" body:[self deviceToDictionary:device]];
        }
    }
}

- (void)bleConnectStateWithState:(NSInteger)state
{
    RCTLogInfo(@"🍎 Connection state changed: %ld", (long)state);
    
    if (state == 1) { // Connected
        // 使用我们保存的连接设备，如果没有则尝试从SDK获取
        if (!self.connectingDevice) {
            self.connectedDevice = [PlaudDeviceAgent shared].recentConnectDevice;
            RCTLogInfo(@"🍎 Using SDK recentConnectDevice as fallback");
        } else {
            self.connectedDevice = self.connectingDevice;
        }
        
        RCTLogInfo(@"🍎 Connection established for device: %@", self.connectedDevice.serialNumber ?: @"unknown");
        
        // 通知其他模块设备已连接（即使设备对象为nil也通知，让其他模块知道连接状态）
        [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudDeviceConnected" object:self.connectedDevice];
        
        // 创建设备信息字典，确保不返回nil
        NSDictionary *deviceDict = [self deviceToDictionary:self.connectedDevice];
        if (!deviceDict) {
            deviceDict = @{
                @"id": @"unknown",
                @"name": @"Connected Device",
                @"serialNumber": @"unknown",
                @"isConnected": @YES
            };
        }
        
        // 立即发送连接成功事件
        [self sendEventWithName:@"onDeviceConnected" body:@{
            @"success": @YES,
            @"connected": @YES,
            @"device": deviceDict,
            @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
        }];
        
        [self sendEventWithName:@"onConnectionStatusChanged" body:@{
            @"connected": @YES,
            @"device": deviceDict
        }];
        
        NSLog(@"[RN] ✅ Device connected successfully, waiting for device state callback...");
        
        // 重置连接完成标志，为新连接准备
        [self resetConnectionCompletionFlags];
        
    } else if (state == 0 || state == 2) { // Disconnected or Failed
        BleDevice *lastDevice = self.connectedDevice;
        self.connectedDevice = nil;
        self.connectingDevice = nil; // 清理连接中的设备引用
        
        // 通知其他模块设备已断开
        [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudDeviceDisconnected" object:nil];
        
        [self sendEventWithName:@"onDeviceDisconnected" body:@{
            @"success": @YES,
            @"connected": @NO,
            @"device": lastDevice ? [self deviceToDictionary:lastDevice] : [NSNull null],
            @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
        }];
        
        [self sendEventWithName:@"onConnectionStatusChanged" body:@{
            @"connected": @NO,
            @"device": [NSNull null]
        }];
    }
}

// 设备状态回调 - 参考原生demo的DeviceInfoViewController实现
- (void)blePenStateWithState:(NSInteger)state 
                    privacy:(NSInteger)privacy 
                   keyState:(NSInteger)keyState 
                      uDisk:(NSInteger)uDisk 
                findMyToken:(NSInteger)findMyToken 
                 hasSndpKey:(NSInteger)hasSndpKey 
          deviceAccessToken:(NSInteger)deviceAccessToken
{
    RCTLogInfo(@"🍎 Device pen state callback - state:%ld privacy:%ld keyState:%ld uDisk:%ld findMyToken:%ld hasSndpKey:%ld deviceAccessToken:%ld", 
               (long)state, (long)privacy, (long)keyState, (long)uDisk, 
               (long)findMyToken, (long)hasSndpKey, (long)deviceAccessToken);
    
    // 每次状态变化时检查delegate
    [self checkDelegateStatusNow];
    
    // 更新设备状态缓存
    [self.deviceStateInfo setObject:@{
        @"state": @(state),
        @"privacy": @(privacy),
        @"keyState": @(keyState),
        @"uDisk": @(uDisk),
        @"findMyToken": @(findMyToken),
        @"hasSndpKey": @(hasSndpKey),
        @"deviceAccessToken": @(deviceAccessToken),
        @"usbDiskMode": @(uDisk == 1), // USB磁盘模式
        @"usbAccessEnabled": @(privacy == 0), // USB访问权限
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    } forKey:@"deviceState"];
    
    // 通知其他模块设备状态更新，传递完整的状态信息
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudDeviceStateUpdated" 
                                                        object:nil
                                                      userInfo:self.deviceStateInfo[@"deviceState"]];
    
    // 发送设备状态事件到JS端
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendEventWithName:@"onDeviceStateChanged" body:self.deviceStateInfo[@"deviceState"]];
    });
    
    // 设置设备状态已接收标志
    self.hasReceivedDeviceState = YES;
    
    // 当设备状态回调触发时，说明设备已经完全初始化，现在可以安全获取其他信息
    if (self.connectedDevice && !self.hasReceivedBatteryInfo && !self.hasReceivedStorageInfo) {
        NSLog(@"[RN] 📡 Device state received, now fetching battery and storage info...");
        [self fetchAllDeviceInfoAfterConnection];
    }
    
    [self checkConnectionCompletionStatus];
}

// 存储信息回调
- (void)bleStorageWithTotal:(NSInteger)total free:(NSInteger)free duration:(NSInteger)duration
{
    RCTLogInfo(@"🍎 ✅ Storage info callback triggered - total:%ld free:%ld duration:%ld", (long)total, (long)free, (long)duration);
    
    NSInteger usedSpace = total - free;
    double usagePercent = total > 0 ? (double)usedSpace / total * 100.0 : 0.0;
    
    // 更新存储信息缓存
    [self.storageInfo setObject:@{
        @"totalSpace": @(total),
        @"freeSpace": @(free), 
        @"usedSpace": @(usedSpace),
        @"duration": @(duration),
        @"usagePercent": @(usagePercent),
        @"totalSpaceText": [self formatStorageBytes:total],
        @"freeSpaceText": [self formatStorageBytes:free],
        @"usedSpaceText": [self formatStorageBytes:usedSpace],
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    } forKey:@"storage"];
    
    // 通知其他模块存储信息更新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudStorageInfoUpdated" object:self.storageInfo[@"storage"]];
    
    // 发送存储信息事件到JS端
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendEventWithName:@"onStorageInfoUpdated" body:self.storageInfo[@"storage"]];
    });
    
    // 设置存储信息已接收标志
    self.hasReceivedStorageInfo = YES;
    [self checkConnectionCompletionStatus];
}

// 电池电量变化回调
- (void)blePowerChangeWithPower:(NSInteger)power oldPower:(NSInteger)oldPower
{
    RCTLogInfo(@"🍎 Battery power change - power:%ld oldPower:%ld", (long)power, (long)oldPower);
    
    // 获取当前充电状态（从之前的信息中）
    BOOL isCharging = [self.batteryInfo[@"battery"][@"isCharging"] boolValue];
    
    // 更新电池信息缓存
    [self updateBatteryInfo:power isCharging:isCharging];
}

// 充电状态回调
- (void)bleChargingStateWithIsCharging:(BOOL)isCharging level:(NSInteger)level
{
    RCTLogInfo(@"🍎 ✅ Charging state callback triggered - isCharging:%@ level:%ld", isCharging ? @"YES" : @"NO", (long)level);
    
    // 更新电池信息缓存
    [self updateBatteryInfo:level isCharging:isCharging];
}

// 文件列表回调 - 与文件管理模块共享数据
- (void)bleFileListWithBleFiles:(NSArray<BleFile *> *)bleFiles
{
    RCTLogInfo(@"🍎 [BluetoothModule] File list received: %lu files", (unsigned long)bleFiles.count);
    
    if (!bleFiles || bleFiles.count == 0) {
        RCTLogInfo(@"🍎 [BluetoothModule] No files to process");
        return;
    }
    
    // 使用通知中心通知文件管理模块更新文件列表
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudFileListUpdated" object:bleFiles];
    
    // 发送文件列表更新事件
    NSMutableArray *filesArray = [NSMutableArray array];
    for (BleFile *file in bleFiles) {
        // 创建文件基本信息字典
        NSDictionary *fileDict = @{
            @"sessionId": @(file.sessionId),
            @"fileSize": @(file.size),
            @"scene": @(file.scenes),
            @"createTime": @(file.sessionId), // sessionId 就是时间戳
            @"channels": @(file.channels ?: 1)
        };
        [filesArray addObject:fileDict];
    }
    
    [self sendEventWithName:@"onFileListUpdated" body:@{
        @"files": filesArray,
        @"totalFiles": @(filesArray.count),
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    }];
    
    // 设置文件列表已接收标志
    self.hasReceivedFileList = YES;
}

#pragma mark - Helper Methods

// 更新电池信息的统一方法
- (void)updateBatteryInfo:(NSInteger)level isCharging:(BOOL)isCharging
{
    NSString *batteryText;
    if (level >= 0 && level <= 100) {
        batteryText = [NSString stringWithFormat:@"%ld%%", (long)level];
    } else {
        batteryText = @"未知";
    }
    
    // 更新电池信息缓存
    [self.batteryInfo setObject:@{
        @"batteryLevel": @(level),
        @"isCharging": @(isCharging),
        @"batteryText": batteryText,
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    } forKey:@"battery"];
    
    // 通知其他模块电池信息更新
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudBatteryInfoUpdated" object:self.batteryInfo[@"battery"]];
    
    // 发送电池信息事件到JS端
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendEventWithName:@"onBatteryInfoUpdated" body:self.batteryInfo[@"battery"]];
    });
    
    // 设置电池信息已接收标志
    self.hasReceivedBatteryInfo = YES;
    [self checkConnectionCompletionStatus];
}

// 格式化存储大小 - 使用1000作为单位换算，与原生demo保持一致  
- (NSString *)formatStorageBytes:(NSInteger)bytes
{
    if (bytes < 0) return @"--";
    
    double kb = bytes / 1000.0;
    double mb = kb / 1000.0; 
    double gb = mb / 1000.0;
    
    if (gb >= 1.0) {
        return [NSString stringWithFormat:@"%.2f GB", gb];
    } else if (mb >= 1.0) {
        return [NSString stringWithFormat:@"%.1f MB", mb];
    } else if (kb >= 1.0) {
        return [NSString stringWithFormat:@"%.1f KB", kb];
    } else {
        return [NSString stringWithFormat:@"%ld B", (long)bytes];
    }
}

- (NSDictionary *)deviceToDictionary:(BleDevice *)device
{
    if (!device) return nil;
    
    @try {
        // 安全处理字符串属性
        NSString *safeUuid = (device.uuid && [device.uuid isKindOfClass:[NSString class]]) ? device.uuid : @"unknown";
        NSString *safeName = (device.name && [device.name isKindOfClass:[NSString class]]) ? device.name : @"Unknown Device";
        NSString *safeSerialNumber = (device.serialNumber && [device.serialNumber isKindOfClass:[NSString class]]) ? device.serialNumber : @"unknown";
        NSString *safeManufacturer = (device.manufacturer && [device.manufacturer isKindOfClass:[NSString class]]) ? device.manufacturer : @"unknown";
        
        // 尝试获取完整版本信息
        NSString *fullVersion = nil;
        if ([device respondsToSelector:@selector(wholeVersion)]) {
            fullVersion = [(id)device wholeVersion];
        }
        
        return @{
            @"id": safeUuid,
            @"name": safeName,
            @"rssi": @(device.rssi),
            @"isConnected": @(device == self.connectedDevice),
            @"batteryLevel": @(device.power),
            @"serialNumber": safeSerialNumber.length > 0 ? safeSerialNumber : [NSNull null],
            @"manufacturer": safeManufacturer.length > 0 ? safeManufacturer : [NSNull null],
            @"versionCode": @(device.versionCode),
            @"wholeVersion": fullVersion ? fullVersion : [NSNull null],
            @"bindCode": @(device.bindCode),
            @"total": @(device.total),
            @"free": @(device.free),
            @"isCharging": @(device.isCharging)
        };
        
    } @catch (NSException *exception) {
        RCTLogError(@"🍎 Error in deviceToDictionary: %@", exception.reason);
        // 返回最基本的设备信息
        return @{
            @"id": @"unknown",
            @"name": @"Device",
            @"rssi": @(-100),
            @"isConnected": @NO,
            @"batteryLevel": @(-1),
            @"serialNumber": [NSNull null],
            @"manufacturer": [NSNull null],
            @"versionCode": @(0),
            @"bindCode": @(0),
            @"total": @(0),
            @"free": @(0),
            @"isCharging": @NO
        };
    }
}

- (NSDictionary *)fileToBasicDictionary:(BleFile *)file
{
    if (!file) return nil;
    
    // 基本文件信息，用于事件通知
    return @{
        @"sessionId": @(file.sessionId),
        @"fileSize": @(file.size),
        @"scene": @(file.scenes),
        @"sn": file.sn ?: @"",
        @"channels": @(file.channels)
    };
}

#pragma mark - File Download Delegate Methods

// 接收文件下载数据并转发给文件管理模块
- (void)bleDataWithSessionId:(int)sessionId start:(int)start data:(NSData *)data
{
    NSLog(@"🍎 [PlaudBluetoothModule] bleData - sessionId:%d start:%d dataSize:%lu", sessionId, start, (unsigned long)data.length);
    
    // 转发数据到文件管理模块的通知
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudFileDataReceived" object:nil userInfo:@{
        @"sessionId": @(sessionId),
        @"start": @(start),
        @"data": data
    }];
}

// 文件同步头信息
- (void)bleSyncFileHeadWithSessionId:(int)sessionId size:(int)size start:(int)start end:(int)end
{
    NSLog(@"🍎 [PlaudBluetoothModule] bleSyncFileHead - sessionId:%d size:%d start:%d end:%d", sessionId, size, start, end);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudFileSyncHead" object:nil userInfo:@{
        @"sessionId": @(sessionId),
        @"size": @(size),
        @"start": @(start),
        @"end": @(end)
    }];
}

// 文件同步完成
- (void)bleSyncFileTailWithSessionId:(int)sessionId crc:(int)crc
{
    NSLog(@"🍎 [PlaudBluetoothModule] bleSyncFileTail - sessionId:%d crc:%d", sessionId, crc);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudFileSyncTail" object:nil userInfo:@{
        @"sessionId": @(sessionId),
        @"crc": @(crc)
    }];
}

// 文件同步停止
- (void)bleSyncFileStop
{
    NSLog(@"🍎 [PlaudBluetoothModule] bleSyncFileStop");
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudFileSyncStop" object:nil userInfo:@{}];
}

// 添加delegate监控机制 - 更频繁的检查
- (void)startDelegateMonitoring
{
    // 每2秒检查一次delegate状态
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        while (YES) {
            sleep(2);
            dispatch_async(dispatch_get_main_queue(), ^{
                PlaudDeviceAgent *agent = [PlaudDeviceAgent shared];
                if (agent.delegate != self) {
                    NSLog(@"[RN] 🚨🚨🚨 DELEGATE WARNING Delegate has been changed! Current: %@, Expected: %@", agent.delegate, self);
                    // 重新设置delegate
                    agent.delegate = self;
                    NSLog(@"[RN] 🔧 DELEGATE FIX Restored delegate to PlaudBluetoothModule");
                } else {
                    NSLog(@"[RN] ✅ DELEGATE CHECK Delegate is correctly set: %@", agent.delegate);
                }
                
                // 额外检查：验证delegate是否响应我们的方法
                if (agent.delegate && [(id)agent.delegate respondsToSelector:@selector(bleRecordStartWithSessionId:start:status:scene:startTime:reason:)]) {
                    NSLog(@"[RN] ✅ METHOD CHECK Delegate responds to bleRecordStart");
                } else {
                    NSLog(@"[RN] ❌ METHOD CHECK Delegate does NOT respond to bleRecordStart!");
                }
            });
        }
    });
}

// 手动触发delegate状态检查
- (void)checkDelegateStatusNow
{
    // 简化的delegate检查，仅在需要时使用
    PlaudDeviceAgent *agent = [PlaudDeviceAgent shared];
    if (agent.delegate != self) {
        NSLog(@"[RN] ⚠️ Delegate changed, restoring...");
        agent.delegate = self;
    }
}

#pragma mark - Connection Completion Management

- (void)resetConnectionCompletionFlags
{
    self.hasReceivedDeviceState = NO;
    self.hasReceivedBatteryInfo = NO;
    self.hasReceivedStorageInfo = NO;
    self.hasReceivedFileList = NO;
}

- (void)fetchAllDeviceInfoAfterConnection
{
    NSLog(@"[RN] 📡 Fetching battery, storage and file info...");
    
    // 不重置状态标志，因为设备状态已经设置过了
    // [self resetConnectionCompletionFlags];
    
    // 立即获取电池和存储信息（设备状态已经在之前获取过了）
    NSLog(@"[RN] 🔋 Getting charging state...");
    [[PlaudDeviceAgent shared] getChargingState];
    
    NSLog(@"[RN] 💾 Getting storage info...");
    [[PlaudDeviceAgent shared] getStorage];
    
    NSLog(@"[RN] 📄 Getting file list...");
    [[PlaudDeviceAgent shared] getFileListWithStartSessionId:0];
}

- (void)checkConnectionCompletionStatus
{
    // 检查是否所有关键信息都已获取（仅用于内部状态跟踪）
    BOOL isBasicInfoComplete = self.hasReceivedDeviceState && 
                              self.hasReceivedBatteryInfo && 
                              self.hasReceivedStorageInfo;
    
    if (isBasicInfoComplete) {
        NSLog(@"[RN] ✅ All device info fetched in background!");
        // 重置标志，为下次连接准备
        [self resetConnectionCompletionFlags];
    } else {
        NSLog(@"[RN] ⏳ Background info fetching: state=%@, battery=%@, storage=%@", 
              self.hasReceivedDeviceState ? @"✅" : @"❌",
              self.hasReceivedBatteryInfo ? @"✅" : @"❌", 
              self.hasReceivedStorageInfo ? @"✅" : @"❌");
    }
}

@end
