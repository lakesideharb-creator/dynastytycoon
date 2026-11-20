#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
恶性价格战反击与非对称博弈引擎 (Price War Defense Engine)
实现 WBS 5.2 面对百亿巨头价格屠杀时的专业差异化对冲与渠道反击数理模型
"""

from dataclasses import dataclass
from typing import Dict, Tuple
from .models import Company

@dataclass
class PriceWarScenario:
    attacker_name: str
    attacker_capital: float
    discount_rate: float            # 如 0.35 (五折至六五折)
    initial_market_share: float     # 玩家初始市占率

class PriceWarEngine:
    @staticmethod
    def simulate_battle(
        company: Company,
        strategy: str,
        scenario: PriceWarScenario
    ) -> Dict:
        """
        模拟应对恶性价格战的战略回报
        strategy:
          'A': 盲目跟进对耗 (-35%至-50%价格战)
          'B': 专业场景升维 (坚守原价，强化专业场景与技术壁垒)
          'C': 私域D2C绕道 (避开传统商超大卖场，深耕会员定制)
        """
        strategy = strategy.upper()

        if strategy == "A":
            # 盲目打价格战：毛利腰斩，巨头以大吃小
            margin_before = 0.65
            margin_after = 0.05
            monthly_loss = 2500000.0 # 每月失血 250 万
            company.cash -= monthly_loss * 3
            company.reputation -= 15
            # 策略A生存条件：剩余现金仍能支撑6个月（即cash > monthly_loss*6）
            is_survived = company.cash > monthly_loss * 6

            return {
                "strategy": "A (盲目跟进降价)",
                "survived": is_survived,
                "gross_margin": margin_after,
                "market_share": scenario.initial_market_share * 0.9,
                "financial_impact": -(monthly_loss * 3),
                "ending_cash": company.cash,
                "verdict": "【惨败·被动消耗】：巨头拥有500亿现金池，降价对其仅是九牛一毛，而你的微薄利润直接归零！连续三个月现金大失血，资金链濒临断裂。"
            }

        elif strategy == "B":
            # 专业场景升维：放弃大众低毛利货架，重兵压注健身房、马拉松、骑行圈层
            # 毛利率逆势提升，强化专业壁垒
            margin_after = 0.68
            revenue_growth = 0.40 # 专业高客单量增长
            marketing_cost = 1500000.0 # 赛事赞助与专业KOL背书费
            company.cash -= marketing_cost
            company.reputation += 25
            net_profit_gain = 3500000.0 # 细分高溢价带来丰厚利润
            company.cash += net_profit_gain

            return {
                "strategy": "B (专业差异化高维反击)",
                "survived": True,
                "gross_margin": margin_after,
                "market_share": scenario.initial_market_share * 1.35,
                "financial_impact": net_profit_gain - marketing_cost,
                "ending_cash": company.cash,
                "verdict": "【大胜·非对称突围】：绝不自降身段打泥坑战！通过占领专业运动高地，产品被封为'专业选手指定电解质'。大众去买巨头廉价货，高净值用户全面投奔你！"
            }

        elif strategy == "C":
            # 渠道绕道：私域会员直营
            margin_after = 0.55
            company.cash -= 800000.0
            company.reputation += 5
            company.cash += 1200000.0

            return {
                "strategy": "C (私域会员绕道直连)",
                "survived": True,
                "gross_margin": margin_after,
                "market_share": scenario.initial_market_share * 0.85,
                "financial_impact": 400000.0,
                "ending_cash": company.cash,
                "verdict": "【偏安一隅·平稳守成】：放弃大卖场二选一争夺，虽然规模增长受限，但凭借忠诚会员基本盘保住了一条活路。"
            }

        return {"error": "未知策略"}
