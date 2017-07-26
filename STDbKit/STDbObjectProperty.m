//
//  STDbObjectProperty.m
//  STDbKit
//
//  Created by stlwtr on 16/10/30.
//  Copyright © 2016年 stlwtr. All rights reserved.
//

#import "STDbObjectProperty.h"
#import "STDbObject.h"

@implementation STDbObjectProperty

- (NSString *)dbType {
    if ([self.type isSubclassOfClass:[STDbObject class]]) {
        return DBText;
    }
    
    NSString *typeStr = self.structName ? self.structName : NSStringFromClass(self.type);
    NSDictionary *dbTypeNames = @{
                                  @"float"          :   DBFloat,
                                  @"int"            :   DBInt,
                                  @"double"         :   DBFloat,
                                  @"long"           :   DBInt,
                                  @"BOOL"           :   DBInt,
                                  @"short"          :   DBInt,
                                  @"long"           :   DBInt,
                                  @"NSInteger"      :   DBInt,
                                  @"NSUInteger"     :   DBInt,
                                  @"Q"              :   DBInt,
                                  @"B"              :   DBInt,
                                  @"char *"         :   DBText,
                                  @"NSString"       :   DBText,
                                  @"NSNumber"       :   DBText,
                                  @"NSDictionary"   :   DBText,
                                  @"NSArray"        :   DBText,
                                  @"NSDate"         :   DBText,
                                  @"NSData"         :   DBData,
                                  @"STDbObject"     :   DBText,
                                  };

    return dbTypeNames[typeStr];
}

@end
