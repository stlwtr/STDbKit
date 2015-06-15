//
//  NSString+STDbHandle.h
//  STDbKit
//
//  Created by yls on 15/3/4.
//  Copyright (c) 2015年 yls. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (STDbHandle)

- (NSData *)base64Data;
- (NSString *)encryptWithKey:(NSString *)key;
- (NSString *)decryptWithKey:(NSString *)key;

@end