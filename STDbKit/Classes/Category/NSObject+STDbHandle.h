//
//  NSObject+STDbHandle.h
//  STDbKit
//
//  Created by yls on 15/3/4.
//  Copyright (c) 2015年 yls. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (STDbHandle)

+ (id)objectWithString:(NSString *)s;
+ (NSString *)stringWithObject:(NSObject *)obj;

@end
