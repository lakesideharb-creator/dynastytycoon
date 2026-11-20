extends "res://ui/dialogs/modal.gd"
## 设置：音乐/音效音量、全屏、自动存档（即时生效并保存）


func _ready() -> void:
	esc_closes = true
	card.custom_minimum_size = Vector2(720, 0)
	body.add_child(ink_label("设置", 34, INK_TEXT, 900))
	_slider("音乐音量", "music")
	_slider("音效音量", "sfx")
	_toggle("全屏显示", "fullscreen")
	_toggle("每月自动存档", "autosave")
	var close_btn := option_button("", "完成")
	close_btn.pressed.connect(close)
	body.add_child(close_btn)
	super._ready()


func _slider(caption: String, key: String) -> void:
	var h := HBoxContainer.new()
	body.add_child(h)
	var cap := ink_label(caption, 22, INK_TEXT, 700, false)
	cap.custom_minimum_size = Vector2(150, 0)
	h.add_child(cap)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = Settings.get(key) * 100
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.add_theme_stylebox_override("slider", ThemeBuilder.box(Color(INK_TEXT, 0.2), Color.TRANSPARENT, 0, 3, 3))
	h.add_child(s)
	var val := ink_label("%d%%" % s.value, 22, INK_TEXT, 700, false)
	val.custom_minimum_size = Vector2(80, 0)
	h.add_child(val)
	s.value_changed.connect(func(v):
		val.text = "%d%%" % v
		Settings.set_value(key, v / 100.0)
		if key == "sfx":
			Audio.sfx("ui_click"))


func _toggle(caption: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = caption
	c.button_pressed = Settings.get(key)
	c.add_theme_font_override("font", ThemeBuilder.serif(700))
	c.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		c.add_theme_color_override(state, INK_TEXT)
	# 不继承全局深色按钮样式：宣纸底 + 细金边
	for state in ["normal", "pressed", "disabled"]:
		c.add_theme_stylebox_override(state, ThemeBuilder.box(Palette.PAPER.darkened(0.05), Palette.GOLD.darkened(0.2), 1, 6, 12))
	for state in ["hover", "hover_pressed"]:
		c.add_theme_stylebox_override(state, ThemeBuilder.box(Palette.PAPER.lightened(0.3), Palette.CINNABAR, 1, 6, 12))
	c.add_theme_stylebox_override("focus", ThemeBuilder.box(Color.TRANSPARENT, Palette.CINNABAR, 2, 6, 12))
	c.toggled.connect(func(on): Settings.set_value(key, on))
	Audio.wire_button(c)
	body.add_child(c)
