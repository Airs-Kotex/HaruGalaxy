# 构建环境与复现

本次构建使用 Ubuntu 22.04 x86_64、Clang 14 和 Theos 发布的 iPhoneOS16.5.sdk 归档，0.2.0 产物为 arm64 / iOS 14.0 的原生 Objective-C 应用。该 SDK 归档内部 `SDKSettings.plist` 的 Version 为 16.4，构建报告按实际元数据记录。源码未使用 Swift。

## Linux

系统依赖：`clang-14`、`lld-14`、`make`、`python3`、主机 C 编译器和 `xz-utils`。

```sh
sudo apt-get install clang-14 lld-14 make python3 gcc xz-utils
mkdir -p .toolchain
curl -fL --retry 2 -o .toolchain/iPhoneOS16.5.sdk.tar.xz https://github.com/theos/sdks/releases/download/master-146e41f/iPhoneOS16.5.sdk.tar.xz
curl -fL --retry 2 -o .toolchain/ldid https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_linux_x86_64
sha256sum .toolchain/iPhoneOS16.5.sdk.tar.xz .toolchain/ldid
tar -xJf .toolchain/iPhoneOS16.5.sdk.tar.xz -C .toolchain
chmod +x .toolchain/ldid
make test
make package
```

本次取得的文件摘要（用于复现同一工具输入，不代表对上游制品的独立认证）：

| 文件 | SHA-256 |
| --- | --- |
| iPhoneOS16.5.sdk.tar.xz | `5e0fd3f01266cce4ce012d4a99b38eb56578fca40d09edc81cd83dee958202fb` |
| ldid_linux_x86_64 | `4b8862b2fefa2cd7fa8f88cb0310779619aeaa8c72d6aff22f019b470f2fa99a` |

工具版本：`Ubuntu clang version 14.0.0-1ubuntu1.1`、`Ubuntu LLD 14.0.0`、ldid 发布 `v2.1.5-procursus7`。

SDK 来源：[theos/sdks 固定发布](https://github.com/theos/sdks/releases/tag/master-146e41f)。签名工具来源：[ProcursusTeam/ldid 固定发布](https://github.com/ProcursusTeam/ldid/releases/tag/v2.1.5-procursus7)。使用下载内容时请遵守其提供方的许可条件。

## 已有工具或 macOS

```sh
python3 scripts/build.py --sdk /absolute/path/iPhoneOS16.5.sdk --clang /absolute/path/clang --linker /absolute/path/ld64.lld --ldid /absolute/path/ldid
```

也可以设置 `IOS_SDK`、`IOS_CLANG`、`IOS_LD`、`LDID`。macOS 默认通过 `xcrun --sdk iphoneos --show-sdk-path` 查找 SDK，并使用系统 Clang/ld；该分支尚未在 macOS 验证，报错时请保存完整编译输出。不同 Clang/SDK 组合可能需要调整声明或链接选项。

编译启用 `-Wall -Wextra -Werror`、ARC、栈保护与 Objective-C exceptions。按参数数组调用工具，无 shell 命令拼接。脚本只清理自身的 `build/ios/objects` 和 `build/ios/Payload/HaruGalaxy.app`，防止旧文件进入新包。0.3.1 起安装包为 `HaruGalaxy-<version>.tipa`，Bundle ID为`io.github.airskotex.harugalaxy`；从旧标识安装会形成独立应用，不能当作同标识覆盖升级。

0.2.0 使用 iOS 14 目标和 `@available(iOS 15, *)` 样式回退。Linux 链接器不会自动提供 Apple compiler-rt，因此将 LLVM 14.0.0 原始 `os_version_check.c` 和许可证纳入 ThirdParty；它负责真实系统版本检测，未用恒真返回值绕过可用性检查。

## 图标

`Resources/AppIcon.svg` 是项目原创的几何矢量图标，PNG 已入库，正常编译无须图像工具。可选的 `scripts/render_icon.py` 使用 Pycairo 按相同几何生成各设备尺寸；该依赖只用于重新导出图标。

## 签名和验证边界

ldid 写入 ad-hoc 代码签名与项目权限；TrollStore 在安装时处理其签名。离线校验会解析 Mach-O 和签名权限，检查是否与工程一致。它不验证设备是否实际授予这些权限，也不证明 scene 创建、触摸、键盘或后台显示成功。

“可复现构建”在此指可以按固定工具和源码重复完成编译流程；zip 时间戳等未归一化，不承诺字节完全相同的归档。

