# 0.3.4 输入路径设备检查

已有反馈设备：iPhone 14 Pro Max / iOS 16.2（20C65）。0.3.3 浮窗/入口得到用户认可；0.3.4 关注键盘和主应用跳转，以下项目尚待设备执行。

| 场景 | 操作与预期 |
| --- | --- |
| 主界面搜索 | 点搜索栏，输入中文、英文、Bundle ID；筛选及时刷新，列表滚动时能收起键盘 |
| 浮窗搜索 | 从边缘面板打开应用，点搜索；若键盘可见直接输入，若不可见则自动转入初春星河主界面 |
| 主应用按钮 | 不需要先点搜索，直接点“在主应用中搜索”；主界面显示并聚焦搜索栏 |
| 文本衔接 | 浮窗已有关键词时转入主应用，继续同一关键词；日志不含文字内容 |
| 正常前台 | 主应用本来在前台时使用输入转场，不重复启动 scene，不出现多张搜索页 |
| 返回浮窗 | 选择应用或点关闭后，原有窗口和入口恢复，选定应用在浮窗中打开 |
| 转场中取消 | 在主应用出现动画中锁屏或退后台；解锁后没有旧输入框重新抢焦点 |
| 重复操作 | 快速搜索、取消、重新搜索；旧 timeout/error/完成回调不能结束新搜索 |
| 外接键盘 | 有实际按键输入时不因软键盘未显示而切换场景 |
| 请求被拒绝 | 系统不激活主场景时，在截止时间恢复浮窗并提示，不留下全屏透明阻挡 |
| 既有交互 | 轻点/拉动入口、窗口移动、缩放、最小化、半屏继续可用 |

导出诊断后运行 `python3 scripts/inspect_diagnostics.py <路径>`，关注 `search_pipeline`：

1. `search.focus_request` / `search.keyboard_check`：是否成为 first responder、窗口是否 key、是否实际观察到键盘。
2. `search.handoff_automatic` / `search.main_scene_requested`：自动或手动选择主应用输入。
3. `search.application_open`：系统是否接受打开本应用的请求；不等于激活已完成。
4. `search.main_scene_activation`：发生指定 scene 的备用激活请求。
5. `search.main_scene_presented`：正常场景在前台且搜索界面呈现完成。
6. `search.keyboard_shown`：frame 经窗口转换后是否真实相交。
7. `search.handoff_cancelled/timeout`、`search.main_scene_finished`、`overlay.search_input`：取消、截止和浮窗恢复。

只用这些阶段判读当前 session，不由“请求接受”推断键盘可用，也不因单条日志缺失直接认定根因。
