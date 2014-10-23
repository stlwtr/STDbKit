#STDbObject

**1. 概述**
-------------
    对于小型数据很方便, 声明一个继承于STDbObject的类对象user，
	写入到数据库直接执行方法[user insertToDb];
	从数据库读取，NSArray *users = [User dbObjectsWhere:@"_id=11" orderby:nil];
	更新到数据库，[user updateToDb];
	从数据库删除，[user removeFromDb];
	
	*更新内容
	1.0.2版本支持复杂类型 NSData, NSDate, NSArray, NSDictionary

**2. 使用方法**
-------------
    1) 引入STDbKit.framework
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
    2) 引入依赖库sqlite3.dylib
    3) 创建需要保存的数据类，该类需继承类STDbObject

**3. 示例**
-------------
   1) 声明一个类，这里新建类User

     #import <STDbKit/STDbObject.h>

	 @interface User : STDbObject

	 @property (strong, nonatomic) NSString *name;
	 @property (assign, nonatomic) NSInteger age;
	 @property (strong, nonatomic) NSNumber *sex;
	 @property (assign, nonatomic) NSTimeInterval time;
	 @property (assign, nonatomic) int _id;

	 @end
    
   2) 插入到数据库

     // 初始化
     User *user = [[User alloc] init];
     user.name = @"admin";
     user.age = 20;
     user.sex = @1;
     user._id = 0;
     // 插入到数据库
     [user insertToDb];

   3) 查询

      // 取出所有用户
      NSArray *users = [User allDbObjects];

	  // 按条件取出数据
      NSArray *users = [User dbObjectsWhere:@"_id=11" orderby:nil];

   4) 修改

       // 首先从数据库中取出要修改的对象
       NSArray *users = [User dbObjectsWhere:@"_id=11" orderby:nil];
       if ([users count] > 0) {
		   User *user = users[0];
           user.name = @"学长";
           // 更新到数据库
           [user updateToDb];
       }
   5) 删除

      // 要删除的数据
      User *user = _users[row];
      NSString *where = [NSString stringWithFormat:@"uid__=%d", user.uid__];
      // 从数据库中删除数据
      [user removeFromDb];
      
       // 批量删除
       [User removeDbObjectsWhere:@"_id=%d", 4];

<p>
	<font color="red" size="3">
	注意：一旦修改了数据类，请删除原来的应用重新运行.
	</font>
</p>
