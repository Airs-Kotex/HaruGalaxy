# 0.3.10：基于3B51日志的边缘输入处理

用户提供0.3.9/build14、iPhone15,3/iOS16.2(20C65)诊断，报告部分App底部按钮无响应。诊断有14330条有效记录，跨13次启动；只以最新0.3.9会话的684条记录分析本版。0.3.8的error64不应混同最新行为。原始日志包含应用标识等设备信息，留在本地并被Git忽略。

## 已有证据

- 0.3.9原应用切换使用route2，设置更新回调确认后台、本地释放通过、普通打开请求accepted=true。没有画面证据，不能称普通App渲染已验证。
- 8pt底边与28pt标题共36pt；采集guest逻辑430×932，呈现413.39056×896，比例0.9613734，符合内容/底边分离模型。日志没有失效按钮对应的实际命中，不能断言是底栏扩大覆盖。
- `_UIRemoteKeyboards`在设备上没有addWindowHostingPID:callerID:和removeWindowHostingPID:callerID:。旧实现先prepare，才检查这两个方法，形成不完整托管准备。
- prepare返回UIRemoteKeyboardWindowHosted，hidden=false，level=-9999999，宿主overlay level1100。此值可能是UIKit托管用途的特殊层级；单凭它不能证明遮挡。后续keyboardVisible变true且sourceScene匹配guest，说明有输入相关活动，也不等于用户能看到或输入。
- systemInputActive查询在设备上不可用；宿主收到的guest触摸数为0不证明无触摸，WindowServer可直接投递。原采集首样本没有guest，后创建guest缺少能力快照。

## 修正与范围

按本实现使用的prepare/finish/add/remove成对能力整体门控。缺少任一接口则不prepare托管键盘，保留系统focus-only路径，记录一次hosting_skipped。不会强制修改UIKit-owned窗口层级，也没有声称找到完整guest输入方案。

此前guest安全区始终为0，这可使贴底/全屏App布局把按钮放进系统手势区。新增纯C函数用实际渲染矩形与宿主safe rectangle计算交集，再换算为guest逻辑点，写入当前方向的scene safe-area字段。移动/旋转/模式变化也更新；拖动合并到30fps，末次提交保证最终值。窗口内部无交集时仍为0，不增加8pt底栏，不改变全屏画面范围。

诊断增加内容/缩放条frame及重叠布尔、宿主和guest请求/报告安全区、6个底部固定探针(宿主hitTest查询而非实际点击)、限时最多40条每窗口真实宿主触摸区域记录。后创建guest在第一次有效样本补接口信息；保留uiClientSettings的输入查询能力观察，不调用新的焦点策略。所有数据不含输入字符、按键、剪贴板、画面或用户触摸坐标。

纯C回归覆盖日志中的缩放尺寸、贴底交集、屏幕中间0边距、横屏、极小/无效矩形；缺少PID接口的能力集合先在旧实现失败，所有16种能力组合验证门控。原生编译和静态检查不替代设备点击验证；独立复核与发布附件记录实际检查结果。
