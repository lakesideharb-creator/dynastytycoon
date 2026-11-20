#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
立绘去背景工具：把 RGB 立绘转成带透明通道的 PNG（仅依赖 Pillow）

两种模式：
  chroma  纯色背景抠像（推荐）：生成时用品红 #FF00FF 平涂背景，按颜色距离转透明并去溢色
          （不用绿幕：伤门/杜门角色穿绿色，会被一起抠掉）
  paper   宣纸背景抠像（应急）：从画面上沿和两侧向内泛洪填充纸色，只保留最大连通主体
  despill 已经是透明底、但边缘残留品红色晕的图：保留透明通道，只去掉品红溢色
  tile    等轴测 2:1 地砖：把边缘模糊羽化的菱形修成边缘清晰的标准菱形，平铺时不留缝
  beam    由地板砖生成横梁投影砖：沿行方向压暗一条带，相邻横梁砖首尾相接成连续阴影

用法：
  python3 tools/remove_background.py --mode chroma 输入.png [...] --out 输出目录
  python3 tools/remove_background.py --mode paper  输入.png [...] --out 输出目录
"""
import argparse
import math
import os
import sys
from collections import deque

from PIL import Image, ImageChops, ImageDraw, ImageFilter

MARK = (255, 0, 255)


# ─── chroma：纯色背景 ─────────────────────────────────────────────────────────
def chroma_cutout(img: Image.Image, key=(255, 0, 255), inner=70, outer=160, despill=True) -> Image.Image:
    """颜色距离 < inner 完全透明，> outer 完全不透明，之间线性过渡；并压掉主体边缘残留的背景色溢色"""
    rgb = img.convert("RGB")
    out = []
    kr, kg, kb = key
    span = float(outer - inner)
    green_key = kg > kr and kg > kb
    magenta_key = kr > kg and kb > kg
    for r, g, b in rgb.getdata():
        dist = abs(r - kr) + abs(g - kg) + abs(b - kb)
        if dist <= inner:
            a = 0
        elif dist >= outer:
            a = 255
        else:
            a = int(255 * (dist - inner) / span)
        if despill:
            if green_key and g > max(r, b):
                g = max(r, b)
            elif magenta_key and min(r, b) > g:
                excess = min(r, b) - g
                r, b = r - excess, b - excess
        out.append((r, g, b, a))
    res = Image.new("RGBA", rgb.size)
    res.putdata(out)
    return res


def despill_magenta(img: Image.Image, min_excess=25, edges_only=False) -> Image.Image:
    """已抠好的 RGBA：min(R,B) 比 G 高出 min_excess 以上视为品红溢色，压回中性色；唇色等轻微偏粉不受影响。
    edges_only=True 时只处理半透明边缘像素，用于本身带紫色设计的图（如太阴的紫纱）"""
    rgba = img.convert("RGBA")
    out = []
    for r, g, b, a in rgba.getdata():
        excess = min(r, b) - g
        if a and excess > min_excess and (not edges_only or a < 245):
            r, b = r - excess, b - excess
        out.append((r, g, b, a))
    res = Image.new("RGBA", rgba.size)
    res.putdata(out)
    return res


def crisp_iso_tile(img: Image.Image, solid=250) -> Image.Image:
    """
    2:1 等轴测地砖：找到完全不透明的内菱形，按中心等比放大到铺满整个画布菱形，
    再套一个边缘清晰的标准菱形透明通道（4 倍超采样抗锯齿）。纹理只缩放、不改色。
    """
    rgba = img.convert("RGBA")
    w, h = rgba.size
    cy = h // 2
    xs = [x for x in range(w) if rgba.getpixel((x, cy))[3] >= solid]
    if not xs:
        raise ValueError("地砖中心行没有不透明像素")
    inner_half = (xs[-1] - xs[0] + 1) / 2
    k = (w / 2) / inner_half
    big = rgba.resize((round(w * k), round(h * k)), Image.LANCZOS)
    left, top = (big.width - w) // 2, (big.height - h) // 2
    tile = big.crop((left, top, left + w, top + h))

    ss = 4
    mask = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(mask).polygon([(w * ss / 2, 0), (w * ss, h * ss / 2), (w * ss / 2, h * ss), (0, h * ss / 2)], fill=255)
    tile.putalpha(mask.resize((w, h), Image.LANCZOS))
    return tile


def beam_shadow_tile(floor: Image.Image, center=0.5, width=0.45, strength=0.5, along="u") -> Image.Image:
    """
    在 2:1 地砖上叠一条与行方向平行的阴影带。地砖局部坐标：上顶点 (u,v)=(0,0)，右顶点 (1,0)，左顶点 (0,1)。
    along="u"：阴影沿 u 方向延伸（横梁沿网格 x 方向，对应 office_fengshui 的 beam_rows），只随 v 变化，
    所以同一行的横梁砖无论怎么排都严丝合缝。
    """
    rgba = floor.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not a:
                continue
            u = ((x - w / 2) / (w / 2) + y / (h / 2)) / 2
            v = (y / (h / 2) - (x - w / 2) / (w / 2)) / 2
            t = v if along == "u" else u
            d = abs(t - center) / (width / 2)
            if d < 1:
                k = 1 - strength * (0.5 + 0.5 * math.cos(math.pi * d))
                px[x, y] = (int(r * k), int(g * k), int(b * k), a)
    return rgba


def magenta_residue(img: Image.Image, min_excess=60) -> int:
    """统计不透明像素中明显偏品红的数量（验收用）"""
    return sum(1 for r, g, b, a in img.convert("RGBA").getdata() if a > 40 and r > g + min_excess and b > g + min_excess)


# ─── paper：宣纸背景 ──────────────────────────────────────────────────────────
def _is_paper(px, ref, tol):
    return sum(abs(px[i] - ref[i]) for i in range(3)) <= tol


def _paper_reference(rgb: Image.Image):
    """取画面上沿一排像素的中位数作为纸色"""
    w, _ = rgb.size
    row = [rgb.getpixel((x, 2)) for x in range(0, w, 4)]
    return tuple(sorted(c[i] for c in row)[len(row) // 2] for i in range(3))


def _largest_component(mask: Image.Image) -> Image.Image:
    """mask: L 模式，255=主体。只保留最大的 4 连通区域（去掉孤立墨点）"""
    w, h = mask.size
    px = mask.load()
    seen = bytearray(w * h)
    best = []
    for sy in range(h):
        for sx in range(w):
            idx = sy * w + sx
            if seen[idx] or px[sx, sy] == 0:
                continue
            comp, q = [], deque([(sx, sy)])
            seen[idx] = 1
            while q:
                x, y = q.popleft()
                comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        n = ny * w + nx
                        if not seen[n] and px[nx, ny]:
                            seen[n] = 1
                            q.append((nx, ny))
            if len(comp) > len(best):
                best = comp
    out = Image.new("L", mask.size, 0)
    op = out.load()
    for x, y in best:
        op[x, y] = 255
    return out


def trim_protrusions(cut: Image.Image, size: int) -> Image.Image:
    """形态学开运算：去掉宽度小于 size 像素、粘在主体边缘的细碎墨点（size 过大会削掉手指）"""
    a = cut.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    core = a.filter(ImageFilter.MinFilter(size)).filter(ImageFilter.MaxFilter(size))
    small = core.resize((256, 256), Image.NEAREST)
    core = _largest_component(small).resize(a.size, Image.NEAREST)
    core = core.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2))
    out = cut.copy()
    out.putalpha(ImageChops.multiply(cut.getchannel("A"), core))
    return out


def paper_cutout(img: Image.Image, thresh=70, side_limit=0.55, feather=1.2, step=16, trim=0) -> Image.Image:
    """
    thresh      泛洪容差（RGB 三通道差值之和）
    side_limit  左右两侧只在上方这个比例内取种子，避免从被画框裁切的衣服处灌入
    """
    rgb = img.convert("RGB")
    w, h = rgb.size
    ref = _paper_reference(rgb)
    work = rgb.copy()
    seeds = [(x, 0) for x in range(0, w, step)]
    seeds += [(0, y) for y in range(0, int(h * side_limit), step)]
    seeds += [(w - 1, y) for y in range(0, int(h * side_limit), step)]
    for sx, sy in seeds:
        px = work.getpixel((sx, sy))
        if px != MARK and _is_paper(px, ref, thresh):
            ImageDraw.floodfill(work, (sx, sy), MARK, thresh=thresh)

    # 主体 = 未被填充的像素；随后去掉孤立墨点
    subject = Image.new("L", (w, h), 0)
    wp, sp = work.load(), subject.load()
    for y in range(h):
        for x in range(w):
            if wp[x, y] != MARK:
                sp[x, y] = 255
    subject = _largest_component(subject)

    # 羽化边缘：先收缩 1 像素去掉纸色描边，再轻微模糊
    alpha = subject.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(feather))
    res = rgb.convert("RGBA")
    res.putalpha(alpha)
    return trim_protrusions(res, trim) if trim else res


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("inputs", nargs="+")
    ap.add_argument("--mode", choices=["chroma", "paper", "despill", "tile", "beam"], required=True)
    ap.add_argument("--out", required=True, help="输出目录（文件名不变）")
    ap.add_argument("--key", default="FF00FF", help="chroma 模式的背景色，十六进制，默认品红 FF00FF")
    ap.add_argument("--thresh", type=int, default=70, help="paper 模式的泛洪容差")
    ap.add_argument("--edges-only", action="store_true", help="despill 模式：只处理半透明边缘（图里本来就有紫色时使用）")
    ap.add_argument("--trim", type=int, default=0, help="paper 模式：去掉宽度小于该像素的粘连墨点（1024 立绘建议 31；会连同发簪等细长道具一起削掉，只对有粘连墨点的图使用）")
    args = ap.parse_args(argv)

    os.makedirs(args.out, exist_ok=True)
    key = tuple(int(args.key[i:i + 2], 16) for i in (0, 2, 4))
    for path in args.inputs:
        img = Image.open(path)
        if args.mode == "chroma":
            res = chroma_cutout(img, key=key)
        elif args.mode == "despill":
            res = despill_magenta(img, edges_only=args.edges_only)
        elif args.mode == "tile":
            res = crisp_iso_tile(img)
        elif args.mode == "beam":
            res = beam_shadow_tile(img)
        else:
            res = paper_cutout(img, thresh=args.thresh, trim=args.trim)
        dst = os.path.join(args.out, os.path.basename(path))
        res.save(dst)
        opaque = sum(1 for a in res.getchannel("A").getdata() if a > 0) / (res.width * res.height)
        print(f"{dst}  主体占比 {opaque:.0%}  品红残留 {magenta_residue(res)}")


if __name__ == "__main__":
    sys.exit(main())
