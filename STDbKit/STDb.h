//
//  STDb.h
//  STDbObject
//
//  Created by stlwtr on 13-12-5.
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

/**
 * 如果要打开数据库加密，打开下面的注释
 */
//#define STDBEncryptEnable 1

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@class STDbObject;

typedef void (^STDbExecuteCallBackBlock)(NSArray *resultArray);
extern NSString *STDbDefaultName;
extern objc_property_t * st_class_copyPropertyList(Class cls, unsigned int *count);

@interface STDb : NSObject

/**
 *	@brief	从外部导入数据库
 *
 *	@param 	dbName 	数据库名称（dbName.db）
 */
+ (void)importDb:(NSString *)dbName  __attribute__ ((deprecated));

/**
 *	@brief	设置数据库路径，方便支持多db应用
 *
 *	@param 	dbPath 	数据库路径
 *
 *  @descrpition 在应用启动或登录时设置，如果数据库文件不存在，
    自动创建，如果存在，则直接使用该数据库文件
 */
+ (BOOL)setCurrentDbPath:(NSString *)dbPath __attribute__ ((deprecated));

/**
 *	@brief	数据库路径
 */
+ (NSString *)currentDbPath __attribute__ ((deprecated));

/**
 *	@brief	数据库路径，不存在自动创建
 */
+ (instancetype)dbWithPath:(NSString *)path;

/**
 *	@brief	默认数据库
 */
+ (instancetype)defaultDb;

/**
 *	@brief	默认数据库路径
 */
+ (NSString *)defaultDbPath;

/**
 *	@brief	数据库路径
 */
@property (nonatomic, strong, readonly) NSString *dbPath;

/**
 *	@brief	是否进行字段加密
 */
@property (nonatomic, assign) BOOL encryptEnable;

/**
 *	@brief	执行select方法
 */
- (BOOL)executeQuery:(NSString *)query resultBlock:(STDbExecuteCallBackBlock)block;

/**
 *	@brief	执行create, update, delete方法
 */
- (BOOL)executeQuery:(NSString *)query;
- (BOOL)executeUpdate:(NSString*)query;
- (BOOL)executeUpdate:(NSString*)query dictionaryArgs:(NSDictionary *)dictionaryArgs;


#pragma mark - transaction

- (BOOL)beginTransaction;
- (BOOL)commit;
- (BOOL)rollback;
- (BOOL)inTransaction;

#pragma mark - STDbObject method

/**
 *	@brief	根据条件查询数据
 *
 *	@param 	aClass 	表相关类
 *	@param 	condition 	条件（nil或空或all为无条件），例 id=5 and name='yls'
 *                      带条数限制条件:id=5 and name='yls' limit 5
 *	@param 	orderby 	排序（nil或空或no为不排序）, 例 id,name
 *
 *	@return	数据对象数组
 */
- (NSMutableArray *)selectDbObjects:(Class)aClass condition:(NSString *)condition orderby:(NSString *)orderby;

/**
 *	@brief	插入一条数据
 *
 *	@param 	obj 	数据对象
 */
- (BOOL)insertDbObject:(STDbObject *)obj;

/**
 *	@brief	仅插入一条数据
 *
 *	@param 	obj 	数据对象
 */
- (BOOL)replaceDbObject:(STDbObject *)obj;

/**
 *	@brief	更新一条数据
 *
 *	@param 	obj 	数据对象
 */
- (BOOL)updateDbObject:(STDbObject *)obj condition:(NSString *)condition;

/**
 *	@brief	remove object from aClass
 *
 *	@param 	aClass 	数据对象
 *	@param 	condition 	删除条件
 */
- (BOOL)removeDbObjects:(Class)aClass condition:(NSString *)condition;

/**
 *	@brief	last row in table named aClass
 */
- (NSInteger)lastRowIdWithClass:(Class)aClass;

- (NSInteger)localVersionForClass:(Class)cls;
- (BOOL)setDbVersion:(NSInteger)version toDbObjectClass:(Class)cls;

- (BOOL)upgradeTableIfNeed:(Class)cls;

@end
