//
//  User.h
//  STQuickKitDemo
//
//  Created by yls on 13-11-26.
//  Copyright (c) 2013年 yls. All rights reserved.
//

//#import <STDbKit/STDbObject.h>
#import <STDbKit/STDbObject.h>
#import "Book.h"

enum AuthorityFlag {
    kAuthorityFlagAdmin = 1 << 0,
    kAuthorityFlagUser  = 1 << 1,
    };

enum SexType {
    kSexTypeMale = 0,
    kSexTypeFemale = 1,
    };

@interface User : STDbObject

@property (assign, nonatomic) int _id;        /** 唯一标识id */
@property (strong, nonatomic) NSString *name; /** 姓名 */
@property (assign, nonatomic) NSInteger age;  /** 年龄 */
@property (strong, nonatomic) NSNumber *sex;  /** 性别 */

@property (strong, nonatomic) NSString *phone;  /** 电话号码 */
@property (strong, nonatomic) NSString *email;  /** 邮箱 */

@property (strong, nonatomic) NSData *image;        /** 头像 */
@property (strong, nonatomic) NSDate *birthday;     /** 出生日期 */
@property (strong, nonatomic) NSDictionary *info;   /** 其他信息 */
@property (strong, nonatomic) NSArray *favs;        /** 爱好 */

@property (strong, nonatomic) Book *book;
@property (strong, nonatomic) NSArray *books;

@end
