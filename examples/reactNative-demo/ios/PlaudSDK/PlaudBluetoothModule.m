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
@property (nonatomic, strong) BleDevice *connectingDevice; // Currently connecting device
@property (nonatomic, assign) BOOL isScanning;
// Real-time device status cache
@property (nonatomic, strong) NSMutableDictionary *deviceStateInfo;
@property (nonatomic, strong) NSMutableDictionary *storageInfo;
@property (nonatomic, strong) NSMutableDictionary *batteryInfo;

// Connection completion status tracking
@property (nonatomic, assign) BOOL hasReceivedDeviceState;
@property (nonatomic, assign) BOOL hasReceivedBatteryInfo;
@property (nonatomic, assign) BOOL hasReceivedStorageInfo;
@property (nonatomic, assign) BOOL hasReceivedFileList;

// Private method declarations
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
        // Don't set delegate during initialization, will set during startScan
        _discoveredDevices = [NSMutableArray array];
        _isScanning = NO;
        _connectedDevice = nil;
        _connectingDevice = nil;
        
        // Initialize real-time status cache
        _deviceStateInfo = [[NSMutableDictionary alloc] init];
        _storageInfo = [[NSMutableDictionary alloc] init];
        _batteryInfo = [[NSMutableDictionary alloc] init];
        
        // Initialize connection completion status flag
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
            
            // Key fix: set current module as unique delegate
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
            
            // Actively get device status information
            [[PlaudDeviceAgent shared] getState];
            
            // Actively get storage information
            [[PlaudDeviceAgent shared] getStorage];
            
            // Actively get charging status information
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
            
            // Save reference to connecting device
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

// Recording start callback - refer to native demo exact method signature
- (void)bleRecordStartWithSessionId:(NSInteger)sessionId 
                              start:(NSInteger)start 
                             status:(NSInteger)status 
                              scene:(NSInteger)scene 
                          startTime:(NSInteger)startTime 
                             reason:(NSInteger)reason
{
    NSLog(@"[RN] 🎙️ Recording started - sessionId:%ld scene:%ld reason:%ld", 
          (long)sessionId, (long)scene, (long)reason);
    
    // Send recording start notification
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
    
    // Test event sending
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
    
    // Send recording end notification
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
    
    // Send recording pause notification
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
    
    // Send recording resume notification
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
        // Use our saved connected device, try to get from SDK if none
        if (!self.connectingDevice) {
            self.connectedDevice = [PlaudDeviceAgent shared].recentConnectDevice;
            RCTLogInfo(@"🍎 Using SDK recentConnectDevice as fallback");
        } else {
            self.connectedDevice = self.connectingDevice;
        }
        
        RCTLogInfo(@"🍎 Connection established for device: %@", self.connectedDevice.serialNumber ?: @"unknown");
        
        // Notify other modules device connected (notify even if device object is nil, let other modules know connection status)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudDeviceConnected" object:self.connectedDevice];
        
        // Create device info dictionary, ensure not returning nil
        NSDictionary *deviceDict = [self deviceToDictionary:self.connectedDevice];
        if (!deviceDict) {
            deviceDict = @{
                @"id": @"unknown",
                @"name": @"Connected Device",
                @"serialNumber": @"unknown",
                @"isConnected": @YES
            };
        }
        
        // Immediately send connection success event
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
        
        // Reset connection completion flag, prepare for new connection
        [self resetConnectionCompletionFlags];
        
    } else if (state == 0 || state == 2) { // Disconnected or Failed
        BleDevice *lastDevice = self.connectedDevice;
        self.connectedDevice = nil;
        self.connectingDevice = nil; // Clean up connecting device reference
        
        // Notify other modules device disconnected
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

// Device status callback - refer to native demo DeviceInfoViewController implementation
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
    
    // Check delegate on every status change
    [self checkDelegateStatusNow];
    
    // Update device status cache
    [self.deviceStateInfo setObject:@{
        @"state": @(state),
        @"privacy": @(privacy),
        @"keyState": @(keyState),
        @"uDisk": @(uDisk),
        @"findMyToken": @(findMyToken),
        @"hasSndpKey": @(hasSndpKey),
        @"deviceAccessToken": @(deviceAccessToken),
        @"usbDiskMode": @(uDisk == 1), // USB disk mode
        @"usbAccessEnabled": @(privacy == 0), // USB access permission
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    } forKey:@"deviceState"];
    
    // Notify other modules device status update, pass complete status info
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudDeviceStateUpdated" 
                                                        object:nil
                                                      userInfo:self.deviceStateInfo[@"deviceState"]];
    
    // Send device status event to JS side
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendEventWithName:@"onDeviceStateChanged" body:self.deviceStateInfo[@"deviceState"]];
    });
    
    // Set device status received flag
    self.hasReceivedDeviceState = YES;
    
    // When device status callback triggers, device is fully initialized, now safe to get other info
    if (self.connectedDevice && !self.hasReceivedBatteryInfo && !self.hasReceivedStorageInfo) {
        NSLog(@"[RN] 📡 Device state received, now fetching battery and storage info...");
        [self fetchAllDeviceInfoAfterConnection];
    }
    
    [self checkConnectionCompletionStatus];
}

