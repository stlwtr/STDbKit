//
//  STDb.m
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

#import "STDb.h"
#import <sqlite3.h>
#import "STDbObject.h"

#import "NSDate+STDbHandle.h"
#import "NSData+STDbHandle.h"
#import "NSObject+STDbHandle.h"
#import "NSString+STDbHandle.h"
#import "STDbObjectProperty.h"

NSString *STDbDefaultName = @"stdb_default.sqlite";
static NSMutableDictionary *stdbClassPropertiesDictionary;

#ifdef STDBEncryptEnable
#define SQLITE_HAS_CODEC 1
#endif

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
static int STDBBusyHandler(void *f, int count);

enum {
    DBObjAttrInt,
    DBObjAttrFloat,
    DBObjAttrString,
    DBObjAttrData,
    DBObjAttrDate,
    DBObjAttrArray,
    DBObjAttrDictionary,
};

@interface STDb()
{
    NSString *_dbPath;
    NSTimeInterval _startBusyRetryTime;
    NSTimeInterval _maxBusyRetryTimeInterval;
    BOOL _inTransaction;
    
    NSMutableDictionary *_dbTableColumnsCache;
}

@property (nonatomic) sqlite3 *sqlite3DB;
@property (nonatomic, assign) BOOL isOpened;

@end

@implementation STDb

+ (void)importDb:(NSString *)dbName
{
    
}

+ (BOOL)setCurrentDbPath:(NSString *)dbPath;
{
    return NO;
}

- (instancetype)init {
    return [self initWithPath:[STDb defaultDbPath]];
}

#pragma mark - path 

+ (NSString *)defaultDbPath {
    NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *path = [NSString stringWithFormat:@"%@/%@", document, STDbDefaultName];
    return path;
}

+ (NSString *)currentDbPath;
{
    return nil;
}

+ (instancetype)dbWithPath:(NSString *)path;
{
    if (path == nil || path.length == 0) {
        path = [self defaultDbPath];
    }
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
    
    STDb *db = [[STDb alloc] initWithPath:filePath];
    
    return db;
}

+ (instancetype)defaultDb;
{
    return [STDb dbWithPath:[STDb defaultDbPath]];
}

- (NSString *)dbPath
{
    return _dbPath;
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _maxBusyRetryTimeInterval = 2.0;
        _dbPath = path;
        
        _dbTableColumnsCache = [NSMutableDictionary dictionary];
        
#ifdef STDb_EncryptEnable
        self.encryptEnable = YES;
#endif
    }
    return self;
}

- (BOOL)executeQuery:(NSString *)query resultBlock:(STDbExecuteCallBackBlock)block;
{
    return [self dbTable:nil executeQuery:query callBackBlock:block];
}

- (BOOL)executeQuery:(NSString *)query;
{
    return [self dbTable:nil executeQuery:query callBackBlock:nil];
}

- (BOOL)executeUpdate:(NSString*)query {
    BOOL result = [self executeQuery:query];
    return result;
}

- (BOOL)executeUpdate:(NSString*)query dictionaryArgs:(NSDictionary *)dictionaryArgs {
    BOOL result = [self executeUpdate:query error:nil dictionaryArgs:dictionaryArgs];
    return result;
}

#pragma mark - transaction

- (BOOL)beginTransaction {
    
    BOOL rc = [self executeUpdate:@"begin exclusive transaction"];
    
    if (rc) {
        _inTransaction = YES;
    }
    return rc;
}

- (BOOL)commit {
    BOOL rc =  [self executeUpdate:@"commit transaction"];
    
    if (rc) {
        _inTransaction = NO;
    }
    
    return rc;
}

- (BOOL)rollback {
    BOOL rc = [self executeUpdate:@"rollback transaction"];
    
    if (rc) {
        _inTransaction = NO;
    }
    
    return rc;
}

- (BOOL)inTransaction {
    return _inTransaction;
}

#pragma mark - private method

