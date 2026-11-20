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

# ─────────────────────────────────────────────────────────────────────────────
# 候选人模板库（姓名·性格标签·专长·门派·适合岗位·薪资区间）
# ─────────────────────────────────────────────────────────────────────────────
_CANDIDATE_TEMPLATES = [
    # (name, gate, roles, salary_range, traits)
    ("陈破军", "xiu_men",   ["CEO", "COO"],        (180000, 280000), ["稳健", "守成", "抗压"]),
    ("李逢源", "sheng_men", ["CFO", "CEO"],         (200000, 320000), ["拓展", "野心", "社交"]),
    ("王惊雷", "jing_alarm_men", ["法务总监", "CMO"], (160000, 250000), ["善辩", "法务", "危机公关"]),
    ("张开泰", "kai_men",   ["CEO", "COO"],         (210000, 350000), ["领导力", "决断", "扩张"]),
    ("刘度势", "du_men",    ["CTO", "COO"],         (140000, 220000), ["隐忍", "分析", "数据"]),
    ("孙景明", "jing_men",  ["CMO", "CDO"],         (150000, 240000), ["品牌", "传播", "声望"]),
    ("赵伤锋", "shang_men", ["CSO", "COO"],         (170000, 260000), ["竞争", "销售", "激进"]),
    ("周死局", "si_men",    ["CFO", "风控总监"],    (130000, 200000), ["保守", "风控", "执行"]),
    ("吴惊风", "jing_alarm_men", ["CMO", "危机公关官"], (180000, 290000), ["应变", "舆情", "颠覆"]),
    ("郑休远", "xiu_men",   ["COO", "人力总监"],   (120000, 190000), ["养生", "平衡", "后勤"]),
    ("沈开拓", "kai_men",   ["CEO", "战略总监"],   (220000, 380000), ["开疆", "战略", "激进"]),
    ("韩生财", "sheng_men", ["CFO", "投资总监"],   (190000, 310000), ["财务", "融资", "增长"]),
    ("秦景辉", "jing_men",  ["CDO", "内容总监"],   (140000, 220000), ["内容", "IP", "创意"]),
    ("林伤破", "shang_men", ["CSO", "区域总监"],   (160000, 250000), ["开拓", "销售", "压迫"]),
    ("徐度衡", "du_men",    ["CTO", "算法总监"],   (200000, 340000), ["技术", "算法", "深度"]),
    ("曹休养", "xiu_men",   ["人力总监", "COO"],   (110000, 170000), ["培育", "团建", "文化"]),
    ("许开源", "kai_men",   ["CTO", "COO"],         (180000, 280000), ["开发", "架构", "效率"]),
    ("谢死守", "si_men",    ["CFO", "审计总监"],   (120000, 185000), ["合规", "审计", "守成"]),
    ("冯景策", "jing_men",  ["CMO", "战略总监"],   (160000, 260000), ["战略", "公关", "形象"]),
    ("蒋生旺", "sheng_men", ["CEO", "COO"],         (230000, 400000), ["成长", "扩张", "活力"]),
    ("叶惊变", "jing_alarm_men", ["危机公关官", "法务总监"], (170000, 270000), ["变革", "应变", "合规"]),
    ("彭度算", "du_men",    ["CFO", "数据总监"],   (155000, 240000), ["财务", "数据", "精算"]),
    ("魏开城", "kai_men",   ["CSO", "市场总监"],   (170000, 260000), ["城市扩张", "BD", "渠道"]),
    ("陆休止", "xiu_men",   ["COO", "供应链总监"], (135000, 210000), ["供应链", "运营", "节奏"]),
    ("丁伤锐", "shang_men", ["CSO", "销售总监"],   (160000, 255000), ["竞争", "谈判", "激进"]),
    ("薛死谋", "si_men",    ["CFO", "风控总监"],   (140000, 215000), ["谋划", "防守", "稳定"]),
    ("严景德", "jing_men",  ["CMO", "品牌总监"],   (150000, 230000), ["口碑", "品味", "公关"]),
    ("何生聚", "sheng_men", ["CEO", "投资总监"],   (200000, 360000), ["募资", "生态", "网络"]),
    ("龚开纪", "kai_men",   ["CTO", "工程总监"],   (175000, 275000), ["基础设施", "工程", "架构"]),
    ("袁度微", "du_men",    ["COO", "精益总监"],   (130000, 200000), ["精益", "数据", "优化"]),
    ("崔休稳", "xiu_men",   ["人力总监", "行政总监"],[105000, 165000], ["稳健", "团队", "文化"]),
    ("钱伤破", "shang_men", ["CEO", "CSO"],         (215000, 370000), ["进攻", "销售", "扩张"]),
    ("朱生发", "sheng_men", ["CFO", "CEO"],         (195000, 325000), ["财务", "融资", "生长"]),
    ("高景耀", "jing_men",  ["CMO", "CDO"],         (145000, 225000), ["内容", "品牌", "传播"]),
    ("梁死坚", "si_men",    ["CTO", "安全总监"],   (160000, 250000), ["安全", "合规", "坚守"]),
    ("侯开略", "kai_men",   ["CEO", "战略总监"],   (225000, 395000), ["战略", "开创", "格局"]),
    ("唐度析", "du_men",    ["数据总监", "CTO"],   (155000, 245000), ["分析", "洞察", "数据"]),
    ("孟休水", "xiu_men",   ["COO", "后勤总监"],   (115000, 175000), ["稳定", "后台", "运营"]),
    ("史惊天", "jing_alarm_men", ["CMO", "CEO"],    (220000, 385000), ["颠覆", "善辩", "震撼"]),
    ("傅伤先", "shang_men", ["CSO", "区域总监"],   (165000, 258000), ["先发", "销售", "推进"]),
]

# 薪资缩放：模板薪资 × 该系数 = 实际月薪（与战役高管 4.5万~7万/月 的量级对齐）
SALARY_SCALE = 0.35

# 门派名称映射
_GATE_NAMES = {
    "xiu_men":   "休门",
    "sheng_men": "生门",
    "jing_men":  "景门",
    "kai_men":   "开门",
    "du_men":    "杜门",
    "jing_alarm_men": "惊门",
    "shang_men": "伤门",
    "si_men":    "死门",
}


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

    def refresh_market(self, pool_size: int = 8) -> List[TalentCandidate]:
        """刷新人才市场，随机抽取 pool_size 名候选人"""
        self.quarter += 1
        sampled = random.sample(self._all_templates, min(pool_size, len(self._all_templates)))
        self.available = []
        for name, gate, roles, (sal_min, sal_max), traits in sampled:
            sal_min, sal_max = int(sal_min * SALARY_SCALE), int(sal_max * SALARY_SCALE)
            asking = random.randint(int(sal_min * 1.05), sal_max)
            minimum = int(sal_min * 0.90)
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
