#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
商道玄机·自由沙盒经营模式 (Sandbox Free Play)
玩家自定义行业、起步资本、地盘，体验20年（2024-2043）商业史诗
"""

import random
from dataclasses import dataclass, field
from typing import List, Dict, Tuple, Optional

from .models import Company, Store, Executive, FinancialStatement
from .cosmic_clock import CosmicClock
from .nine_palaces import NinePalacesSystem
from .personnel import PersonnelSystem
from .simulation_engine import CosmicSimulationEngine
from .event_system import EventSystem
from .talent_pool import TalentPool, TalentCandidate
from .save_manager import SaveManager

from . import tables

# 行业、经济参数、九宫地盘、结局门槛都在 data/sandbox.json（Godot 端 godot/core/sandbox_game.gd 读同一份）
_DATA = tables.load("sandbox.json")
_ECON = _DATA["economy"]

# 行业配置（键 "1"～"5" 为终端菜单编号）
INDUSTRIES = {str(i): dict(v) for i, v in enumerate(_DATA["industries"], 1)}

# 推荐宫位：取九宫亲和度最高的两宫，保证与结算数据一致
_AFFINITIES = NinePalacesSystem().industry_affinities
for _cfg in INDUSTRIES.values():
    _aff = _AFFINITIES.get(_cfg["key"], {})
    _cfg["best_palaces"] = sorted(_aff, key=_aff.get, reverse=True)[:2]

# ─────────────────────────────────────────────────────────────────────────────
# 沙盒经济参数（平衡性调参入口，数值由 tests/test_sandbox_balance.py 锁定）
# ─────────────────────────────────────────────────────────────────────────────
MIN_STORE_INVEST = _ECON["min_store_invest"]            # 开设新网点最低投资
MAX_STORE_INVEST = _ECON["max_store_invest"]            # 单店投资上限
REF_STORE_INVEST = _ECON["ref_store_invest"]            # 基准投资：此投资额下门店规模 = 行业基准
INVEST_REVENUE_EXP = _ECON["invest_revenue_exp"]        # 营收随投资的弹性（<1：大店边际递减）
INVEST_COST_EXP = _ECON["invest_cost_exp"]              # 租金/人工随投资的弹性
STORE_DECAY_RATE = _ECON["store_decay_rate"]            # 每月营收衰减（老化与竞品侵蚀），下限见 models.STORE_DECAY_FLOOR
MAINTENANCE_RATE = _ECON["maintenance_rate"]            # 每月折旧维护 = 投资额 × 该比例
HQ_INVEST_EQUIV = _ECON["hq_invest_equiv"]              # 总部折旧按此投资额计算
SANDBOX_REVENUE_SCALE = _ECON["sandbox_revenue_scale"]  # 沙盒营收整体缩放
SANDBOX_MISC_COST = _ECON["sandbox_misc_cost"]          # 每月杂项行政支出
PALACE_SATURATION = _ECON["palace_saturation"]          # 同一宫位每多一家已有网点，新店营收 × 该系数（市场饱和）
STORE_SALVAGE_RATE = _ECON["store_salvage_rate"]        # 关店回收残值 = 投资额 × 该比例
HIRE_SALARY_CASH_CAP = _ECON["hire_salary_cash_cap"]    # 开出的月薪不得超过现金的该比例
RENT_MULT_RANGE = tuple(_ECON["rent_mult_range"])       # 新店租金随机浮动
STAFF_MULT_RANGE = tuple(_ECON["staff_mult_range"])     # 新店人工随机浮动
STORE_VALUE_MONTHS = _ECON["store_value_months"]        # 净资产估值：门店按月营收 × 该月数计

# 九宫地盘选项（键 "1"～"9" 为终端菜单编号）
PALACE_OPTIONS = {str(i): (p["palace_id"], p["label"]) for i, p in enumerate(_DATA["palaces"], 1)}

# 结局门槛（由 tools/sandbox_balance.py 按机器人玩家分布标定：S≈5%，A≈30%，D≈半数（含外行玩家））
_TH = _DATA["ending_thresholds"]
ENDING_S_ASSETS = _TH["s_assets"]
ENDING_A_ASSETS = _TH["a_assets"]
ENDING_B_ASSETS = _TH["b_assets"]

# 结局定义（20年终局评定）
@dataclass
class SandboxEnding:
    title: str
    description: str
    unlock_condition: str   # 文字说明解锁条件
    grade: str              # S/A/B/C/D


ENDINGS = [SandboxEnding(f"{e['icon']} {e['title']}", e["description"], e["unlock_condition"], e["grade"])
           for e in _DATA["endings"]]


@dataclass
class SandboxState:
    company: Company
    clock: CosmicClock
    engine: CosmicSimulationEngine
    talent_pool: TalentPool
    event_sys: EventSystem
    save_mgr: SaveManager
    industry_cfg: Dict
    turn: int = 0           # 已过月数
    is_bankrupt: bool = False
    game_log: List[str] = field(default_factory=list)


class SandboxGame:
    """
    20年自由经营沙盒
    - create_new_game()  → 初始化玩家公司
    - advance_month()    → 推进一个月（结算+事件）
    - hire_talent()      → 雇佣人才
    - open_new_store()   → 拓展门店
    - refresh_talent_market() → 季度刷新人才市场
    - check_ending()     → 计算终局结局
    """

    START_YEAR = _ECON["start_year"]
    END_YEAR   = _ECON["end_year"]   # 20年

    @classmethod
    def create_new_game(
        cls,
        company_name: str,
        industry_key: str,
        starting_cash: float,
        home_palace_key: str,
    ) -> "SandboxGame":
        game = cls()
        cfg = next(v for v in INDUSTRIES.values() if v["key"] == industry_key)

        # 初始公司
        company = Company(
            name=company_name,
            industry=industry_key,
            cash=starting_cash,
            reputation=_ECON["starting_reputation"],
        )
        # 初始门店（总部）
        # 解析宫位对应城市名
        palace_label = next(
            (label for k, (pid, label) in PALACE_OPTIONS.items() if pid == home_palace_key),
            home_palace_key
        )
        city_name = palace_label.split("·")[1] if "·" in palace_label else palace_label
        hq_store = Store(
            id="hq_001",
            name=f"{company_name}·总部运营中心",
            palace_id=home_palace_key,
            city_name=city_name,
            base_revenue=cfg["base_revenue"] * SANDBOX_REVENUE_SCALE,
            rent=cfg["rent"],
            staff_cost=cfg["staff_cost"],
            is_active=True,
            decay_rate=STORE_DECAY_RATE,
            maintenance_cost=HQ_INVEST_EQUIV * MAINTENANCE_RATE,
            invest=HQ_INVEST_EQUIV,
        )
        company.stores.append(hq_store)

        clock = CosmicClock(cls.START_YEAR)
        engine = CosmicSimulationEngine(clock)
        talent_pool = TalentPool(seed=random.randint(0, 9999))
        event_sys = EventSystem()
        save_mgr = SaveManager()

        game.state = SandboxState(
            company=company,
            clock=clock,
            engine=engine,
            talent_pool=talent_pool,
            event_sys=event_sys,
            save_mgr=save_mgr,
            industry_cfg=cfg,
        )
        game.state.game_log.append(
            f"[{cls.START_YEAR}年01月] 🚀 {company_name} 于【{home_palace_key}】正式起航！"
            f"起步资金 ¥{starting_cash/1e6:.1f}M，行业：{cfg['name']}"
        )
        return game

    def __init__(self):
        self.state: Optional[SandboxState] = None

    # ─── 核心月度推进 ─────────────────────────────────────────────────────────
    def advance_month(self, marketing_budget: float = 0, random_events: bool = True) -> Dict:
        s = self.state
        if s.is_bankrupt:
            return {"error": "公司已破产，请重新开始新局。"}

        # 月度结算
        result = s.engine.simulate_month(s.company, marketing_budget, misc_budget=SANDBOX_MISC_COST)
        # 随机事件
        event = s.event_sys.trigger_monthly_event(s.company, s.clock) if random_events else None

        s.turn += 1
        year, month = s.clock.year, s.clock.month
        s.clock.advance_month()

        # 破产检查
        if s.company.cash < 0:
            s.is_bankrupt = True
            s.game_log.append(f"[{year}年{month:02d}月] 💀 资金链断裂！公司宣告破产。")

        log_line = (
            f"[{year}年{month:02d}月] 净利润: ¥{result.net_profit:+,.0f} | "
            f"现金: ¥{s.company.cash:,.0f} | 商誉: {s.company.reputation}"
        )
        if event:
            log_line += f" | 📰 {event.get('name', '')}"
        s.game_log.append(log_line)

        return {
            "year": year, "month": month,
            "net_profit": result.net_profit,
            "total_revenue": result.gross_revenue,
            "total_cost": result.total_cost,
            "cash": s.company.cash,
            "reputation": s.company.reputation,
            "event": event,
            "is_bankrupt": s.is_bankrupt,
            "turn": s.turn,
        }

    # ─── 雇佣人才 ─────────────────────────────────────────────────────────────
    def hire_talent(self, candidate_idx: int, role: str, salary: int) -> Tuple[bool, str]:
        s = self.state
        pool = s.talent_pool.available
        if candidate_idx < 0 or candidate_idx >= len(pool):
            return False, "候选人编号无效。"
        candidate = pool[candidate_idx]
        if salary > s.company.cash * HIRE_SALARY_CASH_CAP:
            return False, f"开出的薪资超过公司现金的10%，风险过高。"
        exec_obj = s.talent_pool.hire(candidate, role, salary)
        if exec_obj is None:
            return False, f"{candidate.name} 拒绝了你的报价 ¥{salary:,}/月（底线 ¥{candidate.min_salary:,}/月）。"
        s.company.executives.append(exec_obj)
        msg = f"✅ 成功延揽 {exec_obj.name}【{exec_obj.gate_name}】担任{role}，月薪 ¥{salary:,}。"
        s.game_log.append(f"[{s.clock.year}年{s.clock.month:02d}月] 人才引进：{msg}")
        return True, msg

    # ─── 开拓新门店 ───────────────────────────────────────────────────────────
    def open_new_store(self, store_name: str, palace_key: str, invest: float,
                       rent_mult: Optional[float] = None, staff_mult: Optional[float] = None) -> Tuple[bool, str]:
        """rent_mult / staff_mult 为新店租金、人工的随机浮动；不传时随机抽取（对照测试时传入固定值）"""
        s = self.state
        if invest < MIN_STORE_INVEST:
            return False, f"投资额过低：开设新网点至少需要 ¥{MIN_STORE_INVEST:,.0f}。"
        if invest > s.company.cash:
            return False, f"资金不足：需要 ¥{invest:,.0f}，账面仅剩 ¥{s.company.cash:,.0f}。"
        if invest > MAX_STORE_INVEST:
            return False, f"投资额过高：单店投资上限为 ¥{MAX_STORE_INVEST:,.0f}。"
        cfg = s.industry_cfg
        # 九宫亲和因子仅用于展示；月度结算时由 simulate_month 统一乘入，避免重复计算
        np_sys = NinePalacesSystem()
        f_space = np_sys.calculate_store_space_factor(s.company.industry, palace_key)
        scale = invest / REF_STORE_INVEST
        same_palace = sum(1 for st in s.company.stores if st.is_active and st.palace_id == palace_key)
        saturation = PALACE_SATURATION ** same_palace
        base_rev = cfg["base_revenue"] * SANDBOX_REVENUE_SCALE * scale ** INVEST_REVENUE_EXP * saturation
        s.company.cash -= invest
        # 解析城市名
        palace_label = next(
            (label for k, (pid, label) in PALACE_OPTIONS.items() if pid == palace_key),
            palace_key
        )
        city_name = palace_label.split("·")[1] if "·" in palace_label else palace_label
        store_id = f"store_{len(s.company.stores)+1:03d}"
        if rent_mult is None:
            rent_mult = random.uniform(*RENT_MULT_RANGE)
        if staff_mult is None:
            staff_mult = random.uniform(*STAFF_MULT_RANGE)
        new_store = Store(
            id=store_id,
            name=store_name,
            palace_id=palace_key,
            city_name=city_name,
            base_revenue=base_rev,
            rent=cfg["rent"] * scale ** INVEST_COST_EXP * rent_mult,
            staff_cost=cfg["staff_cost"] * scale ** INVEST_COST_EXP * staff_mult,
            is_active=True,
            decay_rate=STORE_DECAY_RATE,
            maintenance_cost=invest * MAINTENANCE_RATE,
            invest=invest,
        )
        s.company.stores.append(new_store)
        msg = (f"✅ 新网点【{store_name}】于{palace_key}落成！"
               f"月基础营收: ¥{base_rev:,.0f}（结算时乘九宫空间因子×{f_space:.2f}"
               + (f"，同宫已有{same_palace}家·饱和×{saturation:.2f}" if same_palace else "")
               + f"），投入: ¥{invest:,.0f}")
        s.game_log.append(f"[{s.clock.year}年{s.clock.month:02d}月] 扩张：{msg}")
        return True, msg

    # ─── 门店盈亏预估与关店 ───────────────────────────────────────────────────
    def estimate_store_profit(self, store: Store) -> float:
        """按当月天时、地利、人和估算单店月利润（不含公司级薪酬与杂项）"""
        s = self.state
        c = s.company
        f_time, _ = s.clock.calculate_time_factor(c.industry)
        f_person, _ = s.engine.personnel_sys.calculate_personnel_factor(c.executives)
        f_space = s.engine.palaces_sys.calculate_store_space_factor(c.industry, store.palace_id, c.fengshui_modifier)
        revenue = store.effective_base_revenue() * f_time * f_space * f_person
        return revenue - (store.rent + store.staff_cost + store.maintenance_cost)

    def close_store(self, store_id: str) -> Tuple[bool, str]:
        s = self.state
        active = [st for st in s.company.stores if st.is_active]
        store = next((st for st in active if st.id == store_id), None)
        if store is None:
            return False, "门店编号无效或已关闭。"
        if len(active) <= 1:
            return False, "这是最后一家营业网点，无法关闭。"
        salvage = store.invest * STORE_SALVAGE_RATE
        store.is_active = False
        s.company.cash += salvage
        msg = f"🔒 已关闭【{store.name}】（营业{store.age_months}个月），回收残值 ¥{salvage:,.0f}。"
        s.game_log.append(f"[{s.clock.year}年{s.clock.month:02d}月] 收缩：{msg}")
        return True, msg

    # ─── 季度刷新人才市场 ─────────────────────────────────────────────────────
    def refresh_talent_market(self) -> str:
        self.state.talent_pool.refresh_market()
        return self.state.talent_pool.display_market()

    # ─── 20年终局判定 ─────────────────────────────────────────────────────────
    def check_ending(self) -> SandboxEnding:
        s = self.state
        c = s.company

        if s.is_bankrupt or c.cash < 0:
            return ENDINGS[4]  # 破产

        net_assets = self.net_assets()

        # 连续5个年度盈利（按最近60个月切成5个自然年度汇总，允许季节性单月亏损）
        hist = c.financial_history
        recent = hist[-60:]
        yearly = [sum(f.net_profit for f in recent[i:i + 12]) for i in range(0, len(recent), 12)]
        five_profitable_years = len(recent) == 60 and all(y > 0 for y in yearly)
        last_year_profit = sum(f.net_profit for f in hist[-12:]) if hist else 0.0
        active_stores = len([st for st in c.stores if st.is_active])

        if (net_assets >= ENDING_S_ASSETS and c.reputation >= _TH["s_reputation"]
                and five_profitable_years and active_stores >= _TH["s_min_stores"]):
            return ENDINGS[0]  # 商道宗师
        elif net_assets >= ENDING_A_ASSETS and c.reputation >= _TH["a_reputation"]:
            return ENDINGS[1]  # 大亨崛起
        elif net_assets >= ENDING_B_ASSETS and last_year_profit > 0:
            return ENDINGS[2]  # 稳健商人
        else:
            return ENDINGS[3]  # 创业者折戟

    # ─── 净资产估算：现金 + 门店估值（月营收 × STORE_VALUE_MONTHS） ──────────────
    def net_assets(self) -> float:
        c = self.state.company
        return c.cash + sum(st.effective_base_revenue() * STORE_VALUE_MONTHS for st in c.stores if st.is_active)

    # ─── 获取当前快照摘要 ─────────────────────────────────────────────────────
    def status_summary(self) -> Dict:
        s = self.state
        c = s.company
        net_assets = self.net_assets()
        years_elapsed = s.turn // 12
        years_left = self.END_YEAR - s.clock.year + 1
        return {
            "company_name": c.name,
            "industry": s.industry_cfg["name"],
            "year": s.clock.year,
            "month": s.clock.month,
            "cash": c.cash,
            "reputation": c.reputation,
            "net_assets_est": net_assets,
            "store_count": len([st for st in c.stores if st.is_active]),
            "executive_count": len(c.executives),
            "years_elapsed": years_elapsed,
            "years_left": years_left,
            "is_bankrupt": s.is_bankrupt,
            "turn": s.turn,
        }

    def is_game_over(self) -> bool:
        s = self.state
        return s.is_bankrupt or s.clock.year > self.END_YEAR
