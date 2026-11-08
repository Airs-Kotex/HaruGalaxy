// SPDX-License-Identifier: Apache-2.0
#import "MWSettingsController.h"
#import "MWPreferences.h"
#import "../Platform/MWFloatingHost.h"

@implementation MWSettingsController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"工作台设置";
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(dismiss)];
    self.tableView.rowHeight=56;
}
- (void)dismiss { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; return section==0 ? 2 : 1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; return @[@"外观",@"实验功能",@"关于"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if(section==0) return @"开启减少动画后，窗口切换将直接完成。也会遵循系统的减少动态效果设置。";
    if(section==1) return @"浮动工作区可在离开应用后继续显示。此模式尚待真机验证，键盘、触摸或锁屏恢复可能受系统版本影响；关闭后返回应用内工作台。";
    return @"0.1.0 Alpha · TrollStore\n参考 UiharuX 与 MilkyWay 的交互，基于开放源码实现。当前版本需要真机验证，不代表所有应用均支持小窗。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle=UITableViewCellSelectionStyleNone;
    if(indexPath.section==0 && indexPath.row==0) {
        cell.textLabel.text=@"主题";
        UISegmentedControl *theme=[[UISegmentedControl alloc] initWithItems:@[@"系统",@"浅色",@"深色"]];
        theme.selectedSegmentIndex=MWPreferences.shared.appearance;
        [theme addTarget:self action:@selector(themeChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView=theme;
    } else if(indexPath.section<2) {
        UISwitch *toggle=[UISwitch new];
        toggle.tag=indexPath.section;
        cell.textLabel.text=indexPath.section==0 ? @"减少动画" : @"浮动工作区";
        toggle.on=indexPath.section==0 ? MWPreferences.shared.reduceMotion : MWFloatingHost.shared.enabled;
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView=toggle;
    } else {
        cell.textLabel.text=@"UiharuXPro4MilkyWay";
        cell.textLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    }
    return cell;
}
- (void)themeChanged:(UISegmentedControl *)sender { MWPreferences.shared.appearance=sender.selectedSegmentIndex; }
- (void)toggleChanged:(UISwitch *)sender {
    if(sender.tag==0) { MWPreferences.shared.reduceMotion=sender.on; return; }
    BOOL enabled=sender.on;
    void (^handler)(BOOL)=self.floatingHandler;
    [self dismissViewControllerAnimated:YES completion:^{if(handler) handler(enabled);}];
}
@end

