#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
动态商战与随机神煞事件系统 (Event & Crisis System)
管理恶性价格战、爆款出圈、公关危机与神煞吉凶突发事件
"""

import random
from typing import Dict, Tuple, Optional
from .models import Company
from . import tables

class EventSystem:
    def __init__(self):
        # 突发事件库（data/random_events.json）
        data = tables.random_events()
        self.trigger_chance = data["trigger_chance"]
        self.events_pool = data["events"]

    def trigger_monthly_event(self, company: Company, month: int) -> Optional[Dict]:
        """
        每个月有 40% 的概率触发突发事件
        """
        if random.random() < self.trigger_chance:
            pool = [e for e in self.events_pool
                    if not e.get("industries") or company.industry in e["industries"]]
            event = random.choice(pool)
            company.cash += event["effect_cash"]
            company.reputation = max(0, min(100, company.reputation + event["effect_reputation"]))
            company.fengshui_modifier = round(max(-0.25, min(0.35, company.fengshui_modifier + event["effect_fengshui"])), 3)
            return event
        return None
