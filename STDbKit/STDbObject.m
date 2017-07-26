//
//  DbObject.m
//  STQuickKit
//
//  Created by stlwtr on 13-11-21.
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

#import "STDbObject.h"
#import "STDbVersion.h"
#import "STDbQueue.h"
#import "STDb.h"

#import <objc/runtime.h>

#import "NSDate+STDbHandle.h"
#import "NSData+STDbHandle.h"
#import "STDbObjectProperty.h"
#import "NSObject+STDbHandle.h"

static const char * kSTDbClassPrimaryPropertyNameKey;

#pragma mark - class static variables



@implementation STDbObject

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @autoreleasepool {
            [self __setup__];
        }
    });
}

- (id)init
{
    self = [super init];
    if (self) {
        self.expireDate = [NSDate distantFuture];
        ___id__ = [STDbObject random];
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
    @synchronized(self) {
        NSString *condition = [self primaryConditionString];
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
            NSString *condition = [self primaryConditionString];
            [db removeDbObjects:[dbObj class] condition:condition];
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
 *	@brief	select all data from db
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

+ (NSInteger)dbVersion
{
    return 0;
}

+ (NSArray *)properties {
    return [self __properties__];
}

+ (NSArray *)primaryKeys {
    return [self __primaryKeys];
}

#pragma mark - Private Method

+ (NSArray *)__properties__ {
    NSDictionary* classProperties = objc_getAssociatedObject(self.class, &kSTDbClassPropertiesKey);
    if (classProperties) return [classProperties allValues];
    
    [self __setup__];
    
    classProperties = objc_getAssociatedObject(self.class, &kSTDbClassPropertiesKey);
    return [classProperties allValues];
}

+ (NSArray *)__primaryKeys {
    NSMutableArray *primaryKeys = [NSMutableArray array];
    NSArray *properties = [self __properties__];
    for (STDbObjectProperty *p in properties) {
        if (p.isPrimaryKey) {
            [primaryKeys addObject:p.name];
        }
    }

    return primaryKeys;
}

- (NSString *)primaryConditionString {
    NSArray *primaryKeys = [self.class __primaryKeys];
    NSMutableArray *conditionArray = [NSMutableArray array];
    
    for (NSString *key in primaryKeys) {
        NSString *keyValue = [NSString stringWithFormat:@"%@='%@'", key, [self valueForKey:key]];
        [conditionArray addObject:keyValue];
    }
    NSString *condition = [conditionArray componentsJoinedByString:@" and "];
    return condition;
}

+ (void)__setup__
{
    if (!objc_getAssociatedObject(self.class, &kSTDbClassPropertiesKey)) {
        [self __inspectProperties];
    }
}

+ (void)__inspectProperties
{
    NSMutableDictionary* propertyIndex = [NSMutableDictionary dictionary];

    Class class = [self class];
    NSScanner* scanner = nil;
    NSString* propertyType = nil;
    
    while ([class isSubclassOfClass:[STDbObject class]]) {
        
        unsigned int propertyCount;
        objc_property_t *properties = class_copyPropertyList(class, &propertyCount);
        
        for (unsigned int i = 0; i < propertyCount; i++) {
            
            STDbObjectProperty* p = [[STDbObjectProperty alloc] init];
            
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            p.name = @(propertyName);
            
            const char *attrs = property_getAttributes(property);
            NSString* propertyAttributes = @(attrs);
            NSArray* attributeItems = [propertyAttributes componentsSeparatedByString:@","];
            
            if ([attributeItems containsObject:@"R"]) {
//                continue; //to next property
            }
            
            if ([propertyAttributes hasPrefix:@"Tc,"]) {
                p.structName = @"BOOL";
            }
            
            scanner = [NSScanner scannerWithString: propertyAttributes];
            
            [scanner scanUpToString:@"T" intoString: nil];
            [scanner scanString:@"T" intoString:nil];
            
            if ([scanner scanString:@"@\"" intoString: &propertyType]) {
                
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"]
                                        intoString:&propertyType];
                
                p.type = NSClassFromString(propertyType);
                p.isMutable = ([propertyType rangeOfString:@"Mutable"].location != NSNotFound);
                
                while ([scanner scanString:@"<" intoString:NULL]) {
                    
                    NSString* protocolName = nil;
                    
                    [scanner scanUpToString:@">" intoString: &protocolName];
                    
                    if ([protocolName isEqualToString:@"STDbIgnore"]) {
                        p = nil;
                    } else if([protocolName isEqualToString:@"STDbPrimaryKey"]) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
                        p.isPrimaryKey = YES;
#pragma GCC diagnostic pop
                        
                        objc_setAssociatedObject(
                                                 self.class,
                                                 &kSTDbClassPrimaryPropertyNameKey,
                                                 p.name,
                                                 OBJC_ASSOCIATION_RETAIN
                                                 );
                    } else {
                        p.protocol = protocolName;
                    }
                    
                    [scanner scanString:@">" intoString:NULL];
                }
                
            }
            
            else if ([scanner scanString:@"{" intoString: &propertyType]) {
                [scanner scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet]
                                    intoString:&propertyType];
                p.structName = propertyType;
                
            } else {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@","]
                                        intoString:&propertyType];
                
                //get the full name of the primitive type
                NSDictionary *primitivesNames = @{@"f":@"float", @"i":@"int", @"d":@"double", @"l":@"long", @"c":@"BOOL", @"s":@"short", @"q":@"long",
                                     //and some famous aliases of primitive types
                                     // BOOL is now "B" on iOS __LP64 builds
                                     @"I":@"NSInteger", @"Q":@"NSUInteger", @"B":@"BOOL", @"*": @"char *",
                                     @"@?":@"Block"};
                propertyType = primitivesNames[propertyType];
                p.structName = propertyType;
            }
            
            NSString *nsPropertyName = @(propertyName);
            
            if([[self class] propertyIsPrimary:nsPropertyName]){
                p.isPrimaryKey = YES;
            }
            
            if([[self class] propertyIsIgnored:nsPropertyName]){
                p = nil;
            }
            
            Class customClass = [[self class] classForCollectionProperty:nsPropertyName];
            if (customClass) {
                p.protocol = NSStringFromClass(customClass);
            }
            
            if ([propertyType isEqualToString:@"Block"]) {
                p = nil;
            }
            
            if (p && ![propertyIndex objectForKey:p.name]) {
                [propertyIndex setValue:p forKey:p.name];
            }
        }
        
        free(properties);
        
        class = [class superclass];
    }
    
    objc_setAssociatedObject(
                             self.class,
                             &kSTDbClassPropertiesKey,
                             [propertyIndex copy],
                             OBJC_ASSOCIATION_RETAIN
                             );
}

+(Class)classForCollectionProperty:(NSString *)propertyName
{
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    NSString *protocolName = [self protocolForArrayProperty:propertyName];
#pragma GCC diagnostic pop
    
    if (!protocolName)
        return nil;
    
    return NSClassFromString(protocolName);
}

+(NSString*)protocolForArrayProperty:(NSString *)propertyName
{
    return nil;
}

+(BOOL)propertyIsPrimary:(NSString*)propertyName
{
    return NO;
}

+(BOOL)propertyIsIgnored:(NSString *)propertyName
{
    return NO;
}

@end

