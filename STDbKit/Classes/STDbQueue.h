//
//  STDbQueue.h
//  STDbKit
//
//  Created by stlwtr on 15/6/15.
//
// Version 2.2.1
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
//

#import <Foundation/Foundation.h>

@class STDb;

@interface STDbQueue : NSObject

/**
 *	@brief	数据库路径，不存在自动创建
 */
+ (instancetype)dbWithPath:(NSString *)path;

/**
 *	@brief	默认数据库路径
 */
+ (instancetype)defaultQueue;

/**
 *	@brief	数据库路径
 */
@property (nonatomic, strong, readonly) NSString *dbPath;

/**
 *	@brief	多线程执行方法
 */
- (void)execute:(void (^)(STDb *db))block;

@end
