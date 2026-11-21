#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
美术资源命名与规格检查：文件名必须能和游戏数据中的 id 对上（Godot 端按 id 拼路径加载）
只检查已经交付的类别；某类目录还不存在时跳过，不要求资源一次到齐。
"""
import sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

import json
import unittest

from src import CampaignManager

ASSETS = os.path.join(ROOT, "godot", "assets")
EXPRESSIONS = ("neutral", "pleased", "stressed", "angry")
MAIN_CAST = ("su_qingmo", "shen_wuben", "zhao_yong", "lin_fan", "li_dao", "zhang_bo",
             "chen_mo", "wen_runsheng", "gu_jingran", "qian_shouxin", "wen_he")

# 与 docs/09_Art_Audio_Prompts.md 第 3、4 节的曲目/音效 id 一致
MUSIC = ("theme_main", "season_spring_wood", "season_summer_fire", "season_autumn_metal",
         "season_winter_water", "decision_tension", "crisis_war_room", "fengshui_studio",
         "sandbox_era", "sting_victory", "sting_defeat", "sting_bankrupt")
SFX = ("ui_click", "ui_hover", "ui_confirm", "ui_cancel", "ui_error", "ui_tab_switch", "compass_rotate",
       "month_advance", "report_print", "cash_gain", "cash_loss", "season_change", "forecast_up",
       "forecast_down", "decision_open", "event_opportunity", "event_crisis", "event_tengshe",
       "exec_hire", "exec_leave", "friction_clash", "place_furniture", "place_artifact",
       "sha_detected", "sha_resolved", "fengshui_score_up", "store_open", "store_close",
       "bankrupt", "victory")

try:
    from PIL import Image
    HAVE_PIL = True
except ImportError:
    HAVE_PIL = False


# 已写进 docs/09_Art_Audio_Prompts.md、等待美术交付的决策卡（游戏内缺图时决策卡不显示插画）
ART_PENDING: set = set()


def data_ids(name, key):
    with open(os.path.join(ROOT, "data", name), encoding="utf-8") as f:
        return [x["id"] for x in json.load(f)[key]]


def present(sub):
    """目录下的资源文件（忽略 Godot 生成的 .import 元数据）"""
    d = os.path.join(ASSETS, sub)
    if not os.path.isdir(d):
        return None
    return {f for f in os.listdir(d) if not f.endswith(".import") and not f.startswith(".")}


class TestAssetNaming(unittest.TestCase):

    def _expect(self, sub, names):
        files = present(sub)
        if files is None:
            self.skipTest(f"assets/{sub} 尚未交付")
        missing = sorted(n for n in names if n not in files)
        self.assertEqual(missing, [], f"assets/{sub} 缺少：{missing}")

    def test_gate_and_god_icons_match_data_ids(self):
        self._expect("icons", [f"gate_{g}.png" for g in data_ids("eight_gates.json", "gates")])
        self._expect("icons", [f"god_{g}.png" for g in data_ids("eight_gods.json", "gods")])
        self._expect("icons", [f"element_{e}.png" for e in ("wood", "fire", "earth", "metal", "water")])
        self._expect("icons", [f"season_{s}.png" for s in ("spring", "summer", "autumn", "winter")])

    def test_decision_cards_cover_all_decision_points(self):
        ids = [dp["id"] for s in CampaignManager.get_all_scenarios_meta() for dp in s.get("decision_points", [])]
        self.assertTrue(ART_PENDING <= set(ids), f"ART_PENDING 里有已不存在的决策点：{ART_PENDING - set(ids)}")
        files = present("events") or set()
        delivered = sorted(i for i in ART_PENDING if f"{i}.png" in files)
        self.assertEqual(delivered, [], f"这些决策卡已交付，请从 ART_PENDING 删掉：{delivered}")
        self._expect("events", [f"{i}.png" for i in ids if i not in ART_PENDING])

    def test_decision_cards_use_lossy_import(self):
        """决策卡是 1920×1080 插画、游戏里只显示中间横条：按有损 WebP 导入（compress/mode=1），否则网页版体积翻倍"""
        d = os.path.join(ASSETS, "events")
        if not os.path.isdir(d):
            self.skipTest("assets/events 尚未交付")
        lossless = []
        for f in sorted(os.listdir(d)):
            if f.endswith(".png.import"):
                with open(os.path.join(d, f), encoding="utf-8") as fh:
                    if "compress/mode=1" not in fh.read():
                        lossless.append(f[:-7])
        self.assertEqual(lossless, [], f"这些决策卡没有按有损压缩导入（.import 里改成 compress/mode=1、lossy_quality=0.85）：{lossless}")

    def test_portraits(self):
        self._expect("portraits", [f"{c}_{e}.png" for c in MAIN_CAST for e in EXPRESSIONS])
        self._expect("portraits", [f"talent_{g}_{x}.png" for g in data_ids("eight_gates.json", "gates") for x in "mf"])

    def test_audio_files(self):
        self._expect("music", [f"{m}.ogg" for m in MUSIC])
        self._expect("sfx", [f"{s}.ogg" for s in SFX])

    def test_no_stray_files(self):
        """资源目录里不应出现无法被任何 id 引用的文件（例如命名拼错）"""
        icons = present("icons") or set()
        valid_icon = ({f"gate_{g}.png" for g in data_ids("eight_gates.json", "gates")}
                      | {f"god_{g}.png" for g in data_ids("eight_gods.json", "gods")}
                      | {f"element_{e}.png" for e in ("wood", "fire", "earth", "metal", "water")}
                      | {f"season_{s}.png" for s in ("spring", "summer", "autumn", "winter")})
        self.assertEqual(sorted(icons - valid_icon), [])


@unittest.skipUnless(HAVE_PIL, "需要 Pillow")
class TestAssetSpecs(unittest.TestCase):

    def _check(self, sub, size, need_alpha):
        files = present(sub)
        if files is None:
            self.skipTest(f"assets/{sub} 尚未交付")
        for f in sorted(files):
            if not f.endswith(".png"):
                continue
            im = Image.open(os.path.join(ASSETS, sub, f))
            with self.subTest(file=f"{sub}/{f}"):
                if size:
                    self.assertEqual(im.size, size)
                if need_alpha:
                    self.assertEqual(im.mode, "RGBA", "应为透明底")

    def test_portraits_transparent_1024(self):
        self._check("portraits", (1024, 1024), True)

    def test_cards_and_scenes_1080p(self):
        self._check("events", (1920, 1080), False)
        self._check("scenes", (1920, 1080), False)

    def test_icons_transparent_256(self):
        self._check("icons", (256, 256), True)

    def test_office_tiles_are_2_to_1(self):
        files = present("office")
        if files is None:
            self.skipTest("assets/office 尚未交付")
        for f in sorted(files):
            im = Image.open(os.path.join(ASSETS, "office", f))
            with self.subTest(file=f):
                self.assertEqual(im.mode, "RGBA")
                self.assertEqual(im.size, (256, 128) if f.startswith("tile_") else (256, 256))


if __name__ == "__main__":
    unittest.main()
