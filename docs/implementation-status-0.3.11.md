# 0.3.11 显示兼容与窗口交互

## iOS15设备证据

用户9D9导出为iPhone13,2/iOS15.4.1(19E258)、0.3.10/build15，共1133条、一次启动，没有丢弃/格式错误。870(com.rjs.game)和Telegram(ph.telegra.Telegraph)均取得进程/presenter，没有guest.failed；870最初内容390×164，后来全画布重开仍获用户画面异常反馈。Telegram初始350×731，随后多次改变比例/半屏。两份导出快照时guest均已关闭，没有限时采集或场景图层证据，不能确定“全窗空白”还是“部分图片不加载”，也不能归因于安全区。

当前Telegram上游存在scene delegate，但不能替代用户安装版本信息。项目不硬编码特定bundle黑名单、不随意接管SpringBoard默认scene、不杀目标进程。新增安装版本、scene manifest/multiple-scenes声明等白名单元数据，自动采集clientDidConnect/contentState和图层登记。attachment及0.5/2/6/12秒定时观察通过generation和closed状态保护；额外content回调去重，总数最多24条。层计数存在不等于首帧或正确像素；不读取图片/聊天内容/完整plist或路径。

按App兼容画布模式通过面板菜单明确重开，目标使用当前系统画布，外窗仍可自由变化但App内尺寸稳定；普通模式仍默认。释放使用现有checked handoff，失败不静默并行创建新目标，锁屏/后台取消。首次复核发现默认新窗放置会改变y位置且丢失最大化/吸附；已改为完整模型传入replacement，挂起目标也在新session ready后重新挂起。

## 半屏与挂起

用户随后报告半屏底边微小操作触发立即变形、标题落入系统下拉区。旧resize began即detach/fitAspect是直接源问题。现在14pt位移前不改模型、不拆吸附，正式转换围绕原frame中心并以safeTop缩小可用范围，普通非全屏标题统一避让顶部。取消仍恢复原模型。

MWWindowParking保存完整模型，state转Parked；view保存guest逻辑尺寸、只缩放呈现，不修改guest scene尺寸。透明UIControl拦截缩略图点击供restore，挂起释放keyboard ownership。面板/标题动作、还原、收纳/关闭和viewport变化配套处理。设置控制全局缩略大小与外形比例，不写入正常窗口frame偏好；固定比例的缩略外形可留边，恢复不沿用缩略尺寸。不是AVPictureInPicture，也不是进程暂停。

扩大复核发现：加载中的B被原应用切换收纳后，晚到ready使它成为Visible但仍detached。挂起入口现在先接回该视图并恢复host visibility，再park；锁屏/隐藏工作台不执行晚到的挂起动作。设备检查补上“收纳中加载完成→面板挂起”的场景，纯C检查不能替代UIKit附着验证。

纯C回归覆盖164pt小画布兼容路径、取消阈值、居中转换/顶部约束、普通/吸附/最大化兼容重开、挂起恢复及关闭不可复活，以及4个窗口/6种比例/小屏横竖屏布局。真实UIKit动作与App显示需设备验证；发布验证记录不将编译通过称为这两款App已修复。
