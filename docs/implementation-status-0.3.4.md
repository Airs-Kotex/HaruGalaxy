# HaruGalaxy 0.3.4 输入流程修订

用户确认 0.3.3 的浮窗与入口操作改善，剩余问题为浮窗应用搜索无法显示键盘，原“在主应用中输入”入口也未成功跳转。没有新的诊断包，因此本次将可确认的源码问题和需要设备观察的结果分开记录。

搜索选择器原来嵌套呈现 UISearchController，搜索开始与 viewWillDisappear 的焦点取消/窗口层级恢复可能相互干扰。现在将 UISearchBar 直接放在列表头部，主界面显示后对实际 searchTextField 申请焦点。键盘通知先转换为窗口坐标并确认相交，避免将屏幕外键盘 frame 当成已出现。浮窗中等待键盘并重载一次输入视图后，仍不可见且没有输入，则自动转入主应用搜索；同时保留随时可点的按钮。

原跳转只调用 `requestSceneSessionActivation`。现在优先通过已有上游声明中的 `LSApplicationWorkspace.defaultWorkspace` / `openApplicationWithBundleID:` 打开自身 Bundle ID，检查 selector、参数数量、BOOL 返回类型与异常。声明来源为仓库固定的 `ThirdParty/FrontBoardAppLauncher/UIKitPrivate.h`；调用只面向本应用，不开放任意外部标识。接收请求不代表前台已显示，协调器等待正常 scene 进入 ForegroundActive 后才呈现搜索。0.6 秒仍未激活时请求指定 scene，6 秒仍未完成则恢复浮窗。原始 SDK/UIResponder 文档要求输入视图已挂在有效窗口、窗口成为 key，代码按此顺序执行。

`MWSearchHandoff` 是生产使用的转场状态模型，记录 generation、等待/呈现/活动状态、fallback 与总截止时间。测试覆盖已在前台、请求接受但不激活、请求拒绝、呈现超时、取消及迟到回调。它不模拟真实 LaunchServices 或 UIKit。

搜索转场期间浮窗 resignKeyWindow，并暂停自身前台状态保护；选择或取消时恢复。锁屏、退后台、关闭宿主和窗口断开时终止输入流程。独立复核指出取消可能早于搜索页展示结束：增加 `invalidateSearch`，取消立即作废搜索页和排队的 focus；迟到转场只关闭自己拥有的 navigation controller，不触及新请求。

诊断新增 `search.application_open`、`search.handoff_*`、`search.main_scene_activation/presented`、`search.keyboard_*`，读取器的 `search_pipeline` 展示有序阶段。不会记录 query 字符串。具体设备表现仍需实际通知与反馈确认。

README 中英文版本精简为产品功能、安装、教程、兼容性和反馈，保留借鉴项目、作者、许可证和 Star History。技术验证记录留在本目录和发布报告。版本 0.3.4 / build 9，Bundle ID 沿用 `io.github.airskotex.harugalaxy`。
