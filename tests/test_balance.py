#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
战役平衡性回归（基于 CampaignRunner 路径穷举）
- 错误的开局主决策：任何决策路径都无法通关
- 正确的开局主决策：既有能赢的路径，也有会输的路径（月度决策真正有分量）
- 最优路径：在随机事件扰动下依然稳定通关
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import random
import unittest

from src import CampaignManager
from src.campaign_runner import CampaignRunner, enumerate_paths, EFFECT_TYPES
from src.personnel import PersonnelSystem
from src.office_fengshui import OfficeLayoutManager
from src import tables

SCENARIOS = tuple(s["id"] for s in CampaignManager.get_all_scenarios_meta() if CampaignManager.is_playable(s["id"]))
EVENT_SEEDS = range(30)


def full_renovation(runner: CampaignRunner):
    """第1个月就把总部从恶煞布局改到满分布局（与 Godot/终端版的改造规则一致）"""
    weight = tables.load("office_items.json")["modifier_weight"]
    delta = (OfficeLayoutManager.create_harmonious_preset().audit_layout().fengshui_modifier
             - OfficeLayoutManager.create_chaotic_preset().audit_layout().fengshui_modifier)
    runner.company.cash -= 190000
    runner.company.fengshui_modifier = round(min(0.35, max(-0.25, runner.company.fengshui_modifier + delta * weight)), 3)


def replay(scenario_id: int, path: str, seed=None, renovate=False) -> CampaignRunner:
    if seed is not None:
        random.seed(seed)
    main, *picks = path.split("|")
    picks = dict(p.split("=") for p in picks)
    r = CampaignRunner(scenario_id)
    r.apply_main_choice(main)
    if renovate:
        full_renovation(r)
    while not r.is_finished:
        for ev in r.pending_decisions():
            # 改造或随机事件会改变现金：路径里的选项付不起、或路径在无事件时已破产而没有这个议题，就按 C→B→A 取第一个可选项
            keys = [picks.get(ev["id"]), "C", "B", "A"]
            next(k for k in keys if k and r.apply_decision(ev["id"], k)[0])
        r.simulate_month(random_events=seed is not None)
        if not r.bankrupt:
            r.advance()
    return r


class TestCampaignBalance(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.paths = {sid: [(p, r.check_win()) for p, r in enumerate_paths(sid)] for sid in SCENARIOS}
        cls.intended = {sid: CampaignManager.get_scenario_by_id(sid)["intended_main_choice"] for sid in SCENARIOS}

    def test_wrong_main_choice_never_wins(self):
        for sid in SCENARIOS:
            for path, win in self.paths[sid]:
                if not path.startswith(self.intended[sid]):
                    with self.subTest(scenario=sid, path=path):
                        self.assertFalse(win)

    def test_monthly_decisions_matter(self):
        for sid in SCENARIOS:
            outcomes = {win for path, win in self.paths[sid] if path.startswith(self.intended[sid])}
            with self.subTest(scenario=sid):
                self.assertEqual(outcomes, {True, False}, "正确主决策下应同时存在通关与失败的路径")

    def test_best_path_robust_to_events(self):
        for sid in SCENARIOS:
            winning = [p for p, w in self.paths[sid] if w]
            # 以无事件时的通关余量挑出最稳的路径
            best = max(winning, key=lambda p: replay(sid, p).company.cash)
            for seed in EVENT_SEEDS:
                with self.subTest(scenario=sid, seed=seed, path=best):
                    self.assertTrue(replay(sid, best, seed).check_win())


    def test_renovation_cannot_rescue_wrong_main_choice(self):
        """风水满配改造 + 随机事件，错误主决策的最优路径依然不能通关"""
        for sid in SCENARIOS:
            wrong = [p for p, _ in self.paths[sid] if not p.startswith(self.intended[sid])]
            best = max(wrong, key=lambda p: replay(sid, p, renovate=True).company.cash)
            for seed in EVENT_SEEDS:
                with self.subTest(scenario=sid, seed=seed, path=best):
                    self.assertFalse(replay(sid, best, seed, renovate=True).check_win())


class TestDecisionData(unittest.TestCase):
    """决策点数据完整性：Godot 端会读取同一份 JSON"""

    def test_decision_points_well_formed(self):
        gates = {g for (_, g) in PersonnelSystem().role_gate_synergy} | {"xiu_men", "si_men"}
        for sid in SCENARIOS:
            meta = CampaignManager.get_scenario_by_id(sid)
            dps = meta.get("decision_points", [])
            self.assertGreaterEqual(len(dps), 3, f"关卡{sid} 至少应有3个月度决策点")
            ids = [d["id"] for d in dps]
            self.assertEqual(len(ids), len(set(ids)), "决策点 id 不可重复")
            for dp in dps:
                self.assertTrue(1 <= dp["turn"] <= meta["duration_months"])
                for opt in dp["options"]:
                    with self.subTest(scenario=sid, dp=dp["id"], option=opt["key"]):
                        if "requires_gate" in opt:
                            self.assertIn(opt["requires_gate"], gates)
                        for eff in opt.get("effects", []):
                            self.assertIn(eff["type"], EFFECT_TYPES)


if __name__ == "__main__":
    unittest.main()
