//
//  NSDate+STDbHandle.h
//  STDbKit
//
//  Created by stlwtr on 15/3/4.
//  Copyright (c) 2015年stlwtr. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (STDbHandle)

+ (NSDate *)dateWithString:(NSString *)s;
+ (NSString *)stringWithDate:(NSDate *)date;

@end