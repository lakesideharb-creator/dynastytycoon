#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
战役剧本系统 (Campaign Scenarios Manager)
关卡的开局配置（setup）、开局主决策（main_choices）与月度决策点（decision_points）
全部定义在 data/campaign_scenarios.json，这里只负责按数据搭建与执行。
"""

import json
import os
from typing import Dict, List, Optional, Tuple

from .models import Company
from .cosmic_clock import CosmicClock
from .effects import apply_effects, build_executive, build_stores


class CampaignManager:
    _scenarios_cache = None

    @classmethod
    def get_all_scenarios_meta(cls) -> List[Dict]:
        if cls._scenarios_cache is None:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            json_path = os.path.join(base_dir, "data", "campaign_scenarios.json")
            if os.path.exists(json_path):
                with open(json_path, "r", encoding="utf-8") as f:
                    cls._scenarios_cache = json.load(f).get("scenarios", [])
            else:
                cls._scenarios_cache = []
        return cls._scenarios_cache

    @classmethod
    def get_scenario_by_id(cls, s_id: int) -> Optional[Dict]:
        for s in cls.get_all_scenarios_meta():
            if s["id"] == s_id:
                return s
        return None

    @classmethod
    def is_playable(cls, s_id: int) -> bool:
        meta = cls.get_scenario_by_id(s_id)
        return bool(meta and "setup" in meta and "main_choices" in meta)

    # ─── 通用：按数据搭建关卡 ─────────────────────────────────────────────
    @classmethod
    def setup_scenario(cls, s_id: int) -> Tuple[Company, CosmicClock, Dict]:
        meta = cls.get_scenario_by_id(s_id)
        if not cls.is_playable(s_id):
            raise ValueError(f"关卡 {s_id} 尚未配置 setup / main_choices")
        st = meta["setup"]
        clock = CosmicClock(start_year=st["clock"]["year"], start_month=st["clock"]["month"])
        c = st["company"]
        company = Company(
            name=c["name"], industry=c["industry"], cash=c["cash"],
            executives=[build_executive(e) for e in st["executives"]],
            stores=[s for spec in st["stores"] for s in build_stores(spec)],
            fengshui_modifier=c["fengshui_modifier"], reputation=c["reputation"],
        )
        return company, clock, meta

    @classmethod
    def apply_main_choice(cls, s_id: int, company: Company, choice: str) -> str:
        choice = choice.upper()
        opt = cls.get_scenario_by_id(s_id).get("main_choices", {}).get(choice)
        if opt is None:
            return "无效选择。"
        apply_effects(company, opt["effects"])
        return opt["result"]

    # ─── 兼容旧接口 ───────────────────────────────────────────────────────
    @classmethod
    def setup_scenario_1(cls): return cls.setup_scenario(1)

    @classmethod
    def setup_scenario_2(cls): return cls.setup_scenario(2)

    @classmethod
    def setup_scenario_3(cls): return cls.setup_scenario(3)

    @classmethod
    def apply_choice_scenario_1(cls, company, choice): return cls.apply_main_choice(1, company, choice)

    @classmethod
    def apply_choice_scenario_2(cls, company, choice): return cls.apply_main_choice(2, company, choice)

    @classmethod
    def apply_choice_scenario_3(cls, company, choice): return cls.apply_main_choice(3, company, choice)

    apply_expansion_choice = apply_choice_scenario_1
