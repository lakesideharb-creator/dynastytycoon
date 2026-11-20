extends "res://ui/dialogs/modal.gd"
## 终局复盘：胜负 + 关键指标 + 决策回顾

signal restart
signal back_to_title

var runner: CampaignRunner


func _ready() -> void:
	card.custom_minimum_size = Vector2(980, 0)
	var won := runner.check_win()
	var c := runner.company
	var title: String
	var color: Color
	if runner.bankrupt:
		title = "资金链断裂 · 破产清算"
		color = Palette.CINNABAR
	elif won:
		title = "目标达成 · 通关"
		color = Palette.GOLD.darkened(0.25)
	else:
		title = "未达通关标准"
		color = Palette.INDIGO
	body.add_child(ink_label(runner.meta["title"], 20, Color(INK_TEXT, 0.6), 700))
	body.add_child(ink_label(title, 44, color, 900))
	body.add_child(ink_label("通关目标：" + runner.meta.get("win_condition_text", ""), 20, Color(INK_TEXT, 0.8)))

	var p := runner.engine.personnel_sys.calculate_personnel_factor(c.executives)
	var last := c.financial_history[-1].net_profit if not c.financial_history.is_empty() else 0.0
	var stats := sans_label("期末现金 %s　·　末月净利润 %s　·　组织内耗 %d%%　·　经营 %d 个月" % [
		Money.short(c.cash), Money.short(last), roundi(p["friction_ratio"] * 100), c.financial_history.size()], 22, INK_TEXT, 700)
	body.add_child(stats)

	var choices: Dictionary = runner.meta.get("choices", {})
	var recap := "开局决断：%s　%s" % [runner.main_choice, choices.get(runner.main_choice, {}).get("name", "")]
	var titles := {}
	for ev in runner.meta.get("decision_points", []):
		titles[ev["id"]] = ev["title"]
	for id in runner.event_choices:
		recap += "\n%s → %s" % [titles.get(id, id), runner.event_choices[id]]
	var r := ink_label(recap, 19, Color(INK_TEXT, 0.85))
	r.custom_minimum_size = Vector2(920, 0)
	body.add_child(r)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	var again := option_button("", "再来一局")
	again.custom_minimum_size = Vector2(300, 56)
	again.pressed.connect(func(): restart.emit())
	row.add_child(again)
	var back := option_button("", "返回标题")
	back.custom_minimum_size = Vector2(300, 56)
	back.pressed.connect(func(): back_to_title.emit())
	row.add_child(back)
	if Settings.playtest_log:
		var note := sans_label("", 17, Color(INK_TEXT, 0.7))
		var exp := option_button("", "导出试玩记录")
		exp.custom_minimum_size = Vector2(300, 56)
		exp.pressed.connect(func(): note.text = PlaytestLog.export())
		row.add_child(exp)
		body.add_child(note)
	super._ready()
