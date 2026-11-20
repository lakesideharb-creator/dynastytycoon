#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
核心数理仿真引擎 (Core Cosmic Simulation Engine)
将天时、地利、人和结合，驱动全公司的月度经营结算与损益表核算
"""

from typing import Dict, List, Tuple
from .models import Company, Store, FinancialStatement, Executive
from .cosmic_clock import CosmicClock
from .nine_palaces import NinePalacesSystem
from .personnel import PersonnelSystem

class CosmicSimulationEngine:
    def __init__(self, clock: CosmicClock = None):
        self.clock = clock or CosmicClock()
        self.palaces_sys = NinePalacesSystem()
        self.personnel_sys = PersonnelSystem()

    def simulate_month(
        self,
        company: Company,
        marketing_budget: float = 0.0,
        misc_budget: float = 50000.0
    ) -> FinancialStatement:
        """
        进行一个自然月的全公司经营结算
        """
        # 1. 天时因子 f(T)
        f_time, time_details = self.clock.calculate_time_factor(company.industry)

        # 2. 人和因子 f(P)
        f_person, person_details = self.personnel_sys.calculate_personnel_factor(company.executives)

        # 3. 各门店地利因子 f(S) 与营收结算
        total_gross_revenue = 0.0
        total_store_rent = 0.0
        store_reports = []

        # 营销预算带来的额外客流加成 (边际递减)
        marketing_multiplier = 1.0 + (min(200000.0, marketing_budget) / 1000000.0)

        for store in company.stores:
            if not store.is_active:
                continue
            f_space = self.palaces_sys.calculate_store_space_factor(
                industry=company.industry,
                palace_id=store.palace_id,
                fengshui_modifier=company.fengshui_modifier
            )
            # 单店产出 = 基础流水 * f(T) * f(S) * f(P) * 营销加成
            store_rev = (store.effective_base_revenue() * f_time * f_space * f_person
                         * marketing_multiplier * company.store_revenue_multiplier(store))
            total_gross_revenue += store_rev
            total_store_rent += store.rent

        # 4. 成本核算
        total_payroll = company.total_monthly_payroll()
        active_stores = [s for s in company.stores if s.is_active]
        total_store_ops = sum(s.staff_cost for s in active_stores)
        total_maintenance = sum(s.maintenance_cost for s in active_stores)
        total_cost = total_store_rent + total_store_ops + total_maintenance + total_payroll + marketing_budget + misc_budget
        net_profit = total_gross_revenue - total_cost

        # 现金结算
        company.cash += net_profit

        # 门店老化与临时修正器到期
        for s in active_stores:
            s.age_months += 1
        company.tick_revenue_modifiers()

        statement = FinancialStatement(
            month=self.clock.month,
            gross_revenue=round(total_gross_revenue, 2),
            rent_expense=round(total_store_rent, 2),
            payroll_expense=round(total_payroll, 2),
            marketing_expense=round(marketing_budget, 2),
            miscellaneous_cost=round(misc_budget, 2),
            total_cost=round(total_cost, 2),
            net_profit=round(net_profit, 2),
            ending_cash=round(company.cash, 2),
            f_time=round(f_time, 3),
            f_space=round(sum(self.palaces_sys.calculate_store_space_factor(company.industry, s.palace_id, company.fengshui_modifier) for s in active_stores)/len(active_stores) if active_stores else 1.0, 3),
            f_person=round(f_person, 3),
            maintenance_expense=round(total_maintenance, 2),
        )

        company.financial_history.append(statement)
        return statement
