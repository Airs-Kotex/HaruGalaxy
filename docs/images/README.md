# 操作示意图

这里的四张图片由 `scripts/render_guides.py` 确定性绘制，**不是模拟器或真机截图**。每张图自身也带有这一标识。示例应用内容是抽象线条，不来自用户的诊断、聊天、图片或其他 App。

| 图片 | 说明 |
| --- | --- |
| `01-workspace-overview.png` | 半屏顶栏贴边、四处缩放、挂起和边缘管理 |
| `02-window-controls.png` | 四个缩放入口、顶部中央四个按钮和挂起文字入口 |
| `03-parking-guide.png` | 挂起、大小/比例设置、点击还原 |
| `04-compatibility-entry.png` | 面板顶部“原始画布”与应用选择列表 |

图解适当放大控件以便阅读，表现功能关系，不保证所有硬件遮挡、系统手势或第三方应用兼容性。实际实现和版本说明以源代码、README、CHANGELOG为准。今后若加入用户授权的真机截图，应单独标注设备、系统和应用版本，不将本组示意图改称截图。

重建需要 Python、Pillow 和支持中文的字体；安装包构建不需要这些绘图依赖：

```sh
python3 scripts/render_guides.py --font /path/to/NotoSansCJKsc-Regular.otf
```

输出为1600×1000 PNG。生成时使用 [Noto Sans CJK SC](https://github.com/notofonts/noto-cjk)，字体遵循SIL Open Font License，字体文件不随仓库/安装包分发。源字体SHA-256为`2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b`。图解与绘制代码使用本项目Apache-2.0许可。