- (NSInteger)lastRowIdWithClass:(Class)aClass;
{
    @synchronized(self){
        NSInteger rowId = 0;
        [self openDb];
        
        sqlite3_stmt *stmt = NULL;
        
        NSMutableString *sql = [NSMutableString stringWithCapacity:0];
        [sql appendString:@"select max(rowid) as rowId from "];
        [sql appendString:NSStringFromClass(aClass)];
        [sql appendString:@";"];
        
        if (sqlite3_prepare_v2([self sqlite3DB], [sql UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_step(stmt);
            int value = sqlite3_column_int(stmt, 0);
            rowId = value;
        }
        sqlite3_finalize(stmt);
        stmt = NULL;
        
        return rowId;
    }
}

- (NSString *)encryptKey
{
    return @"stlwtr";
}

#pragma mark - objc_property_t method

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

- (NSArray *)sqlite_columns:(Class)cls
{
    NSArray *columnsInfo = [_dbTableColumnsCache objectForKey:NSStringFromClass(cls)];
    if (!columnsInfo) {
        columnsInfo = [self tableColumnsCache:cls];
        [_dbTableColumnsCache setObject:columnsInfo forKey:NSStringFromClass(cls)];
    }
    return columnsInfo;
}

- (NSArray *)tableColumnsCache:(Class)cls {
    NSString *table = NSStringFromClass(cls);
    NSMutableString *sql;
    
    sqlite3_stmt *stmt = NULL;
    NSString *str = [NSString stringWithFormat:@"select sql from sqlite_master where type='table' and tbl_name='%@'", table];
    STDb *stdb = self;
    [self openDb];
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
}

- (NSString *)dbTypeConvertFromObjc_property_t:(objc_property_t)property
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
            case 's' :  // short
            case 'i':   // int
            case 'l':   // long
            case 'q':   // long
            case 'I':   // NSInteger
            case 'Q':   // NSUInteger
            case 'B':   // BOOL
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

- (NSString *)dbNameConvertFromObjc_property_t:(objc_property_t)property
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

- (id)valueForObjc_property_t:(objc_property_t)property dbValue:(id)dbValue
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
                    if ([self encryptEnable]) {
                        retStr = [retStr decryptWithKey:[self encryptKey]];
                    }
                    return retStr;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSNumber class]]) {
                    return [NSNumber numberWithDouble:[dbValue doubleValue]];
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSDictionary class]]) {
                    NSString *retStr = [dbValue copy];
                    if ([self encryptEnable]) {
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
                                NSString *__id__ = arr[1];
                                
                                NSString *where = [NSString stringWithFormat:@"%@=%@", kDbId, __id__];
                                
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
                    if ([self encryptEnable]) {
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
                                NSString *__id__ = arr[1];
                                
                                NSString *where = [NSString stringWithFormat:@"%@=%@", kDbId, __id__];
                                NSString *queryStr = [NSString stringWithFormat:@"select * from %@ where %@;", clsName, where];
                                [self executeQuery:queryStr resultBlock:^(NSArray *resultArray) {
                                    if (resultArray.count > 0) {
                                        [results addObject:resultArray[0]];
                                    }
                                }];
                                continue;
                            }
                        }
                        
                        [results addObject:obj];
                    }
                    
                    return results;
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSDate class]]) {
                    NSString *retStr = [dbValue copy];
                    if ([self encryptEnable]) {
                        retStr = [retStr decryptWithKey:[self encryptKey]];
                    }
                    return [NSDate dateWithString:[NSString stringWithFormat:@"%@", retStr]];
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[NSValue class]]) {
                    return [NSData dataWithData:dbValue];
                }
                
                if ([NSClassFromString(cls) isSubclassOfClass:[STDbObject class]]) {
                    NSString *userFlag = (NSString *)dbValue;
                    NSMutableArray *results = [NSMutableArray array];
                    
                    if ([userFlag isKindOfClass:[NSString class]]) {
                        NSString *__id__Str = [userFlag stringByReplacingOccurrencesOfString:DBChildPrefix withString:@""];
                        NSArray *arr = [__id__Str componentsSeparatedByString:@","];
                        NSString *clsName = arr[0];
                        NSString *__id__ = arr[1];
                        NSString *where = [[NSString alloc] initWithFormat:@"%@ = \"%@\" and %@ is not null", kDbId, __id__, kDbPId];
                        
                        NSString *queryStr = [NSString stringWithFormat:@"select * from %@ where %@;", clsName, where];
                        [self executeQuery:queryStr resultBlock:^(NSArray *resultArray) {
                            if (resultArray.count > 0) {
                                id object = [NSClassFromString(clsName) objcFromDictionary:resultArray[0]];
                                [results addObject:object];
                            }
                        }];
                    }
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

- (void)bindObject:(id)obj toColumn:(int)idx inStatement:(sqlite3_stmt*)pStmt {
    
    if ((!obj) || ((NSNull *)obj == [NSNull null])) {
        sqlite3_bind_null(pStmt, idx);
    }
    
    // FIXME - someday check the return codes on these binds.
    else if ([obj isKindOfClass:[NSData class]]) {
        const void *bytes = [obj bytes];
        if (!bytes) {
            // it's an empty NSData object, aka [NSData data].
            // Don't pass a NULL pointer, or sqlite will bind a SQL null instead of a blob.
            bytes = "";
        }
        sqlite3_bind_blob(pStmt, idx, bytes, (int)[obj length], SQLITE_STATIC);
    }
    else if ([obj isKindOfClass:[NSDate class]]) {
        sqlite3_bind_text(pStmt, idx, [[NSDate stringWithDate:obj] UTF8String], -1, SQLITE_STATIC);
    }
    else if ([obj isKindOfClass:[NSNumber class]]) {
        
        if (strcmp([obj objCType], @encode(char)) == 0) {
            sqlite3_bind_int(pStmt, idx, [obj charValue]);
        }
        else if (strcmp([obj objCType], @encode(unsigned char)) == 0) {
            sqlite3_bind_int(pStmt, idx, [obj unsignedCharValue]);
        }
        else if (strcmp([obj objCType], @encode(short)) == 0) {
            sqlite3_bind_int(pStmt, idx, [obj shortValue]);
        }
        else if (strcmp([obj objCType], @encode(unsigned short)) == 0) {
            sqlite3_bind_int(pStmt, idx, [obj unsignedShortValue]);
        }
        else if (strcmp([obj objCType], @encode(int)) == 0) {
            sqlite3_bind_int(pStmt, idx, [obj intValue]);
        }
        else if (strcmp([obj objCType], @encode(unsigned int)) == 0) {
            sqlite3_bind_int64(pStmt, idx, (long long)[obj unsignedIntValue]);
        }
        else if (strcmp([obj objCType], @encode(long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longValue]);
        }
        else if (strcmp([obj objCType], @encode(unsigned long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, (long long)[obj unsignedLongValue]);
        }
        else if (strcmp([obj objCType], @encode(long long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longLongValue]);
        }
        else if (strcmp([obj objCType], @encode(unsigned long long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, (long long)[obj unsignedLongLongValue]);
        }
        else if (strcmp([obj objCType], @encode(float)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj floatValue]);
        }
        else if (strcmp([obj objCType], @encode(double)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj doubleValue]);
        }
        else if (strcmp([obj objCType], @encode(BOOL)) == 0) {
            sqlite3_bind_int(pStmt, idx, ([obj boolValue] ? 1 : 0));
        }
        else {
            sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
        }
    }
    else {
        sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
    }
}

- (id)valueForDbObjc_property_t:(objc_property_t)property dbValue:(id)dbValue _id:(NSString *)_id
{
    @synchronized(self){
        if (!dbValue) {
            return nil;
        }
        char * type = property_copyAttributeValue(property, "T");
        
        if (type[0] != '@') {
            return dbValue;
        } else {
            NSString *cls = [NSString stringWithUTF8String:type];
            cls = [cls stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            cls = [cls stringByReplacingOccurrencesOfString:@"@" withString:@""];
            cls = [cls stringByReplacingOccurrencesOfString:@"\"" withString:@""];
            
            if ([NSClassFromString(cls) isSubclassOfClass:[NSString class]]) {
                NSString *retStr = [NSString stringWithFormat:@"%@", [NSString stringWithFormat:@"%@", dbValue]];
                if ([self encryptEnable]) {
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
                        
                        [dbObject setValue:_id forKey:kPId];
                        [self replaceDbObject:dbObject];
                        
                        NSInteger rowid = [dbObject.class lastRowId];
                        
                        [results setObject:[NSString stringWithFormat:@"%@%@,%@", DBChildPrefix, NSStringFromClass(obj.class),@(rowid)]  forKey:key];
                    } else {
                        [results setObject:obj forKey:key];
                    }
                }
                
                NSString *retStr = [NSString stringWithFormat:@"%@", [NSDictionary stringWithObject:results]];
                if ([self encryptEnable]) {
                    retStr = [retStr encryptWithKey:[self encryptKey]];
                }
                return retStr;
            }
            
            if ([NSClassFromString(cls) isSubclassOfClass:[NSArray class]]) {
                
                NSMutableArray *results = [NSMutableArray arrayWithCapacity:0];
                for (NSObject *obj in (NSArray *)dbValue) {
                    if ([obj isKindOfClass:[STDbObject class]]) {
                        STDbObject *dbObject = (STDbObject *)obj;
                        
                        [dbObject setValue:_id forKey:kPId];
                        [self replaceDbObject:dbObject];
                        
                        NSInteger rowid = [dbObject.class lastRowId];
                        
                        [results addObject:[NSString stringWithFormat:@"%@%@,%@", DBChildPrefix, NSStringFromClass(obj.class),@(rowid)]];
                    } else {
                        [results addObject:obj];
                    }
                }
                NSString *retStr = [NSString stringWithFormat:@"%@", [NSArray stringWithObject:results]];
                if ([self encryptEnable]) {
                    retStr = [retStr encryptWithKey:[self encryptKey]];
                }
                return retStr;
            }
            
            if ([NSClassFromString(cls) isSubclassOfClass:[NSDate class]]) {
                if ([dbValue isKindOfClass:[NSDate class]]) {
                    NSString *retStr = [NSString stringWithFormat:@"%@", [NSDate stringWithDate:dbValue]];
                    if ([self encryptEnable]) {
                        retStr = [retStr encryptWithKey:[self encryptKey]];
                    }
                    return retStr;
                }
            }
            
            if ([NSClassFromString(cls) isSubclassOfClass:[NSValue class]]) {
                return [NSData dataWithData:dbValue];
            }
            
            if ([NSClassFromString(cls) isSubclassOfClass:[STDbObject class]]) {
                return dbValue;
            }
        }
        
        return dbValue;
    }
}

- (NSArray *)keyTypeArrayForClass:(Class)class {
    NSArray *properties = [class properties];
    
    NSMutableArray *keyTypeArray = [NSMutableArray array];
    
    for (STDbObjectProperty *p in properties) {
        NSString *keyTypeStr = [NSString stringWithFormat:@"%@ %@", p.name, p.dbType];
        [keyTypeArray addObject:keyTypeStr];
    }
    
    return keyTypeArray;
}

- (void)class:(Class)aClass getPropertyNameList:(NSMutableArray *)proName primaryKeys:(NSMutableArray *)primaryKeys  __attribute__ ((deprecated))
{
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList(aClass, &count);
    
    for (int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        NSString * key = [self dbNameConvertFromObjc_property_t:property];
        NSString *type = [self dbTypeConvertFromObjc_property_t:property];
        
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
    [self class:[aClass superclass] getPropertyNameList:proName primaryKeys:primaryKeys];
    
}

- (void)class:(Class)aClass getPropertyKeyList:(NSMutableArray *)proName
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
        [self class:[aClass superclass] getPropertyKeyList:proName];
    }
}

