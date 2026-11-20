#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
宣传片剪辑：把 Godot Movie Maker 录下的真实游戏画面（tests/record_trailer.gd）按音乐节拍剪成约 54 秒的中文宣传片。
音乐用 season_summer_fire（琵琶 + 框鼓 + trap 镲，110 BPM），从 87.4 秒的鼓点间奏起，
122.3 秒处的「静音 → 爆发」对应片中的「你，能否通关？」→ 快切。

用法：
  1. 录素材：godot --path godot --resolution 1920x1080 --fixed-fps 30 --write-movie <工作目录>/raw.avi res://tests/record_trailer.tscn
  2. 剪辑：python3 tools/make_trailer.py <工作目录>
输出：store/trailer.mp4（1920×1080，30fps，H.264 + AAC）
"""
import pathlib
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
SERIF = ROOT / "godot/assets/fonts/NotoSerifSC-subset.ttf"
SANS = ROOT / "godot/assets/fonts/NotoSansSC-subset.ttf"
TITLE_ART = ROOT / "godot/assets/scenes/title.png"
MUSIC = ROOT / "godot/assets/music/season_summer_fire.ogg"
MUSIC_START = 87.4
FPS = 30
W, H = 1920, 1080
BEAT = 60 / 110
BAR = BEAT * 4
GOLD = (214, 178, 106, 255)
PAPER = (246, 240, 226, 255)

# 片段：(类型, 片长, 参数)。gameplay 的 src 是素材 raw.avi 中的起点（秒），对应 record_trailer 打印的 MARK
DROP = 34.9                                     # 音乐爆发点（122.3 - 87.4）
TIMELINE = [
    ("intro", 8.7, {}),
    ("game", 2 * BAR, {"src": 4.3, "cap": ("三个真实商战案例", "选址 · 融资 · 团队，开局一念定乾坤")}),
    ("game", 2 * BAR, {"src": 9.0, "cap": ("读懂天时", "大运 · 节气 · 日辰，每月盈亏逐项拆解")}),
    ("game", 1 * BAR, {"src": 14.2, "cap": ("每个抉择 都有后果", "董事会紧急议题，有的当月见效，有的数月后才显现")}),
    ("game", 3 * BAR, {"src": 21.4, "cap": ("调理地利", "破解穿堂煞，总部风水 5 → 100")}),
    ("game", 1 * BAR, {"src": 61.0, "cap": ("求得人和", "八门归位，化解高管内耗")}),
    ("game", None, {"src": 36.0, "cap": ("十二个月", "把账面现金做到 1.35 亿")}),   # 片长补到静音点
    ("gap", None, {}),                                                               # 补到 DROP
    ("flash", BEAT * 2, {"src": 52.4}),
    ("flash", BEAT * 2, {"src": 58.4}),
    ("flash", BEAT * 2, {"src": 40.6}),
    ("flash", BEAT * 2, {"src": 24.4}),
    ("flash", BEAT * 2, {"src": 44.9}),
    ("game", BEAT * 6, {"src": 47.95, "zoom": 0.05}),   # 通关画面只有约 4 秒素材
    ("outro", 10.39, {}),
]


def font(path, size, weight):
    f = ImageFont.truetype(str(path), size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def check_glyphs(texts):
    for path in (SERIF, SANS):
        cmap = TTFont(str(path)).getBestCmap()
        missing = {c for t in texts for c in t if c.strip() and ord(c) not in cmap}
        if missing:
            sys.exit(f"{path.name} 缺字：{''.join(sorted(missing))}，请先运行 tools/subset_fonts.py 收入这些字")


def text_w(draw, text, f, spacing=0):
    return draw.textlength(text, font=f) + spacing * max(0, len(text) - 1)


def draw_text(draw, xy, text, f, fill, spacing=0, shadow=True):
    x, y = xy
    for ch in text:
        if shadow:
            draw.text((x + 3, y + 4), ch, font=f, fill=(0, 0, 0, 200))
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + spacing


def caption_png(path, title, sub):
    """字幕条：底部渐暗 + 左侧金线 + 大标题 + 小字说明"""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(H - 360, H):
        a = int(240 * min(1.0, (y - (H - 360)) / 250) ** 1.2)
        d.line([(0, y), (W, y)], fill=(8, 10, 14, a))
    d.rectangle([110, 846, 118, 1000], fill=GOLD)
    draw_text(d, (150, 830), title, font(SERIF, 88, 900), PAPER, spacing=6)
    draw_text(d, (154, 950), sub, font(SANS, 36, 500), GOLD)
    img.save(path)


def center_png(path, lines, dim=0):
    """居中大字：lines = [(文字, 字体, 颜色, y, 字距)]"""
    img = Image.new("RGBA", (W, H), (0, 0, 0, dim))
    d = ImageDraw.Draw(img)
    for text, f, fill, y, sp in lines:
        draw_text(d, ((W - text_w(d, text, f, sp)) / 2, y), text, f, fill, spacing=sp)
    img.save(path)


def run(args):
    r = subprocess.run(["ffmpeg", "-v", "error", "-y", *args])
    if r.returncode:
        sys.exit("ffmpeg 失败：" + " ".join(map(str, args)))


ENC = ["-c:v", "libx264", "-preset", "medium", "-crf", "15", "-pix_fmt", "yuv420p", "-r", str(FPS)]


def zoom_filter(dur, z):
    return (f"scale=w='trunc({W}*(1+{z}*t/{dur:.3f})/2)*2':h=-2:eval=frame,crop={W}:{H},setsar=1")


def make_game(work, i, raw, dur, frames, p, flash=False):
    out = work / f"clip_{i:02d}.mp4"
    z = p.get("zoom", 0.06 if flash else 0.035)
    vf = zoom_filter(dur, z)
    if flash:
        vf += ",fade=in:st=0:d=0.18:color=white"
    else:
        vf += ",fade=in:st=0:d=0.12"
    if "cap" in p:
        cap = work / f"cap_{i:02d}.png"
        caption_png(cap, *p["cap"])
        fc = (f"[0:v]{vf}[v];[1:v]format=rgba,fade=in:st=0.15:d=0.35:alpha=1[c];[v][c]overlay=0:0[o]")
        run(["-ss", f"{p['src']:.3f}", "-i", str(raw), "-loop", "1", "-i", str(cap),
             "-filter_complex", fc, "-map", "[o]", "-frames:v", str(frames), *ENC, str(out)])
    else:
        run(["-ss", f"{p['src']:.3f}", "-i", str(raw), "-vf", vf, "-frames:v", str(frames), *ENC, str(out)])
    return out


def make_intro(work, dur, frames):
    """片头：标题原画缓推 + 随鼓点依次出现「天时 / 地利 / 人和」与口号"""
    big = font(SERIF, 150, 900)
    mid = font(SERIF, 92, 900)
    layers = [   # (文件, 出现, 消失)
        ("i_tian", [("天时", big, PAPER, 380, 30)], 0.5, 4.75),
        ("i_di", [("地利", big, PAPER, 380, 30)], 1.6, 4.75),
        ("i_ren", [("人和", big, PAPER, 380, 30)], 2.7, 4.75),
        ("i_s1", [("一面罗盘", mid, GOLD, 360, 24)], 4.9, 8.7),
        ("i_s2", [("决胜商海", mid, PAPER, 520, 24)], 6.0, 8.7),
    ]
    # 三个词并排：分别画在左、中、右
    offs = {"i_tian": -560, "i_di": 0, "i_ren": 560}
    inputs, fc = [], []
    for k, (name, lines, t0, t1) in enumerate(layers):
        path = work / f"{name}.png"
        if name in offs:
            img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            d = ImageDraw.Draw(img)
            text, f, fill, y, sp = lines[0]
            draw_text(d, ((W - text_w(d, text, f, sp)) / 2 + offs[name], y), text, f, fill, spacing=sp)
            img.save(path)
        else:
            center_png(path, lines)
        inputs += ["-loop", "1", "-i", str(path)]
        fc.append(f"[{k + 1}:v]format=rgba,fade=in:st={t0}:d=0.18:alpha=1,fade=out:st={t1 - 0.25}:d=0.25:alpha=1[l{k}]")
    fc.insert(0, f"[0:v]{zoom_filter(dur, 0.14)},eq=brightness=-0.32:saturation=0.85,fade=in:st=0:d=0.5[b]")
    chain = "[b]"
    for k in range(len(layers)):
        nxt = f"[o{k}]"
        fc.append(f"{chain}[l{k}]overlay=0:0{nxt}")
        chain = nxt
    fc.append(f"{chain}fade=out:st={dur - 0.2}:d=0.2:color=white[out]")
    out = work / "clip_00.mp4"
    run(["-loop", "1", "-i", str(TITLE_ART), *inputs, "-filter_complex", ";".join(fc), "-map", "[out]",
         "-frames:v", str(frames), *ENC, str(out)])
    return out


def make_gap(work, i, dur, frames):
    path = work / "gap.png"
    center_png(path, [("你，能否通关？", font(SERIF, 110, 900), PAPER, 450, 16)])
    out = work / f"clip_{i:02d}.mp4"
    run(["-f", "lavfi", "-i", f"color=c=0x0B0E12:s={W}x{H}:r={FPS}", "-loop", "1", "-i", str(path),
         "-filter_complex", "[1:v]format=rgba,fade=in:st=0.1:d=0.5:alpha=1[t];[0:v][t]overlay=0:0,scale=1920:1080:eval=frame[o]",
         "-map", "[o]", "-frames:v", str(frames), *ENC, str(out)])
    return out


def make_outro(work, i, dur, frames):
    path = work / "outro.png"
    center_png(path, [
        ("商道玄机·大亨罗盘", font(SERIF, 132, 900), PAPER, 330, 8),
        ("DYNASTY  TYCOON", font(SERIF, 54, 700), GOLD, 520, 16),
        ("天时 · 地利 · 人和 —— 以奇门之术经营商海", font(SANS, 40, 500), PAPER, 630, 0),
        ("itch.io 网页版 · 免费试玩", font(SERIF, 52, 700), GOLD, 800, 6),
        ("lakesideharb.itch.io/dynasty-tycoon", font(SANS, 34, 400), PAPER, 885, 2),
    ], dim=120)
    out = work / f"clip_{i:02d}.mp4"
    fc = (f"[0:v]{zoom_filter(dur, 0.08)},eq=brightness=-0.18,fade=in:st=0:d=0.25:color=white[b];"
          f"[1:v]format=rgba,fade=in:st=0.3:d=0.8:alpha=1[t];[b][t]overlay=0:0,fade=out:st={dur - 1.2}:d=1.2[o]")
    run(["-loop", "1", "-i", str(TITLE_ART), "-loop", "1", "-i", str(path), "-filter_complex", fc,
         "-map", "[o]", "-frames:v", str(frames), *ENC, str(out)])
    return out


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    work = pathlib.Path(sys.argv[1]).resolve()
    raw = work / "raw.avi"
    texts = ["天时地利人和一面罗盘决胜商海你，能否通关？商道玄机·大亨罗盘DYNASTYTYCOON —以奇门之术经营网页版免费试玩"]
    texts += [a + b for k, d, p in TIMELINE if "cap" in p for a, b in [p["cap"]]]
    check_glyphs(texts)

    # 片长：两个 None 分别补到静音点与爆发点
    silence = 120.2 - MUSIC_START
    durs, t = [], 0.0
    for kind, dur, p in TIMELINE:
        if dur is None:
            dur = (silence if kind == "game" else DROP) - t
        durs.append(dur)
        t += dur
    total = t
    clips, t = [], 0.0
    for i, ((kind, _, p), dur) in enumerate(zip(TIMELINE, durs)):
        frames = round((t + dur) * FPS) - round(t * FPS)
        print(f"{i:02d} {kind:<6} {t:6.2f}s +{dur:5.2f}s  {p.get('cap', ('',))[0]}")
        if kind == "intro":
            clips.append(make_intro(work, dur, frames))
        elif kind == "game":
            clips.append(make_game(work, i, raw, dur, frames, p))
        elif kind == "flash":
            clips.append(make_game(work, i, raw, dur, frames, p, flash=True))
        elif kind == "gap":
            clips.append(make_gap(work, i, dur, frames))
        elif kind == "outro":
            clips.append(make_outro(work, i, dur, frames))
        t += dur

    lst = work / "clips.txt"
    lst.write_text("".join(f"file '{c}'\n" for c in clips))
    music = work / "music.wav"
    run(["-ss", str(MUSIC_START), "-t", f"{total:.3f}", "-i", str(MUSIC),
         "-af", f"afade=in:st=0:d=0.3,afade=out:st={total - 2.8:.3f}:d=2.8,loudnorm=I=-14:TP=-1.0:LRA=11",
         "-ar", "48000", str(music)])
    out = ROOT / "store/trailer.mp4"
    out.parent.mkdir(exist_ok=True)
    run(["-f", "concat", "-safe", "0", "-i", str(lst), "-i", str(music), "-map", "0:v", "-map", "1:a",
         "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS),
         "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-shortest", str(out)])
    print(f"已输出 {out}（{total:.1f} 秒）")


if __name__ == "__main__":
    main()
