#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
24小时突发危机公关战备指挥室 (24-Hour PR Crisis War Room)
实现 WBS 5.1 倒计时战备回合判定流，模拟舆论温度、公关策略与八门技能协同
"""

from dataclasses import dataclass, field
from typing import Dict, List, Tuple, Optional
from .models import Company, Executive

ANGER_BAN_LINE = 85     # 怒火 >= 此值：监管封杀
TRUST_DEATH_LINE = 15   # 信任 <= 此值：品牌社会性死亡

@dataclass
class CrisisOption:
    id: str
    title: str
    description: str
    cost: float
    anger_delta: int       # 怒火值变动 (负数代表降温)
    trust_delta: int       # 信任度变动 (正数代表修复)
    special_gate: str = "" # 专属高管门派要求 (如 jing_men, jing_alarm_men)

@dataclass
class CrisisStage:
    stage_id: int
    name: str
    hours_range: str       # 如 "00:00 - 04:00"
    event_headline: str
    options: List[CrisisOption]

class PRCrisisWarRoom:
    def __init__(self, crisis_title: str, initial_anger: int = 75, initial_trust: int = 40):
        self.title = crisis_title
        self.hour = 0
        self.public_anger = initial_anger   # 怒火值 0-100 (>=85 触发监管顶格封杀)
        self.brand_trust = initial_trust    # 品牌信任度 0-100 (<=15 品牌社会性死亡)
        self.total_cost_spent = 0.0
        self.action_logs: List[str] = []
        self.is_resolved = False
        self.verdict = ""

    @staticmethod
    def create_weight_loss_drug_crisis() -> "PRCrisisWarRoom":
        """生成案例十：社交电商平台假减肥药爆雷事件"""
        return PRCrisisWarRoom(
            crisis_title="【特大舆情预警】第三方入驻商户违禁减肥药致消费者急性衰竭住院爆雷",
            initial_anger=80,
            initial_trust=35
        )

    def get_current_stage(self) -> Optional[CrisisStage]:
        if self.hour < 4:
            return CrisisStage(
                stage_id=1,
                name="第一阶段：0-4小时 【止损黄金期 · 舆情初起】",
                hours_range="00:00 - 04:00 (白虎镇压)",
                event_headline="微博热搜第一(#某平台假减肥药致住院# 阅读破3亿)，受害者家属在直播间举牌维权，大批自媒体开始跟进声讨！",
                options=[
                    CrisisOption(
                        id="stage1_deny",
                        title="【推脱掩饰】发声明称系第三方商户个人行为，并威胁起诉爆料者",
                        description="试图法律施压封口。反弹极大，被公众斥为傲慢冷血！",
                        cost=50000.0,
                        anger_delta=+20,
                        trust_delta=-25
                    ),
                    CrisisOption(
                        id="stage1_cold",
                        title="【花钱压热搜】斥资买水军降热搜，启动内部低调核查",
                        description="治标不治本，被网民发现删帖锁广场，引发更大次生舆情！",
                        cost=300000.0,
                        anger_delta=+10,
                        trust_delta=-15
                    ),
                    CrisisOption(
                        id="stage1_active",
                        title="【秒级响应】全网下架涉事品类，先行垫付医疗费，宣布无上限追责",
                        description="第一时间立正挨打，展示企业诚意与底线，迅速遏制怒火蔓延！",
                        cost=800000.0,
                        anger_delta=-25,
                        trust_delta=+20
                    )
                ]
            )
        elif self.hour < 12:
            return CrisisStage(
                stage_id=2,
                name="第二阶段：4-12小时 【化解定盘期 · 舆论激辩】",
                hours_range="04:00 - 12:00 (惊门定性)",
                event_headline="央视与监管机构点名质问平台主体审核责任，主流电商竞品借机上线'品质先行保障'抢夺用户！",
                options=[
                    CrisisOption(
                        id="stage2_press_sincere",
                        title="【景门主理人出战】召开全网直播发布会，CEO出镜90度鞠躬，公布退赔专线",
                        description="景门美学与真诚感召，彻底打破冰冷的企业官僚形象，舆情温度大幅下降！",
                        cost=500000.0,
                        anger_delta=-30,
                        trust_delta=+30,
                        special_gate="jing_men"
                    ),
                    CrisisOption(
                        id="stage2_legal_sue",
                        title="【惊门法务出击】直接向公安经侦报案刑拘涉事黑心供货商",
                        description="严正亮明底线，将矛盾引向上游不法犯罪分子，法律责任定性明确！",
                        cost=200000.0,
                        anger_delta=-20,
                        trust_delta=+20,
                        special_gate="jing_alarm_men"
                    ),
                    CrisisOption(
                        id="stage2_bureaucratic",
                        title="【发布官样通稿】发出一份冷冰冰的格式化通稿，声称'配合调查'",
                        description="毫无诚意的套话公文，再次引爆全网网民嘲讽制作表情包！",
                        cost=20000.0,
                        anger_delta=+15,
                        trust_delta=-20
                    )
                ]
            )
        elif self.hour < 24:
            return CrisisStage(
                stage_id=3,
                name="第三阶段：12-24小时 【长效修复期 · 终局定性】",
                hours_range="12:00 - 24:00 (六合聚人)",
                event_headline="联合监管检查组进驻总部，全网数十万买家开始申请全额退款，进入最终定调时刻！",
                options=[
                    CrisisOption(
                        id="stage3_fund",
                        title="【设立千万质保金】启动1亿元假一赔十基金，联合国家检测机构向全社会透明溯源",
                        description="断臂求生！用雷霆手段将灾难化为企业浴火重生的品控里程碑！",
                        cost=3000000.0,
                        anger_delta=-35,
                        trust_delta=+40
                    ),
                    CrisisOption(
                        id="stage3_pass_buck",
                        title="【拖延等待处罚】按常规程序缴纳罚款，关闭涉事店铺了事",
                        description="虽平息事件，但品牌商誉遭受不可逆重创，日活用户流失过半！",
                        cost=500000.0,
                        anger_delta=+5,
                        trust_delta=-10
                    )
                ]
            )
        return None

    @staticmethod
    def has_required_gate(option: CrisisOption, company: Company) -> bool:
        if not option.special_gate:
            return True
        return any(e.gate_id == option.special_gate for e in company.executives)

    @classmethod
    def effective_deltas(cls, option: CrisisOption, company: Company) -> Tuple[int, int]:
        if cls.has_required_gate(option, company):
            return option.anger_delta, option.trust_delta
        return int(option.anger_delta / 2), int(option.trust_delta / 2)

    def execute_choice(self, option_id: str, company: Company) -> Tuple[bool, str]:
        stage = self.get_current_stage()
        if not stage:
            return False, "危机处理阶段已结束。"

        selected_opt = next((o for o in stage.options if o.id == option_id), None)
        if not selected_opt:
            return False, "无效的选项编号。"

        # 扣除应对资金
        company.cash -= selected_opt.cost
        self.total_cost_spent += selected_opt.cost

        # 专属门派选项：缺少对应高管时效果减半
        anger_delta, trust_delta = self.effective_deltas(selected_opt, company)
        gate_note = "" if self.has_required_gate(selected_opt, company) else " (缺少专属高管·效果减半)"

        # 调整指标
        self.public_anger = max(0, min(100, self.public_anger + anger_delta))
        self.brand_trust = max(0, min(100, self.brand_trust + trust_delta))

        # 记录日志
        log_entry = f"[{stage.hours_range}] 决断：{selected_opt.title}{gate_note} | 怒火 {anger_delta:+d} (现:{self.public_anger}) | 信任 {trust_delta:+d} (现:{self.brand_trust})"
        self.action_logs.append(log_entry)

        # 时间推进
        if stage.stage_id == 1: self.hour = 4
        elif stage.stage_id == 2: self.hour = 12
        elif stage.stage_id == 3: self.hour = 24

        # 检查是否提前失败
        if self.public_anger >= ANGER_BAN_LINE:
            self.is_resolved = True
            self.verdict = "【惨败·监管封杀】：公众怒火突破极值！各大官媒联合通报批评，监管部门责令全平台停业整顿6个月，主要责任人被依法传唤，公司宣告脑死亡！"
            company.reputation = max(5, company.reputation - 50)
            return True, log_entry

        if self.brand_trust <= TRUST_DEATH_LINE:
            self.is_resolved = True
            self.verdict = "【惨败·品牌社会性死亡】：品牌信任彻底崩塌！用户集体卸载、商户成批撤店，合作方纷纷切割，平台沦为全网避之不及的反面教材！"
            company.reputation = max(5, company.reputation - 45)
            return True, log_entry

        # 24小时满期终局结算
        if self.hour >= 24:
            self.is_resolved = True
            if self.public_anger <= 35 and self.brand_trust >= 60:
                self.verdict = "【绝处逢生·卓越通关】：教科书级危机公关逆转！企业不仅承担了全部社会责任，更以千万赔偿基金和透明品控重塑了行业新标杆，商誉逆势飙升！"
                company.reputation = min(100, company.reputation + 20)
            elif self.public_anger <= 60:
                self.verdict = "【平庸过关·元气大伤】：勉强控制住了失控舆情，但付出巨额诉讼与罚款，品牌核心用户流失30%，需经历漫长的修复期。"
                company.reputation = max(20, company.reputation - 15)
            else:
                self.verdict = "【危机失控·沦为弃子】：未能有效化解公众怒火，平台被各应用商店全面下架，融资通道彻底封死，陷入慢性死亡。"
                company.reputation = max(10, company.reputation - 35)

        return True, log_entry
