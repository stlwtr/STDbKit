//
//  DbObject.m
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
//
// emailto: 2008.yls@163.com
// QQ: 603291699
//

#import "STDbObject.h"
#import "STDbVersion.h"
#import "STDbQueue.h"
#import "STDb.h"

#import <objc/runtime.h>

#import "NSDate+STDbHandle.h"
#import "NSData+STDbHandle.h"

@implementation STDbObject

- (id)init
{
    self = [super init];
    if (self) {
        self.expireDate = [NSDate distantFuture];
        ___id__ = -1;
    }
    return self;
}

- (instancetype)initWithPrimaryValue:(NSInteger)_id;
{
    self = [self init];
    if (self) {
        ___id__ = _id;
    }
    return self;
}

/**
 *	@brief	插入到数据库中
 */
- (BOOL)insertToDb
{
    @synchronized(self){
        return [[STDb defaultDb] insertDbObject:self];
    }
}
- (BOOL)insertToDb:(STDb *)db
{
    return [db insertDbObject:self];
}

+ (NSInteger)lastRowId;
{
    return [[STDb defaultDb] lastRowIdWithClass:[self class]];
}
+ (NSInteger)lastRowIdInDb:(STDb *)db;
{
    return [db lastRowIdWithClass:[self class]];
}

- (BOOL)updateToDbsWhere:(NSString *)where NS_DEPRECATED(10_0, 10_4, 2_0, 2_0)
{
    @synchronized(self){
        return [[STDb defaultDb] updateDbObject:self condition:where];
    }
}

/**
 *	@brief	保证数据唯一
 */
- (BOOL)replaceToDb;
{
    @synchronized(self){
        return [[STDb defaultDb] replaceDbObject:self];
    }
}
- (BOOL)replaceToDb:(STDb *)db;
{
    @synchronized(self){
        return [db replaceDbObject:self];
    }
}

- (BOOL)updateToDb
{
    @synchronized(self){
        return [self updateToDb:[STDb defaultDb]];
    }
}
- (BOOL)updateToDb:(STDb *)db
{
    @synchronized(self){
        NSString *condition = [NSString stringWithFormat:@"%@=%@", kDbId, @(self.__id__)];
        return [db updateDbObject:self condition:condition];
    }
}

/**
 *	@brief	从数据库删除对象
 *
 *	@return	更新成功YES,否则NO
 */
- (BOOL)removeFromDb
{
    @synchronized(self){
        return [self removeFromDb:[STDb defaultDb]];
    }
}
- (BOOL)removeFromDb:(STDb *)db
{
    @synchronized(self){
        NSMutableArray *subDbObjects = [NSMutableArray arrayWithCapacity:0];
        [self subDbObjects:subDbObjects];
        
        for (STDbObject *dbObj in subDbObjects) {
            NSString *where = [NSString stringWithFormat:@"%@=%@", kDbId, @(dbObj.__id__)];
            [db removeDbObjects:[dbObj class] condition:where];
        }
        return YES;
    }
}

- (void)subDbObjects:(NSMutableArray *)subObj
{
    @synchronized(self){
        if (!self || ![self isKindOfClass:[STDbObject class]]) {
            return;
        }
        
        [subObj addObject:self];
        
        unsigned int count;
        STDbObject *obj = self;
        Class cls = [obj class];
        objc_property_t *properties = st_class_copyPropertyList(cls, &count);
        
        for (int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            NSString * key = [[NSString alloc]initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
            id value = [obj valueForKey:key];

            if (value && (NSNull *)value != [NSNull null] && [value isKindOfClass:[STDbObject class]]) {
                [subObj addObject:value];
            }
            
            if ([value isKindOfClass:[NSArray class]]) {
                for (STDbObject *obj in value) {
                    if (obj && (NSNull *)obj != [NSNull null] && [obj isKindOfClass:[STDbObject class]]) {
                        [subObj addObject:obj];
                    }
                }
            }
            
            if ([value isKindOfClass:[NSDictionary class]]) {
                for (NSString *key in value) {
                    STDbObject *obj = value[key];
                    if (obj && (NSNull *)obj != [NSNull null] && [obj isKindOfClass:[STDbObject class]]) {
                        [subObj addObject:obj];
                    }
                }
            }
        }
    }
}

/**
 *	@brief	查看是否包含对象
 *
 *	@param 	where 	条件
 *          例：name='xue zhang' and sex='男'
 *
 *	@return	包含YES,否则NO
 */
+ (BOOL)existDbObjectsWhere:(NSString *)where
{
    @synchronized(self){
        return [self existDbObjectsWhere:where db:[STDb defaultDb]];
    }
}
+ (BOOL)existDbObjectsWhere:(NSString *)where db:(STDb *)db
{
    @synchronized(self){
        NSArray *objs = [db selectDbObjects:[self class] condition:where orderby:nil];
        if ([objs count] > 0) {
            return YES;
        }
        return NO;
    }
}

/**
 *	@brief	删除某些数据
 *
 *	@param 	where 	条件
 *          例：name='xue zhang' and sex='男'
 *          填入 all 为全部删除
 *
 *	@return 成功YES,否则NO
 */
+ (BOOL)removeDbObjectsWhere:(NSString *)where
{
    return [self removeDbObjectsWhere:where db:[STDb defaultDb]];
}
+ (BOOL)removeDbObjectsWhere:(NSString *)where db:(STDb *)db
{
    @synchronized(self){
        return [db removeDbObjects:[self class] condition:where];
        return NO;
    }
}

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
+ (NSArray *)dbObjectsWhere:(NSString *)where orderby:(NSString *)orderby
{
    return [self dbObjectsWhere:where orderby:orderby db:[STDb defaultDb]];
}
+ (NSArray *)dbObjectsWhere:(NSString *)where orderby:(NSString *)orderby db:(STDb *)db
{
    @synchronized(self){
        return [db selectDbObjects:[self class] condition:where orderby:orderby];
    }
}

/**
 *	@brief	取出所有数据
 *
 *	@return	数据
 */
+ (NSMutableArray *)allDbObjects
{
    @synchronized(self){
        return [[STDb defaultDb] selectDbObjects:[self class] condition:@"all" orderby:nil];
    }
}
+ (NSMutableArray *)allDbObjectsInDb:(STDb *)db
{
    @synchronized(self){
        return [db selectDbObjects:[self class] condition:@"all" orderby:nil];
    }
}

/**
 *	@brief	objc to dictionary
 */
- (NSDictionary *)objcDictionary;
{
    @synchronized(self){
        unsigned int count;
        STDbObject *obj = self;

        Class cls = [obj class];
        objc_property_t *properties = st_class_copyPropertyList(cls, &count);

        NSMutableDictionary *retDict = [NSMutableDictionary dictionary];
        
        for (int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            NSString * key = [[NSString alloc]initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
            id value = [obj valueForKey:key];
            if (value) {
                [retDict setObject:value forKey:key];
            }
        }
        
        return retDict;
    }
}

/**
 *	@brief	objc from dictionary
 */
+ (STDbObject *)objcFromDictionary:(NSDictionary *)dict;
{
    @synchronized(self){
        STDbObject *obj = [[[self class] alloc] init];
        
        unsigned int count;
        
        Class cls = [obj class];
        objc_property_t *properties = st_class_copyPropertyList(cls, &count);

        for (int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            NSString * key = [[NSString alloc]initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
            id value = [dict objectForKey:key];
            if (value) {
                [obj setValue:value forKey:key];
            }
        }
        return obj;
    }
}

@end

