//
//  PlaudFileManagerModule.m
//  ReactNativeDemo
//
//  Created by Plaud Team on 2024/12/19.
//

#import "PlaudFileManagerModule.h"
#import <React/RCTLog.h>
@import PlaudDeviceBasicSDK;
@import PenBleSDK;

@interface PlaudFileManagerModule () <PlaudDeviceAgentProtocol>
@property (nonatomic, strong) NSMutableArray<BleFile *> *deviceFiles;
@property (nonatomic, strong) NSMutableDictionary *downloadProgress;
@property (nonatomic, strong) BleDevice *currentConnectedDevice;
// Cache real-time device information
@property (nonatomic, strong) NSDictionary *cachedDeviceState;
@property (nonatomic, strong) NSDictionary *cachedStorageInfo;
@property (nonatomic, strong) NSDictionary *cachedBatteryInfo;
@end

@implementation PlaudFileManagerModule

RCT_EXPORT_MODULE(PlaudFileManager);

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[
        @"onDownloadProgress",
        @"onDownloadComplete",
        @"onDownloadCompleted",
        @"onDownloadError",
        @"onFileListUpdated"
    ];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Don't set delegate during initialization to avoid conflicts with Bluetooth module
        // Delegate will be set when file operations are actually needed
        _deviceFiles = [NSMutableArray array];
        _downloadProgress = [NSMutableDictionary dictionary];
        
        // Listen for file list update notifications from Bluetooth module
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleFileListUpdated:)
                                                     name:@"PlaudFileListUpdated"
                                                   object:nil];
        
        // Listen for device connection/disconnection notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDeviceConnected:)
                                                     name:@"PlaudDeviceConnected"
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDeviceDisconnected:)
                                                     name:@"PlaudDeviceDisconnected"
                                                   object:nil];
        
        // Listen for device status update notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleDeviceStateUpdated:)
                                                     name:@"PlaudDeviceStateUpdated"
                                                   object:nil];
        
        // Listen for storage information update notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleStorageInfoUpdated:)
                                                     name:@"PlaudStorageInfoUpdated"
                                                   object:nil];
        
        // Listen for battery information update notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleBatteryInfoUpdated:)
                                                     name:@"PlaudBatteryInfoUpdated"
                                                   object:nil];
        
        // Listen for file list update notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleFileListUpdated:)
                                                     name:@"PlaudFileListUpdated"
                                                   object:nil];
        
        // Listen for file download related notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleFileDataReceived:)
                                                     name:@"PlaudFileDataReceived"
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleFileSyncHead:)
                                                     name:@"PlaudFileSyncHead"
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleFileSyncTail:)
                                                     name:@"PlaudFileSyncTail"
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleFileSyncStop:)
                                                     name:@"PlaudFileSyncStop"
                                                   object:nil];
        
        // No longer set delegate - changed to rely on PlaudBluetoothModule as unique delegate
        // [PlaudDeviceAgent shared].delegate = self; // Removed: avoid overriding PlaudBluetoothModule's delegate
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notification Handlers

- (void)handleFileListUpdated:(NSNotification *)notification
{
    NSArray<BleFile *> *files = notification.object;
    if ([files isKindOfClass:[NSArray class]]) {
        RCTLogInfo(@"🍎 [FileManagerModule] Received file list notification with %lu files", (unsigned long)files.count);
        [self updateFileList:files];
    } else {
        RCTLogError(@"🍎 [FileManagerModule] Invalid file list notification object: %@", notification.object);
    }
}

- (void)handleDeviceConnected:(NSNotification *)notification
{
    BleDevice *connectedDevice = notification.object;
    if ([connectedDevice isKindOfClass:[BleDevice class]]) {
        RCTLogInfo(@"🍎 [FileManagerModule] Device connected: %@", connectedDevice.serialNumber ?: @"unknown");
        self.currentConnectedDevice = connectedDevice;
    }
}

- (void)handleDeviceDisconnected:(NSNotification *)notification
{
    RCTLogInfo(@"🍎 [FileManagerModule] Device disconnected");
    self.currentConnectedDevice = nil;
    // Clear cached device information
    self.cachedDeviceState = nil;
    self.cachedStorageInfo = nil;
    self.cachedBatteryInfo = nil;
}

