//
//  UserListViewController.h
//  STQuickKitDemo
//
//  Created by yls on 13-11-27.
//  Copyright (c) 2013年 yls. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UserListViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>

/**
 *	@brief	用户列表视图
 */
@property (weak, nonatomic) IBOutlet UITableView *tableView;


@end
