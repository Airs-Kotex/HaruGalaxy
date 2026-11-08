#!/usr/bin/env python3
"""Render the project's geometric vector icon using Cairo (optional art tool)."""
from pathlib import Path
import math
import cairo

ROOT = Path(__file__).resolve().parents[1]


def render(size, name):
    surface = cairo.ImageSurface(cairo.FORMAT_RGB24, size, size)
    ctx = cairo.Context(surface)
    ctx.scale(size / 1024, size / 1024)

    def color(hex_value):
        value = hex_value.lstrip("#")
        ctx.set_source_rgb(*(int(value[i:i+2], 16)/255 for i in (0, 2, 4)))

    def rect(x, y, width, height, radius, fill):
        ctx.new_sub_path()
        for cx, cy, start in [(x+width-radius,y+radius,-90),(x+width-radius,y+height-radius,0),
                              (x+radius,y+height-radius,90),(x+radius,y+radius,180)]:
            ctx.arc(cx, cy, radius, math.radians(start), math.radians(start+90))
        ctx.close_path(); color(fill); ctx.fill()

    color("103f4c"); ctx.paint()
    rect(200,178,502,536,62,"2a6973")
    rect(322,306,502,536,62,"e4faf4")
    color("103f4c"); ctx.set_line_width(16); ctx.move_to(322,424); ctx.line_to(824,424); ctx.stroke()
    for x, fill in [(376,"f3726c"),(426,"e9b452"),(476,"2c9a8b")]:
        color(fill); ctx.arc(x,365,14,0,2*math.pi); ctx.fill()
    color("167c83"); ctx.set_line_width(42); ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.move_to(463,524); ctx.line_to(463,646); ctx.curve_to(463,778,679,778,679,646); ctx.line_to(679,524); ctx.stroke()
    color("b3eae1")
    for i, point in enumerate([(787,156),(803,204),(851,220),(803,236),(787,284),(771,236),(723,220),(771,204)]):
        (ctx.move_to if i==0 else ctx.line_to)(*point)
    ctx.close_path(); ctx.fill()
    surface.write_to_png(str(ROOT / "Resources" / name))


for size, name in [(120,"AppIcon60x60@2x.png"),(180,"AppIcon60x60@3x.png"),
                   (152,"AppIcon76x76@2x.png"),(167,"AppIcon83.5x83.5@2x.png"),(1024,"AppIcon.png")]:
    render(size, name)
