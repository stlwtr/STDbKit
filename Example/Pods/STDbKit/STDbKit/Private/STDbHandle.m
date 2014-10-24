//
//  STDbHandle.m
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

#import "STDbHandle.h"
#import <objc/runtime.h>
#import <CommonCrypto/CommonCrypto.h>

#define DBName @"stdb.sqlite"
#define DBParentPrefix @"STDBParentID_"
#define DBChildPrefix  @"STDBChildID_"
#define kPId  @"__pid__"
#define kCId  @"__cid__"

#ifdef DEBUG
#ifdef STDBBUG
#define STDBLog(fmt, ...) NSLog((@"%s [Line %d]\n" fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define STDBLog(...)
#endif
#else
#define STDBLog(...)
#endif

objc_property_t * st_class_copyPropertyList(Class cls, unsigned int *count);

enum {
    DBObjAttrInt,
    DBObjAttrFloat,
    DBObjAttrString,
    DBObjAttrData,
    DBObjAttrDate,
    DBObjAttrArray,
    DBObjAttrDictionary,
};

#define DBText  @"text"
#define DBInt   @"integer"
#define DBFloat @"real"
#define DBData  @"blob"

@interface NSDate (STDbHandle)

+ (NSDate *)dateWithString:(NSString *)s;
+ (NSString *)stringWithDate:(NSDate *)date;

@end

@implementation NSDate (STDbHandle)

+ (NSDate *)dateWithString:(NSString *)s;
{
    if (!s || (NSNull *)s == [NSNull null] || [s isEqual:@""]) {
        return nil;
    }
//    NSTimeInterval t = [s doubleValue];
//    return [NSDate dateWithTimeIntervalSince1970:t];
    
    return [[self dateFormatter] dateFromString:s];
}

+ (NSString *)stringWithDate:(NSDate *)date;
{
    if (!date || (NSNull *)date == [NSNull null] || [date isEqual:@""]) {
        return nil;
    }
//    NSTimeInterval t = [date timeIntervalSince1970];
//    return [NSString stringWithFormat:@"%lf", t];
    return [[self dateFormatter] stringFromDate:date];
}

+ (NSDateFormatter *)dateFormatter
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    return dateFormatter;
}

@end

@interface NSString (STDbHandle)

- (NSData *)base64Data;
- (NSString *)encryptWithKey:(NSString *)key;
- (NSString *)decryptWithKey:(NSString *)key;

@end

@interface NSObject (STDbHandle)

+ (id)objectWithString:(NSString *)s;
+ (NSString *)stringWithObject:(NSObject *)obj;

@end

@implementation NSObject (STDbHandle)