- (void)handleDeviceStateUpdated:(NSNotification *)notification
{
    NSDictionary *deviceState = notification.object;
    if ([deviceState isKindOfClass:[NSDictionary class]]) {
        RCTLogInfo(@"🍎 [FileManagerModule] Device state updated: %@", deviceState);
        self.cachedDeviceState = deviceState;
    }
}

- (void)handleStorageInfoUpdated:(NSNotification *)notification
{
    NSDictionary *storageInfo = notification.object;
    if ([storageInfo isKindOfClass:[NSDictionary class]]) {
        RCTLogInfo(@"🍎 [FileManagerModule] Storage info updated: %@", storageInfo);
        self.cachedStorageInfo = storageInfo;
    }
}

- (void)handleBatteryInfoUpdated:(NSNotification *)notification
{
    NSDictionary *batteryInfo = notification.object;
    if ([batteryInfo isKindOfClass:[NSDictionary class]]) {
        RCTLogInfo(@"🍎 [FileManagerModule] Battery info updated: %@", batteryInfo);
        self.cachedBatteryInfo = batteryInfo;
    }
}

#pragma mark - React Native Methods

RCT_EXPORT_METHOD(getFileList:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Getting device file list");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Return current existing file list (managed by Bluetooth module)
            // Or return empty list, let application know it needs to get through other means
            NSMutableArray *filesArray = [NSMutableArray array];
            for (BleFile *file in self.deviceFiles) {
                [filesArray addObject:[self fileToDictionary:file]];
            }
            
            NSDictionary *result = @{
                @"success": @YES,
                @"files": filesArray,
                @"totalFiles": @(filesArray.count),
                @"message": filesArray.count > 0 ? @"File list retrieved successfully" : @"No files available or not connected"
            };
            
            RCTLogInfo(@"🍎 Returning %lu files from cache", (unsigned long)filesArray.count);
            resolve(result);
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Get file list failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"FILE_LIST_ERROR", errorMessage, nil);
        }
    });
}

// Share file using system share sheet
RCT_EXPORT_METHOD(shareFile:(NSString *)filePath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:filePath]) {
            reject(@"FILE_NOT_FOUND", @"File not found", nil);
            return;
        }
        
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        NSArray *itemsToShare = @[fileURL];
        
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
        
        // Find the root view controller
        UIViewController *rootVC = [UIApplication sharedApplication].delegate.window.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        
        // Configure for iPad
        if ([activityVC respondsToSelector:@selector(popoverPresentationController)]) {
            activityVC.popoverPresentationController.sourceView = rootVC.view;
            activityVC.popoverPresentationController.sourceRect = CGRectMake(rootVC.view.bounds.size.width/2, rootVC.view.bounds.size.height/2, 0, 0);
        }
        
        [rootVC presentViewController:activityVC animated:YES completion:^{
            resolve(@{@"success": @YES, @"message": @"Share sheet presented"});
        }];
    });
}

