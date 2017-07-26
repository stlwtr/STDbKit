//
//  STDbQueue.m
//  STDbKit
//
//  Created by stlwtr on 15/6/15.
//
// Version 2.3.0
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// emailto: 2008.yls@163.com
// QQ: 603291699
// https://github.com/stlwtr/STDbKit
//

#import "STDbQueue.h"
#import "STDb.h"

static const void * const kDispatchQueueSpecificKey = &kDispatchQueueSpecificKey;

@interface STDbQueue()
{
    STDb *_db;
    dispatch_queue_t _queue;
}
@end

@implementation STDbQueue

- (instancetype)initWithPath:(NSString *)filePath {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create([NSString stringWithFormat:@"com_stlwtr.db.%@", self].UTF8String, NULL);
        dispatch_queue_set_specific(_queue, kDispatchQueueSpecificKey, (__bridge void *)self, NULL);
        STDb *db = [STDb dbWithPath:filePath];
        self->_db = db;
    }
    return self;
}

- (NSString *)dbPath
{
    return _db.dbPath;
}

- (void)execute:(void (^)(STDb *db))block;
{
    STDbQueue *currentSyncQueue = (__bridge id)dispatch_get_specific(kDispatchQueueSpecificKey);
    assert(currentSyncQueue != self && "execute: was called reentrantly on the same queue, which would lead to a deadlock");
    
    dispatch_queue_t queue = self->_queue;
    
    dispatch_sync(queue, ^{
        STDb *db = self->_db;
        if (block) {
            block(db);
        }
    });
}

+ (instancetype)dbQueueWithPath:(NSString *)path;
{
    NSString *dbPath = [path stringByStandardizingPath];
    if (![dbPath isAbsolutePath]) {
        NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        dbPath = [docPath stringByAppendingFormat:@"/%@", dbPath];
    }
    
    NSString *pathExt = [dbPath pathExtension];
    NSString *filePath = dbPath;
    NSString *dirPath = dbPath;
    if (pathExt.length != 0) {
        dirPath = [dbPath stringByDeletingLastPathComponent];
    } else {
        filePath = [dbPath stringByAppendingPathComponent:STDbDefaultName];
    }
    
    NSError *error;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dirPath]) {
        BOOL rc = [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (!rc) {
            NSLog(@"%@", error);
        }
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        BOOL rc = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        if (!rc) {
            NSLog(@"create file %@ error.", filePath);
        }
    }
    STDbQueue *dbQueue = [[STDbQueue alloc] initWithPath:filePath];
    return dbQueue;
}

/**
 *	@brief	默认数据库路径
 */
+ (instancetype)defaultQueue {
    return [STDbQueue dbQueueWithPath:[STDb defaultDbPath]];
}

@end