- (void)class:(Class)aClass getPropertyTypeList:(NSMutableArray *)proName
{
    @synchronized(self){
        unsigned int count;
        objc_property_t *properties = class_copyPropertyList(aClass, &count);
        
        for (int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            NSString *type = [self dbTypeConvertFromObjc_property_t:property];
            [proName addObject:type];
        }
        
        if (aClass == [STDbObject class]) {
            return;
        }
        [self class:[aClass superclass] getPropertyTypeList:proName];
    }
}

#pragma mark - sqlite busy handle

- (int)busyRetryTimeout {
    NSLog(@"%s:%d", __FUNCTION__, __LINE__);
    NSLog(@"FMDB: busyRetryTimeout no longer works, please use maxBusyRetryTimeInterval");
    return -1;
}

- (void)setBusyRetryTimeout:(int)i {
    NSLog(@"%s:%d", __FUNCTION__, __LINE__);
    NSLog(@"FMDB: setBusyRetryTimeout does nothing, please use setMaxBusyRetryTimeInterval:");
}

static int STDBBusyHandler(void *f, int count) {
    STDb *self = (__bridge STDb*)f;
    
    if (count == 0) {
        self->_startBusyRetryTime = [NSDate timeIntervalSinceReferenceDate];
        return 1;
    }
    
    NSTimeInterval delta = [NSDate timeIntervalSinceReferenceDate] - (self->_startBusyRetryTime);
    
    if (delta < [self maxBusyRetryTimeInterval]) {
        int requestedSleepInMillseconds = arc4random_uniform(50) + 50;
        int actualSleepInMilliseconds = sqlite3_sleep(requestedSleepInMillseconds);
        if (actualSleepInMilliseconds != requestedSleepInMillseconds) {
            NSLog(@"WARNING: Requested sleep of %i milliseconds, but SQLite returned %i. Maybe SQLite wasn't built with HAVE_USLEEP=1?", requestedSleepInMillseconds, actualSleepInMilliseconds);
        }
        return 1;
    }
    
    return 0;
}

- (void)setMaxBusyRetryTimeInterval:(NSTimeInterval)timeout {
    
    _maxBusyRetryTimeInterval = timeout;
    
    if (!_sqlite3DB) {
        return;
    }
    
    if (timeout > 0) {
        sqlite3_busy_handler(_sqlite3DB, &STDBBusyHandler, (__bridge void *)(self));
    }
    else {
        // turn it off otherwise
        sqlite3_busy_handler(_sqlite3DB, nil, nil);
    }
}

