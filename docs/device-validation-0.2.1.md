# 0.2.1 浮窗修复复测

目标设备仍为 iPhone 14 Pro Max / iOS 16.2 (20C65)。0.2.0 的实际日志已分析：后台请求持续 valid，崩溃发生在关闭 overlay 后，异常为自动 scene presenter 释放前未 invalidate。黑屏与内容缩放是用户实机观察，原日志缺少根层像素状态和实际内容变换。

## 修复内容与证据边界

- binder 清理改为 removeScene → invalidate → destroyScene → release；取消中同步回调有重入保护。若 invalidate 抛异常，隐藏并保留失败对象，阻止再次启用，避免再次释放未注销 presenter。
- 仅标记本项目 binder 的 root view/window，透明与命中处理不作用于其他 root window。无法取得可检查的根窗口时拒绝启用。
- Scene guard 去除 oneway 等 Objective-C 限定符后再验证 ABI，同时记录完整实际编码；不把不兼容的实质返回类型当作 void。
- 真实 guest view 放入本项目拥有的逻辑尺寸容器，只给容器施加等比变换；原生 guest 自身 transform 仍由 UIKit 管理。
- 锁屏 observer 注册后立即读取状态，补上同步 scene 连接早于 observer 注册的时序。

以上通过主机测试、编译和源码复核不代表 iOS 实机已验证。

## 最短复测步骤

1. 确认设置中的版本为 0.2.1 / build 3。
2. 不打开 guest，启用浮动工作区，确认桌面/原界面可见且空白区域可操作。
3. 长按边缘入口打开设置，再关闭浮动工作区；确认应用不闪退，手机恢复正常工作台。先测一次，不必进行高频开关。
4. 再启用，从边缘入口打开一个测试 App，记录内容是否完整、等比、能点按/滚动；拖动缩放并最大化/恢复。
5. 如仍异常，回主应用导出诊断，说明失败在第几步。若开启即黑屏，不再反复尝试同版本。

## 新日志字段

| 事件 | 用途 |
| --- | --- |
| guard.method_abi | 实际方法类型编码，确认 Vv 或其他返回类型 |
| overlay.root_before / root_attached / root_rejected | 根类名、opaque、背景 alpha 或拒绝原因 |
| overlay.binder_scene_removed / binder_invalidated / scene_destroyed | 应按顺序出现的退出阶段 |
| overlay.binder_invalidate_failed | 清理失败，资源保留到退出，要求重新启动 |
| overlay.lock_observer / overlay.lock | 首次锁屏状态是否及时读取 |
| window.content_geometry | 逻辑尺寸、容器缩放 X/Y、guest 实际 bounds 和 transform |

当 scaleX 与 scaleY 相等而内容仍变形，要结合 guestTransform 和实际截图继续分析；只检查外框比例不足以证明内容正确。
