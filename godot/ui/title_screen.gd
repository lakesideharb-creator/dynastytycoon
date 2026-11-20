extends Control
## 标题画面：标题插画 + 可玩战役列表

signal campaign_selected(scenario_id: int)


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
	col.add_theme_constant_override("separation", 14)
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

	for s in DataTables.scenarios():
		var sid := int(s["id"])
		if not CampaignManager.is_playable(sid):
			continue
		var b := Button.new()
		b.text = "%s" % s["title"].replace("【", " 【").strip_edges()
		b.custom_minimum_size = Vector2(880, 64)
		b.tooltip_text = s.get("brief", "")
		b.pressed.connect(func(): campaign_selected.emit(sid))
		Audio.wire_button(b)
		col.add_child(b)

	var quit := Button.new()
	quit.text = "退出"
	quit.custom_minimum_size = Vector2(880, 52)
	quit.pressed.connect(func(): get_tree().quit())
	Audio.wire_button(quit)
	col.add_child(quit)
