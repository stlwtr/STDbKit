STDbKit
==============

This library provides an easy way to access sqlite database.

Requirements
----------------
This project require :
+ ```iOS5```
+ ```ARC```

Podfile
----------------
To integrate STDbKit into your Xcode project using CocoaPods, specify it in your Podfile:

```
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

target 'TargetName' do
pod 'STDbKit', '~> 2.3.0'
end
```

Then, run the following command:

```
$ pod install
```

Usage
----------------
#####  1. declare a class,such as User
```
#import "STDbObject.h"
#import "STDbQueue.h"
#import "STDb.h"

 @interface User : STDbObject

 @property (strong, nonatomic) NSString *name;
 @property (assign, nonatomic) NSInteger age;
 @property (strong, nonatomic) NSNumber *sex;
 @property (assign, nonatomic) NSTimeInterval time;
 @property (assign, nonatomic) int _id;

 @end
```
#####  2. insert into db
```
1：
STDbQueue *dbQueue = [STDbQueue dbWithPath:@"stdb_test/test_queue.sqlite"];
[dbQueue execute:^(STDb *db) {
  User *user = [[User alloc] initWithPrimaryValue:8];
  user.name = @"yls";
  [db insertDbObject:user];
}];
2：
STDbQueue *dbQueue = [STDbQueue dbWithPath:@"stdb_test/test_queue.sqlite"];
[dbQueue execute:^(STDb *db) {
  User *user = [[User alloc] initWithPrimaryValue:8];
  user.name = @"yls";
  [user insertToDb:db];
}];
3：
STDbQueue *dbQueue = [STDbQueue dbWithPath:@"stdb_test/test_queue.sqlite"];
[dbQueue execute:^(STDb *db) {
  [db executeUpdate:@"insert into User(?) values(?)" dictionaryArgs:@{@"name" : @"aaa"}];
}];

```
#####  3. query
```
// query
1：
NSArray *users = [User allDbObjects];
2：
[dbQueue execute:^(STDb *db) {
  [db executeQuery:@"select * from User" resultBlock:^(NSArray *resultArray) {
            NSLog(@"%@", resultArray);
  }];
}];
    
// query objects on condition
NSArray *users = [User dbObjectsWhere:@"_id=11" orderby:nil];

```
#####  4. update
```
// first, query the object 
1：
NSArray *users = [User dbObjectsWhere:@"_id=11" orderby:nil];
if ([users count] > 0) {
   User *user = users[0];
   user.name = @"stlwtr";
   // 更新到数据库
   [user updateToDb];
}
2：
[dbQueue execute:^(STDb *db) {
  [user updateToDb:db];
}];
```
#####  5. delete
```
// get the objects to remove
1：
User *user = _users[row];
// delete the object
[user removeFromDb];
2：
[dbQueue execute:^(STDb *db) {
  [db executeQuery:@"delete from User where __id__=8"];
  }];
}];
// delete the objects on condition
[User removeDbObjectsWhere:@"_id=%d", 4];
```

Roadmap
----------------

#### Current Version : ***2.3.0***  

- ***2.3.0:***  
  + Support STIgnore、STDbPrimaryKey

- ***2.2.5:***  
	+ Support .sqlite file encrypt
	+ Finish Readme.md documentation

- ***V2.2.4:***
	+ Support transaction management 

- ***V2.2.1:***
	+ Support thread Management

- ***V2.0.2:***
  	+ Add method for convert class object into dictionary 
  	+ Add method for convert dictionary into class object

- ***V2.0:***
	+ Support array contains class objects of STDbObject
  	+ Support dictionary contains an STDbObject object
  	+ Remove the associate STDbObject class object after remove the parent object
	
- ***V1.0.5:***
  	+ Support STDbObject class object contains another STDbObject class object

- ***V1.0.4:***
  - add dbObject expireDate property，when then data expire，it will be auto remove from db
 
 - ***V1.0.3:***
  - Support Collections class,such as NSData,NSDate,NSArray,NSDictionary

```
FAQ
----------------
No question asked so far.


Licence
----------------
MIT Licence  
Copyright (c) 2014 Thibault Carpentier <carpen_t@epitech.eu>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

#STDbKit

## 1. 概述
```
对于小型数据很方便, 声明一个继承于STDbObject的类对象user
_dbQueue = [STDbQueue dbWithPath:@"stdb_test/test_encrypt_queue.sqlite"];