// Storage info callback
- (void)bleStorageWithTotal:(NSInteger)total free:(NSInteger)free duration:(NSInteger)duration
{
    RCTLogInfo(@"🍎 ✅ Storage info callback triggered - total:%ld free:%ld duration:%ld", (long)total, (long)free, (long)duration);
    
    NSInteger usedSpace = total - free;
    double usagePercent = total > 0 ? (double)usedSpace / total * 100.0 : 0.0;
    
    // Update storage info cache
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
    
    // Notify other modules storage info update
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudStorageInfoUpdated" object:self.storageInfo[@"storage"]];
    
    // Send storage info event to JS side
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendEventWithName:@"onStorageInfoUpdated" body:self.storageInfo[@"storage"]];
    });
    
    // Set storage info received flag
    self.hasReceivedStorageInfo = YES;
    [self checkConnectionCompletionStatus];
}

// Battery level change callback
- (void)blePowerChangeWithPower:(NSInteger)power oldPower:(NSInteger)oldPower
{
    RCTLogInfo(@"🍎 Battery power change - power:%ld oldPower:%ld", (long)power, (long)oldPower);
    
    // Get current charging status (from previous info)
    BOOL isCharging = [self.batteryInfo[@"battery"][@"isCharging"] boolValue];
    
    // Update battery info cache
    [self updateBatteryInfo:power isCharging:isCharging];
}

// Charging status callback
- (void)bleChargingStateWithIsCharging:(BOOL)isCharging level:(NSInteger)level
{
    RCTLogInfo(@"🍎 ✅ Charging state callback triggered - isCharging:%@ level:%ld", isCharging ? @"YES" : @"NO", (long)level);
    
    // Update battery info cache
    [self updateBatteryInfo:level isCharging:isCharging];
}

// File list callback - share data with file management module
- (void)bleFileListWithBleFiles:(NSArray<BleFile *> *)bleFiles
{
    RCTLogInfo(@"🍎 [BluetoothModule] File list received: %lu files", (unsigned long)bleFiles.count);
    
    if (!bleFiles || bleFiles.count == 0) {
        RCTLogInfo(@"🍎 [BluetoothModule] No files to process");
        return;
    }
    
    // Use notification center to notify file management module update file list
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudFileListUpdated" object:bleFiles];
    
    // Send file list update event
    NSMutableArray *filesArray = [NSMutableArray array];
    for (BleFile *file in bleFiles) {
        // Create file basic info dictionary
        NSDictionary *fileDict = @{
            @"sessionId": @(file.sessionId),
            @"fileSize": @(file.size),
            @"scene": @(file.scenes),
            @"createTime": @(file.sessionId), // sessionId is timestamp
            @"channels": @(file.channels ?: 1)
        };
        [filesArray addObject:fileDict];
    }
    
    [self sendEventWithName:@"onFileListUpdated" body:@{
        @"files": filesArray,
        @"totalFiles": @(filesArray.count),
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    }];
    
    // Set file list received flag
    self.hasReceivedFileList = YES;
}

#pragma mark - Helper Methods

// Unified method to update battery info
- (void)updateBatteryInfo:(NSInteger)level isCharging:(BOOL)isCharging
{
    NSString *batteryText;
    if (level >= 0 && level <= 100) {
        batteryText = [NSString stringWithFormat:@"%ld%%", (long)level];
    } else {
        batteryText = @"Unknown";
    }
    
    // Update battery info cache
    [self.batteryInfo setObject:@{
        @"batteryLevel": @(level),
        @"isCharging": @(isCharging),
        @"batteryText": batteryText,
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    } forKey:@"battery"];
    
    // Notify other modules battery info update
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudBatteryInfoUpdated" object:self.batteryInfo[@"battery"]];
    
    // Send battery info event to JS side
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendEventWithName:@"onBatteryInfoUpdated" body:self.batteryInfo[@"battery"]];
    });
    
    // Set battery info received flag
    self.hasReceivedBatteryInfo = YES;
    [self checkConnectionCompletionStatus];
}

