extends Control
## 标题画面：标题插画 + 可玩战役列表

signal campaign_selected(scenario_id: int)
signal load_requested(slot: String)
signal crisis_selected(crisis_id: String)

const SaveSlotsDialog := preload("res://ui/dialogs/save_slots_dialog.gd")
const SettingsDialog := preload("res://ui/dialogs/settings_dialog.gd")


func _ready() -> void:
	var art := TextureRect.new()
	art.texture = load("res://assets/scenes/title.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)

	# 底部渐暗，保证按钮文字可读
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(Palette.TERMINAL, 0.92))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0.35)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.offset_bottom = -60
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	var title := ThemeBuilder.label("商道玄机 · 大亨罗盘", 72, Palette.PAPER, ThemeBuilder.serif(900))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)
	var sub := ThemeBuilder.label("天时 · 地利 · 人和 —— 以奇门之术经营商海", 26, Color("#2A241C"), ThemeBuilder.serif(700))
	sub.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.55))
	sub.add_theme_constant_override("shadow_offset_y", 1)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(Control.new())

	var latest := SaveGame.latest_slot()
	if latest != "":
		var s := SaveGame.summary(latest)
		var cont := Button.new()
		cont.text = "继续游戏　·　%s　%s　第 %d/%d 月" % [s["name"], s["date"], s["turn"], s["duration"]]
		cont.custom_minimum_size = Vector2(880, 64)
		cont.add_theme_stylebox_override("normal", ThemeBuilder.box(Color("#3A2A12"), Palette.AMBER, 2, 6, 12))
		cont.add_theme_color_override("font_color", Palette.AMBER.lightened(0.3))
		cont.pressed.connect(func(): load_requested.emit(latest))
		Audio.wire_button(cont)
		col.add_child(cont)

	for s in DataTables.scenarios():
		var sid := int(s["id"])
		if not CampaignManager.is_playable(sid):
			continue
		var b := Button.new()
		b.text = "%s" % s["title"].replace("【", " 【").strip_edges()
		b.custom_minimum_size = Vector2(880, 56)
		b.tooltip_text = s.get("brief", "")
		b.pressed.connect(func(): campaign_selected.emit(sid))
		Audio.wire_button(b)
		col.add_child(b)

	for cr in CrisisWarRoom.data()["crises"]:              # 危机公关短战：独立玩法，朱砂色按钮区分
		var cid: String = cr["id"]
		var cb := Button.new()
		cb.text = "⚠ " + cr["case_title"].replace("【", " 【")
		cb.custom_minimum_size = Vector2(880, 56)
		cb.tooltip_text = cr["intro"]
		cb.add_theme_stylebox_override("normal", ThemeBuilder.box(Color("#2A1412"), Palette.CINNABAR.darkened(0.2), 2, 6, 12))
		cb.add_theme_stylebox_override("hover", ThemeBuilder.box(Color("#3A1A16"), Palette.CINNABAR, 2, 6, 12))
		cb.add_theme_color_override("font_color", Palette.PAPER)
		cb.pressed.connect(func(): crisis_selected.emit(cid))
		Audio.wire_button(cb)
		col.add_child(cb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(880, 0)
	col.add_child(row)
	for item in [["读取存档", _open_load], ["设置", func(): add_child(SettingsDialog.new())], ["退出", func(): get_tree().quit()]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(item[1])
		Audio.wire_button(b)
		row.add_child(b)


func _open_load() -> void:
	var d := SaveSlotsDialog.new()
	d.mode = "load"
	d.slot_chosen.connect(func(slot): load_requested.emit(slot))
	add_child(d)
