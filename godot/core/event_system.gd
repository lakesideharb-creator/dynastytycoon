class_name EventSystem
extends RefCounted
## 随机突发事件（对应 src/event_system.py），事件池见 data/random_events.json
## 两端随机数序列不同，事件逻辑单独测试，不参与逐月对照。

var trigger_chance: float
var events_pool: Array


func _init() -> void:
	var data := DataTables.random_events()
	trigger_chance = float(data["trigger_chance"])
	events_pool = data["events"]


func eligible_events(industry: String) -> Array:
	var out := []
	for e in events_pool:
		var inds = e.get("industries")
		if not inds or industry in inds:
			out.append(e)
	return out


## 每月按 trigger_chance 概率触发一个本行业可用的事件；返回事件字典或 null
func trigger_monthly_event(company: Company, rng: RandomNumberGenerator = null) -> Variant:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if rng.randf() >= trigger_chance:
		return null
	var pool := eligible_events(company.industry)
	if pool.is_empty():
		return null
	var event: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	company.cash += float(event["effect_cash"])
	company.reputation = clampi(company.reputation + int(event["effect_reputation"]), 0, 100)
	company.fengshui_modifier = PyFmt.round_to(clampf(company.fengshui_modifier + float(event["effect_fengshui"]), -0.25, 0.35), 3)
	return event
