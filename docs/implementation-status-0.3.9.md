# 0.3.9 细边与输入证据

用户反馈0.3.8的底部还能更薄、guest键盘仍不出现、每次切原应用都提示“不支持安全交接”并关闭小窗。目录中仍只有旧0.2.x诊断，不能以离线构建判断当前系统的键盘运行状态。

错误文字明确来自FBScene deactivate:的ABI检查失败分支。0.3.8把iOS17声明中的接口作为唯一途径，且检查之前UI已移除并关闭目标。本版基于保留的FrontBoardAppLauncher声明及nst运行时声明，补充updateSettings:withTransitionContext:completion:路径：从当前settings取得mutableCopy，仅把foreground改为NO，检查实际setter/方法ABI，通过完成回调及foreground=false再进入本地清理。仍保留输入关系清理、presenter invalidate、scene destroy、scene lookup、代际与2秒超时保护。预检先于UI移除；不存在可用路径时不关闭窗口。

独立复核纠正了属性名与getter的区别：前台状态统一通过声明中的isForeground读取，使用带类型的Objective-C调用及运行时检查，避免误把foreground当selector。触摸计数限定在已有guest呈现子树，标题标签和空白拖动区只维持原来的焦点行为，不增加guest触摸计数。

底部18→8pt，标题仍28pt，控件合计36pt。保持整条宿主专用区域，不把透明触摸区域扩进guest内容。线条改为中央短线，颜色降低，接触加亮。旧几何实现先触发36pt上限断言失败，新实现验证尺寸、分离、旋转与比例。

直接输入的可行性不能仅依据接口声明判断。FrontBoardAppLauncher README明确列出桌面浮窗键盘尚未工作；这说明该后端存在已知限制，不证明所有系统/托管模式均不可能。现有仲裁/可见性桥调用已有0.3.5–0.3.6实现，本轮不再叠加私有焦点操作。移除不能解决问题的MWInputBoardController与全部UI入口，保留正常主应用搜索。

设置增加20秒采集。MWDiagnosticCapture使用单调时间、每秒限速、最多21次样本、代际取消和过期结束；主线程暂停后不追赶漏采。采集通过通知读取既有对象状态，限定四个guest与最多32个自有window元数据。新增RuntimeDiagnostics只检查method编码和经过ABI检查的无参getter，不遍历文本视图、不读取对象description、不触发焦点选择。问题标记与导出也补一份能力快照；未知getter保留unavailable而非false。

此版提供可区分“guest未请求输入”“接口不匹配”“环境桥未匹配”“已选择但键盘未出现”的设备证据。记录仍需要结合实际画面，不将systemInputActive或visible视为可以输入的证明。键盘问题没有被宣布解决。

参考：

- `ThirdParty/FrontBoardAppLauncher/UIKitPrivate+MultitaskSupport.h`中FBScene的updateSettings声明；上游固定提交`fe304c66b87e9bd77896366f234dfadae01df0b6`。
- [nst FBScene runtime declarations](https://github.com/nst/iOS-Runtime-Headers/blob/master/PrivateFrameworks/FrontBoard.framework/FBScene.h)。
- [FrontBoardAppLauncher README / Known issues](https://github.com/khanhduytran0/FrontBoardAppLauncher#known-issues)。

测试、原生构建、静态分析、复核、源码归档与发布校验结果保存在release的verification-report.json。没有本版真机验证结果。
