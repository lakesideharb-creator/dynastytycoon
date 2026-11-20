#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
地利九宫系统 (Nine Palaces System)
管理 3x3 后天洛书九宫地块属性、五行相生相克与门店租金坪效算法
"""

import json
import os
from typing import Dict, List, Optional

from . import tables

class NinePalacesSystem:
    def __init__(self, data_path: Optional[str] = None):
        if data_path is None:
            # 默认路径
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            data_path = os.path.join(base_dir, "data", "nine_palaces.json")

        self.palaces_data = {}
        if os.path.exists(data_path):
            with open(data_path, "r", encoding="utf-8") as f:
                raw = json.load(f)
                for item in raw.get("palaces", []):
                    self.palaces_data[item["id"]] = item
        
        # 行业对九宫的亲和度基准（data/engine_tables.json）
        self.industry_affinities = tables.engine()["industry_affinities"]

    def get_palace_info(self, palace_id: str) -> Dict:
        return self.palaces_data.get(palace_id, {
            "id": palace_id,
            "name": palace_id,
            "element": "Earth",
            "base_rent_multiplier": 1.0
        })

    def calculate_store_space_factor(self, industry: str, palace_id: str, fengshui_modifier: float = 0.0) -> float:
        affinity = self.industry_affinities.get(industry, {}).get(palace_id, 1.0)
        # 工位风水全局加成修正
        return round(affinity * (1.0 + fengshui_modifier), 3)

    def calculate_rent_cost(self, base_rent: float, palace_id: str) -> float:
        palace = self.get_palace_info(palace_id)
        multiplier = palace.get("base_rent_multiplier", 1.0)
        return round(base_rent * multiplier, 2)
