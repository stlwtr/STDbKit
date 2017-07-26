//
//  EncryptTests.m
//  STDbKit
//
//  Created by stlwtr on 16/8/8.
//  Copyright © 2016年 stlwtr. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <STDbKit/STDbKit.h>
#import "User.h"

@interface EncryptTests : XCTestCase
{
    STDbQueue *_dbQueue;
}
@end

@implementation EncryptTests

- (void)setUp {
    [super setUp];
    
    _dbQueue = [STDbQueue dbQueueWithPath:@"stdb_test/test_encrypt_queue.sqlite"];
    
    XCTAssertNotNil([_dbQueue dbPath]);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInsert {
    [_dbQueue execute:^(STDb *db) {
        if (![User existDbObjectsWhere:@"__id__=8" db:db]) {
            User *user = [[User alloc] init];
            user.name = @"yls";
            user.ignore = @"不应该显示的";
            XCTAssertTrue([db insertDbObject:user]);
        }
    }];
}

- (void)testSelect {
    
    [_dbQueue execute:^(STDb *db) {
        
        [db beginTransaction];
        
        NSArray *users = [User allDbObjectsInDb:db];
        //        NSLog(@"%@", users);
        NSLog(@"all user count：%@", @(users.count));
        
        XCTAssertTrue([db executeQuery:@"select * from User;" resultBlock:^(NSArray *resultArray) {
                        NSLog(@"%@", resultArray);
            
            NSLog(@"select count：%@", @(resultArray.count));
        }]);
        
        [db commit];
        
    }];
}

@end
