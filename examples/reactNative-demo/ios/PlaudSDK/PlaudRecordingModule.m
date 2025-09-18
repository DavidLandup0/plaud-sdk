//
//  PlaudRecordingModule.m
//  ReactNativeDemo
//
//  Created by Plaud Team on 2024/12/19.
//

#import "PlaudRecordingModule.h"
#import <React/RCTLog.h>
@import PlaudDeviceBasicSDK;
@import PenBleSDK;

@interface PlaudRecordingModule () <PlaudDeviceAgentProtocol>
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, strong) NSNumber *currentSessionId;
@end

@implementation PlaudRecordingModule

RCT_EXPORT_MODULE(PlaudRecording);

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[
        @"onRecordingStarted",
        @"onRecordingPaused", 
        @"onRecordingResumed",
        @"onRecordingStopped",
        @"onRecordingProgress",
        @"onRecordingError"
    ];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _isRecording = NO;
        _isPaused = NO;
        
        // Don't set delegate directly, but listen to notifications
        // Register device status update notifications
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleDeviceStateChanged:) 
                                                     name:@"PlaudDeviceStateUpdated" 
                                                   object:nil];
        
        // Register dedicated recording status notifications
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleRecordingStarted:) 
                                                     name:@"PlaudRecordingStarted" 
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleRecordingStopped:) 
                                                     name:@"PlaudRecordingStopped" 
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleRecordingPaused:) 
                                                     name:@"PlaudRecordingPaused" 
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(handleRecordingResumed:) 
                                                     name:@"PlaudRecordingResumed" 
                                                   object:nil];
        
        RCTLogInfo(@"🍎 PlaudRecordingModule initialized with notification listener");
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notification Handlers

- (void)handleDeviceStateChanged:(NSNotification *)notification
{
    NSDictionary *stateInfo = notification.userInfo;
    if (stateInfo) {
        NSNumber *keyStateNum = stateInfo[@"keyState"];
        NSNumber *stateNum = stateInfo[@"state"];
        NSNumber *privacyNum = stateInfo[@"privacy"];
        
        if (keyStateNum) {
            NSInteger keyState = [keyStateNum integerValue];
            NSInteger state = [stateNum integerValue];
            NSInteger privacy = [privacyNum integerValue];
            
            RCTLogInfo(@"🍎 [Recording] Received device state notification - keyState:%ld state:%ld privacy:%ld", 
                      (long)keyState, (long)state, (long)privacy);
            
            // Use same logic to handle recording status
            [self handleRecordingStateChange:keyState];
        }
    }
}

- (void)handleRecordingStateChange:(NSInteger)keyState
{
    // Determine recording status based on keyState
    // Need to confirm actual keyState values corresponding to status
    RCTLogInfo(@"🎙️ [Recording] Processing keyState: %ld, current isRecording: %@, isPaused: %@", 
              (long)keyState, self.isRecording ? @"YES" : @"NO", self.isPaused ? @"YES" : @"NO");
    
    if (keyState == 2) {
        // Currently recording
        if (!self.isRecording) {
            // Start recording from idle
            self.isRecording = YES;
            self.isPaused = NO;
            [self sendEventWithName:@"onRecordingStarted" body:@{
                @"success": @YES,
                @"recording": @YES,
                @"sessionId": self.currentSessionId ?: @([[NSDate date] timeIntervalSince1970]),
                @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
            }];
            RCTLogInfo(@"🎙️ Recording started event sent");
        } else if (self.isPaused) {
            // Resume recording from pause
            self.isPaused = NO;
            [self sendEventWithName:@"onRecordingResumed" body:@{
                @"success": @YES,
                @"recording": @YES,
                @"paused": @NO,
                @"sessionId": self.currentSessionId,
                @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
            }];
            RCTLogInfo(@"🎙️ Recording resumed event sent");
        }
    } else if (keyState == 1) {
        // Recording paused
        if (self.isRecording && !self.isPaused) {
            self.isPaused = YES;
            [self sendEventWithName:@"onRecordingPaused" body:@{
                @"success": @YES,
                @"recording": @YES,
                @"paused": @YES,
                @"sessionId": self.currentSessionId,
                @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
            }];
            RCTLogInfo(@"⏸️ Recording paused event sent");
        }
    } else if (keyState == 0) {
        // Idle state (recording ended)
        if (self.isRecording) {
            NSNumber *sessionId = self.currentSessionId;
            self.isRecording = NO;
            self.isPaused = NO;
            self.currentSessionId = nil;
            
            [self sendEventWithName:@"onRecordingStopped" body:@{
                @"success": @YES,
                @"recording": @NO,
                @"sessionId": sessionId ?: @([[NSDate date] timeIntervalSince1970]),
                @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
            }];
            RCTLogInfo(@"🛑 Recording stopped event sent");
        }
    } else {
        // Handle unknown keyState values
        RCTLogInfo(@"🎙️ [Recording] Unknown keyState: %ld - no action taken", (long)keyState);
    }
}

