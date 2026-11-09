# HaruGalaxy 0.3.5 键盘焦点与玻璃控件

用户反馈显示 0.3.4 虽然能跳转到主应用，但主搜索和所有多开 App 都无法弹出键盘。源码对比发现，之前只请求窗口 key 和 first responder，没有给 UIKit 的键盘仲裁器提交当前进程/scene，也没有登记托管 PID 的键盘窗口关系。

0.3.5 新增 `MWKeyboardFocus`：以 `UIKeyboardArbiterManager` / `_UIRemoteKeyboards` 的运行时 selector、返回值和参数签名检查为前提，登记 guest PID 与真实 `FBSSceneIdentityToken`，触摸/激活窗口时选择 guest，搜索/面板/设置时选择宿主。窗口最小化、关闭、锁屏、场景断开和宿主切换释放当前关系。所有 completion 按 owner/generation 检查，旧 App 的迟到回调不能改变当前焦点。诊断只记录状态和标识，不记录输入文字。

独立复核补充了失败清理：移除托管 PID 抛异常或接口消失时保留 client/PID/caller，标记 cleanupPending，下一次选择先重试移除，失败则不登记新的 guest。标题栏点击与窗口就绪也可请求焦点，因为远程场景内部触摸不一定由本地 UIWindow 的 sendEvent 路径可见。

继续参考 LiveContainer 对键盘托管的调查，增加 `MWSceneInputEnvironment`。它先解析实际 scene identity 的 visibility environment，再只对本项目登记的精确 PID+environment 调整 `RBSTarget targetWithPid:environmentIdentifier:`；不匹配的目标直接调用原始实现，登记在 scene/presenter 清理后撤销。这个兼容层是私有 API，不能在主机上证明系统一定授予焦点。

悬浮控件新增 `MWGlassSurface`，在 iOS 14–17 使用 UIKit blur、动态亮边、透明层和微弱高光模拟 Liquid Glass。入口、标题栏和窗口面板使用该组件；guest 内容区不套玻璃。减少透明度或高对比模式切换为清晰的系统背景和更强边框，避免文字不可读。iOS 26+ 的 `UIGlassEffect` 不会在 iOS 16.2 上直接调用，因而文档称为兼容风格。

版本为 0.3.5 / build 10，Bundle ID 继续使用 `io.github.airskotex.harugalaxy`。新增 8 组 C/11 项 Python 检查，33 个生产翻译单元静态分析无诊断，原生包已生成。键盘仲裁实际结果和玻璃渲染仍需你的 iPhone 14 Pro Max / iOS 16.2 反馈。
