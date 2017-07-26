//
//  User.m
//  STDbKit
//
//  Created by stlwtr on 15/6/14.
//  Copyright (c) 2015年stlwtr. All rights reserved.
//

#import "User.h"

@implementation User

+ (NSInteger)dbVersion
{
    return 7;
}

+ (BOOL)propertyIsPrimary:(NSString *)propertyName {
//    if ([propertyName isEqualToString:@"classId"]) {
//        return YES;
//    }
    return NO;
}

@end
