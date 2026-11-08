# UiharuXPro4MilkyWay：调研记录与首版路线建议

调研日期：2026-11-08。状态：已检查公开源码、官方发布包及文档；项目设计尚待确认，未开始产品实现或实机验证。

用户指定项目名为 `UiharuXPro4MilkyWay`，目标目录为 `E:\Codex_Work\UiharuXPro4MilkyWay`。当前会话实际位于 Linux `/root`，`/mnt`、`/media` 均为空，未发现 E 盘的挂载路径。本目录仅保存调研材料，不代表已在用户指定位置创建项目。

## 结论

有可继续开发的技术路线：以 UiharuX Pro 2.0 的行为和发布包作为对照，使用 FrontBoardAppLauncher 的公开源码研究已安装应用的场景托管，使用 TrollSpeed 的公开源码研究全局悬浮层，再实现 MilkyWay 风格的窗口操作和外观。

该路线属于建立可维护源码工程。它不等于取得了 UiharuX 原始源码，也不意味着上述两个开源组件已经完成集成。真实小窗的触摸、键盘、后台显示和生命周期需要先在目标设备验证。

## 已核实的材料

| 材料 | 核实结果 | 用途 |
| --- | --- | --- |
| UiharuX 官方仓库 | `main` 与 `1.3`、`2.0` 标签均指向 `c6380ef3a3fc6e0ddd42685b084827b9e63fd5ac`；该树仅有 README 和 LICENSE | 产品方向、功能描述及发布包入口 |
| UiharuX Pro 2.0 官方发布 | 2025-01-26 发布；附件 `com.straight-tamago.uiharux-pro-2.0.tipa`，3,393,002 字节 | 静态结构和后续实机行为对照 |
| MilkyWay3-Public | `86b736804d0da9defdfa75b6df76827cd69b5d47`；只有说明和翻译，没有插件实现源码 | 多窗口、移动、缩放、最小化、最大化等交互参考 |
| FrontBoardAppLauncher | `fe304c66b87e9bd77896366f234dfadae01df0b6`；Objective-C 源码及 Theos Makefile；仓库附 Apache-2.0 LICENSE | 已安装应用枚举、启动、场景创建、显示和尺寸更新 |
| TrollSpeed | `a609be260c8261ead36509c3bc4ded8479da9c40`；完整源码，MIT | root HUD 进程、全局窗口注册、自身视图触摸接收 |
| LiveContainer | `9d6ea09b05afa2c8fc537c372795a294db631311`；完整源码，AGPL-3.0 | 容器内多任务、窗口管理和场景呈现参考 |