- (NSTimeInterval)maxBusyRetryTimeInterval {
    return _maxBusyRetryTimeInterval;
}

#pragma mark - create、insert、update、delete

- (NSMutableArray *)selectDbObjects:(Class)aClass condition:(NSString *)condition orderby:(NSString *)orderby
{
    if (![self isOpened]) {
        [self openDb];
    }

    NSString *tableName = NSStringFromClass(aClass);
    
    if (![self sqlite_tableExist:aClass]) {
        [self createDbTable:aClass];
    }
    
    [self upgradeTableIfNeed:aClass];
    
    // 清除过期数据
    [self cleanExpireDbObject:aClass];
    
    sqlite3_stmt *stmt = NULL;
    NSMutableArray *array = nil;
    NSMutableString *selectstring = nil;
    
    selectstring = [[NSMutableString alloc] initWithFormat:@"select %@ from %@", @"*", tableName];
    if (condition != nil || [condition length] != 0) {
        if (![[condition lowercaseString] isEqualToString:@"all"]) {
            [selectstring appendFormat:@" where %@", condition];
            if (![condition containsString:kDbPId]) {
                [selectstring appendFormat:@" and %@ is null", kDbPId];
            }
        } else {
            [selectstring appendFormat:@" where %@ is null", kDbPId];
        }
    } else {
        [selectstring appendFormat:@" where %@ is null", kDbPId];
    }
    
    if (orderby != nil || [orderby length] != 0) {
        if (![[orderby lowercaseString] isEqualToString:@"no"]) {
            [selectstring appendFormat:@" order by %@", orderby];
        }
    }
    
    [selectstring appendString:@";"];
    
    STDb *db = self;
    sqlite3 *sqlite3DB = db.sqlite3DB;
    
    if (sqlite3_prepare_v2(sqlite3DB, [selectstring UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
        int column_count = sqlite3_column_count(stmt);
        
        int rc = sqlite3_step(stmt);
        
        while (rc == SQLITE_ROW) {
            
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
                        id objValue = [self valueForObjc_property_t:property_t dbValue:column_value];
                        NSString *objectKey = [NSString stringWithFormat:@"_%@", key];
                        Ivar ivar = class_getInstanceVariable([obj class], objectKey.UTF8String);
                        const char* typeEncoding = ivar_getTypeEncoding(ivar);
                        if (objValue) {
                            if (typeEncoding[0] == '*') {
                                object_setIvar(obj, ivar, objValue);
                            } else {
                                [obj setValue:objValue forKey:key];
                            }
                        }
                    }
                } else if ([obj_column_decltype isEqualToString:@"integer"]) {
                    int value = sqlite3_column_int(stmt, i);
                    column_value = [NSNumber numberWithInt: value];
                    id objValue = [self valueForObjc_property_t:property_t dbValue:column_value];
                    [obj setValue:objValue forKey:key];
                } else if ([obj_column_decltype isEqualToString:@"real"]) {
                    double value = sqlite3_column_double(stmt, i);
                    column_value = [NSNumber numberWithDouble:value];
                    id objValue = [self valueForObjc_property_t:property_t dbValue:column_value];
                    [obj setValue:objValue forKey:key];
                } else if ([obj_column_decltype isEqualToString:@"blob"]) {
                    const void *databyte = sqlite3_column_blob(stmt, i);
                    if (databyte != NULL) {
                        int dataLenth = sqlite3_column_bytes(stmt, i);
                        column_data = [NSData dataWithBytes:databyte length:dataLenth];
                        id objValue = [self valueForObjc_property_t:property_t dbValue:column_data];
                        [obj setValue:objValue forKey:key];
                    }
                } else {
                    const unsigned char *value = sqlite3_column_text(stmt, i);
                    if (value != NULL) {
                        column_value = [NSString stringWithUTF8String: (const char *)value];
                        id objValue = [self valueForObjc_property_t:property_t dbValue:column_value];
                        [obj setValue:objValue forKey:key];
                    }
                }
            }
            if (array == nil) {
                array = [[NSMutableArray alloc] initWithObjects:obj, nil];
            } else {
                [array addObject:obj];
            }
            
            rc = sqlite3_step(stmt);
        }
    }
    
    sqlite3_finalize(stmt);
    stmt = NULL;
    
    return array;
    //    }
}

