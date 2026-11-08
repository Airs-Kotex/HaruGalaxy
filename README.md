# UiharuXPro4MilkyWay

面向 TrollStore 的原生多窗口工具实验版。以 UiharuX 的能力为对照，采用 FrontBoardAppLauncher 的开放场景机制，重新实现 MilkyWay 风格的窗口操作和中文界面。

**当前版本：0.1.0 Alpha。已完成 Linux 交叉编译和离线安装包检查，尚未在 iPhone/iPad 上运行验证。** 编译成功不能证明私有权限、触摸、键盘和后台浮窗在你的系统上可用。

## 已实现的代码

- 已安装应用选择器：名称/标识符搜索、图标、最近使用。
- FrontBoard 应用启动、唯一场景创建与原生 presenter 承载。
- 窗口标题栏拖动、右下角缩放、双击标题栏最大化/还原。
- 关闭、最小化、最大化三键；最小化应用条及恢复。
- 同一 App 只保留一个窗口；Alpha 最多同时保留四个窗口。
- 窗口位置与大小记录、主题跟随/浅色/深色、减少动画。
- 启动超时、失败重试、应用退出检测、关闭后取消回调。
- 关闭小窗仅释放本项目的 scene/presenter，不向目标应用发送结束进程信号。
- 实验性浮动工作区：将同一工作台移到独立根场景，提供边缘悬浮按钮；关闭后回到应用内。默认关闭，每次启动需手动启用。

这是独立源码实现，不包含 UiharuX/MilkyWay 原始二进制或素材。来源见 [NOTICE.md](NOTICE.md)。

## 安装与操作

1. 在已安装 TrollStore 的测试设备上打开 `dist/UiharuXPro4MilkyWay-0.1.0.tipa`，交给 TrollStore 安装。
2. 打开“UiharuX 银河”，点击“打开应用”，先选择一个常用测试 App。
3. 拖动标题栏移动；拖动右下手柄缩放；双击标题栏最大化/还原。
4. 点击减号收纳到应用条，点击应用条条目恢复；点击关闭只关闭小窗。
5. 设置中可切换主题或启用实验性浮动工作区。悬浮按钮点击打开应用选择器，长按打开设置。
6. 浮动模式出现问题时，回到主应用，点击“返回应用内工作台”。

编译目标为 **arm64 / iOS 15.0 起**。这不是完整兼容性声明。TrollStore 本身支持的版本及安装要求见 [官方说明](https://github.com/opa334/TrollStore)。

## 已知限制

- 真实应用内容、触摸路由、键盘、旋转和后台存活尚未实机验证。部分单场景 App 可能不接受新 scene；创建了 presenter 也不代表已有首帧画面。
- 浮动根场景使用 FrontBoard 的 presentation binder。当前没有移植上游对系统场景状态更新的拦截，因此持续显示、桌面穿透和恢复均作为实验项；不能承诺与 UiharuX Pro 完全一致。
- 锁屏状态通知用于隐藏浮动窗口，并同步应用场景可见性；此路径的具体系统行为仍需真机检查。
- 重启应用不会自动重开第三方 App，也不会自动开启浮动模式。
- 未接入 AppSwitcher 卡片长按入口，没有 SpringBoard 插件注入。
- 本环境是 Linux，没有 iOS 设备、模拟器或 Xcode GUI。此版本没有经过屏幕截图比对或设备安装测试。

## 构建

详见 [构建环境](docs/build-environment.md)。已备好环境时：

```sh
make test
make package
make verify
```

打包脚本使用原生 Clang、iPhoneOS SDK、Mach-O 链接器和 ldid，不要求 Theos 或 Swift。

生成文件：

- `dist/UiharuXPro4MilkyWay-0.1.0.tipa`
- `dist/UiharuXPro4MilkyWay-0.1.0.tipa.sha256`
- `dist/build-report.json`（工具、SDK、源码提交与设备验证状态）

`make test` 在主机执行与 iOS UI 相同的 C 状态/几何实现。`make verify` 检查安装包路径、Info.plist、arm64/iOS 15 部署信息、签名结构、权限与资源；它不替代 TrollStore 安装和系统权限校验。

## 迁移至 Windows 项目目录

当前工作副本：`/root/UiharuXPro4MilkyWay`。将源码归档 `dist/UiharuXPro4MilkyWay-source-0.1.0.zip` 解压到 `E:\Codex_Work`，得到目标目录 `E:\Codex_Work\UiharuXPro4MilkyWay`。

源码归档不包含 SDK、下载缓存或安装包；`.tipa` 可单独传到设备。Windows 上编辑源码后，构建可使用 WSL/Linux 或 macOS，不能把本次 Linux 编译链直接当作 Windows 原生工具运行。

## 工程结构

```text
Sources/Core/       C 状态与窗口几何，主机可测试
Sources/Platform/   应用枚举、FrontBoard 场景、浮动根场景
Sources/UI/         工作台协调器、窗口控件、应用选择器和设置
Resources/          清单、权限、原创矢量图标及其 PNG 导出
ThirdParty/         固定上游接口声明与许可证
Tests/              状态机与几何测试
scripts/            编译、签名、打包和产物检查
docs/               设计、实施记录与真机验收表
```

设备验证请使用 [真机验收表](docs/device-validation.md)，记录型号、精确 iOS 版本和 TrollStore 版本。

