#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
战役路径穷举：遍历开局主决策 × 全部月度决策点选项（不含随机事件），输出每条路径的终局指标
用法：python3 tools/campaign_paths.py [关卡编号...]
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.campaign import CampaignManager
from src.campaign_runner import enumerate_paths


def metrics(runner):
    c = runner.company
    _, p = runner.engine.personnel_sys.calculate_personnel_factor(c.executives)
    last = c.financial_history[-1].net_profit if c.financial_history else 0
    return {"win": runner.check_win(), "cash": c.cash, "last_profit": last,
            "friction": p["friction_ratio"], "bankrupt": runner.bankrupt, "months": len(c.financial_history)}


if __name__ == "__main__":
    ids = [int(a) for a in sys.argv[1:]] or [s["id"] for s in CampaignManager.get_all_scenarios_meta() if CampaignManager.is_playable(s["id"])]
    for sid in ids:
        rows = enumerate_paths(sid)
        print(f"=== 关卡{sid}：{len(rows)} 条路径，通关 {sum(metrics(r)['win'] for _, r in rows)} 条")
        for path, r in rows:
            m = metrics(r)
            print(f"  {'✅' if m['win'] else '❌'} {path:<58} 现金{m['cash']/1e6:7.1f}M 末月利{m['last_profit']/1e6:6.2f}M 内耗{m['friction']:.2f}"
                  + (f" 破产@{m['months']}" if m['bankrupt'] else ""))
