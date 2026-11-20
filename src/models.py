#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
数据模型层 (Data Models)
定义九宫、八门、八神、企业主体、高管、财务报表等核心结构体
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional
import json
import os

@dataclass
class Executive:
    id: str
    name: str
    gate_id: str             # 如 kai_men, sheng_men, etc.
    gate_name: str           # 开门, 生门
    role: str                # CEO, CFO, CTO, CMO, VP_Expansion
    salary: float            # 月薪 (元)
    loyalty: int = 80        # 忠诚度 0-100
    stress: int = 20         # 压力值 0-100
    special_trait: str = ""

# 门店老化后营收最低保留比例
STORE_DECAY_FLOOR = 0.65

@dataclass
class Store:
    id: str
    name: str
    palace_id: str           # 所在九宫ID，如 li_9, xun_4
    city_name: str           # 成都、合肥、上海等
    base_revenue: float      # 月基础营收
    rent: float              # 月租金
    staff_cost: float        # 月人工运营成本
    is_active: bool = True
    age_months: int = 0              # 已营业月数
    decay_rate: float = 0.0          # 每月营收衰减率（门店老化/竞品侵蚀），战役门店为 0
    maintenance_cost: float = 0.0    # 每月折旧与维护支出
    invest: float = 0.0              # 开店投资额（关店时按比例回收残值）

    def effective_base_revenue(self) -> float:
        """计入老化衰减后的月基础营收"""
        factor = max(STORE_DECAY_FLOOR, 1.0 - self.decay_rate * self.age_months)
        return self.base_revenue * factor

@dataclass
class FinancialStatement:
    month: int
    gross_revenue: float
    rent_expense: float
    payroll_expense: float
    marketing_expense: float
    miscellaneous_cost: float
    total_cost: float
    net_profit: float
    ending_cash: float
    f_time: float
    f_space: float
    f_person: float
    maintenance_expense: float = 0.0

def modifier_targets_store(modifier: Dict, store: "Store") -> bool:
    prefixes = modifier.get("id_prefix")
    palaces = modifier.get("palace")
    if prefixes and not any(store.id.startswith(p) for p in prefixes):
        return False
    if palaces and store.palace_id not in palaces:
        return False
    return True

@dataclass
class Company:
    name: str
    industry: str            # Cultural_Food, AI_Tech, Health_Care
    cash: float              # 当前现金
    executives: List[Executive] = field(default_factory=list)
    stores: List[Store] = field(default_factory=list)
    fengshui_modifier: float = 0.05   # 工位风水全局修正 (-0.30 ~ +0.30)
    reputation: int = 70              # 企业商誉/公关值 0-100
    active_gods: List[str] = field(default_factory=list) # 激活的神煞ID
    financial_history: List[FinancialStatement] = field(default_factory=list)
    # 营收修正器：{"factor": 1.1, "months_left": 3 或 None(永久), "id_prefix": [...] 可选, "palace": [...] 可选, "label": "..."}
    revenue_modifiers: List[Dict] = field(default_factory=list)

    def store_revenue_multiplier(self, store: "Store") -> float:
        mult = 1.0
        for m in self.revenue_modifiers:
            if modifier_targets_store(m, store):
                mult *= m["factor"]
        return mult

    def tick_revenue_modifiers(self):
        """月末递减临时修正器的剩余月数，到期移除"""
        kept = []
        for m in self.revenue_modifiers:
            if m.get("months_left") is None:
                kept.append(m)
            elif m["months_left"] > 1:
                m["months_left"] -= 1
                kept.append(m)
        self.revenue_modifiers = kept

    def total_monthly_payroll(self) -> float:
        return sum(e.salary for e in self.executives)

    def total_monthly_rent(self) -> float:
        return sum(s.rent for s in self.stores if s.is_active)

    def get_executive_by_role(self, role: str) -> Optional[Executive]:
        for e in self.executives:
            if e.role == role:
                return e
        return None
