//
//  DbObject.h
//  STQuickKit
//
//  Created by yls on 13-11-21.
//
// Version 1.0.4
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

#import <Foundation/Foundation.h>

#define kDbId           @"__id__"
#define kDbKeySuffix    @"__key__"

#define key( __p__ ) [NSString stringWithFormat:@"%@%@", __p__, kDbKeySuffix]

@protocol STDbObject

@required

/**
 *	@brief	对象id，唯一标志
 */
@property (assign, nonatomic, readonly) NSInteger __id__;

/**
 *	@brief	父对象id，唯一标志
 */
@property (assign, nonatomic, readonly) NSInteger __pid__;

/**
 *	@brief	子对象id，唯一标志
 */
@property (assign, nonatomic, readonly) NSInteger __cid__;

/**
 *	@brief	失效日期
 */
@property (strong, nonatomic) NSDate *expireDate;

/**
 *	@brief	插入到数据库中
 */
- (BOOL)insertToDb;

/**
 *	@brief	保证数据唯一
 */
- (BOOL)replaceToDb;
    
/**
 *	@brief	更新某些数据
 *
 *	@param 	where 	条件
 *          例：name='xue zhang' and sex='男'
 *
 */
- (BOOL)updateToDbsWhere:(NSString *)where NS_DEPRECATED(10_0, 10_4, 2_0, 2_0);

/**
 *	@brief	更新数据到数据库中
 *
 *	@return	更新成功YES,否则NO
 */
- (BOOL)updatetoDb;

/**
 *	@brief	从数据库删除对象
 *
 *	@return	更新成功YES,否则NO
 */
- (BOOL)removeFromDb;

/**
 *	@brief	查看是否包含对象
 *
 *	@param 	where 	条件
 *          例：name='xue zhang' and sex='男'
 *
 *	@return	包含YES,否则NO
 */
+ (BOOL)existDbObjectsWhere:(NSString *)where;

/**
 *	@brief	删除某些数据
 *
 *	@param 	where 	条件
 *          例：name='xue zhang' and sex='男'
 *          填入 all 为全部删除
 *
 *	@return 成功YES,否则NO
 */
+ (BOOL)removeDbObjectsWhere:(NSString *)where;

/**
 *	@brief	根据条件取出某些数据
 *
 *	@param 	where 	条件
 *          例：name='xue zhang' and sex='男'
 *          填入 all 为全部
 *
 *	@param 	orderby 	排序
 *          例：name and age
 *
 *	@return	数据
 */
+ (NSMutableArray *)dbObjectsWhere:(NSString *)where orderby:(NSString *)orderby;

/**
 *	@brief	取出所有数据
 *
 *	@return	数据
 */
+ (NSMutableArray *)allDbObjects;

/*
 * 查看最后插入数据的行号
 */
+ (NSInteger)lastRowId;

@end

@interface STDbObject : NSObject<STDbObject>

/**
 *	@brief	对象id，唯一标志
 */
@property (assign, nonatomic, readonly) NSInteger __id__;

/**
 *	@brief	父对象id，唯一标志
 */
@property (assign, nonatomic, readonly) NSInteger __pid__;

/**
 *	@brief	子对象id，唯一标志
 */
@property (assign, nonatomic, readonly) NSInteger __cid__;

/**
 *	@brief	失效日期
 */
@property (strong, nonatomic) NSDate *expireDate;

/**
 *	@brief	objc to dictionary
 */
- (NSDictionary *)objcDictionary;

/**
 *	@brief	objc from dictionary
 */
- (STDbObject *)objcFromDictionary:(NSDictionary *)dict;

@end