来源：[UiharuX 仓库](https://github.com/straight-tamago/UiharuX/tree/c6380ef3a3fc6e0ddd42685b084827b9e63fd5ac)、[Pro 2.0 发布](https://github.com/straight-tamago/UiharuX/releases/tag/2.0)、[MilkyWay3 说明](https://github.com/YuriDevTeam/MilkyWay3-Public/blob/86b736804d0da9defdfa75b6df76827cd69b5d47/README.md)。

MilkyWay3 文档说明它面向 iOS 13–14 越狱环境；其“AppSwitcher 长按应用卡片”入口不能直接当作 TrollStore 应用已有的接入能力。TrollStore 官方明确列出不能直接向系统进程注入 tweak 的限制。[TrollStore 官方说明](https://github.com/opa334/TrollStore/blob/88424f683b2a08f34a3f88985f790f97d84ce1df/README.md#L106)

## 新找到的关键源码

FrontBoardAppLauncher 的实际源码提供了比普通 HUD 更直接的研究入口：

- `LauncherViewController.m:16` 调用 `allInstalledApplications`；第 48 行起将所选 `LSApplicationProxy` 传入窗口对象。
- `DecoratedAppSceneView.m:76` 起使用该应用的 bundle ID 构造进程 identity，执行启动 transaction；完成回调创建场景控制器。
- `AppSceneViewController.m:91` 起的有效方法使用所选应用的 bundle ID 查找运行进程，构造 scene definition；第 155 行创建 scene，第 157–163 行激活 presenter 并取出其视图。该文件第 17–89 行是注释块，不作为执行路径证据。
- `DecoratedFloatingView.m:37` 起在导航栏安装拖动手势，在缩放手柄安装尺寸调整手势。
- Makefile 将这些文件列入构建，声明 arm64、iOS 15.0 部署目标和 UIKit / FrontBoard / RunningBoardServices 依赖。

源码链接：[应用列表与选择](https://github.com/khanhduytran0/FrontBoardAppLauncher/blob/fe304c66b87e9bd77896366f234dfadae01df0b6/LauncherViewController.m#L16)、[场景托管](https://github.com/khanhduytran0/FrontBoardAppLauncher/blob/fe304c66b87e9bd77896366f234dfadae01df0b6/AppSceneViewController.m#L91)、[窗口拖动和缩放](https://github.com/khanhduytran0/FrontBoardAppLauncher/blob/fe304c66b87e9bd77896366f234dfadae01df0b6/DecoratedFloatingView.m#L37)、[构建文件](https://github.com/khanhduytran0/FrontBoardAppLauncher/blob/fe304c66b87e9bd77896366f234dfadae01df0b6/Makefile)。

上游 README 声明需要 TrollStore、支持 iOS 15.0 起的版本，并列出窗口键盘偏移、桌面上窗口键盘不可用、关闭后重开崩溃、部分单 scene 应用出现空窗等已知问题。上游支持声明不等于本项目已通过相同版本的验证。[README](https://github.com/khanhduytran0/FrontBoardAppLauncher/blob/fe304c66b87e9bd77896366f234dfadae01df0b6/README.md)

还需要重新设计关闭语义：当前源码 `AppSceneViewController.m:190` 起的清理路径最终会向应用进程发送 SIGTERM，条件满足时再发送 SIGKILL，并留有“检查 SpringBoard 是否仍托管其他 scene”的 FIXME。本项目建议将“关闭小窗”定义为释放本项目持有的 scene/presenter；“结束应用”应是另一个明确操作，不能直接沿用这段进程终止逻辑。

同一方法传给 `destroyScene:` 的字符串为 `AppSceneViewController:%p`，与创建时使用的 `sceneID:<bundle>-default` 不一致，需要追踪清理结果。当前场景 ID 也不是每个窗口独立生成，同 App 多开应在场景标识和生命周期修正后单独验证。

TrollSpeed 在 `HUDMainApplicationDelegate.mm:44` 起注册自己的窗口 context；`HUDApp.mm:73` 起把触摸交给自己的窗口。这证明它适合全局悬浮层研究，不能单凭这些代码就断言它已经解决第三方 App 的触摸路由。[窗口注册](https://github.com/Lessica/TrollSpeed/blob/a609be260c8261ead36509c3bc4ded8479da9c40/sources/HUDMainApplicationDelegate.mm#L44)、[自身窗口事件](https://github.com/Lessica/TrollSpeed/blob/a609be260c8261ead36509c3bc4ded8479da9c40/sources/HUDApp.mm#L73)

LiveContainer 承载导入到容器的应用，其 `AppSceneViewController.m:51` 创建自有 LiveProcess 扩展。它的多任务不能直接等同于任意系统已安装 App 的窗口化，因此作为补充参考。[LiveContainer 场景代码](https://github.com/LiveContainer/LiveContainer/blob/9d6ea09b05afa2c8fc537c372795a294db631311/MultitaskSupport/AppSceneViewController.m#L51)

## UiharuX 发布包证据

- 官方 `.tipa` SHA-256：`f71a78b5ecbd5bdcec6a09db7b0f87910aa37b1b4941ad9f37eb38ddf360efcc`。
- 包内可执行文件 SHA-256：`a81e412d036100b8e0e6f677395d917924b0f0771b18583910abe0a5777b75cb`。
- Info.plist 声明标识符 `com.straight-tamago.uiharux-pro`、显示名 `UiharuX Pro`、版本 `2.0`。其中 `MinimumOSVersion=12.0` 只是包声明，不能用作 TrollStore 或多窗口功能兼容范围。
- Mach-O 包含 arm64 和 arm64e 切片；load commands 声明 FrontBoard、RunningBoardServices、UIKit、SwiftUI 等依赖。
- 静态元数据中可见 `DecoratedAppSceneView`、`BaseAppViewController`、`closeWindow`、`moveWindow:`、`resizeWindow:`、`createSceneWithDefinition:initialParameters:`、`FBApplicationProcessLaunchTransaction` 等名称。
- 签名中的 XML entitlements 声明了应用启动、scene/global window 相关权限。这些声明不是系统实际授予权限或操作成功的运行证据，也不应直接整份复制到新工程。

这些名称与 FrontBoard 场景托管方向一致；仅凭名称不能确认 UiharuX 的完整调用链、代码来源或各版本上的工作状态。

REA 成功完成包清单和安全提取。当前 REA 原生分析入口因 Linux x64 主机与该 ARM FAT 二进制的架构筛选而拒绝加载；未改动工具注册或安装反编译引擎。上述 plist、Mach-O load commands、字符串节与签名 XML 的后续观察来自只读 Python `struct` / `plistlib` 解析，保存在 `uiharux-static-summary.json`，不是反编译得到的源码。

可复核记录：

- `uiharux-artifact-evidence.json`：REA `inspect_artifact`，Evidence `ev_228f714df0ce43617b4a54fa0659be33091c891a2be514e30409a9dcc69f3960`。
- 原始清单 Manifest：`agm_2862e341a8f0c01eb3fc53404dc7612ccc4d9d36f2d66a2a21c40a3990f3b7e9`。
- `uiharux-extraction-evidence.json`：文件提取位置和各文件 digest。
- `uiharux-static-summary.json`：只读静态解析结果及局限。
- `uiharux-plist-evidence.json`、`uiharux-macho-evidence.json`、`uiharux-signature-evidence.json`：保存的是原生分析失败原因，不能作为成功的原生分析证据。

## 可选开发路线

| 路线 | 结果与取舍 |
| --- | --- |
| A：源码工程，推荐 | 以 UiharuX 的能力和体验为对照，基于 FrontBoardAppLauncher / TrollSpeed 的可读实现开展适配，独立实现窗口管理与界面。调试和维护更可控，但需要重新验证集成后的行为。 |
| B：扩展 UiharuX 2.0 二进制 | 保留官方包的现有实现，研究在应用自身进程中扩展窗口界面与动作。更贴近“直接以 UiharuX 为基底”，但受内部类、Swift/Objective-C 边界和版本变化影响，目前只取得静态线索，尚未证明可用扩展入口。 |
| C：取得 UiharuX 原始工程后派生 | 如果用户目标目录中已有源码，或后续取得作者提供的源码，直接围绕原工程改进。这最符合源码 fork 的开发方式；给出的公开仓库目前不能提供该条件。 |

推荐先确认 A 是否符合用户对“以 UiharuX 为基底”的要求；若要求保留原二进制，则选择 B 并先限定版本做入口验证。

## 建议的首版范围

首个技术验收点是“一款已安装 App 的真实可交互小窗”：显示持续变化的内容，能点击、滚动、输入，能拖动、缩放、关闭和重新打开；宿主退到后台后验证全局显示。只有该链路在指定真机成立，才扩大到多窗口和视觉完善。

交互草案：

1. 可拖动的边缘悬浮按钮打开应用选择器，包含搜索与最近使用。
2. 窗口标题栏负责移动；右下手柄负责缩放；标题栏双击切换最大化与原尺寸。
3. 保留 MilkyWay 易识别的关闭、最小化、最大化动作，同时提供清晰图标和可触达的按钮区域。
4. 最小化后收纳为边缘应用条；恢复时还原窗口大小、位置与层级。
5. 关闭小窗释放本项目持有的场景资源；应用异常退出时显示可理解的状态和重试入口。

视觉草案：磨砂材质标题栏、统一圆角、轻量阴影、活动窗口强调、深浅色适配和中文界面。颜色与具体布局在技术路线确定后细化。

建议模块边界：

- 启动与设置：应用列表、最近使用、偏好保存、悬浮层启动和停止。
- 全局悬浮层：窗口注册、屏幕方向、锁屏状态、自身控件触摸。
- 场景适配：进程/场景创建、呈现、尺寸更新、焦点和资源释放，集中封装版本差异。
- 窗口管理：创建、激活、移动、缩放、最小化、恢复、关闭及状态持久化。
- 窗口界面：标题栏、控制按钮、缩放手柄、动画及主题。

数据流程：选择 App → 场景适配层返回成功的真实场景 → 窗口管理器登记 → 窗口界面承载。失败时回收已创建资源并返回具体错误；只有成功创建场景才显示可操作窗口。

## 验证与待确认条件

真实设备验证需要覆盖：宿主前后台切换、小窗触摸、键盘弹出/收起、横竖屏、最小化恢复、重复关闭重开、锁屏解锁和应用异常退出。候选代码的关闭行为和场景标识使用应先审查，再进入首版。

当前未运行 iOS 构建或真机测试。环境中未发现 `xcodebuild`、Swift 或 ldid 可执行程序；这不是对所有可能构建方案的否定。实际工程确定后再检查 Theos、SDK 或可用 macOS 构建环境。

TrollStore 官方支持范围是 iOS 14.0 beta 2–16.6.1、16.7 RC（20H18）、17.0。FrontBoardAppLauncher 的上游起点为 iOS 15；本项目实际兼容范围须取设备实测结果，不能直接声明为 iOS 14–17 全覆盖。[官方兼容范围](https://github.com/opa334/TrollStore/blob/88424f683b2a08f34a3f88985f790f97d84ce1df/README.md#L7)

后续首先需要确定可写的项目位置以及选择 A/B/C 哪条路线；具体设备型号和 iOS 版本决定首轮实机适配目标。
