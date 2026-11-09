// SPDX-License-Identifier: Apache-2.0
#import "MWSettingsController.h"
#import "MWPreferences.h"
#import "../Platform/MWFloatingHost.h"
#import "../Diagnostics/MWDiagnostics.h"

@implementation MWSettingsController {
    BOOL _exporting;
}
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"工作台设置";
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(dismiss)];
    self.tableView.rowHeight=56;
}
- (void)dismiss { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 4; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; return section==0 ? 2 : (section==2 ? 4 : 1); }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; return @[@"外观",@"浮动工作区",@"真机诊断",@"关于"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if(section==0) return @"开启减少动画后，窗口切换将直接完成。也会遵循系统的减少动态效果设置。";
    if(section==1) {
        NSString *status=!MWFloatingHost.shared.enabled ? @"未启用" : (!MWFloatingHost.shared.ready ? @"正在等待浮窗根视图与窗口连接" :
            (MWFloatingHost.shared.backgroundExecutionValid ? @"系统已批准当前请求" : @"请求未获批准或已失效，请导出诊断"));
        return [NSString stringWithFormat:@"边缘入口闲置时收成小凸起，点按或向内拖动展开。内容按比例缩放，标题栏保持大小。\n后台执行状态：%@。",status];
    }
    if(section==2) return @"详细日志默认开启，保留约 8 MiB。遇到问题先点“标记刚发生的问题”，再导出 JSON。日志包含机型、系统、相关应用标识与窗口事件，保存在本机，由你决定分享给谁。不会录制画面或输入内容。";
    return [NSString stringWithFormat:@"%@ Alpha · TrollStore\n面向 iOS 14–17.0 的受支持 TrollStore 系统逐项检测能力；各版本的小窗、触摸和后台行为需实机确认。",NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]];
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
    } else if(indexPath.section==2) {
        cell.textLabel.text=@[@"详细诊断记录",@"标记刚发生的问题",@"导出诊断包",@"清空日志"][indexPath.row];
        if(indexPath.row==0) {
            UISwitch *toggle=[UISwitch new]; toggle.on=MWDiagnostics.shared.detailed;
            [toggle addTarget:self action:@selector(logLevelChanged:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=toggle;
        } else {
            cell.selectionStyle=UITableViewCellSelectionStyleDefault;
            cell.textLabel.textColor=indexPath.row==3 ? UIColor.systemRedColor : self.view.tintColor;
        }
    } else {
        cell.textLabel.text=@"UiharuXPro4MilkyWay";
        cell.textLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    }
    return cell;
}
- (void)logLevelChanged:(UISwitch *)sender { MWDiagnostics.shared.detailed=sender.on; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(indexPath.section!=2 || indexPath.row==0) return;
    if(indexPath.row==1) { [MWDiagnostics.shared markProblem]; [self showDiagnosticMessage:@"已记录问题标记，请继续导出诊断包。"]; }
    if(indexPath.row==3) [MWDiagnostics.shared clearWithCompletion:^(NSError *error){[self showDiagnosticMessage:error.localizedDescription ?: @"本机日志已清空。"];}];
    if(indexPath.row==2 && !_exporting) {
        _exporting=YES;
        [MWDiagnostics.shared exportWithCompletion:^(NSURL *file,NSError *error) {
            self->_exporting=NO;
            if(!file) { [self showDiagnosticMessage:error.localizedDescription ?: @"导出失败，请检查本机存储空间。"]; return; }
            if(!self.viewIfLoaded.window || self.presentedViewController || self.isBeingDismissed || self.navigationController.isBeingDismissed) {
                [NSFileManager.defaultManager removeItemAtURL:file error:nil];
                MWLog(@"diagnostics.export_cancelled",@{@"reason":@"settings no longer visible"}); return;
            }
            UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
            share.popoverPresentationController.sourceView=self.view;
            share.popoverPresentationController.sourceRect=[self.tableView rectForRowAtIndexPath:indexPath];
            share.completionWithItemsHandler=^(UIActivityType type,BOOL completed,NSArray *items,NSError *activityError) {
                (void)type; (void)items;
                MWLog(@"diagnostics.share_completed",@{@"completed":@(completed),@"error":MWErrorFields(activityError)});
                [NSFileManager.defaultManager removeItemAtURL:file error:nil];
            };
            [self presentViewController:share animated:YES completion:nil];
        }];
    }
}
- (void)showDiagnosticMessage:(NSString *)message {
    if(self.presentedViewController || !self.viewIfLoaded.window || self.isBeingDismissed) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"真机诊断" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)themeChanged:(UISegmentedControl *)sender { MWPreferences.shared.appearance=sender.selectedSegmentIndex; }
- (void)toggleChanged:(UISwitch *)sender {
    if(sender.tag==0) { MWPreferences.shared.reduceMotion=sender.on; return; }
    BOOL enabled=sender.on;
    void (^handler)(BOOL)=self.floatingHandler;
    [self dismissViewControllerAnimated:YES completion:^{if(handler) handler(enabled);}];
}
@end

