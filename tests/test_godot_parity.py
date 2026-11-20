#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Python 与 Godot 两套引擎的一致性：
- godot/data 与 data/ 同步
- godot/tests/golden 与当前 Python 引擎的输出一致（改了 Python 逻辑却没重新导出时会失败）
- 本机有 Godot 时运行 Godot 端对照测试（godot/tests/run_tests.gd）
"""
import sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.join(ROOT, "tools"))

import filecmp
import shutil
import subprocess
import tempfile
import unittest

import export_golden
import sync_godot_data

GODOT_DIR = os.path.join(ROOT, "godot")
GOLDEN_DIR = os.path.join(GODOT_DIR, "tests", "golden")


def find_godot():
    """GODOT_BIN 环境变量 > PATH 中的 godot > 常见安装位置"""
    candidates = [os.environ.get("GODOT_BIN"), shutil.which("godot"), shutil.which("godot4"),
                  "/Applications/Godot.app/Contents/MacOS/Godot",
                  os.path.expanduser("~/Downloads/Godot.app/Contents/MacOS/Godot"),
                  os.path.expanduser("~/Applications/Godot.app/Contents/MacOS/Godot")]
    return next((c for c in candidates if c and os.path.exists(c)), None)


class TestGodotData(unittest.TestCase):

    def test_data_synced(self):
        self.assertEqual(sync_godot_data.out_of_sync(), [],
                         "godot/data 与 data/ 不一致，请运行 python3 tools/sync_godot_data.py")

    def test_golden_up_to_date(self):
        with tempfile.TemporaryDirectory() as td:
            export_golden.main(["--out", td])
            stale = [f for f in sorted(os.listdir(td))
                     if not os.path.exists(os.path.join(GOLDEN_DIR, f))
                     or not filecmp.cmp(os.path.join(td, f), os.path.join(GOLDEN_DIR, f), shallow=False)]
        self.assertEqual(stale, [], "golden 数据过期，请运行 python3 tools/export_golden.py")


@unittest.skipUnless(find_godot(), "本机未找到 Godot（可设置 GODOT_BIN）")
class TestGodotParity(unittest.TestCase):

    def test_godot_engine_matches_python(self):
        godot = find_godot()
        if not os.path.isdir(os.path.join(GODOT_DIR, ".godot")):
            subprocess.run([godot, "--headless", "--path", GODOT_DIR, "--import"],
                           capture_output=True, text=True, timeout=300)
        res = subprocess.run([godot, "--headless", "--path", GODOT_DIR, "-s", "res://tests/run_tests.gd"],
                             capture_output=True, text=True, timeout=300)
        tail = "\n".join(res.stdout.strip().splitlines()[-15:])
        self.assertEqual(res.returncode, 0, f"Godot 对照测试失败：\n{tail}\n{res.stderr[-1500:]}")
        self.assertIn("失败 0 项", res.stdout)
        errors = [l for l in (res.stdout + res.stderr).splitlines() if "SCRIPT ERROR" in l or "Compile Error" in l]
        self.assertEqual(errors, [], "Godot 脚本有编译/运行错误（可能导致部分测试没有执行）")
        self._python_reads_godot_save()

    def _python_reads_godot_save(self):
        """Godot 写出的存档用 Python 读档后续玩，结果与 Python 不中断地玩同一条路径一致"""
        import json
        from src.save_manager import SaveManager
        from src.campaign_runner import CampaignRunner
        with open(os.path.join(GODOT_DIR, "tests", "out", "godot_save.json"), encoding="utf-8") as f:
            data = json.load(f)
        path = "B|s1_summer=A|s1_rival=B|s1_winter=A"
        picks = dict(p.split("=") for p in path.split("|")[1:])

        def finish(r):
            while not r.is_finished:
                for ev in r.pending_decisions():
                    r.apply_decision(ev["id"], picks[ev["id"]])
                r.simulate_month(random_events=False)
                if not r.bankrupt:
                    r.advance()
            return r

        loaded = SaveManager.from_dict(data)
        self.assertEqual([it.id for it in loaded.office_items][-1], "screen_1")
        resumed = finish(CampaignRunner(loaded.scenario_id, loaded.company, loaded.clock, loaded.progress))
        fresh = CampaignRunner(1)
        fresh.apply_main_choice("B")
        finish(fresh)
        self.assertAlmostEqual(resumed.company.cash, fresh.company.cash, delta=1e-6 * abs(fresh.company.cash))
        self.assertEqual(resumed.check_win(), fresh.check_win())


if __name__ == "__main__":
    unittest.main()
