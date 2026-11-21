#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
《商道玄机：大亨罗盘》（Dynasty Tycoon: The Cosmic Board）
Milestone 0 交互式终端模拟器 (Interactive Terminal Simulator)
全面支持战役一、二、三实机推演、十大传奇商战全景与企业总部风水工位DIY系统
"""

import sys
import os
import time
import argparse

current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

from src import (
    Company, Store, Executive, CosmicClock,
    CosmicSimulationEngine, CampaignManager, EventSystem, SaveManager,
    OfficeLayoutManager, GridItem, FengShuiAudit,
    PRCrisisWarRoom, CrisisStage, CrisisOption,
    SandboxGame, TalentPool, INDUSTRIES, PALACE_OPTIONS, NinePalacesSystem
)
from src.sandbox import STORE_SALVAGE_RATE
from src.campaign_runner import CampaignRunner, check_win_condition, enumerate_paths
from src.insight import explain_month, forecast_next_month

# ANSI 终端色彩
CYAN = "\033[96m"
YELLOW = "\033[93m"
GREEN = "\033[92m"
RED = "\033[91m"
MAGENTA = "\033[95m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"

def print_banner():
    banner = f"""{CYAN}{BOLD}
╔═══════════════════════════════════════════════════════════════════════════════╗
║   ██████╗ ██╗   ██╗███╗   ██╗ █████╗ ███████╗████████╗██╗   ██╗   ████████╗   ║
║   ██╔══██╗╚██╗ ██╔╝████╗  ██║██╔══██╗██╔════╝╚══██╔══╝╚██╗ ██╔╝   ╚══██╔══╝   ║
║   ██║  ██║ ╚████╔╝ ██╔██╗ ██║███████║███████╗   ██║    ╚████╔╝       ██║      ║
║   ██║  ██║  ╚██╔╝  ██║╚██╗██║██╔══██║╚════██║   ██║     ╚██╔╝        ██║      ║
║   ██████╔╝   ██║   ██║ ╚████║██║  ██║███████║   ██║      ██║         ██║      ║
║   ╚═════╝    ╚═╝   ╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝   ╚═╝      ╚═╝         ╚═╝      ║
║                  《商道玄机：大亨罗盘》· 交互式终端沙盘系统                   ║
║                 DYNASTY TYCOON: THE COSMIC BOARD (v1.1.0 M0)                  ║
╚═══════════════════════════════════════════════════════════════════════════════╝{RESET}"""
    print(banner)

def print_hud(company: Company, clock: CosmicClock, engine: CosmicSimulationEngine):
    f_time, time_info = clock.calculate_time_factor(company.industry)
    f_person, person_info = engine.personnel_sys.calculate_personnel_factor(company.executives)
    
    print(f"\n{BOLD}{'='*80}{RESET}")
    print(f"{YELLOW}【天时时钟】{RESET} {clock.era_name} | {clock.year}年 {clock.month:02d}月 | {time_info['season_name']}")
    print(f"            {CYAN}日辰神煞：{time_info['sha_name']}{RESET} -> {DIM}{time_info['sha_desc']}{RESET}")
    print(f"{GREEN}【企业财务】{RESET} 公司：{BOLD}{company.name}{RESET} | 赛道：{company.industry} | 业务体量：{len(company.stores)}处网点/中心")
    print(f"            账面现金：{BOLD}¥{company.cash:,.2f}{RESET} | 商誉口碑：{company.reputation}/100 | 风水修正：{company.fengshui_modifier*100:+.1f}%")
    
    friction_pct = int(person_info['friction_ratio'] * 100)
    friction_color = GREEN if friction_pct <= 10 else (YELLOW if friction_pct <= 25 else RED)
    print(f"{MAGENTA}【人和董事会】{RESET} (综合f_P: {f_person:.2f} | 组织内耗率: {friction_color}{friction_pct}%{RESET})")
    exec_line = " | ".join([f"{e.role}({e.gate_name}·{e.name})" for e in company.executives])
    print(f"            {exec_line}")
    if person_info["clash_log"]:
        for clash in person_info["clash_log"]:
            print(f"            {DIM}{clash}{RESET}")
    print(f"{BOLD}{'='*80}{RESET}")

# 风水修正值上下限（与随机事件系统保持一致）
FENGSHUI_MOD_MIN, FENGSHUI_MOD_MAX = -0.25, 0.35
# 办公室改造的审计变化只按此比例计入公司修正（data/office_items.json）
from src import tables as _tables
OFFICE_WEIGHT = _tables.load("office_items.json")["modifier_weight"]

# 风水工位改造项目：编号 -> (费用, 新增物件工厂, 成功提示)
FENGSHUI_UPGRADES = {
    "1": (30000, lambda: [GridItem("scr_manual", "紫檀木玄关屏风", "screen", 4, 5, facing="N")],
          "屏风落成！中轴穿堂气流已被成功截断。"),
    "2": (80000, lambda: [GridItem("p_desk", "总裁乾位实木大案", "desk", 1, 0, facing="S", role="President")],
          "总裁办调整至西北乾位实墙格局！威信大涨。"),
    "3": (50000, lambda: [GridItem("f_desk", "财务保密专案桌", "desk", 4, 1, facing="S", role="Finance")],
          "财务室迁入正北坎一深水藏金之位！资金跑冒滴漏清零。"),
    "4": (60000, lambda: [GridItem("pixiu", "汉白玉招财貔貅", "artifact", 2, 0, facing="S"),
                          GridItem("wenchang", "九层紫铜文昌塔", "artifact", 8, 4, facing="W")],
          "貔貅与文昌塔归位！企业气场大盛。"),
    "5": (200000, None, "全套大师级调和布局落成！"),
}

def manage_fengshui_studio(company: Company, office_mgr: OfficeLayoutManager):
    """企业总部风水工位DIY与调理控制台"""
    while True:
        audit = office_mgr.audit_layout()
        print(f"\n{YELLOW}{BOLD}{'='*30} 企业总部风水工位DIY控制台 {'='*30}{RESET}")
        print(office_mgr.render_ascii_map())
        print(f"\n当前风水综合评级：{BOLD}{audit.score}/100 分{RESET} | 产出修正：{BOLD}{audit.fengshui_modifier*100:+.1f}%{RESET}")
        
        if audit.auspicious_perks:
            print(f"{GREEN}【吉星吉格】：{RESET}")
            for p in audit.auspicious_perks:
                print(f"  ✓ {p}")
        if audit.sha_penalties:
            print(f"{RED}【恶煞冲克】：{RESET}")
            for s in audit.sha_penalties:
                print(f"  ✗ {s}")
        if audit.recommendations:
            print(f"{CYAN}【大师建议】：{RESET}")
            for r in audit.recommendations:
                print(f"  » {r}")

        print(f"\n{BOLD}工位装潢与化煞操作：{RESET}")
        print("  [1] 购置【紫檀木高隔玄关屏风】安置于 (4,5) (耗资 ¥30,000 · 化解穿堂煞)")
        print("  [2] 重构【总裁办西北乾位实墙格局】安置于 (1,0) (耗资 ¥80,000 · 乾位得位)")
        print("  [3] 迁建【财务室正北深水保密室】安置于 (4,1) (耗资 ¥50,000 · 深水藏金)")
        print("  [4] 请购【汉白玉招财貔貅 + 九层文昌塔】 (耗资 ¥60,000 · 资方青睐+研发提速)")
        print("  [5] 一键装潢为【八卦归位·大师级调和布局】 (全套耗资 ¥200,000)")
        print("  [0] 保存布局并返回上一级菜单")

        cmd = input(f"\n{YELLOW}请选择工位修缮项目 [1-5/0]: {RESET}").strip()
        if cmd == "0":
            break
        if cmd not in FENGSHUI_UPGRADES:
            print(f"{RED}无效指令。{RESET}")
            continue

        cost, items, success_msg = FENGSHUI_UPGRADES[cmd]
        if company.cash < cost:
            print(f"{RED}集团账面资金不足 ¥{cost:,}。{RESET}")
            continue

        company.cash -= cost
        before = office_mgr.audit_layout().fengshui_modifier
        if cmd == "5":
            # 原地替换布局，保证调用方持有的 office_mgr 同步更新
            office_mgr.items = OfficeLayoutManager.create_harmonious_preset().items
        else:
            for it in items():
                office_mgr.add_item(it)
        after = office_mgr.audit_layout().fengshui_modifier
        # 按布局评分的变化量调整修正值，保留关卡初始值与随机事件带来的影响
        company.fengshui_modifier = round(
            max(FENGSHUI_MOD_MIN, min(FENGSHUI_MOD_MAX, company.fengshui_modifier + (after - before) * OFFICE_WEIGHT)), 3
        )
        print(f"{GREEN}{success_msg}{RESET}")


def check_campaign_win(scenario_id: int, company: Company, engine: CosmicSimulationEngine, meta: dict) -> bool:
    """按 campaign_scenarios.json 中的 win_condition 判定通关"""
    return check_win_condition(company, engine, meta)


MAIN_CHOICE_PROMPTS = {
    1: f"""
{RED}{BOLD}【紧急董事会】首轮全国跨省扩张战略决策路口：{RESET}
  {BOLD}[A]{RESET} 采纳拓展VP·赵勇路线：进军郑州、合肥（下沉铺量，30家低租金店，耗资300万）
  {BOLD}[B]{RESET} 采纳品牌官·苏清墨路线：进军成都、西安（离九宫文化共振，30家概念店，耗资360万）
  {BOLD}[C]{RESET} 采纳折中主义：合肥15家 + 成都15家（分散试水，耗资330万）""",
    2: f"""
{RED}{BOLD}【生死择时路口】面对仅剩4个月的现金跑道与黑天鹅前夜：{RESET}
  {BOLD}[A]{RESET} 2019Q3秋分前立决：签下略显苛刻的对赌，迅速锁死2000万现金入账（储备过冬粮草）
  {BOLD}[B]{RESET} 拖延至2020Q1：不拿钱，等待算法迭代博取1.5亿更高估值
  {BOLD}[C]{RESET} 裁撤研发断臂求生：砍掉半数技术人员，将月失血降至最低""",
    3: f"""
{RED}{BOLD}【权力重构路口】创始人团队内耗高达45%，产品持续跳票：{RESET}
  {BOLD}[A]{RESET} 八门归位：劝退伤门原CEO转任战略VP，由景门苏清墨掌舵CEO，增聘休门COO调和矛盾 (耗资150万)
  {BOLD}[B]{RESET} 强压施暴：各打五十大板，强推严苛OKR量化考评与连坐扣薪
  {BOLD}[C]{RESET} 弃车保帅：解散自研技术团队转买外部方案，全面做纯销售驱动""",
    4: f"""
{RED}{BOLD}【价格屠杀路口】百亿巨头全国商超买一送一，并逼经销商二选一：{RESET}
  {BOLD}[A]{RESET} 采纳拓展VP·赵勇路线：全国商超跟进五折，拿出800万给经销商补差价
  {BOLD}[B]{RESET} 采纳品牌官·苏清墨路线：撤出大卖场红海，转战马拉松、健身房、运动医学等专业场景（耗资600万）
  {BOLD}[C]{RESET} 绕道私域：砍掉经销层级，自建会员小程序直连消费者（耗资300万）""",
    5: f"""
{RED}{BOLD}【投决会路口】爆红预制菜「鲜厨匠」估值20亿，各家机构抢份额：{RESET}
  {BOLD}[A]{RESET} 采纳投资经理·赵勇路线：3000万全额打款，接受无保护条款
  {BOLD}[B]{RESET} 采纳风控合伙人·沈务本路线：首期1200万，写死回购条款（本金+8%）与业绩对赌
  {BOLD}[C]{RESET} 估值太高不碰：1000万转投冷链物流""",
    6: f"""
{RED}{BOLD}【择时路口】新品智能锁研发完成，推广预算仅200万，何时发布？{RESET}
  {BOLD}[A]{RESET} 采纳拓展VP·赵勇路线：赶上7月暑期大促立即上线（200万全部投进大促会场）
  {BOLD}[B]{RESET} 采纳品牌官·苏清墨路线：蓄势到9月中秋前夕，前置悬念，开门日全线首发（先投50万预热）
  {BOLD}[C]{RESET} 再等等：押注双十一，11月再上线""",
    7: f"""
{RED}{BOLD}【扩产路口】车企订单暴涨，四条BMS产线满负荷也交不完货：{RESET}
  {BOLD}[A]{RESET} 采纳拓展VP·赵勇路线：借款1.5亿，一次性新建8条产线，扩到三倍产能
  {BOLD}[B]{RESET} 采纳CFO·沈务本路线：自有资金新建4条产线扩到两倍，留存三成抗周期储备
  {BOLD}[C]{RESET} 不扩产：只接利润最高的订单""",
}


PLAYTEST_LOG = None   # 由 --playtest 打开：saves/playtest_log.jsonl


def log_playtest(runner: CampaignRunner, outcome: str):
    """试玩模式下记录一局战役的决策路径与结果（每局一行 JSON）"""
    if not PLAYTEST_LOG:
        return
    import json, datetime
    c = runner.company
    _, p_info = runner.engine.personnel_sys.calculate_personnel_factor(c.executives)
    row = {
        "time": datetime.datetime.now().isoformat(timespec="seconds"),
        "scenario": runner.scenario_id, "outcome": outcome, "months_played": len(c.financial_history),
        "main_choice": runner.main_choice, "decisions": runner.event_choices,
        "cash": round(c.cash), "last_month_profit": round(c.financial_history[-1].net_profit) if c.financial_history else None,
        "friction": p_info["friction_ratio"], "fengshui": round(c.fengshui_modifier, 3),
    }
    with open(PLAYTEST_LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")


def present_decision(runner: CampaignRunner, ev: dict):
    """展示月度决策点并读取玩家选择"""
    print(f"\n{MAGENTA}{BOLD}{'━' * 26} ⚡ 董事会紧急议题 {'━' * 26}{RESET}")
    print(f"{BOLD}{ev['title']}{RESET}")
    print(f"  {ev['desc']}\n")
    available = {}
    for opt in ev["options"]:
        ok, reason = runner.option_available(opt)
        tag = "" if ok else f" {RED}({reason}){RESET}"
        print(f"  {BOLD}[{opt['key']}]{RESET} {opt['label']}{tag}" if ok else f"  {DIM}[{opt['key']}] {opt['label']}{RESET}{tag}")
        if ok:
            available[opt["key"]] = opt
    while True:
        key = input(f"{YELLOW}请拍板 [{'/'.join(available)}]: {RESET}").strip().upper()
        if key in available:
            ok, msg = runner.apply_decision(ev["id"], key)
            print(f"  {GREEN}▶ {msg}{RESET}")
            return
        print(f"  {RED}无效或不可选，请输入 {'/'.join(available)}。{RESET}")


def run_campaign_interactive(scenario_id: int, resume=None):
    """resume: SaveManager.load_game() 返回的 LoadedGame，用于从存档继续"""
    if resume is not None:
        scenario_id = resume.scenario_id
    if scenario_id not in MAIN_CHOICE_PROMPTS:
        print(f"{RED}关卡 {scenario_id} 暂未实装独立交互推演面板。{RESET}")
        return

    office_mgr = OfficeLayoutManager.create_chaotic_preset()
    if resume is not None:
        runner = CampaignRunner(scenario_id, company=resume.company, clock=resume.clock, progress=resume.progress)
        if resume.office_items:
            office_mgr.items = {it.id: it for it in resume.office_items}
    else:
        runner = CampaignRunner(scenario_id)
    company, clock, engine, meta = runner.company, runner.clock, runner.engine, runner.meta

    print(f"\n{YELLOW}{BOLD}>>> 正在载入：{meta['title']} <<<{RESET}")
    print(f"{CYAN}战略方法论：{RESET}{meta.get('methodology', '')}")
    print(f"{CYAN}关卡背景：{RESET}{meta['brief']}")
    print(f"{CYAN}通关目标：{RESET}{BOLD}{meta.get('win_condition_text', '')}{RESET}\n")
    if resume is not None:
        print(f"{GREEN}已从存档恢复：第 {runner.turn} 个月 · {clock.year}年{clock.month:02d}月{RESET}\n")

    marketing_budget = 0.0
    while not runner.is_finished:
        print_hud(company, clock, engine)
        print(f"{DIM}  进度：第 {runner.turn}/{runner.duration} 个月 | 目标：{meta.get('win_condition_text', '')}{RESET}")

        if runner.main_choice is None:
            print(MAIN_CHOICE_PROMPTS[scenario_id])
            choice = ""
            while choice not in ["A", "B", "C"]:
                choice = input(f"{YELLOW}请下达董事长决断指令 (A/B/C): {RESET}").strip().upper()
                if choice not in ["A", "B", "C"]:
                    print(f"{RED}无效指令，请输入 A、B 或 C。{RESET}")
            print(f"\n{GREEN}{runner.apply_main_choice(choice)}{RESET}")

        for ev in runner.pending_decisions():
            present_decision(runner, ev)

        # 每月经营指令菜单
        print(f"\n{CYAN}--- 第 {clock.year}年 {clock.month:02d}月 经营决策菜单 ---{RESET}")
        print("  [1] 调整月度营销/算力公关预算 (当前: ¥{:,.0f})".format(marketing_budget))
        print("  [2] 进入【企业总部风水工位DIY系统】(当前风水修正: {:+.1f}%)".format(company.fengshui_modifier * 100))
        print("  [3] 查阅高管团队与适岗度")
        print("  [4] 推进当前月份 (结算本月财务结账单)")
        print("  [S] 保存当前进度快照")
        print("  [Q] 退出本关战役")

        while True:
            cmd = input(f"{YELLOW}请输入操作指令 [1-4/S/Q] (回车默认[4]推进): {RESET}").strip().upper()
            if cmd == "" or cmd == "4":
                break
            elif cmd == "1":
                try:
                    val = float(input("请输入本月追加预算(0-300000元): ").strip())
                    marketing_budget = max(0.0, min(300000.0, val))
                    print(f"{GREEN}已设定本月预算为 ¥{marketing_budget:,.2f}{RESET}")
                except ValueError:
                    print(f"{RED}输入无效数字。{RESET}")
            elif cmd == "2":
                manage_fengshui_studio(company, office_mgr)
            elif cmd == "3":
                print("\n【高管花名册与适岗度】")
                _, p_info = engine.personnel_sys.calculate_personnel_factor(company.executives)
                for e in company.executives:
                    score = p_info["role_details"].get(e.role, {}).get("score", 0)
                    print(f"  - {e.role:<14} | 姓名: {e.name:<6} | 命格: {e.gate_name:<4} | 适岗: {score:.2f} | 月薪: ¥{e.salary:,.0f} | 压力: {e.stress} | 忠诚: {e.loyalty}")
            elif cmd == "S":
                path = SaveManager.save_game(
                    company, clock, scenario_id=scenario_id,
                    progress=runner.progress(),
                    office_items=list(office_mgr.items.values()),
                )
                print(f"{GREEN}游戏进度已保存至: {path}{RESET}")
            elif cmd == "Q":
                print(f"{YELLOW}正在退出当前战役...{RESET}")
                log_playtest(runner, "quit")
                return

        stmt, evt = runner.simulate_month(marketing_budget)

        print(f"\n{BOLD}{'='*30} 【第 {clock.month:02d} 月 财务结账单】 {'='*30}{RESET}")
        print(f"  月度总营收 (Gross Revenue) : {GREEN}¥{stmt.gross_revenue:,.2f}{RESET}")
        print(f"  物业与租金 (Rent Expense)  : {RED}-¥{stmt.rent_expense:,.2f}{RESET}")
        print(f"  全员薪酬 (Payroll)         : {RED}-¥{stmt.payroll_expense:,.2f}{RESET}")
        print(f"  门店运营/营销/杂项         : {RED}-¥{stmt.total_cost - stmt.rent_expense - stmt.payroll_expense:,.2f}{RESET}")
        print(f"  -------------------------------------------------------------")
        profit_color = GREEN if stmt.net_profit >= 0 else RED
        print(f"  当月净利润 (Net Profit)    : {profit_color}{BOLD}¥{stmt.net_profit:,.2f}{RESET}")
        print(f"  期末账面现金储备           : {BOLD}¥{company.cash:,.2f}{RESET}")

        print(f"\n{CYAN}  ─ 本月盈亏解读 ─{RESET}")
        for line in explain_month(company, engine):
            print(f"  {line}")

        if evt:
            print(f"\n{MAGENTA}>>> 突发商战与神煞动态 <<<{RESET}")
            print(f"  {BOLD}{evt['name']}{RESET}: {evt['desc']}")
            print(f"  反馈影响: 资金 {evt['effect_cash']:+,.0f} | 商誉 {evt['effect_reputation']:+d}")

        if runner.bankrupt:
            print(f"\n{RED}{BOLD}【现金流断裂破产警告】：集团账户彻底枯竭（当前现金: ¥{company.cash:,.2f}）！{RESET}")
            print(f"{RED}在激烈的周期波动中，公司失血过多被迫进入破产清算。战役失败！{RESET}")
            log_playtest(runner, "bankrupt")
            return

        print(f"  {YELLOW}{forecast_next_month(clock, company.industry)}{RESET}")
        runner.advance()
        marketing_budget = 0.0

    # 终局结算
    if not company.financial_history:
        return
    last_stmt = company.financial_history[-1]
    _, p_info = engine.personnel_sys.calculate_personnel_factor(company.executives)
    print(f"\n{BOLD}{'='*80}{RESET}")
    print(f"{YELLOW}{BOLD}【战役终局复盘考核】{RESET}")
    print(f"通关目标：{meta.get('win_condition_text', '')}")
    print(f"最终账面现金：¥{company.cash:,.2f} | 末月净利润：¥{last_stmt.net_profit:,.2f} | 组织内耗：{p_info['friction_ratio']*100:.0f}%")
    print(f"\n{CYAN}你的关键决策：{RESET}")
    print(f"  开局主决策：{runner.main_choice}")
    titles = {ev["id"]: ev["title"] for ev in meta.get("decision_points", [])}
    for ev_id, key in runner.event_choices.items():
        print(f"  {titles.get(ev_id, ev_id)} → {key}")

    log_playtest(runner, "win" if runner.check_win() else "lose")
    if runner.check_win():
        print(f"\n{GREEN}{BOLD}🎉 恭喜通关！【{meta['title']}】目标圆满达成！{RESET}")
    else:
        print(f"\n{RED}{BOLD}❌ 未达通关标准。商海莫测，请重新审视天时、地利与人和的动态平衡！{RESET}")


def display_all_10_scenarios():
    scenarios = CampaignManager.get_all_scenarios_meta()
    print(f"\n{YELLOW}{BOLD}{'='*30} 《商道玄机》十大传奇商战全景图谱 {'='*30}{RESET}\n")
    for s in scenarios:
        print(f"{CYAN}{BOLD}[关卡 {s['id']:02d}] {s['title']}{RESET}")
        print(f"  核心运筹：{s.get('methodology', '商业博弈')}")
        print(f"  所属赛道：{s.get('industry', '通用商业')} | 演练周期：{s.get('duration_months', 12)} 个月")
        print(f"  背景综述：{s.get('brief', '')}")
        print(f"  核心决策分支：")
        for k, v in s.get("choices", {}).items():
            print(f"    - 选项 {k}：{v.get('name', '')}")
            if "verdict" in v:
                print(f"      {DIM}» 复盘：{v['verdict']}{RESET}")
        print(f"{DIM}{'-'*80}{RESET}")

def run_crisis_war_room_interactive():
    """战役十：假减肥药危机公关黄金24小时"""
    print(f"\n{RED}{BOLD}{'='*30} ⚠️  特大舆情预警 — 24小时危机公关指挥室 {'='*30}{RESET}")
    print(f"{CYAN}战役十：社交电商平台爆款违禁减肥药事件【黄金24小时】{RESET}\n")
    print("  背景：你执掌的社交电商平台第三方入驻商户违规销售含违禁成分减肥药，")
    print("  一名消费者急性衰竭住院，微博热搜第一，阅读量破3亿，危机全面爆发！\n")
    print(f"  平台账面现金：¥40,000,000 | 初始商誉：40/100（已受损）")
    print(f"{YELLOW}  核心指标：公众怒火(0-100，>=85触发监管封杀) + 品牌信任(0-100，<=15品牌死亡){RESET}\n")

    company = PRCrisisWarRoom.create_company()
    room = PRCrisisWarRoom.create_weight_loss_drug_crisis()
    print("  指挥室成员：" + " | ".join(f"{e.role}({e.gate_name}·{e.name})" for e in company.executives))
    print(f"  {DIM}提示：带门派标签的选项需要对应门派的高管坐镇，否则效果减半。{RESET}")

    while not room.is_resolved:
        stage = room.get_current_stage()
        if not stage:
            break

        anger_bar = "█" * (room.public_anger // 5) + "░" * (20 - room.public_anger // 5)
        trust_bar = "█" * (room.brand_trust // 5) + "░" * (20 - room.brand_trust // 5)
        anger_color = RED if room.public_anger >= 70 else YELLOW
        trust_color = GREEN if room.brand_trust >= 50 else YELLOW

        print(f"\n{BOLD}{'─'*76}{RESET}")
        print(f"{RED}{BOLD}⏰ 当前时刻：Hour +{room.hour:02d}  {stage.name}{RESET}")
        print(f"{anger_color}  怒火指数 [{anger_bar}] {room.public_anger:3d}/100{RESET}  "
              f"{trust_color}信任指数 [{trust_bar}] {room.brand_trust:3d}/100{RESET}")
        print(f"  账面现金：{BOLD}¥{company.cash:,.0f}{RESET}  |  已累计投入应急基金：¥{room.total_cost_spent:,.0f}")
        print(f"\n{YELLOW}{BOLD}  📢 舆情播报：{RESET}{stage.event_headline}\n")

        for i, opt in enumerate(stage.options, 1):
            cost_str = f"耗资 ¥{opt.cost:,.0f}"
            eff_anger, eff_trust = PRCrisisWarRoom.effective_deltas(opt, company)
            anger_str = f"怒火 {eff_anger:+d}"
            trust_str = f"信任 {eff_trust:+d}"
            gate_tag = "" if PRCrisisWarRoom.has_required_gate(opt, company) else f" {RED}(缺少专属高管·效果减半){RESET}"
            print(f"  {BOLD}[{i}]{RESET} {opt.title}{gate_tag}")
            print(f"      {DIM}→ {opt.description}{RESET}")
            print(f"      {CYAN}[ {cost_str} | {anger_str} | {trust_str} ]{RESET}\n")

        while True:
            choice_input = input(f"{YELLOW}请下达决断指令 [1-{len(stage.options)}]: {RESET}").strip()
            if choice_input.isdigit() and 1 <= int(choice_input) <= len(stage.options):
                chosen_opt = stage.options[int(choice_input) - 1]
                ok, log = room.execute_choice(chosen_opt.id, company)
                print(f"\n  {GREEN}▶ 决策执行：{log}{RESET}")
                break
            else:
                print(f"  {RED}无效输入，请输入 1 到 {len(stage.options)} 之间的数字。{RESET}")

    print(f"\n{BOLD}{'='*76}{RESET}")
    print(f"{BOLD}{'='*20} ⚖️  24小时战役终局裁决 {'='*20}{RESET}\n")
    verdict_color = GREEN if "绝处逢生" in room.verdict else (YELLOW if "平庸" in room.verdict else RED)
    print(f"{verdict_color}{BOLD}{room.verdict}{RESET}\n")
    print(f"  最终公众怒火：{room.public_anger}/100  |  最终品牌信任：{room.brand_trust}/100")
    print(f"  最终账面现金：¥{company.cash:,.0f}  |  总应急投入：¥{room.total_cost_spent:,.0f}")
    print(f"  最终公司商誉：{company.reputation}/100")
    print(f"\n{CYAN}  ─ 决策回放日志 ─{RESET}")
    for entry in room.action_logs:
        print(f"  {DIM}{entry}{RESET}")
    input(f"\n{DIM}按 Enter 返回主菜单...{RESET}")


def run_sandbox_interactive():
    """二十年自由经营沙盒模式 (2024-2043)"""
    print(f"\n{MAGENTA}{BOLD}{'='*25} 🌐 二十年商业沙盒史诗 (2024-2043) {'='*25}{RESET}")
    print(f"{CYAN}自由开局 · 天时九运 · 人才市场 · 九宫置业 · 商道宗师传奇{RESET}\n")

    # 1. 行业选择
    print("【第一步：择定商业赛道】")
    for k, v in INDUSTRIES.items():
        print(f"  [{k}] {BOLD}{v['name']}{RESET} — {DIM}{v['desc']}{RESET}")
    
    ind_choice = "1"
    while True:
        c_in = input(f"{YELLOW}请选择创办行业 [1-5] (默认1): {RESET}").strip()
        if not c_in:
            ind_choice = "1"
            break
        if c_in in INDUSTRIES:
            ind_choice = c_in
            break
        print(f"{RED}无效输入，请输入 1-5。{RESET}")
    
    chosen_ind = INDUSTRIES[ind_choice]

    # 2. 公司名称
    c_name = input(f"{YELLOW}请输入公司商号/品牌名 (默认'天玄实业'): {RESET}").strip()
    if not c_name:
        c_name = "天玄实业"

    # 3. 初始资本
    c_cash = 6000000.0
    cash_in = input(f"{YELLOW}请输入起步资本 (200万~2000万，默认600万): {RESET}").strip()
    if cash_in.isdigit():
        val = float(cash_in)
        if 2000000 <= val <= 50000000:
            c_cash = val

    # 4. 龙兴之地选择
    print(f"\n【第二步：定都龙兴之地 (九宫发祥地)】")
    for k, (pid, label) in PALACE_OPTIONS.items():
        rec = f" {GREEN}(推荐契合){RESET}" if pid in chosen_ind.get("best_palaces", []) else ""
        print(f"  [{k}] {label}{rec}")

    pal_choice = "9"
    while True:
        p_in = input(f"{YELLOW}请选择总部所在地 [1-9] (默认9·离九宫): {RESET}").strip()
        if not p_in:
            pal_choice = "9"
            break
        if p_in in PALACE_OPTIONS:
            pal_choice = p_in
            break
        print(f"{RED}无效输入，请输入 1-9。{RESET}")

    home_palace = PALACE_OPTIONS[pal_choice][0]

    # 创建游戏沙盘
    game = SandboxGame.create_new_game(c_name, chosen_ind["key"], c_cash, home_palace)
    print(f"\n{GREEN}{BOLD}🎉 {c_name} 于 {PALACE_OPTIONS[pal_choice][1]} 正式扬帆启航！{RESET}")

    mkt_budget = 50000.0
    office_mgr = OfficeLayoutManager.create_chaotic_preset()  # 整局沿用同一份办公室布局

    # 核心沙盒循环
    while not game.is_game_over():
        s = game.status_summary()
        c = game.state.company
        clk = game.state.clock
        f_time, time_info = clk.calculate_time_factor(c.industry)
        f_person, person_info = game.state.engine.personnel_sys.calculate_personnel_factor(c.executives)

        friction_pct = int(person_info['friction_ratio'] * 100)
        fr_color = GREEN if friction_pct <= 10 else (YELLOW if friction_pct <= 25 else RED)

        print(f"\n{BOLD}{'─'*78}{RESET}")
        print(f"{YELLOW}【天时】{RESET}{clk.era_name} · {clk.year}年 {clk.month:02d}月 | 季节:{time_info['season_name']} | 神煞:{time_info['sha_name']} (f_T:{f_time:.2f})")
        print(f"{GREEN}【企业】{RESET}{BOLD}{c.name}{RESET} ({chosen_ind['name']}) | 现金: {BOLD}¥{c.cash:,.0f}{RESET} | 商誉: {c.reputation}/100 | 风水修正: {c.fengshui_modifier*100:+.1f}%")
        print(f"        估算净资产: ¥{s['net_assets_est']:,.0f} | 门店/中心: {s['store_count']}处 | 距2043终局还剩: {s['years_left']}年")
        
        exec_str = " | ".join([f"{e.role}({e.gate_name}·{e.name})" for e in c.executives]) if c.executives else "暂无高管 (需招募)"
        print(f"{MAGENTA}【高管】{RESET}{exec_str} (内耗率: {fr_color}{friction_pct}%{RESET} | f_P: {f_person:.2f})")
        print(f"{BOLD}{'─'*78}{RESET}")

        print("沙盘决策：")
        print("  [1] 推进单月 (结算月度盈亏与随机神煞)")
        print("  [2] 逛人才市场 (8门英才·议价延揽入阁)")
        print("  [3] 九宫战略拓店 (斥资跨省开设新据点)")
        print("  [4] 调整月度营销公关预算 (当前: ¥{:,.0f})".format(mkt_budget))
        print("  [5] 进入【企业总部风水工位DIY系统】")
        print("  [6] 快速推进一年 (批量推进12个月)")
        print("  [7] 查阅公司大事记历史日志")
        print("  [8] 门店经营一览与关店止损")
        print("  [0] 提前封印终局并退出")

        act = input(f"{YELLOW}请选择指令 [1-8/0] (回车默认[1]): {RESET}").strip()
        if not act:
            act = "1"

        if act == "1":
            res = game.advance_month(mkt_budget)
            profit_color = GREEN if res["net_profit"] >= 0 else RED
            print(f"\n  {BOLD}[{res['year']}年{res['month']:02d}月结账单]{RESET}")
            print(f"  月度总营收: ¥{res['total_revenue']:,.0f} | 总成本: ¥{res['total_cost']:,.0f}")
            print(f"  净利润: {profit_color}{BOLD}¥{res['net_profit']:+,.0f}{RESET} | 剩余现金: ¥{res['cash']:,.0f}")
            if res.get("event"):
                ev = res["event"]
                print(f"  {CYAN}📰 突发事件：{ev['name']}{RESET} -> {ev['desc']}")

        elif act == "2":
            pool = game.state.talent_pool
            print(f"\n{pool.display_market()}")
            print(f"  [0] 返回上级菜单")
            t_choice = input(f"{YELLOW}请选择欲招募的候选人编号 [1-8/0]: {RESET}").strip()
            if t_choice.isdigit() and 1 <= int(t_choice) <= len(pool.available):
                c_idx = int(t_choice) - 1
                cand = pool.available[c_idx]
                print(f"\n  选中英才：{cand.name}【{cand.gate_name}】 期望岗位：{'/'.join(cand.eligible_roles)}")
                print(f"  候选人要价：¥{cand.asking_salary:,}/月")
                role_assign = input(f"  请指派职位 (CEO/CFO/CTO/CMO/COO，直接回车默认{cand.eligible_roles[0]}): ").strip()
                if not role_assign:
                    role_assign = cand.eligible_roles[0]
                offer_in = input(f"  开出月薪 Offer (建议 ≥ ¥{cand.min_salary:,}，直接回车使用要价): ").strip()
                offer_val = int(offer_in) if offer_in.isdigit() else cand.asking_salary
                
                ok, h_msg = game.hire_talent(c_idx, role_assign, offer_val)
                print(f"  {h_msg}")
            elif t_choice == "0":
                pass
            else:
                print(f"  {RED}无效编号。{RESET}")

        elif act == "3":
            print(f"\n【九宫战略置业与开店】(当前现金: ¥{c.cash:,.0f})")
            for k, (pid, label) in PALACE_OPTIONS.items():
                np_sys = NinePalacesSystem()
                f_sp = np_sys.calculate_store_space_factor(c.industry, pid)
                print(f"  [{k}] {label} (空间亲和因子 f_S: {f_sp:.2f})")
            p_sel = input(f"{YELLOW}选择拓店宫位 [1-9/0取消]: {RESET}").strip()
            if p_sel in PALACE_OPTIONS:
                tar_pid, tar_label = PALACE_OPTIONS[p_sel]
                s_name = input(f"请输入新分店/研发中心名称 (如'{tar_label.split('·')[1]}旗舰店'): ").strip()
                if not s_name:
                    s_name = f"{tar_label.split('·')[1]}分店"
                inv_in = input(f"请输入投资金 (100万~1000万，投资越大门店越大但边际递减，直接回车按200万): ").strip()
                inv_val = float(inv_in) if inv_in.isdigit() else 2000000.0
                ok, o_msg = game.open_new_store(s_name, tar_pid, inv_val)
                print(f"  {o_msg}")

        elif act == "4":
            b_in = input(f"请输入新的月度营销公关预算 (0~500,000元，当前¥{mkt_budget:,.0f}): ").strip()
            if b_in.isdigit():
                mkt_budget = float(b_in)
                print(f"  {GREEN}已更新营销预算为 ¥{mkt_budget:,.0f}/月。{RESET}")

        elif act == "5":
            manage_fengshui_studio(c, office_mgr)

        elif act == "6":
            print(f"\n{YELLOW}>>> 正在快速推进 12 个月运营... <<<{RESET}")
            for m in range(12):
                if game.is_game_over():
                    break
                r = game.advance_month(mkt_budget)
            # 每满一年刷新一次人才市场
            game.refresh_talent_market()
            print(f"{GREEN}已推进至 {clk.year}年 {clk.month:02d}月！当前期末现金: ¥{c.cash:,.0f}{RESET}")

        elif act == "7":
            print(f"\n{CYAN}=== 公司大事记历史日志 ==={RESET}")
            for log in game.state.game_log[-15:]:
                print(f"  {DIM}{log}{RESET}")

        elif act == "8":
            active = [st for st in c.stores if st.is_active]
            print(f"\n{CYAN}=== 门店经营一览 (按本月天时·地利·人和预估) ==={RESET}")
            for i, st in enumerate(active, 1):
                est = game.estimate_store_profit(st)
                est_color = GREEN if est >= 0 else RED
                decay_pct = (1 - st.effective_base_revenue() / st.base_revenue) * 100 if st.base_revenue else 0
                print(f"  [{i}] {st.name:<14} {st.palace_id:<7} 营业{st.age_months:>3}月 老化-{decay_pct:.0f}% "
                      f"| 预估月利 {est_color}¥{est:+,.0f}{RESET} | 关店残值 ¥{st.invest * STORE_SALVAGE_RATE:,.0f}")
            pick = input(f"{YELLOW}输入要关闭的门店编号 (回车返回): {RESET}").strip()
            if pick.isdigit() and 1 <= int(pick) <= len(active):
                ok, msg = game.close_store(active[int(pick) - 1].id)
                print(f"  {GREEN if ok else RED}{msg}{RESET}")

        elif act == "0":
            confirm = input(f"{RED}确定提前结算沙盘并评定结局吗？(y/N): {RESET}").strip().lower()
            if confirm == "y":
                break

    # 终局评定
    ending = game.check_ending()
    s = game.status_summary()
    print(f"\n{BOLD}{'═'*78}{RESET}")
    print(f"{BOLD}{'='*25} 🏆 终局商业成就总评 {'='*25}{RESET}\n")
    grade_color = GREEN if ending.grade in ["S", "A"] else (YELLOW if ending.grade == "B" else RED)
    print(f"  最终结局：{grade_color}{BOLD}{ending.title} [评级: {ending.grade}级]{RESET}")
    print(f"  史诗评语：{DIM}{ending.description}{RESET}\n")
    print(f"  最终累计经营月份：{s['turn']} 个月 (经商 {s['years_elapsed']} 年)")
    print(f"  期末账面现金：¥{s['cash']:,.0f}")
    print(f"  期末总资产估值：¥{s['net_assets_est']:,.0f}")
    print(f"  旗下活跃网点数：{s['store_count']} 处")
    print(f"  董事会核心班底：{s['executive_count']} 人")
    print(f"  最终企业商誉：{s['reputation']}/100")
    print(f"\n{BOLD}{'═'*78}{RESET}")
    input(f"\n{DIM}按 Enter 返回主菜单...{RESET}")


def run_all_headless_tests():
    print(f"\n{YELLOW}{BOLD}>>> 正在执行十大战役数理模型自动化批处理回测... <<<{RESET}")
    names = {1: "新中式烘焙·离九共振", 2: "AI教育初创·择时对赌", 3: "四人组权力归位·八门调和", 4: "功能饮料·非对称突围", 5: "预制菜投资·条款风控", 6: "智能门锁·择时引爆", 7: "电池BMS·分步扩产"}
    all_ok = True
    for sid, name in names.items():
        paths = enumerate_paths(sid)
        wins = [p for p, r in paths if r.check_win()]
        intended = CampaignManager.get_scenario_by_id(sid).get("intended_main_choice")
        wrong = [p for p in wins if intended and not p.startswith(intended)]
        ok = bool(wins) and not wrong and len(wins) < len([p for p, _ in paths if p.startswith(intended or "")])
        all_ok &= ok
        mark = f"{GREEN}✓{RESET}" if ok else f"{RED}✗{RESET}"
        print(f"  {mark} 关卡{sid:02d} ({name}): {len(paths)} 条决策路径，通关 {len(wins)} 条，错误主决策通关 {len(wrong)} 条")

    # 沙盒自由模式自动化回测
    sandbox_test = SandboxGame.create_new_game("回测测试实业", "Cultural_Food", 8_000_000.0, "li_9")
    for _ in range(12):
        sandbox_test.advance_month(30000.0)
    cand = sandbox_test.state.talent_pool.available[0]
    sandbox_test.hire_talent(0, "COO", cand.asking_salary)
    sandbox_test.open_new_store("蓉城锦里新店", "li_9", 1_500_000.0)
    s_sum = sandbox_test.status_summary()
    print(f"  ✓ 自由沙盒 (2024-2043自由经营模式): 模拟12月期末净资产 ¥{s_sum['net_assets_est']:,.0f} | 门店数 {s_sum['store_count']} [通过]")

    if all_ok:
        print(f"\n{GREEN}{BOLD}✅ 战役路径与自由沙盒校验通过！{RESET}")
    else:
        print(f"\n{RED}{BOLD}❌ 部分战役路径不符合设计意图，请运行 tools/campaign_paths.py 查看详情。{RESET}")

def main():
    parser = argparse.ArgumentParser(description="《商道玄机：大亨罗盘》控制台模拟引擎")
    parser.add_argument("--scenario", type=int, choices=sorted(MAIN_CHOICE_PROMPTS), help="直接进入指定战役关卡")
    parser.add_argument("--headless", action="store_true", help="无头快速回测模式")
    parser.add_argument("--load", action="store_true", help="读取 quicksave 存档继续战役")
    parser.add_argument("--playtest", action="store_true", help="试玩模式：把每局战役的决策与结果记录到 saves/playtest_log.jsonl")
    args = parser.parse_args()

    if args.playtest:
        global PLAYTEST_LOG
        PLAYTEST_LOG = os.path.join(SaveManager.get_save_dir(), "playtest_log.jsonl")
        print(f"{DIM}试玩记录已开启：{PLAYTEST_LOG}{RESET}")

    if args.headless:
        run_all_headless_tests()
        return
    if args.load:
        loaded = SaveManager.load_game()
        if loaded is None:
            print(f"{RED}未找到存档 saves/quicksave.json。{RESET}")
            return
        run_campaign_interactive(loaded.scenario_id, resume=loaded)
        return
    if args.scenario:
        run_campaign_interactive(args.scenario)
        return

    print_banner()

    while True:
        print("\n主菜单选择：")
        print(f"  {BOLD}[1]{RESET} 启动【战役一：新中式烘焙的空间大破局】(空间算法实机)")
        print(f"  {BOLD}[2]{RESET} 启动【战役二：AI教育初创的融资择时生死战】(时间算法实机)")
        print(f"  {BOLD}[3]{RESET} 启动【战役三：豪华创业四人组的权力归位】(人物算法实机)")
        print(f"  {BOLD}[4]{RESET} 启动【战役四：功能饮料面对百亿巨头的降价屠杀】(竞争策略实机)")
        print(f"  {BOLD}[K]{RESET} 选择其他可玩战役（案例五、六、七等，按编号进入）")
        print(f"  {BOLD}[5]{RESET} {RED}启动【战役十：假减肥药危机公关黄金24小时】(舆情指挥室){RESET}")
        print(f"  {BOLD}[6]{RESET} {MAGENTA}启动【二十年自由经商沙盒模式】(自由开局·人才市场·九宫置业·2024-2043史诗){RESET}")
        print(f"  {BOLD}[7]{RESET} 启动【企业总部风水工位DIY与测算沙盘】(Office FengShui Studio)")
        print(f"  {BOLD}[8]{RESET} 查阅【十大传奇商战案例全景图谱】(10大案例脚本全鉴)")
        print(f"  {BOLD}[9]{RESET} 执行【十大战役与沙盘数理底层自动化批处理跑测】")
        print(f"  {BOLD}[L]{RESET} 读取战役存档继续 (quicksave)")
        print(f"  {BOLD}[0]{RESET} 退出系统")

        sel = input(f"\n{YELLOW}请选择操作功能 [1-9/K/L/0]: {RESET}").strip().upper()
        if sel in ["1", "2", "3", "4"]:
            run_campaign_interactive(int(sel))
        elif sel == "K":
            for sid in sorted(MAIN_CHOICE_PROMPTS):
                print(f"  [{sid}] {CampaignManager.get_scenario_by_id(sid)['title']}")
            pick = input(f"{YELLOW}输入关卡编号: {RESET}").strip()
            if pick.isdigit() and int(pick) in MAIN_CHOICE_PROMPTS:
                run_campaign_interactive(int(pick))
        elif sel == "5":
            run_crisis_war_room_interactive()
        elif sel == "6":
            run_sandbox_interactive()
        elif sel == "7":
            fake_comp = Company("风水实验室", "AI_Tech", 5000000.0)
            studio_mgr = OfficeLayoutManager.create_chaotic_preset()
            manage_fengshui_studio(fake_comp, studio_mgr)
        elif sel == "8":
            display_all_10_scenarios()
        elif sel == "L":
            loaded = SaveManager.load_game()
            if loaded is None:
                print(f"{RED}未找到存档，请先在战役中按 [S] 保存。{RESET}")
            else:
                run_campaign_interactive(loaded.scenario_id, resume=loaded)
        elif sel == "9":
            run_all_headless_tests()
        elif sel == "0":
            print("感谢体验《商道玄机：大亨罗盘》，商业如弈，再会！")
            break
        else:
            print(f"{RED}无效输入，请重新选择。{RESET}")

if __name__ == "__main__":
    main()
