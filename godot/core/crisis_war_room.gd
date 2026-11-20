class_name CrisisWarRoom
extends RefCounted
## 24小时危机公关指挥室（对应 src/crisis_war_room.py PRCrisisWarRoom）
## 阶段、选项与终局裁决读 res://data/crisis_scenarios.json；规则与 Python 端逐项一致，由 golden 测试对照。

const DEFAULT_CRISIS := "weight_loss_drug"

var crisis_id := DEFAULT_CRISIS
var title := ""
var hour := 0
var public_anger := 75          ## 怒火 0–100，≥ anger_ban_line 触发监管封杀
var brand_trust := 40           ## 信任 0–100，≤ trust_death_line 品牌社会性死亡
var total_cost_spent := 0.0
var action_logs: Array[String] = []
var choices: Array[String] = []
var is_resolved := false
var verdict := ""
var verdict_key := ""           ## ban / trust_death / excellent / mediocre / failed


static func data() -> Dictionary:
	return DataTables.load_json("crisis_scenarios.json")


static func definition(id := DEFAULT_CRISIS) -> Dictionary:
	for c in data()["crises"]:
		if c["id"] == id:
			return c
	push_error("未知危机：" + id)
	return {}


static func anger_ban_line() -> int:
	return int(data()["anger_ban_line"])


static func trust_death_line() -> int:
	return int(data()["trust_death_line"])


static func create(id := DEFAULT_CRISIS) -> CrisisWarRoom:
	var d := definition(id)
	var r := CrisisWarRoom.new()
	r.crisis_id = id
	r.title = d["title"]
	r.public_anger = int(d["initial_anger"])
	r.brand_trust = int(d["initial_trust"])
	return r


## 指挥室所属公司与在场高管
static func create_company(id := DEFAULT_CRISIS) -> Company:
	var c: Dictionary = definition(id)["company"]
	var co := Company.new()
	co.name = c["name"]
	co.industry = c["industry"]
	co.cash = float(c["cash"])
	co.reputation = int(c["reputation"])
	for e in c["executives"]:
		co.executives.append(Executive.from_dict(e))
	return co


func stages() -> Array:
	return definition(crisis_id)["stages"]


func current_stage() -> Dictionary:
	for s in stages():
		if hour < int(s["end_hour"]):
			return s
	return {}


func stage_index() -> int:
	var st := current_stage()
	return stages().find(st) if not st.is_empty() else stages().size()


static func has_required_gate(option: Dictionary, company: Company) -> bool:
	var gate: String = option.get("special_gate", "")
	if gate == "":
		return true
	for e in company.executives:
		if e.gate_id == gate:
			return true
	return false


## 实际生效的 [怒火变动, 信任变动]；缺少专属高管时减半并向零取整（同 Python int(x / 2)）
static func effective_deltas(option: Dictionary, company: Company) -> Array[int]:
	var a := int(option["anger_delta"])
	var t := int(option["trust_delta"])
	if has_required_gate(option, company):
		return [a, t]
	return [int(a / 2.0), int(t / 2.0)]


static func _signed(x: int) -> String:
	return ("+" if x >= 0 else "") + str(x)


func _resolve(key: String, company: Company) -> void:
	var v: Dictionary = definition(crisis_id)["verdicts"][key]
	is_resolved = true
	verdict_key = key
	verdict = v["text"]
	var rep := company.reputation + int(v["reputation_delta"])
	if v.has("reputation_min"):
		rep = maxi(int(v["reputation_min"]), rep)
	if v.has("reputation_max"):
		rep = mini(int(v["reputation_max"]), rep)
	company.reputation = rep


## 返回 {"ok", "log"}
func execute_choice(option_id: String, company: Company) -> Dictionary:
	var stage := current_stage()
	if stage.is_empty():
		return {"ok": false, "log": "危机处理阶段已结束。"}
	var opt := {}
	for o in stage["options"]:
		if o["id"] == option_id:
			opt = o
	if opt.is_empty():
		return {"ok": false, "log": "无效的选项编号。"}

	company.cash -= float(opt["cost"])
	total_cost_spent += float(opt["cost"])
	choices.append(option_id)

	var d := effective_deltas(opt, company)
	var gate_note := "" if has_required_gate(opt, company) else " (缺少专属高管·效果减半)"
	public_anger = clampi(public_anger + d[0], 0, 100)
	brand_trust = clampi(brand_trust + d[1], 0, 100)
	var log_entry := "[%s] 决断：%s%s | 怒火 %s (现:%d) | 信任 %s (现:%d)" % [
		stage["hours_range"], opt["title"], gate_note, _signed(d[0]), public_anger, _signed(d[1]), brand_trust]
	action_logs.append(log_entry)
	hour = int(stage["end_hour"])

	if public_anger >= anger_ban_line():
		_resolve("ban", company)
	elif brand_trust <= trust_death_line():
		_resolve("trust_death", company)
	elif current_stage().is_empty():
		var v: Dictionary = definition(crisis_id)["verdicts"]
		if public_anger <= int(v["excellent"]["max_anger"]) and brand_trust >= int(v["excellent"]["min_trust"]):
			_resolve("excellent", company)
		elif public_anger <= int(v["mediocre"]["max_anger"]):
			_resolve("mediocre", company)
		else:
			_resolve("failed", company)
	return {"ok": true, "log": log_entry}


func grade() -> String:
	if verdict_key == "":
		return ""
	return definition(crisis_id)["verdicts"][verdict_key]["grade"]
