//
//  UserListViewController.m
//  STQuickKitDemo
//
//  Created by yls on 13-11-27.
//  Copyright (c) 2013年 yls. All rights reserved.
//

#import "UserListViewController.h"
#import "AddUserViewController.h"
#import "UserDetailViewController.h"

#import "User.h"
//#import <STDbKit/STDbKit.h>
#import "STDb.h"
#import "NSDate+Exts.h"

@interface UserListViewController ()

@property (assign, nonatomic) NSInteger selectedRow;
@property (strong, nonatomic) NSMutableArray *users;

@end

@implementation UserListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIBarButtonItem *rightBtnItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addUser:)];
    [self.navigationItem setRightBarButtonItems:@[rightBtnItem]];
    
    _tableView.editing = YES;

    // 导入数据库数据; 如果不需要从外部导入，不做处理
//    [STDb importDb:@"user.db"];
    
//    NSInteger rowId = [User lastRowId];
//    NSLog(@"%d", rowId);
    
    // 添加默认用户
    if (![User existDbObjectsWhere:@"_id=0"]) {
        // 初始化
        User *user = [[User alloc] init];
        user._id = 0;
        user.name = @"admin";
        user.age = 26;
        user.sex = @(kSexTypeMale);
        
        user.phone = @"10086";
        user.email = @"863629377@qq.com";
        
        UIImage *image = [UIImage imageNamed:@"4"];
        user.image = UIImagePNGRepresentation(image);
        user.birthday = [NSDate dateWithDateString:@"1987-01-01"];
        user.info = @{@"name": @"xuezhang"};
        user.favs = @[@"桌球、羽毛球"];
        
        Book *book = [[Book alloc] init];
        book.name = @"oc";
        
        user.book = book;
        
        Book *book1 = [[Book alloc] init];
        book1.name = @"b1";
        Book *book2 = [[Book alloc] init];
        book2.name = @"b2";
        
        user.books = @[book1, book2];
        
        // 插入到数据库
        [user insertToDb];
        
        User *user2 = [[User alloc] init];
        user2.name = @"stlwtr";
        user2.book = book1;
        user2.books = @[book1, book2];
        
        [user2 insertToDb];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _users = [User allDbObjects];
    [_tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - tableView dataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_users count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *idetifier = @"UserListCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:idetifier];
    
    NSInteger row = [indexPath row];
    
    User *user = _users[row];
    
    UIImageView *headImgView = (UIImageView *)[cell.contentView viewWithTag:1];
    headImgView.image = [UIImage imageWithData:user.image];
    cell.textLabel.text = user.name;
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"年龄:%d", user.age];
    
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    _selectedRow = [indexPath row];
    return indexPath;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = [indexPath row];
    return row != 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSInteger row = [indexPath row];
        
        // 要删除的数据
        User *user = _users[row];
        // 从数据库中删除数据
        if ([user removeFromDb]) {
            // 数据库数据删除成功
            
            [tableView beginUpdates];
            
            // 删除数据源中的数据
            [_users removeObjectAtIndex:row];
            
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            [tableView endUpdates];
        }
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSString *idetifier = segue.identifier;
    
    if ([idetifier isEqualToString:@"userList_userDetail"]) {
        UserDetailViewController *detail = segue.destinationViewController;
        detail.user = _users[_selectedRow];
    }
}

- (void)addUser:(id)sender
{
    [self performSegueWithIdentifier:@"userList_addUser" sender:sender];
}

@end
