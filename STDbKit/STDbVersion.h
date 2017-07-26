//
//  STDbVersion.h
//  STDbObject
//
//  Created by stlwtr on 13-12-2.
//
// Version 2.3.0
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// emailto: 2008.yls@163.com
// QQ: 603291699
// https://github.com/stlwtr/STDbKit
//

#ifndef STDbObject_STDbVersion_h
#define STDbObject_STDbVersion_h

/*************** 版本更新 ******************
 *  @brief v2.2.3 2017-07-26更新
 1. 优化了主键逻辑
 2. 增加了打包SDK脚本
 --------------------------
 
 *  @brief v2.2.2 2017-04-08更新
 1. 添加忽略、主键标识
 --------------------------
 *  @brief v2.2.1 2013-12-20更新
 1. 添加dbObject过期属性，当数据过期，数据会被自动删除，可用于有时间限制的历史纪录等场景
 --------------------------
 *  @brief v1.0 STDbObject类实现方法
    1. 数据库查询: + (NSMutableArray *)allDbObjects;
                 + (NSArray *)dbObjectsWhere:(NSString *)where orderby:(NSString *)orderby;
    2. 数据库插入: insertToDb;
    3. 数据库修改: - (BOOL)updateToDbsWhere:(NSString *)where;
    4. 数据库删除: + (BOOL)removeDbObjectsWhere:(NSString *)where;
 --------------------------
 *  @brief v1.0.1 2013-12-01更新
    1. 不再使用方法 - (BOOL)updateToDbsWhere:(NSString *)where,使用方法
       - (BOOL)updatetoDb 代替;
    2. 添加方法: - (BOOL)removeDbObject;
 --------------------------
 *  @brief v1.0.2 2013-12-11更新
    1. 支持复杂类型（NSData， NSDate， NSArray, NSDictionary）
    2. 修正一些bug
 --------------------------
 *  @brief v1.0.5 2013-12-31更新
    1. 添加dbObject加密功能
 *****************************************/


#define STDbKitVersionNumber1_0     100.00
#define STDbKitVersionNumber1_0_4   100.40
#define STDbKitVersionNumber2_3_0   230.161117

static double STDbKitVersionNumber = STDbKitVersionNumber2_3_0;
static const unsigned char STDbKitVersionString[] = "2.3.0";

#endif
