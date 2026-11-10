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
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 5; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; return section<3 ? 2 : (section==3 ? 5 : 1); }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; return @[@"外观",@"浮动工作区",@"挂起小窗",@"真机诊断",@"关于"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if(section==0) return @"开启减少动画后，窗口切换将直接完成。也会遵循系统的减少动态效果设置。";
    if(section==1) {
        NSString *status=!MWFloatingHost.shared.enabled ? @"未启用" : (!MWFloatingHost.shared.ready ? @"正在等待浮窗根视图与窗口连接" :
            (MWFloatingHost.shared.backgroundExecutionValid ? @"系统已批准当前请求" : @"请求未获批准或已失效，请导出诊断"));
        return [NSString stringWithFormat:@"轻点入口打开面板，按住直接拖动到任意位置。松手靠近左右边缘才吸附收起；位于屏幕中间时保持展开。也可开启“入口保持展开”。最小化窗口收进面板。\n后台执行状态：%@。",status];
    }
    if(section==2) return @"挂起窗口位于右上角，点击缩略窗还原。大小按可用区域短边的比例调整，多窗口时自动缩小以免重叠；外形比例只影响缩略窗，内容保持等比，恢复时仍使用挂起前的位置、尺寸和模式。";
    if(section==3) return @"键盘无法出现时，点“采集键盘诊断”后在20秒内返回小窗点击文本框，再导出诊断包。采集包括输入请求、焦点状态、窗口显示状态和接口能力，不记录输入文字、按键或剪贴板。详细日志默认开启，本机滚动保留约8 MiB。";
    return [NSString stringWithFormat:@"%@ · TrollStore\n原生应用小窗、边缘收纳、自由与原始比例缩放。系统与应用兼容性见项目说明。",NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]];
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
        BOOL keepExpanded=indexPath.section==1 && indexPath.row==1;
        toggle.tag=keepExpanded ? 2 : indexPath.section;
        cell.textLabel.text=indexPath.section==0 ? @"减少动画" : (keepExpanded ? @"入口保持展开" : @"浮动工作区");
        toggle.on=indexPath.section==0 ? MWPreferences.shared.reduceMotion :
            (keepExpanded ? MWPreferences.shared.edgeAlwaysExpanded : MWFloatingHost.shared.enabled);
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView=toggle;
    } else if(indexPath.section==2) {
        if(indexPath.row==0) {
            cell.textLabel.text=[NSString stringWithFormat:@"大小 %.0f%%",MWPreferences.shared.parkedSizeFraction*100];
            UISlider *slider=[[UISlider alloc] initWithFrame:CGRectMake(0,0,150,44)];
            slider.minimumValue=0.18; slider.maximumValue=0.5; slider.value=MWPreferences.shared.parkedSizeFraction;
            slider.accessibilityLabel=@"挂起小窗大小";
            [slider addTarget:self action:@selector(parkedSizeChanged:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=slider;
        } else {
            cell.textLabel.text=@"外形比例";
            UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; button.frame=CGRectMake(0,0,150,44);
            [self updateParkedRatioButton:button]; cell.accessoryView=button;
        }
    } else if(indexPath.section==3) {
        cell.textLabel.text=@[@"详细诊断记录",@"采集键盘诊断（20秒）",@"标记刚发生的问题",@"导出诊断包",@"清空日志"][indexPath.row];
        if(indexPath.row==0) {
            UISwitch *toggle=[UISwitch new]; toggle.on=MWDiagnostics.shared.detailed;
            [toggle addTarget:self action:@selector(logLevelChanged:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=toggle;
        } else {
            cell.selectionStyle=UITableViewCellSelectionStyleDefault;
            cell.textLabel.textColor=indexPath.row==4 ? UIColor.systemRedColor : self.view.tintColor;
        }
    } else {
        cell.textLabel.text=@"HaruGalaxy · 初春星河";
        cell.textLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    }
    return cell;
}
- (void)logLevelChanged:(UISwitch *)sender { MWDiagnostics.shared.detailed=sender.on; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(indexPath.section!=3 || indexPath.row==0) return;
    if(indexPath.row==1) {
        [self dismissViewControllerAnimated:YES completion:^{[MWDiagnostics.shared startKeyboardCapture];}];
        return;
    }
    if(indexPath.row==2) { [MWDiagnostics.shared markProblem]; [self showDiagnosticMessage:@"已记录问题标记，请继续导出诊断包。"]; }
    if(indexPath.row==4) [MWDiagnostics.shared clearWithCompletion:^(NSError *error){[self showDiagnosticMessage:error.localizedDescription ?: @"本机日志已清空。"];}];
    if(indexPath.row==3 && !_exporting) {
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
- (void)parkedSizeChanged:(UISlider *)sender {
    MWPreferences.shared.parkedSizeFraction=sender.value;
    UITableViewCell *cell=[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2]];
    cell.textLabel.text=[NSString stringWithFormat:@"大小 %.0f%%",sender.value*100];
}
- (void)updateParkedRatioButton:(UIButton *)button {
    NSArray *ratios=@[@0,@1,@(4.0/3),@(3.0/4),@(16.0/9),@(9.0/16)];
    NSArray *titles=@[@"跟随原窗口",@"1:1",@"4:3",@"3:4",@"16:9",@"9:16"];
    NSMutableArray *actions=[NSMutableArray array];
    __weak typeof(self) weakSelf=self; __weak UIButton *weakButton=button;
    for(NSUInteger i=0;i<ratios.count;i++) {
        double ratio=[ratios[i] doubleValue];
        UIAction *action=[UIAction actionWithTitle:titles[i] image:nil identifier:nil handler:^(__kindof UIAction *item) {
            (void)item; MWPreferences.shared.parkedAspectRatio=ratio; [weakSelf updateParkedRatioButton:weakButton];
        }];
        if(fabs(ratio-MWPreferences.shared.parkedAspectRatio)<0.0001) {
            action.state=UIMenuElementStateOn; [button setTitle:titles[i] forState:UIControlStateNormal];
        }
        [actions addObject:action];
    }
    button.menu=[UIMenu menuWithTitle:@"挂起外形比例" children:actions]; button.showsMenuAsPrimaryAction=YES;
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
    if(sender.tag==2) { MWPreferences.shared.edgeAlwaysExpanded=sender.on; return; }
    BOOL enabled=sender.on;
    void (^handler)(BOOL)=self.floatingHandler;
    [self dismissViewControllerAnimated:YES completion:^{if(handler) handler(enabled);}];
}
@end

