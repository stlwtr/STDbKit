//
//  STDbObjectProperty.h
//  STDbKit
//
//  Created by stlwtr on 16/10/30.
//  Copyright © 2016年 stlwtr. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DBText  @"text"
#define DBInt   @"integer"
#define DBFloat @"real"
#define DBData  @"blob"

typedef NS_ENUM(NSInteger, STDbPropertyGetterType) {
    STDbPropertyGetterTypeNotInspected = 0,
    STDbPropertyGetterTypeCustom,
    STDbPropertyGetterTypeNo
};

@interface STDbObjectProperty : NSObject

/** The name of the declared property (not the ivar name) */
@property (copy, nonatomic) NSString *name;

/** A property class type  */
@property (assign, nonatomic) Class type;

/** A property class type  */
@property (copy, nonatomic, readonly) NSString *dbType;

/** Struct name if a struct */
@property (strong, nonatomic) NSString *structName;

/** The name of the protocol the property conforms to (or nil) */
@property (copy, nonatomic) NSString *protocol;

/** If YES, it will be ignore */
@property (assign, nonatomic) BOOL isIgnore;

/** If YES, it will be the primary key */
@property (assign, nonatomic) BOOL isPrimaryKey;

/** If YES - create a mutable object for the value of the property */
@property (assign, nonatomic) BOOL isMutable;

/** The status of property getter introspection in a model */
@property (assign, nonatomic) STDbPropertyGetterType getterType;

/** a custom getter for this property, found in the owning model */
@property (assign, nonatomic) SEL customGetter;

/** custom setters for this property, found in the owning model */
@property (strong, nonatomic) NSMutableDictionary *customSetters;

@end
