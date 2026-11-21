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
	return {"runner": runner, "office": _office_from(d)}


## 沙盒存档（Godot 独有，"mode": "sandbox"；Python 终端版沙盒不支持存档）
static func sandbox_to_dict(game: SandboxGame, office: OfficeLayout) -> Dictionary:
	var d := game.to_dict()
	d["version"] = VERSION
	d["year"] = game.clock.year
	d["month"] = game.clock.month
	d["office_items"] = office.to_array() if office else []
	d["meta"] = {"saved_at": Time.get_datetime_string_from_system(false, true),
			"title": "二十年自由沙盒：%s · %s" % [game.company.name, game.industry_cfg.get("name", "")],
			"cash": game.company.cash, "turn": game.turn, "duration": total_sandbox_months()}
	return d


static func total_sandbox_months() -> int:
	var e := SandboxGame.econ()
	return (int(e["end_year"]) - int(e["start_year"])) * 12 + 12 - 2 + 1     # 2024 年 2 月开局至 2043 年 12 月


static func save_sandbox(slot: String, game: SandboxGame, office: OfficeLayout) -> bool:
	return _write(slot, sandbox_to_dict(game, office))


static func _office_from(d: Dictionary) -> OfficeLayout:
	if d.get("office_items", []).is_empty():
		return OfficeLayout.from_preset("chaotic")
	var office := OfficeLayout.new()
	for it in d["office_items"]:
		office.add_item(OfficeItem.from_dict(it))
	return office


static func path(slot: String) -> String:
	return dir + slot + ".json"


static func save(slot: String, runner: CampaignRunner, office: OfficeLayout) -> bool:
	return _write(slot, to_dict(runner, office))


static func _write(slot: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		push_error("无法写入存档：" + path(slot))
		return false
	f.store_string(JSON.stringify(data, "  "))
	return true


static func read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	return data if data is Dictionary else {}


## 读档并恢复；战役返回 {"runner", "office"}，沙盒返回 {"sandbox", "office"}；失败返回空字典
static func load_slot(slot: String) -> Dictionary:
	var d := read(slot)
	if d.get("mode", "") == "sandbox":
		return {"sandbox": SandboxGame.from_dict(d), "office": _office_from(d)}
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
	if d.get("mode", "") == "sandbox":
		s["title"] = meta.get("title", "二十年自由沙盒")
		s["date"] = "%d年%02d月" % [int(d["year"]), int(d["month"])]
		s["turn"] = int(d.get("turn", 0))
		s["duration"] = int(meta.get("duration", total_sandbox_months()))
		s["cash"] = float(d["company"]["cash"])
		s["saved_at"] = str(meta.get("saved_at", ""))
		return s
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