RCT_EXPORT_METHOD(downloadFile:(double)sessionId
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Starting file download for sessionId: %.0f", sessionId);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            NSInteger sessionIdInt = (NSInteger)sessionId;
            
            // Find the file
            BleFile *targetFile = nil;
            for (BleFile *file in self.deviceFiles) {
                if (file.sessionId == sessionIdInt) {
                    targetFile = file;
                    break;
                }
            }
            
            if (!targetFile) {
                reject(@"FILE_NOT_FOUND", @"File not found", nil);
                return;
            }
            
            // Create download directory - save to Application Support directory
            // This is the recommended location for app-internal data that should persist
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
            NSString *appSupportPath = [paths objectAtIndex:0];
            NSString *downloadDir = [appSupportPath stringByAppendingPathComponent:@"Recordings"];
            
            RCTLogInfo(@"🍎 Download directory (Application Support): %@", downloadDir);
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if (![fileManager fileExistsAtPath:downloadDir]) {
                [fileManager createDirectoryAtPath:downloadDir withIntermediateDirectories:YES attributes:nil error:nil];
            }
            
            // Generate filename
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
            NSString *timestamp = [formatter stringFromDate:[NSDate date]];
            NSString *fileName = [NSString stringWithFormat:@"recording_%ld_%@.mp3", (long)sessionIdInt, timestamp];
            NSString *filePath = [downloadDir stringByAppendingPathComponent:fileName];
            
            // Initialize download progress
            self.downloadProgress[@(sessionIdInt)] = @0;
            
            // Start file size monitoring for progress
            [self startMonitoringDownloadProgress:sessionIdInt filePath:filePath];
            
            // Start download via device agent
            // This will trigger bleData callbacks to receive data chunks
            [[PlaudDeviceAgent shared] downloadFileWithSessionId:sessionIdInt desiredOutputPath:filePath];
            
            resolve(@{
                @"success": @YES,
                @"sessionId": @(sessionId),
                @"fileName": fileName,
                @"filePath": filePath,
                @"message": @"File download started"
            });
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Download file failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"DOWNLOAD_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(deleteFile:(double)sessionId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Deleting file with sessionId: %.0f", sessionId);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            NSInteger sessionIdInt = (NSInteger)sessionId;
            
            // Find the file
            BleFile *targetFile = nil;
            for (BleFile *file in self.deviceFiles) {
                if (file.sessionId == sessionIdInt) {
                    targetFile = file;
                    break;
                }
            }
            
            if (!targetFile) {
                reject(@"FILE_NOT_FOUND", @"File not found", nil);
                return;
            }
            
            // Delete file via device agent
            [[PlaudDeviceAgent shared] deleteFileWithSessionId:sessionIdInt];
            
            // Remove from local array
            [self.deviceFiles removeObject:targetFile];
            
            resolve(@{
                @"success": @YES,
                @"sessionId": @(sessionId),
                @"message": @"File deleted successfully"
            });
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Delete file failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"DELETE_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(clearAllFiles:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Clearing all files from device");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Clear all files via device agent
            [[PlaudDeviceAgent shared] clearAllFiles];
            
            // Clear local array
            [self.deviceFiles removeAllObjects];
            
            resolve(@{
                @"success": @YES,
                @"message": @"All files cleared successfully"
            });
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Clear all files failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"CLEAR_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(getStorageInfo:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Getting device storage info");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Prioritize using cached real-time storage info
            if (self.cachedStorageInfo) {
                RCTLogInfo(@"🍎 Using cached storage info");
                NSMutableDictionary *result = [self.cachedStorageInfo mutableCopy];
                result[@"success"] = @YES;
                result[@"message"] = @"Real-time storage info retrieved successfully";
                resolve(result);
                return;
            }
            
            // Use connected device info to calculate storage space
            BleDevice *connectedDevice = self.currentConnectedDevice;
            if (!connectedDevice) {
                // Return default values when device not connected, avoid JS errors
                NSDictionary *defaultResult = @{
                    @"success": @YES,
                    @"totalSpace": @(0),
                    @"usedSpace": @(0),
                    @"freeSpace": @(0),
                    @"totalSpaceText": @"--",
                    @"usedSpaceText": @"--",
                    @"freeSpaceText": @"--",
                    @"usagePercent": @(0),
                    @"message": @"Device not connected"
                };
                resolve(defaultResult);
                return;
            }
            
            NSInteger totalSpace = connectedDevice.total;
            NSInteger freeSpace = connectedDevice.free;
            NSInteger usedSpace = totalSpace - freeSpace;
            
            // Format size text
            NSString *totalSpaceText = [self formatBytes:totalSpace];
            NSString *usedSpaceText = [self formatBytes:usedSpace];
            NSString *freeSpaceText = [self formatBytes:freeSpace];
            
            double usagePercent = totalSpace > 0 ? (double)usedSpace / totalSpace * 100.0 : 0.0;
            
            NSDictionary *result = @{
                @"success": @YES,
                @"totalSpace": @(totalSpace),
                @"usedSpace": @(usedSpace),
                @"freeSpace": @(freeSpace),
                @"totalSpaceText": totalSpaceText,
                @"usedSpaceText": usedSpaceText,
                @"freeSpaceText": freeSpaceText,
                @"usagePercent": @(usagePercent),
                @"message": @"Storage info retrieved successfully"
            };
            
            resolve(result);
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Get storage info failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"STORAGE_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(getDeviceState:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Getting device state");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            BleDevice *connectedDevice = self.currentConnectedDevice;
            
            NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
            
            if (!connectedDevice) {
                // Return default status when device not connected, rather than reject
                result = [@{
                    @"success": @YES,
                    @"isRecording": @NO,
                    @"isConnected": @NO,
                    @"deviceId": @"unknown",
                    @"serialNumber": @"unknown",
                    @"usbDiskMode": @NO,
                    @"usbAccessEnabled": @NO,
                    @"message": @"Device not connected, returning default state"
                } mutableCopy];
            } else {
                // Device connected, return actual status
                result = [@{
                    @"success": @YES,
                    @"isRecording": @NO,
                    @"isConnected": @YES,
                    @"deviceId": connectedDevice.uuid ?: @"unknown",
                    @"serialNumber": connectedDevice.serialNumber ?: @"unknown",
                    @"usbDiskMode": @NO,
                    @"usbAccessEnabled": @NO,
                    @"message": @"Device state retrieved successfully"
                } mutableCopy];
                
                // If there's cached device status, include USB mode info
                if (self.cachedDeviceState) {
                    result[@"usbDiskMode"] = self.cachedDeviceState[@"usbDiskMode"] ?: @NO;
                    result[@"usbAccessEnabled"] = self.cachedDeviceState[@"usbAccessEnabled"] ?: @NO;
                    result[@"message"] = @"Device state with real-time USB info retrieved successfully";
                }
            }
            
            resolve(result);
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Get device state failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"DEVICE_STATE_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(getBatteryStatus:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Getting battery status");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Prioritize using cached real-time battery info
            if (self.cachedBatteryInfo) {
                RCTLogInfo(@"🍎 Using cached battery info");
                NSMutableDictionary *result = [self.cachedBatteryInfo mutableCopy];
                result[@"success"] = @YES;
                result[@"charging"] = result[@"isCharging"]; // Maintain API compatibility
                result[@"message"] = @"Real-time battery info retrieved successfully";
                resolve(result);
                return;
            }
            
            BleDevice *connectedDevice = self.currentConnectedDevice;
            if (!connectedDevice) {
                // Return default battery status when device not connected
                NSDictionary *defaultResult = @{
                    @"success": @YES,
                    @"batteryLevel": @(-1),
                    @"charging": @NO,
                    @"batteryText": @"Unknown",
                    @"message": @"Device not connected"
                };
                resolve(defaultResult);
                return;
            }
            
            NSInteger batteryLevel = connectedDevice.power;
            BOOL isCharging = connectedDevice.isCharging;
            
            NSString *batteryText;
            if (batteryLevel >= 0 && batteryLevel <= 100) {
                batteryText = [NSString stringWithFormat:@"%ld%%", (long)batteryLevel];
            } else {
                batteryText = @"Unknown";
            }
            
            NSDictionary *result = @{
                @"success": @YES,
                @"batteryLevel": @(batteryLevel),
                @"charging": @(isCharging),
                @"batteryText": batteryText,
                @"message": @"Battery status retrieved successfully"
            };
            
            resolve(result);
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Get battery status failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"BATTERY_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(getDeviceVersion:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Getting device version");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            BleDevice *connectedDevice = self.currentConnectedDevice;
            if (!connectedDevice) {
                // Return default version info when device not connected
                NSDictionary *defaultResult = @{
                    @"success": @YES,
                    @"versionName": @"Unknown version",
                    @"versionCode": @(0),
                    @"message": @"Device not connected"
                };
                resolve(defaultResult);
                return;
            }
            
            // Use device.wholeVersion() method to get real firmware version
            NSString *versionName = [connectedDevice wholeVersion] ?: @"v1.0.0";
            
            NSDictionary *result = @{
                @"success": @YES,
                @"versionName": versionName,
                @"versionCode": @(100),
                @"message": @"Device version retrieved successfully"
            };
            
            resolve(result);
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Get device version failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"VERSION_ERROR", errorMessage, nil);
        }
    });
}

