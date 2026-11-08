# 0.2.0 实施记录

按 iPhone 14 Pro Max / iOS 16.2 的首轮反馈完成源码迭代。后台故障的代码层原因候选为 0.1.0 缺少持续执行请求和根 scene 后台更新处理；没有该设备的运行日志，尚不能把它当作最终实机根因。

改动包括：自身进程 BKS continuous assertion；仅当前自有 overlay 的 settings diff 语义归一化；锁屏期间跟踪真实基线、解锁同步；边缘小凸起；真实 presenter 的统一比例变换；本机详细日志、回收与导出；iOS 14 宿主回退。

代码复核修正了锁屏时保护基线过期、断裂日志与 UTF-8 导出缺失、极小视口缩放溢出、设置页退出后异步导出清理等问题。Scene hook 始终把原 completion 对象传给原实现一次，不丢弃系统更新或手动调用未知回调。

新权限 `com.apple.multitasking.unlimitedassertions` 用于自身后台请求。实际是否被允许由设备上的 assertion.valid 及日志记录决定。没有增加目标 App 的进程终止操作。

构建最低目标为 iOS 14.0；这扩大宿主可安装范围，不能消除 iOS 14 已知的外部 scene 限制。适配矩阵见 `compatibility.md`。本版最终真机状态依 `device-validation-0.2.0.md` 更新。
