//
//  PlaudLogRedirect.h
//  PlaudSDK
//
//  Created by Plaud Team on 2024/12/19.
//  Copyright © 2024 Plaud. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Macro definition for redirecting NSLog to file
/// Usage: #import "PlaudLogRedirect.h" in files that need redirection
/// Then use PLAUD_NSLOG(@"message") instead of NSLog(@"message")
/// Note: This macro outputs to both console and saves to file

#define PLAUD_NSLOG(format, ...) \
    do { \
        NSString *message = [NSString stringWithFormat:format, ##__VA_ARGS__]; \
        NSLog(@"%@", message); \
        [PlaudLogRedirect saveNSLogToFile:message]; \
    } while(0)

/// Log redirection manager
@interface PlaudLogRedirect : NSObject

/// Save NSLog message to file
/// @param message Log message
+ (void)saveNSLogToFile:(NSString *)message;

/// Get all log file paths
/// @return Array of log file paths
+ (NSArray<NSString *> *)getAllLogFilePaths;

/// Get current log file path
/// @return Current log file path
+ (NSString *)getCurrentLogFilePath;

/// Manually clean up log files
+ (void)cleanupLogFiles;

/// Export log files to specified directory
/// @param destinationPath Target directory path
/// @param completion Completion callback
+ (void)exportLogFilesToPath:(NSString *)destinationPath completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END