#pragma mark - PlaudDeviceAgentDelegate (File Events)

- (void)onFileListReceived:(NSArray<BleFile *> *)files
{
    RCTLogInfo(@"🍎 File list received: %lu files", (unsigned long)files.count);
    
    self.deviceFiles = [files mutableCopy];
    
    // Convert to dictionary array
    NSMutableArray *filesArray = [NSMutableArray array];
    for (BleFile *file in files) {
        [filesArray addObject:[self fileToDictionary:file]];
    }
    
    [self sendEventWithName:@"onFileListUpdated" body:@{
        @"files": filesArray,
        @"totalFiles": @(filesArray.count),
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    }];
}

- (void)onDownloadProgress:(BleFile *)file progress:(NSInteger)bytesDownloaded totalBytes:(NSInteger)totalBytes
{
    self.downloadProgress[@(file.sessionId)] = @(bytesDownloaded);
    
    [self sendEventWithName:@"onDownloadProgress" body:@{
        @"sessionId": @(file.sessionId),
        @"downloadedBytes": @(bytesDownloaded),
        @"totalBytes": @(totalBytes),
        @"progress": @((double)bytesDownloaded / totalBytes),
        @"fileName": [self generateFileName:file],
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    }];
}

- (void)onDownloadComplete:(BleFile *)file filePath:(NSString *)filePath
{
    RCTLogInfo(@"🍎 Download complete: sessionId %ld -> %@", (long)file.sessionId, filePath);
    
    [self.downloadProgress removeObjectForKey:@(file.sessionId)];
    
    // Get file size
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attrs = [fileManager attributesOfItemAtPath:filePath error:nil];
    NSNumber *fileSize = [attrs objectForKey:NSFileSize];
    
    [self sendEventWithName:@"onDownloadComplete" body:@{
        @"sessionId": @(file.sessionId),
        @"filePath": filePath,
        @"fileName": [filePath lastPathComponent],
        @"fileSize": fileSize ?: @0,
        @"message": @"File download completed",
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    }];
}

