extends "res://ui/dialogs/modal.gd"
## 危机公关开局简报：指挥室插画 + 事件背景 + 胜负规则 + 进入指挥室

signal start

var crisis: Dictionary


func _ready() -> void:
	card.custom_minimum_size = Vector2(1120, 0)
	body.add_child(ink_label("特大舆情预警 · 24小时危机公关指挥室", 20, Palette.CINNABAR, 700))
	var art := TextureRect.new()
	art.texture = load("res://assets/scenes/war_room.png")
	art.custom_minimum_size = Vector2(1064, 330)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	body.add_child(art)
	body.add_child(ink_label(crisis["case_title"], 32, INK_TEXT, 900))
	var intro := ink_label(crisis["intro"], 21, Color(INK_TEXT, 0.88))
	intro.custom_minimum_size = Vector2(1064, 0)
	body.add_child(intro)

	var v: Dictionary = crisis["verdicts"]
	var rules := "胜负规则：公众怒火 ≥ %d 立即被监管封杀；品牌信任 ≤ %d 品牌社会性死亡。\n熬满 24 小时：怒火 ≤ %d 且信任 ≥ %d 为卓越通关，怒火 ≤ %d 勉强过关。\n带门派标签的应对需要对应门派的高管坐镇，否则效果减半。" % [
		CrisisWarRoom.anger_ban_line(), CrisisWarRoom.trust_death_line(),
		int(v["excellent"]["max_anger"]), int(v["excellent"]["min_trust"]), int(v["mediocre"]["max_anger"])]
	var r := ink_label(rules, 19, Palette.CINNABAR.darkened(0.15), 700)
	r.custom_minimum_size = Vector2(1064, 0)
	body.add_child(r)
	var b := option_button("", "进入指挥室（Enter）")
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func():
		Audio.sfx("ui_confirm")
		start.emit()
		close())
	body.add_child(b)
	super._ready()
	b.grab_focus.call_deferred()