// Format storage size - use 1000 as unit conversion, consistent with native demo  
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
        // Safely handle string properties
        NSString *safeUuid = (device.uuid && [device.uuid isKindOfClass:[NSString class]]) ? device.uuid : @"unknown";
        NSString *safeName = (device.name && [device.name isKindOfClass:[NSString class]]) ? device.name : @"Unknown Device";
        NSString *safeSerialNumber = (device.serialNumber && [device.serialNumber isKindOfClass:[NSString class]]) ? device.serialNumber : @"unknown";
        NSString *safeManufacturer = (device.manufacturer && [device.manufacturer isKindOfClass:[NSString class]]) ? device.manufacturer : @"unknown";
        
        // Try to get complete version info
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
        // Return most basic device info
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
    
    // Basic file info for event notification
    return @{
        @"sessionId": @(file.sessionId),
        @"fileSize": @(file.size),
        @"scene": @(file.scenes),
        @"sn": file.sn ?: @"",
        @"channels": @(file.channels)
    };
}

#pragma mark - File Download Delegate Methods

// Receive file download data and forward to file management module
- (void)bleDataWithSessionId:(int)sessionId start:(int)start data:(NSData *)data
{
    NSLog(@"🍎 [PlaudBluetoothModule] bleData - sessionId:%d start:%d dataSize:%lu", sessionId, start, (unsigned long)data.length);
    
    // Forward data to file management module notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudFileDataReceived" object:nil userInfo:@{
        @"sessionId": @(sessionId),
        @"start": @(start),
        @"data": data
    }];
}

// File sync header info
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

// File sync completed
- (void)bleSyncFileTailWithSessionId:(int)sessionId crc:(int)crc
{
    NSLog(@"🍎 [PlaudBluetoothModule] bleSyncFileTail - sessionId:%d crc:%d", sessionId, crc);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudFileSyncTail" object:nil userInfo:@{
        @"sessionId": @(sessionId),
        @"crc": @(crc)
    }];
}

// File sync stopped
- (void)bleSyncFileStop
{
    NSLog(@"🍎 [PlaudBluetoothModule] bleSyncFileStop");
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlaudFileSyncStop" object:nil userInfo:@{}];
}

// Add delegate monitoring mechanism - more frequent checks
- (void)startDelegateMonitoring
{
    // Check delegate status every 2 seconds
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        while (YES) {
            sleep(2);
            dispatch_async(dispatch_get_main_queue(), ^{
                PlaudDeviceAgent *agent = [PlaudDeviceAgent shared];
                if (agent.delegate != self) {
                    NSLog(@"[RN] 🚨🚨🚨 DELEGATE WARNING Delegate has been changed! Current: %@, Expected: %@", agent.delegate, self);
                    // Reset delegate
                    agent.delegate = self;
                    NSLog(@"[RN] 🔧 DELEGATE FIX Restored delegate to PlaudBluetoothModule");
                } else {
                    NSLog(@"[RN] ✅ DELEGATE CHECK Delegate is correctly set: %@", agent.delegate);
                }
                
                // Additional check: verify delegate responds to our methods
                if (agent.delegate && [(id)agent.delegate respondsToSelector:@selector(bleRecordStartWithSessionId:start:status:scene:startTime:reason:)]) {
                    NSLog(@"[RN] ✅ METHOD CHECK Delegate responds to bleRecordStart");
                } else {
                    NSLog(@"[RN] ❌ METHOD CHECK Delegate does NOT respond to bleRecordStart!");
                }
            });
        }
    });
}

// Manually trigger delegate status check
- (void)checkDelegateStatusNow
{
    // Simplified delegate check, use only when needed
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
    
    // Don't reset status flags because device status already set
    // [self resetConnectionCompletionFlags];
    
    // Immediately get battery and storage info (device status already obtained before)
    NSLog(@"[RN] 🔋 Getting charging state...");
    [[PlaudDeviceAgent shared] getChargingState];
    
    NSLog(@"[RN] 💾 Getting storage info...");
    [[PlaudDeviceAgent shared] getStorage];
    
    NSLog(@"[RN] 📄 Getting file list...");
    [[PlaudDeviceAgent shared] getFileListWithStartSessionId:0];
}

- (void)checkConnectionCompletionStatus
{
    // Check if all key info obtained (for internal status tracking only)
    BOOL isBasicInfoComplete = self.hasReceivedDeviceState && 
                              self.hasReceivedBatteryInfo && 
                              self.hasReceivedStorageInfo;
    
    if (isBasicInfoComplete) {
        NSLog(@"[RN] ✅ All device info fetched in background!");
        // Reset flags, prepare for next connection
        [self resetConnectionCompletionFlags];
    } else {
        NSLog(@"[RN] ⏳ Background info fetching: state=%@, battery=%@, storage=%@", 
              self.hasReceivedDeviceState ? @"✅" : @"❌",
              self.hasReceivedBatteryInfo ? @"✅" : @"❌", 
              self.hasReceivedStorageInfo ? @"✅" : @"❌");
    }
}

@end
