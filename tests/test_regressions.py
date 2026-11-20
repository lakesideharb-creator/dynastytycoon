#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
回归测试：沙盒九宫因子、拓店最低投资、风水布局持久化与关卡初始风水值
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import io
import unittest
from contextlib import redirect_stdout
from unittest import mock

import play
from src import SandboxGame, Company, OfficeLayoutManager, CosmicSimulationEngine, CampaignManager
from src.sandbox import MIN_STORE_INVEST


def run_studio(company, office_mgr, commands):
    """以模拟输入驱动风水工作室，结尾自动追加 0 退出"""
    with mock.patch("builtins.input", side_effect=list(commands) + ["0"]), redirect_stdout(io.StringIO()):
        play.manage_fengshui_studio(company, office_mgr)


class TestSandboxStore(unittest.TestCase):

    def setUp(self):
        self.game = SandboxGame.create_new_game("测试", "Cultural_Food", 20_000_000, "kan_1")

    def test_space_factor_applied_once(self):
        """离九宫新店的营收应体现 1.45 亲和度，且只乘一次"""
        ok, _ = self.game.open_new_store("离九店", "li_9", 2_000_000)
        self.assertTrue(ok)
        store = self.game.state.company.stores[-1]
        self.assertEqual(store.base_revenue, self.game.state.industry_cfg["base_revenue"])

        engine = self.game.state.engine
        f_space = engine.palaces_sys.calculate_store_space_factor("Cultural_Food", "li_9", self.game.state.company.fengshui_modifier)
        self.assertAlmostEqual(f_space, round(1.45 * (1 + self.game.state.company.fengshui_modifier), 3))

    def test_rejects_investment_below_minimum(self):
        cash_before = self.game.state.company.cash
        stores_before = len(self.game.state.company.stores)
        for invest in (0, MIN_STORE_INVEST - 1):
            ok, _ = self.game.open_new_store("白嫖店", "li_9", invest)
            self.assertFalse(ok)
        self.assertEqual(self.game.state.company.cash, cash_before)
        self.assertEqual(len(self.game.state.company.stores), stores_before)


class TestFengShuiStudio(unittest.TestCase):

    def test_full_preset_persists_to_caller(self):
        company = Company("测试", "AI_Tech", 5_000_000, fengshui_modifier=0.0)
        mgr = OfficeLayoutManager.create_chaotic_preset()
        run_studio(company, mgr, ["5"])
        self.assertEqual(mgr.audit_layout().score, 100, "一键装潢后调用方持有的布局应更新")

    def test_upgrades_accumulate_across_visits(self):
        company = Company("测试", "AI_Tech", 5_000_000, fengshui_modifier=0.0)
        mgr = OfficeLayoutManager.create_chaotic_preset()
        run_studio(company, mgr, ["1"])
        after_first = company.fengshui_modifier
        run_studio(company, mgr, ["3"])
        self.assertGreater(company.fengshui_modifier, after_first, "第二次进入时应保留第一次的改造")
        self.assertIn("scr_manual", mgr.items)

    def test_upgrade_adds_delta_to_scenario_base(self):
        """改造只叠加变化量，不覆盖关卡设定的初始风水值"""
        company, _, _ = CampaignManager.setup_scenario_1()
        base = company.fengshui_modifier
        mgr = OfficeLayoutManager.create_chaotic_preset()
        probe = OfficeLayoutManager.create_chaotic_preset()
        before = probe.audit_layout().fengshui_modifier
        probe.add_item(play.FENGSHUI_UPGRADES["1"][1]()[0])
        delta = probe.audit_layout().fengshui_modifier - before

        run_studio(company, mgr, ["1"])
        self.assertAlmostEqual(company.fengshui_modifier, round(base + delta, 3))
        self.assertGreater(company.fengshui_modifier, base)

    def test_insufficient_cash_changes_nothing(self):
        company = Company("穷", "AI_Tech", 10_000, fengshui_modifier=0.05)
        mgr = OfficeLayoutManager.create_chaotic_preset()
        run_studio(company, mgr, ["5"])
        self.assertEqual(company.cash, 10_000)
        self.assertEqual(company.fengshui_modifier, 0.05)


class TestCampaignFengShuiBase(unittest.TestCase):

    def test_campaign_keeps_scenario_modifier(self):
        """进入战役并直接推进时，应使用关卡自带的风水值而非恶煞布局的 -18%"""
        captured = {}
        real_simulate = CosmicSimulationEngine.simulate_month

        def spy(self, company, *a, **kw):
            captured.setdefault("mod", company.fengshui_modifier)
            return real_simulate(self, company, *a, **kw)

        inputs = ["B", "4", "Q"]
        with mock.patch.object(CosmicSimulationEngine, "simulate_month", spy), \
             mock.patch.object(play.EventSystem, "trigger_monthly_event", return_value=None), \
             mock.patch("builtins.input", side_effect=inputs), redirect_stdout(io.StringIO()):
            play.run_campaign_interactive(1)
        self.assertEqual(captured["mod"], 0.08)


if __name__ == "__main__":
    unittest.main()
