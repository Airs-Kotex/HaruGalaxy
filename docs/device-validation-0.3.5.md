# HaruGalaxy 0.3.5 输入与外观验收

## 键盘

1. 安装 `HaruGalaxy-0.3.5.tipa`，开启浮动工作区。
2. 从浮窗打开应用搜索，点搜索框，确认系统键盘出现并能输入。
3. 打开一个需要输入的 guest App，点文本框，确认键盘出现；切换到另一个 guest，再重复一次。
4. 在 guest A 正在输入时点 guest B；B 获得焦点，A 的键盘不应残留到错误 scene。
5. 最小化、关闭正在输入的 App，再恢复另一个窗口；确认旧窗口不会重新抢焦点。
6. 锁屏/解锁、主应用搜索转浮窗、浮窗转主应用后分别重复输入。
7. 使用外接键盘时，键盘窗口不出现不应阻止文字输入。

## 日志

查看 `keyboard_pipeline`：

- `keyboard.guest_registered` / `keyboard.environment_registered`：guest PID、scene token 和 visibility environment 已登记。
- `keyboard.environment_applied`：精确 PID+environment 调整命中；不是所有进程的全局替换。
- `keyboard.focus_requested/completed`：请求和完成回调，不等于系统已显示键盘。
- `keyboard.snapshot` 字段中的 `allowed/active/visible/hosted`：当时仲裁器可见状态。
- `keyboard.visibility`：系统键盘通知及当前 owner。

如果没有 `keyboard.environment_registered`，结合 `environment_unavailable` 检查运行系统的 symbol/scene identity；如果有注册但没有 `environment_applied`，可能是系统没有执行对应 target 调用，也可能是精确匹配未命中；如果有 focus request 但 `visible=false`，重点保留该时刻的系统状态和具体 App。缺少日志本身不能确定原因。

## Liquid Glass 风格

- 边缘入口、窗口标题栏和面板使用半透明材质、内侧亮边和柔和阴影。
- 深色/浅色切换后文字和边框清晰。
- 设置中打开系统“降低透明度”或“增加对比度”后，玻璃降级为不透明系统背景和强边框。
- guest 内容不应出现玻璃叠层，点击、滚动、文本框焦点和窗口控制区域保持可用。

这版没有真实设备输入自动化；系统键盘授权、私有 API 可用性和最终视觉效果必须以设备反馈为准。
