#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
经营复盘解读 (Monthly Insight)
把 f(T)·f(S)·f(P) 的数值拆解成玩家看得懂、学得会的因果说明，并给出下月天时预告。
"""

from collections import Counter
from typing import List

from .models import Company
from .cosmic_clock import CosmicClock
from .simulation_engine import CosmicSimulationEngine
from . import tables

INDUSTRY_ELEMENT = tables.engine()["industry_elements"]
INDUSTRY_NAME = tables.engine()["industry_names"]
SEASON_ELEMENT = {"Spring": "Wood", "Summer": "Fire", "Autumn": "Metal", "Winter": "Water"}
SEASON_CN = {"Spring": "春", "Summer": "夏", "Autumn": "秋", "Winter": "冬"}
ELEMENT_CN = {"Wood": "木", "Fire": "火", "Earth": "土", "Metal": "金", "Water": "水"}
GENERATES = {"Wood": "Fire", "Fire": "Earth", "Earth": "Metal", "Metal": "Water", "Water": "Wood"}
OVERCOMES = {"Wood": "Earth", "Earth": "Water", "Water": "Fire", "Fire": "Metal", "Metal": "Wood"}


def season_relation(season_elem: str, industry_elem: str) -> str:
    """旺相休囚死：当令五行与行业五行的关系"""
    s, i = ELEMENT_CN[season_elem], ELEMENT_CN[industry_elem]
    if season_elem == industry_elem:
        return f"旺·{s}当令，与行业同气"
    if GENERATES[season_elem] == industry_elem:
        return f"相·{s}生{i}，得令相助"
    if GENERATES[industry_elem] == season_elem:
        return f"休·{i}生{s}，行业泄气"
    if OVERCOMES[industry_elem] == season_elem:
        return f"囚·{i}克{s}，耗力难展"
    return f"死·{s}克{i}，受制最重"


def time_lines(clock: CosmicClock, industry: str, prefix: str = "") -> List[str]:
    f_t, d = clock.calculate_time_factor(industry)
    season = clock.get_season_key(clock.month)
    ind_elem = INDUSTRY_ELEMENT.get(industry, "Fire")
    rel = season_relation(SEASON_ELEMENT[season], ind_elem)
    return [
        f"{prefix}天时 ×{f_t:.2f} = 大运 ×{d['era_mod']:.2f}"
        f" · {SEASON_CN[season]}季【{rel}】×{d['season_mod']:.2f}"
        f" · {d['sha_name']} ×{d['sha_mod']:.2f}",
    ]


def explain_month(company: Company, engine: CosmicSimulationEngine) -> List[str]:
    """在 simulate_month 之后、advance_month 之前调用，解读刚结算的这个月"""
    lines = []
    clock = engine.clock
    ind = INDUSTRY_NAME.get(company.industry, company.industry)
    ind_elem = ELEMENT_CN[INDUSTRY_ELEMENT.get(company.industry, "Fire")]
    lines.append(f"【天时】{ind}属{ind_elem}。" + time_lines(clock, company.industry)[0])
    _, d = clock.calculate_time_factor(company.industry)
    lines.append(f"        {d['sha_desc']}")

    # 地利：按宫位汇总门店
    active = [s for s in company.stores if s.is_active]
    by_palace = Counter(s.palace_id for s in active)
    parts = []
    for pid, n in by_palace.most_common():
        aff = engine.palaces_sys.industry_affinities.get(company.industry, {}).get(pid, 1.0)
        name = engine.palaces_sys.get_palace_info(pid).get("name", pid)
        parts.append(f"{name} {n}处 ×{aff:.2f}")
    lines.append(f"【地利】" + "；".join(parts) + f"（另含风水修正 {company.fengshui_modifier * 100:+.0f}%）")

    # 人和
    f_p, p = engine.personnel_sys.calculate_personnel_factor(company.executives)
    lines.append(f"【人和】×{f_p:.2f} = 平均适岗 {p['avg_match_score']:.2f} × (1 − 内耗 {p['friction_ratio'] * 100:.0f}%)")
    for clash in p["clash_log"][:3]:
        lines.append(f"        {clash}")
    stressed = [e for e in company.executives if e.stress > 60]
    for e in stressed:
        lines.append(f"        ⚠ {e.role}{e.name} 压力 {e.stress}（>60 开始拖累表现）")

    # 营收修正器
    for m in company.revenue_modifiers:
        span = f"剩{m['months_left']}个月" if m.get("months_left") else "长期"
        lines.append(f"【决策余波】{m.get('label', '营收修正')} ×{m['factor']:.2f}（{span}）")
    return lines


def forecast_next_month(clock: CosmicClock, industry: str) -> str:
    nxt = CosmicClock(clock.year, clock.month)
    nxt.advance_month()
    f_now, _ = clock.calculate_time_factor(industry)
    f_next, _ = nxt.calculate_time_factor(industry)
    trend = "↑" if f_next > f_now + 1e-9 else ("↓" if f_next < f_now - 1e-9 else "→")
    return f"【下月预告】{nxt.year}年{nxt.month:02d}月 " + time_lines(nxt, industry)[0] + f"  {trend}"
