extends GridContainer
## 九宫选址格：用九宫商业地图（上北下南）的九块插画做按钮，显示宫名、城市、该行业的地利系数与附加信息

signal palace_selected(palace_id: String)

const MAP := "res://assets/scenes/nine_palace_map.png"
## 与地图和办公室九宫一致：上北下南、左西右东
const LAYOUT := [["qian_6", "kan_1", "gen_8"], ["dui_7", "zhong_5", "zhen_3"], ["kun_2", "li_9", "xun_4"]]
const COL_X := [74, 674, 1284]
const COL_W := [562, 572, 562]
const ROW_Y := [4, 366, 756]
const ROW_H := [328, 356, 320]

var industry := ""
var info_fn: Callable                ## palace_id -> 附加说明（可选）
var disabled_fn: Callable            ## palace_id -> 不可选原因（空字符串表示可选）
var selected := ""
var cell_size := Vector2(300, 170)
var _buttons := {}


func _init() -> void:
	columns = 3
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)


func setup(industry_key: String) -> void:
	industry = industry_key
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	var map: Texture2D = load(MAP)
	var nps := NinePalacesSystem.new()
	var best := SandboxGame.best_palaces(industry)
	for r in 3:
		for col in 3:
			var pid: String = LAYOUT[r][col]
			var b := Button.new()
			b.custom_minimum_size = cell_size
			b.toggle_mode = true
			b.clip_contents = true
			var normal := ThemeBuilder.box(Color.BLACK, Palette.GOLD.darkened(0.45), 1, 6, 0)
			b.add_theme_stylebox_override("normal", normal)
			b.add_theme_stylebox_override("hover", ThemeBuilder.box(Color.BLACK, Palette.AMBER, 2, 6, 0))
			b.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color.BLACK, Palette.GOLD.lightened(0.2), 4, 6, 0))
			b.add_theme_stylebox_override("hover_pressed", ThemeBuilder.box(Color.BLACK, Palette.GOLD.lightened(0.2), 4, 6, 0))
			b.add_theme_stylebox_override("focus", ThemeBuilder.box(Color.TRANSPARENT, Palette.AMBER, 2, 6, 0))
			b.add_theme_stylebox_override("disabled", normal)
			var art := TextureRect.new()
			var at := AtlasTexture.new()
			at.atlas = map
			at.region = Rect2(COL_X[col], ROW_Y[r], COL_W[col], ROW_H[r])
			art.texture = at
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.set_anchors_preset(Control.PRESET_FULL_RECT)
			art.offset_left = 3
			art.offset_top = 3
			art.offset_right = -3
			art.offset_bottom = -3
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(art)
			var shade := ColorRect.new()                # 下半部压暗，托住文字
			shade.color = Color(0.04, 0.05, 0.07, 0.72)
			shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			shade.offset_top = -cell_size.y * 0.56
			shade.offset_left = 3
			shade.offset_right = -3
			shade.offset_bottom = -3
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(shade)
			var v := VBoxContainer.new()
			v.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			v.offset_top = -cell_size.y * 0.56
			v.offset_left = 12
			v.offset_right = -10
			v.offset_bottom = -6
			v.add_theme_constant_override("separation", 0)
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(v)
			var parts := SandboxGame.palace_label(pid).split("·")
			var head := HBoxContainer.new()
			head.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(head)
			head.add_child(ThemeBuilder.label(parts[0], 21, Palette.PAPER, ThemeBuilder.serif(900)))
			var f := nps.affinity(industry, pid)
			var fl := ThemeBuilder.label("地利 ×%.2f" % f, 18,
					Palette.JADE if f >= 1.1 else (Palette.CINNABAR.lightened(0.2) if f < 0.95 else Palette.TEXT), ThemeBuilder.mono())
			fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			head.add_child(fl)
			v.add_child(ThemeBuilder.label(parts[1] if parts.size() > 1 else "", 15, Palette.TEXT_DIM))
			var extra := ThemeBuilder.label("", 15, Palette.GOLD)
			extra.name = "Extra"
			v.add_child(extra)
			if pid in best:
				var tag := ThemeBuilder.label(" ★ 推荐 ", 15, Palette.INK, ThemeBuilder.serif(900))
				var tp := PanelContainer.new()
				tp.add_theme_stylebox_override("panel", ThemeBuilder.box(Palette.GOLD, Color.TRANSPARENT, 0, 4, 2))
				tp.add_child(tag)
				tp.position = Vector2(8, 8)
				tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(tp)
			b.tooltip_text = SandboxGame.palace_label(pid)
			b.pressed.connect(_on_pressed.bind(pid))
			Audio.wire_button(b)
			add_child(b)
			_buttons[pid] = b
	refresh()


func refresh() -> void:
	for pid in _buttons:
		var b: Button = _buttons[pid]
		var extra: Label = b.find_child("Extra", true, false)
		var why: String = disabled_fn.call(pid) if disabled_fn.is_valid() else ""
		b.disabled = why != ""
		b.modulate = Color(1, 1, 1, 0.45) if b.disabled else Color.WHITE
		extra.text = why if why != "" else (info_fn.call(pid) if info_fn.is_valid() else "")
		b.set_pressed_no_signal(pid == selected)


func select(pid: String) -> void:
	selected = pid
	refresh()


func _on_pressed(pid: String) -> void:
	select(pid)
	palace_selected.emit(pid)