- (BOOL)updateDbObject:(STDbObject *)obj condition:(NSString *)condition
{
    //    @synchronized(self){
    
    if (![self isOpened]) {
        [self openDb];
    }
    
    NSString *tableName = NSStringFromClass(obj.class);
    
    if (![self sqlite_tableExist:obj.class]) {
        [self createDbTable:obj.class];
    }
    
    [self upgradeTableIfNeed:obj.class];
    
    sqlite3_stmt *stmt = NULL;
    int rc = -1;
    sqlite3 *sqlite3DB = [self sqlite3DB];
    
    Class cls = [obj class];
    NSArray *propertyArr = [cls properties];
    
    NSMutableArray *keys = [NSMutableArray array];
    NSMutableArray *binds = [NSMutableArray array];
    NSMutableArray *dbPropertyArr = [NSMutableArray array];
    
    for (STDbObjectProperty *p in propertyArr) {
        NSString * key = p.name;
        
        if ([key isEqualToString:kDbId] || [key isEqualToString:kDbPId]) {
            continue;
        }
        
        NSString *bindValue = [NSString stringWithFormat:@"%@=?", key];
        [binds addObject:bindValue];
        [keys addObject:key];
        [dbPropertyArr addObject:p];
    }
    
    NSString *newValue = [binds componentsJoinedByString:@","];
    
    if (![self isOpened]) {
        [self openDb];
    }
    
    NSMutableString *createStr = [NSMutableString stringWithFormat:@"update %@ set %@ where %@", tableName, newValue, condition];
    
    const char *errmsg = 0;
    if (sqlite3_prepare_v2(sqlite3DB, [createStr UTF8String], -1, &stmt, &errmsg) == SQLITE_OK) {
        
        int i = 1;
        for (STDbObjectProperty *p in dbPropertyArr) {
            NSString *key = p.name;
            NSString *column_type_string = p.dbType;
            
            id value = [self ivarObject:obj forKey:key];
            // convert to db value
            value = [self convertToDbValue:value pid:obj.__id__];
            
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
    //        [self closeDb];
    if ((rc != SQLITE_DONE) && (rc != SQLITE_ROW)) {
        fprintf(stderr,"update table fail: %s\n",errmsg);
        return NO;
    }
    return YES;
    //    }
}

- (BOOL)insertDbObject:(STDbObject *)obj;
{
    @synchronized(self){
        return [self insertDbObject:obj forced:YES];
    }
}

- (BOOL)replaceDbObject:(STDbObject *)obj;
{
    @synchronized(self){
        return[self insertDbObject:obj forced:NO];
    }
}

- (BOOL)insertDbObject:(STDbObject *)obj forced:(BOOL)forced
{
    @synchronized(self){
        if (![self isOpened]) {
            [self openDb];
        }
        
        NSString *tableName = NSStringFromClass(obj.class);
        
        if (![self sqlite_tableExist:obj.class]) {
            [self createDbTable:obj.class];
        }
        
        [self upgradeTableIfNeed:obj.class];
        
        NSArray *propertyArr = [self keyTypeArrayForClass:obj.class];
        
        NSUInteger argNum = [propertyArr count];
        
        NSString *insertSql = forced ? @"insert" : @"replace";
        NSMutableString *sql_NSString = [[NSMutableString alloc] initWithFormat:@"%@ into %@ values(?)", insertSql,tableName];
        NSRange range = [sql_NSString rangeOfString:@"?"];
        for (int i = 0; i < argNum - 1; i++) {
            [sql_NSString insertString:@",?" atIndex:range.location + 1];
        }
        
        sqlite3_stmt *stmt = NULL;
        STDb *db = self;
        sqlite3 *sqlite3DB = db.sqlite3DB;
        
        // obj包含的STDbObject对象
        //    NSMutableArray *subDbObjects = [NSMutableArray arrayWithCapacity:0];
        
        const char *errmsg = NULL;
        if (sqlite3_prepare_v2(sqlite3DB, [sql_NSString UTF8String], -1, &stmt, &errmsg) == SQLITE_OK) {
            for (int i = 1; i <= argNum; i++) {
                NSArray *keyTypeArray = [propertyArr[i - 1] componentsSeparatedByString:@" "];
                NSString * key = keyTypeArray[0];
                
                NSString *column_type_string = keyTypeArray[1];
                
                id value = [self ivarObject:obj forKey:key];
                value = [self convertToDbValue:value pid:obj.__id__];
                
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
                        NSString *column_value = value;
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
                //                [self closeDb];
                
                return NO;
            }
        }
        sqlite3_finalize(stmt);
        stmt = NULL;
        //        [self closeDb];
        
        return YES;
    }
}

- (BOOL)removeDbObjects:(Class)aClass condition:(NSString *)condition
{
    @synchronized(self){
        if (![self isOpened]) {
            [self openDb];
        }
        
        NSString *tableName = NSStringFromClass(aClass);
        
        if (![self sqlite_tableExist:aClass]) {
            [self createDbTable:aClass];
        }
        
        [self upgradeTableIfNeed:aClass];
        
        sqlite3_stmt *stmt = NULL;
        int rc = -1;
        
        sqlite3 *sqlite3DB = [self sqlite3DB];
        
        // 删掉表
        if (!condition || [[condition lowercaseString] isEqualToString:@"all"]) {
            return [self removeDbTable:aClass];
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
        //        [self closeDb];
        if ((rc != SQLITE_DONE) && (rc != SQLITE_ROW)) {
            //        fprintf(stderr,"remove dbObject fail: %s\n",errmsg);
            return NO;
        }
        return YES;
    }
}

- (BOOL)removeDbTable:(Class)aClass
{
    @synchronized(self){
        if (![self isOpened]) {
            [self openDb];
        }
        
        NSMutableString *sql = [NSMutableString stringWithCapacity:0];
        [sql appendString:@"drop table if exists "];
        [sql appendString:NSStringFromClass(aClass)];
        
        char *errmsg = 0;
        STDb *db = self;
        sqlite3 *sqlite3DB = db.sqlite3DB;
        int ret = sqlite3_exec(sqlite3DB,[sql UTF8String], NULL, NULL, &errmsg);
        if(ret != SQLITE_OK){
            fprintf(stderr,"drop table fail: %s\n",errmsg);
        }
        sqlite3_free(errmsg);
        
        //        [self closeDb];
        
        return YES;
    }
}

- (NSString *)createSqlWithClass:(Class)aClass selectSql:(NSString *)selectSql {
    NSMutableString *sql = [NSMutableString stringWithCapacity:0];
    [sql appendString:@"create table "];
    [sql appendString:NSStringFromClass(aClass)];
    [sql appendString:@"("];
    
    NSArray *propertyArr = [self keyTypeArrayForClass:aClass];
    NSArray *primaryKeys = [aClass primaryKeys];
    
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
    
    if (selectSql) {
        [sql appendString:selectSql];
    }
    
    [sql appendString:@");"];
    return sql;
};

- (NSString *)createSqlWithClass:(Class)aClass {
    return [self createSqlWithClass:aClass selectSql:nil];
}

- (void)createDbTable:(Class)aClass
{
    @synchronized(self){
        if (![self isOpened]) {
            [self openDb];
        }
        
        if ([self sqlite_tableExist:aClass]) {
            STDBLog(@"数据库表%@已存在!", NSStringFromClass(aClass));
            return;
        }
        
        if (![self isOpened]) {
            [self openDb];
        }
        
        NSString *sql = [self createSqlWithClass:aClass];
        
        char *errmsg = 0;
        STDb *db = self;
        sqlite3 *sqlite3DB = db.sqlite3DB;
        int ret = sqlite3_exec(sqlite3DB,[sql UTF8String], NULL, NULL, &errmsg);
        if(ret != SQLITE_OK){
            STDBLog("create table fail: %s\n", errmsg);
        }
        sqlite3_free(errmsg);
        
        //        [self closeDb];
    }
}

- (BOOL)dbTable:(Class)aClass executeQuery:(NSString *)query callBackBlock:(void (^)(NSArray *resultArray))block;
{
    if (query.length == 0) {
        return NO;
    }
    
    if (![self isOpened]) {
        [self openDb];
    }
    
    NSMutableString *sql = [NSMutableString stringWithCapacity:0];
    [sql appendString:query];
    
    char *errmsg = 0;
    STDb *db = self;
    
    __block NSMutableArray *resultArray = [NSMutableArray array];
    int (^resultBlock)(NSDictionary *resultDictionary) = ^(NSDictionary *resultDictionary) {
        if ([resultDictionary isKindOfClass:[NSDictionary class]]) {
            [resultArray addObject:resultDictionary];
        }
        return 0;
    };
    int ret = sqlite3_exec(db.sqlite3DB, [sql UTF8String], block ? STDbExecuteBulkSQLCallback : nil, (__bridge void *)(resultBlock), &errmsg);
    
    if(ret != SQLITE_OK){
        fprintf(stderr, "sqlite3_exec fail: %s\n", errmsg);
    }
    sqlite3_free(errmsg);
    if (block) {
        block(resultArray);
    }
    return ret == SQLITE_OK;
}

- (BOOL)executeUpdate:(NSString *)sql error:(NSError**)outErr dictionaryArgs:(NSDictionary *)dictionaryArgs {
    
    if (![self isOpened]) {
        [self openDb];
    }
    
    sqlite3_stmt *stmt = NULL;
    STDb *db = self;
    
    // obj包含的STDbObject对象
    //    NSMutableArray *subDbObjects = [NSMutableArray arrayWithCapacity:0];
    
    const char *errmsg = NULL;
    if (sqlite3_prepare_v2(db.sqlite3DB, [sql UTF8String], -1, &stmt, &errmsg) == SQLITE_OK) {
        
        NSInteger idx = 0;
        
        for (NSString *dictionaryKey in [dictionaryArgs allKeys]) {
            
            // Prefix the key with a colon.
            NSString *parameterName = [[NSString alloc] initWithFormat:@":%@", dictionaryKey];
            const char *zName = [parameterName UTF8String];
            // Get the index for the parameter name.
            int namedIdx = sqlite3_bind_parameter_index(stmt, zName);
            
            if (namedIdx > 0) {
                // Standard binding from here.
                [self bindObject:[dictionaryArgs objectForKey:dictionaryKey] toColumn:namedIdx inStatement:stmt];
                // increment the binding count, so our check below works out
                idx++;
            }
        }
        
        int rc = sqlite3_step(stmt);
        
        if ((rc != SQLITE_DONE) && (rc != SQLITE_ROW)) {
            fprintf(stderr, "%s dbObject fail: %s\n", "executeUpdate", errmsg);
            sqlite3_finalize(stmt);
            stmt = NULL;
            //                [self closeDb];
            
            return NO;
        }
    } else {
        sqlite3_finalize(stmt);
        stmt = NULL;
        
        return NO;
    }
    sqlite3_finalize(stmt);
    stmt = NULL;
    
    return YES;
}

int STDbExecuteBulkSQLCallback(void *theBlockAsVoid, int columns, char **values, char **names) {
    
    if (!theBlockAsVoid) {
        return SQLITE_OK;
    }
    
    int (^execCallbackBlock)(NSDictionary *resultsDictionary) = (__bridge int (^)(NSDictionary *__strong))(theBlockAsVoid);
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:(NSUInteger)columns];
    
    for (NSInteger i = 0; i < columns; i++) {
        NSString *key = [NSString stringWithUTF8String:names[i]];
        id value = values[i] ? [NSString stringWithUTF8String:values[i]] : [NSNull null];
        [dictionary setObject:value forKey:key];
    }
    
    return execCallbackBlock(dictionary);
}

#pragma mark - sqlite method

- (BOOL)isOpened
{
    @synchronized(self){
        return _isOpened;
    }
}

- (BOOL)openDb
{
    @synchronized(self){
        NSString *dbPath = _dbPath;
        STDb *db = self;
        
        int flags = SQLITE_OPEN_READWRITE;
        if ([[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
            flags = SQLITE_OPEN_READWRITE;
        } else {
            flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE;
        }
        
        if ([self isOpened]) {
            return YES;
        }
        
        int rc = sqlite3_open_v2([dbPath UTF8String], &db->_sqlite3DB, flags, NULL);
        if (rc == SQLITE_OK) {
            db.isOpened = YES;
            if (db->_maxBusyRetryTimeInterval > 0.0) {
                // set the handler
                [db setMaxBusyRetryTimeInterval:db->_maxBusyRetryTimeInterval];
            }

#ifdef SQLITE_HAS_CODEC
            NSString *key = [self encryptKey];
            NSData *keyData = [NSData dataWithBytes:[key UTF8String] length:(NSUInteger)strlen([key UTF8String])];
            
            int rc = sqlite3_key(_sqlite3DB, [keyData bytes], (int)[keyData length]);
            
            if (rc != SQLITE_OK) {
                STDBLog(@"设置encrypt key值失败!");
            }
#endif
            return (rc == SQLITE_OK);
            
            return YES;
        } else {
            STDBLog(@"打开数据库%@失败!", dbPath);
            return NO;
        }
        
        return NO;
    }
}

- (BOOL)sqlite_tableExist:(Class)aClass {
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

- (NSArray *)sqlite_tablename {
    @synchronized(self){
        if (![self isOpened]) {
            [self openDb];
        }
        
        sqlite3_stmt *stmt = NULL;
        NSMutableArray *tablenameArray = [[NSMutableArray alloc] init];
        NSString *str = [NSString stringWithFormat:@"select tbl_name from sqlite_master where type='table'"];
        sqlite3 *sqlite3DB = [self sqlite3DB];
        if (sqlite3_prepare_v2(sqlite3DB, [str UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
            while (SQLITE_ROW == sqlite3_step(stmt)) {
                const unsigned char *text = sqlite3_column_text(stmt, 0);
                [tablenameArray addObject:[NSString stringWithUTF8String:(const char *)text]];
            }
        }
        sqlite3_finalize(stmt);
        stmt = NULL;
        
        return tablenameArray;
    }
}

- (BOOL)cleanExpireDbObject:(Class)aClass
{
    @synchronized(self){
        if (![self isOpened]) {
            [self openDb];
        }
        
        NSString *dateStr = [NSDate stringWithDate:[NSDate date]];
        NSString *condition = [NSString stringWithFormat:@"expireDate<'%@'", dateStr];
        [self removeDbObjects:aClass condition:condition];
        
        if (![self isOpened]) {
            [self openDb];
        }
        return YES;
    }
}

#pragma mark - version for dbobject

- (BOOL)upgradeTableIfNeed:(Class)cls {
    if ([self shouldUpgradeDbObjectTable:cls]) {
        NSArray *columns = [self sqlite_columns:cls];
        NSMutableArray *columnArr = [NSMutableArray array];
        for (NSDictionary *dict in columns) {
            [columnArr addObject:dict[@"title"]];
        }
        
        NSArray *propertyArr = [self keyTypeArrayForClass:cls];
        
        NSMutableArray *propertyNames = [NSMutableArray array];
        for (NSString *property in propertyArr) {
            [propertyNames addObject:[property componentsSeparatedByString:@" "][0]];
        }
        NSArray *propertys = propertyNames;
        
        NSArray *sameArr = [self sameItemsWithArray1:columnArr array2:propertys];
        if ([columnArr isEqualToArray:sameArr]) {
            [self setDbVersion:[cls dbVersion] toDbObjectClass:cls];
        } else {
            NSString *tempTableName = [NSString stringWithFormat:@"temp_%@", NSStringFromClass(cls)];
            NSString *sql = [NSString stringWithFormat:@"create table if not exists %@ as select * from %@;", tempTableName, NSStringFromClass(cls)];
            BOOL rc = [self executeQuery:sql];
            if (rc) {
                NSString *dropSql = [NSString stringWithFormat:@"drop table if exists %@;", NSStringFromClass(cls)];
                if ([self executeQuery:dropSql]) {
                    NSArray *sameItems = [self sameItemsWithArray1:columnArr array2:propertys];
                    NSString *colStr = [sameItems componentsJoinedByString:@", "];
                    NSString *select = [NSString stringWithFormat:@"select %@ from %@;", colStr, tempTableName];
                    NSString *createSql = [NSString stringWithFormat:@"create table if not exists %@ as %@;", NSStringFromClass(cls), select];
                    if ([self executeQuery:createSql]) {
                        NSString *dropTempSql = [NSString stringWithFormat:@"drop table if exists %@;", tempTableName];
                        [self executeQuery:dropTempSql];
    
                        NSArray *otherCols = [self itemsContainInArray1:propertys notContainInArray2:columnArr];
                        
                        NSMutableArray *otherProperty = [NSMutableArray array];
                        for (NSString *col in otherCols) {
                            for (NSString *property in propertyArr) {
                                NSString *name = [property componentsSeparatedByString:@" "][0];
                                if ([name isEqualToString:col]) {
                                    [otherProperty addObject:property];
                                }
                            }
                        }
                        
                        for (NSString *property in otherProperty) {
                            NSString *alterSql = [NSString stringWithFormat:@"alter table %@ add column %@;", NSStringFromClass(cls), property];
                            [self executeQuery:alterSql];
                        }
                        [self setDbVersion:[cls dbVersion] toDbObjectClass:cls];
                    }
                };
                NSArray *columnsInfo = [self tableColumnsCache:cls];
                [_dbTableColumnsCache setObject:columnsInfo forKey:NSStringFromClass(cls)];
            }
            return rc;
        }
    }
    
    return YES;
}

- (NSString *)versionFilePath {
    NSString *path = [self dbPath];
    NSInteger hash = [path hash];
    
    NSString *file = [NSHomeDirectory() stringByAppendingFormat:@"/Documents/%@.stdbversion", @(hash)];
    return file;
}

- (NSInteger)localVersionForClass:(Class)cls {
    NSString *file = [self versionFilePath];
    NSMutableDictionary *versionDict = [NSMutableDictionary dictionaryWithContentsOfFile:file];
    if([versionDict isKindOfClass:[NSDictionary class]]) {
        NSNumber *versionNum = versionDict[NSStringFromClass(cls)];
        return versionNum.integerValue;
    }
    return 0;
}

- (BOOL)shouldUpgradeDbObjectTable:(Class)cls {
    NSInteger dbVersion = [cls dbVersion];
    NSInteger localVersion = [self localVersionForClass:cls];
    if (dbVersion > localVersion) {
        return YES;
    }
    return NO;
}

- (BOOL)setDbVersion:(NSInteger)version toDbObjectClass:(Class)cls {
    NSString *file = [self versionFilePath];
    NSMutableDictionary *versionDict = [NSMutableDictionary dictionaryWithContentsOfFile:file];
    if (!versionDict) {
        versionDict = [NSMutableDictionary dictionary];
    }
    [versionDict setObject:@(version) forKey:NSStringFromClass(cls)];
    if (![versionDict writeToFile:file atomically:YES]) {
        NSLog(@"版本号写入失败！");
        return NO;
    };
    return YES;
}

#pragma mark - other method

- (id)ivarObject:(id)object forKey:(NSString *)key {
    id value;
    NSString *ivarName = [NSString stringWithFormat:@"_%@", key];
    Ivar ivar = class_getInstanceVariable([object class], ivarName.UTF8String);
    const char* typeEncoding = ivar_getTypeEncoding(ivar);
    
    /*
     @{@"f":@"float", @"i":@"int", @"d":@"double", @"l":@"long", @"c":@"BOOL", @"s":@"short", @"q":@"long",
     //and some famous aliases of primitive types
     // BOOL is now "B" on iOS __LP64 builds
     @"I":@"NSInteger", @"Q":@"NSUInteger", @"B":@"BOOL", @"*": @"char *",
     @"@?":@"Block"};
     */
    switch (typeEncoding[0]) {
        case '*': {
            char * charValue = ((char * (*)(id, Ivar))object_getIvar)(object, ivar);
            if (charValue) {
                value = @(charValue);
            }
        }
            break;
        case 'i':
        case 'c':
        case 'B':
        case 's': {
            Ivar ivar = class_getInstanceVariable ([object class], ivarName.UTF8String);
            ptrdiff_t offset = ivar_getOffset(ivar);
            unsigned char *stuffBytes = (unsigned char *)(__bridge void *)object;
            int intValue = * ((int *)(stuffBytes + offset));
            value = @(intValue);
        }
            break;
        case 'l':
        case 'I':
        case 'q':
        case 'Q': {
            Ivar ivar = class_getInstanceVariable ([object class], ivarName.UTF8String);
            ptrdiff_t offset = ivar_getOffset(ivar);
            unsigned char *stuffBytes = (unsigned char *)(__bridge void *)object;
            long longValue = * ((long *)(stuffBytes + offset));
            value = @(longValue);
        }
            break;
        case 'f': {
            Ivar ivar = class_getInstanceVariable ([object class], ivarName.UTF8String);
            ptrdiff_t offset = ivar_getOffset(ivar);
            unsigned char *stuffBytes = (unsigned char *)(__bridge void *)object;
            float floatValue = * ((float *)(stuffBytes + offset));
            value = @(floatValue);
        }
            break;
        case 'd': {
            Ivar ivar = class_getInstanceVariable ([object class], ivarName.UTF8String);
            ptrdiff_t offset = ivar_getOffset(ivar);
            unsigned char *stuffBytes = (unsigned char *)(__bridge void *)object;
            double doubleValue = * ((double *)(stuffBytes + offset));
            value = @(doubleValue);
        }
            break;
        case '@': {
            value = object_getIvar(object, ivar);
        }
            break;
        default:
            break;
    }
    return value;
}

- (id)convertToDbValue:(id)value pid:(NSString *)pid {
    
    if ([value isKindOfClass:[NSString class]]) {
        NSString *retStr = [NSString stringWithFormat:@"%@", [NSString stringWithFormat:@"%@", value]];
        if ([self encryptEnable]) {
            retStr = [retStr encryptWithKey:[self encryptKey]];
        }
        return retStr;
    }
    
    if ([value isKindOfClass:[NSNumber class]]) {
        return [NSString stringWithFormat:@"%@", value];
    }
    
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *results = [NSMutableDictionary dictionaryWithCapacity:0];
        
        for (NSString *key in value) {
            NSObject *obj = value[key];
            
            if ([obj isKindOfClass:[STDbObject class]]) {
                STDbObject *dbObject = (STDbObject *)obj;
                
                [self replaceDbObject:dbObject];
                
                NSInteger rowid = [dbObject.class lastRowId];
                
                [results setObject:[NSString stringWithFormat:@"%@%@,%@", DBChildPrefix, NSStringFromClass(obj.class),@(rowid)]  forKey:key];
            } else {
                [results setObject:obj forKey:key];
            }
        }
        
        NSString *retStr = [NSString stringWithFormat:@"%@", [NSDictionary stringWithObject:results]];
        if ([self encryptEnable]) {
            retStr = [retStr encryptWithKey:[self encryptKey]];
        }
        return retStr;
    }
    
    if ([value isKindOfClass:[NSArray class]]) {
        
        NSMutableArray *results = [NSMutableArray arrayWithCapacity:0];
        for (NSObject *obj in (NSArray *)value) {
            if ([obj isKindOfClass:[STDbObject class]]) {
                STDbObject *dbObject = (STDbObject *)obj;
                
                [dbObject setValue:pid forKey:kPId];
                [self replaceDbObject:dbObject];
                
                [results addObject:[NSString stringWithFormat:@"%@%@,%@", DBChildPrefix, NSStringFromClass(obj.class), dbObject.__id__]];
            } else {
                [results addObject:obj];
            }
        }
        NSString *retStr = [NSString stringWithFormat:@"%@", [NSArray stringWithObject:results]];
        if ([self encryptEnable]) {
            retStr = [retStr encryptWithKey:[self encryptKey]];
        }
        return retStr;
    }
    
    if ([value isKindOfClass:[NSDate class]]) {
        if ([value isKindOfClass:[NSDate class]]) {
            NSString *retStr = [NSString stringWithFormat:@"%@", [NSDate stringWithDate:value]];
            if ([self encryptEnable]) {
                retStr = [retStr encryptWithKey:[self encryptKey]];
            }
            return retStr;
        } else {
            return @"";
        }
        
    }
    
    if ([value isKindOfClass:[NSValue class]]) {
        return [NSData dataWithData:value];
    }
    
    if ([value isKindOfClass:[STDbObject class]]) {
        STDbObject *dbObject = (STDbObject *)value;
        [dbObject setValue:pid forKey:kDbPId];
        [self replaceDbObject:dbObject];
        NSString *result = [NSString stringWithFormat:@"%@%@,%@", DBChildPrefix, NSStringFromClass([value class]), dbObject.__id__];
        return result;
    }
    
    return value;
}

- (NSArray *)sameItemsWithArray1:(NSArray *)array1 array2:(NSArray *)array2 {
    NSMutableArray *sameItems = [NSMutableArray array];
    if ([array1 isKindOfClass:[NSArray class]] && [array2 isKindOfClass:[NSArray class]]) {
        for (id obj in array1) {
            if ([array2 containsObject:obj]) {
                [sameItems addObject:obj];
            }
        }
    }
    return sameItems;
}

- (NSArray *)itemsContainInArray1:(NSArray *)array1 notContainInArray2:(NSArray *)array2 {
    NSMutableArray *sameItems = [NSMutableArray array];
    if ([array1 isKindOfClass:[NSArray class]] && [array2 isKindOfClass:[NSArray class]]) {
        for (id obj in array1) {
            if (![array2 containsObject:obj]) {
                [sameItems addObject:obj];
            }
        }
    }
    return sameItems;
}

@end
