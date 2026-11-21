extends "res://ui/dialogs/modal.gd"
## 沙盒终局总评：评级 + 结局 + 关键数据 + 新开一局 / 返回标题 / 导出试玩记录

signal restart
signal back_to_title

const GRADE_COLOR := {"S": Color("#B8862E"), "A": Color("#8C6A2E"), "B": Color("#3D5A6C"), "C": Color("#7A5A3A"), "D": Color("#A8322A")}

var game: SandboxGame
var ending: Dictionary
var early := false                 ## 提前封盘


func _ready() -> void:
	card.custom_minimum_size = Vector2(1060, 0)
	var c := game.company
	body.add_child(ink_label("%s · %s　二十年终局总评%s" % [c.name, game.industry_cfg["name"], "（提前封盘）" if early else ""], 20, Color(INK_TEXT, 0.6), 700))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 26)
	body.add_child(head)
	var g: String = ending["grade"]
	var grade := ink_label(g, 120, GRADE_COLOR.get(g, INK_TEXT), 900, false)
	head.add_child(grade)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	tv.add_child(ink_label(ending["title"], 42, GRADE_COLOR.get(g, INK_TEXT), 900))
	var d := ink_label(ending["description"], 21, Color(INK_TEXT, 0.88))
	d.custom_minimum_size = Vector2(820, 0)
	tv.add_child(d)
	body.add_child(sans_label("期末现金 %s　·　估算净资产 %s　·　门店 %d 家　·　高管 %d 人　·　商誉 %d　·　经营 %d 个月" % [
		Money.short(c.cash), Money.short(game.net_assets()), c.active_stores().size(), c.executives.size(), c.reputation, game.turn], 19, INK_TEXT, 700))
	var cond := ink_label("评级条件：" + ending["unlock_condition"], 18, Color(INK_TEXT, 0.65))
	cond.custom_minimum_size = Vector2(1000, 0)
	body.add_child(cond)
	var ladder := PackedStringArray()
	for e in SandboxGame.data()["endings"]:
		ladder.append("%s 级 %s：%s" % [e["grade"], e["title"], e["unlock_condition"]])
	var lad := ink_label("\n".join(ladder), 16, Color(INK_TEXT, 0.55))
	lad.custom_minimum_size = Vector2(1000, 0)
	body.add_child(lad)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	var again := option_button("", "新开一局")
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
