#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
战役推进器 (Campaign Runner)
与界面无关的战役状态机：开局主决策 → 每月结算 → 按月触发的数据驱动决策点 → 终局判定。
决策点与效果全部定义在 data/campaign_scenarios.json 的 "decision_points" 中，
效果类型刻意保持精简，便于 Godot 端以同一份 JSON 复刻（见 EFFECT_TYPES）。
"""

import copy
from typing import Dict, List, Optional, Tuple

from .models import Company, FinancialStatement
from .cosmic_clock import CosmicClock
from .simulation_engine import CosmicSimulationEngine
from .event_system import EventSystem
from .campaign import CampaignManager
from .effects import EFFECT_TYPES, apply_effects  # noqa: F401  apply_effects 供旧代码从此处导入

FENGSHUI_MIN, FENGSHUI_MAX = -0.25, 0.35


class CampaignRunner:
    def __init__(self, scenario_id: int, company: Optional[Company] = None,
                 clock: Optional[CosmicClock] = None, progress: Optional[Dict] = None):
        self.scenario_id = scenario_id
        fresh_company, fresh_clock, self.meta = CampaignManager.setup_scenario(scenario_id)
        self.company = company or fresh_company
        self.clock = clock or fresh_clock
        self.engine = CosmicSimulationEngine(self.clock)
        self.event_sys = EventSystem()
        progress = progress or {}
        self.turn: int = progress.get("turn", 1)                       # 当前第几个月（1 起）
        self.main_choice: Optional[str] = progress.get("main_choice")
        if self.main_choice is None and progress.get("decision_made"):
            self.main_choice = "?"                                     # 兼容 v1 存档
        self.event_choices: Dict[str, str] = dict(progress.get("event_choices", {}))
        self.bankrupt = False

    # ── 状态 ──────────────────────────────────────────────────────────────
    @property
    def duration(self) -> int:
        return self.meta.get("duration_months", 12)

    @property
    def is_finished(self) -> bool:
        return self.bankrupt or self.turn > self.duration

    def progress(self) -> Dict:
        return {"turn": self.turn, "main_choice": self.main_choice,
                "decision_made": self.main_choice is not None,
                "event_choices": dict(self.event_choices)}

    # ── 开局主决策 ────────────────────────────────────────────────────────
    def apply_main_choice(self, key: str) -> str:
        self.main_choice = key.upper()
        return CampaignManager.apply_main_choice(self.scenario_id, self.company, self.main_choice)

    # ── 月度决策点 ────────────────────────────────────────────────────────
    def _event_visible(self, ev: Dict) -> bool:
        need = ev.get("requires_main_choice")
        if need and self.main_choice not in need:
            return False
        for prior_id, keys in ev.get("requires_event_choice", {}).items():
            if self.event_choices.get(prior_id) not in keys:
                return False
        return True

    def pending_decisions(self) -> List[Dict]:
        return [ev for ev in self.meta.get("decision_points", [])
                if ev["turn"] == self.turn and ev["id"] not in self.event_choices and self._event_visible(ev)]

    def option_available(self, option: Dict) -> Tuple[bool, str]:
        gate = option.get("requires_gate")
        if gate and not any(e.gate_id == gate for e in self.company.executives):
            return False, f"需要{option.get('requires_gate_name', gate)}高管坐镇"
        cost = -sum(e["amount"] for e in option.get("effects", []) if e["type"] == "cash" and e["amount"] < 0)
        if cost and self.company.cash < cost:
            return False, f"现金不足 ¥{cost:,.0f}"
        return True, ""

    def apply_decision(self, event_id: str, key: str) -> Tuple[bool, str]:
        ev = next((e for e in self.pending_decisions() if e["id"] == event_id), None)
        if ev is None:
            return False, "该决策点当前不可用。"
        opt = next((o for o in ev["options"] if o["key"] == key.upper()), None)
        if opt is None:
            return False, "无效选项。"
        ok, reason = self.option_available(opt)
        if not ok:
            return False, reason
        notes = apply_effects(self.company, opt.get("effects", []))
        self.event_choices[event_id] = opt["key"]
        result = opt.get("result", "")
        return True, result + (f"（{'，'.join(notes)}）" if notes else "")

    # ── 月度结算 ──────────────────────────────────────────────────────────
    def simulate_month(self, marketing_budget: float = 0.0, random_events: bool = True
                       ) -> Tuple[FinancialStatement, Optional[Dict]]:
        stmt = self.engine.simulate_month(self.company, marketing_budget=marketing_budget)
        evt = self.event_sys.trigger_monthly_event(self.company, self.clock.month) if random_events else None
        if self.company.cash < 0:
            self.bankrupt = True
        return stmt, evt

    def advance(self):
        self.clock.advance_month()
        self.turn += 1

    # ── 终局 ──────────────────────────────────────────────────────────────
    def check_win(self) -> bool:
        if self.bankrupt:
            return False
        return check_win_condition(self.company, self.engine, self.meta)


def check_win_condition(company: Company, engine: CosmicSimulationEngine, meta: Dict) -> bool:
    """按 campaign_scenarios.json 中的 win_condition 判定通关"""
    wc = meta.get("win_condition", {})
    if company.cash < wc.get("min_cash", 0) or company.cash <= 0:
        return False
    if "final_month_profit" in wc:
        if not company.financial_history or company.financial_history[-1].net_profit < wc["final_month_profit"]:
            return False
    if "max_friction" in wc:
        _, p_info = engine.personnel_sys.calculate_personnel_factor(company.executives)
        if p_info["friction_ratio"] > wc["max_friction"]:
            return False
    return True


def enumerate_paths(scenario_id: int) -> List[Tuple[str, "CampaignRunner"]]:
    """穷举开局主决策 × 全部月度决策点选项（不含随机事件），返回 [(路径, 结束时的 runner)]"""
    results = []

    def run_from(runner: CampaignRunner, path: List[str]):
        while not runner.is_finished:
            pending = runner.pending_decisions()
            if pending:
                ev = pending[0]
                for opt in ev["options"]:
                    if not runner.option_available(opt)[0]:
                        continue
                    branch = copy.deepcopy(runner)
                    branch.apply_decision(ev["id"], opt["key"])
                    run_from(branch, path + [f"{ev['id']}={opt['key']}"])
                return
            runner.simulate_month(random_events=False)
            if not runner.bankrupt:
                runner.advance()
        results.append(("|".join(path), runner))

    for main in "ABC":
        r = CampaignRunner(scenario_id)
        r.apply_main_choice(main)
        run_from(r, [main])
    return results
