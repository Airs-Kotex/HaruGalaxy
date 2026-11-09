# Contributing to HaruGalaxy

感谢帮助初春星河改进真机兼容性与窗口交互。

## 提交问题

先查看 [Issues](https://github.com/Airs-Kotex/HaruGalaxy/issues)，避免重复。提供应用版本、设备型号、iOS 精确 build、TrollStore 版本、可复现步骤，以及发生在应用内还是浮动模式。

设置 → 真机诊断 → 标记问题 → 导出诊断包。公开上传前检查日志内容；其中可能有相关 App 的 bundle ID 和设备信息。不要提交密码、token、屏幕敏感内容或未经检查的系统日志。

## 提交修改

1. Fork 仓库并创建功能分支，围绕一个具体问题修改。
2. 执行 `make test`。UI/Platform 改动还应完成 `make package`，按设备验收表记录实际测试。
3. 提交 PR，描述触发条件、行为变化、验证方式和仍未验证的部分。

不要提交 `.toolchain/`、`build/`、`dist/`、SDK、签名凭据或用户诊断文件。保留上游版权及来源说明。新私有接口需给出可查证的声明来源、运行时检查和失败回退。

Core 测试验证真实几何/状态/存储行为；不要用字符串存在性测试替代运行行为。编译通过不等同于 iOS 真机功能通过。PR 若改变后台托管、窗口清理或触摸路由，应明确列出设备版本和取消/锁屏/失败路径。

## English

Please keep pull requests focused, run `make test`, and disclose device-validation limits. Native UI or platform changes should include a successful build and a device test record where available. Preserve attribution and never commit SDKs, credentials, packages, or private logs. Runtime capability checks and failure cleanup are required for new private APIs.
