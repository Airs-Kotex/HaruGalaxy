# UiharuXPro4MilkyWay

面向 TrollStore 的原生多窗口工具实验版。以 UiharuX 的能力为对照，采用 FrontBoardAppLauncher 的开放场景机制，重新实现 MilkyWay 风格的窗口操作和中文界面。

**当前版本：0.2.1 Alpha。** 已读取 iPhone 14 Pro Max / iOS 16.2 的 0.2.0 诊断日志：后台请求持续有效，但浮窗关闭时发生 `UIAutomaticScenePresenter` 未注销断言，另有根窗口黑屏和内容缩放的实机反馈。本版修正 binder 注销顺序、限定根窗口透明/穿透处理、`oneway void` 类型检查，并用独立容器缩放真实内容。**0.2.1 仍需同一设备确认显示、退出和触摸；编译和签名成功不等于真机修复已验证。**

## 已实现的代码

- 已安装应用选择器：名称/标识符搜索、图标、最近使用。
- FrontBoard 应用启动、唯一场景创建与原生 presenter 承载。
- 窗口标题栏拖动、右下角等比缩放、双击标题栏按比例最大化/还原；标题栏不随内容缩小。
- 关闭、最小化、最大化三键；最小化应用条及恢复。
- 同一 App 只保留一个窗口；Alpha 最多同时保留四个窗口。
- 窗口位置与大小记录、主题跟随/浅色/深色、减少动画。
- 启动超时、失败重试、应用退出检测、关闭后取消回调。
- 关闭小窗仅释放本项目的 scene/presenter，不向目标应用发送结束进程信号。
- 实验性浮动工作区：将同一工作台移到独立根场景，提供边缘悬浮按钮；关闭后回到应用内。默认关闭，每次启动需手动启用。
- 边缘入口闲置时收为 8pt 小凸起，保留 44pt 触达区域；点按/向内拖动展开，左右吸附并记忆位置。
- 仅对自身进程申请持续后台执行，对自身当前浮动 scene 的更新做语义保护，锁屏仍可隐藏内容。申请结果、失效与回调均记入日志。
- 详细本机诊断：最多约 8 MiB 滚动日志、运行心跳、问题标记、JSON 导出；断裂记录恢复与异常字节保留。
- 0.2.1 新增根窗口透明状态、运行时方法签名、binder 清理阶段以及真实内容缩放/变换日志；根窗口无法安全识别时拒绝开启浮窗。

这是独立源码实现，不包含 UiharuX/MilkyWay 原始二进制或素材。来源见 [NOTICE.md](NOTICE.md)。

## 安装与操作

1. 在已安装 TrollStore 的测试设备上打开 `dist/UiharuXPro4MilkyWay-0.2.1.tipa`，交给 TrollStore 安装。
2. 打开“UiharuX 银河”，点击“打开应用”，先选择一个常用测试 App。
3. 拖动标题栏移动；拖动右下手柄等比缩放内容；双击标题栏最大化/还原。
4. 点击减号收纳到应用条，点击应用条条目恢复；点击关闭只关闭小窗。
5. 设置中可切换主题或启用实验性浮动工作区。边缘凸起点按展开，再点打开应用选择器；长按打开设置，闲置 3 秒自动收回。
6. 浮动模式出现问题时，回到主应用，点击“返回应用内工作台”。

编译目标为 **arm64 / iOS 14.0 起**，使用运行时能力检测和 iOS 14 样式回退。安装目标、可用接口与已验证功能分别记录，见[兼容性矩阵](docs/compatibility.md)。TrollStore 本身支持的版本及安装要求见 [官方说明](https://github.com/opa334/TrollStore)。

## 真机反馈与日志

详细记录默认开启。推荐先在 iPhone 14 Pro Max / iOS 16.2 按以下顺序复测：

1. 用 0.2.1 覆盖安装，先空载开启浮窗，确认背景可见、空白可点，再关闭浮窗确认不闪退。
2. 从边缘入口打开测试 App，尝试等比缩放、点按与滚动；普通入口和浮动入口均测一次。
3. 上述通过后再回桌面等待 30 秒，及锁屏/解锁验证恢复；出现黑屏时不要反复重试旧包。
4. 回到本应用设置 → 真机诊断 → **标记刚发生的问题** → **导出诊断包**。
5. 保存/分享 `UiharuX-Diagnostics-….json`，连同发生时间及操作步骤反馈。

导出包包含机型、系统 build、应用版本、能力/权限观察、后台请求状态、场景生命周期、相关应用标识、几何事件和心跳间隔。日志在本机；不自动上传、不录制屏幕或输入内容。若分享无法打开，可通过应用的文件共享目录取得 `Documents/Diagnostics/events-*.jsonl`。

分析工具：`python3 scripts/inspect_diagnostics.py <导出的 JSON 路径>`。心跳缺口只是进程/主线程运行间隔的证据，不自动判定为崩溃。完整测试步骤见[0.2.1 真机验收](docs/device-validation-0.2.1.md)。

## 已知限制

- 0.2.1 的根层透明、穿透触摸、缩放后坐标、键盘和旋转仍需复测。部分单场景 App 可能不接受新 scene；创建了 presenter 也不代表已有首帧画面。
- 浮动根场景使用 FrontBoard presentation binder，加上持续执行 assertion 和只针对当前自有 overlay 的 diff 适配。系统可能拒绝请求或变更私有接口，日志会记录其结果；不承诺被用户强制结束后的自动恢复。
- iOS 14 的外部应用 scene 有上游已知限制；降低安装目标不代表该版本的完整小窗能力已经验证。
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

- `dist/UiharuXPro4MilkyWay-0.2.1.tipa`
- `dist/UiharuXPro4MilkyWay-0.2.1.tipa.sha256`
- `dist/build-report.json`（工具、SDK、源码提交与设备验证状态）

`make test` 执行状态/比例几何、边缘位置、日志滚动/中断恢复以及诊断解析测试。`make verify` 检查安装包路径、Info.plist、arm64/iOS 14 部署信息、签名结构、权限与资源；它不替代 TrollStore 安装和系统权限校验。

## 迁移至 Windows 项目目录

当前工作副本：`/root/UiharuXPro4MilkyWay`。将源码归档 `dist/UiharuXPro4MilkyWay-source-0.2.1.zip` 解压到 `E:\Codex_Work`，得到目标目录 `E:\Codex_Work\UiharuXPro4MilkyWay`。

源码归档不包含 SDK、下载缓存或安装包；`.tipa` 可单独传到设备。Windows 上编辑源码后，构建可使用 WSL/Linux 或 macOS，不能把本次 Linux 编译链直接当作 Windows 原生工具运行。

## 工程结构

```text
Sources/Core/       C 状态与窗口几何，主机可测试
Sources/Platform/   应用枚举、FrontBoard 场景、浮动根场景
Sources/Diagnostics/ 本机事件日志、设备信息、运行心跳与导出
Sources/UI/         工作台协调器、窗口控件、应用选择器和设置
Resources/          清单、权限、原创矢量图标及其 PNG 导出
ThirdParty/         固定上游接口声明与许可证
Tests/              状态机与几何测试
scripts/            编译、签名、打包和产物检查
docs/               设计、实施记录与真机验收表
```

设备验证请使用 [0.2.1 真机验收表](docs/device-validation-0.2.1.md)。之前版本的原始验收记录保留作历史参考。

