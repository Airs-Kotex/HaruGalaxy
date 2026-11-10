// SPDX-License-Identifier: Apache-2.0
#import "MWDisplayOptionsController.h"

@implementation MWDisplayOptionsController {
    BOOL _finished;
}
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"原始画布";
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
        target:self action:@selector(close)];
    self.tableView.rowHeight=UITableViewAutomaticDimension; self.tableView.estimatedRowHeight=76;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section; return self.windows.count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; (void)section; return self.windows.count ? @"点选一个窗口进行切换" : @"请先从窗口面板打开一个应用";
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return @"原始画布使用手机原始画布，再缩放到小窗中。切换会重新打开该小窗，当前页面或表单可能重置。外窗位置和比例会保留；仅调整布局，不能修复键盘或未提交画面的应用。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    NSDictionary *row=self.windows[indexPath.row];
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text=row[@"name"]; cell.textLabel.numberOfLines=2;
    cell.detailTextLabel.text=[row[@"compatible"] boolValue] ? @"当前为原始画布 · 点此切回普通并重新打开" : @"原始画布并重新打开";
    cell.detailTextLabel.numberOfLines=0; cell.detailTextLabel.textColor=self.view.tintColor;
    cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator; return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(_finished || indexPath.row<0 || (NSUInteger)indexPath.row>=self.windows.count) return;
    _finished=YES;
    NSDictionary *row=self.windows[indexPath.row];
    NSString *bundle=row[@"bundle"]; BOOL compatible=![row[@"compatible"] boolValue];
    void (^handler)(NSString *,BOOL)=self.selectionHandler;
    [self.navigationController dismissViewControllerAnimated:YES completion:^{if(handler) handler(bundle,compatible);}];
}
- (void)close {
    if(_finished) return; _finished=YES;
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}
@end
