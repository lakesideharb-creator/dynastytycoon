extends "res://ui/dialogs/modal.gd"
## 危机公关终局裁决：结局 + 终值 + 决策回放 + 再来一局 / 返回标题 / 导出试玩记录

signal restart
signal back_to_title

var room: CrisisWarRoom
var company: Company


func _ready() -> void:
	card.custom_minimum_size = Vector2(1060, 0)
	var grade := room.grade()
	var color := Palette.GOLD.darkened(0.25) if grade == "win" else (Palette.INDIGO if grade == "pass" else Palette.CINNABAR)
	var head: String = {"win": "绝处逢生 · 卓越通关", "pass": "平庸过关 · 元气大伤"}.get(grade, "危机失败")
	body.add_child(ink_label(CrisisWarRoom.definition(room.crisis_id)["case_title"], 20, Color(INK_TEXT, 0.6), 700))
	body.add_child(ink_label(head, 44, color, 900))
	var verdict := ink_label(room.verdict, 21, Color(INK_TEXT, 0.9))
	verdict.custom_minimum_size = Vector2(1000, 0)
	body.add_child(verdict)
	body.add_child(sans_label("终局怒火 %d　·　品牌信任 %d　·　应急投入 %s　·　公司商誉 %d　·　坚持 %d 小时" % [
		room.public_anger, room.brand_trust, Money.short(room.total_cost_spent), company.reputation, room.hour], 22, INK_TEXT, 700))
	var titles := {}
	for st in room.stages():
		for o in st["options"]:
			titles[o["id"]] = [st["hours_range"].split(" (")[0], o["title"]]
	var recap := ""
	for id in room.choices:
		recap += ("\n" if recap != "" else "") + "%s　%s" % titles[id]
	var r := ink_label(recap, 19, Color(INK_TEXT, 0.85))
	r.custom_minimum_size = Vector2(1000, 0)
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
