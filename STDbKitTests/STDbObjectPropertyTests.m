//
//  STDbObjectPropertyTests.m
//  STDbKit
//
//  Created by stlwtr on 2017/4/8.
//  Copyright © 2017年 stlwtr. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "User.h"

@interface STDbObjectPropertyTests : XCTestCase

@end

@implementation STDbObjectPropertyTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)teSTDbObjectProperty {
    User *u = [[User alloc] init];
    u.userId = @(12);
    u.userInfo = @{@"name":@"xue zhang"};
    u.name = @"xue zhang";
    u.ignore = @"aaa";
    
    [u updateToDb];
}

@end
