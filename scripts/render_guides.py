#!/usr/bin/env python3
"""Draw honest operation diagrams for README; these are NOT simulator screenshots.

Optional documentation tool: Pillow and a CJK font are required.
Usage: python3 scripts/render_guides.py --font /path/to/NotoSansCJKsc-Regular.otf
"""
import argparse
from functools import lru_cache
from pathlib import Path
import plistlib

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
W, H, SCALE = 1600, 1000, 2
BG, INK, MUTED = "#f3f6f2", "#153e48", "#58727a"
TEAL, ORANGE, BLUE, RED, GREEN = "#13878b", "#c27b25", "#3b78bd", "#cd5960", "#2a9271"
WHITE, LINE = "#ffffff", "#cbdad7"


class Diagram:
    def __init__(self, font, index, title, subtitle):
        self.font_path = str(font)
        self.image = Image.new("RGB", (W * SCALE, H * SCALE), BG)
        self.draw = ImageDraw.Draw(self.image)
        self.rect(0, 0, W, 14, TEAL)
        self.text(64, 43, f"HARUGALAXY / 初春星河        操作图解 {index}", 20, TEAL)
        self.text(64, 92, title, 46, INK)
        self.text(66, 160, subtitle, 22, MUTED)
        self.line([(64, 206), (1536, 206)], LINE, 1)

    @lru_cache(maxsize=20)
    def font(self, size):
        return ImageFont.truetype(self.font_path, round(size * SCALE))

    def text(self, x, y, value, size=24, color=INK, anchor="lt"):
        self.draw.text((round(x * SCALE), round(y * SCALE)), value,
                       font=self.font(size), fill=color, anchor=anchor)

    def rect(self, x, y, w, h, color, radius=0, outline=None, width=1):
        box = tuple(round(v * SCALE) for v in (x, y, x + w, y + h))
        if radius:
            self.draw.rounded_rectangle(box, round(radius * SCALE), fill=color,
                                        outline=outline, width=round(width * SCALE))
        else:
            self.draw.rectangle(box, fill=color, outline=outline, width=round(width * SCALE))

    def line(self, points, color=TEAL, width=2):
        self.draw.line([(round(x * SCALE), round(y * SCALE)) for x, y in points],
                       fill=color, width=round(width * SCALE), joint="curve")

    def circle(self, x, y, r, color, outline=None, width=1):
        self.draw.ellipse(tuple(round(v * SCALE) for v in (x-r, y-r, x+r, y+r)),
                          fill=color, outline=outline, width=round(width*SCALE))

    def arrow(self, points, color=TEAL, width=3):
        self.line(points, color, width)
        x, y = points[-1]
        px, py = points[-2]
        import math
        angle = math.atan2(y-py, x-px)
        self.line([(x-12*math.cos(angle-0.5), y-12*math.sin(angle-0.5)),
                   (x, y),
                   (x-12*math.cos(angle+0.5), y-12*math.sin(angle+0.5))], color, width)

    def controls(self, x, y, w, unit=22, parked=False):
        colors = [RED, ORANGE, GREEN, BLUE]
        start = x + w/2 - unit*2
        centers = []
        for i, color in enumerate(colors):
            cx, cy = start + unit*(i+0.5), y
            centers.append((cx, cy))
            r = unit*0.2
            if i == 0:
                self.line([(cx-r, cy-r), (cx+r, cy+r)], color, 2)
                self.line([(cx+r, cy-r), (cx-r, cy+r)], color, 2)
            elif i == 1:
                self.line([(cx-r, cy), (cx+r, cy)], color, 2)
            elif i == 2:
                self.rect(cx-r, cy-r, r*2, r*2, None, 1, color, 2)
            else:
                self.rect(cx-r*1.4, cy-r, r*2.8, r*2, None, 1, color, 2)
                self.rect(cx, cy, r*1.1, r*0.8, color, 1)
        return centers

    def window(self, x, y, w, h, sample="示例应用", color="#e7f2ed", factor=1):
        header, rail = 28*factor, 8*factor
        self.rect(x+3, y+7, w, h, "#dae4df", 16)
        self.rect(x, y, w, h, WHITE, 14, LINE)
        self.rect(x+1, y+1, w-2, header, "#e4eee8", 8)
        centers = self.controls(x, y+header/2, w, unit=28*factor)
        self.line([(x+12, y+header*0.7), (x+12, y+header*0.3), (x+20, y+header*0.3)], TEAL, 2)
        self.line([(x+w-20, y+header*0.3), (x+w-12, y+header*0.3), (x+w-12, y+header*0.7)], ORANGE, 2)
        self.rect(x+1, y+header+1, w-2, h-header-rail-2, color)
        self.rect(x+1, y+h-rail, w-2, rail-1, "#edf2ed")
        self.line([(x+w*0.25-11, y+h-rail/2), (x+w*0.25+11, y+h-rail/2)], ORANGE, 2)
        self.line([(x+w*0.75-11, y+h-rail/2), (x+w*0.75+11, y+h-rail/2)], TEAL, 2)
        self.text(x+24, y+header+24, sample, min(24, w/13), INK)
        for n, fraction in enumerate((0.72, 0.87, 0.58)):
            yy = y+header+70+n*22
            if yy+8 < y+h-rail-16:
                self.rect(x+24, yy, (w-48)*fraction, 7, "#b8cfc7", 3)
        return centers

    def step(self, x, y, number, title):
        self.circle(x+19, y+19, 19, TEAL)
        self.text(x+19, y+19, number, 20, WHITE, "mm")
        self.text(x+52, y+2, title, 27)

    def footer(self, note):
        self.line([(64, 912), (1536, 912)], LINE, 1)
        self.text(64, 938, "操作示意图 · 非真机截图 / ILLUSTRATION, NOT A SCREENSHOT", 18, TEAL)
        self.text(64, 967, note, 16, MUTED)

    def save(self, name):
        path = ROOT / "docs/images" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        self.image.resize((W, H), Image.Resampling.LANCZOS).save(path, optimize=True)
        print(path.relative_to(ROOT))


