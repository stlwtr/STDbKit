//
//  AddUserViewController.h
//  STQuickKitDemo
//
//  Created by yls on 13-11-27.
//  Copyright (c) 2013年 yls. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AddUserViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UITextField *ageTextField;

- (IBAction)commit:(id)sender;

@end
