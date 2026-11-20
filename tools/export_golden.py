#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
导出"标准答案"数据：Python 引擎在固定输入下的全部结算结果，供 Godot 端逐项对照。
默认输出到 godot/tests/golden/。不含随机事件（两端随机数不同，事件逻辑单独测）。

用法：python3 tools/export_golden.py [--out 目录]
"""
import argparse
import json
import os
import sys
from dataclasses import asdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from src.campaign_runner import CampaignRunner, enumerate_paths
from src.cosmic_clock import CosmicClock
from src.insight import explain_month, forecast_next_month
from src.models import Executive
from src.nine_palaces import NinePalacesSystem
from src.personnel import PersonnelSystem

INDUSTRIES = ["Cultural_Food", "AI_Tech", "Health_Care", "New_Energy", "Social_Commerce",
              "Traditional_Manufacturing", "Traditional_RealEstate", "Unknown_Industry"]
PALACES = ["kan_1", "kun_2", "zhen_3", "xun_4", "zhong_5", "qian_6", "dui_7", "gen_8", "li_9"]
GATES = ["kai_men", "xiu_men", "sheng_men", "shang_men", "du_men", "jing_men", "si_men", "jing_alarm_men"]
ROLES = ["CEO", "CFO", "CTO", "CMO", "COO", "VP_Expansion", "法务总监"]


def replay(scenario_id: int, path: str) -> dict:
    main, *picks = path.split("|")
    picks = dict(p.split("=") for p in picks)
    r = CampaignRunner(scenario_id)
    r.apply_main_choice(main)
    months = []
    while not r.is_finished:
        for ev in r.pending_decisions():
            r.apply_decision(ev["id"], picks[ev["id"]])
        stmt, _ = r.simulate_month(random_events=False)
        months.append({
            "statement": asdict(stmt),
            "cash": r.company.cash,
            "explain": explain_month(r.company, r.engine),
            "forecast": forecast_next_month(r.clock, r.company.industry),
        })
        if not r.bankrupt:
            r.advance()
    _, p = r.engine.personnel_sys.calculate_personnel_factor(r.company.executives)
    return {
        "path": path,
        "months": months,
        "win": r.check_win(),
        "bankrupt": r.bankrupt,
        "final_cash": r.company.cash,
        "friction": p["friction_ratio"],
        "reputation": r.company.reputation,
        "fengshui": r.company.fengshui_modifier,
        "executives": [asdict(e) for e in r.company.executives],
        "active_stores": sum(1 for s in r.company.stores if s.is_active),
    }


def factor_tables() -> dict:
    time_rows = []
    for start in ((2019, 9), (2023, 11), (2024, 2)):
        clk = CosmicClock(*start)
        for _ in range(26):
            for ind in INDUSTRIES:
                f, d = clk.calculate_time_factor(ind)
                time_rows.append({"year": clk.year, "month": clk.month, "industry": ind, "f_time": f,
                                  "era_mod": d["era_mod"], "season_mod": d["season_mod"], "sha_name": d["sha_name"]})
            clk.advance_month()

    np_sys = NinePalacesSystem()
    space_rows = [{"industry": ind, "palace": pid, "fengshui": fs,
                   "f_space": np_sys.calculate_store_space_factor(ind, pid, fs)}
                  for ind in INDUSTRIES for pid in PALACES for fs in (-0.18, 0.0, 0.05, 0.35)]

    ps = PersonnelSystem()
    teams = []
    for i, g in enumerate(GATES):          # 单人：每个门派 × 每个岗位
        for role in ROLES:
            teams.append([Executive(f"x{i}", "x", g, g, role, 1, loyalty=70, stress=40)])
    combos = [
        [("CEO", "shang_men", 75, 65), ("CTO", "du_men", 60, 70), ("CMO", "jing_men", 65, 55), ("CFO", "sheng_men", 70, 60)],
        [("CEO", "jing_men", 95, 20), ("CTO", "du_men", 90, 25), ("CFO", "sheng_men", 70, 60),
         ("VP_Expansion", "shang_men", 75, 30), ("COO", "xiu_men", 90, 15)],
        [("CEO", "shang_men", 50, 95), ("VP_Expansion", "shang_men", 40, 90)],
        [("COO", "xiu_men", 80, 20), ("HR", "xiu_men", 80, 20)],
        [("CEO", "kai_men", 85, 50), ("CTO", "du_men", 90, 45), ("CFO", "sheng_men", 80, 60)],
    ]
    for c in combos:
        teams.append([Executive(f"c{i}", "x", g, g, role, 1, loyalty=lo, stress=st) for i, (role, g, lo, st) in enumerate(c)])
    personnel_rows = []
    for team in teams:
        f, d = ps.calculate_personnel_factor(team)
        personnel_rows.append({"team": [asdict(e) for e in team], "f_person": f,
                               "friction": d["friction_ratio"], "avg": d["avg_match_score"], "clash_log": d["clash_log"]})
    f, d = ps.calculate_personnel_factor([])
    personnel_rows.append({"team": [], "f_person": f, "friction": d["friction_ratio"], "avg": d["avg_match_score"], "clash_log": []})
    return {"time": time_rows, "space": space_rows, "personnel": personnel_rows}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.join(ROOT, "godot", "tests", "golden"))
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)

    def dump(name, obj):
        with open(os.path.join(args.out, name), "w", encoding="utf-8") as f:
            json.dump(obj, f, ensure_ascii=False, indent=1, sort_keys=True)

    dump("factors.json", factor_tables())
    total = 0
    for sid in (1, 2, 3):
        paths = [p for p, _ in enumerate_paths(sid)]
        dump(f"campaign_{sid}.json", {"scenario_id": sid, "paths": [replay(sid, p) for p in paths]})
        total += len(paths)
    print(f"已导出 {total} 条战役路径与因子表 → {args.out}")


if __name__ == "__main__":
    main()