def overview(font):
    d = Diagram(font, "01", "一屏协作，窗口各得其所", "上下半屏、自由缩放、边缘管理与挂起，围绕同一套窗口操作。")
    x, y, w, h = 100, 248, 370, 620
    d.rect(x-12, y-12, w+24, h+24, INK, 28)
    d.window(x, y, w, h/2, "示例应用 A · 阅读", "#edf2df")
    d.window(x, y+h/2, w, h/2, "示例应用 B · 记录", "#e2efee")
    d.rect(x+w-12, y+210, 12, 54, TEAL, 6)
    d.rect(100, 212, 188, 28, TEAL, 14)
    d.text(194, 226, "顶栏贴半屏上沿", 16, WHITE, "mm")
    items = [
        ("01", "半屏铺满", "吸附后从半屏上沿开始排布，取消额外的顶部留白。"),
        ("02", "四处缩放", "左上 / 右下等比；右上 / 左下自由。轻点不改形。"),
        ("03", "随时挂起", "右上角保留缩略窗，点击恢复先前的位置和比例。"),
        ("04", "边缘管理", "收纳、还原、关闭与挂起设置，都从面板进入。"),
    ]
    for i, (num, title, body) in enumerate(items):
        yy = 280+i*143
        d.text(580, yy, num, 22, TEAL)
        d.text(642, yy-4, title, 30)
        d.text(642, yy+45, body, 21, MUTED)
        if i < 3:
            d.line([(642, yy+108), (1488, yy+108)], LINE, 1)
    d.footer("示例内容仅用于说明布局。实际画面受目标 App、系统手势与屏幕物理遮挡影响。")
    d.save("01-workspace-overview.png")


