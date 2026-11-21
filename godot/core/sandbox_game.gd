class_name SandboxGame
extends RefCounted
## 二十年自由沙盒（对应 src/sandbox.py SandboxGame）：招人 → 选址开店 → 月度结算 → 关店止损 → 终局评级
## 参数读 res://data/sandbox.json；不含随机部分的规则与 Python 逐项一致，由 golden 测试对照。

var company: Company
var clock: CosmicClock
var engine: CosmicSimulationEngine
var talent_pool: TalentPool
var event_sys := EventSystem.new()
var industry_cfg: Dictionary
var turn := 0
var is_bankrupt := false
var game_log: Array[String] = []
var rng: RandomNumberGenerator


static func data() -> Dictionary:
	return DataTables.load_json("sandbox.json")


static func econ() -> Dictionary:
	return data()["economy"]


static func industries() -> Array:
	return data()["industries"]


static func industry(key: String) -> Dictionary:
	for v in industries():
		if v["key"] == key:
			return v
	return {}


static func palace_label(palace_id: String) -> String:
	for p in data()["palaces"]:
		if p["palace_id"] == palace_id:
			return p["label"]
	return palace_id


static func city_of(palace_id: String) -> String:
	var label := palace_label(palace_id)
	return label.split("·")[1] if "·" in label else label


## 推荐宫位：该行业九宫亲和度最高的两宫（与 Python INDUSTRIES[...]["best_palaces"] 一致）
static func best_palaces(industry_key: String) -> Array:
	var aff: Dictionary = NinePalacesSystem.new().industry_affinities.get(industry_key, {})
	var keys := aff.keys()
	var order := range(keys.size())
	order.sort_custom(func(a, b): return float(aff[keys[a]]) > float(aff[keys[b]]) or (float(aff[keys[a]]) == float(aff[keys[b]]) and a < b))
	return order.slice(0, 2).map(func(i): return keys[i])


static func create_new_game(company_name: String, industry_key: String, starting_cash: float, home_palace: String,
		r: RandomNumberGenerator = null) -> SandboxGame:
	var g := SandboxGame.new()
	g.rng = r if r else RandomNumberGenerator.new()
	if r == null:
		g.rng.randomize()
	var e := econ()
	g.industry_cfg = industry(industry_key)
	var c := Company.new()
	c.name = company_name
	c.industry = industry_key
	c.cash = starting_cash
	c.reputation = int(e["starting_reputation"])
	var hq := Store.new()
	hq.id = "hq_001"
	hq.name = "%s·总部运营中心" % company_name
	hq.palace_id = home_palace
	hq.city_name = city_of(home_palace)
	hq.base_revenue = float(g.industry_cfg["base_revenue"]) * float(e["sandbox_revenue_scale"])
	hq.rent = float(g.industry_cfg["rent"])
	hq.staff_cost = float(g.industry_cfg["staff_cost"])
	hq.decay_rate = float(e["store_decay_rate"])
	hq.maintenance_cost = float(e["hq_invest_equiv"]) * float(e["maintenance_rate"])
	hq.invest = float(e["hq_invest_equiv"])
	c.stores.append(hq)
	g.company = c
	g.clock = CosmicClock.new(int(e["start_year"]))
	g.engine = CosmicSimulationEngine.new(g.clock)
	g.talent_pool = TalentPool.new(g.rng)
	g.talent_pool.refresh_market()
	g.game_log.append("[%d年%02d月] %s 于【%s】正式起航！起步资金 %s，行业：%s" % [
		g.clock.year, g.clock.month, company_name, palace_label(home_palace), Money.short(starting_cash), g.industry_cfg["name"]])
	return g


func _stamp() -> String:
	return "[%d年%02d月]" % [clock.year, clock.month]


# ─── 月度推进 ────────────────────────────────────────────────────────────────
## 返回 {year, month, statement, event, is_bankrupt, turn}
func advance_month(marketing_budget: float = 0.0, random_events := true) -> Dictionary:
	if is_bankrupt:
		return {"error": "公司已破产，请重新开始新局。"}
	var st := engine.simulate_month(company, marketing_budget, float(econ()["sandbox_misc_cost"]))
	var event = event_sys.trigger_monthly_event(company, rng) if random_events else null
	turn += 1
	var y := clock.year
	var m := clock.month
	clock.advance_month()
	if company.cash < 0:
		is_bankrupt = true
		game_log.append("[%d年%02d月] 资金链断裂！公司宣告破产。" % [y, m])
	var line := "[%d年%02d月] 净利润 %s　现金 %s　商誉 %d" % [y, m, Money.short(st.net_profit), Money.short(company.cash), company.reputation]
	if event != null:
		line += "　事件：" + str(event.get("name", ""))
	game_log.append(line)
	return {"year": y, "month": m, "statement": st, "event": event, "is_bankrupt": is_bankrupt, "turn": turn}


