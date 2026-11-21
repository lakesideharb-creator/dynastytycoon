#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
试玩记录汇总工具（tools/analyze_playtests.py）：
- tests/fixtures/playtests/ 是用 Godot 游戏内同一套 PlaytestLog 生成的真实格式记录（tests/gen_playtest_samples.gd）
- 其余用例用手写记录覆盖去重、坏行、终端版记录、可通关路线对照与自动提示
"""
import json
import os
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.join(ROOT, "tools"))

import analyze_playtests as ap  # noqa: E402

FIXTURES = os.path.join(ROOT, "tests", "fixtures", "playtests")
WIN_PATH = {"main_choice": "B", "decisions": {"s1_summer": "A", "s1_rival": "B", "s1_winter": "B"}}   # tools/campaign_paths.py 中可通关


def campaign(outcome="win", main="B", decisions=None, months=12, **kw):
    row = {"scenario": 1, "outcome": outcome, "months_played": months, "main_choice": main,
           "decisions": decisions if decisions is not None else dict(WIN_PATH["decisions"]),
           "cash": 140_000_000, "last_month_profit": 1, "friction": 0.05, "fengshui": 0.1}
    row.update(kw)
    return row


class TestAnalyzePlaytests(unittest.TestCase):

    def _write(self, d, name, rows, extra_lines=()):
        path = os.path.join(d, name)
        with open(path, "w", encoding="utf-8") as f:
            for r in rows:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
            for line in extra_lines:
                f.write(line + "\n")
        return path

    def test_fixture_report_covers_all_modes(self):
        rows, bad = ap.load_rows(ap.collect_files([FIXTURES]))
        self.assertEqual(bad, 0)
        modes = {ap.mode_of(r) for _, r in rows}
        self.assertEqual(modes, {"campaign", "crisis", "sandbox"}, "示例记录应包含三种模式")
        report = ap.build_report(rows)
        for heading in ["# 试玩记录汇总", "## 需要关注", "## 战役", "## 危机公关指挥室", "## 自由沙盒", "走了理论可通关路线"]:
            self.assertIn(heading, report)
        self.assertIn("4 位试玩者", report)

    def test_dedupes_repeated_exports_and_skips_bad_lines(self):
        with tempfile.TemporaryDirectory() as d:
            row = campaign(time="2026-11-20 10:00:00")
            self._write(d, "甲.jsonl", [row, row, campaign(outcome="lose", main="A", time="t2")], ["{坏行"])
            rows, bad = ap.load_rows(ap.collect_files([d]))
        self.assertEqual(len(rows), 2, "同一试玩者重复导出的局只算一次")
        self.assertEqual(bad, 1)
        self.assertTrue(all(t == "甲" for t, _ in rows), "文件名即试玩者代号")

    def test_terminal_rows_without_mode_or_platform(self):
        rows = [("终端玩家", campaign())]
        report = ap.build_report(rows)
        self.assertIn("终端版×1", report)
        self.assertIn("通关率 **100%**", report)

    def test_winning_route_check(self):
        rows = [("a", campaign(time="1")),                                             # 可通关路线且通关
                ("b", campaign(outcome="lose", time="2")),                             # 可通关路线但没通关
                ("c", campaign(main="A", decisions={"s1_summer": "A", "s1_rival": "A", "s1_winter": "A"}, time="3"))]  # 路线外却通关
        report = ap.build_report(rows)
        self.assertIn("走了理论可通关路线（不计随机事件）的：2/3", report)
        self.assertIn("其中没通关的 1 局", report)
        self.assertIn("不在可通关路线上却通关的 1 局", report)

    def test_flags_dominant_choice_quits_and_difficulty(self):
        rows = [(f"p{i}", campaign(time=str(i))) for i in range(6)]
        rows += [(f"q{i}", campaign(outcome="quit", months=4, time=f"q{i}")) for i in range(3)]
        report = ap.build_report(rows, check_paths=False)
        self.assertIn("100% 的人选了 B", report)
        self.assertIn("只有 0% 的人选", report)
        self.assertIn("中途退出——检查退出月份", report)
        self.assertIn("通关率 100%，偏易", report)
        self.assertIn("中途退出在第 4, 4, 4 个月", report)

    def test_crisis_and_sandbox_sections(self):
        crisis = {"mode": "crisis", "scenario": 10, "crisis": "weight_loss_drug", "outcome": "win", "verdict": "excellent",
                  "decisions": ["stage1_active", "stage2_press_sincere", "stage3_fund"], "anger": 0, "trust": 100}
        sandbox = {"mode": "sandbox", "industry": "AI_Tech", "outcome": "quit", "grade": "C", "months_played": 30,
                   "year": 2026, "net_assets": 3e7, "stores": 2, "executives": [], "office_score": 5}
        report = ap.build_report([("x", crisis), ("y", sandbox)])
        self.assertIn("绝处逢生·卓越通关", report)
        self.assertIn("秒级响应 → 景门主理人出战 → 设立千万质保金（1 局）", report)
        self.assertIn("中途离开的年份：2026年×1", report)
        self.assertIn("一个高管都没雇", report)
        self.assertIn("AI科技创业", report)

    def test_cli_writes_report(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "report.md")
            ap.main([FIXTURES, "--out", out, "--no-paths"])
            with open(out, encoding="utf-8") as f:
                self.assertIn("# 试玩记录汇总", f.read())


if __name__ == "__main__":
    unittest.main()
