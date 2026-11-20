class_name CampaignManager
## 战役剧本（对应 src/campaign.py）：按 campaign_scenarios.json 搭建关卡、执行开局主决策


static func get_scenario(scenario_id: int) -> Dictionary:
	for s in DataTables.scenarios():
		if int(s["id"]) == scenario_id:
			return s
	return {}


static func is_playable(scenario_id: int) -> bool:
	var s := get_scenario(scenario_id)
	return s.has("setup") and s.has("main_choices")


## 返回 {"company": Company, "clock": CosmicClock, "meta": Dictionary}
static func setup_scenario(scenario_id: int) -> Dictionary:
	var meta := get_scenario(scenario_id)
	assert(is_playable(scenario_id), "关卡 %d 尚未配置 setup / main_choices" % scenario_id)
	var st: Dictionary = meta["setup"]
	var clock := CosmicClock.new(int(st["clock"]["year"]), int(st["clock"]["month"]))
	var c: Dictionary = st["company"]
	var company := Company.new()
	company.name = c["name"]
	company.industry = c["industry"]
	company.cash = float(c["cash"])
	company.fengshui_modifier = float(c["fengshui_modifier"])
	company.reputation = int(c["reputation"])
	for e in st["executives"]:
		company.executives.append(Executive.from_dict(e))
	for spec in st["stores"]:
		company.stores.append_array(Effects.build_stores(spec))
	return {"company": company, "clock": clock, "meta": meta}


static func apply_main_choice(scenario_id: int, company: Company, choice: String) -> String:
	var opt = get_scenario(scenario_id).get("main_choices", {}).get(choice.to_upper())
	if opt == null:
		return "无效选择。"
	Effects.apply_effects(company, opt["effects"])
	return opt["result"]
