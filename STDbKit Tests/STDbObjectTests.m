//
//  STDbObjectTests.m
//  STDbKit
//
//  Created by stlwtr on 15/6/14.
//  Copyright (c) 2015年 yls. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "STDbKit.h"
#import "User.h"
#import "STDb.h"
#import "STDbQueue.h"

@interface STDbObjectTests : XCTestCase
{
    STDbQueue *_dbQueue;
}
@end

@implementation STDbObjectTests

+ (void)setUp
{
    [User setVersion:1.1];
    NSLog(@"version %@", @([User version]));
    NSLog(@"version %@", @([STDbObject version]));
}

- (void)setUp {
    [super setUp];

    _dbQueue = [STDbQueue dbWithPath:@"stdb_test/test_queue.sqlite"];
    XCTAssertNotNil([_dbQueue dbPath]);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInsert {
    [_dbQueue execute:^(STDb *db) {
         if (![User existDbObjectsWhere:@"__id__=8" db:db]) {
             User *user = [[User alloc] initWithPrimaryValue:8];
             user.name = @"yls";
             XCTAssertTrue([db insertDbObject:user]);
         }
    }];
}

- (void)testRemove {
    [_dbQueue execute:^(STDb *db) {
        if ([User existDbObjectsWhere:@"__id__=8" db:db]) {
            XCTAssertTrue([User removeDbObjectsWhere:@"__id__=8" db:db]);
        } else {
            [db executeQuery:@"delete from User where __id__=8"];
        }
    }];
}

- (void)testSelect {
    [_dbQueue execute:^(STDb *db) {
        XCTAssertTrue([db executeQuery:@"select * from User" resultBlock:^(NSArray *resultArray) {
            NSLog(@"%@", resultArray);
        }]);
    }];
}

- (void)testQuery {
    [_dbQueue execute:^(STDb *db) {
        XCTAssertTrue([db executeUpdate:@"insert into User(?) values(?)" dictionaryArgs:@{@"name" : @"aaa"}]);
    }];
}

- (void)testUpdateAfterInsert {
    [_dbQueue execute:^(STDb *db) {
        User *user = [[User alloc] init];
        user.name = @"ab";
        XCTAssertTrue(user.__id__ == -1);
        XCTAssertTrue([user insertToDb:db]);
        NSInteger row = [User lastRowIdInDb:db];
        XCTAssertTrue(row == user.__id__);
        user.name = @"cc";
        XCTAssertTrue([user updateToDb:db]);
        NSString *where = [NSString stringWithFormat:@"%@==%@", kDbId, @(user.__id__)];
        NSArray *users = [User dbObjectsWhere:where orderby:nil db:db];
        if (users.count > 0) {
            User *user2 = users[0];
            XCTAssertTrue([user2.name isEqualToString:@"cc"]);
        }
    }];
}

- (void)testFor {
    [_dbQueue execute:^(STDb *db) {
        for (int i = 0; i < 100; i++) {
            User *user = [[User alloc] init];
            user.name = @"ab";
            XCTAssertTrue([user insertToDb:db]);
        }
    }];
}

@end
