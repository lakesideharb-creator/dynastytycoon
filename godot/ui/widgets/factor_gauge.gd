extends VBoxContainer
## 三才因子条：天时 f(T)、地利 f(S)、人和 f(P)，1.0 为基准刻度

var _rows := {}


func _init() -> void:
	add_theme_constant_override("separation", 8)
	for key in ["天时", "地利", "人和"]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		add_child(h)
		var cap := ThemeBuilder.label(key, 22, Palette.GOLD, ThemeBuilder.serif(700))
		cap.custom_minimum_size = Vector2(52, 0)
		h.add_child(cap)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 18)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.set_meta("value", 1.0)
		bar.draw.connect(_draw_bar.bind(bar))
		h.add_child(bar)
		var num := ThemeBuilder.label("×1.00", 22, Palette.TEXT, ThemeBuilder.mono())
		num.custom_minimum_size = Vector2(84, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(num)
		_rows[key] = {"bar": bar, "num": num}


func set_values(f_t: float, f_s: float, f_p: float) -> void:
	for pair in [["天时", f_t], ["地利", f_s], ["人和", f_p]]:
		var row: Dictionary = _rows[pair[0]]
		row["bar"].set_meta("value", pair[1])
		row["bar"].queue_redraw()
		row["num"].text = "×%.2f" % pair[1]
		row["num"].add_theme_color_override("font_color", Palette.JADE if pair[1] >= 1.0 else Palette.CINNABAR)


func _draw_bar(bar: Control) -> void:
	var v: float = bar.get_meta("value")
	var max_v := 2.5
	var w := bar.size.x
	bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color("#0B0E12"))
	var fill_w := clampf(v / max_v, 0.0, 1.0) * w
	bar.draw_rect(Rect2(Vector2.ZERO, Vector2(fill_w, bar.size.y)), Palette.JADE.darkened(0.15) if v >= 1.0 else Palette.CINNABAR.darkened(0.1))
	var base_x := w / max_v
	bar.draw_line(Vector2(base_x, -3), Vector2(base_x, bar.size.y + 3), Palette.PAPER, 2.0)
