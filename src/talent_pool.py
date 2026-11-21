#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
商道玄机·人才市场随机生成池 (Talent Pool Generator)
维护一个40人候选库，每季度刷新，支持议价与雇佣
"""

import random
from dataclasses import dataclass, field
from typing import List, Optional
from .models import Executive

from . import tables

# 候选人模板库、薪资缩放与门派中文名都在 data/sandbox.json（Godot 端读同一份）
_DATA = tables.load("sandbox.json")
_ECON = _DATA["economy"]

# (name, gate, roles, salary_range, traits)
_CANDIDATE_TEMPLATES = [(t["name"], t["gate"], list(t["roles"]), tuple(t["salary_range"]), list(t["traits"]))
                        for t in _DATA["talent_templates"]]

# 薪资缩放：模板薪资 × 该系数 = 实际月薪（与战役高管 4.5万~7万/月 的量级对齐）
SALARY_SCALE = _ECON["talent_salary_scale"]
ASK_FLOOR = _ECON["talent_ask_floor"]          # 要价下限 = 缩放后最低薪资 × 该系数
MIN_RATIO = _ECON["talent_min_ratio"]          # 议价底线 = 缩放后最低薪资 × 该系数
POOL_SIZE = _ECON["talent_pool_size"]

# 门派名称映射
_GATE_NAMES = dict(_DATA["gate_names"])


@dataclass
class TalentCandidate:
    name: str
    gate: str           # 门派代码
    gate_name: str      # 门派中文
    eligible_roles: List[str]
    asking_salary: int  # 要价月薪
    min_salary: int     # 最低接受月薪（议价底线）
    traits: List[str]
    is_hired: bool = False
    stress: int = 0
    # 适配Executive的统一角色
    role: str = ""

    def to_executive(self, assigned_role: str, agreed_salary: int) -> Executive:
        """转换为可加入董事会的Executive对象"""
        import uuid
        return Executive(
            id=f"exec_{self.name[:4]}_{uuid.uuid4().hex[:6]}",
            name=self.name,
            gate_id=self.gate,
            gate_name=_GATE_NAMES.get(self.gate, self.gate),
            role=assigned_role,
            salary=agreed_salary,
            stress=self.stress,
            special_trait="·".join(self.traits[:2]) if self.traits else "",
        )


class TalentPool:
    """
    人才市场 — 每季度刷新，支持搜寻、议价与雇佣
    """

    def __init__(self, seed: Optional[int] = None):
        if seed is not None:
            random.seed(seed)
        self._all_templates = list(_CANDIDATE_TEMPLATES)
        self.available: List[TalentCandidate] = []
        self.quarter = 0
        self.refresh_market()

    def refresh_market(self, pool_size: int = POOL_SIZE) -> List[TalentCandidate]:
        """刷新人才市场，随机抽取 pool_size 名候选人"""
        self.quarter += 1
        sampled = random.sample(self._all_templates, min(pool_size, len(self._all_templates)))
        self.available = []
        for name, gate, roles, (sal_min, sal_max), traits in sampled:
            sal_min, sal_max = int(sal_min * SALARY_SCALE), int(sal_max * SALARY_SCALE)
            asking = random.randint(int(sal_min * ASK_FLOOR), sal_max)
            minimum = int(sal_min * MIN_RATIO)
            self.available.append(TalentCandidate(
                name=name,
                gate=gate,
                gate_name=_GATE_NAMES.get(gate, gate),
                eligible_roles=list(roles),
                asking_salary=asking,
                min_salary=minimum,
                traits=list(traits),
            ))
        return self.available

    def negotiate(self, candidate: TalentCandidate, offer: int) -> bool:
        """
        向候选人提出薪资 offer，返回是否接受
        接受条件：offer >= candidate.min_salary
        """
        return offer >= candidate.min_salary

    def hire(self, candidate: TalentCandidate, role: str, salary: int) -> Optional[Executive]:
        """
        完成雇佣，从市场移除该候选人，返回Executive对象
        """
        if candidate not in self.available:
            return None
        if not self.negotiate(candidate, salary):
            return None
        candidate.is_hired = True
        self.available.remove(candidate)
        return candidate.to_executive(role, salary)

    def display_market(self) -> str:
        """返回人才市场的格式化文本摘要"""
        lines = [f"═══ 第{self.quarter}季度人才市场（{len(self.available)}人在池）═══"]
        for i, c in enumerate(self.available, 1):
            roles_str = "/".join(c.eligible_roles[:2])
            traits_str = "·".join(c.traits[:3])
            lines.append(
                f"  [{i:2d}] {c.name:<6} 【{c.gate_name}】 "
                f"岗位:{roles_str:<14} 要价:¥{c.asking_salary:>7,}/月  "
                f"底线:¥{c.min_salary:>7,}/月  特质:{traits_str}"
            )
        return "\n".join(lines)
