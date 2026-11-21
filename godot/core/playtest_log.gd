class_name PlaytestLog
## 试玩记录：每局战役的决策路径与结果（每局一行 JSON，字段与终端版 play.py --playtest 一致，另加风水评分）
## 只保存在本机（网页版在浏览器本地存储），由试玩者主动导出后发回。

static var path := "user://playtest_log.jsonl"     ## 测试可改到临时文件
static var enabled := true                         ## 由 Settings 同步（核心代码不依赖界面层的自动加载）


static func record(runner: CampaignRunner, office: OfficeLayout, outcome: String) -> void:
	if not enabled or runner.main_choice == "":
		return
	var c := runner.company
	var p := runner.engine.personnel_sys.calculate_personnel_factor(c.executives)
	var row := {
		"time": Time.get_datetime_string_from_system(false, true),
		"scenario": runner.scenario_id, "outcome": outcome, "months_played": c.financial_history.size(),
		"main_choice": runner.main_choice, "decisions": runner.event_choices,
		"cash": roundi(c.cash),
		"last_month_profit": roundi(c.financial_history[-1].net_profit) if not c.financial_history.is_empty() else null,
		"friction": p["friction_ratio"], "fengshui": PyFmt.round_to(c.fengshui_modifier, 3),
		"office_score": office.audit()["score"] if office else null,
		"platform": OS.get_name(),
	}
	_append(row)


## 危机公关指挥室一局：outcome 为 win / pass / fail / quit，另记终局类型与每步选择
static func record_crisis(room: CrisisWarRoom, company: Company, outcome: String) -> void:
	if not enabled or room.choices.is_empty():
		return
	_append({
		"time": Time.get_datetime_string_from_system(false, true),
		"mode": "crisis", "scenario": int(CrisisWarRoom.definition(room.crisis_id)["scenario_id"]),
		"crisis": room.crisis_id, "outcome": outcome, "verdict": room.verdict_key,
		"decisions": room.choices.duplicate(), "anger": room.public_anger, "trust": room.brand_trust,
		"cash": roundi(company.cash), "spent": roundi(room.total_cost_spent), "reputation": company.reputation,
		"platform": OS.get_name(),
	})


## 自由沙盒一局：outcome 为结局评级 S–D、sealed（提前封盘）或 quit（中途离开）
static func record_sandbox(game: SandboxGame, office: OfficeLayout, outcome: String) -> void:
	if not enabled or game.turn == 0:
		return
	var c := game.company
	var p := game.engine.personnel_sys.calculate_personnel_factor(c.executives)
	_append({
		"time": Time.get_datetime_string_from_system(false, true),
		"mode": "sandbox", "industry": c.industry, "outcome": outcome, "grade": game.check_ending()["grade"],
		"months_played": game.turn, "year": game.clock.year, "cash": roundi(c.cash), "net_assets": roundi(game.net_assets()),
		"reputation": c.reputation, "stores": c.active_stores().size(), "stores_opened": c.stores.size() - 1,
		"executives": c.executives.map(func(e): return "%s:%s" % [e.role, e.gate_id]),
		"friction": p["friction_ratio"], "fengshui": PyFmt.round_to(c.fengshui_modifier, 3),
		"office_score": office.audit()["score"] if office else null, "last_year_profit": roundi(game.last_year_profit()),
		"platform": OS.get_name(),
	})


static func _append(row: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(row))


static func read_all() -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


static func count() -> int:
	return read_all().strip_edges().split("\n", false).size()


## 导出：网页版触发浏览器下载；桌面版保存到用户目录并复制到剪贴板。返回给玩家看的说明。
static func export() -> String:
	var text := read_all()
	if text.strip_edges() == "":
		return "还没有试玩记录：玩完（或中途退出）一局后才会记录。"
	var file_name := "dynasty_tycoon_playtest_%s.jsonl" % Time.get_date_string_from_system()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, "application/json")
		return "已下载 %s（%d 局），请把这个文件发给开发者。" % [file_name, count()]
	DisplayServer.clipboard_set(text)
	var out := OS.get_user_data_dir().path_join(file_name)
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f:
		f.store_string(text)
	return "已导出 %d 局：%s（内容也已复制到剪贴板）" % [count(), out]


static func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