+ (id)objectWithString:(NSString *)s;
{
    if (!s || (NSNull *)s == [NSNull null] || [s isEqual:@""]) {
        return nil;
    }
    return [NSJSONSerialization JSONObjectWithData:[s dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
}
+ (NSString *)stringWithObject:(NSObject *)obj;
{
    if (!obj || (NSNull *)obj == [NSNull null] || [obj isEqual:@""]) {
        return nil;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end

@interface STDbHandle()

@property (nonatomic) sqlite3 *sqlite3DB;
@property (nonatomic, assign) BOOL isOpened;

@end

@implementation STDbHandle

/**
 *	@brief	单例数据库
 *
 *	@return	单例
 */
+ (instancetype)shareDb
{
    @synchronized(self){
        static STDbHandle *stdb;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            stdb = [[STDbHandle alloc] init];
#ifdef STDb_EncryptEnable
            stdb.encryptEnable = YES;
#endif
        });
        return stdb;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
#ifdef STDb_EncryptEnable
        self.encryptEnable = YES;
#endif
    }
    return self;
}

/**
 *	@brief	从外部导入数据库
 *
 *	@param 	dbName 	数据库名称（dbName.db）
 */
+ (void)importDb:(NSString *)dbName
{
    @synchronized(self){
        NSString *dbPath = [STDbHandle dbPath];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
            NSString *ext = [dbName pathExtension];
            NSString *extDbName = [dbName stringByDeletingPathExtension];
            NSString *extDbPath = [[NSBundle mainBundle] pathForResource:extDbName ofType:ext];
            if (extDbPath) {
                NSError *error;
                BOOL rc = [[NSFileManager defaultManager] copyItemAtPath:extDbPath toPath:dbPath error:&error];
                if (rc) {
                    NSArray *tables = [STDbHandle sqlite_tablename];
                    for (NSString *table in tables) {
                        NSMutableString *sql;
                        
                        sqlite3_stmt *stmt = NULL;
                        NSString *str = [NSString stringWithFormat:@"select sql from sqlite_master where type='table' and tbl_name='%@'", table];
                        STDbHandle *stdb = [STDbHandle shareDb];
                        [STDbHandle openDb];
                        if (sqlite3_prepare_v2(stdb->_sqlite3DB, [str UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
                            while (SQLITE_ROW == sqlite3_step(stmt)) {
                                const unsigned char *text = sqlite3_column_text(stmt, 0);
                                sql = [NSMutableString stringWithUTF8String:(const char *)text];
                            }
                        }
                        sqlite3_finalize(stmt);
                        stmt = NULL;
                        
                        NSRange r = [sql rangeOfString:@"("];
                        
                        // 备份数据库
                        
                        // 错误信息
                        char *errmsg = NULL;
                        
                        // 创建临时表
                        NSString *createTempDb = [NSString stringWithFormat:@"create temporary table t_backup%@", [sql substringFromIndex:r.location]];
                        int ret = sqlite3_exec(stdb.sqlite3DB, [createTempDb UTF8String], NULL, NULL, &errmsg);
                        if (ret != SQLITE_OK) {
                            NSLog(@"%s", errmsg);
                        }
                        
                        //导入数据
                        NSString *importDb = [NSString stringWithFormat:@"insert into t_backup select * from %@", table];
                        ret = sqlite3_exec(stdb.sqlite3DB, [importDb UTF8String], NULL, NULL, &errmsg);
                        if (ret != SQLITE_OK) {
                            NSLog(@"%s", errmsg);
                        }
                        // 删除旧表
                        NSString *dropDb = [NSString stringWithFormat:@"drop table %@", table];
                        ret = sqlite3_exec(stdb.sqlite3DB, [dropDb UTF8String], NULL, NULL, &errmsg);
                        if (ret != SQLITE_OK) {
                            NSLog(@"%s", errmsg);
                        }
                        // 创建新表
                        NSMutableString *createNewTl = [NSMutableString stringWithString:sql];
                        if (r.location != NSNotFound) {
                            NSString *insertStr = [NSString stringWithFormat:@"\n\t%@ %@ primary key,", kDbId, DBInt];
                            [createNewTl insertString:insertStr atIndex:r.location + 1];
                        } else {
                            return;
                        }
                        NSString *createDb = [NSString stringWithFormat:@"%@", createNewTl];
                        ret = sqlite3_exec(stdb.sqlite3DB, [createDb UTF8String], NULL, NULL, &errmsg);
                        if (ret != SQLITE_OK) {
                            NSLog(@"%s", errmsg);
                        }
                        
                        // 从临时表导入数据到新表
                        
                        NSString *cols = [[NSString alloc] init];
                        
                        NSString *t_str = [sql substringWithRange:NSMakeRange(r.location + 1, [sql length] - r.location - 2)];
                        t_str = [t_str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                        t_str = [t_str stringByReplacingOccurrencesOfString:@"\t" withString:@""];
                        t_str = [t_str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        
                        NSMutableArray *colsArr = [NSMutableArray arrayWithCapacity:0];
                        for (NSString *s in [t_str componentsSeparatedByString:@","]) {
                            NSString *s0 = [NSString stringWithString:s];
                            s0 = [s0 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            NSArray *a = [s0 componentsSeparatedByString:@" "];
                            NSString *s1 = a[0];
                            s1 = [s1 stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                            [colsArr addObject:s1];
                        }
                        cols = [colsArr componentsJoinedByString:@", "];
                        
                        importDb = [NSString stringWithFormat:@"insert into %@ select (rowid-1) as %@, %@ from t_backup", table, kDbId, cols];
                        
                        ret = sqlite3_exec(stdb.sqlite3DB, [importDb UTF8String], NULL, NULL, &errmsg);
                        if (ret != SQLITE_OK) {
                            NSLog(@"%s", errmsg);
                        }
                        
                        // 删除临时表
                        dropDb = [NSString stringWithFormat:@"drop table t_backup"];
                        ret = sqlite3_exec(stdb.sqlite3DB, [dropDb UTF8String], NULL, NULL, &errmsg);
                        if (ret != SQLITE_OK) {
                            NSLog(@"%s", errmsg);
                        }
                        
                        // 加密数据库
                        if ([[self shareDb] encryptEnable]) {
                            NSMutableArray *results = [NSClassFromString(table) allDbObjects];
                            for (STDbObject *obj in results) {
                                
                                [self openDb];
                                
                                NSMutableArray *keys = [NSMutableArray arrayWithCapacity:0];
                                [STDbHandle class:obj.class getPropertyKeyList:keys];
                                
                                NSMutableArray *types = [NSMutableArray arrayWithCapacity:0];
                                [STDbHandle class:obj.class getPropertyTypeList:types];
                                
                                for (NSInteger i = 0; i < keys.count; i++) {
                                    NSString *type = types[i];
                                    NSString *key = keys[i];
                                    
                                    if ([type isEqualToString:@"text"]) {
                                        NSString *value = [[NSString alloc] initWithFormat:@"%@", [obj valueForKey:key]];
                                        if ([[self shareDb] encryptEnable]) {
                                            value = [value encryptWithKey:[self encryptKey]];
                                        }
                                        [obj setValue:value forKey:key];
                                    }
                                }
                                
                                [obj updatetoDb];
                            }
                        }
                    }
                } else {
                    NSLog(@"%@", error.localizedDescription);
                }
                
            } else {
                
            }
        }
    }
}

/**
 *	@brief	打开数据库
 *
 *	@return	成功标志
 */
+ (BOOL)openDb
{
    @synchronized(self){
        NSString *dbPath = [STDbHandle dbPath];
        STDbHandle *db = [STDbHandle shareDb];
        
        int flags = SQLITE_OPEN_READWRITE;
        if ([[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
            flags = SQLITE_OPEN_READWRITE;
        } else {
            flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE;
        }
        
        if ([STDbHandle isOpened]) {
    //        STDBLog(@"数据库已打开");
            return YES;
        }

        int rc = sqlite3_open_v2([dbPath UTF8String], &db->_sqlite3DB, flags, NULL);
        if (rc == SQLITE_OK) {
    //        STDBLog(@"打开数据库%@成功!", dbPath);
            
            db.isOpened = YES;
            return YES;
        } else {
            STDBLog(@"打开数据库%@失败!", dbPath);
            return NO;
        }

        return NO;
    }
}

/*
 * 关闭数据库
 */
+ (BOOL)closeDb {
    @synchronized(self){
    #ifdef STDBBUG
        NSString *dbPath = [STDb dbPath];
    #endif
        
        STDbHandle *db = [STDbHandle shareDb];
        
        if (![db isOpened]) {
    //        STDBLog(@"数据库已关闭");
            return YES;
        }
        
        int rc = sqlite3_close(db.sqlite3DB);
        if (rc == SQLITE_OK) {
    //        STDBLog(@"关闭数据库%@成功!", dbPath);
            db.isOpened = NO;
            db.sqlite3DB = NULL;
            return YES;
        } else {
            STDBLog(@"关闭数据库%@失败!", dbPath);
            return NO;
        }
        return YES;
    }
}

/**
 *	@brief	数据库路径
 *
 *	@return	数据库路径
 */
+ (NSString *)dbPath
{
    @synchronized(self){
        NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSString *path = [NSString stringWithFormat:@"%@/%@", document, DBName];
        return path;
    }
}

/**
 *	@brief	根据aClass表 添加一列
 *
 *	@param 	aClass 	表相关类
 *	@param 	columnName 	列名
 */
+ (void)dbTable:(Class)aClass addColumn:(NSString *)columnName
{
    @synchronized(self){
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
        
        NSMutableString *sql = [NSMutableString stringWithCapacity:0];
        [sql appendString:@"alter table "];
        [sql appendString:NSStringFromClass(aClass)];
        if ([columnName isEqualToString:kDbId]) {
            NSString *colStr = [NSString stringWithFormat:@"%@ %@ primary key", kDbId, DBInt];
            [sql appendFormat:@" add column %@;", colStr];
        } else {
            [sql appendFormat:@" add column %@ %@;", columnName, DBText];
        }

        char *errmsg = 0;
        STDbHandle *db = [STDbHandle shareDb];
        
        int ret = sqlite3_exec(db.sqlite3DB, [sql UTF8String], NULL, NULL, &errmsg);
        
        if(ret != SQLITE_OK){
            fprintf(stderr,"table add column fail: %s\n", errmsg);
        }
        sqlite3_free(errmsg);
        
//        [STDbHandle closeDb];
    }
}

/**
 *	@brief	根据aClass创建表
 *
 *	@param 	aClass 	表相关类
 */
+ (void)createDbTable:(Class)aClass
{
    @synchronized(self){
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
        
        if ([STDbHandle sqlite_tableExist:aClass]) {
            STDBLog(@"数据库表%@已存在!", NSStringFromClass(aClass));
            return;
        }
        
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
        
        NSMutableString *sql = [NSMutableString stringWithCapacity:0];
        [sql appendString:@"create table "];
        [sql appendString:NSStringFromClass(aClass)];
        [sql appendString:@"("];
        
        NSMutableArray *propertyArr = [NSMutableArray arrayWithCapacity:0];
        NSMutableArray *primaryKeys = [NSMutableArray arrayWithCapacity:0];
        
        [STDbHandle class:aClass getPropertyNameList:propertyArr primaryKeys:primaryKeys];
        
        NSString *propertyStr = [propertyArr componentsJoinedByString:@","];
        
        [sql appendString:propertyStr];
        
        NSMutableArray *primaryKeysArr = [NSMutableArray array];
        for (NSString *s in primaryKeys) {
            NSString *str = [NSString stringWithFormat:@"\"%@\"", s];
            [primaryKeysArr addObject:str];
        }
        
        NSString *priKeysStr = [primaryKeysArr componentsJoinedByString:@","];
        NSString *primaryKeysStr = [NSString stringWithFormat:@",primary key(%@)", priKeysStr];
        [sql appendString:primaryKeysStr];
        
        [sql appendString:@");"];
        
        char *errmsg = 0;
        STDbHandle *db = [STDbHandle shareDb];
        sqlite3 *sqlite3DB = db.sqlite3DB;
        int ret = sqlite3_exec(sqlite3DB,[sql UTF8String], NULL, NULL, &errmsg);
        if(ret != SQLITE_OK){
    //        fprintf(stderr,"create table fail: %s\n",errmsg);
        }
        sqlite3_free(errmsg);
        
//        [STDbHandle closeDb];
    }
}

/**
 *	@brief	插入一条数据
 *
 *	@param 	obj 	数据对象
 */
- (BOOL)insertDbObject:(STDbObject *)obj;
{
    @synchronized(self){
        return [self insertDbObject:obj forced:YES];
    }
}

/**
 *	@brief	仅插入一条数据
 *
 *	@param 	obj 	数据对象
 */
- (BOOL)replaceDbObject:(STDbObject *)obj;
{
    @synchronized(self){
        return[self insertDbObject:obj forced:NO];
    }
}

/**
 *	@brief	插入一条数据
 *
 *	@param 	obj 	数据对象
 */
- (BOOL)insertDbObject:(STDbObject *)obj forced:(BOOL)forced
{
    @synchronized(self){
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
        
        NSString *tableName = NSStringFromClass(obj.class);
        
        if (![STDbHandle sqlite_tableExist:obj.class]) {
            [STDbHandle createDbTable:obj.class];
        }
        
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
        
        NSMutableArray *propertyArr = [NSMutableArray arrayWithCapacity:0];
        propertyArr = [NSMutableArray arrayWithArray:[STDbHandle sqlite_columns:obj.class]];
        
        NSUInteger argNum = [propertyArr count];
        
        NSString *insertSql = forced ? @"insert" : @"replace";
        NSMutableString *sql_NSString = [[NSMutableString alloc] initWithFormat:@"%@ into %@ values(?)", insertSql,tableName];
        NSRange range = [sql_NSString rangeOfString:@"?"];
        for (int i = 0; i < argNum - 1; i++) {
            [sql_NSString insertString:@",?" atIndex:range.location + 1];
        }
        
        sqlite3_stmt *stmt = NULL;
        STDbHandle *db = [STDbHandle shareDb];
        sqlite3 *sqlite3DB = db.sqlite3DB;
        
        // obj包含的STDbObject对象
    //    NSMutableArray *subDbObjects = [NSMutableArray arrayWithCapacity:0];
        
        const char *errmsg = NULL;
        if (sqlite3_prepare_v2(sqlite3DB, [sql_NSString UTF8String], -1, &stmt, &errmsg) == SQLITE_OK) {
            for (int i = 1; i <= argNum; i++) {
                NSString * key = propertyArr[i - 1][@"title"];
                
                if ([key isEqualToString:kDbId]) {
                    continue;
                }
                
                NSString *column_type_string = propertyArr[i - 1][@"type"];
                
                id value;
                NSInteger rowId = [STDbHandle lastRowIdWithClass:obj.class];
                
                if ([key hasPrefix:DBParentPrefix]) {
                    key = [key stringByReplacingOccurrencesOfString:DBParentPrefix withString:@""];
                    
                    value = [[NSString alloc] initWithFormat:@"%@", @(rowId+1)];
                } else {
                    value = [obj valueForKey:key];
                    NSObject *object = (NSObject *)value;
                    if ([object isKindOfClass:[STDbObject class]]) {
                        NSInteger subDbRowId = [STDbHandle lastRowIdWithClass:object.class];
                        value = [[NSString alloc] initWithFormat:@"%@", @(subDbRowId+1)];
                        
                        STDbObject *dbObj = (STDbObject *)object;
                        [dbObj setValue:@(rowId+1) forKey:kPId];
                        [dbObj insertToDb];
                    }
                }

                if ([column_type_string isEqualToString:@"blob"]) {
                    if (!value || value == [NSNull null] || [value isEqual:@""]) {
                        sqlite3_bind_null(stmt, i);
                    } else {
                        NSData *data = [NSData dataWithData:value];
                        NSUInteger len = [data length];
                        const void *bytes = [data bytes];
                        sqlite3_bind_blob(stmt, i, bytes, (int)len, NULL);
                    }
                    
                } else if ([column_type_string isEqualToString:@"text"]) {
                    if (!value || value == [NSNull null] || [value isEqual:@""]) {
                        sqlite3_bind_null(stmt, i);
                    } else {
                        objc_property_t property_t = class_getProperty(obj.class, [key UTF8String]);
                        
                        value = [STDbHandle valueForDbObjc_property_t:property_t dbValue:value _id:rowId];
                        NSString *column_value = [NSString stringWithFormat:@"%@", value];
                        sqlite3_bind_text(stmt, i, [column_value UTF8String], -1, SQLITE_STATIC);
                    }
                    
                } else if ([column_type_string isEqualToString:@"real"]) {
                    if (!value || value == [NSNull null] || [value isEqual:@""]) {
                        sqlite3_bind_null(stmt, i);
                    } else {
                        id column_value = value;
                        sqlite3_bind_double(stmt, i, [column_value doubleValue]);
                    }
                }
                else if ([column_type_string isEqualToString:@"integer"]) {
                    if (!value || value == [NSNull null] || [value isEqual:@""]) {
                        sqlite3_bind_null(stmt, i);
                    } else {
                        id column_value = value;
                        sqlite3_bind_int(stmt, i, [column_value intValue]);
                    }
                }
            }
            int rc = sqlite3_step(stmt);
            
            if ((rc != SQLITE_DONE) && (rc != SQLITE_ROW)) {
                NSString *insertSql = forced ? @"insert" : @"replace";
                fprintf(stderr,"%s dbObject fail: %s\n", insertSql.UTF8String, errmsg);
                sqlite3_finalize(stmt);
                stmt = NULL;
//                [STDbHandle closeDb];
                
                return NO;
            }
        }
        sqlite3_finalize(stmt);
        stmt = NULL;
//        [STDbHandle closeDb];
        
        return YES;
    }
}

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
- (NSMutableArray *)selectDbObjects:(Class)aClass condition:(NSString *)condition orderby:(NSString *)orderby
{
//    @synchronized(self){
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
        
        // 清除过期数据
        [STDbHandle cleanExpireDbObject:aClass];
        
        sqlite3_stmt *stmt = NULL;
        NSMutableArray *array = nil;
        NSMutableString *selectstring = nil;
        NSString *tableName = NSStringFromClass(aClass);
        
        selectstring = [[NSMutableString alloc] initWithFormat:@"select %@ from %@", @"*", tableName];
        if (condition != nil || [condition length] != 0) {
            if (![[condition lowercaseString] isEqualToString:@"all"]) {
                [selectstring appendFormat:@" where %@", condition];
            }
        }
        
        if (orderby != nil || [orderby length] != 0) {
            if (![[orderby lowercaseString] isEqualToString:@"no"]) {
                [selectstring appendFormat:@" order by %@", orderby];
            }
        }
        
        STDbHandle *db = [STDbHandle shareDb];
        sqlite3 *sqlite3DB = db.sqlite3DB;
        
        if (sqlite3_prepare_v2(sqlite3DB, [selectstring UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
            int column_count = sqlite3_column_count(stmt);
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                
                STDbObject *obj = [[NSClassFromString(tableName) alloc] init];
                
                for (int i = 0; i < column_count; i++) {
                    const char *column_name = sqlite3_column_name(stmt, i);
                    const char * column_decltype = sqlite3_column_decltype(stmt, i);

                    id column_value = nil;
                    NSData *column_data = nil;
                    
                    NSString* key = [NSString stringWithFormat:@"%s", column_name];
                    key = [key stringByReplacingOccurrencesOfString:DBParentPrefix withString:@""];
                    
                    objc_property_t property_t = class_getProperty(obj.class, [key UTF8String]);
                    
                    NSString *obj_column_decltype = [[NSString stringWithUTF8String:column_decltype] lowercaseString];
                    if ([obj_column_decltype isEqualToString:@"text"]) {
                        const unsigned char *value = sqlite3_column_text(stmt, i);
                        if (value != NULL) {
                            column_value = [NSString stringWithUTF8String: (const char *)value];
                            id objValue = [STDbHandle valueForObjc_property_t:property_t dbValue:column_value];
                            if (objValue) {
                                [obj setValue:objValue forKey:key];
                            }
                        }
                    } else if ([obj_column_decltype isEqualToString:@"integer"]) {
                        int value = sqlite3_column_int(stmt, i);
                        if (&value != NULL) {
                            column_value = [NSNumber numberWithInt: value];
                            id objValue = [STDbHandle valueForObjc_property_t:property_t dbValue:column_value];
                            [obj setValue:objValue forKey:key];
                        }
                    } else if ([obj_column_decltype isEqualToString:@"real"]) {
                        double value = sqlite3_column_double(stmt, i);
                        if (&value != NULL) {
                            column_value = [NSNumber numberWithDouble:value];
                            id objValue = [STDbHandle valueForObjc_property_t:property_t dbValue:column_value];
                            [obj setValue:objValue forKey:key];
                        }
                    } else if ([obj_column_decltype isEqualToString:@"blob"]) {
                        const void *databyte = sqlite3_column_blob(stmt, i);
                        if (databyte != NULL) {
                            int dataLenth = sqlite3_column_bytes(stmt, i);
                            column_data = [NSData dataWithBytes:databyte length:dataLenth];
                            id objValue = [STDbHandle valueForObjc_property_t:property_t dbValue:column_data];
                            [obj setValue:objValue forKey:key];
                        }
                    } else {
                        const unsigned char *value = sqlite3_column_text(stmt, i);
                        if (value != NULL) {
                            column_value = [NSString stringWithUTF8String: (const char *)value];
                            id objValue = [STDbHandle valueForObjc_property_t:property_t dbValue:column_value];
                            [obj setValue:objValue forKey:key];
                        }
                    }
                }
                if (array == nil) {
                    array = [[NSMutableArray alloc] initWithObjects:obj, nil];
                } else {
                    [array addObject:obj];
                }
            }
        }
        
        sqlite3_finalize(stmt);
        stmt = NULL;
//        [STDbHandle closeDb];
    
        return array;
//    }
}

/**
 *	@brief	根据条件删除类
 *
 *	@param 	aClass      表相关类
 *	@param 	condition   条件（nil或空为无条件），例 id=5 and name='yls'
 *                      无条件或者all时删除所有.
 *
 *	@return	删除是否成功
 */
- (BOOL)removeDbObjects:(Class)aClass condition:(NSString *)condition
{
    @synchronized(self){
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
        
        sqlite3_stmt *stmt = NULL;
        int rc = -1;
        
        sqlite3 *sqlite3DB = [[STDbHandle shareDb] sqlite3DB];
        
        NSString *tableName = NSStringFromClass(aClass);
        
        // 删掉表
        if (!condition || [[condition lowercaseString] isEqualToString:@"all"]) {
            return [STDbHandle removeDbTable:aClass];
        }
        
        NSMutableString *createStr;
        
        if ([condition length] > 0) {
            createStr = [NSMutableString stringWithFormat:@"delete from %@ where %@", tableName, condition];
        } else {
            createStr = [NSMutableString stringWithFormat:@"delete from %@", tableName];
        }

        const char *errmsg = 0;
        if (sqlite3_prepare_v2(sqlite3DB, [createStr UTF8String], -1, &stmt, &errmsg) == SQLITE_OK) {
            rc = sqlite3_step(stmt);
        }
        sqlite3_finalize(stmt);
        stmt = NULL;
//        [STDbHandle closeDb];
        if ((rc != SQLITE_DONE) && (rc != SQLITE_ROW)) {
    //        fprintf(stderr,"remove dbObject fail: %s\n",errmsg);
            return NO;
        }
        return YES;
    }
}

/**
 *	@brief	根据条件修改一条数据
 *
 *	@param 	obj 	修改的数据对象（属性中有值的修改，为nil的不处理）
 *	@param 	condition 	条件（nil或空为无条件），例 id=5 and name='yls'
 *
 *	@return	修改是否成功
 */
- (BOOL)updateDbObject:(STDbObject *)obj condition:(NSString *)condition
{
//    @synchronized(self){
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
        
        NSMutableArray *propertyTypeArr = [NSMutableArray arrayWithArray:[STDbHandle sqlite_columns:obj.class]];
        
        sqlite3_stmt *stmt = NULL;
        int rc = -1;
        NSString *tableName = NSStringFromClass(obj.class);
        NSMutableArray *propertyArr = [NSMutableArray arrayWithCapacity:0];
        sqlite3 *sqlite3DB = [[STDbHandle shareDb] sqlite3DB];
        
        unsigned int count;
        Class cls = [obj class];
        objc_property_t *properties = st_class_copyPropertyList(cls, &count);
    
        NSMutableArray *keys = [NSMutableArray arrayWithCapacity:0];
        
        for (int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            NSString * key = [[NSString alloc]initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
            id objValue = [obj valueForKey:key];
            id value = [STDbHandle valueForDbObjc_property_t:property dbValue:objValue _id:-1];

            if (value && (NSNull *)value != [NSNull null]) {
                NSString *bindValue = [NSString stringWithFormat:@"%@=?", key];
                [propertyArr addObject:bindValue];
                [keys addObject:key];
            }
        }
        
        NSString *newValue = [propertyArr componentsJoinedByString:@","];
    
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
    
        NSMutableString *createStr = [NSMutableString stringWithFormat:@"update %@ set %@ where %@", tableName, newValue, condition];
        
        const char *errmsg = 0;
        if (sqlite3_prepare_v2(sqlite3DB, [createStr UTF8String], -1, &stmt, &errmsg) == SQLITE_OK) {
            
            int i = 1;
            for (NSString *key in keys) {
                
                if ([key isEqualToString:kDbId]) {
                    continue;
                }
                
                NSString *column_type_string = propertyTypeArr[i - 1][@"type"];
                
                id value = [obj valueForKey:key];
                
                if ([column_type_string isEqualToString:@"blob"]) {
                    if (!value || value == [NSNull null] || [value isEqual:@""]) {
                        sqlite3_bind_null(stmt, i);
                    } else {
                        NSData *data = [NSData dataWithData:value];
                        NSUInteger len = [data length];
                        const void *bytes = [data bytes];
                        sqlite3_bind_blob(stmt, i, bytes, (int)len, NULL);
                    }
                    
                } else if ([column_type_string isEqualToString:@"text"]) {
                    if (!value || value == [NSNull null] || [value isEqual:@""]) {
                        sqlite3_bind_null(stmt, i);
                    } else {
                        objc_property_t property_t = class_getProperty(obj.class, [key UTF8String]);
                        
                        value = [STDbHandle valueForDbObjc_property_t:property_t dbValue:value _id:obj.__id__];
                        NSString *column_value = [NSString stringWithFormat:@"%@", value];
            
                        sqlite3_bind_text(stmt, i, [column_value UTF8String], -1, SQLITE_STATIC);
                    }
                    
                } else if ([column_type_string isEqualToString:@"real"]) {
                    if (!value || value == [NSNull null] || [value isEqual:@""]) {
                        sqlite3_bind_null(stmt, i);
                    } else {
                        id column_value = value;
                        sqlite3_bind_double(stmt, i, [column_value doubleValue]);
                    }
                }
                else if ([column_type_string isEqualToString:@"integer"]) {
                    if (!value || value == [NSNull null] || [value isEqual:@""]) {
                        sqlite3_bind_null(stmt, i);
                    } else {
                        id column_value = value;
                        sqlite3_bind_int(stmt, i, [column_value intValue]);
                    }
                }
                i++;
            }
            
            rc = sqlite3_step(stmt);
        }
        sqlite3_finalize(stmt);
        stmt = NULL;
//        [STDbHandle closeDb];
        if ((rc != SQLITE_DONE) && (rc != SQLITE_ROW)) {
            fprintf(stderr,"update table fail: %s\n",errmsg);
            return NO;
        }
        return YES;
//    }
}

/**
 *	@brief	根据aClass删除表
 *
 *	@param 	aClass 	表相关类
 *
 *	@return	删除表是否成功
 */
+ (BOOL)removeDbTable:(Class)aClass
{
    @synchronized(self){
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
        
        NSMutableString *sql = [NSMutableString stringWithCapacity:0];
        [sql appendString:@"drop table if exists "];
        [sql appendString:NSStringFromClass(aClass)];

        char *errmsg = 0;
        STDbHandle *db = [STDbHandle shareDb];
        sqlite3 *sqlite3DB = db.sqlite3DB;
        int ret = sqlite3_exec(sqlite3DB,[sql UTF8String], NULL, NULL, &errmsg);
        if(ret != SQLITE_OK){
            fprintf(stderr,"drop table fail: %s\n",errmsg);
        }
        sqlite3_free(errmsg);
        
//        [STDbHandle closeDb];
        
        return YES;
    }
}

/**
 *	@brief	根据aClass清除过期数据
 *
 *	@param 	aClass 	表相关类
 *
 *	@return	清除过期表是否成功
 */
+ (BOOL)cleanExpireDbObject:(Class)aClass
{
    @synchronized(self){
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }

        NSString *dateStr = [NSDate stringWithDate:[NSDate date]];
        NSString *condition = [NSString stringWithFormat:@"expireDate<'%@'", dateStr];
        [[[STDbHandle alloc] init] removeDbObjects:aClass condition:condition];
        
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
        
        return YES;
    }
}

#pragma mark - other method

/*
 * 查看所有表名
 */
+ (NSArray *)sqlite_tablename {
    @synchronized(self){
        if (![STDbHandle isOpened]) {
            [STDbHandle openDb];
        }
        
        sqlite3_stmt *stmt = NULL;
        NSMutableArray *tablenameArray = [[NSMutableArray alloc] init];
        NSString *str = [NSString stringWithFormat:@"select tbl_name from sqlite_master where type='table'"];
        sqlite3 *sqlite3DB = [[STDbHandle shareDb] sqlite3DB];
        if (sqlite3_prepare_v2(sqlite3DB, [str UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
            while (SQLITE_ROW == sqlite3_step(stmt)) {
                const unsigned char *text = sqlite3_column_text(stmt, 0);
                [tablenameArray addObject:[NSString stringWithUTF8String:(const char *)text]];
            }
        }
        sqlite3_finalize(stmt);
        stmt = NULL;
        
//        [STDbHandle closeDb];
        
        return tablenameArray;
    }
}

/*
 * 判断一个表是否存在；
 */
+ (BOOL)sqlite_tableExist:(Class)aClass {
    @synchronized(self){
        NSArray *tableArray = [self sqlite_tablename];
        NSString *tableName = NSStringFromClass(aClass);
        for (NSString *tablename in tableArray) {
            if ([tablename isEqualToString:tableName]) {
                return YES;
            }
        }
        return NO;
    }
}

+ (NSArray *)sqlite_columns:(Class)cls
{
//    @synchronized(self){
        NSString *table = NSStringFromClass(cls);
        NSMutableString *sql;
        
        sqlite3_stmt *stmt = NULL;
        NSString *str = [NSString stringWithFormat:@"select sql from sqlite_master where type='table' and tbl_name='%@'", table];
        STDbHandle *stdb = [STDbHandle shareDb];
        [STDbHandle openDb];
        if (sqlite3_prepare_v2(stdb->_sqlite3DB, [str UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
            while (SQLITE_ROW == sqlite3_step(stmt)) {
                const unsigned char *text = sqlite3_column_text(stmt, 0);
                sql = [NSMutableString stringWithUTF8String:(const char *)text];
            }
        }
        sqlite3_finalize(stmt);
        stmt = NULL;
        
        NSRange r = [sql rangeOfString:@"("];
        
        NSString *t_str = [sql substringWithRange:NSMakeRange(r.location + 1, [sql length] - r.location - 2)];
        t_str = [t_str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        t_str = [t_str stringByReplacingOccurrencesOfString:@"\t" withString:@""];
        t_str = [t_str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        NSRange primaryRangeR = [t_str rangeOfString:@",primary key\\(.*\\)" options:NSRegularExpressionSearch];
//        NSLog(@"%@", NSStringFromRange(primaryRangeR));
        if (primaryRangeR.location != NSNotFound) {
            t_str = [t_str stringByReplacingCharactersInRange:primaryRangeR withString:@""];
        }
        
        NSMutableArray *colsArr = [NSMutableArray arrayWithCapacity:0];
        NSArray *strs = [t_str componentsSeparatedByString:@","];
        
        for (NSString *s in strs) {
            if ([s hasPrefix:@"primary key"] || s.length == 0) {
                continue;
            }
            NSString *s0 = [NSString stringWithString:s];
            s0 = [s0 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSArray *a = [s0 componentsSeparatedByString:@" "];
            NSString *s1 = a[0];
            NSString *type = a.count >= 2 ? a[1] : @"blob";
            type = [type stringByReplacingOccurrencesOfString:@"\"" withString:@""];
            type = [type stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            s1 = [s1 stringByReplacingOccurrencesOfString:@"\"" withString:@""];
            [colsArr addObject:@{@"type": type, @"title": s1}];
        }
        return colsArr;
//    }
}

+ (NSString *)dbTypeConvertFromObjc_property_t:(objc_property_t)property
{
    @synchronized(self){
        char * type = property_copyAttributeValue(property, "T");
        
        switch(type[0]) {
            case 'f' : //float
            case 'd' : //double
            {
                return DBFloat;
            }
                break;
            
            case 'c':   // char
            case 's' : //short
            case 'i':   // int
            case 'l':   // long
            {
                return DBInt;
            }
                break;

            case '*':   // char *
                break;
                
            case '@' : //ObjC object
                //Handle different clases in here
            {
                NSString *cls = [NSString stringWithUTF8String:type];
                cls = [cls stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                cls = [cls stringByReplacingOccurrencesOfString:@"@" withString:@""];
                cls = [cls stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSString class]]) {
                    return DBText;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSNumber class]]) {
                    return DBText;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSDictionary class]]) {
                    return DBText;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSArray class]]) {
                    return DBText;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSDate class]]) {
                    return DBText;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSData class]]) {
                    return DBData;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[STDbObject class]]) {
                    return DBText;
                }
            }
                break;
        }

        return DBText;
    }
}

+ (NSString *)dbNameConvertFromObjc_property_t:(objc_property_t)property
{
    @synchronized(self){
        NSString *key = [[NSString alloc]initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        char * type = property_copyAttributeValue(property, "T");
        
        switch(type[0]) {
            case '@' : //ObjC object
                //Handle different clases in here
            {
                NSString *cls = [NSString stringWithUTF8String:type];
                cls = [cls stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                cls = [cls stringByReplacingOccurrencesOfString:@"@" withString:@""];
                cls = [cls stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                
                if ([NSClassFromString(cls) isSubclassOfClass:[STDbObject class]]) {
    //                NSString *retKey = [DBParentPrefix stringByAppendingString:key];
                    NSString *retKey = key;
                    return retKey;
                }
            }
                break;
        }
        
        return key;
    }
}

+ (id)valueForObjc_property_t:(objc_property_t)property dbValue:(id)dbValue
{
    @synchronized(self){
        char * type = property_copyAttributeValue(property, "T");
    //    NSString *key = [[NSString alloc]initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        
        switch(type[0]) {
            case 'f' : //float
            {
                return [NSNumber numberWithDouble:[dbValue floatValue]];
            }
                break;
            case 'd' : //double
            {
                return [NSNumber numberWithDouble:[dbValue doubleValue]];
            }
                break;
                
            case 'c':   // char
            {
                return [NSNumber numberWithDouble:[dbValue charValue]];
            }
                break;
            case 's' : //short
            {
                return [NSNumber numberWithDouble:[dbValue shortValue]];
            }
                break;
            case 'i':   // int
            {
                return [NSNumber numberWithDouble:[dbValue longValue]];
            }
                break;
            case 'l':   // long
            {
                return [NSNumber numberWithDouble:[dbValue longValue]];
            }
                break;
                
            case '*':   // char *
                break;
                
            case '@' : //ObjC object
                //Handle different clases in here
            {
                NSString *cls = [NSString stringWithUTF8String:type];
                cls = [cls stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                cls = [cls stringByReplacingOccurrencesOfString:@"@" withString:@""];
                cls = [cls stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSString class]]) {
                    NSString *retStr = [dbValue copy];
                    if ([[self shareDb] encryptEnable]) {
                        retStr = [retStr decryptWithKey:[self encryptKey]];
                    }
                    return retStr;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSNumber class]]) {
                    return [NSNumber numberWithDouble:[dbValue doubleValue]];
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSDictionary class]]) {
                    NSString *retStr = [dbValue copy];
                    if ([[self shareDb] encryptEnable]) {
                        retStr = [retStr decryptWithKey:[self encryptKey]];
                    }
                    NSDictionary *dict = [NSDictionary objectWithString:[NSString stringWithFormat:@"%@", retStr]];
                    NSMutableDictionary *results = [NSMutableDictionary dictionaryWithDictionary:dict];
                    
                    for (NSString *key in dict) {
                        NSObject *obj = dict[key];
                        if ([obj isKindOfClass:[NSString class]]) {
                            NSString *dbObj = [obj copy];
                            if ([dbObj hasPrefix:DBChildPrefix]) {
                                NSString *rowidStr = [dbObj stringByReplacingOccurrencesOfString:DBChildPrefix withString:@""];
                                NSArray *arr = [rowidStr componentsSeparatedByString:@","];
                                NSString *clsName = arr[0];
                                NSInteger rowid = [arr[1] integerValue];
                                
                                NSString *where = [NSString stringWithFormat:@"%@=%@", kDbId, @(rowid)];
                                
                                STDbObject *child = (STDbObject *)[NSClassFromString(clsName) dbObjectsWhere:where orderby:nil][0];
                                [results setObject:child forKey:key];
                                
                                continue;
                            }
                        }
                        [results setObject:obj forKey:key];
                    }
                    return results;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSArray class]]) {
                    
                    NSMutableArray *results = [NSMutableArray arrayWithCapacity:0];

                    NSString *retStr = [dbValue copy];
                    if ([[self shareDb] encryptEnable]) {
                        retStr = [retStr decryptWithKey:[self encryptKey]];
                    }
                    NSArray *dbArr = [NSArray objectWithString:[NSString stringWithFormat:@"%@", retStr]];
                    
                    for (NSObject *obj in dbArr) {
                        
                        if ([obj isKindOfClass:[NSString class]]) {
                            NSString *dbObj = [obj copy];
                            if ([dbObj hasPrefix:DBChildPrefix]) {
                                NSString *rowidStr = [dbObj stringByReplacingOccurrencesOfString:DBChildPrefix withString:@""];
                                NSArray *arr = [rowidStr componentsSeparatedByString:@","];
                                NSString *clsName = arr[0];
                                NSInteger rowid = [arr[1] integerValue];
                                
                                NSString *where = [NSString stringWithFormat:@"%@=%@", kDbId, @(rowid)];
                                
                                STDbObject *child = (STDbObject *)[NSClassFromString(clsName) dbObjectsWhere:where orderby:nil][0];
                                [results addObject:child];
                                
                                continue;
                            }
                        }
                        
                        [results addObject:obj];
                    }
                    
                    return results;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSDate class]]) {
                    NSString *retStr = [dbValue copy];
                    if ([[self shareDb] encryptEnable]) {
                        retStr = [retStr decryptWithKey:[self encryptKey]];
                    }
                    return [NSDate dateWithString:[NSString stringWithFormat:@"%@", retStr]];
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSValue class]]) {
                    return [NSData dataWithData:dbValue];
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[STDbObject class]]) {
                    
                    NSString *where = [[NSString alloc] initWithFormat:@"%@=%@", kDbId, dbValue];
                    
                    NSMutableArray *results = [NSClassFromString(cls) dbObjectsWhere:where orderby:nil];
                    
                    if (results.count > 0) {
                        STDbObject *obj = results[0];
                        return obj;
                    } else {
                        return nil;
                    }
                }
            }
                break;
        }
        
        return dbValue;
    }
}

