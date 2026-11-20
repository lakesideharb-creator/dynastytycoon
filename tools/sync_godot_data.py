#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把仓库根目录 data/ 下 Godot 需要的数据文件同步到 godot/data/（data/ 是唯一数据源）。
改完 data/*.json 后运行一次；tests/test_godot_sync.py 会检查两边是否一致。

用法：python3 tools/sync_godot_data.py [--check]
"""
import argparse
import filecmp
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "data")
DST = os.path.join(ROOT, "godot", "data")
FILES = ["engine_tables.json", "campaign_scenarios.json", "random_events.json",
         "nine_palaces.json", "eight_gates.json", "eight_gods.json"]


def out_of_sync():
    return [f for f in FILES if not os.path.exists(os.path.join(DST, f))
            or not filecmp.cmp(os.path.join(SRC, f), os.path.join(DST, f), shallow=False)]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="只检查，不复制；不一致时返回非零")
    args = ap.parse_args(argv)
    stale = out_of_sync()
    if args.check:
        print("一致" if not stale else f"不一致：{stale}")
        return 1 if stale else 0
    os.makedirs(DST, exist_ok=True)
    for f in stale:
        shutil.copyfile(os.path.join(SRC, f), os.path.join(DST, f))
        print(f"已同步 {f}")
    if not stale:
        print("已是最新")
    return 0


if __name__ == "__main__":
    sys.exit(main())
