//
//  PlaudUploadModule.m
//  ReactNativeDemo
//
//  Created by Plaud Team on 2024/12/19.
//

#import "PlaudUploadModule.h"
#import <React/RCTLog.h>

@implementation PlaudUploadModule

RCT_EXPORT_MODULE(PlaudUpload);

- (NSArray<NSString *> *)supportedEvents {
    return @[@"onUploadProgress", @"onUploadComplete", @"onUploadError"];
}

RCT_EXPORT_METHOD(uploadFile:(NSString *)filePath
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    RCTLogInfo(@"[iOS] PlaudUploadModule uploadFile called with path: %@", filePath);
    
    @try {
        // TODO: Implement actual file upload logic
        // For now, simulate success
        
        NSDictionary *result = @{
            @"success": @YES,
            @"filePath": filePath,
            @"message": @"File uploaded successfully (iOS placeholder)"
        };
        
        resolve(result);
        
        // Send completion event
        [self sendEventWithName:@"onUploadComplete" body:@{
            @"filePath": filePath,
            @"success": @YES
        }];
        
    } @catch (NSException *exception) {
        RCTLogError(@"[iOS] PlaudUploadModule uploadFile error: %@", exception.reason);
        reject(@"UPLOAD_ERROR", [NSString stringWithFormat:@"Upload file error: %@", exception.reason], nil);
    }
}

RCT_EXPORT_METHOD(addListener:(NSString *)eventName)
{
    // Required for RCTEventEmitter
}

RCT_EXPORT_METHOD(removeListeners:(NSInteger)count)
{
    // Required for RCTEventEmitter
}

@end
