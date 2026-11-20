#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
人和八门系统 (Personnel & Eight Gates System)
管理高管命格、八门适岗系数、四门创业铁三角检测与组织内耗算法
"""

import json
import os
from typing import Dict, List, Tuple
from .models import Executive
from . import tables

class PersonnelSystem:
    def __init__(self, data_path: str = None):
        if data_path is None:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            data_path = os.path.join(base_dir, "data", "eight_gates.json")

        self.gates_data = {}
        if os.path.exists(data_path):
            with open(data_path, "r", encoding="utf-8") as f:
                raw = json.load(f)
                for item in raw.get("gates", []):
                    self.gates_data[item["id"]] = item

        # 岗位与八门适岗匹配度矩阵（data/engine_tables.json）
        self.role_gate_synergy = {(r["role"], r["gate"]): r["score"] for r in tables.engine()["role_gate_synergy"]}

    def calculate_internal_friction(self, executives: List[Executive]) -> Tuple[float, List[str]]:
        """
        计算高管团队内部内耗系数 (Friction Ratio)
        返回: (内耗扣减比率 0.0~0.5, 冲突报告)
        """
        clash_log = []
        base_friction = 0.0

        gate_counts = {}
        for e in executives:
            gate_counts[e.gate_id] = gate_counts.get(e.gate_id, 0) + 1

        # 1. 两伤相争必内耗 (多个伤门高管)
        if gate_counts.get("shang_men", 0) >= 2:
            base_friction += 0.25
            clash_log.append("【两伤相克】：团队内存在多名狼性伤门高管，各自为战争抢资源，内耗+25%")

        # 2. 伤门与杜门碰撞 (狼性销售 vs 闭门研发)
        if gate_counts.get("shang_men", 0) >= 1 and gate_counts.get("du_men", 0) >= 1:
            base_friction += 0.15
            clash_log.append("【伤杜相争】：前线销售频繁催促功能上线，技术研发坚守质量拒绝配合，内耗+15%")

        # 3. 伤门与生门碰撞 (激进垫资扩张 vs 严格财务风控)
        if gate_counts.get("shang_men", 0) >= 1 and gate_counts.get("sheng_men", 0) >= 1:
            base_friction += 0.15
            clash_log.append("【生伤相争】：前线要求大量垫资放账，财务死守风控拒绝审批，内耗+15%")

        # 4. 伤门错位任CEO惩罚 (暴躁独断致人心浮动)
        ceo = next((e for e in executives if e.role == "CEO"), None)
        cfo = next((e for e in executives if e.role == "CFO"), None)
        if ceo and ceo.gate_id == "shang_men":
            base_friction += 0.10
            clash_log.append("【伤门司帅】：伤门暴烈，适合为先锋而非帅印，担任CEO致使团队压力剧增，内耗+10%")

        # 5. 景门CEO 与 生门CFO 的黄金互补
        if ceo and cfo:
            if ceo.gate_id == "jing_men" and cfo.gate_id == "sheng_men":
                base_friction -= 0.10
                clash_log.append("【景生相融】：品牌愿景(景门)与务实算账(生门)形成互补合力，内耗降低10%")

        # 6. 休门人润滑剂减压
        xiu_count = gate_counts.get("xiu_men", 0)
        if xiu_count > 0:
            reduction = min(0.25, xiu_count * 0.15)
            base_friction -= reduction
            clash_log.append(f"【休门润木】：休门HR/COO调和人际矛盾，内耗降低 {int(reduction*100)}%")

        total_friction = max(0.0, min(0.50, base_friction))
        return round(total_friction, 3), clash_log

    def calculate_personnel_factor(self, executives: List[Executive]) -> Tuple[float, Dict]:
        """
        综合计算人和因子 f(P)
        f(P) = (平均适岗匹配分) * (1 - 内耗率)
        """
        if not executives:
            return 0.70, {
                "error": "无核心管理层",
                "avg_match_score": 0.0,
                "friction_ratio": 0.0,
                "clash_log": [],
                "role_details": {},
                "f_person": 0.70,
            }

        scores = []
        role_details = {}
        for e in executives:
            match_score = self.role_gate_synergy.get((e.role, e.gate_id), 1.0)
            # 压力与忠诚度对表现的微调
            stress_penalty = max(0.0, (e.stress - 60) * 0.005)
            loyalty_bonus = (e.loyalty - 50) * 0.002
            final_exec_score = round(match_score - stress_penalty + loyalty_bonus, 3)
            scores.append(final_exec_score)
            role_details[e.role] = {
                "name": e.name,
                "gate": e.gate_name,
                "score": final_exec_score
            }

        avg_score = sum(scores) / len(scores)
        friction, clash_log = self.calculate_internal_friction(executives)
        f_person = max(0.40, avg_score * (1.0 - friction))

        details = {
            "avg_match_score": round(avg_score, 3),
            "friction_ratio": friction,
            "clash_log": clash_log,
            "role_details": role_details,
            "f_person": round(f_person, 3)
        }
        return round(f_person, 3), details
