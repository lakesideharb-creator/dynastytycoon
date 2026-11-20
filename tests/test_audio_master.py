#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音频母带工具测试（用 ffmpeg 合成测试音，没有 ffmpeg 时跳过）
"""
import sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

import shutil
import subprocess
import tempfile
import unittest

import audio_master as am

HAVE_FFMPEG = shutil.which("ffmpeg") is not None


def synth(path: str, expr: str, seconds: float, rate=192000):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi",
                    "-i", f"{expr}:d={seconds}:sample_rate={rate}", "-c:a", "libvorbis", path], check=True)


@unittest.skipUnless(HAVE_FFMPEG, "需要 ffmpeg")
class TestAudioMaster(unittest.TestCase):

    def setUp(self):
        self.td = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.td, ignore_errors=True)

    def p(self, name):
        return os.path.join(self.td, name)

    def test_music_loop_removes_fades_and_normalizes(self):
        # 粉噪 20 秒，前 4 秒淡入、后 4 秒淡出 → 原样循环时接缝处会掉到很低
        src = self.p("src.ogg")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi",
                        "-i", "anoisesrc=color=pink:amplitude=0.3:d=20:sample_rate=192000",
                        "-af", "afade=t=in:d=4,afade=t=out:st=16:d=4", "-c:a", "libvorbis", src], check=True)
        before = am.measure(src)
        self.assertLess(before["head_db"], before["body_db"] - 10)

        loop = self.p("loop.ogg")
        am.make_loop(src, loop, xfade=2.0, trim_lead=False, trim_fades=True)
        out = self.p("out.ogg")
        am.loudnorm_music(loop, out)
        m = am.measure(out)
        self.assertEqual(m["sample_rate"], am.SAMPLE_RATE)
        self.assertAlmostEqual(m["lufs"], am.MUSIC_LUFS, delta=1.0)
        self.assertLessEqual(m["true_peak"], am.MUSIC_TP + 0.5)
        self.assertGreater(m["head_db"], m["body_db"] - 4, "循环起点不应再有淡入")
        self.assertGreater(m["tail_db"], m["body_db"] - 4, "循环终点不应再有淡出")

    def test_trim_lead_silence(self):
        src = self.p("lead.ogg")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                        "-f", "lavfi", "-i", "anullsrc=r=48000:cl=mono:d=0.7",
                        "-f", "lavfi", "-i", "sine=frequency=440:d=10:sample_rate=48000",
                        "-filter_complex", "[0:a][1:a]concat=n=2:v=0:a=1[o]", "-map", "[o]",
                        "-c:a", "libvorbis", src], check=True)
        out = self.p("lead_out.ogg")
        am.make_loop(src, out, xfade=1.0, trim_lead=True)
        self.assertLess(am.measure(out)["lead_silence_ms"], 20)

    def test_sfx_levels_aligned_and_limited(self):
        quiet, loud = self.p("quiet.ogg"), self.p("loud.ogg")
        synth(quiet, "sine=frequency=660", 0.6)
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi",
                        "-i", "sine=frequency=440:d=0.6:sample_rate=44100", "-af", "volume=-30dB",
                        "-c:a", "libvorbis", quiet], check=True)
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi",
                        "-i", "anoisesrc=color=white:amplitude=0.9:d=0.6:sample_rate=44100",
                        "-c:a", "libvorbis", loud], check=True)
        levels = []
        for src in (quiet, loud):
            out = src.replace(".ogg", "_m.ogg")
            am.master_sfx(src, out)
            m = am.measure(out)
            self.assertEqual(m["sample_rate"], am.SAMPLE_RATE)
            self.assertLessEqual(m["true_peak"], -0.5)
            levels.append(m["window_rms"])
        self.assertLess(abs(levels[0] - levels[1]), 4.0, f"响度应对齐：{levels}")


if __name__ == "__main__":
    unittest.main()