+ (id)valueForDbObjc_property_t:(objc_property_t)property dbValue:(id)dbValue _id:(NSInteger)_id
{
    @synchronized(self){
        if (!dbValue) {
            return nil;
        }
        char * type = property_copyAttributeValue(property, "T");
        
        switch(type[0]) {
            case 'f' : //float
            {
                return [NSNumber numberWithDouble:[dbValue floatValue]];
            }
                break;
            case 'd' : //double
            {
                return [NSNumber numberWithDouble:[dbValue doubleValue]];
            }
                break;
                
            case 'c':   // char
            {
                return [NSNumber numberWithDouble:[dbValue charValue]];
            }
                break;
            case 's' : //short
            {
                return [NSNumber numberWithDouble:[dbValue shortValue]];
            }
                break;
            case 'i':   // int
            {
                return [NSNumber numberWithDouble:[dbValue longValue]];
            }
                break;
            case 'l':   // long
            {
                return [NSNumber numberWithDouble:[dbValue longValue]];
            }
                break;
                
            case '*':   // char *
                break;
                
            case '@' : //ObjC object
                //Handle different clases in here
            {
                NSString *cls = [NSString stringWithUTF8String:type];
                cls = [cls stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                cls = [cls stringByReplacingOccurrencesOfString:@"@" withString:@""];
                cls = [cls stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSString class]]) {
                    NSString *retStr = [NSString stringWithFormat:@"%@", [NSString stringWithFormat:@"%@", dbValue]];
                    if ([[self shareDb] encryptEnable]) {
                        retStr = [retStr encryptWithKey:[self encryptKey]];
                    }
                    return retStr;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSNumber class]]) {
                    return [NSNumber numberWithDouble:[dbValue doubleValue]];
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSDictionary class]]) {
                    NSMutableDictionary *results = [NSMutableDictionary dictionaryWithCapacity:0];
                    
                    for (NSString *key in dbValue) {
                        NSObject *obj = dbValue[key];

                        if ([obj isKindOfClass:[STDbObject class]]) {
                            STDbObject *dbObject = (STDbObject *)obj;
                            
                            [dbObject setValue:@(_id) forKey:kPId];
                            [dbObject replaceToDb];
                            
                            NSInteger rowid = [dbObject.class lastRowId];
                            
                            [results setObject:[NSString stringWithFormat:@"%@%@,%@", DBChildPrefix, NSStringFromClass(obj.class),@(rowid)]  forKey:key];
                        } else {
                            [results setObject:obj forKey:key];
                        }
                    }
                    
                    NSString *retStr = [NSString stringWithFormat:@"%@", [NSDictionary stringWithObject:results]];
                    if ([[self shareDb] encryptEnable]) {
                        retStr = [retStr encryptWithKey:[self encryptKey]];
                    }
                    return retStr;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSArray class]]) {
                    
                    NSMutableArray *results = [NSMutableArray arrayWithCapacity:0];
                    for (NSObject *obj in (NSArray *)dbValue) {
                        if ([obj isKindOfClass:[STDbObject class]]) {
                            STDbObject *dbObject = (STDbObject *)obj;
          
                            [dbObject setValue:@(_id) forKey:kPId];
                            [dbObject replaceToDb];
                            
                            NSInteger rowid = [dbObject.class lastRowId];
                            
                            [results addObject:[NSString stringWithFormat:@"%@%@,%@", DBChildPrefix, NSStringFromClass(obj.class),@(rowid)]];
                        } else {
                            [results addObject:obj];
                        }
                    }
                    NSString *retStr = [NSString stringWithFormat:@"%@", [NSArray stringWithObject:results]];
                    if ([[self shareDb] encryptEnable]) {
                        retStr = [retStr encryptWithKey:[self encryptKey]];
                    }
                    return retStr;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSDate class]]) {
                    if ([dbValue isKindOfClass:[NSDate class]]) {
                        NSString *retStr = [NSString stringWithFormat:@"%@", [NSDate stringWithDate:dbValue]];
                        if ([[self shareDb] encryptEnable]) {
                            retStr = [retStr encryptWithKey:[self encryptKey]];
                        }
                        return retStr;
                    } else {
                        return @"";
                    }
                    
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSValue class]]) {
                    return [NSData dataWithData:dbValue];
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[STDbObject class]]) {
                    return dbValue;
                }
            }
                break;
        }
        
        return dbValue;
    }
}

