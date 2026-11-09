# HaruGalaxy 0.3.1 实施记录

品牌改为 HaruGalaxy / 初春星河，Bundle ID 依用户追加要求改为 `io.github.airskotex.harugalaxy`；与旧应用独立安装，不自动迁移设置/日志。本次发布计划对应 GitHub `Airs-Kotex/HaruGalaxy`；用户明确授权公开上传。原始诊断、SDK、下载缓存和凭据不进入仓库。

修正系统比例语义，角标迁到右上/右下；普通拖动使用完整bounds，半屏根据未裁剪窗口边界和方向触发，降低下半屏手势对系统底部区域的依赖。

搜索先恢复窗口key状态并降低本窗口层级以避免遮盖输入视图，记录实际键盘通知；正常scene兼容搜索由协调器管理，取消/错误/退后台恢复overlay，锁屏状态仍由host统一计算。代码复核修正活跃UISearchController下误关闭子呈现，以及旧输入请求回调结束新请求的问题。

自由缩放使用CADisplayLink合并尺寸提交，重复逻辑尺寸和重复阴影路径计算被跳过；这属于代码级优化，没有设备帧时间证据，不标注具体FPS改善。

构建产物名称、可执行文件、国际化显示名、README/英文README、贡献说明、问题模板、变更记录和基础CI同步更新。上游来源保留NOTICE与许可证。Star History使用公开真实数据链接，不包含用户token或伪造统计。