写入到数据库直接执行方法  [user insertToDb]; 
从数据库读取，NSArray *users = [User dbObjectsWhere:@"_id=11" orderby:nil];
更新到数据库，[user updateToDb];
从数据库删除，[user removeFromDb]; 
```

## 2. 更新历史
2.2.5 更新内容（2016-08-08） 

  - 支持数据库加密
  
```
// 数据库db文件加密
[_dbQueue execute:^(STDb *db) { 
	db.encryptDB = YES; 
}]; 
```
 
2.2.4 更新内容（2016-01-27） 

  - 支持事务处理
  - 优化性能 

2.2.1 更新内容（2015-06-15）

  - 添加多线程支持  
  - 多db文件支持  
  - 增加了数据库更新功能， + (NSInteger)dbVersion;  
                                   
2.0.2 更新内容（2014-02-18）
  - add objc to dictionary method 
  - add dictionary to objc method

2.0 更新内容（2014-01-06）

  - support array contain objects of STDbObject class
  - support dictionary contain an STDbObject object
  - remove the sub STDbObject after remove the parent object

1.0.5 更新内容（2014-01-04）

  - 支持一个STDbObject对象包含另一个STDbObject对象了

1.0.4 更新内容（2014-01-02）

  - 添加dbObject过期属性，当数据过期，数据会被自动删除，可用于有时间限制的历史纪录等场景添加了数据库加密功能（目前仅支持字符串加密）
  
1.0.3 更新内容（2013-06-01）

  - 支持复杂类型NSData,NSDate,NSArray,NSDictionary

## 3. 使用方法

```
方法一：导入源码
方法二：项目支持cocoapods，在Podfile中添加pod STDbKit
方法三：制作STDbKit.framework并引入，可从附件中下载

支持模拟器和真机STDbKit.framework制作方法:
   1. 分别在device和模拟器下运行
   2. 右击 STDbKit.framework, 选择Show In Finder, 找到上级目录,本项目是release版本,
      这里显示Release-iphoneos,Release-iphonesimulator
   3. 把Release-iphoneos,Release-iphonesimulator文件夹拷贝到桌面
   4. 在终端运行lipo -create ~/Desktop/Release-iphoneos/STDbKit.framework/STDbKit \
      ~/Desktop/Release-iphonesimulator/STDbKit.framework/STDbKit \
      -output ~/Desktop/STDbKit
   5. 在桌面文件夹Release-iphoneos上, 拷贝 STDbKit.framework到桌面，把桌面上 STDbKit 
      文件覆盖到STDbKit.framework, 制作完成
   6. 在项目中引用STDbKit.framework框架，支持模拟器和真机了
 * 引入依赖库sqlite3.dylib
 * 创建需要保存的数据类，该类需继承类STDbObject
```

## 4. 示例

#####  1. 声明一个类，这里新建类User
```
#import "STDbObject.h"
#import "STDbQueue.h"
#import "STDb.h"

 @interface User : STDbObject

 @property (strong, nonatomic) NSString *name;
 @property (assign, nonatomic) NSInteger age;
 @property (strong, nonatomic) NSNumber *sex;
 @property (assign, nonatomic) NSTimeInterval time;
 @property (assign, nonatomic) int _id;

 @end
```
#####  2. 插入到数据库
```
方式一：
STDbQueue *dbQueue = [STDbQueue dbWithPath:@"stdb_test/test_queue.sqlite"];
[dbQueue execute:^(STDb *db) {
	User *user = [[User alloc] initWithPrimaryValue:8];
	user.name = @"yls";
	[db insertDbObject:user];
}];
方式二：
STDbQueue *dbQueue = [STDbQueue dbWithPath:@"stdb_test/test_queue.sqlite"];
[dbQueue execute:^(STDb *db) {
	User *user = [[User alloc] initWithPrimaryValue:8];
	user.name = @"yls";
	[user insertToDb:db];
}];
方式三：
STDbQueue *dbQueue = [STDbQueue dbWithPath:@"stdb_test/test_queue.sqlite"];
[dbQueue execute:^(STDb *db) {
	[db executeUpdate:@"insert into User(?) values(?)" dictionaryArgs:@{@"name" : @"aaa"}];
}];

```
#####  3. 查询
```
// 取出所有用户
方式一：
NSArray *users = [User allDbObjects];
方式二：
[dbQueue execute:^(STDb *db) {
	[db executeQuery:@"select * from User" resultBlock:^(NSArray *resultArray) {
            NSLog(@"%@", resultArray);
	}];
}];
    
// 按条件取出数据
NSArray *users = [User dbObjectsWhere:@"_id=11" orderby:nil];

```
#####  4. 修改
```
// 首先从数据库中取出要修改的对象
方式一：
NSArray *users = [User dbObjectsWhere:@"_id=11" orderby:nil];
if ([users count] > 0) {
   User *user = users[0];
   user.name = @"学长";
   // 更新到数据库
   [user updateToDb];
}
方式二：
[dbQueue execute:^(STDb *db) {
	[user updateToDb:db];
}];
```
#####  5. 删除
```
// 要删除的数据
方式一：
User *user = _users[row];
// 从数据库中删除数据
[user removeFromDb];
方式二：
[dbQueue execute:^(STDb *db) {
	[db executeQuery:@"delete from User where __id__=8"];
	}];
}];
// 批量删除
[User removeDbObjectsWhere:@"_id=%d", 4];

```
FAQ
----------------
No question asked so far.

Requirements
----------------
This project require :
+ ```iOS5```
+ ```ARC```

Licence
----------------
MIT Licence  
Copyright (c) 2014 Thibault Carpentier <carpen_t@epitech.eu>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
