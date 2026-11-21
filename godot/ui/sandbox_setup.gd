extends Control
## 自由沙盒开局：选行业、起商号、定起步资本、选总部宫位

signal start_requested(company_name: String, industry_key: String, starting_cash: float, home_palace: String)
signal back_requested

const PalaceGrid := preload("res://ui/widgets/palace_grid.gd")

var industry_key := ""
var _ind_buttons := {}
var _name_edit: LineEdit
var _cash_slider: HSlider
var _cash_lbl: Label
var _grid: GridContainer
var _palace_info: Label
var _summary: RichTextLabel
var _start_btn: Button


func _ready() -> void:
	var e := SandboxGame.econ()
	var bg := TextureRect.new()
	bg.texture = load("res://assets/scenes/nine_palace_map.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.35, 0.33, 0.32)
	add_child(bg)
	var veil := ColorRect.new()
	veil.color = Color(Palette.TERMINAL, 0.86)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	tv.add_child(ThemeBuilder.label("二十年自由沙盒", 40, Palette.PAPER, ThemeBuilder.serif(900)))
	tv.add_child(ThemeBuilder.label("%d—%d · 自选行业与地盘，招贤纳士、九宫拓店，看你能否成为商道宗师" % [int(e["start_year"]), int(e["end_year"])], 19, Palette.TEXT_DIM))
	var back := Button.new()
	back.text = "返回标题"
	back.custom_minimum_size = Vector2(160, 54)
	back.pressed.connect(func(): back_requested.emit())
	Audio.wire_button(back)
	head.add_child(back)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# 左：行业 + 商号 + 资本
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(820, 0)
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	left.add_child(_section("一、选择行业"))
	for ind in SandboxGame.industries():
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 84)
		b.add_theme_stylebox_override("normal", ThemeBuilder.box(Color("#161B23"), Palette.TERMINAL_LINE, 1, 8, 0))
		b.add_theme_stylebox_override("hover", ThemeBuilder.box(Color("#1E1A15"), Palette.AMBER, 2, 8, 0))
		b.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color("#2A2014"), Palette.GOLD, 3, 8, 0))
		b.add_theme_stylebox_override("hover_pressed", ThemeBuilder.box(Color("#2A2014"), Palette.GOLD, 3, 8, 0))
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_theme_constant_override("margin_left", 18)
		m.add_theme_constant_override("margin_right", 18)
		m.add_theme_constant_override("margin_top", 8)
		b.add_child(m)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 2)
		m.add_child(v)
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(h)
		h.add_child(ThemeBuilder.label(ind["name"], 23, Palette.PAPER, ThemeBuilder.serif(900)))
		var nums := ThemeBuilder.label("单店月营收 %s · 租金 %s · 人工 %s" % [Money.short(float(ind["base_revenue"])), Money.short(float(ind["rent"])), Money.short(float(ind["staff_cost"]))], 16, Palette.AMBER, ThemeBuilder.mono())
		nums.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nums.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(nums)
		var d := ThemeBuilder.label(ind["desc"], 16, Palette.TEXT_DIM)
		v.add_child(d)
		b.pressed.connect(_pick_industry.bind(ind["key"]))
		Audio.wire_button(b)
		left.add_child(b)
		_ind_buttons[ind["key"]] = b

	left.add_child(_section("二、商号与起步资本"))
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 14)
	left.add_child(nr)
	nr.add_child(ThemeBuilder.label("商号", 20, Palette.TEXT))
	_name_edit = LineEdit.new()
	_name_edit.text = "天玄实业"
	_name_edit.max_length = 12
	_name_edit.custom_minimum_size = Vector2(320, 48)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.text_changed.connect(func(_t): _refresh())
	nr.add_child(_name_edit)
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 14)
	left.add_child(cr)
	cr.add_child(ThemeBuilder.label("起步资本", 20, Palette.TEXT))
	_cash_slider = HSlider.new()
	_cash_slider.min_value = float(e["starting_cash_range"][0])
	_cash_slider.max_value = float(e["starting_cash_range"][1])
	_cash_slider.step = 1000000
	_cash_slider.value = float(e["default_starting_cash"])
	_cash_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cash_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cash_slider.value_changed.connect(func(_v): _refresh())
	cr.add_child(_cash_slider)
	_cash_lbl = ThemeBuilder.label("", 24, Palette.AMBER, ThemeBuilder.mono())
	_cash_lbl.custom_minimum_size = Vector2(140, 0)
	cr.add_child(_cash_lbl)

	# 右：总部宫位
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	right.add_child(_section("三、总部选址（九宫地盘，上北下南）"))
	_grid = PalaceGrid.new()
	_grid.cell_size = Vector2(318, 178)
	_grid.palace_selected.connect(func(_p): _refresh())
	right.add_child(_grid)
	_palace_info = ThemeBuilder.label("", 17, Palette.TEXT_DIM)
	_palace_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_palace_info)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 20)
	root.add_child(foot)
	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.add_theme_font_size_override("normal_font_size", 19)
	foot.add_child(_summary)
	_start_btn = Button.new()
	_start_btn.text = "开张大吉  ▶"
	_start_btn.custom_minimum_size = Vector2(320, 70)
	_start_btn.add_theme_font_size_override("font_size", 30)
	_start_btn.add_theme_stylebox_override("normal", ThemeBuilder.box(Color("#3A2A12"), Palette.AMBER, 2, 8, 14))
	_start_btn.add_theme_stylebox_override("hover", ThemeBuilder.box(Color("#4A3616"), Palette.AMBER.lightened(0.2), 2, 8, 14))
	_start_btn.add_theme_color_override("font_color", Palette.AMBER.lightened(0.3))
	_start_btn.pressed.connect(_on_start)
	Audio.wire_button(_start_btn)
	foot.add_child(_start_btn)

	_pick_industry(SandboxGame.industries()[0]["key"])
	Audio.play_music("sandbox_era")


