#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
天时时钟系统 (Cosmic Clock System)
管理三元九运（二十年大周期）、四季月令（春夏秋冬）与日辰干支神煞演化
数值表见 data/engine_tables.json
"""

from typing import Dict, Tuple

from . import tables

_T = tables.engine()
MONTH_NAMES = _T["month_names"]
SEASON_NAMES = {int(k): v for k, v in _T["season_names"].items()}


def era_for_year(year: int) -> Dict:
    return next(e for e in _T["eras"] if year <= e["until_year"])


class CosmicClock:
    def __init__(self, start_year: int = 2024, start_month: int = 2):
        self.year = start_year
        self.month = start_month
        self._set_era()
        self.era_weights = _T["era_weights"]
        self.season_multipliers = _T["season_multipliers"]
        self.daily_shas = [(s["name"], s["mod"], s["desc"]) for s in _T["daily_shas"]]

    def _set_era(self):
        era = era_for_year(self.year)
        self.era_id = era["id"]
        self.era_name = era["name"]

    def get_season_key(self, month: int) -> str:
        return _T["season_of_month"][str(month)]

    def advance_month(self) -> Tuple[int, int]:
        self.month += 1
        if self.month > 12:
            self.month = 1
            self.year += 1
            self._set_era()
        return self.year, self.month

    def get_current_sha(self) -> Tuple[str, float, str]:
        # 基于年月循环抽取日辰神煞
        index = (self.year * 12 + self.month) % len(self.daily_shas)
        return self.daily_shas[index]

    def calculate_time_factor(self, industry: str) -> Tuple[float, Dict]:
        era_mod = self.era_weights.get(self.era_id, {}).get(industry, 1.0)
        season_key = self.get_season_key(self.month)
        elem = _T["industry_elements"].get(industry, _T["default_industry_element"])
        season_mod = self.season_multipliers[season_key].get(elem, 1.0)
        sha_name, sha_mod, sha_desc = self.get_current_sha()

        f_time = era_mod * season_mod * sha_mod
        details = {
            "era_name": self.era_name,
            "era_mod": era_mod,
            "season_name": SEASON_NAMES[self.month],
            "season_mod": season_mod,
            "sha_name": sha_name,
            "sha_mod": sha_mod,
            "sha_desc": sha_desc,
            "f_time": round(f_time, 3)
        }
        return f_time, details
