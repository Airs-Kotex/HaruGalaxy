# 0.2.0 浮窗黑屏与退出崩溃调查

输入：用户提供 `dist/UiharuX-Diagnostics-22E56E82-AE5C-42EF-9A0F-81F2E9D953FE.json`，31,389 字节；包含 96 条事件、两个启动会话、无丢弃/解析错误。设备 iPhone15,3，iOS 16.2 (20C65)，0.2.0 build 2。

文件最初未被 `rg --files` 找到，是因为项目 `.gitignore` 排除了 dist；直接检查用户指定路径后已读取。后续对用户指名的日志先使用精确路径，不依据尊重忽略规则的搜索判断文件缺失。

## 观测

- 01:15:18.716，`guard.unavailable` 原因为 `return signature`。
- 01:15:18.717，后台 assertion `valid=true`；后续九次采样仍为 true。不能将黑屏归因为未取得持续执行请求。
- 浮动场景身份与预期匹配，窗口连接完成；正常心跳和入口事件仍出现。
- 01:16:02.890 用户关闭浮窗，随后停止后台请求、迁回普通工作台、断开 overlay。
- 01:16:02.906 未捕获异常：`UIAutomaticScenePresenter must be invalidated before it can be deallocated.` 栈在 UIKitCore 的释放/自动释放池阶段。
- 记录的小窗操作属于浮动模式开启前。外框宽 311.427、高 723，内容扣除 48 后的比例为 430/932，外框约束正确。日志未记录内容 presentationView 实际变换，也没有浮动后成功打开 guest 的事件，因此不能据此判断用户看到的内容已等比显示。

## 源码与接口证据

1. `MWFloatingHost.stop` 原顺序为销毁 FBScene、释放 binder，未调用 binder 的 `removeScene:` 或 `invalidate`。公开 runtime header 显示 binder 持有 scene→presenter 字典，并公开 removeScene/invalidate。这与退出时自动 presenter 释放断言直接一致。
2. `FBSWorkspaceScenesClient` 的更新方法声明为 `oneway void`。Objective-C 编码中 `V` 为 oneway 限定符；0.2.0 直接检查返回编码首字符是否为 v 会拒绝 Vv。修正为去除已知限定符后验证，保留完整 runtime 编码日志。
3. 参考项目显式清除 `UIRootSceneWindow.layer.backgroundColor`。本工程只给自己的 MWOverlayWindow/canvas 设置 clearColor，未处理 binder 生成的 root window。它是黑屏的有据修复方向，但日志未包含像素/根层状态，最终仍需真机确认。
4. 原代码直接修改系统管理的 presentationView.transform。外框比例测试不能覆盖系统重设私有视图变换的行为；改为独立逻辑尺寸容器承担 uniform scale，额外记录容器和 guest 的实际几何。

接口来源（runtime 声明，不等于 iOS 16.2 的执行证明）：

- https://github.com/LeoNatan/Apple-Runtime-Headers/blob/master/iOS/PrivateFrameworks/UIKitCore.framework/UIScenePresentationBinder.h
- https://github.com/LeoNatan/Apple-Runtime-Headers/blob/master/iOS/PrivateFrameworks/UIKitCore.framework/UIRootWindowScenePresentationBinder.h
- https://github.com/LeoNatan/Apple-Runtime-Headers/blob/master/iOS/PrivateFrameworks/UIKitCore.framework/UIRootSceneWindow.h
- https://github.com/LeoNatan/Apple-Runtime-Headers/blob/master/iOS/PrivateFrameworks/FrontBoardServices.framework/FBSWorkspaceScenesClient.h
- https://github.com/khanhduytran0/FrontBoardAppLauncher/blob/fe304c66b87e9bd77896366f234dfadae01df0b6/AppDelegate.m

修复后先验证编译、ABI 类型判断、几何和日志检查，再由同一设备确认黑屏、退出稳定性及内容触摸坐标。不得把编译通过写成真机问题已解决。
