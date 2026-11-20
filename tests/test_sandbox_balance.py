#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
沙盒经济机制与平衡性回归
- 机制：门店老化、维护折旧、投资规模、同宫饱和、关店残值、结局门槛
- 平衡：机器人玩家分布（tools/sandbox_balance.py）落在目标区间
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))

import random
import unittest
from collections import Counter

import sandbox_balance as bal
from src import SandboxGame, FinancialStatement
from src import sandbox as sb
from src.models import Store, STORE_DECAY_FLOOR


def new_game(cash=50_000_000):
    random.seed(0)
    return SandboxGame.create_new_game("测试", "Cultural_Food", cash, "kan_1")


class TestStoreMechanics(unittest.TestCase):

    def test_aging_reduces_revenue_to_floor(self):
        st = Store("s", "s", "li_9", "成都", 100.0, 0, 0, decay_rate=0.015)
        self.assertEqual(st.effective_base_revenue(), 100.0)
        st.age_months = 10
        self.assertAlmostEqual(st.effective_base_revenue(), 85.0)
        st.age_months = 1000
        self.assertAlmostEqual(st.effective_base_revenue(), 100.0 * STORE_DECAY_FLOOR)

    def test_campaign_stores_do_not_age(self):
        st = Store("s", "s", "li_9", "成都", 100.0, 0, 0)
        st.age_months = 120
        self.assertEqual(st.effective_base_revenue(), 100.0)

    def test_investment_scales_with_diminishing_returns(self):
        game = new_game()
        game.open_new_store("小", "li_9", sb.REF_STORE_INVEST)
        game.open_new_store("大", "zhen_3", sb.REF_STORE_INVEST * 4)
        small, big = game.state.company.stores[-2:]
        ratio = big.base_revenue / small.base_revenue
        self.assertAlmostEqual(ratio, 4 ** sb.INVEST_REVENUE_EXP, places=6)
        self.assertLess(ratio, 4)
        self.assertEqual(big.maintenance_cost, sb.REF_STORE_INVEST * 4 * sb.MAINTENANCE_RATE)

    def test_same_palace_saturation(self):
        game = new_game()
        game.open_new_store("一", "li_9", 2_000_000)
        game.open_new_store("二", "li_9", 2_000_000)
        first, second = game.state.company.stores[-2:]
        self.assertAlmostEqual(second.base_revenue / first.base_revenue, sb.PALACE_SATURATION)

    def test_rejects_investment_above_cap(self):
        ok, msg = new_game(cash=1e9).open_new_store("巨", "li_9", sb.MAX_STORE_INVEST + 1)
        self.assertFalse(ok)
        self.assertIn("上限", msg)

    def test_close_store_returns_salvage(self):
        game = new_game()
        game.open_new_store("分店", "li_9", 2_000_000)
        cash = game.state.company.cash
        store = game.state.company.stores[-1]
        ok, _ = game.close_store(store.id)
        self.assertTrue(ok)
        self.assertFalse(store.is_active)
        self.assertAlmostEqual(game.state.company.cash - cash, 2_000_000 * sb.STORE_SALVAGE_RATE)

    def test_cannot_close_last_store(self):
        game = new_game()
        ok, _ = game.close_store(game.state.company.stores[0].id)
        self.assertFalse(ok)
        self.assertTrue(game.state.company.stores[0].is_active)

    def test_best_palaces_match_affinity_table(self):
        aff = sb.NinePalacesSystem().industry_affinities
        for cfg in sb.INDUSTRIES.values():
            table = aff[cfg["key"]]
            self.assertEqual(len(table), 9, f"{cfg['key']} 缺少九宫亲和数据")
            self.assertEqual(table[cfg["best_palaces"][0]], max(table.values()))


class TestEndingRules(unittest.TestCase):

    def _with_history(self, monthly_profits, assets_cash):
        game = new_game(cash=assets_cash)
        c = game.state.company
        c.reputation = 95
        for _ in range(3):
            game.open_new_store("店", "zhen_3", 1_000_000)
        c.cash = assets_cash
        c.financial_history = [FinancialStatement(i, 0, 0, 0, 0, 0, 0, p, 0, 1, 1, 1)
                               for i, p in enumerate(monthly_profits)]
        return game

    def test_s_allows_seasonal_losing_months(self):
        """每年有亏损月份但年度盈利，仍满足"连续5个年度盈利" """
        year = [100_000] * 9 + [-50_000] * 3
        game = self._with_history(year * 5, sb.ENDING_S_ASSETS)
        self.assertEqual(game.check_ending().grade, "S")

    def test_s_requires_five_profitable_years(self):
        losing_year = [-100_000] * 12
        good_year = [100_000] * 12
        game = self._with_history(good_year * 4 + losing_year, sb.ENDING_S_ASSETS)
        self.assertNotEqual(game.check_ending().grade, "S")


class TestSandboxBalance(unittest.TestCase):
    """机器人玩家分布回归：数值改动若让沙盒失衡，这里会报警"""

    N = 150

    @classmethod
    def setUpClass(cls):
        cls.runs = []
        for seed in range(cls.N):
            rng = random.Random(seed)
            rng.choice([0] * 5)
            skill = rng.random()       # 与 play_bot 内部抽样顺序一致
            grade, turn, _ = bal.play_bot(seed)
            cls.runs.append((skill, grade, turn))

    def test_idle_company_goes_bankrupt_in_years_2_to_7(self):
        for cfg in sb.INDUSTRIES.values():
            turns = sorted(bal.play_bot(s, idle=True, industry=cfg["key"])[1] for s in range(5))
            with self.subTest(industry=cfg["key"]):
                self.assertTrue(24 <= turns[2] <= 84, f"放置破产月份中位数 {turns[2]}")

    def test_grade_distribution(self):
        dist = Counter(g for _, g, _ in self.runs)
        share = lambda g: dist[g] / self.N
        self.assertTrue(0.01 <= share("S") <= 0.15, f"S {share('S'):.0%}")
        self.assertTrue(0.15 <= share("A") <= 0.45, f"A {share('A'):.0%}")

    def test_skill_is_rewarded(self):
        def d_rate(lo, hi):
            tier = [g for sk, g, _ in self.runs if lo <= sk < hi]
            return sum(g == "D" for g in tier) / len(tier)
        expert, novice = d_rate(0.67, 1.01), d_rate(0.0, 0.33)
        self.assertLess(expert, 0.30, f"高手破产率 {expert:.0%}")
        self.assertGreater(novice, expert + 0.25, f"外行 {novice:.0%} vs 高手 {expert:.0%}")


if __name__ == "__main__":
    unittest.main()
