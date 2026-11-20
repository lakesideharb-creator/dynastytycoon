#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
itch.io 封面图：标题画面原画 + 中英文标题，输出 store/cover.png（630×500）与 store/cover@2x.png（1260×1000）
用法：python3 tools/make_cover.py
"""
import pathlib
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "godot/assets/scenes/title.png"
SERIF = ROOT / "godot/assets/fonts/NotoSerifSC-subset.ttf"
SANS = ROOT / "godot/assets/fonts/NotoSansSC-subset.ttf"
OUT = ROOT / "store"
W, H = 1260, 1000
GOLD = (214, 178, 106)


def font(path, size, weight):
    f = ImageFont.truetype(str(path), size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def centered(draw, y, text, f, fill, shadow=None, spacing=0):
    w = draw.textlength(text, font=f) + spacing * (len(text) - 1)
    x = (W - w) / 2
    for ch in text:
        if shadow:
            draw.text((x + 3, y + 4), ch, font=f, fill=shadow)
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + spacing


def main():
    art = Image.open(ART).convert("RGB")
    ch = 1000                                    # 裁出以罗盘为中心、630:500 比例的区域
    cw = round(ch * W / H)
    cx, top = 975, 0
    art = art.crop((cx - cw // 2, top, cx + cw // 2, top + ch)).resize((W, H), Image.LANCZOS)

    shade = Image.new("L", (W, H), 0)            # 底部渐暗，托住标题文字
    d = ImageDraw.Draw(shade)
    for y in range(H):
        t = max(0.0, (y - H * 0.50) / (H * 0.50))
        d.line([(0, y), (W, y)], fill=int(235 * min(1.0, t * 1.15) ** 1.4))
    dark = Image.new("RGB", (W, H), (11, 14, 18))
    img = Image.composite(dark, art, shade)

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    title = "商道玄机·大亨罗盘"
    f_title = font(SERIF, 112, 900)
    centered(gd, 640, title, f_title, (0, 0, 0, 200))
    glow = glow.filter(ImageFilter.GaussianBlur(14))
    img = Image.alpha_composite(img.convert("RGBA"), glow)

    draw = ImageDraw.Draw(img)
    centered(draw, 640, title, f_title, (246, 240, 226), shadow=(20, 16, 12))
    centered(draw, 800, "DYNASTY TYCOON", font(SERIF, 46, 700), GOLD, spacing=14)
    centered(draw, 880, "天时 · 地利 · 人和 —— 以奇门之术经营商海", font(SANS, 36, 500), (226, 220, 206))

    OUT.mkdir(exist_ok=True)
    img = img.convert("RGB")
    img.save(OUT / "cover@2x.png", optimize=True)
    img.resize((630, 500), Image.LANCZOS).save(OUT / "cover.png", optimize=True)
    print("已输出", OUT / "cover.png", OUT / "cover@2x.png")


if __name__ == "__main__":
    main()
