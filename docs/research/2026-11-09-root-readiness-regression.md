# 0.2.1 根视图检查回归

用户在 iPhone 14 Pro Max / iOS 16.2 上报告：点击“浮动工作区”立即提示“系统没有提供可管理的浮窗根视图”。本轮没有收到 0.2.1 的新 JSON 日志；目录中仍只有已分析的 0.2.0 日志，不能把旧日志当作本轮执行证据。

## 可确认的代码问题

0.2.1 在 `UIRootWindowScenePresentationBinder` 初始化后立刻调用 `_rootView`，并在创建/加入 FBScene 前要求返回可连接的 UIView。`MWRootWindowAdapter` 对 nil 与非 UIView 使用同一错误分支，对 UIView 尚未连接到 UIWindow 也报不兼容。用户看到的提示对应前一个分支。

这个前置要求没有接口或设备证据支持。公开 runtime 声明显示 binder 有 `_noteWillStartPresentingScene:`、`_rootView` 和 `addScene:`，但不承诺 init 后立即存在 root。0.2.0 的设备日志还证明 scene connection 可能在 `createScene` 内同步发生。修复必须分别处理 scene 已加入、窗口连接和 root 可用，不能用固定的单一步骤顺序推定就绪。

“懒创建导致此提示”是与代码和反馈一致的解释；没有新运行记录，不能保证 root 在 addScene 后一定会出现。新版本提供等待/拒绝分离和对应日志以验证该条件。

## 0.2.2 修复

- root 类与 ABI 能力检查可以预先执行；实际 `_rootView` 查询在 addScene 完成后开始。
- nil root、未连接到 window 的 UIView → Pending；不兼容的对象/类/ABI → Unsupported。
- 最大等待 2 秒，主线程每 50ms 观察一次；每次启动带 generation，取消或重新启动后旧任务只返回，不操作新实例。
- 普通工作台保持原位置。新 scene 先发布透明、非交互的临时窗口以建立托管层；root 和窗口两者就绪后才迁移工作台、启用交互及取得 key 状态。
- 就绪依据每次当前观察值，不累计过去已就绪的状态；root 在等待期间消失不能继续激活。
- 更换 root window 时移除旧窗口的关联，只处理当前拥有的根窗口。
- 失败后仍执行 removeScene → invalidate → destroyScene；注销失败时保留对象和禁止再启用的保护未撤回。

## 验证范围

新增生产代码共享的 C 启动状态测试覆盖：禁止 addScene 前探测、同步窗口后延迟 root、root 后延迟窗口、root 暂时出现后消失、旧 generation、取消、超时、真正拒绝，以及重复就绪只激活一次。

编译和状态机测试只能证明本地实现与回归场景，实际 binder 根窗口生成时机仍需要设备反馈。下一次日志用 `overlay.scene_created` → `overlay.root_probe` → `overlay.root_ready` 或 `overlay.root_rejected` 区分。
