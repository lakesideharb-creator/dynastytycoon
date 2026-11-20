#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
数值表加载器：引擎用到的全部常量表都放在 data/*.json，Python 与 Godot 读同一份文件。
"""

import json
import os
from functools import lru_cache

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")


@lru_cache(maxsize=None)
def load(name: str) -> dict:
    with open(os.path.join(DATA_DIR, name), "r", encoding="utf-8") as f:
        return json.load(f)


def engine() -> dict:
    return load("engine_tables.json")


def random_events() -> dict:
    return load("random_events.json")