- (void)onDownloadError:(BleFile *)file error:(NSString *)error
{
    RCTLogError(@"🍎 Download error for sessionId %ld: %@", (long)file.sessionId, error);
    
    [self.downloadProgress removeObjectForKey:@(file.sessionId)];
    
    [self sendEventWithName:@"onDownloadError" body:@{
        @"sessionId": @(file.sessionId),
        @"error": error,
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    }];
}

// SDK data transfer callback - implement file saving logic similar to native demo
- (void)bleDataWithSessionId:(NSInteger)sessionId start:(NSInteger)start data:(NSData *)data
{
    RCTLogInfo(@"🍎 Download data received: sessionId:%ld start:%ld dataSize:%lu", (long)sessionId, (long)start, (unsigned long)data.length);
    
    // Get documents directory and file path
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths objectAtIndex:0];
    NSString *fileName = [NSString stringWithFormat:@"%ld.dat", (long)sessionId];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName];
    
    // Use file handle for data writing (similar to native demo PLBleFileManager)
    if (start == 0) {
        // First write, create new file
        [data writeToFile:filePath atomically:YES];
    } else {
        // Subsequent writes, append data
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
        if (fileHandle) {
            [fileHandle seekToFileOffset:start];
            [fileHandle writeData:data];
            [fileHandle closeFile];
        }
    }
    
    // Accumulate downloaded bytes
    NSInteger totalDownloaded = start + data.length;
    self.downloadProgress[@(sessionId)] = @(totalDownloaded);
    
    // Find corresponding file to get total size
    BleFile *targetFile = nil;
    for (BleFile *file in self.deviceFiles) {
        if (file.sessionId == sessionId) {
            targetFile = file;
            break;
        }
    }
    
    if (targetFile) {
        // Send download progress event
        [self sendEventWithName:@"onDownloadProgress" body:@{
            @"sessionId": @(sessionId),
            @"downloadedBytes": @(totalDownloaded),
            @"totalBytes": @(targetFile.size),
            @"progress": @((double)totalDownloaded / targetFile.size),
            @"fileName": [NSString stringWithFormat:@"recording_%ld.dat", (long)sessionId],
            @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
        }];
        
        // Check if download is completed
        if (totalDownloaded >= targetFile.size) {
            RCTLogInfo(@"🍎 Download completed for sessionId: %ld", (long)sessionId);
            [self.downloadProgress removeObjectForKey:@(sessionId)];
            
            // Send download completion event
            [self sendEventWithName:@"onDownloadComplete" body:@{
                @"sessionId": @(sessionId),
                @"filePath": filePath,
                @"fileName": fileName,
                @"fileSize": @(totalDownloaded),
                @"message": @"Raw file download completed (DAT format)",
                @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
            }];
        }
    }
}

#pragma mark - Private Methods

- (void)updateFileList:(NSArray<BleFile *> *)files
{
    RCTLogInfo(@"🍎 [FileManagerModule] Updating file list with %lu files", (unsigned long)files.count);
    self.deviceFiles = [files mutableCopy];
    
    // Notify JS side file list updated
    NSMutableArray *filesArray = [NSMutableArray array];
    for (BleFile *file in files) {
        [filesArray addObject:[self fileToDictionary:file]];
    }
    
    [self sendEventWithName:@"onFileListUpdated" body:@{
        @"files": filesArray,
        @"totalFiles": @(filesArray.count),
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    }];
}