def controls(font):
    d = Diagram(font, "02", "四处缩放，一眼找到操作", "顶部只放四个居中按钮；底边左右分区，内容区域独立。")
    x, y, w, h = 380, 326, 840, 430
    centers = d.window(x, y, w, h, "应用内容 · 操作区域不被透明控件覆盖", "#e8efeb", factor=1.7)
    labels = ["关闭", "最小化", "最大化", "挂起"]
    for (cx, cy), label, color, label_x in zip(centers, labels, [RED, ORANGE, GREEN, BLUE], [620,740,860,980]):
        d.line([(cx, cy-14), (cx, 309), (label_x, 284)], color, 2)
        d.text(label_x, 264, label, 20, color, "mm")
    d.text(800, 592, "进入等比：先缩入原窗口范围", 28, INK, "mm")
    d.text(800, 639, "明确拖动后再调整，轻点保持原布局", 21, MUTED, "mm")
    for title, mode, px, py, side, color, point in [
        ("左上角", "等比缩放", 70, 340, "left", TEAL, (x+16, y+20)),
        ("右上角", "自由缩放", 1270, 340, "right", ORANGE, (x+w-16, y+20)),
        ("左下半边", "自由缩放", 70, 688, "left", ORANGE, (x+w*0.25, y+h-7)),
        ("右下半边", "等比缩放", 1270, 688, "right", TEAL, (x+w*0.75, y+h-7)),
    ]:
        d.text(px, py, title, 26, color)
        d.text(px, py+42, mode, 21, MUTED)
        if side == "left":
            d.arrow([(px+192, py+27), (x-30, py+27), point], color, 2)
        else:
            d.arrow([(px-18, py+27), (x+w+26, py+27), point], color, 2)
    d.rect(380, 800, 840, 58, "#e0ece6", 12)
    d.text(800, 829, "挂起找不到？面板中有“挂起 / 还原”和“挂起设置”文字入口", 20, INK, "mm")
    d.footer("控件在图中适当放大以便阅读。示意不代表真机触摸或第三方 App 的兼容性已验证。")
    d.save("02-window-controls.png")


