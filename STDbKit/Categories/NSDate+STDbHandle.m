//
//  NSDate+STDbHandle.m
//  STDbKit
//
//  Created by stlwtr on 15/3/4.
//  Copyright (c) 2015年stlwtr. All rights reserved.
//

#import "NSDate+STDbHandle.h"

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