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
from src.office_fengshui import GridItem, OfficeLayoutManager
from src.save_manager import SaveManager
from src import tables, CampaignManager
from src.crisis_war_room import PRCrisisWarRoom

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


def office_layouts(n=300, seed=20261120) -> dict:
    """风水审计：两个预设 + n 个随机布局（覆盖各岗位、朝向、遮挡物与法器）"""
    import random
    rng = random.Random(seed)

    def audit(items):
        mgr = OfficeLayoutManager()
        for it in items:
            mgr.add_item(GridItem(**it))
        a = mgr.audit_layout()
        return {"items": items, "score": a.score, "modifier": a.fengshui_modifier,
                "perks": a.auspicious_perks, "shas": a.sha_penalties, "recs": a.recommendations}

    rows = [audit([asdict_item(i) for i in OfficeLayoutManager.from_preset(name).items.values()])
            for name in ("chaotic", "harmonious")]
    for _ in range(n):
        items, used = [], set()

        def spot():
            while True:
                xy = (rng.randrange(9), rng.randrange(9))
                if xy not in used:
                    used.add(xy)
                    return xy
        for role in rng.sample(["President", "Finance", "CTO", "Sales"], rng.randint(1, 4)):
            x, y = spot()
            items.append({"id": f"desk_{role}", "name": f"{role}桌", "category": "desk", "x": x, "y": y,
                          "facing": rng.choice("NSEW"), "role": role})
        for k in range(rng.randint(0, 3)):
            x, y = (4, rng.randint(1, 7)) if rng.random() < 0.5 else spot()
            used.add((x, y))
            items.append({"id": f"block_{k}", "name": "屏风", "category": rng.choice(["screen", "plant"]),
                          "x": x, "y": y, "facing": "N", "role": ""})
        for art in rng.sample(["pixiu", "wenchang", "fishtank"], rng.randint(0, 3)):
            x, y = spot()
            items.append({"id": art, "name": art, "category": "artifact", "x": x, "y": y, "facing": "S", "role": ""})
        rows.append(audit(items))
    return {"layouts": rows}


def save_fixtures(save_turn=6) -> dict:
    """跨引擎存档：每个关卡走设计正解中通关余量最大的路径，第1月满配风水改造，
    第 save_turn 个月开头（议题未处理）存档；再记录从存档继续到结局的逐月结果，供 Godot 读档后对照"""
    weight = tables.load("office_items.json")["modifier_weight"]
    chaotic = OfficeLayoutManager.create_chaotic_preset()
    harmonious = OfficeLayoutManager.create_harmonious_preset()
    delta = harmonious.audit_layout().fengshui_modifier - chaotic.audit_layout().fengshui_modifier
    out = []
    for sid in (1, 2, 3):
        intended = CampaignManager.get_scenario_by_id(sid)["intended_main_choice"]
        paths = [p for p, r in enumerate_paths(sid) if p.startswith(intended) and r.check_win()]
        path = max(paths, key=lambda p: replay(sid, p)["final_cash"])
        main, *picks = path.split("|")
        picks = dict(p.split("=") for p in picks)
        r = CampaignRunner(sid)
        r.apply_main_choice(main)
        r.company.cash -= 190000
        r.company.fengshui_modifier = round(min(0.35, max(-0.25, r.company.fengshui_modifier + delta * weight)), 3)
        save = None
        while not r.is_finished:
            if r.turn == save_turn and save is None:
                save = SaveManager.to_dict(r.company, r.clock, sid, r.progress(), list(harmonious.items.values()))
            for ev in r.pending_decisions():
                r.apply_decision(ev["id"], picks[ev["id"]])
            r.simulate_month(random_events=False)
            if not r.bankrupt:
                r.advance()
        resumed = [asdict(f) for f in r.company.financial_history[save_turn - 1:]]
        out.append({"scenario_id": sid, "path": path, "save": save, "after_months": resumed,
                    "final_cash": r.company.cash, "win": r.check_win()})
    return {"fixtures": out}


def asdict_item(it) -> dict:
    return {"id": it.id, "name": it.name, "category": it.category, "x": it.x, "y": it.y, "facing": it.facing, "role": it.role}


def crisis_paths() -> dict:
    """危机公关：不同在场高管 × 不同开局怒火/信任 × 全部选项路径，逐步记录状态"""
    teams = {
        "default": None,
        "no_jing": [("x1", "甲", "sheng_men", "生门", "CFO")],
        "both_gates": [("x1", "甲", "jing_men", "景门", "CEO"), ("x2", "乙", "jing_alarm_men", "惊门", "法务总监")],
    }
    starts = [(80, 35), (50, 50), (40, 30), (70, 20), (20, 80), (60, 45)]
    out = []

    def company_for(team):
        c = PRCrisisWarRoom.create_company()
        if teams[team] is not None:
            c.executives = [Executive(i, n, g, gn, r, 1) for i, n, g, gn, r in teams[team]]
        return c

    def walk(team, start, prefix):
        room = PRCrisisWarRoom.from_data()
        room.public_anger, room.brand_trust = start
        c = company_for(team)
        steps = []
        for oid in prefix:
            ok, log = room.execute_choice(oid, c)
            steps.append({"choice": oid, "ok": ok, "log": log, "anger": room.public_anger, "trust": room.brand_trust,
                          "hour": room.hour, "cash": c.cash, "spent": room.total_cost_spent,
                          "resolved": room.is_resolved, "verdict_key": room.verdict_key, "verdict": room.verdict,
                          "reputation": c.reputation})
        if room.is_resolved:
            out.append({"team": team, "start": list(start), "path": list(prefix), "steps": steps})
            return
        for o in room.get_current_stage().options:
            walk(team, start, prefix + [o.id])

    for team in teams:
        for start in starts:
            walk(team, start, [])
    return {"teams": {k: v for k, v in teams.items()}, "paths": out}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.join(ROOT, "godot", "tests", "golden"))
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)

    def dump(name, obj):
        with open(os.path.join(args.out, name), "w", encoding="utf-8") as f:
            json.dump(obj, f, ensure_ascii=False, indent=1, sort_keys=True)

    dump("factors.json", factor_tables())
    dump("office.json", office_layouts())
    dump("saves.json", save_fixtures())
    crisis = crisis_paths()
    dump("crisis.json", crisis)
    total = 0
    for sid in (1, 2, 3):
        paths = [p for p, _ in enumerate_paths(sid)]
        dump(f"campaign_{sid}.json", {"scenario_id": sid, "paths": [replay(sid, p) for p in paths]})
        total += len(paths)
    print(f"已导出 {total} 条战役路径、{len(crisis['paths'])} 条危机公关路径与因子表 → {args.out}")


if __name__ == "__main__":
    main()