+ (BOOL)isOpened
{
    @synchronized(self){
        return [[self shareDb] isOpened];
    }
}

+ (void)class:(Class)aClass getPropertyNameList:(NSMutableArray *)proName primaryKeys:(NSMutableArray *)primaryKeys
{
        unsigned int count;
        objc_property_t *properties = class_copyPropertyList(aClass, &count);
        
        for (int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            NSString * key = [STDbHandle dbNameConvertFromObjc_property_t:property];
            NSString *type = [STDbHandle dbTypeConvertFromObjc_property_t:property];
            
            NSString *proStr;
            
            if ([key isEqualToString:kDbId]) {
                [primaryKeys addObject:kDbId];
                proStr = [NSString stringWithFormat:@"%@ %@", kDbId, DBInt];
            } else if ([key hasSuffix:kDbKeySuffix]) {
                [primaryKeys addObject:key];
                proStr = [NSString stringWithFormat:@"%@ %@", key, type];
            } else {
                proStr = [NSString stringWithFormat:@"%@ %@", key, type];
            }

            [proName addObject:proStr];
        }
        
        if (aClass == [STDbObject class]) {
            return;
        }
        [STDbHandle class:[aClass superclass] getPropertyNameList:proName primaryKeys:primaryKeys];
    
}

+ (void)class:(Class)aClass getPropertyKeyList:(NSMutableArray *)proName
{
    @synchronized(self){
        unsigned int count;
        objc_property_t *properties = class_copyPropertyList(aClass, &count);
        
        for (int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            NSString * key = [[NSString alloc]initWithCString:property_getName(property)  encoding:NSUTF8StringEncoding];
            [proName addObject:key];
        }
        
        if (aClass == [STDbObject class]) {
            return;
        }
        [STDbHandle class:[aClass superclass] getPropertyKeyList:proName];
    }
}

