//
//  User.h
//  STDbKit
//
//  Created by stlwtr on 15/6/14.
//  Copyright (c) 2015年stlwtr. All rights reserved.
//

#import <STDbKit/STDbObject.h>

@interface User : STDbObject

@property (nonatomic, strong) void (^resultBlock)(void);
@property (nonatomic, assign) char * address;
@property (nonatomic, strong) NSNumber<STDbPrimaryKey> *userId;
@property (nonatomic) int classId;
@property (nonatomic) short shortValue;
@property (nonatomic) long long longlongValue;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString<STIgnore> *ignore;
@property (nonatomic, strong) NSDictionary *userInfo;
@property (nonatomic, assign) NSUInteger age;
@property (nonatomic, assign) float weight;
@property (nonatomic, strong) User *user;

@end
