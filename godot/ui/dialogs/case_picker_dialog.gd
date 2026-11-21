extends "res://ui/dialogs/modal.gd"
## 商战案例选关：列出案例一到九（案例十在标题画面单独入口），可玩的按数字键或点击进入，未完成的标「筹备中」

signal chosen(scenario_id: int)


func _ready() -> void:
	esc_closes = true
	card.custom_minimum_size = Vector2(1120, 0)
	body.add_child(ink_label("商战案例", 34, INK_TEXT, 900))
	body.add_child(ink_label("每个案例教一种经营算法：一个开局决断，三四个月度议题，在限定月数内达成通关目标。按数字键可直接进入。", 19, Color(INK_TEXT, 0.7)))
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", ThemeBuilder.box(Palette.GOLD, Color.TRANSPARENT, 0, 0, 1))
	body.add_child(sep)
	for s in DataTables.scenarios():
		var sid := int(s["id"])
		if sid >= 10:                    # 案例十是危机公关指挥室，标题画面单独入口
			continue
		var playable := CampaignManager.is_playable(sid)
		var b := option_button(str(sid), String(s["title"]), playable, "" if playable else "筹备中")
		b.tooltip_text = s.get("brief", "")
		b.pressed.connect(func():
			Audio.sfx("ui_confirm")
			chosen.emit(sid)
			close())
		body.add_child(b)
	var back := option_button("", "返回")
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.pressed.connect(close)
	body.add_child(back)
	super._ready()
