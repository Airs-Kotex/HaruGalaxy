<p align="center">
  <img src="Resources/AppIcon.png" width="112" alt="HaruGalaxy icon">
</p>

<h1 align="center">HaruGalaxy · 初春星河</h1>

<p align="center">为 TrollStore 用户打造的原生多窗口工作台</p>

<p align="center">
  <a href="https://github.com/Airs-Kotex/HaruGalaxy/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/Airs-Kotex/HaruGalaxy?include_prereleases&label=release"></a>
  <a href="https://github.com/Airs-Kotex/HaruGalaxy/actions/workflows/core-tests.yml"><img alt="Core tests" src="https://github.com/Airs-Kotex/HaruGalaxy/actions/workflows/core-tests.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="Apache 2.0" src="https://img.shields.io/github/license/Airs-Kotex/HaruGalaxy"></a>
  <a href="https://github.com/Airs-Kotex/HaruGalaxy/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/Airs-Kotex/HaruGalaxy?style=flat"></a>
</p>

<p align="center">简体中文 · <a href="README.en.md">English</a> · <a href="https://github.com/Airs-Kotex/HaruGalaxy/releases">下载</a> · <a href="https://github.com/Airs-Kotex/HaruGalaxy/issues">反馈</a></p>

HaruGalaxy 将已安装应用放进可移动、缩放和收纳的小窗。项目以 UiharuX 的能力和 MilkyWay 的交互为参考，基于开放的 FrontBoard 场景托管资料实现，使用 Objective-C、UIKit 和可测试的 C 几何模型。

