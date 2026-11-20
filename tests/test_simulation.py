#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
单元测试与数理验证套件 (Unit Tests & Balance Verification)
"""

import unittest
import os
import sys

current_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

from src import (
    Company, Store, Executive, CosmicClock,
    NinePalacesSystem, PersonnelSystem, CosmicSimulationEngine,
    CampaignManager, SaveManager
)

class TestCosmicSimulation(unittest.TestCase):
    def setUp(self):
        self.clock = CosmicClock(start_year=2024, start_month=2)
        self.palace_sys = NinePalacesSystem()
        self.personnel_sys = PersonnelSystem()
        self.engine = CosmicSimulationEngine(self.clock)

    def test_cosmic_clock(self):
        f_time, details = self.clock.calculate_time_factor("Cultural_Food")
        self.assertGreater(f_time, 1.0, "离九运餐饮加成应当大于1.0")
        y, m = self.clock.advance_month()
        self.assertEqual(m, 3)
        self.assertEqual(y, 2024)

    def test_nine_palaces_affinity(self):
        # 离九宫文化餐饮亲和度应该高于坎一宫
        aff_li = self.palace_sys.calculate_store_space_factor("Cultural_Food", "li_9")
        aff_kan = self.palace_sys.calculate_store_space_factor("Cultural_Food", "kan_1")
        self.assertGreater(aff_li, aff_kan, "离九宫对文化餐饮亲和度应显著高于坎一宫")

    def test_personnel_friction_and_synergy(self):
        # 景门CEO + 生门CFO
        execs_good = [
            Executive("1", "CEO林", "jing_men", "景门", "CEO", 50000),
            Executive("2", "CFO沈", "sheng_men", "生门", "CFO", 40000),
        ]
        friction_good, clash_log_good = self.personnel_sys.calculate_internal_friction(execs_good)
        self.assertEqual(friction_good, 0.0, "景门CEO与生门CFO互补，内耗应为0")

        # 两伤相冲
        execs_clash = [
            Executive("1", "CEO林", "shang_men", "伤门", "CEO", 50000),
            Executive("2", "VP赵", "shang_men", "伤门", "VP_Expansion", 40000),
        ]
        friction_clash, clash_log_clash = self.personnel_sys.calculate_internal_friction(execs_clash)
        self.assertGreaterEqual(friction_clash, 0.25, "双伤门高管必然产生内耗")

    def test_campaign_scenario_1_divergence(self):
        """验证案例一：选离九宫(成都)优于选巽四宫(郑州/合肥)"""
        # 方案 A: 郑州/合肥
        comp_a, clock_a, _ = CampaignManager.setup_scenario_1()
        CampaignManager.apply_expansion_choice(comp_a, "A")
        eng_a = CosmicSimulationEngine(clock_a)
        for _ in range(12):
            eng_a.simulate_month(comp_a)
            clock_a.advance_month()

        # 方案 B: 成都/西安
        comp_b, clock_b, _ = CampaignManager.setup_scenario_1()
        CampaignManager.apply_expansion_choice(comp_b, "B")
        eng_b = CosmicSimulationEngine(clock_b)
        for _ in range(12):
            eng_b.simulate_month(comp_b)
            clock_b.advance_month()

        last_a = comp_a.financial_history[-1].net_profit
        last_b = comp_b.financial_history[-1].net_profit

        self.assertGreater(last_b, last_a, "方案B（文化高地共振）月净利应远超方案A（下沉低溢价）")
        self.assertGreater(comp_b.cash, comp_a.cash, "方案B全年现金沉淀应高于方案A")
        self.assertGreaterEqual(last_b, 12000000.0, "方案B第12个月净利应突破1200万达成通关")

    def test_save_manager(self):
        comp, clock, _ = CampaignManager.setup_scenario_1()
        save_file = SaveManager.save_game(comp, clock, scenario_id=1, slot_name="test_save")
        self.assertTrue(os.path.exists(save_file), "存档文件应当成功生成")
        # 清理测试存档
        if os.path.exists(save_file):
            os.remove(save_file)

if __name__ == "__main__":
    unittest.main()