def parking(font):
    d = Diagram(font, "03", "缩到一角，点一下还原", "挂起保留会话；缩略窗大小与外形比例，不会改写原窗口的恢复状态。")
    d.step(64, 238, "1", "点击蓝色挂起按钮")
    d.step(568, 238, "2", "右上角保留缩略窗")
    d.step(1072, 238, "3", "设置外形，点击还原")
    centers = d.window(80, 322, 410, 470, "示例应用 · 当前页面", "#e5efe6")
    d.circle(*centers[-1], 18, None, BLUE, 2)
    d.rect(584, 322, 410, 470, "#e4eeea", 18, LINE)
    d.text(610, 568, "桌面 / 其他应用区域", 22, MUTED)
    d.rect(828, 344, 140, 198, WHITE, 12, TEAL, 2)
    d.rect(838, 358, 120, 166, "#cde3db", 6)
    d.text(898, 430, "挂起画面", 20, INK, "mm")
    d.text(898, 465, "点击还原", 17, TEAL, "mm")
    d.arrow([(507, 525), (555, 525)], TEAL, 3)
    d.rect(1088, 322, 438, 470, WHITE, 18, LINE)
    d.text(1114, 349, "挂起小窗设置", 26)
    d.line([(1114, 402), (1498, 402)], LINE, 1)
    d.text(1114, 430, "大小", 22)
    d.text(1498, 432, "18% – 50%", 20, TEAL, "rt")
    d.line([(1120, 494), (1490, 494)], "#c9d9d1", 6)
    d.line([(1120, 494), (1320, 494)], TEAL, 6)
    d.circle(1320, 494, 12, WHITE, TEAL, 2)
    d.text(1114, 540, "外形比例", 22)
    values = ["跟随原窗", "1:1", "4:3", "3:4", "16:9", "9:16"]
    for i, value in enumerate(values):
        xx, yy = 1112+(i%3)*128, 593+(i//3)*60
        active = i == 0
        d.rect(xx, yy, 116, 44, TEAL if active else "#edf2ed", 8)
        d.text(xx+58, yy+22, value, 18, WHITE if active else MUTED, "mm")
    d.text(1114, 736, "入口：窗口面板 → 挂起设置", 19, MUTED)
    d.text(285, 832, "位置 / 尺寸 / 缩放模式都会记住", 21, MUTED, "mm")
    d.text(789, 832, "点击缩略窗，恢复挂起前的状态", 21, TEAL, "mm")
    d.footer("挂起是缩略显示，不是暂停应用进程，也不是系统视频画中画。示例内容不来自真实 App。")
    d.save("03-parking-guide.png")


def compatibility(font):
    d = Diagram(font, "04", "原始画布，现在直接可见", "无需先找省略号：打开边缘面板，点击顶部“原始画布”。")
    d.step(64, 238, "1", "打开窗口面板")
    d.step(598, 238, "2", "点击“原始画布”")
    d.step(1120, 238, "3", "选择需要重开的 App")
    d.rect(76, 328, 422, 484, WHITE, 24, LINE)
    d.text(104, 358, "窗口面板", 28)
    for i, title in enumerate(["打开应用", "挂起设置", "原始画布"]):
        xx = 94+i*128
        d.rect(xx, 423, 122, 50, TEAL if i == 2 else "#edf2ed", 8)
        d.text(xx+61, 448, title, 20, WHITE if i == 2 else INK, "mm")
    d.rect(98, 502, 378, 132, "#edf2ed", 16)
    d.text(120, 524, "示例应用 A", 24)
    d.text(120, 570, "收纳    全屏    挂起    关闭", 20, MUTED)
    d.rect(98, 657, 378, 132, "#edf2ed", 16)
    d.text(120, 679, "示例应用 B", 24)
    d.text(120, 725, "收纳    全屏    挂起    关闭", 20, MUTED)
    d.arrow([(511, 553), (563, 553)], TEAL, 3)
    d.rect(598, 328, 432, 484, WHITE, 24, LINE)
    d.text(624, 356, "原始画布", 28)
    d.text(624, 410, "点选一个窗口进行切换", 19, MUTED)
    d.rect(618, 464, 392, 122, "#e0eee7", 12, TEAL)
    d.text(640, 485, "示例应用 A", 23)
    d.text(640, 529, "原始画布并重新打开", 22, TEAL)
    d.rect(618, 610, 392, 143, "#edf2ed", 12)
    d.text(640, 632, "示例应用 B", 23)
    d.text(640, 676, "当前为原始画布", 19, MUTED)
    d.text(640, 707, "点此切回普通并重新打开", 19, TEAL)
    d.text(1116, 382, "使用系统原始画布", 27)
    d.text(1116, 432, "外窗可自由改变尺寸，", 22, MUTED)
    d.text(1116, 470, "内容保持等比缩放。", 22, MUTED)
    d.line([(1116, 535), (1520, 535)], LINE, 1)
    d.text(1116, 578, "切换会重开该小窗", 27)
    d.text(1116, 628, "页面或表单可能重置，", 22, MUTED)
    d.text(1116, 666, "外窗布局会保留。", 22, MUTED)
    d.text(800, 858, "如果列表为空，请先从窗口面板打开一个应用。", 22, MUTED, "mm")
    d.footer("原始画布仅调整内容尺寸；不能修复键盘、未提交图层或图片加载问题。")
    d.save("04-compatibility-entry.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--font", type=Path, default=ROOT/".toolchain/NotoSansCJKsc-Regular.otf")
    args = parser.parse_args()
    if not args.font.is_file():
        parser.error("Provide an installed CJK font with --font. See docs/images/README.md.")
    # Derive the product identity from the repository, never a captured screen.
    assert plistlib.loads((ROOT/"Resources/Info.plist").read_bytes())["CFBundleDisplayName"] == "初春星河"
    for draw in (overview, controls, parking, compatibility):
        draw(args.font)


if __name__ == "__main__":
    main()