#pragma mark - Helper Methods

- (NSDictionary *)fileToDictionary:(BleFile *)file
{
    if (!file) return nil;
    
    // Calculate duration based on file format and size
    NSInteger durationSeconds = 0;
    
    // Debug: Log file format information
    RCTLogInfo(@"🍎 File format debug - sessionId:%ld size:%ld isOgg:%@ channels:%ld", 
               (long)file.sessionId, (long)file.size, file.isOgg ? @"YES" : @"NO", (long)file.channels);
    
    // For OPUS/compressed files, use empirical calculation based on typical bitrates
    // OPUS for speech typically uses 32-64 kbps (4-8 KB/s)
    // For 16kHz mono speech, a reasonable estimate is ~5 KB/s
    if (file.isOgg || file.size < 1000000) { // Likely compressed format
        NSInteger estimatedBytesPerSecond = 5000; // 5 KB/s for OPUS speech
        durationSeconds = file.size / estimatedBytesPerSecond;
        RCTLogInfo(@"🍎 Using compressed format calculation: %ld bytes / %ld bytes/sec = %ld seconds", 
                   (long)file.size, (long)estimatedBytesPerSecond, (long)durationSeconds);
    } else {
        // For raw PCM files: 16kHz * 2 bytes (16-bit) * channels
        NSInteger bytesPerSecond = 16000 * 2 * (file.channels > 0 ? file.channels : 1);
        durationSeconds = file.size / bytesPerSecond;
        RCTLogInfo(@"🍎 Using PCM format calculation: %ld bytes / %ld bytes/sec = %ld seconds", 
                   (long)file.size, (long)bytesPerSecond, (long)durationSeconds);
    }
    
    // Format duration as MM:SS
    NSInteger minutes = durationSeconds / 60;
    NSInteger seconds = durationSeconds % 60;
    NSString *durationString = [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
    
    // Format file size - use 1000 as unit conversion, consistent with native demo
    NSString *sizeText;
    if (file.size < 1000) {
        sizeText = [NSString stringWithFormat:@"%ld B", (long)file.size];
    } else if (file.size < 1000 * 1000) {
        sizeText = [NSString stringWithFormat:@"%.1f KB", file.size / 1000.0];
    } else {
        sizeText = [NSString stringWithFormat:@"%.1f MB", file.size / (1000.0 * 1000.0)];
    }
    
    // Format creation time using sessionId timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSDate *createDate = [NSDate dateWithTimeIntervalSince1970:file.sessionId]; // sessionId is timestamp
    NSString *createTime = [formatter stringFromDate:createDate];
    
    // Scene name mapping
    NSString *sceneName = @"Recording";
    switch (file.scenes) {
        case 1: sceneName = @"Meeting"; break;
        case 2: sceneName = @"Classroom"; break;
        case 3: sceneName = @"Interview"; break;
        case 4: sceneName = @"Music"; break;
        case 5: sceneName = @"Memo"; break;
        default: sceneName = @"Recording"; break;
    }
    
    @try {
        // Safely handle string properties
        NSString *safeSn = (file.sn && [file.sn isKindOfClass:[NSString class]]) ? file.sn : @"";
        
        return @{
            @"sessionId": @(file.sessionId),
            @"fileSize": @(file.size),
            @"scene": @(file.scenes),
            @"sceneName": sceneName,
            @"duration": durationString,
            @"sizeText": sizeText,
            @"createTime": createTime,
            @"channels": @(file.channels),
            @"sn": safeSn,
            @"timezone": @(file.timezone),
            @"isOgg": @(file.isOgg),
            @"nsAgc": @(file.nsAgc)
        };
        
    } @catch (NSException *exception) {
        RCTLogError(@"🍎 Error in fileToDictionary: %@", exception.reason);
        // Return most basic file info
        return @{
            @"sessionId": @(file.sessionId),
            @"fileSize": @(file.size),
            @"scene": @(file.scenes),
            @"sceneName": @"Recording",
            @"duration": @"00:00",
            @"sizeText": @"0 B",
            @"createTime": @"1970-01-01 00:00:00",
            @"channels": @(file.channels),
            @"sn": @"",
            @"timezone": @(file.timezone),
            @"isOgg": @(file.isOgg),
            @"nsAgc": @(file.nsAgc)
        };
    }
}

- (NSString *)generateFileName:(BleFile *)file
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    return [NSString stringWithFormat:@"recording_%ld_%@.opus", (long)file.sessionId, timestamp];
}

