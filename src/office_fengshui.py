#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
企业总部风水工位DIY系统 (Office FengShui Building & Grid Engine)
实现等轴测/二维九宫办公室网格、视线/气流射线检测（Raycasting）、恶煞判定与吉位加成
"""

from dataclasses import dataclass, field
from typing import Dict, List, Tuple, Optional

# 九宫区域划分 (9x9 网格，每宫 3x3)
PALACE_GRID_MAP = {
    (0, 0): "qian_6", (0, 1): "qian_6", (0, 2): "qian_6",
    (1, 0): "qian_6", (1, 1): "qian_6", (1, 2): "qian_6",
    (2, 0): "qian_6", (2, 1): "qian_6", (2, 2): "qian_6",  # 乾六 (西北 0-2, 0-2)

    (3, 0): "kan_1", (3, 1): "kan_1", (3, 2): "kan_1",
    (4, 0): "kan_1", (4, 1): "kan_1", (4, 2): "kan_1",
    (5, 0): "kan_1", (5, 1): "kan_1", (5, 2): "kan_1",    # 坎一 (正北 3-5, 0-2)

    (6, 0): "gen_8", (6, 1): "gen_8", (6, 2): "gen_8",
    (7, 0): "gen_8", (7, 1): "gen_8", (7, 2): "gen_8",
    (8, 0): "gen_8", (8, 1): "gen_8", (8, 2): "gen_8",    # 艮八 (东北 6-8, 0-2)

    (0, 3): "dui_7", (0, 4): "dui_7", (0, 5): "dui_7",
    (1, 3): "dui_7", (1, 4): "dui_7", (1, 5): "dui_7",
    (2, 3): "dui_7", (2, 4): "dui_7", (2, 5): "dui_7",    # 兑七 (正西 0-2, 3-5)

    (3, 3): "zhong_5", (3, 4): "zhong_5", (3, 5): "zhong_5",
    (4, 3): "zhong_5", (4, 4): "zhong_5", (4, 5): "zhong_5",
    (5, 3): "zhong_5", (5, 4): "zhong_5", (5, 5): "zhong_5", # 中五 (中宫 3-5, 3-5)

    (6, 3): "zhen_3", (6, 4): "zhen_3", (6, 5): "zhen_3",
    (7, 3): "zhen_3", (7, 4): "zhen_3", (7, 5): "zhen_3",
    (8, 3): "zhen_3", (8, 4): "zhen_3", (8, 5): "zhen_3",    # 震三 (正东 6-8, 3-5)

    (0, 6): "kun_2", (0, 7): "kun_2", (0, 8): "kun_2",
    (1, 6): "kun_2", (1, 7): "kun_2", (1, 8): "kun_2",
    (2, 6): "kun_2", (2, 7): "kun_2", (2, 8): "kun_2",    # 坤二 (西南 0-2, 6-8)

    (3, 6): "li_9", (3, 7): "li_9", (3, 8): "li_9",
    (4, 6): "li_9", (4, 7): "li_9", (4, 8): "li_9",
    (5, 6): "li_9", (5, 7): "li_9", (5, 8): "li_9",        # 离九 (正南 3-5, 6-8)

    (6, 6): "xun_4", (6, 7): "xun_4", (6, 8): "xun_4",
    (7, 6): "xun_4", (7, 7): "xun_4", (7, 8): "xun_4",
    (8, 6): "xun_4", (8, 7): "xun_4", (8, 8): "xun_4"     # 巽四 (东南 6-8, 6-8)
}

PALACE_NAMES = {
    "qian_6": "乾位 (西北·尊贵权柄)",
    "kan_1": "坎位 (正北·深水藏财)",
    "gen_8": "艮位 (东北·稳健基石)",
    "dui_7": "兑位 (正西·口碑声量)",
    "zhong_5": "中宫 (太极·中央调度)",
    "zhen_3": "震位 (正东·雷鸣开拓)",
    "kun_2": "坤位 (西南·承载滋养)",
    "li_9": "离位 (正南·光明审美)",
    "xun_4": "巽位 (东南·风行流通)"
}

@dataclass
class GridItem:
    id: str
    name: str
    category: str        # desk, screen, plant, artifact, beam, door, window
    x: int
    y: int
    facing: str = "S"    # N, S, E, W
    role: str = ""       # President, Finance, CTO, Sales

@dataclass
class FengShuiAudit:
    score: int                     # 0-100分
    fengshui_modifier: float       # -0.30 ~ +0.30
    auspicious_perks: List[str]    # 吉格列表
    sha_penalties: List[str]       # 恶煞列表
    recommendations: List[str]     # 改造建议

class OfficeLayoutManager:
    def __init__(self, width: int = 9, height: int = 9):
        self.width = width
        self.height = height
        self.items: Dict[str, GridItem] = {}
        # 固定结构设施
        self.door_pos = (4, 8)       # 正南主大门
        self.window_pos = (4, 0)     # 正北落地大窗
        self.beam_rows = [3]         # y=3 为建筑承重横梁

    def get_palace_at(self, x: int, y: int) -> str:
        return PALACE_GRID_MAP.get((x, y), "zhong_5")

    def add_item(self, item: GridItem):
        self.items[item.id] = item

    def clear(self):
        self.items = {}

    def is_blocked(self, x: int, y: int) -> bool:
        for it in self.items.values():
            if it.x == x and it.y == y and it.category in ["screen", "plant", "wall"]:
                return True
        return False

    def check_through_draft_sha(self) -> Tuple[bool, str]:
        """
        穿堂煞射线检测 (Raycasting):
        检查从正南大门 (4,8) 到正北落地窗 (4,0) 是否有直接气流贯穿通道，且无玄关屏风/绿植阻隔
        """
        is_penetrated = True
        for y in range(1, 8):
            if self.is_blocked(4, y):
                is_penetrated = False
                break
        if is_penetrated:
            return True, "【穿堂大煞】：大门与落地大窗在正中轴直通对穿！气乘风则散，每月产生 15% 资金跑冒与坏账。"
        return False, "【藏风聚气】：中轴线已设置玄关/屏风遮挡，气流迂回婉转，化解穿堂风。"

    def audit_layout(self) -> FengShuiAudit:
        score = 50 # 基础分
        perks = []
        shas = []
        recs = []

        # 1. 检测穿堂煞
        has_draft, draft_desc = self.check_through_draft_sha()
        if has_draft:
            score -= 18
            shas.append(draft_desc)
            recs.append("建议在中轴线 (x=4, y=4或5) 摆放【玄关屏风】或【高叶发财树】切断穿堂气流。")
        else:
            score += 10
            perks.append(draft_desc)

        # 2. 遍历工位与道具进行微观检测
        for item in self.items.values():
            palace = self.get_palace_at(item.x, item.y)

            # --- 总裁办检测 ---
            if item.role == "President":
                # 乾位或艮位得位判定
                if palace in ["qian_6", "gen_8"]:
                    score += 15
                    perks.append(f"【乾位得位】：总裁办公桌坐落于 {PALACE_NAMES[palace]}，权威威信稳固，战略决策洞察力+15%。")
                else:
                    score -= 8
                    shas.append(f"【乾坤失位】：总裁桌落于 {PALACE_NAMES[palace]}，非首领之位，容易被下属架空。")
                    recs.append("建议将总裁办公室调整至西北乾位 (0-2, 0-2)。")

                # 背后靠山检测 (背后是否紧挨实墙 y=0 或有屏风)
                if item.facing == "S" and item.y == 0:
                    score += 10
                    perks.append("【背后实墙】：总裁椅后依实墙靠山，前方视野开阔，得贵人与资方坚实支持。")
                elif item.facing == "S" and item.y > 0 and not self.is_blocked(item.x, item.y - 1):
                    score -= 10
                    shas.append("【背门而坐】：总裁背后空旷悬虚无靠山，容易突遭背刺与合同纠纷。")
                    recs.append("建议总裁工位紧贴北实墙 (y=0) 或背后加设高大书架玄关。")

            # --- 财务室检测 ---
            elif item.role == "Finance":
                if palace == "kan_1":
                    score += 15
                    perks.append("【深水藏金】：财务室坐落于正北坎一深水位，水主流动生财，资金跑冒滴漏率清零。")
                elif palace == "li_9":
                    score -= 12
                    shas.append("【水火相克】：财务室落于正南离火位，火烈蒸水，企业开支不可遏制大失血。")
                    recs.append("财务工位切忌置于正南离火位，必须迁入正北坎水位避光隐蔽处。")

            # --- 技术研发检测 ---
            elif item.role == "CTO":
                if palace in ["zhen_3", "kan_1"]:
                    score += 12
                    perks.append(f"【极客雷动】：研发团队坐落于 {PALACE_NAMES[palace]}，灵感迸发，技术专利研发提速 20%。")

            # --- 销售战区检测 ---
            elif item.role == "Sales":
                if palace in ["zhen_3", "xun_4"]:
                    score += 10
                    perks.append(f"【战鼓雷鸣】：销售先锋坐落于 {PALACE_NAMES[palace]}，狼性签单欲望大增。")

            # --- 横梁压顶检测 ---
            if item.category == "desk" and item.y in self.beam_rows:
                score -= 12
                shas.append(f"【横梁压顶】：{item.name} 正上方横贯建筑承重梁，高管长期受压易生暗疾，精力扣减30点！")
                recs.append(f"建议将 {item.name} 移出 y=3 承重梁投影线，或增设石膏吊顶包覆。")

            # --- 专属风水法器检测 ---
            if item.category == "artifact":
                if item.id == "pixiu" and palace in ["qian_6", "zhong_5"]:
                    score += 10
                    perks.append("【招财貔貅】：汉白玉貔貅坐落于首领乾位，外部顶级资方参访意向提升 20%。")
                elif item.id == "wenchang" and palace in ["zhen_3", "kan_1"]:
                    score += 10
                    perks.append("【文昌高耸】：九层紫铜文昌塔镇守研发核心区，技术代码崩溃概率降为零。")
                elif item.id == "fishtank" and palace in ["xun_4", "kan_1"]:
                    score += 8
                    perks.append("【聚宝活水】：水草造景鱼缸激活东南巽位，现金流周转速度提升 15%。")

        final_score = max(5, min(100, score))
        # 风水加成修正: 50分为基准，范围 -0.25 到 +0.25
        modifier = round((final_score - 50) / 100.0 * 0.40, 3)

        return FengShuiAudit(
            score=final_score,
            fengshui_modifier=modifier,
            auspicious_perks=perks,
            sha_penalties=shas,
            recommendations=recs
        )

    def render_ascii_map(self) -> str:
        """渲染办公室 ASCII 楼层平面图"""
        grid = [[" · " for _ in range(self.width)] for _ in range(self.height)]
        
        # 标注大门与大窗
        grid[self.door_pos[1]][self.door_pos[0]] = "[门]"
        grid[self.window_pos[1]][self.window_pos[0]] = "[窗]"

        # 标注横梁
        for r in self.beam_rows:
            for c in range(self.width):
                if grid[r][c] == " · ":
                    grid[r][c] = " ~ " # 横梁波纹

        # 填充实体
        for it in self.items.values():
            symbol = " ? "
            if it.role == "President": symbol = " 👑"
            elif it.role == "Finance": symbol = " 💰"
            elif it.role == "CTO": symbol = " 💻"
            elif it.role == "Sales": symbol = " ⚔️"
            elif it.category == "screen": symbol = " █ "
            elif it.category == "plant": symbol = " 🌿"
            elif it.id == "pixiu": symbol = " 🦁"
            elif it.id == "wenchang": symbol = " 🗼"
            elif it.id == "fishtank": symbol = " 🐟"
            grid[it.y][it.x] = symbol

        lines = []
        lines.append("      [正北·落地大窗 (01坎位 / 08艮位 / 06乾位)]")
        lines.append("   ┌" + "───" * self.width + "┐")
        for y in range(self.height):
            row_str = "".join(grid[y])
            beam_tag = " <横梁>" if y in self.beam_rows else ""
            lines.append(f"{y:02d} │{row_str}│{beam_tag}")
        lines.append("   └" + "───" * self.width + "┘")
        lines.append("      [正南·办公大门 (09离位 / 02坤位 / 04巽位)]")
        return "\n".join(lines)

    @staticmethod
    def create_chaotic_preset() -> "OfficeLayoutManager":
        """生成恶煞缠身的初始糟糕布局 (穿堂煞 + 横梁压顶 + 财务在离火)"""
        mgr = OfficeLayoutManager()
        # 总裁桌坐在正中穿堂线上且背后无靠
        mgr.add_item(GridItem("p_desk", "总裁办公桌", "desk", 4, 3, facing="S", role="President")) # 正好在横梁上且无屏风
        # 财务在正南离火位
        mgr.add_item(GridItem("f_desk", "财务总监桌", "desk", 4, 7, facing="N", role="Finance"))
        # 研发桌在正西兑位
        mgr.add_item(GridItem("cto_desk", "CTO研发桌", "desk", 1, 4, facing="E", role="CTO"))
        return mgr

    @staticmethod
    def create_harmonious_preset() -> "OfficeLayoutManager":
        """生成八卦归位、化煞聚财的卓越风水布局"""
        mgr = OfficeLayoutManager()
        # 1. 屏风阻断穿堂煞
        mgr.add_item(GridItem("screen_1", "紫檀木玄关屏风", "screen", 4, 5, facing="N"))
        mgr.add_item(GridItem("plant_1", "高叶招财树", "plant", 4, 4, facing="N"))

        # 2. 总裁办调入西北乾位，紧依实墙，前方无梁
        mgr.add_item(GridItem("p_desk", "总裁乾位实木案", "desk", 1, 0, facing="S", role="President"))
        mgr.add_item(GridItem("pixiu", "汉白玉招财貔貅", "artifact", 2, 0, facing="S"))

        # 3. 财务室迁入正北坎一深水藏金位
        mgr.add_item(GridItem("f_desk", "财务保密专案桌", "desk", 4, 1, facing="S", role="Finance"))

        # 4. CTO研发迁入正东震三雷鸣位，配置文昌塔
        mgr.add_item(GridItem("cto_desk", "CTO极客研发台", "desk", 7, 4, facing="W", role="CTO"))
        mgr.add_item(GridItem("wenchang", "九层紫铜文昌塔", "artifact", 8, 4, facing="W"))

        # 5. 东南巽位摆放鱼缸
        mgr.add_item(GridItem("fishtank", "流动生态鱼缸", "artifact", 7, 7, facing="N"))
        return mgr
