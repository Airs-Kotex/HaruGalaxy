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

HaruGalaxy 将已安装应用放进可移动、缩放和收纳的小窗，让多个 App 在同一屏幕中协作。以 UiharuX 的多任务能力和 MilkyWay 的操作体验为参考，采用原生 Objective-C / UIKit 实现。

**当前版本：[0.3.4](https://github.com/Airs-Kotex/HaruGalaxy/releases/tag/v0.3.4)** · [更新记录](CHANGELOG.md)

## 功能

- **原生应用小窗**：启动已安装 App，直接操作真实内容。
- **后台浮动工作区**：离开主应用后，通过屏幕边缘入口管理窗口。
- **边缘收纳**：最小化收入面板，恢复、全屏和关闭集中管理。
- **自由与等比缩放**：右上角调整宽高，右下角按系统原始比例缩放。
- **半屏与全屏**：拖动并停留即可吸附半屏，也可铺满屏幕。
- **方便唤出的入口**：轻点、向内短拉或原地长按松手打开；可设置保持展开。
- **应用搜索**：按名称或 Bundle ID 查找，支持最近使用；键盘未出现时自动转入主应用输入。
- **主题与本机日志**：深浅色、减少动画、位置记忆及手动诊断导出。

目前每个 App 一个窗口，最多同时保留四个会话。

## 安装与升级

1. 设备已安装 [TrollStore](https://github.com/opa334/TrollStore)。
2. 下载 [HaruGalaxy-0.3.4.tipa](https://github.com/Airs-Kotex/HaruGalaxy/releases/download/v0.3.4/HaruGalaxy-0.3.4.tipa)。
3. 从“文件”或分享菜单交给 TrollStore 安装，已有 0.3.1 及后续版本可直接覆盖。
4. 打开 **初春星河**，在设置中启用“浮动工作区”。

Bundle ID：`io.github.airskotex.harugalaxy`。0.3.0 及更早版本使用旧标识，其设置和日志不会自动迁移。历史版本可在 [Releases](https://github.com/Airs-Kotex/HaruGalaxy/releases) 中获取；0.3.2 已撤回。

## 使用教程

### 入口与窗口管理

| 动作 | 结果 |
| --- | --- |
| 轻点边缘凸起 | 打开或关闭窗口面板 |
| 向屏幕内短拉后松手 | 打开面板；拉回原位置则取消 |
| 原地长按后松手 | 打开或关闭面板 |
| 长按振动后继续拖动 | 移动入口，松手吸附左右边缘 |
| 设置 → 入口保持展开 | 让入口保持较宽的图标 |
| 面板 → 打开应用 | 搜索或选择已安装 App |
| 黄色减号 | 将窗口收入面板 |
| 点击面板中的窗口条目 | 恢复或聚焦窗口 |
| 红色关闭 | 关闭小窗并释放托管场景 |
| 面板外轻点 | 仅关闭面板，该次点击不操作下层 App |

入口保留小凸起，周围有更大的触摸容错区。若与 App 常用按钮重叠，可长按拖到另一侧或不同高度。

### 缩放、半屏与全屏

- **右上角细弧**：自由调整宽高，App 按新视口重新排版。
- **右下角细弧**：按当前屏幕方向的系统原始画布比例缩放；不会沿用自由拉伸后的比例。
- **半屏**：先进入自由缩放模式，再拖标题栏让窗口边缘靠近屏幕边缘，短暂停留，看到预览后松手。竖屏为上下半屏，横屏为左右半屏。
- **全屏**：点击绿色按钮或双击标题栏；通过边缘面板还原、最小化或关闭。

普通窗口可以拖到屏幕顶部。动态岛等物理遮挡、状态栏及系统手势区域仍由 iOS 管理。

### 搜索应用

点击搜索栏即可按应用名称或标识筛选。如果浮窗没有显示键盘，会自动打开初春星河的主界面继续输入，也可以直接点击 **“在主应用中搜索”**。选中应用或取消后恢复浮窗，已打开的窗口会保留。

切换过程中如系统拒绝打开主应用，会恢复浮窗并显示提示。搜索文字只用于本次筛选，不写入诊断日志。

## 兼容性

- 面向 TrollStore 官方支持系统：iOS/iPadOS 14.0 beta 2–16.6.1、16.7 RC（20H18）、17.0，构建架构为 arm64。
- 已有 iPhone 14 Pro Max / iOS 16.2 的后台浮窗与入口操作反馈。
- 外部 App 场景、键盘和动态窗口尺寸受系统及目标应用限制；iOS 14 的场景托管存在上游限制，其他设备记录见 [兼容性说明](docs/compatibility.md)。

应用重启后不会自动开启浮动模式或重新打开窗口。关闭小窗只释放自身托管场景，不向目标 App 发送终止进程信号。

## 反馈与日志

在窗口面板进入 **设置 → 真机诊断 → 标记刚发生的问题 → 导出诊断包**，并在 [Issue](https://github.com/Airs-Kotex/HaruGalaxy/issues/new/choose) 中说明版本、机型、系统 build 和复现步骤。

日志保存在本机，滚动存储约 8 MiB，包含场景、窗口、输入阶段与系统状态；不录屏、不记录输入文字、不自动上传。公开分享前请检查并按需隐藏应用标识等个人信息。

```sh
python3 scripts/inspect_diagnostics.py /path/to/HaruGalaxy-Diagnostics-example.json
```

## 从源码构建

```sh
git clone https://github.com/Airs-Kotex/HaruGalaxy.git
cd HaruGalaxy
make test
make package
make verify
```

构建需要 Clang、Mach-O linker、iPhoneOS SDK 和 ldid。Linux/WSL 配置、工具来源与摘要见 [构建说明](docs/build-environment.md)。源码包可脱离 Git 构建，仓库不分发 Apple SDK、下载缓存和用户日志。

产物位于 `dist/`：安装包、SHA-256 与构建报告。开发验证和设备记录位于 `Tests/`、`docs/` 及发布附件。

## 工程结构

```text
Sources/Core/          几何、手势、输入转场、启动状态与日志存储
Sources/Platform/      应用枚举、场景托管、主应用激活与后台执行
Sources/UI/            窗口、角标、边缘面板、搜索和设置
Sources/Diagnostics/   本机事件记录与导出
Resources/             清单、权限、图标与名称本地化
ThirdParty/            上游声明、compiler-rt 与许可证
Tests/                 核心逻辑及工具回归检查
scripts/               构建、打包、校验和日志读取
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

由 [Airs-Kotex](https://github.com/Airs-Kotex) 维护。感谢提供设备反馈和日志的用户。HaruGalaxy 是独立项目，未声称获得上述作者背书或成为其官方版本。具体复用和许可见 [NOTICE.md](NOTICE.md) 与 [LICENSE](LICENSE)。

## 参与

欢迎报告问题、补充设备兼容性记录、改进文档或提交 PR。贡献前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## Star 增长

如果项目对你有帮助，欢迎 Star、反馈和贡献。以下图表读取 GitHub 的真实历史；新仓库可能暂时没有足够数据，第三方服务也可能延迟或限流。

[![Star History Chart](https://api.star-history.com/svg?repos=Airs-Kotex/HaruGalaxy&type=Date)](https://star-history.com/#Airs-Kotex/HaruGalaxy&Date)

## 许可证

本项目新增实现采用 [Apache License 2.0](LICENSE)。第三方文件遵循各自保留的许可和署名。iPhoneOS SDK 不随仓库分发，其使用受提供方条款约束。
