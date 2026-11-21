extends "res://ui/dialogs/modal.gd"
## 九宫拓店：选宫位 → 定投资额 → 预估月营收/成本/利润与回本期 → 开店

signal opened(msg: String)

const PalaceGrid := preload("res://ui/widgets/palace_grid.gd")

var game: SandboxGame
var _grid: GridContainer
var _invest: HSlider
var _invest_lbl: Label
var _name: LineEdit
var _preview: RichTextLabel
var _open_btn: Button
var _named_by_user := false


func _ready() -> void:
	esc_closes = true
	card.custom_minimum_size = Vector2(1560, 0)
	var e := SandboxGame.econ()
	var head := HBoxContainer.new()
	body.add_child(head)
	head.add_child(ink_label("九宫战略拓店", 32, INK_TEXT, 900, false))
	var note := sans_label("　同一宫位每多一家店，新店营收 ×%.2f（市场饱和）。投资越大门店越大，但边际递减。" % float(e["palace_saturation"]), 17, Color(INK_TEXT, 0.65))
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(note)
	var close_btn := option_button("", "关闭 (Esc)")
	close_btn.custom_minimum_size = Vector2(160, 48)
	close_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	body.add_child(row)
	_grid = PalaceGrid.new()
	_grid.cell_size = Vector2(300, 170)
	_grid.info_fn = func(pid):
		var n := game.same_palace_count(pid)
		return ("已有 %d 家 · 新店 ×%.2f" % [n, game.saturation(pid)]) if n > 0 else "尚无门店"
	_grid.palace_selected.connect(func(pid):
		if not _named_by_user:
			_name.text = _default_name(pid)
		_refresh())
	row.add_child(_grid)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 14)
	row.add_child(side)
	side.add_child(ink_label("门店名称", 20, INK_TEXT, 700))
	_name = LineEdit.new()
	_name.max_length = 14
	_name.custom_minimum_size = Vector2(0, 48)
	_name.add_theme_font_size_override("font_size", 21)
	_name.text_changed.connect(func(_t):
		_named_by_user = true
		_refresh())
	side.add_child(_name)
	side.add_child(ink_label("投资额", 20, INK_TEXT, 700))
	var ir := HBoxContainer.new()
	side.add_child(ir)
	_invest = HSlider.new()
	_invest.min_value = float(e["min_store_invest"])
	_invest.max_value = maxf(float(e["min_store_invest"]), minf(float(e["max_store_invest"]), floorf(game.company.cash / 500000.0) * 500000.0))
	_invest.step = 500000
	_invest.value = clampf(float(e["ref_store_invest"]), _invest.min_value, _invest.max_value)
	_invest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_invest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_invest.value_changed.connect(func(_v): _refresh())
	ir.add_child(_invest)
	_invest_lbl = sans_label("", 24, Palette.CINNABAR.darkened(0.2), 700)
	_invest_lbl.custom_minimum_size = Vector2(130, 0)
	_invest_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ir.add_child(_invest_lbl)
	_preview = RichTextLabel.new()
	_preview.bbcode_enabled = true
	_preview.fit_content = true
	_preview.add_theme_font_override("normal_font", ThemeBuilder.serif(400))
	_preview.add_theme_font_size_override("normal_font_size", 19)
	_preview.add_theme_color_override("default_color", INK_TEXT)
	side.add_child(_preview)
	_open_btn = option_button("", "斥资开店")
	_open_btn.custom_minimum_size = Vector2(0, 56)
	_open_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_open_btn.pressed.connect(_on_open)
	side.add_child(_open_btn)

	_grid.setup(game.company.industry)
	var first: String = SandboxGame.best_palaces(game.company.industry)[0]
	_grid.select(first)
	_name.text = _default_name(first)
	_named_by_user = false
	_refresh()
	super._ready()


## 默认店名：城市 + 分店；同城已有则依次叫二店、三店……
func _default_name(pid: String) -> String:
	var city := SandboxGame.city_of(pid).split("/")[0]
	var names := {}
	for s in game.company.stores:
		names[s.name] = true
	if not names.has(city + "分店"):
		return city + "分店"
	var cn := ["二", "三", "四", "五", "六", "七", "八", "九", "十"]
	for i in cn.size():
		if not names.has(city + cn[i] + "店"):
			return city + cn[i] + "店"
	return "%s%d号店" % [city, game.company.stores.size() + 1]


func _refresh() -> void:
	var e := SandboxGame.econ()
	var pid: String = _grid.selected
	var inv := _invest.value
	_invest_lbl.text = Money.short(inv)
	if pid == "":
		_preview.text = ""
		_open_btn.disabled = true
		return
	var c := game.company
	var scale := inv / float(e["ref_store_invest"])
	var base := game.new_store_base_revenue(pid, inv)
	var f_t := float(game.clock.calculate_time_factor(c.industry)["value"])
	var f_s := game.engine.palaces_sys.calculate_store_space_factor(c.industry, pid, c.fengshui_modifier)
	var f_p := float(game.engine.personnel_sys.calculate_personnel_factor(c.executives)["value"])
	var rev := base * f_t * f_s * f_p
	var rm := (float(e["rent_mult_range"][0]) + float(e["rent_mult_range"][1])) / 2.0
	var sm := (float(e["staff_mult_range"][0]) + float(e["staff_mult_range"][1])) / 2.0
	var cost := float(game.industry_cfg["rent"]) * scale * rm + float(game.industry_cfg["staff_cost"]) * scale * sm + inv * float(e["maintenance_rate"])
	var profit := rev - cost
	var pay := ("约 %d 个月回本" % ceili(inv / profit)) if profit > 0 else "按本月估算会亏损"
	var ok := inv <= c.cash and c.cash >= float(e["min_store_invest"])
	_preview.text = "月基础营收 [b]%s[/b]（规模 ×%.2f%s）\n按本月估算：营收 %s = 基础 × 天时 %.2f × 地利 %.2f × 人和 %.2f\n月成本约 %s（租金、人工随市场浮动 ±15%%，含折旧）\n月利润约 [color=%s][b]%s[/b][/color]，%s\n开店后现金 %s　·　关店可回收残值 %s" % [
		Money.short(base), pow(scale, float(e["invest_revenue_exp"])),
		("，饱和 ×%.2f" % game.saturation(pid)) if game.same_palace_count(pid) > 0 else "",
		Money.short(rev), f_t, f_s, f_p, Money.short(cost),
		Palette.hex(Palette.JADE.darkened(0.35) if profit >= 0 else Palette.CINNABAR), Money.short(profit), pay,
		Money.short(c.cash - inv), Money.short(inv * float(e["store_salvage_rate"]))]
	if not ok:
		_preview.text += "\n[color=%s]现金不足：开新店至少需要 %s。[/color]" % [Palette.hex(Palette.CINNABAR), Money.short(float(e["min_store_invest"]))]
	_open_btn.disabled = not ok or _name.text.strip_edges() == ""


func _on_open() -> void:
	var res := game.open_new_store(_name.text.strip_edges(), _grid.selected, _invest.value)
	if res["ok"]:
		Audio.sfx("store_open")
		opened.emit(res["msg"])
		close()
	else:
		Audio.sfx("ui_error")
		_preview.text += "\n[color=%s]%s[/color]" % [Palette.hex(Palette.CINNABAR), res["msg"]]
