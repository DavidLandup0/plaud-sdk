//
//  PlaudLogRedirect.m
//  PlaudSDK
//
//  Created by Plaud Team on 2024/12/19.
//  Copyright © 2024 Plaud. All rights reserved.
//

#import "PlaudLogRedirect.h"
@import PenBleSDK;

@implementation PlaudLogRedirect

+ (void)saveNSLogToFile:(NSString *)message {
    // Use unified log saving function
    [self saveUnifiedLog:message level:@"NSLog"];
}

+ (void)saveUnifiedLog:(NSString *)message level:(NSString *)level {
    // Create formatted message with unified timestamp
    NSString *timestamp = [self getCurrentTimestamp];
    NSString *formattedMessage = [NSString stringWithFormat:@"[%@] [%@] %@", timestamp, level, message];
    
    // Save to Documents/PlaudLogs directory
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *documentsURL = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        NSURL *logsDirectory = [documentsURL URLByAppendingPathComponent:@"PlaudLogs"];
        
        // Create log directory
        NSError *error;
        [fileManager createDirectoryAtURL:logsDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        
        if (error) {
            return;
        }
        
        NSURL *logURL = [logsDirectory URLByAppendingPathComponent:@"plaud.log"];
        NSData *logData = [[formattedMessage stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
        
        // Check file size, rotate if exceeds configured limit
        if ([fileManager fileExistsAtPath:logURL.path]) {
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:logURL.path error:nil];
            NSNumber *fileSize = attributes[NSFileSize];
            
            // Use runtime reflection to access PlaudLogConfig
            long long maxFileSize = 10 * 1024 * 1024; // Default 10MB
            Class configClass = NSClassFromString(@"PlaudLogConfig");
            if (configClass) {
                id sharedInstance = [configClass performSelector:@selector(shared)];
                if (sharedInstance && [sharedInstance respondsToSelector:@selector(maxFileSize)]) {
                    maxFileSize = [[sharedInstance performSelector:@selector(maxFileSize)] longLongValue];
                }
            }
            
            // 使用统一的日志文件轮转管理器检查是否需要轮转
            // Objective-C通过反射调用PenBleSDK模块中的轮转管理器
            Class rotationManagerClass = NSClassFromString(@"PlaudLogFileRotationManager");
            if (rotationManagerClass) {
                id sharedInstance = [rotationManagerClass performSelector:@selector(shared)];
                if (sharedInstance && [sharedInstance respondsToSelector:@selector(checkAndRotateIfNeeded:additionalSize:)]) {
                    NSNumber *additionalSize = @([logData length]);
                    [sharedInstance performSelector:@selector(checkAndRotateIfNeeded:additionalSize:) 
                                         withObject:logURL.path 
                                         withObject:additionalSize];
                }
            } else {
                // 降级到原有逻辑（仅作为备用）
                if (fileSize && [fileSize longLongValue] + [logData length] > maxFileSize) {
                    // Rotate file
                    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
                    NSURL *rotatedURL = [logsDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"plaud_%.0f.log", timestamp]];
                    [fileManager moveItemAtURL:logURL toURL:rotatedURL error:nil];
                    
                    // Clean up old files
                    [self cleanupOldLogFilesInDirectory:logsDirectory];
                }
            }
        }
        
        if ([fileManager fileExistsAtPath:logURL.path]) {
            // Append to existing file
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:logURL error:&error];
            if (fileHandle) {
                [fileHandle seekToEndOfFile];
                [fileHandle writeData:logData];
                [fileHandle closeFile];
            }
        } else {
            // Create new file
            [logData writeToURL:logURL atomically:YES];
        }
    });
}

