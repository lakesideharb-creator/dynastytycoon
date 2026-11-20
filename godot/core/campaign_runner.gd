class_name CampaignRunner
extends RefCounted
## 战役推进器（对应 src/campaign_runner.py），与界面无关的状态机：
## 开局主决策 → 每月结算 → 按月触发的数据驱动决策点 → 终局判定

var scenario_id: int
var company: Company
var clock: CosmicClock
var meta: Dictionary
var engine: CosmicSimulationEngine
var event_sys := EventSystem.new()
var turn: int = 1                       ## 当前第几个月（从 1 开始）
var main_choice: String = ""            ## 空字符串表示尚未做开局决策
var event_choices := {}                 ## 决策点 id -> 选项 key
var bankrupt := false


func _init(id: int) -> void:
	scenario_id = id
	var s := CampaignManager.setup_scenario(id)
	company = s["company"]
	clock = s["clock"]
	meta = s["meta"]
	engine = CosmicSimulationEngine.new(clock)


## 从存档恢复（progress 结构与 Python CampaignRunner.progress() 相同）
static func restore(id: int, c: Company, clk: CosmicClock, progress: Dictionary) -> CampaignRunner:
	var r := CampaignRunner.new(id)
	r.company = c
	r.clock = clk
	r.engine = CosmicSimulationEngine.new(clk)
	r.turn = int(progress.get("turn", 1))
	var mc = progress.get("main_choice")
	r.main_choice = "" if mc == null else str(mc)
	if r.main_choice == "" and progress.get("decision_made", false):
		r.main_choice = "?"                                     # 兼容 v1 旧存档
	r.event_choices = Dictionary(progress.get("event_choices", {})).duplicate()
	return r


func duration() -> int:
	return int(meta.get("duration_months", 12))


func is_finished() -> bool:
	return bankrupt or turn > duration()


func apply_main_choice(key: String) -> String:
	main_choice = key.to_upper()
	return CampaignManager.apply_main_choice(scenario_id, company, main_choice)


func _event_visible(ev: Dictionary) -> bool:
	var need = ev.get("requires_main_choice")
	if need and not (main_choice in need):
		return false
	var prior: Dictionary = ev.get("requires_event_choice", {})
	for prior_id in prior:
		if not (event_choices.get(prior_id, "") in prior[prior_id]):
			return false
	return true


func pending_decisions() -> Array:
	var out := []
	for ev in meta.get("decision_points", []):
		if int(ev["turn"]) == turn and not event_choices.has(ev["id"]) and _event_visible(ev):
			out.append(ev)
	return out


## 返回 {"ok": bool, "reason": String}
func option_available(option: Dictionary) -> Dictionary:
	var gate = option.get("requires_gate")
	if gate:
		var has_gate := false
		for e in company.executives:
			if e.gate_id == gate:
				has_gate = true
				break
		if not has_gate:
			return {"ok": false, "reason": "需要%s高管坐镇" % option.get("requires_gate_name", gate)}
	var cost := 0.0
	for e in option.get("effects", []):
		if e["type"] == "cash" and float(e["amount"]) < 0:
			cost -= float(e["amount"])
	if cost > 0 and company.cash < cost:
		return {"ok": false, "reason": "现金不足 ¥" + PyFmt.signed_thousands(cost).substr(1)}
	return {"ok": true, "reason": ""}


## 返回 {"ok": bool, "message": String}
func apply_decision(event_id: String, key: String) -> Dictionary:
	var ev: Dictionary = {}
	for e in pending_decisions():
		if e["id"] == event_id:
			ev = e
	if ev.is_empty():
		return {"ok": false, "message": "该决策点当前不可用。"}
	var opt: Dictionary = {}
	for o in ev["options"]:
		if o["key"] == key.to_upper():
			opt = o
	if opt.is_empty():
		return {"ok": false, "message": "无效选项。"}
	var avail := option_available(opt)
	if not avail["ok"]:
		return {"ok": false, "message": avail["reason"]}
	var notes := Effects.apply_effects(company, opt.get("effects", []))
	event_choices[event_id] = opt["key"]
	var msg: String = opt.get("result", "")
	if not notes.is_empty():
		msg += "（%s）" % "，".join(notes)
	return {"ok": true, "message": msg}


## 返回 {"statement": FinancialStatement, "event": Dictionary 或 null}
func simulate_month(marketing_budget: float = 0.0, random_events: bool = true, rng: RandomNumberGenerator = null) -> Dictionary:
	var stmt := engine.simulate_month(company, marketing_budget)
	var evt = null
	if random_events:
		evt = event_sys.trigger_monthly_event(company, rng)
	if company.cash < 0:
		bankrupt = true
	return {"statement": stmt, "event": evt}


func advance() -> void:
	clock.advance_month()
	turn += 1


func check_win() -> bool:
	if bankrupt:
		return false
	return check_win_condition(company, engine, meta)


func progress() -> Dictionary:
	return {"turn": turn, "main_choice": null if main_choice == "" else main_choice,
			"decision_made": main_choice != "", "event_choices": event_choices.duplicate()}


static func check_win_condition(c: Company, eng: CosmicSimulationEngine, m: Dictionary) -> bool:
	var wc: Dictionary = m.get("win_condition", {})
	if c.cash < float(wc.get("min_cash", 0)) or c.cash <= 0:
		return false
	if wc.has("final_month_profit"):
		if c.financial_history.is_empty() or c.financial_history[-1].net_profit < float(wc["final_month_profit"]):
			return false
	if wc.has("max_friction"):
		var p := eng.personnel_sys.calculate_personnel_factor(c.executives)
		if p["friction_ratio"] > float(wc["max_friction"]):
			return false
	return true
