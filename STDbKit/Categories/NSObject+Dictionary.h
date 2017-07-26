//
//  NSObject+Dictionary.h
//  STDbKit
//
//  Created by stlwtr on 2017/7/25.
//  Copyright © 2017年 stlwtr. All rights reserved.
//

#import <Foundation/Foundation.h>

static const char * kSTClassPropertiesKey;

@protocol STIgnore <NSObject>
@end

@interface NSObject (Dictionary)

/**
 *	@brief	objc to dictionary
 */
- (NSDictionary *)objcDictionary;

/**
 *	@brief	objc from dictionary
 */
+ (id)objcFromDictionary:(NSDictionary *)dictionary;

@end
