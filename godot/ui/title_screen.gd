extends Control
## 标题画面：标题插画 + 商战案例（选关对话框）、危机公关、自由沙盒

signal campaign_selected(scenario_id: int)
signal load_requested(slot: String)
signal crisis_selected(crisis_id: String)
signal sandbox_selected

const SaveSlotsDialog := preload("res://ui/dialogs/save_slots_dialog.gd")
const SettingsDialog := preload("res://ui/dialogs/settings_dialog.gd")
const CasePickerDialog := preload("res://ui/dialogs/case_picker_dialog.gd")


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

	var playable := DataTables.scenarios().filter(func(sc): return CampaignManager.is_playable(int(sc["id"]))).size()
	var cases := Button.new()
	cases.text = "◆ 商战案例　·　%d 个案例可玩" % playable
	cases.custom_minimum_size = Vector2(880, 64)
	cases.add_theme_font_size_override("font_size", 26)
	cases.pressed.connect(_open_cases)
	Audio.wire_button(cases)
	col.add_child(cases)

	# 危机公关（朱砂）与自由沙盒（鎏金）并排一行，省出纵向空间
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 12)
	modes.custom_minimum_size = Vector2(880, 0)
	col.add_child(modes)
	for cr in CrisisWarRoom.data()["crises"]:
		var cid: String = cr["id"]
		var cb := _mode_button("⚠ 案例十 · 危机公关 24 小时", cr["case_title"] + "\n" + cr["intro"], Color("#2A1412"), Color("#3A1A16"), Palette.CINNABAR)
		cb.pressed.connect(func(): crisis_selected.emit(cid))
		modes.add_child(cb)
	var sb := _mode_button("◎ 二十年自由沙盒", "自选行业与地盘，招贤纳士、九宫拓店，2024—2043 问鼎商道宗师", Color("#2A2214"), Color("#3A2E18"), Palette.GOLD)
	sb.pressed.connect(func(): sandbox_selected.emit())
	modes.add_child(sb)

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


func _mode_button(text: String, tip: String, bg: Color, bg_hover: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", ThemeBuilder.box(bg, border.darkened(0.15), 2, 6, 12))
	b.add_theme_stylebox_override("hover", ThemeBuilder.box(bg_hover, border.lightened(0.1), 2, 6, 12))
	b.add_theme_color_override("font_color", Palette.PAPER)
	Audio.wire_button(b)
	return b


func _open_load() -> void:
	var d := SaveSlotsDialog.new()
	d.mode = "load"
	d.slot_chosen.connect(func(slot): load_requested.emit(slot))
	add_child(d)


func _open_cases() -> void:
	var d := CasePickerDialog.new()
	d.chosen.connect(func(sid): campaign_selected.emit(sid))
	add_child(d)
