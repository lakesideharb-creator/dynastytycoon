#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音频母带处理：统一采样率、响度与峰值，并为循环音乐制作无缝循环点（依赖 ffmpeg）

  music  两遍 loudnorm 归一到 -14 LUFS / -1.5 dBTP；可去掉开头静音、用首尾交叉淡化做无缝循环
  sfx    以"最响 200ms 窗口"的 RMS 对齐响度（短音效无法测积分响度），限幅到 -2 dBFS

用法：
  python3 tools/audio_master.py music 输入.ogg [...] --out 目录 [--loop-xfade 2.5] [--trim-lead]
  python3 tools/audio_master.py sfx   输入.ogg [...] --out 目录
  python3 tools/audio_master.py check 目录或文件 [...]      # 只测量，不修改
"""
import argparse
import array
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import wave

SAMPLE_RATE = 48000
MUSIC_LUFS, MUSIC_TP = -14.0, -1.5
SFX_WINDOW_RMS, SFX_PEAK = -14.0, -2.0       # 最响 200ms 窗口的目标 RMS（dBFS）与限幅值（为 Vorbis 编码过冲留余量）
VORBIS_QUALITY = "5"                          # ≈160 kbps
SILENCE_DB = -50.0


def ffmpeg_bin() -> str:
    exe = shutil.which("ffmpeg")
    if not exe:
        sys.exit("未找到 ffmpeg，请先安装（brew install ffmpeg）")
    return exe


def run(args, capture=True) -> str:
    res = subprocess.run([ffmpeg_bin(), "-hide_banner", "-nostats", *args],
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0:
        raise RuntimeError(res.stderr[-2000:])
    return res.stderr


# ─── 测量 ─────────────────────────────────────────────────────────────────────
def decode_mono(path: str):
    """解码为 48k 单声道 16bit，返回 (samples, sr)"""
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "x.wav")
        run(["-y", "-i", path, "-ac", "1", "-ar", str(SAMPLE_RATE), "-c:a", "pcm_s16le", wav])
        with wave.open(wav) as w:
            return array.array("h", w.readframes(w.getnframes())), w.getframerate()


def _db(v: float) -> float:
    return 20 * math.log10(max(v, 1e-9))


def rms_db(seg) -> float:
    if not seg:
        return -120.0
    return _db(math.sqrt(sum(v * v for v in seg) / len(seg)) / 32768)


def loudest_window_rms(samples, sr, window=0.2) -> float:
    n = max(1, int(sr * window))
    if len(samples) <= n:
        return rms_db(samples)
    acc = sum(v * v for v in samples[:n])
    best = acc
    for i in range(n, len(samples)):
        acc += samples[i] * samples[i] - samples[i - n] * samples[i - n]
        best = max(best, acc)
    return _db(math.sqrt(best / n) / 32768)


def lead_silence(samples, sr, db=SILENCE_DB) -> float:
    thr = 32768 * 10 ** (db / 20)
    return next((i for i, v in enumerate(samples) if abs(v) > thr), len(samples)) / sr


def measure(path: str) -> dict:
    s, sr = decode_mono(path)
    info = run(["-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"])
    lufs = re.findall(r"I:\s+(-?[\d.]+) LUFS", info)
    tp = re.findall(r"Peak:\s+(-?[\d.]+) dBFS", info)
    rate = re.search(r"Audio: \w+, (\d+) Hz", info)
    half = int(sr * 0.5)
    mid = len(s) // 2
    return {
        "file": os.path.basename(path),
        "seconds": round(len(s) / sr, 2),
        "sample_rate": int(rate.group(1)) if rate else None,
        "lufs": float(lufs[-1]) if lufs else None,
        "true_peak": float(tp[-1]) if tp else None,
        "window_rms": round(loudest_window_rms(s, sr), 1),
        "lead_silence_ms": round(lead_silence(s, sr) * 1000),
        "head_db": round(rms_db(s[:half]), 1),
        "tail_db": round(rms_db(s[-half:]), 1),
        "body_db": round(rms_db(s[mid:mid + sr * 5]), 1),
    }


# ─── 处理 ─────────────────────────────────────────────────────────────────────
def _encode(filter_graph: str, src: str, dst: str, complex_graph=False):
    args = ["-y", "-i", src]
    args += ["-filter_complex", filter_graph, "-map", "[out]"] if complex_graph else ["-af", filter_graph]
    args += ["-ar", str(SAMPLE_RATE), "-c:a", "libvorbis", "-q:a", VORBIS_QUALITY, dst]
    run(args)


def full_level_span(samples, sr, window=1.0, drop_db=6.0):
    """返回电平进入/离开"主体电平 - drop_db"的时间点，用于切掉原曲的淡入和淡出"""
    n = int(sr * window)
    levels = [rms_db(samples[i:i + n]) for i in range(0, len(samples) - n, n)]
    body = sorted(levels)[len(levels) // 2]
    loud = [i for i, v in enumerate(levels) if v >= body - drop_db]
    return loud[0] * window, (loud[-1] + 1) * window


def make_loop(src: str, dst: str, xfade: float, trim_lead: bool, trim_fades: bool = False, fade_drop: float = 6.0):
    """首尾交叉淡化：结尾 xfade 秒与开头 xfade 秒叠化后放到开头，循环点处信号连续"""
    s, sr = decode_mono(src)
    start, end = 0.0, len(s) / sr
    if trim_fades:
        start, end = full_level_span(s, sr, drop_db=fade_drop)
    elif trim_lead:
        start = lead_silence(s, sr)
    length = end - start
    n = xfade
    g = (f"[0:a]atrim=start={start}:end={end},asetpts=PTS-STARTPTS,asplit=3[a][b][c];"
         f"[a]atrim=0:{n},asetpts=PTS-STARTPTS[head];"
         f"[b]atrim={n}:{length - n},asetpts=PTS-STARTPTS[mid];"
         f"[c]atrim={length - n},asetpts=PTS-STARTPTS[tail];"
         f"[tail][head]acrossfade=d={n}:c1=qsin:c2=qsin[x];"
         f"[x][mid]concat=n=2:v=0:a=1[out]")
    _encode(g, src, dst, complex_graph=True)


def loudnorm_music(src: str, dst: str):
    first = run(["-i", src, "-af", f"loudnorm=I={MUSIC_LUFS}:TP={MUSIC_TP}:LRA=11:print_format=json", "-f", "null", "-"])
    stats = json.loads(first[first.rindex("{"):first.rindex("}") + 1])
    f = (f"loudnorm=I={MUSIC_LUFS}:TP={MUSIC_TP}:LRA=11:"
         f"measured_I={stats['input_i']}:measured_TP={stats['input_tp']}:"
         f"measured_LRA={stats['input_lra']}:measured_thresh={stats['input_thresh']}:"
         f"offset={stats['target_offset']}:linear=true")
    # loudnorm 线性模式不保证真峰值，补一级限幅（留出 Vorbis 编码过冲余量）
    _encode(f"aresample={SAMPLE_RATE},{f},alimiter=limit={10 ** ((MUSIC_TP - 0.5) / 20):.4f}:attack=1:release=50:level=false",
            src, dst)


def master_sfx(src: str, dst: str, target: float = SFX_WINDOW_RMS):
    s, sr = decode_mono(src)
    gain = target - loudest_window_rms(s, sr)
    _encode(f"aresample={SAMPLE_RATE},volume={gain:.2f}dB,"
            f"alimiter=limit={10 ** (SFX_PEAK / 20):.4f}:attack=1:release=50:level=false", src, dst)
    return gain


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["music", "sfx", "check"])
    ap.add_argument("inputs", nargs="+")
    ap.add_argument("--out", help="输出目录（文件名不变）")
    ap.add_argument("--target", type=float, default=SFX_WINDOW_RMS,
                    help="sfx：最响 200ms 窗口目标 RMS（dBFS），默认 -14；悬停、点击等高频界面音建议 -20")
    ap.add_argument("--loop-xfade", type=float, default=0.0, help="music：首尾交叉淡化秒数，0 表示不做循环处理")
    ap.add_argument("--trim-lead", action="store_true", help="music：去掉开头静音")
    ap.add_argument("--trim-fades", action="store_true", help="music：切掉原曲的淡入和淡出再做循环（原曲首尾有淡入淡出时使用）")
    ap.add_argument("--fade-drop", type=float, default=6.0, help="music：低于主体电平多少 dB 视为淡入/淡出段（原曲有很长的尾声时调小，如 3）")
    args = ap.parse_args(argv)

    files = []
    for p in args.inputs:
        files += sorted(os.path.join(p, f) for f in os.listdir(p) if f.endswith(".ogg")) if os.path.isdir(p) else [p]

    if args.mode == "check":
        for f in files:
            m = measure(f)
            print("  ".join(f"{k}={v}" for k, v in m.items()))
        return
    if not args.out:
        ap.error("music / sfx 模式需要 --out")
    os.makedirs(args.out, exist_ok=True)
    for f in files:
        dst = os.path.join(args.out, os.path.basename(f))
        if args.mode == "sfx":
            gain = master_sfx(f, dst, args.target)
            print(f"{os.path.basename(f)}  增益 {gain:+.1f} dB")
        else:
            with tempfile.TemporaryDirectory() as td:
                src = f
                if args.loop_xfade or args.trim_lead or args.trim_fades:
                    src = os.path.join(td, "loop.ogg")
                    make_loop(f, src, args.loop_xfade or 0.01, args.trim_lead, args.trim_fades, args.fade_drop)
                loudnorm_music(src, dst)
            print(f"{os.path.basename(f)}  已处理")


if __name__ == "__main__":
    main()