- (NSString *)formatBytes:(NSInteger)bytes
{
    // Use 1000 as unit conversion, consistent with native demo
    if (bytes < 1000) {
        return [NSString stringWithFormat:@"%ld B", (long)bytes];
    } else if (bytes < 1000 * 1000) {
        return [NSString stringWithFormat:@"%.1f KB", bytes / 1000.0];
    } else if (bytes < 1000 * 1000 * 1000) {
        return [NSString stringWithFormat:@"%.1f MB", bytes / (1000.0 * 1000.0)];
    } else {
        return [NSString stringWithFormat:@"%.2f GB", bytes / (1000.0 * 1000.0 * 1000.0)];
    }
}

// Monitor download progress by checking file size
- (void)startMonitoringDownloadProgress:(NSInteger)sessionId filePath:(NSString *)filePath
{
    // Find target file size
    BleFile *targetFile = nil;
    for (BleFile *file in self.deviceFiles) {
        if (file.sessionId == sessionId) {
            targetFile = file;
            break;
        }
    }
    
    if (!targetFile) {
        RCTLogError(@"🍎 Cannot find target file for sessionId: %ld", (long)sessionId);
        return;
    }
    
    NSInteger expectedSize = targetFile.size;
    RCTLogInfo(@"🍎 Starting download progress monitoring for sessionId:%ld expectedSize:%ld", (long)sessionId, (long)expectedSize);
    
    // Create a timer to check file size periodically
    NSTimer *progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // Debug: Always log to see if timer is running
        RCTLogInfo(@"🍎 Timer check: sessionId:%ld filePath:%@", (long)sessionId, filePath);
        
        if ([fileManager fileExistsAtPath:filePath]) {
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
            NSNumber *fileSize = [attributes objectForKey:NSFileSize];
            NSInteger currentSize = fileSize.integerValue;
            
            RCTLogInfo(@"🍎 File exists with size: %ld bytes", (long)currentSize);
            
            if (currentSize > 0) {
                // Update progress
                self.downloadProgress[@(sessionId)] = @(currentSize);
                
                double progress = (double)currentSize / expectedSize;
                if (progress > 1.0) progress = 1.0;
                
                RCTLogInfo(@"🍎 Download progress: sessionId:%ld currentSize:%ld expectedSize:%ld progress:%.2f", 
                          (long)sessionId, (long)currentSize, (long)expectedSize, progress);
                
                // Send progress event
                [self sendEventWithName:@"onDownloadProgress" body:@{
                    @"sessionId": @(sessionId),
                    @"downloadedBytes": @(currentSize),
                    @"totalBytes": @(expectedSize),
                    @"progress": @(progress),
                    @"fileName": [filePath lastPathComponent],
                    @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
                }];
                
                // Stop timer if download is complete
                if (currentSize >= expectedSize) {
                    [timer invalidate];
                    RCTLogInfo(@"🍎 Download progress monitoring completed for sessionId:%ld", (long)sessionId);
                    
                    // Check if file actually exists and log details
                    BOOL fileExists = [fileManager fileExistsAtPath:filePath];
                    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:nil];
                    NSNumber *actualFileSize = [fileAttributes objectForKey:NSFileSize];
                    
                    RCTLogInfo(@"🍎 📁 File completion check:");
                    RCTLogInfo(@"🍎 📁 File exists: %@", fileExists ? @"YES" : @"NO");
                    RCTLogInfo(@"🍎 📁 File path: %@", filePath);
                    RCTLogInfo(@"🍎 📁 File size: %@ bytes", actualFileSize);
                    RCTLogInfo(@"🍎 📁 Directory listing:");
                    
                    // List directory contents
                    NSString *parentDir = [filePath stringByDeletingLastPathComponent];
                    NSArray *dirContents = [fileManager contentsOfDirectoryAtPath:parentDir error:nil];
                    for (NSString *file in dirContents) {
                        RCTLogInfo(@"🍎 📁   - %@", file);
                    }
                    
                    // Send download completion event
                    [self sendEventWithName:@"onDownloadCompleted" body:@{
                        @"sessionId": @(sessionId),
                        @"success": @YES,
                        @"filePath": filePath,
                        @"fileName": [filePath lastPathComponent],
                        @"finalSize": actualFileSize ?: @(currentSize),
                        @"fileExists": @(fileExists),
                        @"message": @"File download completed successfully"
                    }];
                }
            }
        } else {
            RCTLogInfo(@"🍎 File does not exist yet: %@", filePath);
        }
    }];
    
    // Store timer to invalidate later if needed
    static NSMutableDictionary *progressTimers = nil;
    if (!progressTimers) {
        progressTimers = [NSMutableDictionary dictionary];
    }
    progressTimers[@(sessionId)] = progressTimer;
    
    // Auto-cleanup timer after reasonable time (5 minutes)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSTimer *timer = progressTimers[@(sessionId)];
        if (timer && timer.isValid) {
            [timer invalidate];
            [progressTimers removeObjectForKey:@(sessionId)];
            RCTLogInfo(@"🍎 Download progress timer auto-cleanup for sessionId:%ld", (long)sessionId);
        }
    });
}

