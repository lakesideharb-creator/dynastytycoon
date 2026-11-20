#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
24小时突发危机公关战备指挥室 (24-Hour PR Crisis War Room)
实现 WBS 5.1 倒计时战备回合判定流，模拟舆论温度、公关策略与八门技能协同。
阶段、选项与终局裁决都在 data/crisis_scenarios.json（Godot 端 godot/core/crisis_war_room.gd 读同一份）。
"""

from dataclasses import dataclass, field
from typing import Dict, List, Tuple, Optional
from .models import Company, Executive
from . import tables

DEFAULT_CRISIS = "weight_loss_drug"


def _data() -> dict:
    return tables.load("crisis_scenarios.json")


ANGER_BAN_LINE = _data()["anger_ban_line"]       # 怒火 >= 此值：监管封杀
TRUST_DEATH_LINE = _data()["trust_death_line"]   # 信任 <= 此值：品牌社会性死亡


def crisis_def(crisis_id: str = DEFAULT_CRISIS) -> dict:
    return next(c for c in _data()["crises"] if c["id"] == crisis_id)


@dataclass
class CrisisOption:
    id: str
    title: str
    description: str
    cost: float
    anger_delta: int       # 怒火值变动 (负数代表降温)
    trust_delta: int       # 信任度变动 (正数代表修复)
    special_gate: str = "" # 专属高管门派要求 (如 jing_men, jing_alarm_men)


@dataclass
class CrisisStage:
    stage_id: int
    name: str
    hours_range: str       # 如 "00:00 - 04:00"
    event_headline: str
    options: List[CrisisOption]
    end_hour: int = 24


def _stage_from(d: dict) -> CrisisStage:
    return CrisisStage(
        stage_id=d["stage_id"], name=d["name"], hours_range=d["hours_range"],
        event_headline=d["event_headline"], end_hour=d["end_hour"],
        options=[CrisisOption(id=o["id"], title=o["title"], description=o["description"], cost=float(o["cost"]),
                              anger_delta=int(o["anger_delta"]), trust_delta=int(o["trust_delta"]),
                              special_gate=o.get("special_gate", "")) for o in d["options"]])


class PRCrisisWarRoom:
    def __init__(self, crisis_title: str, initial_anger: int = 75, initial_trust: int = 40,
                 crisis_id: str = DEFAULT_CRISIS):
        self.crisis_id = crisis_id
        self.title = crisis_title
        self.hour = 0
        self.public_anger = initial_anger   # 怒火值 0-100 (>=85 触发监管顶格封杀)
        self.brand_trust = initial_trust    # 品牌信任度 0-100 (<=15 品牌社会性死亡)
        self.total_cost_spent = 0.0
        self.action_logs: List[str] = []
        self.choices: List[str] = []
        self.is_resolved = False
        self.verdict = ""
        self.verdict_key = ""

    @classmethod
    def from_data(cls, crisis_id: str = DEFAULT_CRISIS) -> "PRCrisisWarRoom":
        d = crisis_def(crisis_id)
        return cls(d["title"], d["initial_anger"], d["initial_trust"], crisis_id)

    @staticmethod
    def create_weight_loss_drug_crisis() -> "PRCrisisWarRoom":
        """生成案例十：社交电商平台假减肥药爆雷事件"""
        return PRCrisisWarRoom.from_data("weight_loss_drug")

    @staticmethod
    def create_company(crisis_id: str = DEFAULT_CRISIS) -> Company:
        """指挥室所属公司与在场高管（数据中的 company 段）"""
        c = crisis_def(crisis_id)["company"]
        execs = [Executive(e["id"], e["name"], e["gate_id"], e["gate_name"], e["role"], e["salary"],
                           portrait=e.get("portrait", "")) for e in c["executives"]]
        return Company(c["name"], c["industry"], float(c["cash"]), reputation=c["reputation"], executives=execs)

    def stages(self) -> List[CrisisStage]:
        return [_stage_from(s) for s in crisis_def(self.crisis_id)["stages"]]

    def get_current_stage(self) -> Optional[CrisisStage]:
        return next((s for s in self.stages() if self.hour < s.end_hour), None)

    @staticmethod
    def has_required_gate(option: CrisisOption, company: Company) -> bool:
        if not option.special_gate:
            return True
        return any(e.gate_id == option.special_gate for e in company.executives)

    @classmethod
    def effective_deltas(cls, option: CrisisOption, company: Company) -> Tuple[int, int]:
        if cls.has_required_gate(option, company):
            return option.anger_delta, option.trust_delta
        return int(option.anger_delta / 2), int(option.trust_delta / 2)

    def _resolve(self, key: str, company: Company) -> None:
        v = crisis_def(self.crisis_id)["verdicts"][key]
        self.is_resolved = True
        self.verdict_key = key
        self.verdict = v["text"]
        rep = company.reputation + v["reputation_delta"]
        if "reputation_min" in v:
            rep = max(v["reputation_min"], rep)
        if "reputation_max" in v:
            rep = min(v["reputation_max"], rep)
        company.reputation = rep

    def execute_choice(self, option_id: str, company: Company) -> Tuple[bool, str]:
        stage = self.get_current_stage()
        if not stage:
            return False, "危机处理阶段已结束。"

        selected_opt = next((o for o in stage.options if o.id == option_id), None)
        if not selected_opt:
            return False, "无效的选项编号。"

        # 扣除应对资金
        company.cash -= selected_opt.cost
        self.total_cost_spent += selected_opt.cost
        self.choices.append(option_id)

        # 专属门派选项：缺少对应高管时效果减半
        anger_delta, trust_delta = self.effective_deltas(selected_opt, company)
        gate_note = "" if self.has_required_gate(selected_opt, company) else " (缺少专属高管·效果减半)"

        # 调整指标
        self.public_anger = max(0, min(100, self.public_anger + anger_delta))
        self.brand_trust = max(0, min(100, self.brand_trust + trust_delta))

        # 记录日志
        log_entry = f"[{stage.hours_range}] 决断：{selected_opt.title}{gate_note} | 怒火 {anger_delta:+d} (现:{self.public_anger}) | 信任 {trust_delta:+d} (现:{self.brand_trust})"
        self.action_logs.append(log_entry)

        # 时间推进到本阶段结束
        self.hour = stage.end_hour

        # 检查是否提前失败
        if self.public_anger >= ANGER_BAN_LINE:
            self._resolve("ban", company)
            return True, log_entry
        if self.brand_trust <= TRUST_DEATH_LINE:
            self._resolve("trust_death", company)
            return True, log_entry

        # 24小时满期终局结算
        if self.get_current_stage() is None:
            v = crisis_def(self.crisis_id)["verdicts"]
            if self.public_anger <= v["excellent"]["max_anger"] and self.brand_trust >= v["excellent"]["min_trust"]:
                self._resolve("excellent", company)
            elif self.public_anger <= v["mediocre"]["max_anger"]:
                self._resolve("mediocre", company)
            else:
                self._resolve("failed", company)

        return True, log_entry
