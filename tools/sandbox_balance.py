#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
沙盒平衡性模拟器：用一批策略各异的机器人玩家跑完 20 年，统计结局分布
用法：python3 tools/sandbox_balance.py [局数]
"""
import os, random, sys
from collections import Counter
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src import sandbox as sb
from src.sandbox import SandboxGame, INDUSTRIES, PALACE_OPTIONS
from src.personnel import PersonnelSystem

ROLES = ["CEO", "CFO", "CMO", "CTO"]
SYNERGY = PersonnelSystem().role_gate_synergy
ALL_PALACES = [pid for pid, _ in PALACE_OPTIONS.values()]


def pick_palace(rng, cfg, skilled):
    return cfg["best_palaces"][0] if skilled else rng.choice(ALL_PALACES)


def try_hire(rng, game, skilled):
    pool = game.state.talent_pool.available
    filled = {e.role for e in game.state.company.executives}
    open_roles = [r for r in ROLES if r not in filled]
    if not pool or not open_roles:
        return
    if skilled:
        best = max(((SYNERGY.get((r, c.gate), 1.0), i, r) for i, c in enumerate(pool) for r in open_roles))
        if best[0] < 1.2:
            return
        _, idx, role = best
    else:
        idx = rng.randrange(len(pool))
        role = rng.choice(open_roles)
    game.hire_talent(idx, role, pool[idx].asking_salary)


def monthly_cost(game):
    c = game.state.company
    return (sum(s.rent + s.staff_cost + s.maintenance_cost for s in c.stores if s.is_active)
            + c.total_monthly_payroll() + sb.SANDBOX_MISC_COST)


def play_bot(seed, idle=False, industry=None):
    rng = random.Random(seed)
    random.seed(seed)
    ind_key = industry or rng.choice([v["key"] for v in INDUSTRIES.values()])
    cfg = next(v for v in INDUSTRIES.values() if v["key"] == ind_key)
    skill = rng.random()                       # 0=外行 1=高手
    skilled = lambda: rng.random() < skill
    home = "li_9" if idle else pick_palace(rng, cfg, skilled())
    game = SandboxGame.create_new_game("bot", ind_key, 6_000_000, home)

    max_hires = 0 if idle else rng.randint(1, 4)
    reserve_months = rng.uniform(3, 12)
    invest_size = rng.choice([1e6, 2e6, 3e6, 5e6, 8e6])
    marketing = 50_000 if idle else rng.choice([0, 50_000, 100_000, 200_000])

    while not game.is_game_over():
        if not idle:
            if len(game.state.company.executives) < max_hires and game.state.turn % 3 == 0:
                try_hire(rng, game, skilled())
            cash = game.state.company.cash
            if cash - invest_size > reserve_months * monthly_cost(game):
                game.open_new_store("bot店", pick_palace(rng, cfg, skilled()), invest_size)
        if not idle and game.state.turn % 12 == 6 and skilled():
            # 年中复盘：关闭按天时均值估算仍亏损的老店
            for st in [x for x in game.state.company.stores if x.is_active and x.age_months > 12]:
                if game.estimate_store_profit(st) < 0:
                    game.close_store(st.id)
        game.advance_month(marketing)
        if game.state.turn % 12 == 0:
            game.refresh_talent_market()
    return game.check_ending().grade, game.state.turn, game.status_summary()["net_assets_est"]


def report(n=300):
    active = [play_bot(s) for s in range(n)]
    grades = Counter(g for g, _, _ in active)
    dist = {g: grades.get(g, 0) / n for g in "SABCD"}
    idle_turns = {}
    for v in INDUSTRIES.values():
        runs = [play_bot(s, idle=True, industry=v["key"]) for s in range(20)]
        idle_turns[v["key"]] = sorted(t for _, t, _ in runs)[len(runs) // 2]
    return dist, idle_turns


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    dist, idle = report(n)
    print("活跃玩家结局分布:", "  ".join(f"{g}:{p:.0%}" for g, p in dist.items()))
    print("放置不管·破产月份中位数:", idle)