#pragma mark - File Download Notification Handlers

// Handle file data forwarded from PlaudBluetoothModule
- (void)handleFileDataReceived:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    int sessionId = [userInfo[@"sessionId"] intValue];
    int start = [userInfo[@"start"] intValue];
    NSData *data = userInfo[@"data"];
    
    NSLog(@"🍎 [FileManager] Received file data - sessionId:%d start:%d dataSize:%lu", sessionId, start, (unsigned long)data.length);
    
    // Call original bleData method logic
    [self bleDataWithSessionId:sessionId start:start data:data];
}

// Handle file sync header info
- (void)handleFileSyncHead:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    int sessionId = [userInfo[@"sessionId"] intValue];
    int size = [userInfo[@"size"] intValue];
    int start = [userInfo[@"start"] intValue];
    int end = [userInfo[@"end"] intValue];
    
    NSLog(@"🍎 [FileManager] File sync head - sessionId:%d size:%d start:%d end:%d", sessionId, size, start, end);
    
    // Sync header processing logic can be added here
}

// Handle file sync completion
- (void)handleFileSyncTail:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    int sessionId = [userInfo[@"sessionId"] intValue];
    int crc = [userInfo[@"crc"] intValue];
    
    NSLog(@"🍎 [FileManager] File sync tail - sessionId:%d crc:%d", sessionId, crc);
    
    // Call file sync completion logic
    [self bleSyncFileTailWithSessionId:sessionId crc:crc];
}

// Handle file sync stop
- (void)handleFileSyncStop:(NSNotification *)notification
{
    NSLog(@"🍎 [FileManager] File sync stopped");
    
    // Call sync stop logic
    [self bleSyncFileStop];
}

#pragma mark - PlaudDeviceAgentProtocol

// bleDataWithSessionId:start:data: method already implemented above

// Empty implementation of other required delegate methods
- (void)bleConnectStateWithState:(NSInteger)state {}
- (void)bleBindWithSn:(NSString *)sn status:(NSInteger)status protVersion:(NSInteger)protVersion timezone:(NSInteger)timezone {}
- (void)blePenStateWithState:(NSInteger)state privacy:(NSInteger)privacy keyState:(NSInteger)keyState uDisk:(NSInteger)uDisk findMyToken:(NSInteger)findMyToken hasSndpKey:(NSInteger)hasSndpKey deviceAccessToken:(NSInteger)deviceAccessToken {}
- (void)bleStorageWithTotal:(NSInteger)total free:(NSInteger)free duration:(NSInteger)duration {}
- (void)blePowerChangeWithPower:(NSInteger)power oldPower:(NSInteger)oldPower {}
- (void)bleChargingStateWithIsCharging:(BOOL)isCharging level:(NSInteger)level {}
- (void)bleFileListWithBleFiles:(NSArray<BleFile *> *)bleFiles {}
- (void)bleDataCompleteWithSessionId:(NSInteger)sessionId {}
- (void)bleDownloadFileWithSessionId:(NSInteger)sessionId desiredOutputPath:(NSString *)desiredOutputPath status:(NSInteger)status progress:(NSInteger)progress tips:(NSString *)tips {}
- (void)bleSyncFileHeadWithSessionId:(NSInteger)sessionId status:(NSInteger)status {}
- (void)bleSyncFileTailWithSessionId:(NSInteger)sessionId crc:(NSInteger)crc {}
- (void)bleDeleteFileWithSessionId:(NSInteger)sessionId status:(NSInteger)status {}

@end
