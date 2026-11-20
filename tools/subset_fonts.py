#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 Noto Serif SC / Noto Sans SC 可变字体裁剪成游戏用的子集（保留字重轴，一个文件覆盖所有字重）。
收字范围：游戏数据与脚本中出现的全部字符 + ASCII + 常用标点符号 + GB2312 一级汉字（3755 个常用字）。
思路参考 Ninefold Gate 的 tools/subset_font.py。新增大量文案后重新运行即可。

用法：python3 tools/subset_fonts.py <NotoSerifSC[wght].ttf> <NotoSansSC[wght].ttf>
输出：godot/assets/fonts/NotoSerifSC-subset.ttf、NotoSansSC-subset.ttf
依赖：pip install fonttools
"""
import json
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "godot" / "assets" / "fonts"
SYMBOLS = "，。！？、：；“”‘’（）【】《》〈〉「」『』…—–·×÷＋－％～　·•→←↑↓↻⌂✓✗»«▶◀■□●○◆◇★☆⚠⚡¥￥≥≤≠±°℃‰"


def game_chars() -> set:
    chars = set(chr(c) for c in range(0x20, 0x7F)) | set(SYMBOLS)
    for b1 in range(0xB0, 0xD8):                    # GB2312 一级汉字
        for b2 in range(0xA1, 0xFF):
            try:
                chars.add(bytes([b1, b2]).decode("gb2312"))
            except UnicodeDecodeError:
                pass

    def walk(v):
        if isinstance(v, str):
            chars.update(v)
        elif isinstance(v, dict):
            for k, x in v.items():
                walk(k)
                walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)

    for p in (ROOT / "data").glob("*.json"):
        walk(json.loads(p.read_text(encoding="utf-8")))
    for ext in ("*.gd", "*.tscn", "*.tres"):
        for p in (ROOT / "godot").rglob(ext):
            if ".godot" not in p.parts and "tests" not in p.parts:
                chars |= set(p.read_text(encoding="utf-8", errors="ignore"))
    return {c for c in chars if c.isprintable() or c == "　"}


def subset_font(src: str, dst: pathlib.Path, text: str) -> None:
    font = TTFont(src)
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.notdef_outline = True
    opts.hinting = False                           # 去掉 hinting 显著减小体积，屏幕显示无明显差别
    sub = subset.Subsetter(opts)
    sub.populate(text=text)
    sub.subset(font)
    font.save(str(dst))


def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    if len(argv) != 2:
        sys.exit(__doc__)
    OUT.mkdir(parents=True, exist_ok=True)
    text = "".join(sorted(game_chars()))
    for src, name in zip(argv, ["NotoSerifSC-subset.ttf", "NotoSansSC-subset.ttf"]):
        dst = OUT / name
        subset_font(src, dst, text)
        cmap = TTFont(str(dst)).getBestCmap()
        missing = [c for c in text if ord(c) not in cmap and c.strip()]
        print(f"{name}: {dst.stat().st_size / 1e6:.1f} MB，收字 {len(text)}，字体中缺 {len(missing)} 个：{''.join(missing)[:80]}")


if __name__ == "__main__":
    main()
