#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试套件：危机公关战备指挥室 & 恶性价格战引擎
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import unittest
from src import PRCrisisWarRoom, CrisisStage, CrisisOption, PriceWarEngine, PriceWarScenario
from src.models import Company, Store


def _make_company(cash: float = 50_000_000, reputation: int = 60) -> Company:
    return Company(
        name="测试社交电商平台",
        industry="Social_Commerce",
        cash=cash,
        reputation=reputation
    )


class TestPRCrisisWarRoom(unittest.TestCase):

    # ── A1: stage1_deny → 怒火上升、信任下降 ──────────────────────────────────
    def test_stage1_deny_increases_anger(self):
        room = PRCrisisWarRoom.create_weight_loss_drug_crisis()
        company = _make_company()
        initial_anger = room.public_anger          # 80
        initial_trust = room.brand_trust           # 35
        ok, log = room.execute_choice("stage1_deny", company)
        self.assertTrue(ok, "execute_choice 应该返回 True")
        self.assertGreater(room.public_anger, initial_anger, "选择推脱掩饰后怒火应上升")
        self.assertLess(room.brand_trust, initial_trust, "选择推脱掩饰后信任度应下降")

    # ── A2: stage1_active → 怒火下降、信任上升 ───────────────────────────────
    def test_stage1_active_decreases_anger(self):
        room = PRCrisisWarRoom.create_weight_loss_drug_crisis()
        company = _make_company()
        initial_anger = room.public_anger
        ok, log = room.execute_choice("stage1_active", company)
        self.assertTrue(ok)
        self.assertLess(room.public_anger, initial_anger, "积极应对后怒火应下降")

    # ── A3: 完整胜利路径 → 绝处逢生 ─────────────────────────────────────────
    def test_full_win_path_verdict(self):
        """积极→诚恳发布会→千万质保金 → 最终怒火≤35，信任≥60，verdict含'绝处逢生'"""
        room = PRCrisisWarRoom.create_weight_loss_drug_crisis()
        company = _make_company(cash=100_000_000)

        room.execute_choice("stage1_active", company)   # 阶段1
        room.execute_choice("stage2_press_sincere", company)  # 阶段2
        room.execute_choice("stage3_fund", company)     # 阶段3

        self.assertTrue(room.is_resolved, "24小时后应标记为已解决")
        self.assertLessEqual(room.public_anger, 35,
                             f"胜利路径怒火应≤35，实际={room.public_anger}")
        self.assertGreaterEqual(room.brand_trust, 60,
                                f"胜利路径信任应≥60，实际={room.brand_trust}")
        self.assertIn("绝处逢生", room.verdict, f"verdict应含'绝处逢生'，实际={room.verdict}")

    # ── A4: 完整失败路径 → 提前触发监管封杀 ─────────────────────────────────
    def test_full_lose_path_early_fail(self):
        """推脱→官样通稿 → 怒火≥85，提前终局封杀"""
        room = PRCrisisWarRoom.create_weight_loss_drug_crisis()
        company = _make_company()

        # stage1_deny: anger +20 → 100 (capped), trust -25 → 10
        room.execute_choice("stage1_deny", company)
        # 此时怒火已≥85，应立即标记失败
        if room.is_resolved:
            self.assertIn("监管封杀", room.verdict)
            return

        # stage2_bureaucratic: anger +15
        room.execute_choice("stage2_bureaucratic", company)
        self.assertTrue(room.is_resolved, "双重错误选择后应触发提前失败")
        self.assertIn("监管封杀", room.verdict, f"verdict应含'监管封杀'，实际={room.verdict}")

    # ── A5: 资金扣除正确 ─────────────────────────────────────────────────────
    def test_cost_deducted_from_company(self):
        room = PRCrisisWarRoom.create_weight_loss_drug_crisis()
        company = _make_company(cash=50_000_000)
        room.execute_choice("stage1_active", company)   # cost=800_000
        self.assertAlmostEqual(company.cash, 50_000_000 - 800_000, places=0)


class TestPriceWarEngine(unittest.TestCase):

    def _make_scenario(self):
        return PriceWarScenario(
            attacker_name="百亿巨头饮品集团",
            attacker_capital=10_000_000_000,
            discount_rate=0.35,
            initial_market_share=0.15
        )

    # ── B1: 策略A → 现金大幅流失，净财务影响为负 ────────────────────────────
    def test_strategy_a_cash_loss(self):
        """盲目跟进降价：3个月失血750万，净财务影响必须为负数"""
        company = _make_company(cash=30_000_000)
        result = PriceWarEngine.simulate_battle(company, "A", self._make_scenario())
        self.assertLess(result["financial_impact"], 0,
                        f"策略A净财务影响应为负，实际={result['financial_impact']}")
        # 现金应显著减少（>500万损失）
        self.assertLess(result["ending_cash"], 30_000_000 - 5_000_000,
                        f"策略A应损失≥500万，实际cash={result['ending_cash']}")

    # ── B2: 策略B → 现金增加、市占率增长 ─────────────────────────────────────
    def test_strategy_b_cash_positive(self):
        company = _make_company(cash=30_000_000)
        result = PriceWarEngine.simulate_battle(company, "B", self._make_scenario())
        self.assertTrue(result["survived"])
        self.assertGreater(result["financial_impact"], 0,
                           "差异化策略应净利润为正")
        self.assertGreater(result["market_share"], 0.15,
                           "策略B市占率应超过初始值0.15")

    # ── B3: 策略C → 保住现金正流 ─────────────────────────────────────────────
    def test_strategy_c_survived(self):
        company = _make_company(cash=30_000_000)
        result = PriceWarEngine.simulate_battle(company, "C", self._make_scenario())
        self.assertTrue(result["survived"])
        self.assertGreater(result["financial_impact"], 0,
                           "渠道绕道策略应维持正向现金流")

    # ── B4: 策略大小写不敏感 ─────────────────────────────────────────────────
    def test_strategy_case_insensitive(self):
        company = _make_company()
        result = PriceWarEngine.simulate_battle(company, "b", self._make_scenario())
        self.assertNotIn("error", result, "小写策略键应同样有效")


if __name__ == "__main__":
    unittest.main()
