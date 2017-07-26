//
//  STDbObjectTests.m
//  STDbKit
//
//  Created by stlwtr on 15/6/14.
//  Copyright (c) 2015年stlwtr. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "STDbKit.h"
#import "User.h"
#import "STDb.h"
#import "STDbQueue.h"
#import "STDbObjectProperty.h"
#import "NSObject+Dictionary.h"

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
    
    NSLog(@"%@", NSHomeDirectory());
    
}

- (void)setUp {
    [super setUp];

    _dbQueue = [STDbQueue dbQueueWithPath:@"stdb_test/test_queue.sqlite"];
    XCTAssertNotNil([_dbQueue dbPath]);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInsert {
    [_dbQueue execute:^(STDb *db) {
         if (![User existDbObjectsWhere:@"userId=153" db:db]) {
             
             User *u = [[User alloc] init];
             u.userId = @1;
             
             User *user = [[User alloc] init];
             user.user = u;
             user.userId = @153;
             user.address = "bei jing, China";
             user.classId = 45;
             user.name = @"yls";
             user.weight = 65.3;
             user.ignore = @"this is ignored";
             user.userInfo = @{@"aa": @"bb"};
             user.resultBlock = ^{};
             user.age = 21;
             user.shortValue = 41;
             user.longlongValue = 240240;
             XCTAssertTrue([db insertDbObject:user]);
             
             NSArray *users = [User dbObjectsWhere:@"userId=153" orderby:nil db:db];
             if (users.count > 0){
                 User *resultObject = users[0];
                 XCTAssertNotNil(resultObject.user);
             }
         }
    }];
}

- (void)testPropertyType {
    NSArray *properties = [User properties];
    for (STDbObjectProperty *p in properties) {
        NSLog(@"name = %@, type = %@, dbType = %@", p.name, p.structName ? p.structName : NSStringFromClass(p.type), p.dbType);
        XCTAssertNotNil(p.dbType);
    }
}

- (void)testRemove {
    [_dbQueue execute:^(STDb *db) {
        if ([User existDbObjectsWhere:@"userId=153" db:db]) {
            XCTAssertTrue([User removeDbObjectsWhere:@"userId=153" db:db]);
        } else {
            [db executeQuery:@"delete from User"];
        }
    }];
}

- (void)testRemoveAll {
    [_dbQueue execute:^(STDb *db) {
        [db executeQuery:@"delete from User"];
    }];
}

- (void)testSelect {
    
    [_dbQueue execute:^(STDb *db) {
        
        [db executeQuery:@"select * from User where __id__ = \"1F25E0CB604D4C03\" and __pid__ is not null;" resultBlock:^(NSArray *resultArray) {
            NSLog(@"%@", resultArray);
        }];
        
        
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

- (void)testMeasureSelect {
    [self measureBlock:^{
        [self testSelect];
    }];
}

- (void)testQuery {
    [_dbQueue execute:^(STDb *db) {
        NSDictionary *args = @{ @"name" : @"aaa", @"userId" : @123 };
        XCTAssertTrue([db executeUpdate:@"insert into User(name,age,__pid__,shortValue,weight,userId,address,expireDate,longlongValue,classId,userInfo,__id__) values(:name,:age,:__pid__,:shortValue,:weight,:userId,:address,:expireDate,:longlongValue,:classId,:userInfo,:__id__)" dictionaryArgs:args]);
    }];
}

- (void)testUpdateAfterInsert {
    [_dbQueue execute:^(STDb *db) {
        User *user = [[User alloc] init];
        user.name = @"ab";
        user.userId = @15;
        XCTAssertTrue([user replaceToDb:db]);

        user.name = @"cc";
        XCTAssertTrue([user updateToDb:db]);
        NSString *where = [NSString stringWithFormat:@"%@=%@", @"userId", @15];
        NSArray *users = [User dbObjectsWhere:where orderby:nil db:db];
        if (users.count > 0) {
            User *user2 = users[0];
            XCTAssertTrue([user2.name isEqualToString:@"cc"]);
        }
    }];
}

- (void)testFor {
    
    [_dbQueue execute:^(STDb *db) {
        [db executeQuery:@"delete from User"];
        
        for (int i = 0; i < 1000; i++) {
            User *user = [[User alloc] init];
            user.name = @"ab";
            user.userId = @(i);
            user.userInfo = @{ @"age" : @29, @"class" : @"高三"};
            XCTAssertTrue([user insertToDb:db]);
        }
    }];
}

- (void)testTransaction {
    
    [_dbQueue execute:^(STDb *db) {
        
        [db beginTransaction];
        
        [db executeQuery:@"delete from User"];
        
        for (int i = 0; i < 1000; i++) {
            User *user = [[User alloc] init];
            user.name = @"ab";
            user.userId = @(i);
            user.userInfo = @{ @"age" : @29, @"class" : @"高三"};
            XCTAssertTrue([user insertToDb:db]);
        }
        
        [db commit];
        
    }];
    
}

- (void)testForInsert {
    
    [self measureBlock:^{
        
       [self testFor];
    }];
}

- (void)testForMeasure {
        [self testRemoveAll];
    
        [_dbQueue execute:^(STDb *db) {
            
//            [db beginTransaction];
            
            for (int i = 0; i < 1000; i++) {
                User *user = [[User alloc] init];
                user.name = @"ab";
                user.userInfo = @{ @"age" : @29, @"class" : @"高三"};
                XCTAssertTrue([user insertToDb:db]);
            }
            
//            [db commit];
            
        }];
}

- (void)testUpgradeDb {
    [_dbQueue execute:^(STDb *db) {
        BOOL rc = [db setDbVersion:1 toDbObjectClass:[User class]];
        XCTAssertTrue(rc);
        NSInteger localVersion = [db localVersionForClass:[User class]];
        XCTAssertEqual(localVersion, 1);
    }];
}

- (void)testProperty {
    
    [_dbQueue execute:^(STDb *db) {
        [db upgradeTableIfNeed:[User class]];
    }];
}

- (void)testRandom {
    NSTimeInterval ti = [NSDate timeIntervalSinceReferenceDate];
    NSString *ramdomStr = [NSString stringWithFormat:@"%0X%0X", (uint32_t)floor(ti), arc4random()];
    
    NSLog(@"%@", ramdomStr);
}

- (void)testNSObject2Dictionary {
    User *user = [[User alloc] init];
    user.name = @"abc";
    user.address = "address is bei jing";
    user.longlongValue = 5157107510;
    user.ignore = @"ignore";
    NSDictionary *dictionary = [user objcDictionary];
    NSLog(@"%@", dictionary);
    
    User *user2 = [User objcFromDictionary:dictionary];
    
    NSLog(@"%@", user2);
}

@end
