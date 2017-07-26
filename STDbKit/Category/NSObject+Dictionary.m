//
//  NSObject+Dictionary.m
//  STDbKit
//
//  Created by stlwtr on 2017/7/25.
//  Copyright © 2017年 stlwtr. All rights reserved.
//

#import "NSObject+Dictionary.h"
#import <objc/runtime.h>
#import "STDbObject.h"

@implementation NSObject (Dictionary)

/**
 *	@brief	objc to dictionary
 */
- (NSDictionary *)objcDictionary {
    @synchronized(self){
        unsigned int count;
        id obj = self;
        
        Class cls = [obj class];
        objc_property_t *properties = my_class_copyPropertyList(cls, &count);
        
        NSMutableDictionary *retDict = [NSMutableDictionary dictionary];
        
        for (int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            NSString * key = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
            id value = [self ivarObject:obj forKey:key];
            if (value && ![value isKindOfClass:[NSNull class]]) {
                [retDict setObject:value forKey:key];
            }
        }
        
        return retDict;
    }
}

/**
 *	@brief	objc from dictionary
 */
+ (id)objcFromDictionary:(NSDictionary *)dictionary {
    id obj = [[[self class] alloc] init];
    
    for (NSString *key in dictionary) {
        NSString *ivarName = [NSString stringWithFormat:@"_%@", key];
        Ivar ivar = class_getInstanceVariable([obj class], ivarName.UTF8String);
        const char *type = ivar_getTypeEncoding(ivar);
        if (ivar) {
            id value = dictionary[key];
            value = [self safeNumFromValue:value objCType:type];
            // When object_setIvar(obj, ivar, ${long long value}), the value became wrong
            // Char * value cannot use the -setValue:forKey:
            if (type[0] == '*') {
                object_setIvar(obj, ivar, value);
            } else {
                [obj setValue:value forKey:key];
            }
        }
    }
    return obj;
}

+ (id)safeNumFromValue:(id)value objCType:(const char *)objCType {
    if ([value isKindOfClass:[NSNumber class]]) {
        return value;
    } else if ([value isKindOfClass:[NSString class]]) {
        NSString *str = value;
        switch (objCType[0]) {
            case '*': {
                return value;
            }
                break;
            case 'i':
            case 'c':
            case 'B':
            case 's': {
                value = @(str.intValue);
            }
                break;
            case 'l':
            case 'I':
            case 'q':
            case 'Q': {
                value = @(str.longLongValue);
            }
                break;
            case 'f': {
                value = @(str.floatValue);
            }
                break;
            case 'd': {
                value = @(str.doubleValue);
            }
                break;
            case '@': {
                if ([value isKindOfClass:[NSString class]]) {
                    NSString *str = value;
                    if ([str hasPrefix:@"STDBChildID_"]) {
                        NSString *rowidStr = [str stringByReplacingOccurrencesOfString:@"STDBChildID_" withString:@""];
                        NSArray *arr = [rowidStr componentsSeparatedByString:@","];
                        NSString *clsName = arr[0];
                        NSString *__id__ = arr[1];
                        
                        NSString *where = [NSString stringWithFormat:@"%@=%@", @"__id__", __id__];
                        
                        id child = [NSClassFromString(clsName) dbObjectsWhere:where orderby:nil][0];
                        
                        return child;
                    }
                }
            }
            default:
                return value;
                break;
        }
    }
    
    return value;
}

/*
 * @{@"f":@"float", @"i":@"int", @"d":@"double", @"l":@"long", @"c":@"BOOL", @"s":@"short", @"q":@"long",
 * //and some famous aliases of primitive types
 * // BOOL is now "B" on iOS __LP64 builds
 * @"I":@"NSInteger", @"Q":@"NSUInteger", @"B":@"BOOL", @"*": @"char *",
 * @"@?":@"Block"};
 */
- (id)ivarObject:(id)object forKey:(NSString *)key {
    id value;
    NSString *ivarName = [NSString stringWithFormat:@"_%@", key];
    Ivar ivar = class_getInstanceVariable([object class], ivarName.UTF8String);
    const char* typeEncoding = ivar_getTypeEncoding(ivar);
    
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

objc_property_t * my_class_copyPropertyList(Class cls, unsigned int *count)
{
    if ([NSStringFromClass(cls) isEqualToString:NSStringFromClass(NSObject.class)]) {
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

@end
