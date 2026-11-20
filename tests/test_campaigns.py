#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
十大传奇商战关卡数理验证与关卡二/三单元测试套件
"""

import unittest
import os
import sys

current_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

from src import (
    Company, CosmicClock, CosmicSimulationEngine,
    CampaignManager
)

class TestAllCampaigns(unittest.TestCase):
    def test_all_10_scenarios_metadata(self):
        """验证全部10个战役剧本元数据完整性"""
        scenarios = CampaignManager.get_all_scenarios_meta()
        self.assertEqual(len(scenarios), 10, "必须完整包含10个战役关卡配置")
        for s in scenarios:
            self.assertIn("id", s)
            self.assertIn("title", s)
            self.assertIn("methodology", s)
            self.assertIn("choices", s)
            self.assertIn("A", s["choices"])
            self.assertIn("B", s["choices"])

    def test_scenario_2_time_algorithm(self):
        """
        验证案例二【时间算法】：
        方案A（2019Q3秋分前立决签下2000万对赌）能顺利挺过2020资本寒冬；
        方案B（拖延至2020Q1）在第5个月现金耗尽断粮破产。
        """
        # 方案 A: 提前融资
        comp_a, clock_a, meta_a = CampaignManager.setup_scenario_2()
        CampaignManager.apply_choice_scenario_2(comp_a, "A")
        eng_a = CosmicSimulationEngine(clock_a)
        bankrupt_a = False
        for m in range(15):
            stmt = eng_a.simulate_month(comp_a)
            if comp_a.cash <= 0:
                bankrupt_a = True
                break
            clock_a.advance_month()
        self.assertFalse(bankrupt_a, "方案A（2019Q3提前储备弹药）绝不应破产")
        self.assertGreater(comp_a.cash, 10000000.0, "方案A期末现金应大幅盈余（超千万）")

        # 方案 B: 拖延至2020Q1
        comp_b, clock_b, meta_b = CampaignManager.setup_scenario_2()
        CampaignManager.apply_choice_scenario_2(comp_b, "B")
        eng_b = CosmicSimulationEngine(clock_b)
        bankrupt_month = -1
        for m in range(15):
            stmt = eng_b.simulate_month(comp_b)
            if comp_b.cash <= 0:
                bankrupt_month = m + 1
                break
            clock_b.advance_month()
        self.assertGreater(bankrupt_month, 0, "方案B必然因现金流断裂破产")
        self.assertLessEqual(bankrupt_month, 6, "方案B在半年内必见底破产")

    def test_scenario_3_personnel_algorithm(self):
        """
        验证案例三【人物算法】：
        方案A（八门归位：景门主理人掌舵CEO、增聘休门COO）内耗降至5%以下，产出翻倍；
        方案B（强推量化惩罚）内耗激化，团队崩溃。
        """
        # 方案 A: 权力重构，八门归位
        comp_a, clock_a, meta_a = CampaignManager.setup_scenario_3()
        CampaignManager.apply_choice_scenario_3(comp_a, "A")
        eng_a = CosmicSimulationEngine(clock_a)
        f_person_a, p_info_a = eng_a.personnel_sys.calculate_personnel_factor(comp_a.executives)
        self.assertLessEqual(p_info_a["friction_ratio"], 0.05, "方案A内耗率应压制在5%以下")
        self.assertGreater(f_person_a, 1.10, "方案A综合人和因子应显著大于1.1")

        # 方案 B: 强行施压，维持错位
        comp_b, clock_b, meta_b = CampaignManager.setup_scenario_3()
        CampaignManager.apply_choice_scenario_3(comp_b, "B")
        eng_b = CosmicSimulationEngine(clock_b)
        f_person_b, p_info_b = eng_b.personnel_sys.calculate_personnel_factor(comp_b.executives)
        self.assertGreaterEqual(p_info_b["friction_ratio"], 0.25, "方案B内耗率应高达25%以上")
        self.assertLess(f_person_b, f_person_a, "方案B人和产出应显著低于方案A")

if __name__ == "__main__":
    unittest.main()
