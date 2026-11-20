class_name SaveGame
## 存档：结构与 Python 版 src/save_manager.py 完全相同（两端存档可互读，对照测试见 tests/golden/saves.json）
## 文件位于 user://saves/{槽位}.json；槽位：autosave（每月自动）、slot1–slot3（手动）

const VERSION := 2
static var dir := "user://saves/"     ## 截图/测试脚本可改到独立目录，避免覆盖玩家存档
const SLOTS := ["autosave", "slot1", "slot2", "slot3"]
const SLOT_NAMES := {"autosave": "自动存档", "slot1": "存档一", "slot2": "存档二", "slot3": "存档三"}


static func to_dict(runner: CampaignRunner, office: OfficeLayout) -> Dictionary:
	return {
		"version": VERSION,
		"scenario_id": runner.scenario_id,
		"year": runner.clock.year,
		"month": runner.clock.month,
		"progress": runner.progress(),
		"office_items": office.to_array() if office else [],
		"company": runner.company.to_dict(),
		# 以下为 Godot 端附加信息（Python 读档时忽略）
		"meta": {"saved_at": Time.get_datetime_string_from_system(false, true),
				"title": runner.meta.get("title", ""), "cash": runner.company.cash,
				"turn": runner.turn, "duration": runner.duration()},
	}


## 返回 {"runner": CampaignRunner, "office": OfficeLayout}
static func from_dict(d: Dictionary) -> Dictionary:
	var company := Company.from_dict(d["company"])
	var clock := CosmicClock.new(int(d["year"]), int(d["month"]))
	var runner := CampaignRunner.restore(int(d["scenario_id"]), company, clock, d.get("progress", {}))
	var office := OfficeLayout.new()
	if d.get("office_items", []).is_empty():
		office = OfficeLayout.from_preset("chaotic")
	else:
		for it in d["office_items"]:
			office.add_item(OfficeItem.from_dict(it))
	return {"runner": runner, "office": office}


static func path(slot: String) -> String:
	return dir + slot + ".json"


static func save(slot: String, runner: CampaignRunner, office: OfficeLayout) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		push_error("无法写入存档：" + path(slot))
		return false
	f.store_string(JSON.stringify(to_dict(runner, office), "  "))
	return true


static func read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	return data if data is Dictionary else {}


## 读档并恢复；失败返回空字典
static func load_slot(slot: String) -> Dictionary:
	var d := read(slot)
	if d.is_empty() or not CampaignManager.is_playable(int(d.get("scenario_id", 0))):
		return {}
	return from_dict(d)


## 槽位摘要：{"slot", "name", "exists", "title", "date", "turn", "duration", "cash", "saved_at"}
static func summary(slot: String) -> Dictionary:
	var d := read(slot)
	var s := {"slot": slot, "name": SLOT_NAMES[slot], "exists": not d.is_empty()}
	if d.is_empty():
		return s
	var meta: Dictionary = d.get("meta", {})
	var scen := CampaignManager.get_scenario(int(d["scenario_id"]))
	s["title"] = meta.get("title", scen.get("title", ""))
	s["date"] = "%d年%02d月" % [int(d["year"]), int(d["month"])]
	s["turn"] = int(d.get("progress", {}).get("turn", 1))
	s["duration"] = int(meta.get("duration", scen.get("duration_months", 12)))
	s["cash"] = float(d["company"]["cash"])
	s["saved_at"] = str(meta.get("saved_at", ""))
	return s


## 最近保存的槽位（标题画面「继续游戏」用），没有则返回 ""
static func latest_slot() -> String:
	var best := ""
	var best_time := -1
	for slot in SLOTS:
		if FileAccess.file_exists(path(slot)):
			var t := FileAccess.get_modified_time(path(slot))
			if t > best_time:
				best_time = t
				best = slot
	return best


static func delete(slot: String) -> void:
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))
