#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试套件：自由沙盒经营模式 & 人才市场系统
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import unittest
from src import SandboxGame, TalentPool, INDUSTRIES, PALACE_OPTIONS


class TestTalentPool(unittest.TestCase):

    def setUp(self):
        self.pool = TalentPool(seed=42)

    def test_pool_refresh(self):
        candidates = self.pool.available
        self.assertEqual(len(candidates), 8, "默认人才市场每季度应有8名候选人")
        first = candidates[0]
        self.assertTrue(first.asking_salary >= first.min_salary, "要价应大于等于底线薪资")

    def test_negotiation_and_hiring(self):
        c = self.pool.available[0]
        # 低于底线薪资应拒绝
        low_offer = c.min_salary - 10000
        self.assertFalse(self.pool.negotiate(c, low_offer))
        exec_fail = self.pool.hire(c, "COO", low_offer)
        self.assertIsNone(exec_fail)

        # 满足底线薪资应成功
        high_offer = c.asking_salary
        self.assertTrue(self.pool.negotiate(c, high_offer))
        exec_obj = self.pool.hire(c, "COO", high_offer)
        self.assertIsNotNone(exec_obj)
        self.assertEqual(exec_obj.name, c.name)
        self.assertEqual(exec_obj.role, "COO")
        self.assertEqual(exec_obj.salary, high_offer)
        self.assertNotIn(c, self.pool.available, "被雇佣的人选应移出候选池")


class TestSandboxGame(unittest.TestCase):

    def test_create_game(self):
        game = SandboxGame.create_new_game("天启文化", "Cultural_Food", 8_000_000, "li_9")
        summary = game.status_summary()
        self.assertEqual(summary["company_name"], "天启文化")
        self.assertEqual(summary["cash"], 8_000_000)
        self.assertEqual(summary["store_count"], 1)
        self.assertEqual(summary["executive_count"], 0)
        self.assertFalse(summary["is_bankrupt"])

    def test_advance_months(self):
        game = SandboxGame.create_new_game("灵枢医疗", "Health_Care", 12_000_000, "gen_8")
        res = game.advance_month(marketing_budget=50_000)
        self.assertIn("net_profit", res)
        self.assertIn("cash", res)
        self.assertEqual(res["turn"], 1)
        self.assertEqual(len(game.state.company.financial_history), 1)

    def test_open_store(self):
        game = SandboxGame.create_new_game("星汉能源", "New_Energy", 20_000_000, "zhen_3")
        ok, msg = game.open_new_store("杭州二号储能中心", "zhen_3", 5_000_000)
        self.assertTrue(ok)
        self.assertEqual(len(game.state.company.stores), 2)
        self.assertAlmostEqual(game.state.company.cash, 15_000_000, delta=1.0)

        # 资金不足应拒绝开店
        fail_ok, fail_msg = game.open_new_store("超预算中心", "kan_1", 30_000_000)
        self.assertFalse(fail_ok)
        self.assertIn("资金不足", fail_msg)

    def test_hire_talent_flow(self):
        game = SandboxGame.create_new_game("智道云", "AI_Tech", 15_000_000, "kan_1")
        game.refresh_talent_market()
        c = game.state.talent_pool.available[0]
        # 正常合理报价
        ok, msg = game.hire_talent(0, "CTO", c.asking_salary)
        self.assertTrue(ok)
        self.assertEqual(len(game.state.company.executives), 1)
        self.assertEqual(game.state.company.executives[0].name, c.name)

    def test_ending_evaluation(self):
        game = SandboxGame.create_new_game("太极商行", "Cultural_Food", 5_000_000, "li_9")
        ending = game.check_ending()
        self.assertIsNotNone(ending.grade)
        self.assertIn(ending.grade, ["S", "A", "B", "C", "D"])

    def test_bankruptcy_trigger(self):
        game = SandboxGame.create_new_game("脆断初创", "AI_Tech", 100_000, "kan_1")
        # 强制将现金设为巨额负数并推进，确保结算后依然为负
        game.state.company.cash = -50_000_000
        game.advance_month()
        self.assertTrue(game.state.is_bankrupt)
        ending = game.check_ending()
        self.assertEqual(ending.grade, "D", "负现金流应触发D级破产结局")


if __name__ == "__main__":
    unittest.main()
