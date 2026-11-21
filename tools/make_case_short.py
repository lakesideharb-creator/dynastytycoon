#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
案例短片：用决策卡插画 + 关卡数据生成 1080×1920 竖屏短片（约 70 秒，抖音 / 视频号 / 小红书 / B站竖屏）。

结构：钩子 → 困境 → 开局三选一 → 停顿「你选哪个？」→ 三个选项的结局（错 / 错 / 对）→ 三个月度议题 → 一句点题 → 片尾引流
开局选项、结局文案、议题标题都直接读 data/campaign_scenarios.json；钩子、点题、配乐写在下面的 SCRIPTS 里。

用法：python3 tools/make_case_short.py 4 6        （默认输出到 store/shorts/）
      python3 tools/make_case_short.py 4 --work /tmp/短片工作目录
输出：store/shorts/case{N}_short.mp4（H.264 + AAC）与 case{N}_cover.png（封面）
"""
import argparse
import json
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
SERIF = ROOT / "godot/assets/fonts/NotoSerifSC-subset.ttf"
SANS = ROOT / "godot/assets/fonts/NotoSansSC-subset.ttf"
EVENTS = ROOT / "godot/assets/events"
MUSIC = ROOT / "godot/assets/music"
FPS = 30
W, H = 1080, 1920
IMG_Y, IMG_H = 560, 608                       # 中部插画区（16:9 插画按宽 1080 缩放）
GOLD = (214, 178, 106, 255)
PAPER = (246, 240, 226, 255)
CINNABAR = (196, 64, 48, 255)
JADE = (92, 170, 130, 255)
DIM = (190, 182, 166, 255)
NUM = {4: "四", 5: "五", 6: "六", 7: "七", 8: "八", 9: "九"}

# 每个案例的短片脚本：钩子、困境一句话、点题、配乐；插画用决策卡（事件 id）
SCRIPTS = {
    4: {
        "hook": ["百亿巨头", "全国买一送一", "你跟不跟？"],
        "hook_art": "s4_dealers",
        "setup": ["新锐电解质水「澜泉」年销5亿", "巨头杀来：商超买一送一", "还逼经销商二选一"],
        "setup_art": "s4_dealers",
        "result_art": "s4_marathon",
        "wrong_art": {"A": "s4_dealers", "C": "s4_copycat"},
        "lesson": ["不在泥坑里", "和巨头比价格"],
        "lesson_sub": "竞争策略 · 非对称突围",
        "music": "crisis_war_room.ogg", "music_start": 0.0,
    },
    6: {
        "hook": ["新品研发完成", "推广费只有200万", "什么时候发布？"],
        "hook_art": "s6_launch",
        "setup": ["人脸识别智能锁「锁境」", "7月暑期大促？9月中秋前夕？", "还是干脆等双十一？"],
        "setup_art": "s6_chips",
        "result_art": "s6_launch",
        "wrong_art": {"A": "s6_double11", "C": "s6_late_launch"},
        "lesson": ["好产品也要等对时机", "景门当令，悬念才有落点"],
        "lesson_sub": "营销时机 · 择时引爆",
        "music": "theme_main.ogg", "music_start": 0.0,
    },
}

# 片段时长（秒）
T_HOOK, T_SETUP, T_CHOICES, T_ASK, T_RESULT, T_DP, T_LESSON, T_OUTRO = 4.5, 8.0, 9.0, 4.0, 5.5, 4.5, 6.0, 7.0


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


def wrap(draw, text, f, width):
    """按像素宽度折行，并把各行长度拉平（避免末行只剩一两个字）"""
    lines = _greedy(draw, text, f, width)
    if len(lines) > 1:
        even = draw.textlength(text, font=f) / len(lines) + f.size * 0.6
        balanced = _greedy(draw, text, f, min(width, even))
        if len(balanced) == len(lines):
            lines = balanced
    return lines


def _greedy(draw, text, f, width):
    """逐字折行（中文没有空格）"""
    lines, cur = [], ""
    for ch in text:
        if draw.textlength(cur + ch, font=f) > width and cur:
            lines.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        lines.append(cur)
    return lines


def draw_text(d, xy, text, f, fill, shadow=True, center=False):
    x, y = xy
    if center:
        x = (W - d.textlength(text, font=f)) / 2
    if shadow:
        d.text((x + 3, y + 4), text, font=f, fill=(0, 0, 0, 210))
    d.text((x, y), text, font=f, fill=fill)


def layer(path, draw_fn, dim=0):
    img = Image.new("RGBA", (W, H), (0, 0, 0, dim))
    draw_fn(ImageDraw.Draw(img))
    img.save(path)
    return path


def run(args):
    r = subprocess.run(["ffmpeg", "-v", "error", "-y", *args])
    if r.returncode:
        sys.exit("ffmpeg 失败：" + " ".join(map(str, args)))


ENC = ["-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-r", str(FPS)]


def scene(out, dur, art=None, layers=(), zoom=0.06, dark=0.38, fade_in=0.25):
    """一个片段：背景（插画模糊铺满 + 中部清晰插画缓推，或纯色）+ 若干文字层（各自淡入淡出）"""
    frames = round(dur * FPS)
    inputs, fc = [], []
    if art:
        inputs += ["-loop", "1", "-framerate", str(FPS), "-i", str(art)]
        fc.append(f"[0:v]split=2[a][b];[a]scale=-2:{H},crop={W}:{H},boxblur=28:2,eq=brightness=-{dark}:saturation=0.8[bg];"
                  f"[b]scale=w='trunc({W}*(1+{zoom}*t/{dur:.3f})/2)*2':h=-2:eval=frame,crop={W}:{IMG_H}[fg];"
                  f"[bg][fg]overlay=0:{IMG_Y},setsar=1,fade=in:st=0:d={fade_in}[base]")
    else:
        inputs += ["-f", "lavfi", "-i", f"color=c=0x0B0E12:s={W}x{H}:r={FPS}"]
        fc.append(f"[0:v]setsar=1,fade=in:st=0:d={fade_in}[base]")
    chain = "[base]"
    for k, (png, t0, t1) in enumerate(layers):
        inputs += ["-loop", "1", "-framerate", str(FPS), "-i", str(png)]
        f = f"[{k + 1}:v]format=rgba,fade=in:st={t0:.2f}:d=0.3:alpha=1"
        if t1 is not None:
            f += f",fade=out:st={t1 - 0.25:.2f}:d=0.25:alpha=1"
        fc.append(f + f"[l{k}]")
        fc.append(f"{chain}[l{k}]overlay=0:0[o{k}]")
        chain = f"[o{k}]"
    fc.append(f"{chain}fade=out:st={dur - 0.18:.2f}:d=0.18[out]")
    run([*inputs, "-filter_complex", ";".join(fc), "-map", "[out]", "-frames:v", str(frames), *ENC, str(out)])
    return out


def header(d, case_label, title):
    """顶部：案例编号 + 标题（每个片段都带，方便中途划进来的观众）"""
    draw_text(d, (0, 150), case_label, font(SERIF, 44, 700), GOLD, center=True)
    f = font(SERIF, 60, 900)
    for i, line in enumerate(wrap(d, title, f, W - 140)[:2]):
        draw_text(d, (0, 225 + i * 84), line, f, PAPER, center=True)


def build(sid, work, out_dir):
    meta = next(s for s in json.loads((ROOT / "data/campaign_scenarios.json").read_text(encoding="utf-8"))["scenarios"] if s["id"] == sid)
    sc = SCRIPTS[sid]
    method = meta["title"].split("【")[1].split("】")[0]
    case_label = f"案例{NUM[sid]} · {method}"
    title = meta["title"].split("：", 1)[1]
    intended = meta["intended_main_choice"]
    keys = list(meta["main_choices"])
    path_dps = [dp for dp in meta["decision_points"]
                if intended in dp.get("requires_main_choice", [intended]) and "requires_event_choice" not in dp][:3]
    texts = sc["hook"] + sc["setup"] + sc["lesson"] + [sc["lesson_sub"], case_label, title, "开局决断", "你选哪个？", "评论区告诉我",
             "选错了", "选对了", "接下来的三个月", "完整推演", "商道玄机·大亨罗盘", "itch.io 免费试玩", "lakesideharb.itch.io/dynasty-tycoon",
             "以奇门之术经营商海 ✓ × ▶ 0123456789"]
    texts += [meta["choices"][k]["name"] + meta["choices"][k]["verdict"] for k in keys] + [dp["title"] for dp in path_dps]
    check_glyphs(texts)
    art = lambda eid: EVENTS / f"{eid}.png"
    clips = []
    n = 0

    def nxt():
        nonlocal n
        n += 1
        return work / f"c{sid}_{n:02d}.mp4"

    # 1 钩子：三行大字逐行砸出
    hook_layers = []
    for i, line in enumerate(sc["hook"]):
        p = layer(work / f"h{sid}_{i}.png", lambda d, i=i, line=line: draw_text(
            d, (0, 1260 + i * 130), line, font(SERIF, 92 if i < 2 else 104, 900), CINNABAR if i == 2 else PAPER, center=True))
        hook_layers.append((p, 0.25 + i * 1.0, None))
    hook_layers.append((layer(work / f"hh{sid}.png", lambda d: header(d, case_label, title)), 0.1, None))
    clips.append(scene(nxt(), T_HOOK, art(sc["hook_art"]), hook_layers, zoom=0.1))

    # 2 困境
    def setup_draw(d):
        header(d, case_label, title)
        f = font(SANS, 50, 500)
        for i, line in enumerate(sc["setup"]):
            draw_text(d, (0, 1260 + i * 96), line, f, PAPER if i < 2 else GOLD, center=True)
    clips.append(scene(nxt(), T_SETUP, art(sc["setup_art"]),
                       [(layer(work / f"s{sid}.png", setup_draw), 0.2, None)], zoom=0.07))

    # 3 开局三选一：三张选项条依次出现
    opt_layers = [(layer(work / f"ch{sid}.png", lambda d: (header(d, case_label, title),
                   draw_text(d, (0, 600), "开局决断", font(SERIF, 72, 900), GOLD, center=True))), 0.1, None)]
    for i, k in enumerate(keys):
        def opt_draw(d, i=i, k=k):
            y = 800 + i * 300
            d.rounded_rectangle([70, y, W - 70, y + 250], radius=18, fill=(22, 26, 34, 235), outline=GOLD, width=3)
            d.text((110, y + 60), k, font=font(SERIF, 110, 900), fill=GOLD)
            f = font(SERIF, 46, 700)
            for j, line in enumerate(wrap(d, meta["choices"][k]["name"], f, W - 330)[:3]):
                d.text((250, y + 40 + j * 64), line, font=f, fill=PAPER)
        opt_layers.append((layer(work / f"o{sid}_{k}.png", opt_draw), 0.8 + i * 1.6, None))
    clips.append(scene(nxt(), T_CHOICES, None, opt_layers))

    # 4 停顿：你选哪个？（倒数 3-2-1）
    ask = [(layer(work / f"ask{sid}.png", lambda d: (draw_text(d, (0, 760), "你选哪个？", font(SERIF, 130, 900), PAPER, center=True),
            draw_text(d, (0, 950), "评论区告诉我", font(SANS, 54, 500), GOLD, center=True))), 0.1, None)]
    for i, c in enumerate("321"):
        ask.append((layer(work / f"cd{sid}_{c}.png", lambda d, c=c: draw_text(d, (0, 1180), c, font(SERIF, 200, 900), CINNABAR, center=True)),
                    0.6 + i * 1.0, 1.6 + i * 1.0))
    clips.append(scene(nxt(), T_ASK, None, ask))

    # 5 三个结局：错的两个先放，对的最后
    order = [k for k in keys if k != intended] + [intended]
    for k in order:
        ok = k == intended
        def res_draw(d, k=k, ok=ok):
            header(d, case_label, title)
            d.rounded_rectangle([70, 1230, W - 70, 1310], radius=12, fill=(JADE if ok else CINNABAR)[:3] + (230,))
            draw_text(d, (0, 1238), f"{k}　{'✓ 选对了' if ok else '× 选错了'}", font(SERIF, 52, 900), PAPER, shadow=False, center=True)
            f = font(SERIF, 44, 700)
            for j, line in enumerate(wrap(d, meta["choices"][k]["name"], f, W - 160)[:2]):
                draw_text(d, (0, 1350 + j * 62), line, f, GOLD, center=True)
            f2 = font(SANS, 42, 400)
            for j, line in enumerate(wrap(d, meta["choices"][k]["verdict"], f2, W - 160)[:4]):
                draw_text(d, (0, 1500 + j * 62), line, f2, PAPER, center=True)
        art_id = sc["result_art"] if ok else sc.get("wrong_art", {}).get(k, sc["setup_art"])
        clips.append(scene(nxt(), T_RESULT + (1.0 if ok else 0), art(art_id), [(layer(work / f"r{sid}_{k}.png", res_draw), 0.15, None)],
                           zoom=0.05, dark=0.3 if ok else 0.5))

    # 6 接下来的三个月：月度议题
    for i, dp in enumerate(path_dps):
        def dp_draw(d, dp=dp, i=i):
            header(d, case_label, title)
            draw_text(d, (0, 1250), f"第 {dp['turn']} 个月", font(SANS, 44, 500), GOLD, center=True)
            f = font(SERIF, 58, 900)
            for j, line in enumerate(wrap(d, dp["title"], f, W - 140)[:2]):
                draw_text(d, (0, 1330 + j * 80), line, f, PAPER, center=True)
            if i == 0:
                draw_text(d, (0, 1560), "开局选对，只是开始", font(SANS, 42, 400), DIM, center=True)
        clips.append(scene(nxt(), T_DP, art(dp["id"]), [(layer(work / f"d{sid}_{i}.png", dp_draw), 0.1, None)], zoom=0.08))

    # 7 点题
    def lesson_draw(d):
        for i, line in enumerate(sc["lesson"]):
            draw_text(d, (0, 760 + i * 130), line, font(SERIF, 86, 900), PAPER, center=True)
        draw_text(d, (0, 1060), sc["lesson_sub"], font(SANS, 46, 500), GOLD, center=True)
    clips.append(scene(nxt(), T_LESSON, None, [(layer(work / f"l{sid}.png", lesson_draw), 0.3, None)]))

    # 8 片尾引流
    def outro_draw(d):
        # 标题在插画上方、引流信息在插画下方，避免压在罗盘原画上
        draw_text(d, (0, 250), "商道玄机·大亨罗盘", font(SERIF, 92, 900), PAPER, center=True)
        draw_text(d, (0, 390), "以奇门之术经营商海", font(SANS, 46, 500), GOLD, center=True)
        draw_text(d, (0, 1260), f"完整推演 · {case_label}", font(SERIF, 54, 700), PAPER, center=True)
        draw_text(d, (0, 1360), "itch.io 免费试玩", font(SERIF, 60, 900), GOLD, center=True)
        draw_text(d, (0, 1460), "lakesideharb.itch.io/dynasty-tycoon", font(SANS, 38, 400), PAPER, center=True)
    clips.append(scene(nxt(), T_OUTRO, ROOT / "godot/assets/scenes/title.png",
                       [(layer(work / f"e{sid}.png", outro_draw), 0.3, None)], zoom=0.05, dark=0.5))

    # 拼接 + 配乐（结局「选对了」处叠一声胜利音效）
    lst = work / f"list{sid}.txt"
    lst.write_text("".join(f"file '{c}'\n" for c in clips))
    total = T_HOOK + T_SETUP + T_CHOICES + T_ASK + T_RESULT * 3 + 1.0 + T_DP * len(path_dps) + T_LESSON + T_OUTRO
    win_at = T_HOOK + T_SETUP + T_CHOICES + T_ASK + T_RESULT * 2 + 0.2
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"case{sid}_short.mp4"
    af = (f"[1:a]atrim=start={sc['music_start']}:duration={total:.3f},asetpts=PTS-STARTPTS,volume=0.8,"
          f"afade=in:st=0:d=0.4,afade=out:st={total - 2.5:.3f}:d=2.5[m];"
          f"[2:a]adelay={int(win_at * 1000)}|{int(win_at * 1000)},volume=0.9[s];"
          f"[m][s]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-14:TP=-1.0:LRA=11[a]")
    run(["-f", "concat", "-safe", "0", "-i", str(lst), "-i", str(MUSIC / sc["music"]), "-i", str(MUSIC / "sting_victory.ogg"),
         "-filter_complex", af, "-map", "0:v", "-map", "[a]", "-c:v", "libx264", "-preset", "slow", "-crf", "19",
         "-pix_fmt", "yuv420p", "-r", str(FPS), "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart",
         "-t", f"{total:.3f}", str(out)])
    # 封面：钩子画面第 4 秒
    cover = out_dir / f"case{sid}_cover.png"
    run(["-ss", "3.8", "-i", str(out), "-frames:v", "1", str(cover)])
    print(f"已输出 {out}（{total:.1f} 秒）与封面 {cover.name}")


def main():
    ap = argparse.ArgumentParser(description="生成案例竖屏短片")
    ap.add_argument("cases", nargs="+", type=int)
    ap.add_argument("--work", help="中间文件目录（默认临时目录）")
    ap.add_argument("--out", default=str(ROOT / "store/shorts"))
    args = ap.parse_args()
    for sid in args.cases:
        if sid not in SCRIPTS:
            sys.exit(f"案例 {sid} 还没有短片脚本（SCRIPTS）")
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(args.work) if args.work else pathlib.Path(tmp)
        work.mkdir(parents=True, exist_ok=True)
        for sid in args.cases:
            build(sid, work, pathlib.Path(args.out))


if __name__ == "__main__":
    main()
