#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
立绘去背景工具测试（合成图，覆盖实际遇到的难点）
"""
import sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

import unittest

try:
    from PIL import Image, ImageDraw
    import remove_background as rb
    HAVE_PIL = True
except ImportError:          # Pillow 只是美术管线依赖，游戏本体不需要
    HAVE_PIL = False

PAPER = (240, 235, 222)
IVORY = (236, 230, 214)       # 与纸色非常接近，苏清墨的外套就是这种情况
INK = (20, 20, 20)


@unittest.skipUnless(HAVE_PIL, "需要 Pillow")
class TestChroma(unittest.TestCase):

    def setUp(self):
        self.img = Image.new("RGB", (100, 100), (255, 0, 255))
        d = ImageDraw.Draw(self.img)
        d.rectangle((10, 10, 40, 40), fill=(200, 55, 45))     # 朱砂红点缀
        d.rectangle((60, 10, 90, 40), fill=(78, 125, 91))     # 伤门绿衣服
        d.rectangle((10, 60, 40, 90), fill=(230, 190, 160))   # 肤色
        d.rectangle((60, 60, 90, 90), fill=(200, 80, 200))    # 边缘溢色

    def test_background_transparent_subject_opaque(self):
        out = rb.chroma_cutout(self.img)
        self.assertEqual(out.getpixel((0, 0))[3], 0)
        for xy in ((25, 25), (75, 25), (25, 75)):
            self.assertEqual(out.getpixel(xy)[3], 255, xy)

    def test_colors_preserved(self):
        out = rb.chroma_cutout(self.img)
        self.assertEqual(out.getpixel((25, 25))[:3], (200, 55, 45))
        self.assertEqual(out.getpixel((75, 25))[:3], (78, 125, 91))
        self.assertEqual(out.getpixel((25, 75))[:3], (230, 190, 160))

    def test_magenta_spill_removed(self):
        r, g, b, _ = rb.chroma_cutout(self.img).getpixel((75, 75))
        self.assertLessEqual(min(r, b), g)


@unittest.skipUnless(HAVE_PIL, "需要 Pillow")
class TestPaper(unittest.TestCase):

    def _figure(self):
        """纸色背景；描黑边的象牙色"衣服"从底边伸出画面；左上角有一团孤立墨点"""
        img = Image.new("RGB", (200, 200), PAPER)
        d = ImageDraw.Draw(img)
        d.rectangle((50, 80, 150, 199), fill=IVORY, outline=INK, width=3)
        d.ellipse((80, 30, 120, 80), fill=(225, 185, 150), outline=INK, width=3)   # 头
        d.ellipse((10, 10, 25, 25), fill=INK)                                      # 孤立墨点
        return img

    def test_ivory_garment_kept_and_background_removed(self):
        out = rb.paper_cutout(self._figure())
        self.assertEqual(out.getpixel((5, 100))[3], 0, "背景应透明")
        self.assertEqual(out.getpixel((100, 150))[3], 255, "与纸色相近的衣服不能被抠掉")
        self.assertEqual(out.getpixel((100, 55))[3], 255, "头部应保留")

    def test_isolated_splash_removed(self):
        out = rb.paper_cutout(self._figure())
        self.assertEqual(out.getpixel((17, 17))[3], 0)

    def test_trim_removes_thin_protrusion_only_when_enabled(self):
        img = self._figure()
        ImageDraw.Draw(img).line((50, 120, 20, 120), fill=INK, width=3)   # 细长的"发簪"
        self.assertGreater(rb.paper_cutout(img).getpixel((30, 120))[3], 0, "默认不削细长道具")
        self.assertEqual(rb.paper_cutout(img, trim=15).getpixel((30, 120))[3], 0)


@unittest.skipUnless(HAVE_PIL, "需要 Pillow")
class TestIsoTiles(unittest.TestCase):

    def _soft_tile(self):
        """模拟交付的地砖：菱形内部纯色，外圈 12px 羽化"""
        from PIL import ImageFilter
        w, h = 256, 128
        img = Image.new("RGBA", (w, h), (232, 200, 140, 0))
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).polygon([(128, 12), (232, 64), (128, 116), (24, 64)], fill=255)
        img.putalpha(mask.filter(ImageFilter.GaussianBlur(6)))
        return img

    def test_crisp_tile_fills_exact_diamond(self):
        out = rb.crisp_iso_tile(self._soft_tile())
        self.assertEqual(out.size, (256, 128))
        self.assertEqual(out.getpixel((128, 64))[3], 255)
        self.assertEqual(out.getpixel((3, 64))[3], 255, "左顶点附近应已铺满")
        self.assertEqual(out.getpixel((128, 3))[3], 255, "上顶点附近应已铺满")
        self.assertEqual(out.getpixel((5, 5))[3], 0, "菱形外应完全透明")
        self.assertEqual(out.getpixel((250, 120))[3], 0)

    def test_beam_shadow_constant_along_row(self):
        floor = rb.crisp_iso_tile(self._soft_tile())
        beam = rb.beam_shadow_tile(floor)
        # 沿 u 方向（与左上-右下边平行）移动，v 不变 → 亮度不变；跨 v 方向 → 中间最暗
        along = [beam.getpixel((128 - 64 + 2 * k, 64 + k))[0] for k in range(-20, 21, 10)]
        self.assertLessEqual(max(along) - min(along), 2, "同一行方向上阴影深浅应一致")
        center = beam.getpixel((128, 64))[0]
        edge = beam.getpixel((128, 6))[0]
        self.assertLess(center, edge, "阴影带中心应比两侧暗")


if __name__ == "__main__":
    unittest.main()
