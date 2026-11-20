#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
存档系统 (Save & Load System)
实现游戏进度快照导出与载入
"""

import json
import os
from dataclasses import asdict, dataclass, field
from typing import Dict, List, Optional
from .models import Company, Store, Executive, FinancialStatement
from .cosmic_clock import CosmicClock
from .office_fengshui import GridItem

SAVE_VERSION = 2


@dataclass
class LoadedGame:
    scenario_id: int
    company: Company
    clock: CosmicClock
    progress: Dict = field(default_factory=dict)        # 关卡进度，如 turn / decision_made
    office_items: List[GridItem] = field(default_factory=list)


class SaveManager:
    @staticmethod
    def get_save_dir() -> str:
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        save_dir = os.path.join(base_dir, "saves")
        os.makedirs(save_dir, exist_ok=True)
        return save_dir

    @classmethod
    def save_path(cls, slot_name: str) -> str:
        return os.path.join(cls.get_save_dir(), f"{slot_name}.json")

    # ─── 存档结构（与 Godot 端 core/save_game.gd 完全相同，两端存档可互读） ────────────
    @staticmethod
    def to_dict(company: Company, clock: CosmicClock, scenario_id: int,
                progress: Optional[Dict] = None, office_items: Optional[List[GridItem]] = None) -> Dict:
        return {
            "version": SAVE_VERSION,
            "scenario_id": scenario_id,
            "year": clock.year,
            "month": clock.month,
            "progress": progress or {},
            "office_items": [asdict(it) for it in (office_items or [])],
            "company": {
                "name": company.name,
                "industry": company.industry,
                "cash": company.cash,
                "reputation": company.reputation,
                "fengshui_modifier": company.fengshui_modifier,
                "active_gods": list(company.active_gods),
                "revenue_modifiers": [dict(m) for m in company.revenue_modifiers],
                "executives": [asdict(e) for e in company.executives],
                "stores": [asdict(s) for s in company.stores],
                "financial_history": [asdict(f) for f in company.financial_history],
            }
        }

    @staticmethod
    def from_dict(data: Dict) -> LoadedGame:
        """兼容 v1 旧存档（缺少的字段取默认值）"""
        c = data["company"]
        company = Company(
            name=c["name"],
            industry=c["industry"],
            cash=c["cash"],
            executives=[Executive(**e) for e in c.get("executives", [])],
            stores=[Store(**s) for s in c.get("stores", [])],
            fengshui_modifier=c.get("fengshui_modifier", 0.05),
            reputation=c.get("reputation", 70),
            active_gods=list(c.get("active_gods", [])),
            financial_history=[FinancialStatement(**f) for f in c.get("financial_history", [])],
            revenue_modifiers=[dict(m) for m in c.get("revenue_modifiers", [])],
        )
        clock = CosmicClock(start_year=data["year"], start_month=data["month"])
        return LoadedGame(
            scenario_id=data["scenario_id"],
            company=company,
            clock=clock,
            progress=data.get("progress", {}),
            office_items=[GridItem(**it) for it in data.get("office_items", [])],
        )

    @classmethod
    def save_game(
        cls,
        company: Company,
        clock: CosmicClock,
        scenario_id: int,
        slot_name: str = "quicksave",
        progress: Optional[Dict] = None,
        office_items: Optional[List[GridItem]] = None,
    ) -> str:
        save_path = cls.save_path(slot_name)
        with open(save_path, "w", encoding="utf-8") as f:
            json.dump(cls.to_dict(company, clock, scenario_id, progress, office_items), f, ensure_ascii=False, indent=2)
        return save_path

    @classmethod
    def load_game(cls, slot_name: str = "quicksave") -> Optional[LoadedGame]:
        """读取存档；文件不存在时返回 None"""
        save_path = cls.save_path(slot_name)
        if not os.path.exists(save_path):
            return None
        with open(save_path, "r", encoding="utf-8") as f:
            return cls.from_dict(json.load(f))

    @classmethod
    def has_save(cls, slot_name: str = "quicksave") -> bool:
        return os.path.exists(cls.save_path(slot_name))