#pragma mark - Recording Notification Handlers

- (void)handleRecordingStarted:(NSNotification *)notification
{
    NSDictionary *recordingInfo = notification.userInfo;
    if (recordingInfo) {
        NSNumber *sessionId = recordingInfo[@"sessionId"];
        NSNumber *status = recordingInfo[@"status"];
        NSNumber *scene = recordingInfo[@"scene"];
        
        RCTLogInfo(@"🎙️ [Recording] Received recording started notification - sessionId:%@ status:%@ scene:%@", 
                  sessionId, status, scene);
        
        self.isRecording = YES;
        self.isPaused = NO;
        self.currentSessionId = sessionId;
        
        [self sendEventWithName:@"onRecordingStarted" body:@{
            @"success": @YES,
            @"recording": @YES,
            @"sessionId": sessionId ?: @([[NSDate date] timeIntervalSince1970]),
            @"status": status ?: @0,
            @"scene": scene ?: @1,
            @"timestamp": recordingInfo[@"timestamp"] ?: @([[NSDate date] timeIntervalSince1970] * 1000)
        }];
        RCTLogInfo(@"🎙️ Recording started event sent to JS");
    }
}

- (void)handleRecordingStopped:(NSNotification *)notification
{
    NSDictionary *recordingInfo = notification.userInfo;
    if (recordingInfo) {
        NSNumber *sessionId = recordingInfo[@"sessionId"];
        NSNumber *status = recordingInfo[@"status"];
        
        RCTLogInfo(@"🎙️ [Recording] Received recording stopped notification - sessionId:%@ status:%@", 
                  sessionId, status);
        
        NSNumber *currentSessionId = self.currentSessionId;
        self.isRecording = NO;
        self.isPaused = NO;
        self.currentSessionId = nil;
        
        [self sendEventWithName:@"onRecordingStopped" body:@{
            @"success": @YES,
            @"recording": @NO,
            @"sessionId": sessionId ?: currentSessionId ?: @([[NSDate date] timeIntervalSince1970]),
            @"status": status ?: @0,
            @"timestamp": recordingInfo[@"timestamp"] ?: @([[NSDate date] timeIntervalSince1970] * 1000)
        }];
        RCTLogInfo(@"🛑 Recording stopped event sent to JS");
    }
}

- (void)handleRecordingPaused:(NSNotification *)notification
{
    NSDictionary *recordingInfo = notification.userInfo;
    if (recordingInfo) {
        NSNumber *sessionId = recordingInfo[@"sessionId"];
        
        RCTLogInfo(@"🎙️ [Recording] Received recording paused notification - sessionId:%@", sessionId);
        
        self.isPaused = YES;
        // Keep isRecording = YES during pause
        
        [self sendEventWithName:@"onRecordingPaused" body:@{
            @"success": @YES,
            @"recording": @YES,
            @"paused": @YES,
            @"sessionId": sessionId ?: self.currentSessionId ?: @([[NSDate date] timeIntervalSince1970]),
            @"timestamp": recordingInfo[@"timestamp"] ?: @([[NSDate date] timeIntervalSince1970] * 1000)
        }];
        RCTLogInfo(@"⏸️ Recording paused event sent to JS");
    }
}

- (void)handleRecordingResumed:(NSNotification *)notification
{
    NSDictionary *recordingInfo = notification.userInfo;
    if (recordingInfo) {
        NSNumber *sessionId = recordingInfo[@"sessionId"];
        
        RCTLogInfo(@"🎙️ [Recording] Received recording resumed notification - sessionId:%@", sessionId);
        
        self.isPaused = NO;
        // Keep isRecording = YES after resume
        
        [self sendEventWithName:@"onRecordingResumed" body:@{
            @"success": @YES,
            @"recording": @YES,
            @"paused": @NO,
            @"sessionId": sessionId ?: self.currentSessionId ?: @([[NSDate date] timeIntervalSince1970]),
            @"timestamp": recordingInfo[@"timestamp"] ?: @([[NSDate date] timeIntervalSince1970] * 1000)
        }];
        RCTLogInfo(@"▶️ Recording resumed event sent to JS");
    }
}

#pragma mark - React Native Methods