func _section(text: String) -> Label:
	return ThemeBuilder.label(text, 22, Palette.GOLD, ThemeBuilder.serif(700))


func _pick_industry(key: String) -> void:
	industry_key = key
	for k in _ind_buttons:
		_ind_buttons[k].set_pressed_no_signal(k == key)
	_grid.setup(key)
	_grid.select(SandboxGame.best_palaces(key)[0])
	_refresh()


func _refresh() -> void:
	_cash_lbl.text = Money.short(_cash_slider.value)
	var pid: String = _grid.selected
	var ind := SandboxGame.industry(industry_key)
	var f := NinePalacesSystem.new().affinity(industry_key, pid) if pid != "" else 1.0
	_palace_info.text = ("%s　·　%s在此宫的地利系数 ×%.2f（推荐宫位：%s）" % [SandboxGame.palace_label(pid), ind["name"], f,
			"、".join(SandboxGame.best_palaces(industry_key).map(func(p): return SandboxGame.palace_label(p).split("·")[0]))]) if pid != "" else ""
	var e := SandboxGame.econ()
	var monthly := float(ind["rent"]) + float(ind["staff_cost"]) + float(e["hq_invest_equiv"]) * float(e["maintenance_rate"]) + float(e["sandbox_misc_cost"])
	_summary.text = "[color=%s]%s[/color] · %s · 总部 %s · 起步资本 [color=%s]%s[/color]\n[color=%s]总部每月固定开支约 %s（不含高管薪酬与营销）。没有高管时人和只有 ×0.70，开张后先去人才市场延揽人才。[/color]" % [
		Palette.hex(Palette.PAPER), _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "（未命名）", ind["name"],
		SandboxGame.palace_label(pid).split("·")[0] if pid != "" else "未选", Palette.hex(Palette.AMBER), Money.short(_cash_slider.value),
		Palette.hex(Palette.TEXT_DIM), Money.short(monthly)]
	_start_btn.disabled = pid == "" or _name_edit.text.strip_edges() == ""


func _on_start() -> void:
	Audio.sfx("ui_confirm")
	start_requested.emit(_name_edit.text.strip_edges(), industry_key, _cash_slider.value, _grid.selected)
