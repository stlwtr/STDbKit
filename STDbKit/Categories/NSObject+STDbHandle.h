//
//  NSObject+STDbHandle.h
//  STDbKit
//
//  Created by stlwtr on 15/3/4.
//  Copyright (c) 2015年stlwtr. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (STDbHandle)

+ (id)objectWithString:(NSString *)s;
+ (NSString *)stringWithObject:(NSObject *)obj;

+ (NSString *)random;

@end
