#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
战役推进器、决策效果与盈亏解读测试
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import io
import unittest
from contextlib import redirect_stdout
from unittest import mock

import play
from src import Company, Store, Executive, SaveManager, CosmicClock
from src.campaign_runner import CampaignRunner, apply_effects
from src.insight import season_relation, explain_month, forecast_next_month

TEST_SLOT = "_unittest_runner"


def advance_to(runner: CampaignRunner, turn: int):
    while runner.turn < turn:
        runner.simulate_month(random_events=False)
        runner.advance()


class TestEffects(unittest.TestCase):

    def setUp(self):
        self.c = Company("c", "Cultural_Food", 1_000_000, reputation=98, executives=[
            Executive("1", "甲", "jing_men", "景门", "CEO", 1, stress=90, loyalty=50)])
        self.c.stores = [Store("sh_1", "老店", "xun_4", "上海", 100, 10, 20),
                         Store("li_1", "新店", "li_9", "成都", 100, 10, 20)]

    def test_basic_effects_and_clamps(self):
        apply_effects(self.c, [{"type": "cash", "amount": -200_000}, {"type": "reputation", "delta": 10},
                               {"type": "fengshui", "delta": 1.0},
                               {"type": "exec", "match": {"all": True}, "stress": 30, "loyalty": -5}])
        self.assertEqual(self.c.cash, 800_000)
        self.assertEqual(self.c.reputation, 100)
        self.assertEqual(self.c.fengshui_modifier, 0.35)
        self.assertEqual(self.c.executives[0].stress, 100)
        self.assertEqual(self.c.executives[0].loyalty, 45)

    def test_revenue_modifier_targets_and_expires(self):
        apply_effects(self.c, [{"type": "revenue_mod", "factor": 1.5, "months": 2, "id_prefix": ["li_"]}])
        old, new = self.c.stores
        self.assertEqual(self.c.store_revenue_multiplier(old), 1.0)
        self.assertEqual(self.c.store_revenue_multiplier(new), 1.5)
        self.c.tick_revenue_modifiers()
        self.assertEqual(self.c.store_revenue_multiplier(new), 1.5)
        self.c.tick_revenue_modifiers()
        self.assertEqual(self.c.store_revenue_multiplier(new), 1.0)

    def test_permanent_modifier_and_store_cost(self):
        apply_effects(self.c, [{"type": "revenue_mod", "factor": 0.9, "months": None},
                               {"type": "store_cost", "field": "staff_cost", "factor": 0.5, "id_prefix": ["sh_"]}])
        for _ in range(24):
            self.c.tick_revenue_modifiers()
        self.assertEqual(self.c.store_revenue_multiplier(self.c.stores[0]), 0.9)
        self.assertEqual(self.c.stores[0].staff_cost, 10)
        self.assertEqual(self.c.stores[1].staff_cost, 20)

    def test_remove_executive(self):
        apply_effects(self.c, [{"type": "exec", "match": {"name": "甲"}, "remove": True}])
        self.assertEqual(self.c.executives, [])

    def test_unknown_effect_raises(self):
        with self.assertRaises(ValueError):
            apply_effects(self.c, [{"type": "teleport"}])


class TestRunner(unittest.TestCase):

    def tearDown(self):
        path = SaveManager.save_path(TEST_SLOT)
        if os.path.exists(path):
            os.remove(path)

    def test_decisions_appear_on_their_turn_once(self):
        r = CampaignRunner(1)
        r.apply_main_choice("B")
        self.assertEqual(r.pending_decisions(), [])
        advance_to(r, 4)
        [ev] = r.pending_decisions()
        self.assertEqual(ev["id"], "s1_summer")
        ok, _ = r.apply_decision("s1_summer", "C")
        self.assertTrue(ok)
        self.assertEqual(r.pending_decisions(), [])

    def test_branch_requires_prior_choice(self):
        for terms, expected in (("B", "s2_milestone_hard"), ("A", "s2_milestone_soft")):
            r = CampaignRunner(2)
            r.apply_main_choice("A")
            advance_to(r, 3)
            r.apply_decision("s2_terms", terms)
            advance_to(r, 6)
            r.apply_decision("s2_pandemic", "C")
            advance_to(r, 10)
            self.assertEqual([e["id"] for e in r.pending_decisions()], [expected])

    def test_main_choice_gates_events(self):
        r = CampaignRunner(2)
        r.apply_main_choice("C")
        advance_to(r, 3)
        self.assertEqual(r.pending_decisions(), [], "未签对赌就不应出现对赌条款议题")

    def test_gated_option_unavailable_without_gate(self):
        r = CampaignRunner(3)
        r.apply_main_choice("B")          # 不聘休门COO
        advance_to(r, 3)
        [ev] = r.pending_decisions()
        xiu_opt = next(o for o in ev["options"] if o.get("requires_gate") == "xiu_men")
        ok, reason = r.option_available(xiu_opt)
        self.assertFalse(ok)
        self.assertIn("休门", reason)
        self.assertFalse(r.apply_decision(ev["id"], xiu_opt["key"])[0])

    def test_save_and_resume_keeps_decisions(self):
        r = CampaignRunner(1)
        r.apply_main_choice("B")
        advance_to(r, 4)
        r.apply_decision("s1_summer", "A")
        SaveManager.save_game(r.company, r.clock, 1, slot_name=TEST_SLOT, progress=r.progress())
        loaded = SaveManager.load_game(TEST_SLOT)
        r2 = CampaignRunner(1, company=loaded.company, clock=loaded.clock, progress=loaded.progress)
        self.assertEqual(r2.main_choice, "B")
        self.assertEqual(r2.turn, 4)
        self.assertEqual(r2.pending_decisions(), [])
        self.assertEqual(len(r2.company.revenue_modifiers), 1)


class TestInsight(unittest.TestCase):

    def test_season_relations(self):
        self.assertTrue(season_relation("Fire", "Fire").startswith("旺"))
        self.assertTrue(season_relation("Wood", "Fire").startswith("相"))
        self.assertTrue(season_relation("Fire", "Wood").startswith("休"))
        self.assertTrue(season_relation("Fire", "Metal").startswith("死"))
        self.assertTrue(season_relation("Metal", "Fire").startswith("囚"))

    def test_explain_and_forecast(self):
        r = CampaignRunner(3)
        r.apply_main_choice("B")
        r.simulate_month(random_events=False)
        text = "\n".join(explain_month(r.company, r.engine))
        for tag in ("【天时】", "【地利】", "【人和】", "伤杜相争"):
            self.assertIn(tag, text)
        self.assertIn("2024年03月", forecast_next_month(r.clock, r.company.industry))


class TestInteractiveCampaign(unittest.TestCase):

    def test_full_playthrough_scenario_3(self):
        # 主决策A；每月回车推进；三个决策点依次选 B(休门调解) / A(挽留赵勇) / A(发布会)
        inputs = ["A"] + [""] * 2 + ["B", ""] + [""] * 2 + ["A", ""] + [""] * 2 + ["A", ""] + [""] * 3
        out = io.StringIO()
        with mock.patch("builtins.input", side_effect=inputs), \
             mock.patch.object(play.EventSystem, "trigger_monthly_event", return_value=None), \
             redirect_stdout(out):
            play.run_campaign_interactive(3)
        text = out.getvalue()
        for snippet in ("董事会紧急议题", "本月盈亏解读", "下月预告", "你的关键决策", "恭喜通关"):
            self.assertIn(snippet, text)


if __name__ == "__main__":
    unittest.main()
