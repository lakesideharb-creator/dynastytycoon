#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
数据驱动的效果系统：战役开局配置、开局主决策、月度决策点共用同一组效果类型。
效果定义写在 data/campaign_scenarios.json；Godot 端（godot/core/effects.gd）实现同一组类型。

效果类型（EFFECT_TYPES）：
  cash          {"amount": 数值}
  reputation    {"delta": 整数}                                   结果夹在 0–100
  fengshui      {"delta": 数值}                                    结果夹在 -0.25–0.35
  fengshui_set  {"value": 数值}                                    直接设定（开局/重整办公室）
  revenue_mod   {"factor", "months"(null=长期), "label", "id_prefix"?, "palace"?}
  store_field   {"field", "factor"? / "add"?, "id_prefix"?, "palace"?}   修改门店数值字段
  store_cost    同 store_field（兼容旧写法，field 为 staff_cost / rent）
  add_stores    {"count"?, "id", "name", "palace_id", "city_name", "base_revenue", "rent", "staff_cost"}
                id/name 中的 {nn} 替换为两位序号（01、02…）
  exec          {"match": {"role"|"name"|"gate"|"all"}, "stress"?, "loyalty"?, "set"?: {字段: 值}, "set_role"?, "remove"?}
  add_exec      {Executive 全部字段}
"""

from typing import Dict, List

from .models import Company, Executive, Store, modifier_targets_store

EFFECT_TYPES = ("cash", "reputation", "fengshui", "fengshui_set", "revenue_mod", "store_field",
                "store_cost", "add_stores", "exec", "add_exec")

FENGSHUI_MIN, FENGSHUI_MAX = -0.25, 0.35
STORE_NUMERIC_FIELDS = ("base_revenue", "rent", "staff_cost", "maintenance_cost")
EXEC_SETTABLE = ("role", "salary", "loyalty", "stress", "special_trait", "portrait")


def _clamp(v, lo, hi):
    return max(lo, min(hi, v))


def _exec_matches(e: Executive, match: Dict) -> bool:
    if match.get("all"):
        return True
    return all(getattr(e, {"gate": "gate_id"}.get(k, k)) == v for k, v in match.items())


def build_stores(spec: Dict) -> List[Store]:
    count = spec.get("count")
    fields = {k: spec[k] for k in ("palace_id", "city_name", "base_revenue", "rent", "staff_cost")}
    extra = {k: spec[k] for k in ("decay_rate", "maintenance_cost", "invest") if k in spec}
    if not count:
        return [Store(id=spec["id"], name=spec["name"], **fields, **extra)]
    return [Store(id=spec["id"].replace("{nn}", f"{i:02d}"), name=spec["name"].replace("{nn}", f"{i:02d}"),
                  **fields, **extra) for i in range(1, count + 1)]


def build_executive(spec: Dict) -> Executive:
    return Executive(**{k: v for k, v in spec.items() if k != "type"})


def apply_effects(company: Company, effects: List[Dict]) -> List[str]:
    """执行一组效果，返回人类可读的变化描述"""
    notes = []
    for eff in effects:
        t = eff["type"]
        if t == "cash":
            company.cash += eff["amount"]
            notes.append(f"资金 {eff['amount']:+,.0f}")
        elif t == "reputation":
            company.reputation = int(_clamp(company.reputation + eff["delta"], 0, 100))
            notes.append(f"商誉 {eff['delta']:+d}")
        elif t == "fengshui":
            company.fengshui_modifier = round(_clamp(company.fengshui_modifier + eff["delta"], FENGSHUI_MIN, FENGSHUI_MAX), 3)
            notes.append(f"风水 {eff['delta'] * 100:+.0f}%")
        elif t == "fengshui_set":
            company.fengshui_modifier = eff["value"]
            notes.append(f"风水修正设为 {eff['value'] * 100:+.0f}%")
        elif t == "revenue_mod":
            mod = {k: eff[k] for k in ("factor", "id_prefix", "palace", "label") if k in eff}
            mod["months_left"] = eff.get("months")
            company.revenue_modifiers.append(mod)
            span = f"{eff['months']}个月" if eff.get("months") else "长期"
            notes.append(f"{eff.get('label', '营收')} ×{eff['factor']:.2f}（{span}）")
        elif t in ("store_field", "store_cost"):
            field = eff["field"]
            if field not in STORE_NUMERIC_FIELDS:
                raise ValueError(f"store_field 不支持字段: {field}")
            for st in company.stores:
                if st.is_active and modifier_targets_store(eff, st):
                    v = getattr(st, field)
                    if "factor" in eff:
                        v = v * eff["factor"]
                    if "add" in eff:
                        v = v + eff["add"]
                    setattr(st, field, v)
            label = {"staff_cost": "人工成本", "rent": "租金", "base_revenue": "基础营收", "maintenance_cost": "维护成本"}[field]
            notes.append(f"{label} ×{eff['factor']:.2f}" if "factor" in eff else f"{label} {eff['add']:+,.0f}")
        elif t == "add_stores":
            new = build_stores(eff)
            company.stores.extend(new)
            notes.append(f"新增门店 {len(new)} 家")
        elif t == "exec":
            targets = [e for e in company.executives if _exec_matches(e, eff["match"])]
            for e in targets:
                if eff.get("remove"):
                    company.executives.remove(e)
                    notes.append(f"{e.role}{e.name}离职")
                    continue
                e.stress = int(_clamp(e.stress + eff.get("stress", 0), 0, 100))
                e.loyalty = int(_clamp(e.loyalty + eff.get("loyalty", 0), 0, 100))
                if "set_role" in eff:
                    e.role = eff["set_role"]
                for k, v in eff.get("set", {}).items():
                    if k not in EXEC_SETTABLE:
                        raise ValueError(f"exec.set 不支持字段: {k}")
                    setattr(e, k, v)
            if targets and not eff.get("remove") and (eff.get("stress") or eff.get("loyalty")):
                who = "全员" if eff["match"].get("all") else "、".join(e.name for e in targets)
                parts = [f"压力{eff['stress']:+d}" if eff.get("stress") else "",
                         f"忠诚{eff['loyalty']:+d}" if eff.get("loyalty") else ""]
                notes.append(f"{who} " + " ".join(p for p in parts if p))
        elif t == "add_exec":
            e = build_executive(eff)
            company.executives.append(e)
            notes.append(f"{e.role}{e.name}加入")
        else:
            raise ValueError(f"未知效果类型: {t}")
    return notes
