#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
回归测试：惊门ID统一、危机公关门派与信任底线、存档读写与续玩、沙盒拓店菜单
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import io
import unittest
from contextlib import redirect_stdout
from unittest import mock

import play
from src import (Company, Executive, PersonnelSystem, PRCrisisWarRoom, SaveManager,
                 CampaignManager, CosmicSimulationEngine, OfficeLayoutManager, GridItem)
from src.talent_pool import _CANDIDATE_TEMPLATES, _GATE_NAMES

TEST_SLOT = "_unittest_slot"


class TestJingAlarmGate(unittest.TestCase):

    def test_cmo_synergy_applies(self):
        e = Executive("x", "x", "jing_alarm_men", "惊门", "CMO", 1, loyalty=50, stress=20)
        _, info = PersonnelSystem().calculate_personnel_factor([e])
        self.assertEqual(info["avg_match_score"], 1.25)

    def test_talent_gates_have_names(self):
        for name, gate, *_ in _CANDIDATE_TEMPLATES:
            self.assertIn(gate, _GATE_NAMES, f"{name} 的门派 {gate} 缺少中文名")
            if "惊" in name:
                self.assertEqual(gate, "jing_alarm_men", f"{name} 应属惊门")


class TestCrisisRules(unittest.TestCase):

    def _stage2_legal(self, room):
        room.hour = 4
        return next(o for o in room.get_current_stage().options if o.special_gate == "jing_alarm_men")

    def test_missing_gate_halves_effect(self):
        company = Company("c", "Social_Commerce", 1e8)
        room = PRCrisisWarRoom("t", initial_anger=50, initial_trust=50)
        opt = self._stage2_legal(room)
        room.execute_choice(opt.id, company)
        self.assertEqual(room.public_anger, 50 + int(opt.anger_delta / 2))
        self.assertEqual(room.brand_trust, 50 + int(opt.trust_delta / 2))

    def test_matching_gate_full_effect(self):
        company = Company("c", "Social_Commerce", 1e8,
                          executives=[Executive("l", "法", "jing_alarm_men", "惊门", "法务总监", 1)])
        room = PRCrisisWarRoom("t", initial_anger=50, initial_trust=50)
        opt = self._stage2_legal(room)
        room.execute_choice(opt.id, company)
        self.assertEqual(room.public_anger, 50 + opt.anger_delta)

    def test_trust_death_line_ends_crisis(self):
        company = Company("c", "Social_Commerce", 1e8)
        room = PRCrisisWarRoom("t", initial_anger=40, initial_trust=30)
        room.execute_choice("stage1_deny", company)   # 怒火 60，信任 5
        self.assertTrue(room.is_resolved)
        self.assertIn("社会性死亡", room.verdict)


class TestSaveLoad(unittest.TestCase):

    def tearDown(self):
        path = SaveManager.save_path(TEST_SLOT)
        if os.path.exists(path):
            os.remove(path)

    def test_round_trip(self):
        company, clock, _ = CampaignManager.setup_scenario_3()
        company.executives[0].special_trait = "暴烈"
        company.active_gods.append("bai_hu")
        CosmicSimulationEngine(clock).simulate_month(company)
        clock.advance_month()
        items = [GridItem("scr", "屏风", "screen", 4, 5)]
        SaveManager.save_game(company, clock, 3, slot_name=TEST_SLOT,
                              progress={"turn": 2, "decision_made": True}, office_items=items)

        loaded = SaveManager.load_game(TEST_SLOT)
        self.assertEqual(loaded.scenario_id, 3)
        self.assertEqual((loaded.clock.year, loaded.clock.month), (clock.year, clock.month))
        self.assertEqual(loaded.clock.era_id, clock.era_id)
        self.assertEqual(loaded.company.cash, company.cash)
        self.assertEqual(loaded.company.executives, company.executives)
        self.assertEqual(loaded.company.stores, company.stores)
        self.assertEqual(loaded.company.financial_history, company.financial_history)
        self.assertEqual(loaded.company.active_gods, ["bai_hu"])
        self.assertEqual(loaded.progress, {"turn": 2, "decision_made": True})
        self.assertEqual(loaded.office_items, items)

    def test_missing_save_returns_none(self):
        self.assertIsNone(SaveManager.load_game("_does_not_exist_"))

    def test_campaign_resume_skips_decision(self):
        """从已做决策的存档继续时，不应再次弹出 A/B/C 决断"""
        company, clock, _ = CampaignManager.setup_scenario_1()
        CampaignManager.apply_choice_scenario_1(company, "B")
        SaveManager.save_game(company, clock, 1, slot_name=TEST_SLOT,
                              progress={"turn": 5, "decision_made": True})
        loaded = SaveManager.load_game(TEST_SLOT)
        stores_before = len(loaded.company.stores)
        # 第一个输入若被当成决断会是 "4"（非法），这里直接推进一次再退出
        with mock.patch("builtins.input", side_effect=["4", "Q"]), \
             mock.patch.object(play.EventSystem, "trigger_monthly_event", return_value=None), \
             redirect_stdout(io.StringIO()):
            play.run_campaign_interactive(1, resume=loaded)
        self.assertEqual(len(loaded.company.stores), stores_before, "不应重复执行扩张决策")
        self.assertEqual(len(loaded.company.financial_history), 1)


class TestSandboxMenu(unittest.TestCase):

    def test_expand_menu_runs(self):
        """沙盒 [3] 拓店菜单此前因缺少 NinePalacesSystem 导入而崩溃"""
        inputs = ["1", "测试", "", "9",          # 行业、名称、资本、总部
                  "3", "9", "", "",              # 拓店：离九宫、默认名、默认 200 万
                  "0", "y", ""]                  # 提前结算并返回
        out = io.StringIO()
        with mock.patch("builtins.input", side_effect=inputs), redirect_stdout(out):
            play.run_sandbox_interactive()
        self.assertIn("f_S: 1.45", out.getvalue())   # 离九宫·文化餐饮亲和度
        self.assertIn("落成", out.getvalue())


if __name__ == "__main__":
    unittest.main()
