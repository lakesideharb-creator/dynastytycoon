#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
《商道玄机：大亨罗盘》核心数理模型验证沙盘引擎 (Simulation Engine)
公式核心：Performance = Base * f(Time) * f(Space) * f(Personnel) - FixedCost
"""

import json
from dataclasses import dataclass
from typing import Dict, List, Optional

@dataclass
class BusinessScenario:
    name: str
    industry: str            # 行业类型，如 Cultural_Food, AI_Tech
    base_revenue: float      # 月基础流水基数
    fixed_cost: float        # 月固定成本（含基础薪酬与常规开支）
    rent_base: float         # 基础租金

class CosmicSimulationEngine:
    def __init__(self):
        # 时代大运系数 (运势对各行业的加权)
        self.era_weights = {
            "Era_9_LiHuo": {  # 离九运 (2024-2043)
                "Cultural_Food": 1.45,
                "AI_Tech": 1.55,
                "Health_Care": 1.40,
                "Heavy_Industry": 0.70,
                "Traditional_RealEstate": 0.65
            }
        }
        
        # 季节月令系数 (1-12月)
        # 春(1-3月)木旺, 夏(4-6月)火旺, 秋(7-9月)金旺, 冬(10-12月)水旺
        self.season_multipliers = {
            "Spring": {"Wood": 1.30, "Fire": 1.10, "Earth": 0.90, "Metal": 0.85, "Water": 1.00},
            "Summer": {"Wood": 0.85, "Fire": 1.35, "Earth": 1.20, "Metal": 0.80, "Water": 0.80},
            "Autumn": {"Wood": 0.75, "Fire": 0.85, "Earth": 1.00, "Metal": 1.35, "Water": 1.15},
            "Winter": {"Wood": 1.10, "Fire": 0.70, "Earth": 0.85, "Metal": 1.05, "Water": 1.35}
        }

        # 宫位匹配字典
        self.palace_affinities = {
            "Cultural_Food": {
                "li_9": 1.45,     # 离九宫（文化品牌共振）
                "xun_4": 1.00,    # 巽四宫（平价渠道渗透）
                "kan_1": 0.60,    # 坎一宫（受克低迷）
                "zhen_3": 1.20    # 震三宫（木生火助长）
            },
            "AI_Tech": {
                "zhen_3": 1.50,   # 震三宫（科技创新高地）
                "li_9": 1.40,     # 离九宫（科技认知溢价）
                "qian_6": 1.30,   # 乾六宫（资本驱动）
                "gen_8": 0.75     # 艮八宫（重资产不匹配）
            }
        }

        # 八门适岗系数 (角色 vs 职责)
        self.gate_role_synergy = {
            ("CEO", "kai_men"): 1.35,
            ("CEO", "jing_men"): 1.25,
            ("CEO", "du_men"): 0.80,
            ("CFO", "sheng_men"): 1.40,
            ("CFO", "shang_men"): 0.70,
            ("CTO", "du_men"): 1.45,
            ("CTO", "kai_men"): 0.85,
            ("CMO", "jing_men"): 1.40,
            ("CMO", "du_men"): 0.65
        }

    def get_season(self, month: int) -> str:
        if month in [1, 2, 3]: return "Spring"
        if month in [4, 5, 6]: return "Summer"
        if month in [7, 8, 9]: return "Autumn"
        return "Winter"

    def calculate_month(
        self,
        scenario: BusinessScenario,
        month: int,
        era: str,
        palace_id: str,
        ceo_gate: str,
        cfo_gate: str,
        fengshui_modifier: float = 0.0
    ) -> Dict:
        # 1. 天时因子 f(T)
        era_mod = self.era_weights.get(era, {}).get(scenario.industry, 1.0)
        season = self.get_season(month)
        # 文化餐饮主火，AI主木/火
        industry_element = "Fire" if scenario.industry == "Cultural_Food" else "Wood"
        season_mod = self.season_multipliers[season][industry_element]
        f_time = era_mod * season_mod

        # 2. 空间因子 f(S)
        palace_affinity = self.palace_affinities.get(scenario.industry, {}).get(palace_id, 1.0)
        f_space = palace_affinity * (1.0 + fengshui_modifier)

        # 3. 人为因子 f(P)
        ceo_match = self.gate_role_synergy.get(("CEO", ceo_gate), 1.0)
        cfo_match = self.gate_role_synergy.get(("CFO", cfo_gate), 1.0)
        
        # 内耗计算
        friction_penalty = 0.0
        if ceo_gate == "shang_men" and cfo_gate == "shang_men":
            friction_penalty = 0.35  # 两伤相遇必内耗
        elif ceo_gate == "jing_men" and cfo_gate == "sheng_men":
            friction_penalty = -0.10 # 品牌愿景与算账务实完美互补

        f_person = (ceo_match * 0.5 + cfo_match * 0.5) * (1.0 - friction_penalty)

        # 4. 商业产出结算
        gross_revenue = scenario.base_revenue * f_time * f_space * f_person
        total_cost = scenario.fixed_cost + (scenario.rent_base * (1.5 if palace_id == "li_9" else 1.0))
        net_profit = gross_revenue - total_cost

        return {
            "month": month,
            "season": season,
            "f_time": round(f_time, 3),
            "f_space": round(f_space, 3),
            "f_person": round(f_person, 3),
            "gross_revenue": round(gross_revenue, 2),
            "total_cost": round(total_cost, 2),
            "net_profit": round(net_profit, 2)
        }

    def run_case_study_1_comparison(self):
        """还原原书案例一：国潮烘焙在 离九宫（成都/西安） vs 巽四宫（郑州/合肥）的经营对比"""
        print("=" * 60)
        print("【案例一数理沙盘验证】：国潮烘焙选址决策 (24个月回测)")
        print("=" * 60)

        bakery_scenario = BusinessScenario(
            name="国潮新烘焙A品牌",
            industry="Cultural_Food",
            base_revenue=800000.0,  # 80万/月
            fixed_cost=400000.0,
            rent_base=120000.0
        )

        for palace_id, label in [("li_9", "方案A：进入离九宫（西南成都/华中武汉）"), ("xun_4", "方案B：进入巽四宫（郑州/合肥等下沉通道）")]:
            total_net_profit = 0.0
            print(f"\n>>> 正在演算：{label}")
            for m in range(1, 13):
                # 假设CEO为景门人(品牌)，CFO为生门人(算账)，工位风水加成+10%
                res = self.calculate_month(
                    scenario=bakery_scenario,
                    month=m,
                    era="Era_9_LiHuo",
                    palace_id=palace_id,
                    ceo_gate="jing_men",
                    cfo_gate="sheng_men",
                    fengshui_modifier=0.10
                )
                total_net_profit += res["net_profit"]
                if m in [3, 6, 9, 12]:
                    print(f"  - 第 {m:02d} 月 [{res['season']}]: 月流水 ¥{res['gross_revenue']:,.0f} | 净利 ¥{res['net_profit']:,.0f} (f_S: {res['f_space']})")
            
            print(f"==> 全年累计净利润: ¥{total_net_profit:,.2f}")

if __name__ == "__main__":
    engine = CosmicSimulationEngine()
    engine.run_case_study_1_comparison()