RCT_EXPORT_METHOD(startRecording:(NSString *)deviceId
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Starting recording for device: %@ with options: %@", deviceId, options);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (self.isRecording) {
                resolve(@{
                    @"success": @YES,
                    @"recording": @YES,
                    @"message": @"Already recording",
                    @"sessionId": self.currentSessionId ?: [NSNull null]
                });
                return;
            }
            
            // Extract recording options
            NSString *quality = options[@"quality"] ?: @"high";
            NSString *format = options[@"format"] ?: @"opus";
            NSNumber *channel = options[@"channel"] ?: @1;
            NSNumber *sessionId = options[@"sessionId"];
            
            // Start recording via device agent
            [[PlaudDeviceAgent shared] startRecord];
            
            // Use provided session ID or generate one
            self.currentSessionId = sessionId ?: @([[NSDate date] timeIntervalSince1970]);
            self.isRecording = YES;
            self.isPaused = NO;
            
            NSDictionary *result = @{
                @"success": @YES,
                @"recording": @YES,
                @"deviceId": deviceId,
                @"sessionId": self.currentSessionId,
                @"quality": quality,
                @"format": format,
                @"channel": channel,
                @"message": @"Recording started successfully"
            };
            
            [self sendEventWithName:@"onRecordingStarted" body:result];
            resolve(result);
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Start recording failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            
            [self sendEventWithName:@"onRecordingError" body:@{
                @"error": errorMessage,
                @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
            }];
            
            reject(@"RECORDING_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(pauseRecording:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Pausing recording");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.isRecording || self.isPaused) {
                resolve(@{
                    @"success": @YES,
                    @"recording": @(self.isRecording),
                    @"paused": @(self.isPaused),
                    @"message": @"Recording not active or already paused"
                });
                return;
            }
            
            // Pause recording via device agent
            [[PlaudDeviceAgent shared] pauseRecord];
            self.isPaused = YES;
            
            NSDictionary *result = @{
                @"success": @YES,
                @"recording": @YES,
                @"paused": @YES,
                @"sessionId": self.currentSessionId,
                @"message": @"Recording paused"
            };
            
            [self sendEventWithName:@"onRecordingPaused" body:result];
            resolve(result);
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Pause recording failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"RECORDING_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(resumeRecording:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Resuming recording");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.isRecording || !self.isPaused) {
                resolve(@{
                    @"success": @YES,
                    @"recording": @(self.isRecording),
                    @"paused": @(self.isPaused),
                    @"message": @"Recording not paused"
                });
                return;
            }
            
            // Resume recording via device agent
            [[PlaudDeviceAgent shared] resumeRecord];
            self.isPaused = NO;
            
            NSDictionary *result = @{
                @"success": @YES,
                @"recording": @YES,
                @"paused": @NO,
                @"sessionId": self.currentSessionId,
                @"message": @"Recording resumed"
            };
            
            [self sendEventWithName:@"onRecordingResumed" body:result];
            resolve(result);
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Resume recording failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"RECORDING_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(stopRecording:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"🍎 Stopping recording");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.isRecording) {
                resolve(@{
                    @"success": @YES,
                    @"recording": @NO,
                    @"message": @"Recording not active"
                });
                return;
            }
            
            // Stop recording via device agent
            [[PlaudDeviceAgent shared] stopRecord];
            
            NSNumber *finalSessionId = self.currentSessionId;
            self.isRecording = NO;
            self.isPaused = NO;
            self.currentSessionId = nil;
            
            NSDictionary *result = @{
                @"success": @YES,
                @"recording": @NO,
                @"sessionId": finalSessionId,
                @"message": @"Recording stopped successfully"
            };
            
            [self sendEventWithName:@"onRecordingStopped" body:result];
            resolve(result);
            
        } @catch (NSException *exception) {
            NSString *errorMessage = [NSString stringWithFormat:@"Stop recording failed: %@", exception.reason];
            RCTLogError(@"❌ %@", errorMessage);
            reject(@"RECORDING_ERROR", errorMessage, nil);
        }
    });
}

RCT_EXPORT_METHOD(getRecordingStatus:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        resolve(@{
            @"success": @YES,
            @"recording": @(self.isRecording),
            @"paused": @(self.isPaused),
            @"sessionId": self.currentSessionId ?: [NSNull null]
        });
        
    } @catch (NSException *exception) {
        reject(@"STATUS_ERROR", exception.reason, nil);
    }
}

#pragma mark - PlaudDeviceAgentDelegate (Recording Events)

- (void)onRecordingStart:(NSNumber *)sessionId
{
    RCTLogInfo(@"🍎 Recording started callback: %@", sessionId);
    
    self.currentSessionId = sessionId;
    self.isRecording = YES;
    self.isPaused = NO;
    
    [self sendEventWithName:@"onRecordingStarted" body:@{
        @"success": @YES,
        @"recording": @YES,
        @"sessionId": sessionId,
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    }];
}

- (void)onRecordingStop:(NSNumber *)sessionId
{
    RCTLogInfo(@"🍎 Recording stopped callback: %@", sessionId);
    
    self.isRecording = NO;
    self.isPaused = NO;
    self.currentSessionId = nil;
    
    [self sendEventWithName:@"onRecordingStopped" body:@{
        @"success": @YES,
        @"recording": @NO,
        @"sessionId": sessionId,
        @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000)
    }];
}

- (void)onRecordingProgress:(NSDictionary *)progress
{
    // Send recording progress updates
    NSMutableDictionary *progressData = [progress mutableCopy];
    progressData[@"timestamp"] = @([[NSDate date] timeIntervalSince1970] * 1000);
    
    [self sendEventWithName:@"onRecordingProgress" body:progressData];
}

// Note: Original delegate methods have been removed, now receive recording status changes through notification mechanism

@end