+ (void)class:(Class)aClass getPropertyTypeList:(NSMutableArray *)proName
{
    @synchronized(self){
        unsigned int count;
        objc_property_t *properties = class_copyPropertyList(aClass, &count);
        
        for (int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            NSString *type = [STDbHandle dbTypeConvertFromObjc_property_t:property];
            [proName addObject:type];
        }
        
        if (aClass == [STDbObject class]) {
            return;
        }
        [STDbHandle class:[aClass superclass] getPropertyTypeList:proName];
    }
}

+ (NSInteger)lastRowIdWithClass:(Class)aClass;
{
    @synchronized(self){
        NSInteger rowId = 0;
        [self openDb];
        
        sqlite3_stmt *stmt = NULL;
        
        NSMutableString *sql = [NSMutableString stringWithCapacity:0];
        [sql appendString:@"select max(rowid) as rowId from "];
        [sql appendString:NSStringFromClass(aClass)];
        [sql appendString:@";"];
        
        if (sqlite3_prepare_v2([[self shareDb] sqlite3DB], [sql UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_step(stmt);
            int value = sqlite3_column_int(stmt, 0);
            rowId = value;
        }
        sqlite3_finalize(stmt);
        stmt = NULL;
        
        return rowId;
    }
}

+ (NSString *)encryptKey
{
    return @"stlwtr";
}

#pragma mark - 


@end

@interface NSData (STDbHandle)

- (NSString *)base64String;
/** 加密 */
- (NSData *)aes256EncryptWithKey:(NSString *)key;
/** 解密 */
- (NSData *)aes256DecryptWithKey:(NSString *)key;

@end

@implementation NSData (STDbHandle)

- (NSString *)base64String
{
    NSData *data = [self copy];
    
    NSString *encoding = nil;
    unsigned char *encodingBytes = NULL;
    @try {
        static char encodingTable[64] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        static NSUInteger paddingTable[] = {0,2,1};
        //                 Table 1: The Base 64 Alphabet
        //
        //    Value Encoding  Value Encoding  Value Encoding  Value Encoding
        //        0 A            17 R            34 i            51 z
        //        1 B            18 S            35 j            52 0
        //        2 C            19 T            36 k            53 1
        //        3 D            20 U            37 l            54 2
        //        4 E            21 V            38 m            55 3
        //        5 F            22 W            39 n            56 4
        //        6 G            23 X            40 o            57 5
        //        7 H            24 Y            41 p            58 6
        //        8 I            25 Z            42 q            59 7
        //        9 J            26 a            43 r            60 8
        //       10 K            27 b            44 s            61 9
        //       11 L            28 c            45 t            62 +
        //       12 M            29 d            46 u            63 /
        //       13 N            30 e            47 v
        //       14 O            31 f            48 w         (pad) =
        //       15 P            32 g            49 x
        //       16 Q            33 h            50 y
        
        NSUInteger dataLength = [data length];
        NSUInteger encodedBlocks = (dataLength * 8) / 24;
        NSUInteger padding = paddingTable[dataLength % 3];
        if( padding > 0 ) encodedBlocks++;
        NSUInteger encodedLength = encodedBlocks * 4;
        
        encodingBytes = malloc(encodedLength);
        if( encodingBytes != NULL ) {
            NSUInteger rawBytesToProcess = dataLength;
            NSUInteger rawBaseIndex = 0;
            NSUInteger encodingBaseIndex = 0;
            unsigned char *rawBytes = (unsigned char *)[data bytes];
            unsigned char rawByte1, rawByte2, rawByte3;
            while( rawBytesToProcess >= 3 ) {
                rawByte1 = rawBytes[rawBaseIndex];
                rawByte2 = rawBytes[rawBaseIndex+1];
                rawByte3 = rawBytes[rawBaseIndex+2];
                encodingBytes[encodingBaseIndex] = encodingTable[((rawByte1 >> 2) & 0x3F)];
                encodingBytes[encodingBaseIndex+1] = encodingTable[((rawByte1 << 4) & 0x30) | ((rawByte2 >> 4) & 0x0F) ];
                encodingBytes[encodingBaseIndex+2] = encodingTable[((rawByte2 << 2) & 0x3C) | ((rawByte3 >> 6) & 0x03) ];
                encodingBytes[encodingBaseIndex+3] = encodingTable[(rawByte3 & 0x3F)];
                
                rawBaseIndex += 3;
                encodingBaseIndex += 4;
                rawBytesToProcess -= 3;
            }
            rawByte2 = 0;
            switch (dataLength-rawBaseIndex) {
                case 2:
                    rawByte2 = rawBytes[rawBaseIndex+1];
                case 1:
                    rawByte1 = rawBytes[rawBaseIndex];
                    encodingBytes[encodingBaseIndex] = encodingTable[((rawByte1 >> 2) & 0x3F)];
                    encodingBytes[encodingBaseIndex+1] = encodingTable[((rawByte1 << 4) & 0x30) | ((rawByte2 >> 4) & 0x0F) ];
                    encodingBytes[encodingBaseIndex+2] = encodingTable[((rawByte2 << 2) & 0x3C) ];
                    // we can skip rawByte3 since we have a partial block it would always be 0
                    break;
            }
            // compute location from where to begin inserting padding, it may overwrite some bytes from the partial block encoding
            // if their value was 0 (cases 1-2).
            encodingBaseIndex = encodedLength - padding;
            while( padding-- > 0 ) {
                encodingBytes[encodingBaseIndex++] = '=';
            }
            encoding = [[NSString alloc] initWithBytes:encodingBytes length:encodedLength encoding:NSASCIIStringEncoding];
        }
    }
    @catch (NSException *exception) {
        encoding = nil;
        NSLog(@"WARNING: error occured while tring to encode base 32 data: %@", exception);
    }
    @finally {
        if( encodingBytes != NULL ) {
            free( encodingBytes );
        }
    }
    return encoding;
}

/** 加密 */
- (NSData *)aes256EncryptWithKey:(NSString *)key
{
    char keyPtr[kCCKeySizeAES256+1];
    bzero(keyPtr, sizeof(keyPtr));
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    NSUInteger dataLength = [self length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding | kCCOptionECBMode,
                                          keyPtr, kCCBlockSizeAES128,
                                          NULL,
                                          [self bytes], dataLength,
                                          buffer, bufferSize,
                                          &numBytesEncrypted);
    if (cryptStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    free(buffer);
    return nil;
}

/** 解密 */
- (NSData *)aes256DecryptWithKey:(NSString *)key
{
    char keyPtr[kCCKeySizeAES256+1];
    bzero(keyPtr, sizeof(keyPtr));
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    NSUInteger dataLength = [self length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding | kCCOptionECBMode,
                                          keyPtr, kCCBlockSizeAES128,
                                          NULL,
                                          [self bytes], dataLength,
                                          buffer, bufferSize,
                                          &numBytesDecrypted);
    if (cryptStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    free(buffer);
    return nil;
}

@end

@implementation NSString (STDbHandle)

- (NSData *)base64Data;
{
    NSString *encoding = [self copy];
    
    NSData *data = nil;
    unsigned char *decodedBytes = NULL;
    @try {
#define __ 255
        static char decodingTable[256] = {
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x00 - 0x0F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x10 - 0x1F
            __,__,__,__, __,__,__,__, __,__,__,62, __,__,__,63,  // 0x20 - 0x2F
            52,53,54,55, 56,57,58,59, 60,61,__,__, __, 0,__,__,  // 0x30 - 0x3F
            __, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,  // 0x40 - 0x4F
            15,16,17,18, 19,20,21,22, 23,24,25,__, __,__,__,__,  // 0x50 - 0x5F
            __,26,27,28, 29,30,31,32, 33,34,35,36, 37,38,39,40,  // 0x60 - 0x6F
            41,42,43,44, 45,46,47,48, 49,50,51,__, __,__,__,__,  // 0x70 - 0x7F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x80 - 0x8F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x90 - 0x9F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xA0 - 0xAF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xB0 - 0xBF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xC0 - 0xCF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xD0 - 0xDF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xE0 - 0xEF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xF0 - 0xFF
        };
        encoding = [encoding stringByReplacingOccurrencesOfString:@"=" withString:@""];
        NSData *encodedData = [encoding dataUsingEncoding:NSASCIIStringEncoding];
        unsigned char *encodedBytes = (unsigned char *)[encodedData bytes];
        
        NSUInteger encodedLength = [encodedData length];
        NSUInteger encodedBlocks = (encodedLength+3) >> 2;
        NSUInteger expectedDataLength = encodedBlocks * 3;
        
        unsigned char decodingBlock[4];
        
        decodedBytes = malloc(expectedDataLength);
        if( decodedBytes != NULL ) {
            
            NSUInteger i = 0;
            NSUInteger j = 0;
            NSUInteger k = 0;
            unsigned char c;
            while( i < encodedLength ) {
                c = decodingTable[encodedBytes[i]];
                i++;
                if( c != __ ) {
                    decodingBlock[j] = c;
                    j++;
                    if( j == 4 ) {
                        decodedBytes[k] = (decodingBlock[0] << 2) | (decodingBlock[1] >> 4);
                        decodedBytes[k+1] = (decodingBlock[1] << 4) | (decodingBlock[2] >> 2);
                        decodedBytes[k+2] = (decodingBlock[2] << 6) | (decodingBlock[3]);
                        j = 0;
                        k += 3;
                    }
                }
            }
            
            // Process left over bytes, if any
            if( j == 3 ) {
                decodedBytes[k] = (decodingBlock[0] << 2) | (decodingBlock[1] >> 4);
                decodedBytes[k+1] = (decodingBlock[1] << 4) | (decodingBlock[2] >> 2);
                k += 2;
            } else if( j == 2 ) {
                decodedBytes[k] = (decodingBlock[0] << 2) | (decodingBlock[1] >> 4);
                k += 1;
            }
            data = [[NSData alloc] initWithBytes:decodedBytes length:k];
        }
    }
    @catch (NSException *exception) {
        data = nil;
        NSLog(@"WARNING: error occured while decoding base 32 string: %@", exception);
    }
    @finally {
        if( decodedBytes != NULL ) {
            free( decodedBytes );
        }
    }
    return data;
}

- (NSString *)encryptWithKey:(NSString *)key;
{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    NSData *eData = [data aes256EncryptWithKey:key];
    NSString *base64String = [eData base64String];
    return base64String;
}

- (NSString *)decryptWithKey:(NSString *)key;
{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    NSData *eData = [data aes256DecryptWithKey:key];
    NSString *base64String = [eData base64String];
    return base64String;
}

@end

objc_property_t * st_class_copyPropertyList(Class cls, unsigned int *count)
{
    if (![cls isSubclassOfClass:[STDbObject class]]) {
        return NULL;
    };
    objc_property_t *properties = class_copyPropertyList(cls, count);
    if (!properties) {
        while (1) {
            cls = [cls superclass];
            properties = class_copyPropertyList(cls, count);
            if (properties) {
                break;
            }
        }
    }
    return properties;
}