+ (void)cleanupOldLogFilesInDirectory:(NSURL *)directory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error;
    NSArray *files = [fileManager contentsOfDirectoryAtURL:directory
                                 includingPropertiesForKeys:@[NSURLCreationDateKey]
                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                                      error:&error];
    
    if (error) {
        return;
    }
    
    // Filter log files and sort by creation time
    NSArray *logFiles = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"lastPathComponent BEGINSWITH 'plaud_' AND pathExtension == 'log'"]];
    logFiles = [logFiles sortedArrayUsingComparator:^NSComparisonResult(NSURL *url1, NSURL *url2) {
        NSDate *date1 = nil, *date2 = nil;
        [url1 getResourceValue:&date1 forKey:NSURLCreationDateKey error:nil];
        [url2 getResourceValue:&date2 forKey:NSURLCreationDateKey error:nil];
        return [date2 compare:date1]; // Descending order
    }];
        
    // Delete files exceeding configured count
    NSInteger maxCount = 10; // Default
    NSTimeInterval maxAge = 7 * 24 * 60 * 60; // Default 7 days
    
    // Use runtime reflection to get configuration
    Class configClass = NSClassFromString(@"PlaudLogConfig");
    if (configClass) {
        id sharedInstance = [configClass performSelector:@selector(shared)];
        if (sharedInstance) {
            if ([sharedInstance respondsToSelector:@selector(maxFileCount)]) {
                maxCount = [[sharedInstance performSelector:@selector(maxFileCount)] integerValue];
            }
            if ([sharedInstance respondsToSelector:@selector(maxFileAge)]) {
                maxAge = [[sharedInstance performSelector:@selector(maxFileAge)] doubleValue];
            }
        }
    }
    
    if ([logFiles count] > maxCount) {
        for (NSInteger i = maxCount; i < [logFiles count]; i++) {
            [fileManager removeItemAtURL:logFiles[i] error:nil];
        }
    }
    
    // Delete files older than configured age
    NSDate *cutoffDate = [NSDate dateWithTimeIntervalSinceNow:-maxAge];
    for (NSURL *fileURL in logFiles) {
        NSDate *creationDate = nil;
        [fileURL getResourceValue:&creationDate forKey:NSURLCreationDateKey error:nil];
        if (creationDate && [creationDate compare:cutoffDate] == NSOrderedAscending) {
            [fileManager removeItemAtURL:fileURL error:nil];
        }
    }
}

+ (NSArray<NSString *> *)getAllLogFilePaths {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *logsDirectory = [documentsURL URLByAppendingPathComponent:@"PlaudLogs"];
    
    if (![fileManager fileExistsAtPath:logsDirectory.path]) {
        return @[];
    }
    
    NSError *error;
    NSArray *files = [fileManager contentsOfDirectoryAtURL:logsDirectory
                                 includingPropertiesForKeys:@[NSURLNameKey]
                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                                      error:&error];
    
    if (error) {
        return @[];
    }
    
    NSMutableArray *logFiles = [NSMutableArray array];
    for (NSURL *fileURL in files) {
        NSString *fileName = [fileURL lastPathComponent];
        if ([fileName hasPrefix:@"plaud"] && [fileName hasSuffix:@".log"]) {
            [logFiles addObject:[fileURL path]];
        }
    }
    
    return [logFiles copy];
}

+ (NSString *)getCurrentLogFilePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *logsDirectory = [documentsURL URLByAppendingPathComponent:@"PlaudLogs"];
    NSURL *logURL = [logsDirectory URLByAppendingPathComponent:@"plaud.log"];
    return logURL.path;
}

+ (void)cleanupLogFiles {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *logsDirectory = [documentsURL URLByAppendingPathComponent:@"PlaudLogs"];
    [self cleanupOldLogFilesInDirectory:logsDirectory];
}

+ (void)exportLogFilesToPath:(NSString *)destinationPath completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray<NSString *> *logFiles = [self getAllLogFilePaths];
        
        NSError *error = nil;
        
        // Ensure target directory exists
        if (![fileManager fileExistsAtPath:destinationPath]) {
            [fileManager createDirectoryAtPath:destinationPath
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&error];
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, error);
                });
                return;
            }
        }
        
        // Copy all log files
        for (NSString *logFilePath in logFiles) {
            NSString *fileName = [logFilePath lastPathComponent];
            NSString *destinationFilePath = [destinationPath stringByAppendingPathComponent:fileName];
            
            // If target file exists, delete it first
            if ([fileManager fileExistsAtPath:destinationFilePath]) {
                [fileManager removeItemAtPath:destinationFilePath error:nil];
            }
            
            [fileManager copyItemAtPath:logFilePath
                                 toPath:destinationFilePath
                                  error:&error];
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, error);
                });
                return;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES, nil);
        });
    });
}

#pragma mark - 内部时间戳函数

/// 获取共享的日期格式化器（性能优化）
+ (NSDateFormatter *)sharedTimestampFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone localTimeZone];
    });
    return formatter;
}

/// 获取当前时间戳字符串
+ (NSString *)getCurrentTimestamp {
    return [[self sharedTimestampFormatter] stringFromDate:[NSDate date]];
}

@end
