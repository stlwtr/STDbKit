//
//  User.h
//  STDbKit
//
//  Created by stlwtr on 15/6/14.
//  Copyright (c) 2015年 yls. All rights reserved.
//

#import "STDbObject.h"

@interface User : STDbObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSDictionary *userInfo;

@end
