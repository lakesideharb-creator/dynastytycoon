#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
企业总部风水工位DIY系统单元测试套件
"""

import unittest
import os
import sys

current_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

from src.office_fengshui import OfficeLayoutManager, GridItem

class TestOfficeFengShui(unittest.TestCase):
    def test_through_draft_sha(self):
        mgr = OfficeLayoutManager()
        # 无任何遮挡 -> 触发穿堂煞
        has_draft, _ = mgr.check_through_draft_sha()
        self.assertTrue(has_draft, "门窗直冲中轴无阻挡时必须触发穿堂煞")

        # 增加屏风遮挡
        mgr.add_item(GridItem("scr", "屏风", "screen", 4, 4))
        has_draft2, _ = mgr.check_through_draft_sha()
        self.assertFalse(has_draft2, "中轴线上放置屏风后穿堂煞必须被消除")

    def test_beam_overhead(self):
        mgr = OfficeLayoutManager()
        # 工位放置在 y=3 (承重横梁上)
        mgr.add_item(GridItem("d1", "测试工位", "desk", 2, 3))
        audit = mgr.audit_layout()
        has_beam_sha = any("横梁压顶" in s for s in audit.sha_penalties)
        self.assertTrue(has_beam_sha, "工位落于横梁投影线必须触发横梁压顶恶煞")

    def test_president_and_finance_positioning(self):
        # 糟糕布局：总裁在离位无靠山，财务在离位
        mgr_bad = OfficeLayoutManager()
        mgr_bad.add_item(GridItem("p", "总裁桌", "desk", 4, 7, facing="S", role="President"))
        mgr_bad.add_item(GridItem("f", "财务桌", "desk", 4, 6, facing="N", role="Finance"))
        audit_bad = mgr_bad.audit_layout()
        self.assertTrue(any("乾坤失位" in s for s in audit_bad.sha_penalties))
        self.assertTrue(any("水火相克" in s for s in audit_bad.sha_penalties))

        # 优良布局：总裁在乾位依墙，财务在正北坎位
        mgr_good = OfficeLayoutManager()
        mgr_good.add_item(GridItem("p", "总裁桌", "desk", 1, 0, facing="S", role="President"))
        mgr_good.add_item(GridItem("f", "财务桌", "desk", 4, 1, facing="S", role="Finance"))
        audit_good = mgr_good.audit_layout()
        self.assertTrue(any("乾位得位" in p for p in audit_good.auspicious_perks))
        self.assertTrue(any("深水藏金" in p for p in audit_good.auspicious_perks))

    def test_presets_contrast(self):
        chaotic = OfficeLayoutManager.create_chaotic_preset().audit_layout()
        harmonious = OfficeLayoutManager.create_harmonious_preset().audit_layout()

        self.assertLessEqual(chaotic.score, 30, "混乱初始风水评分应在30分以下")
        self.assertLess(chaotic.fengshui_modifier, 0.0, "混乱初始风水加成应为负扣减")

        self.assertGreaterEqual(harmonious.score, 85, "调和风水评分应达到85分以上")
        self.assertGreater(harmonious.fengshui_modifier, 0.10, "调和风水加成应大于+10%")

if __name__ == "__main__":
    unittest.main()