# ─── 雇佣人才 ───────────────────────────────────────────────────────────────
## 返回 {ok, msg, exec}
func hire_talent(candidate_idx: int, role: String, salary: int) -> Dictionary:
	var pool := talent_pool.available
	if candidate_idx < 0 or candidate_idx >= pool.size():
		return {"ok": false, "msg": "候选人编号无效。"}
	var cand: Dictionary = pool[candidate_idx]
	if salary > company.cash * float(econ()["hire_salary_cash_cap"]):
		return {"ok": false, "msg": "开出的薪资超过公司现金的 %d%%，风险过高。" % roundi(float(econ()["hire_salary_cash_cap"]) * 100)}
	var e := talent_pool.hire(cand, role, salary)
	if e == null:
		return {"ok": false, "msg": "%s 拒绝了你的报价 %s/月（底线 %s/月）。" % [cand["name"], Money.full(salary), Money.full(int(cand["min_salary"]))]}
	company.executives.append(e)
	var msg := "成功延揽 %s【%s】担任%s，月薪 %s。" % [e.name, e.gate_name, RoleNames.cn(role), Money.full(salary)]
	game_log.append("%s 人才引进：%s" % [_stamp(), msg])
	return {"ok": true, "msg": msg, "exec": e}


# ─── 开店 ───────────────────────────────────────────────────────────────────
## 新店的月基础营收（未乘天时/地利/人和），用于预览与开店
func new_store_base_revenue(palace_id: String, invest: float) -> float:
	var e := econ()
	var scale := invest / float(e["ref_store_invest"])
	return float(industry_cfg["base_revenue"]) * float(e["sandbox_revenue_scale"]) \
			* pow(scale, float(e["invest_revenue_exp"])) * saturation(palace_id)


func same_palace_count(palace_id: String) -> int:
	var n := 0
	for s in company.stores:
		if s.is_active and s.palace_id == palace_id:
			n += 1
	return n


func saturation(palace_id: String) -> float:
	return pow(float(econ()["palace_saturation"]), same_palace_count(palace_id))


## 返回 {ok, msg, store}；rent_mult / staff_mult 小于 0 时随机抽取（对照测试传入固定值）
func open_new_store(store_name: String, palace_id: String, invest: float, rent_mult := -1.0, staff_mult := -1.0) -> Dictionary:
	var e := econ()
	if invest < float(e["min_store_invest"]):
		return {"ok": false, "msg": "投资额过低：开设新网点至少需要 %s。" % Money.short(float(e["min_store_invest"]))}
	if invest > company.cash:
		return {"ok": false, "msg": "资金不足：需要 %s，账面仅剩 %s。" % [Money.short(invest), Money.short(company.cash)]}
	if invest > float(e["max_store_invest"]):
		return {"ok": false, "msg": "投资额过高：单店投资上限为 %s。" % Money.short(float(e["max_store_invest"]))}
	var scale := invest / float(e["ref_store_invest"])
	var same := same_palace_count(palace_id)
	var base_rev := new_store_base_revenue(palace_id, invest)
	company.cash -= invest
	if rent_mult < 0:
		rent_mult = rng.randf_range(float(e["rent_mult_range"][0]), float(e["rent_mult_range"][1]))
	if staff_mult < 0:
		staff_mult = rng.randf_range(float(e["staff_mult_range"][0]), float(e["staff_mult_range"][1]))
	var s := Store.new()
	s.id = "store_%03d" % (company.stores.size() + 1)
	s.name = store_name
	s.palace_id = palace_id
	s.city_name = city_of(palace_id)
	s.base_revenue = base_rev
	s.rent = float(industry_cfg["rent"]) * pow(scale, float(e["invest_cost_exp"])) * rent_mult
	s.staff_cost = float(industry_cfg["staff_cost"]) * pow(scale, float(e["invest_cost_exp"])) * staff_mult
	s.decay_rate = float(e["store_decay_rate"])
	s.maintenance_cost = invest * float(e["maintenance_rate"])
	s.invest = invest
	company.stores.append(s)
	var f_space := engine.palaces_sys.calculate_store_space_factor(company.industry, palace_id)
	var msg := "新网点【%s】于%s落成！月基础营收 %s（结算时乘九宫空间因子×%.2f%s），投入 %s" % [
		store_name, palace_label(palace_id).split("·")[0], Money.short(base_rev), f_space,
		("，同宫已有%d家·饱和×%.2f" % [same, pow(float(e["palace_saturation"]), same)]) if same > 0 else "", Money.short(invest)]
	game_log.append("%s 扩张：%s" % [_stamp(), msg])
	return {"ok": true, "msg": msg, "store": s}


