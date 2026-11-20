#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Steam 商店与游戏库美术素材：从标题原画 + 罗盘贴图生成全部规格，输出到 store/steam/
同时生成游戏图标 godot/icon.png 与 godot/icon.ico（桌面版导出用）。
用法：python3 tools/make_steam_assets.py
尺寸以 Steamworks「图形素材」页面的要求为准（2025 年起胶囊图为双倍尺寸）。
"""
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "godot/assets/scenes/title.png"
DIAL = ROOT / "godot/assets/textures/compass_dial.png"
SERIF = ROOT / "godot/assets/fonts/NotoSerifSC-subset.ttf"
OUT = ROOT / "store/steam"
FOCUS = (975, 400)                     # 原画中罗盘中心
GOLD = (214, 178, 106, 255)
PAPER = (246, 240, 226, 255)
INK = (11, 14, 18)


def font(size, weight):
    f = ImageFont.truetype(str(SERIF), size)
    f.set_variation_by_axes([weight])
    return f


def spaced(draw, xy, text, f, fill, sp):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + sp


def spaced_w(draw, text, f, sp):
    return sum(draw.textlength(ch, font=f) for ch in text) + sp * (len(text) - 1)


def logo(english=True) -> Image.Image:
    """标志：商道玄机（金）/ 大亨罗盘（白，大字）/ DYNASTY TYCOON（金），带柔和暗影便于压在原画上"""
    W, H = 2400, 1300
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rows = [("商道玄机", font(150, 700), GOLD, 60, 130),
            ("大亨罗盘", font(400, 900), PAPER, 230, 40)]
    if english:
        rows.append(("DYNASTY TYCOON", font(120, 700), GOLD, 760, 34))
    for text, f, fill, y, sp in rows:
        spaced(d, ((W - spaced_w(d, text, f, sp)) / 2, y), text, f, fill, sp)
    if english:   # 两侧短金线
        y = 830
        tw = spaced_w(d, "DYNASTY TYCOON", rows[2][1], 34)
        d.line([((W - tw) / 2 - 260, y), ((W - tw) / 2 - 60, y)], fill=GOLD, width=8)
        d.line([((W + tw) / 2 + 60, y), ((W + tw) / 2 + 260, y)], fill=GOLD, width=8)
    img = img.crop(img.getbbox())
    pad = 60
    canvas = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste((5, 6, 8, 230), (pad + 8, pad + 12), img.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(img, (pad, pad))
    return canvas


def crop_art(w, h, zoom, fx, fy):
    """按目标比例裁原画，使罗盘尽量落在 (fx, fy) 处；zoom > 1 表示放大（裁得更小）"""
    art = Image.open(ART).convert("RGB")
    ar = w / h
    cw, ch = (art.width, art.width / ar) if ar >= art.width / art.height else (art.height * ar, art.height)
    cw, ch = cw / zoom, ch / zoom
    x0 = min(max(0, FOCUS[0] - fx * cw), art.width - cw)
    y0 = min(max(0, FOCUS[1] - fy * ch), art.height - ch)
    return art.crop((round(x0), round(y0), round(x0 + cw), round(y0 + ch))).resize((w, h), Image.LANCZOS)


def shade(img, kind, strength=235, start=0.45):
    """渐暗：bottom 底部、right 右侧、all 整体"""
    w, h = img.size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    if kind == "all":
        m.paste(strength, (0, 0, w, h))
    else:
        n = h if kind == "bottom" else w
        for i in range(n):
            t = max(0.0, (i - n * start) / (n * (1 - start)))
            v = int(strength * min(1.0, t * 1.25) ** 1.3)
            d.line([(0, i), (w, i)] if kind == "bottom" else [(i, 0), (i, h)], fill=v)
    return Image.composite(Image.new("RGB", (w, h), INK), img, m)


def place_logo(img, box, lg):
    w, h = img.size
    bx, by, bw, bh = box[0] * w, box[1] * h, box[2] * w, box[3] * h
    s = min(bw / lg.width, bh / lg.height)
    l2 = lg.resize((round(lg.width * s), round(lg.height * s)), Image.LANCZOS)
    out = img.convert("RGBA")
    out.alpha_composite(l2, (round(bx + (bw - l2.width) / 2), round(by + (bh - l2.height) / 2)))
    return out.convert("RGB")


def icon(size=1024) -> Image.Image:
    """游戏图标：墨色圆角底 + 金色罗盘盘面 + 朱砂/金色指针"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=size * 0.2, fill=INK + (255,))
    dial = Image.open(DIAL).convert("RGBA").resize((round(size * 0.9), round(size * 0.9)), Image.LANCZOS)
    glow = dial.filter(ImageFilter.GaussianBlur(size * 0.012))
    off = round(size * 0.05)
    img.alpha_composite(glow, (off, off))
    img.alpha_composite(dial, (off, off))
    c = size / 2
    r = size * 0.36
    import math
    a = math.radians(-45)
    tip = (c + r * math.cos(a), c + r * math.sin(a))
    tail = (c - r * math.cos(a), c - r * math.sin(a))
    nx, ny = -math.sin(a) * size * 0.045, math.cos(a) * size * 0.045
    d = ImageDraw.Draw(img)
    d.polygon([tip, (c + nx, c + ny), (c - nx, c - ny)], fill=(196, 52, 40, 255))
    d.polygon([tail, (c + nx, c + ny), (c - nx, c - ny)], fill=GOLD)
    d.ellipse([c - size * 0.045, c - size * 0.045, c + size * 0.045, c + size * 0.045], fill=GOLD, outline=INK, width=round(size * 0.01))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lg = logo()
    lg_cn = logo(english=False)
    specs = {
        # 文件名: (宽, 高, 放大, 罗盘位置x, y, 渐暗, 标志框(x, y, w, h 均为比例), 标志)
        "header_capsule_920x430": (920, 430, 1.45, 0.27, 0.48, "right", (0.47, 0.10, 0.50, 0.80), lg),
        "small_capsule_462x174": (462, 174, 1.3, 0.5, 0.5, "all", (0.04, 0.06, 0.92, 0.88), lg_cn),
        "main_capsule_1232x706": (1232, 706, 1.0, 0.5, 0.37, "bottom", (0.18, 0.56, 0.64, 0.40), lg),
        "vertical_capsule_748x896": (748, 896, 1.15, 0.5, 0.31, "bottom", (0.07, 0.56, 0.86, 0.40), lg),
        "library_capsule_600x900": (600, 900, 1.1, 0.5, 0.30, "bottom", (0.07, 0.58, 0.86, 0.38), lg),
        "library_header_920x430": (920, 430, 1.45, 0.27, 0.48, "right", (0.47, 0.10, 0.50, 0.80), lg),
    }
    for name, (w, h, z, fx, fy, sh, box, l) in specs.items():
        img = crop_art(w, h, z, fx, fy)
        img = shade(img, sh, strength=150 if sh == "all" else 235, start=0.40 if sh == "right" else 0.45)
        place_logo(img, box, l).save(OUT / f"{name}.png", optimize=True)

    # 商店页背景：低对比、去饱和，不放文字
    bg = crop_art(1438, 810, 1.0, 0.5, 0.45)
    bg = Image.blend(bg.convert("L").convert("RGB"), bg, 0.35)
    shade(bg, "all", strength=150).save(OUT / "page_background_1438x810.png", optimize=True)
    # 游戏库主视觉：无文字（Steam 会叠加 library_logo）
    crop_art(3840, 1240, 1.2, 0.62, 0.45).save(OUT / "library_hero_3840x1240.png", optimize=True)
    # 游戏库标志：透明底
    l = lg.copy()
    l.thumbnail((1280, 720), Image.LANCZOS)
    l.save(OUT / "library_logo_1280x720.png", optimize=True)

    ic = icon()
    ic.convert("RGB").resize((184, 184), Image.LANCZOS).save(OUT / "community_icon_184x184.jpg", quality=95)
    ic.resize((256, 256), Image.LANCZOS).save(OUT / "icon_256.png")
    ic.resize((32, 32), Image.LANCZOS).save(OUT / "client_icon_32x32.tga")
    ic.save(OUT / "client_icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    ic.resize((512, 512), Image.LANCZOS).save(ROOT / "godot/icon.png")
    ic.save(ROOT / "godot/icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    for p in sorted(OUT.iterdir()):
        print(p.name, Image.open(p).size)


if __name__ == "__main__":
    main()
