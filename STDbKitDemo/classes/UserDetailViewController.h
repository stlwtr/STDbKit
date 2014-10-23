//
//  UserDetailViewController.h
//  STQuickKitDemo
//
//  Created by yls on 13-11-27.
//  Copyright (c) 2013年 yls. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "User.h"

@interface UserDetailViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UITextField *ageTextField;

@property (nonatomic, strong) User *user;

- (IBAction)update:(id)sender;

@end