# ─── 门店盈亏预估与关店 ──────────────────────────────────────────────────────
## 按当月天时、地利、人和估算单店月利润（不含公司级薪酬与杂项）
func estimate_store_profit(store: Store) -> float:
	var f_time := float(clock.calculate_time_factor(company.industry)["value"])
	var f_person := float(engine.personnel_sys.calculate_personnel_factor(company.executives)["value"])
	var f_space := engine.palaces_sys.calculate_store_space_factor(company.industry, store.palace_id, company.fengshui_modifier)
	var revenue := store.effective_base_revenue() * f_time * f_space * f_person
	return revenue - (store.rent + store.staff_cost + store.maintenance_cost)


func salvage_value(store: Store) -> float:
	return store.invest * float(econ()["store_salvage_rate"])


func close_store(store_id: String) -> Dictionary:
	var active := company.active_stores()
	var store: Store = null
	for s in active:
		if s.id == store_id:
			store = s
	if store == null:
		return {"ok": false, "msg": "门店编号无效或已关闭。"}
	if active.size() <= 1:
		return {"ok": false, "msg": "这是最后一家营业网点，无法关闭。"}
	var salvage := salvage_value(store)
	store.is_active = false
	company.cash += salvage
	var msg := "已关闭【%s】（营业 %d 个月），回收残值 %s。" % [store.name, store.age_months, Money.short(salvage)]
	game_log.append("%s 收缩：%s" % [_stamp(), msg])
	return {"ok": true, "msg": msg}


func refresh_talent_market() -> void:
	talent_pool.refresh_market()


# ─── 终局 ───────────────────────────────────────────────────────────────────
func net_assets() -> float:
	var v := company.cash
	for s in company.stores:
		if s.is_active:
			v += s.effective_base_revenue() * float(econ()["store_value_months"])
	return v


func monthly_fixed_cost() -> float:
	var t := company.total_monthly_payroll() + float(econ()["sandbox_misc_cost"])
	for s in company.active_stores():
		t += s.rent + s.staff_cost + s.maintenance_cost
	return t


func last_year_profit() -> float:
	var t := 0.0
	for f in company.financial_history.slice(-12):
		t += f.net_profit
	return t


## 返回 data/sandbox.json 中的结局字典（grade/icon/title/description/unlock_condition）
func check_ending() -> Dictionary:
	var ends: Array = data()["endings"]
	var th: Dictionary = data()["ending_thresholds"]
	if is_bankrupt or company.cash < 0:
		return ends[4]
	var na := net_assets()
	var hist := company.financial_history
	var years := int(th["s_profitable_years"])
	var recent := hist.slice(-12 * years)
	var five := recent.size() == 12 * years
	if five:
		for i in range(0, recent.size(), 12):
			var y := 0.0
			for f in recent.slice(i, i + 12):
				y += f.net_profit
			if not (y > 0):
				five = false
	var ly := last_year_profit() if not hist.is_empty() else 0.0
	var stores := company.active_stores().size()
	if na >= float(th["s_assets"]) and company.reputation >= int(th["s_reputation"]) and five and stores >= int(th["s_min_stores"]):
		return ends[0]
	if na >= float(th["a_assets"]) and company.reputation >= int(th["a_reputation"]):
		return ends[1]
	if na >= float(th["b_assets"]) and ly > 0:
		return ends[2]
	return ends[3]


func years_left() -> int:
	return int(econ()["end_year"]) - clock.year + 1


func is_game_over() -> bool:
	return is_bankrupt or clock.year > int(econ()["end_year"])


# ─── 存档 ───────────────────────────────────────────────────────────────────
func to_dict() -> Dictionary:
	return {"mode": "sandbox", "industry": company.industry, "company": company.to_dict(),
			"clock": {"year": clock.year, "month": clock.month}, "turn": turn, "is_bankrupt": is_bankrupt,
			"game_log": Array(game_log).slice(-200), "talent_pool": talent_pool.to_dict()}


static func from_dict(d: Dictionary) -> SandboxGame:
	var g := SandboxGame.new()
	g.rng = RandomNumberGenerator.new()
	g.rng.randomize()
	g.company = Company.from_dict(d["company"])
	g.industry_cfg = industry(g.company.industry)
	g.clock = CosmicClock.new(int(d["clock"]["year"]), int(d["clock"]["month"]))
	g.engine = CosmicSimulationEngine.new(g.clock)
	g.turn = int(d.get("turn", 0))
	g.is_bankrupt = bool(d.get("is_bankrupt", false))
	for l in d.get("game_log", []):
		g.game_log.append(str(l))
	g.talent_pool = TalentPool.new(g.rng)
	g.talent_pool.load_dict(d.get("talent_pool", {}))
	if g.talent_pool.available.is_empty():
		g.talent_pool.refresh_market()
	return g
