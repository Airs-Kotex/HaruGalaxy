# HaruGalaxy 0.3.3 实施记录

本次继续处理回滚后未解决的入口唤出与流畅度问题。对照 iPhoneOS SDK 的 `UIControl.h` 与 Clang AST，确认 0.3.2 实现的 `beginTracking:withEvent:`、`continueTracking:withEvent:`、`endTracking:withEvent:` 是普通新增方法，没有覆盖 SDK 的 `beginTrackingWithTouch:withEvent:`、`continueTrackingWithTouch:withEvent:`、`endTrackingWithTouch:withEvent:`。旧路径同时移除了点击识别器，因此点击无法通过该代码进入入口激活。

修正三个 selector 后，将原版源码交给 Clang 解析并检查其实现方法，旧版因缺少三个 required selector 而失败，修复源码通过。构建脚本在打包前执行检查：只接受 `MWEdgeHandle` 自己的 implementation 方法，拒绝用头文件声明满足条件，并对照当前 SDK UIControl 声明的返回类型。CI 中另有无 SDK 的源码 selector 回归和检查器测试。此证据确认接口错误，不声称解释所有 guest 内容触摸异常。

独立复核发现 end/cancel 还需按 UIKit 契约调用父类清理。现正常结束无条件先调用 super，取消先清理自有模型/计时器再调用 super，避免父类取消以 nil touch 回调结束时发生重复激活。程序主动取消也经过该路径。AST 检查分别确认两个 override 内实际发送 super 消息；删除任一 super 调用的编译变体会被检查拒绝。

恢复入口的 56×76 点固定触摸区域和 12×60 点凸起、点击/短拉/原地长按唤出、振动后才拖动、取消失效计时器及保持展开偏好。恢复面板条目复用、隐藏面板不重复布局、未变化边框/角标不重复更新和常规日志异步 flush。后台/终止/异常仍保留同步边界；没有设备帧时间证据，因此不标注提速百分比。

分层证据记录根窗口抽样查询、窗口实际送达入口的触摸、UIControl 跟踪、激活与面板打开/阻挡。根查询仅记录返回值并保留原生路由；窗口记录后始终调用 super，不记录 guest 内容、键盘或连续坐标。诊断读取器按时间提供有限数量的阶段事件，并说明抽样和缺失的解释边界。

版本为 0.3.3 / build 8，Bundle ID 继续为 `io.github.airskotex.harugalaxy`。候选版源码位于修复分支，0.3.2 继续撤回，默认主分支与 0.3.1 回退包保留。实际验证结果和制品来源以随预发布附带的报告为准；[真机验收](device-validation-0.3.3.md) 尚待用户执行。