**0.3.2 已撤回，请使用 [0.3.1 Alpha](https://github.com/Airs-Kotex/HaruGalaxy/releases/tag/v0.3.1)。** 用户反馈升级至 0.3.2 后，悬浮窗在不同界面点击均无响应；该版 Release 和 tag 已移除，主分支代码已回滚至 0.3.1。具体失效原因尚未确认，详见 [撤回记录](docs/research/2026-11-09-0.3.2-withdrawal.md)。

用户此前反馈 **iPhone 14 Pro Max / iOS 16.2** 后台浮窗可用、整体体验可用，仍有收起入口难唤出和流畅度问题。0.3.1 是本次回退版本；构建通过、接口存在或成功取得后台请求，均不等于所有 App/设备功能已验证。

## 功能

- **真实 App 场景**：枚举设备应用，启动并托管原生内容；不是网页模拟或截图。
- **边缘窗口面板**：轻点入口管理窗口；最小化收入面板，屏幕底部不放收纳条。
- **两种缩放**：右上细弧自由调整宽高；右下细弧按系统完整画布的原始比例缩放。
- **半屏与全屏**：拖动窗口靠近边缘出现半屏预览，松手吸附；最大化使用完整屏幕边界，面板随时可还原。
- **明确的触摸规则**：轻点开面板，长按振动后拖动移位；面板外点击只关闭面板，避免误触下层 App。
- **中文界面与主题**：深浅色、减少动画、最近使用和窗口位置/模式记忆。
- **本机诊断**：场景/输入焦点/手势日志、问题标记、滚动存储和 JSON 导出，无自动上传。

首版限制每个 App 一个窗口、总计最多四个会话。关闭小窗仅释放自身持有的场景和 presenter，不向目标 App 发送结束进程信号。

## 安装与升级

1. 设备需已安装 [TrollStore](https://github.com/opa334/TrollStore)。普通签名/常规侧载无法等价提供本项目依赖的权限。
2. 下载 [HaruGalaxy-0.3.1.tipa](https://github.com/Airs-Kotex/HaruGalaxy/releases/download/v0.3.1/HaruGalaxy-0.3.1.tipa)。
3. 从“文件”或分享菜单交给 TrollStore 安装。已装 0.3.2 的用户请用此包覆盖回退，0.3.1 与 0.3.2 的 Bundle ID 相同，无须先卸载。0.3.0 及更早版本使用旧标识，设置与日志不会自动迁移。
4. 打开 **初春星河**，先在应用内打开一个常用 App 验证，再启用设置中的“浮动工作区”。

## 使用教程

### 入口与窗口管理

| 动作 | 结果 |
| --- | --- |
| 轻点边缘凸起 | 打开或关闭窗口面板 |
| 长按约 0.35 秒，振动后拖动 | 移动入口；松手吸附左右边缘，不触发轻点 |
| 面板 → 打开应用 | 搜索或选择已安装 App |
| 黄色减号 | 将窗口收入边缘面板 |
| 点面板中的窗口条目 | 恢复或聚焦该窗口 |
| 红色关闭 | 关闭小窗并释放其场景 |
| 面板外轻点 | 仅关闭面板，该次点击不操作下层 App |

### 自由缩放与系统等比

- **右上角细弧 = 自由缩放**：固定左下角，宽高可分别调整；App 接收新的逻辑视口并重新排版。
- **右下角细弧 = 系统原始比例缩放**：以当前屏幕方向的完整系统逻辑尺寸为画布。自由拉宽后切回等比，会恢复该原始比例，而不是保持拉宽后的比例。
- 手柄没有大块底色，命中区域集中在角落边缘；内部区域留给 App 内容操作。
- 某些固定布局 App 不适合窄视口，可改用原始比例模式。

### 无按钮半屏快捷操作

1. 使用右上手柄进入自由模式。
2. 拖动标题栏，让**窗口边缘**接近目标屏幕边缘。
3. 短暂停留约 0.18 秒，出现“松手进入半屏”预览后松手。

竖屏对应上/下半屏，横屏对应左/右半屏。向下拖时不需要把手指一直拖到 Home 手势区。移开会取消预览，系统取消手势时恢复原布局。

### 全屏与顶部区域

绿色按钮或双击标题栏进入全屏。全屏隐藏本项目标题栏和缩放手柄，**通过边缘面板还原、最小化或关闭**。

普通窗口也允许拖到屏幕顶部，不再被 safeTop 硬挡住。系统状态栏、Home 指示条、手势区域和动态岛的最终表现受系统控制；物理遮挡不会因窗口覆盖而消失。

### 搜索输入法

搜索开始时，应用会申请 key window/first responder 并观察实际键盘通知。

如果浮动 scene 仍不能显示系统输入法，列表上方会出现 **“键盘未显示？在主应用中输入”**。点它将激活现有主应用场景，在正常界面输入；选择或取消后恢复浮动内容，保留已打开的会话。该兼容流程不会记录搜索文字。

若系统拒绝激活主 scene，可从主屏幕打开初春星河后再搜索，并导出诊断反馈。此路径是兼容措施，不是“所有设备上浮窗键盘已修复”的承诺。

## 兼容性与已知限制

| 项目 | 状态 |
| --- | --- |
| 编译目标 | arm64，iOS/iPadOS 14.0 起 |
| TrollStore 范围 | 按官方支持版本：14.0 beta 2–16.6.1、16.7 RC（20H18）、17.0 |
| 已有真机反馈 | iPhone 14 Pro Max / iOS 16.2，0.2.2 后台浮窗可用 |
| 0.3.1 新交互与键盘 | 本地构建/逻辑检查完成，真机验收待补充 |
| iOS 14 外部场景 | 上游已知存在限制；可安装不等于完整窗口能力可用 |
| iPad / 其他版本 | 需要更多设备记录，不宣称全部验证 |

更多见 [兼容性记录](docs/compatibility.md) 和 [0.3.1 真机验收](docs/device-validation-0.3.1.md)。

已知边界：部分单场景 App 可能空窗；动态视口、键盘焦点和远程触摸坐标依赖私有接口；不保证系统强制结束进程后自动恢复。重启不会自动重开 guest 或自动启用浮动模式。项目没有注入 SpringBoard 插件，也未实现 AppSwitcher 卡片长按入口。

## 反馈与日志

在窗口面板进入 **设置 → 真机诊断 → 标记刚发生的问题 → 导出诊断包**。

导出 `HaruGalaxy-Diagnostics-….json`，包含型号、系统 build、版本、相关 App 标识、场景阶段、后台申请结果、键盘是否显示、窗口几何和运行心跳。默认详细记录，滚动存储约 **8 MiB**；不录屏、不记录键盘输入、不自动上传。

提交 [Issue](https://github.com/Airs-Kotex/HaruGalaxy/issues/new/choose) 时说明：版本、机型、精确 iOS build、TrollStore 版本、复现步骤、预期与实际结果。**公开上传前检查并按需脱敏日志**，不要放入密码、token 或账号数据。

```sh
python3 scripts/inspect_diagnostics.py /path/to/HaruGalaxy-Diagnostics-example.json
```

心跳缺口不自动等于崩溃；未捕获 Objective-C 异常可记录，fatal signal / jetsam 仍需系统日志辅助。

## 从源码构建

```sh
git clone https://github.com/Airs-Kotex/HaruGalaxy.git
cd HaruGalaxy
make test
make package
make verify
```

`make package` 需要 Clang、Mach-O linker、iPhoneOS SDK 和 ldid。Linux 配置、固定下载来源和摘要见 [构建环境](docs/build-environment.md)。工具支持显式路径：

```sh
python3 scripts/build.py \
  --sdk /path/to/iPhoneOS.sdk \
  --clang /path/to/clang \
  --linker /path/to/ld64.lld \
  --ldid /path/to/ldid
```

Windows 可使用 WSL；macOS 有工具发现分支，但仍需在对应环境验证。源码归档可脱离 Git 构建。仓库与源码包不包含 Apple SDK、下载缓存或用户日志。

输出在 `dist/`：`.tipa`、SHA-256 文件和构建报告。CI 运行 Core/日志/诊断测试，不把它标成真机 UI 验证，也不会自动下载并分发 SDK。

## 工程结构

```text
Sources/Core/          可在主机测试的几何、状态、启动及日志存储
Sources/Platform/      应用枚举、FrontBoard 场景、浮动根窗口与后台执行
Sources/UI/            窗口、角标、边缘面板、搜索和设置
Sources/Diagnostics/   本机事件记录与导出
Resources/             清单、权限、品牌图标与显示名本地化
ThirdParty/            固定上游声明、compiler-rt 与许可证
Tests/                 Core 与诊断解析回归测试
scripts/               编译、签名、打包、校验和日志读取
docs/                  构建、兼容性、调查和设备验收记录
```

## 借鉴项目与致谢

| 项目 / 作者 | 本项目中的作用 | 复用边界 |
| --- | --- | --- |
| [UiharuX](https://github.com/straight-tamago/UiharuX) · [straight-tamago](https://github.com/straight-tamago) | TrollStore 多任务能力与体验参考 | 没有打包原程序或图标；公开仓库不提供完整实现源码 |
| [MilkyWay 3](https://github.com/YuriDevTeam/MilkyWay3-Public) · [YuriDevTeam](https://github.com/YuriDevTeam)、[Soh Satoh](https://twitter.com/soh_satoh) | 窗口移动、缩放、最小化与最大化的交互启发 | 不包含其闭源插件二进制 |
| [FrontBoardAppLauncher](https://github.com/khanhduytran0/FrontBoardAppLauncher) · [khanhduytran0](https://github.com/khanhduytran0) 及贡献者 | 外部 App scene 启动、托管与浮动 binder 的核心参考 | 固定上游接口声明、保留 Apache-2.0 许可；生命周期另行修改 |
| [TrollSpeed](https://github.com/Lessica/TrollSpeed) · [Lessica](https://github.com/Lessica) | TrollStore 全局窗口和生命周期资料 | 架构参考，未拷贝 HUD 实现 |
| [LiveContainer](https://github.com/LiveContainer/LiveContainer) · 项目维护者与贡献者 | 场景/窗口管理参考 | 未拷贝其实现文件；上游头文件原有来源注释保留 |
| [TrollStore](https://github.com/opa334/TrollStore) · [opa334](https://github.com/opa334) 及贡献者 | 安装和权限机制 | 运行前提，遵循其支持范围 |
| [Theos headers](https://github.com/theos/headers) · Theos 团队 | 私有接口声明与 SDK 工具资料 | 运行时检查所需接口 |
| [Apple Runtime Headers](https://github.com/LeoNatan/Apple-Runtime-Headers) · [Leo Natan](https://github.com/LeoNatan)；[iOS Runtime Headers](https://github.com/nst/iOS-Runtime-Headers) · nst 及贡献者 | binder、scene diff 和 assertion 声明核实 | 声明参考，不代表所有 iOS 版本执行行为相同 |
| [LLVM compiler-rt](https://github.com/llvm/llvm-project/tree/llvmorg-14.0.0/compiler-rt) · LLVM contributors | Linux 交叉编译下的真实系统版本检查 | 保留 Apache-2.0 WITH LLVM-exception 许可 |

由 [Airs-Kotex](https://github.com/Airs-Kotex) 维护。感谢提供真机测试和日志的用户。HaruGalaxy 是独立项目，未声称获得上述作者背书或成为其官方版本。具体复用和许可见 [NOTICE.md](NOTICE.md) 与 [LICENSE](LICENSE)。

## 参与与路线

欢迎报告可复现的交互问题、提交不同 iOS/设备组合的测试记录、改进文档或贡献 PR。请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

近期重点：验证浮动输入法兼容路径、改善远程触摸与窗口焦点、测量实际交互延迟、补齐 iOS 14/15/17 和 iPad 记录。尚未验证的功能不会标为已支持。版本变化见 [CHANGELOG.md](CHANGELOG.md)。

## Star 增长

如果项目对你有帮助，欢迎 Star、反馈和参与测试。以下图表读取 GitHub 的真实历史；新仓库可能暂时没有足够数据，第三方服务也可能延迟或限流。

[![Star History Chart](https://api.star-history.com/svg?repos=Airs-Kotex/HaruGalaxy&type=Date)](https://star-history.com/#Airs-Kotex/HaruGalaxy&Date)

## 许可证

本项目新增实现采用 [Apache License 2.0](LICENSE)。第三方文件遵循各自保留的许可和署名。iPhoneOS SDK 不随仓库分发，其使用受提供方条款约束。
