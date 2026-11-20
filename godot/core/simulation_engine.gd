class_name CosmicSimulationEngine
extends RefCounted
## 月度经营结算（对应 src/simulation_engine.py）
## 单店产出 = 有效基础流水 × f(T) × f(S) × f(P) × 营销加成 × 决策修正

var clock: CosmicClock
var palaces_sys := NinePalacesSystem.new()
var personnel_sys := PersonnelSystem.new()


func _init(c: CosmicClock = null) -> void:
	clock = c if c else CosmicClock.new()


func simulate_month(company: Company, marketing_budget: float = 0.0, misc_budget: float = 50000.0) -> FinancialStatement:
	var f_time: float = clock.calculate_time_factor(company.industry)["value"]
	var f_person: float = personnel_sys.calculate_personnel_factor(company.executives)["value"]
	var marketing_multiplier := 1.0 + (minf(200000.0, marketing_budget) / 1000000.0)

	var gross := 0.0
	var rent := 0.0
	var active := company.active_stores()
	for store in active:
		var f_space := palaces_sys.calculate_store_space_factor(company.industry, store.palace_id, company.fengshui_modifier)
		gross += store.effective_base_revenue() * f_time * f_space * f_person * marketing_multiplier * company.store_revenue_multiplier(store)
		rent += store.rent

	var payroll := company.total_monthly_payroll()
	var ops := 0.0
	var maintenance := 0.0
	for s in active:
		ops += s.staff_cost
	for s in active:
		maintenance += s.maintenance_cost
	var total_cost := rent + ops + maintenance + payroll + marketing_budget + misc_budget
	var net := gross - total_cost
	company.cash += net

	for s in active:
		s.age_months += 1
	company.tick_revenue_modifiers()

	var f_space_avg := 1.0
	if not active.is_empty():
		var sum := 0.0
		for s in active:
			sum += palaces_sys.calculate_store_space_factor(company.industry, s.palace_id, company.fengshui_modifier)
		f_space_avg = sum / active.size()

	var st := FinancialStatement.new()
	st.month = clock.month
	st.gross_revenue = PyFmt.round_to(gross, 2)
	st.rent_expense = PyFmt.round_to(rent, 2)
	st.payroll_expense = PyFmt.round_to(payroll, 2)
	st.marketing_expense = PyFmt.round_to(marketing_budget, 2)
	st.miscellaneous_cost = PyFmt.round_to(misc_budget, 2)
	st.total_cost = PyFmt.round_to(total_cost, 2)
	st.net_profit = PyFmt.round_to(net, 2)
	st.ending_cash = PyFmt.round_to(company.cash, 2)
	st.f_time = PyFmt.round_to(f_time, 3)
	st.f_space = PyFmt.round_to(f_space_avg, 3)
	st.f_person = PyFmt.round_to(f_person, 3)
	st.maintenance_expense = PyFmt.round_to(maintenance, 2)
	company.financial_history.append(st)
	return st
