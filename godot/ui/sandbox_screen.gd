extends Control
## 二十年自由沙盒主界面：左侧金融终端（结账单、近三年现金走势、盈亏解读），右侧罗盘（三才因子、下月预告、经营操作），
## 底部高管卡。规则由 SandboxGame 驱动；人才市场每季度刷新，每月自动存档。

signal exit_requested
signal new_game_requested
signal load_requested(slot: String)

const OfficeScreen := preload("res://ui/office_screen.gd")
const SystemMenu := preload("res://ui/dialogs/system_menu.gd")
const SaveSlotsDialog := preload("res://ui/dialogs/save_slots_dialog.gd")
const SettingsDialog := preload("res://ui/dialogs/settings_dialog.gd")
const TalentDialog := preload("res://ui/dialogs/talent_market_dialog.gd")
const ExpansionDialog := preload("res://ui/dialogs/expansion_dialog.gd")
const StoresDialog := preload("res://ui/dialogs/stores_dialog.gd")
const EndingDialog := preload("res://ui/dialogs/sandbox_ending_dialog.gd")
const ExecCard := preload("res://ui/widgets/exec_card.gd")
const CashChart := preload("res://ui/widgets/cash_chart.gd")
const FactorGauge := preload("res://ui/widgets/factor_gauge.gd")
const SEASON_ICON := {"Spring": "spring", "Summer": "summer", "Autumn": "autumn", "Winter": "winter"}
const CHART_MONTHS := 36

var new_game := {}                 ## 新开局参数：{name, industry, cash, home}
var restore := {}                  ## 读档：{"sandbox": SandboxGame, "office": OfficeLayout}
var game: SandboxGame
var office: OfficeLayout
var _busy := false
var _logged := false
var _seal_armed := false

var _company_lbl: Label
var _sub_lbl: Label
var _date_lbl: Label
var _era_lbl: Label
var _season_icon: TextureRect
var _cash_lbl: Label
var _assets_lbl: Label
var _rep_lbl: Label
var _years_lbl: Label
var _grade_lbl: Label
var _goal_lbl: Label
var _goal_bar: ProgressBar
var _stmt_title: Label
var _stmt_values := {}
var _chart: Control
var _insight: RichTextLabel
var _gauge: VBoxContainer
var _compass: Compass3D
var _compass_holder: Control
var _forecast: RichTextLabel
var _mkt_slider: HSlider
var _mkt_lbl: Label
var _advance_btn: Button
var _year_btn: Button
var _seal_btn: Button
var _talent_btn: Button
var _exec_row: HBoxContainer
var _exec_cards := {}
var _toast_box: VBoxContainer


func _exit_tree() -> void:
	if not _logged and game and not game.is_game_over() and game.turn > 0:
		PlaytestLog.record_sandbox(game, office, "quit")


func _ready() -> void:
	if restore.is_empty():
		game = SandboxGame.create_new_game(new_game["name"], new_game["industry"], float(new_game["cash"]), new_game["home"])
		office = OfficeLayout.from_preset("chaotic")
	else:
		game = restore["sandbox"]
		office = restore["office"]
	_build()
	_mkt_slider.value = float(SandboxGame.econ()["default_marketing"])
	_refresh()
	_render_forecast(Insight.time_line(game.clock, game.company.industry), "本月天时（%d年%02d月）" % [game.clock.year, game.clock.month])
	var hist := game.company.financial_history
	if hist.is_empty():
		_insight.text = "[color=%s]新公司刚刚开张。建议先去「人才市场」延揽高管——没有管理层时人和只有 ×0.70；再到推荐宫位开分店。\n每月结算后，这里会用天时、地利、人和三方面解释盈亏来源。[/color]" % Palette.hex(Palette.TEXT_DIM)
	else:
		_show_statement(hist[-1], "上月")
		_render_insight(Insight.explain_month(game.company, game.engine))
		_toast("已读取存档：%d年%02d月，第 %d 个月" % [game.clock.year, game.clock.month, game.turn], Palette.GOLD)
	Audio.play_music("sandbox_era")


# ─── 布局 ──────────────────────────────────────────────────────────────────
func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_build_top_bar())
	root.add_child(_build_goal_bar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	body.add_child(_build_terminal())
	body.add_child(_build_compass_side())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 168)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_exec_row = HBoxContainer.new()
	_exec_row.add_theme_constant_override("separation", 14)
	_exec_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exec_row.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(_exec_row)
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_box.position = Vector2(-560, 150)
	_toast_box.custom_minimum_size = Vector2(520, 0)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_box)


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	bar.add_child(left)
	_company_lbl = ThemeBuilder.label("", 32, Palette.PAPER, ThemeBuilder.serif(900))
	left.add_child(_company_lbl)
	_sub_lbl = ThemeBuilder.label("", 17, Palette.TEXT_DIM)
	left.add_child(_sub_lbl)
	bar.add_child(_spacer())
	_season_icon = TextureRect.new()
	_season_icon.custom_minimum_size = Vector2(56, 56)
	_season_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_season_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bar.add_child(_season_icon)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 2)
	bar.add_child(mid)
	_date_lbl = ThemeBuilder.label("", 28, Palette.GOLD, ThemeBuilder.serif(700))
	mid.add_child(_date_lbl)
	_era_lbl = ThemeBuilder.label("", 16, Palette.TEXT_DIM)
	mid.add_child(_era_lbl)
	bar.add_child(_spacer())
	_cash_lbl = _stat(bar, "账面现金")
	_assets_lbl = _stat(bar, "估算净资产")
	_rep_lbl = _stat(bar, "商誉")
	_years_lbl = _stat(bar, "距终局")
	var back := Button.new()
	back.text = "菜单 (Esc)"
	back.pressed.connect(open_system_menu)
	Audio.wire_button(back)
	bar.add_child(back)
	return bar


func _stat(parent: Control, caption: String) -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	parent.add_child(v)
	v.add_child(ThemeBuilder.label(caption, 15, Palette.TEXT_DIM))
	var l := ThemeBuilder.label("", 28, Palette.AMBER, ThemeBuilder.mono())
	v.add_child(l)
	return l


func _build_goal_bar() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.box(Color("#1A1610"), Palette.GOLD.darkened(0.4), 1, 6, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	h.add_child(ThemeBuilder.label("若此刻封盘", 18, Palette.GOLD, ThemeBuilder.serif(700)))
	_grade_lbl = ThemeBuilder.label("", 20, Palette.PAPER, ThemeBuilder.serif(900))
	h.add_child(_grade_lbl)
	_goal_lbl = ThemeBuilder.label("", 18, Palette.TEXT)
	_goal_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_goal_lbl)
	_goal_bar = ProgressBar.new()
	_goal_bar.custom_minimum_size = Vector2(320, 14)
	_goal_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_goal_bar.show_percentage = false
	h.add_child(_goal_bar)
	return p


func _build_terminal() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.55
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_stmt_title = ThemeBuilder.label("月度结账单", 22, Palette.GOLD, ThemeBuilder.serif(700))
	v.add_child(_stmt_title)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for item in [["revenue", "月度总营收"], ["rent", "物业租金"], ["payroll", "全员薪酬"],
			["other", "运营/营销/杂项"], ["net", "当月净利润"], ["cash", "期末现金"]]:
		grid.add_child(ThemeBuilder.label(item[1], 17, Palette.TEXT_DIM))
		var val := ThemeBuilder.label("—", 22, Palette.TEXT, ThemeBuilder.mono())
		val.custom_minimum_size = Vector2(170, 0)
		grid.add_child(val)
		_stmt_values[item[0]] = val
	_chart = CashChart.new()
	_chart.custom_minimum_size = Vector2(0, 220)
	v.add_child(_chart)
	v.add_child(ThemeBuilder.label("本月盈亏解读", 20, Palette.GOLD, ThemeBuilder.serif(700)))
	_insight = RichTextLabel.new()
	_insight.bbcode_enabled = true
	_insight.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_insight.scroll_active = true
	v.add_child(_insight)
	return panel


func _build_compass_side() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_compass_holder = Control.new()
	_compass_holder.custom_minimum_size = Vector2(0, 118)
	_compass_holder.clip_contents = true
	v.add_child(_compass_holder)
	_compass = Compass3D.new()
	_compass.base_scale = 0.2
	_compass_holder.add_child(_compass)
	_compass_holder.resized.connect(func(): _compass.position = _compass_holder.size / 2)
	_gauge = FactorGauge.new()
	v.add_child(_gauge)
	_forecast = RichTextLabel.new()
	_forecast.bbcode_enabled = true
	_forecast.fit_content = true
	_forecast.custom_minimum_size = Vector2(0, 60)
	v.add_child(_forecast)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var mkt := HBoxContainer.new()
	v.add_child(mkt)
	mkt.add_child(ThemeBuilder.label("月度营销预算", 18, Palette.TEXT_DIM))
	_mkt_slider = HSlider.new()
	_mkt_slider.min_value = 0
	_mkt_slider.max_value = float(SandboxGame.econ()["marketing_max"])
	_mkt_slider.step = 10000
	_mkt_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mkt_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mkt_slider.tooltip_text = "营销加成随预算递增，超过 20 万不再增加"
	_mkt_slider.value_changed.connect(func(val): _mkt_lbl.text = Money.short(val) if val > 0 else "不投放")
	mkt.add_child(_mkt_slider)
	_mkt_lbl = ThemeBuilder.label("不投放", 18, Palette.AMBER, ThemeBuilder.mono())
	_mkt_lbl.custom_minimum_size = Vector2(110, 0)
	mkt.add_child(_mkt_lbl)

	var ops := GridContainer.new()
	ops.columns = 2
	ops.add_theme_constant_override("h_separation", 10)
	ops.add_theme_constant_override("v_separation", 8)
	v.add_child(ops)
	_talent_btn = _op(ops, "人才市场 (H)", _open_talent)
	_op(ops, "九宫拓店 (N)", _open_expansion)
	_op(ops, "门店经营 (S)", _open_stores)
	_op(ops, "风水工位 (F)", _open_office)

	var adv := HBoxContainer.new()
	adv.add_theme_constant_override("separation", 10)
	v.add_child(adv)
	_advance_btn = Button.new()
	_advance_btn.text = "推进本月  ▶"
	_advance_btn.tooltip_text = "快捷键：空格"
	_advance_btn.custom_minimum_size = Vector2(0, 58)
	_advance_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advance_btn.size_flags_stretch_ratio = 1.6
	_advance_btn.add_theme_font_size_override("font_size", 30)
	_advance_btn.add_theme_stylebox_override("normal", ThemeBuilder.box(Color("#3A2A12"), Palette.AMBER, 2, 8, 14))
	_advance_btn.add_theme_stylebox_override("hover", ThemeBuilder.box(Color("#4A3616"), Palette.AMBER.lightened(0.2), 2, 8, 14))
	_advance_btn.add_theme_color_override("font_color", Palette.AMBER.lightened(0.3))
	_advance_btn.pressed.connect(_on_advance)
	Audio.wire_button(_advance_btn)
	adv.add_child(_advance_btn)
	_year_btn = Button.new()
	_year_btn.text = "快进一年 ▶▶"
	_year_btn.tooltip_text = "连续推进 12 个月（快捷键 Y）"
	_year_btn.custom_minimum_size = Vector2(0, 58)
	_year_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_year_btn.pressed.connect(_on_fast_year)
	Audio.wire_button(_year_btn)
	adv.add_child(_year_btn)
	_seal_btn = Button.new()
	_seal_btn.text = "提前封盘结算"
	_seal_btn.custom_minimum_size = Vector2(0, 36)
	_seal_btn.add_theme_font_size_override("font_size", 17)
	_seal_btn.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_seal_btn.pressed.connect(_on_seal)
	Audio.wire_button(_seal_btn)
	v.add_child(_seal_btn)
	return panel


func _op(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	Audio.wire_button(b)
	parent.add_child(b)
	return b


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


# ─── 刷新 ──────────────────────────────────────────────────────────────────
func _refresh() -> void:
	var c := game.company
	var clk := game.clock
	var t := DataTables.engine()
	_company_lbl.text = c.name
	_sub_lbl.text = "二十年自由沙盒 · %s · 门店 %d 家 · 高管 %d 人" % [game.industry_cfg["name"], c.active_stores().size(), c.executives.size()]
	_date_lbl.text = "%d年%02d月　%s" % [clk.year, clk.month, t["season_names"][str(clk.month)]]
	_era_lbl.text = "%s　·　%s" % [clk.era_name, t["month_names"][clk.month - 1]]
	_season_icon.texture = load("res://assets/icons/season_%s.png" % SEASON_ICON[clk.get_season_key(clk.month)])
	_cash_lbl.text = Money.short(c.cash)
	_cash_lbl.add_theme_color_override("font_color", Palette.AMBER if c.cash >= 0 else Palette.CINNABAR)
	_assets_lbl.text = Money.short(game.net_assets())
	_rep_lbl.text = "%d" % c.reputation
	_years_lbl.text = "%d年" % maxi(0, game.years_left())
	_refresh_goal()
	var f_t: float = clk.calculate_time_factor(c.industry)["value"]
	var active := c.active_stores()
	var f_s := 1.0
	if not active.is_empty():
		var sum := 0.0
		for s in active:
			sum += game.engine.palaces_sys.calculate_store_space_factor(c.industry, s.palace_id, c.fengshui_modifier)
		f_s = sum / active.size()
	var p := game.engine.personnel_sys.calculate_personnel_factor(c.executives)
	_gauge.set_values(f_t, f_s, p["value"])
	var hist := c.financial_history
	var window := hist.slice(-CHART_MONTHS)
	var start: float = hist[-window.size() - 1].ending_cash if hist.size() > window.size() else float(new_game.get("cash", window[0].ending_cash if not window.is_empty() else c.cash))
	_chart.left_label = "%d个月前" % window.size() if hist.size() > window.size() else "开局"
	_chart.right_label = "本月"
	_chart.set_data(start, window, 0.0, maxi(window.size(), 12))
	_refresh_execs(p)
	_talent_btn.text = "人才市场 (H) · %d人" % game.talent_pool.available.size()


func _profitable_streak() -> int:
	var hist := game.company.financial_history
	var n := 0
	var i := hist.size()
	while i >= 12:
		var y := 0.0
		for f in hist.slice(i - 12, i):
			y += f.net_profit
		if y <= 0:
			break
		n += 1
		i -= 12
	return n


func _refresh_goal() -> void:
	var c := game.company
	var e := game.check_ending()
	var th: Dictionary = SandboxGame.data()["ending_thresholds"]
	_grade_lbl.text = "%s 级 · %s" % [e["grade"], e["title"]]
	var na := game.net_assets()
	var parts := PackedStringArray()
	var target := float(th["a_assets"])
	match e["grade"]:
		"S":
			parts.append("已达最高评级，守住到 %d 年底" % int(SandboxGame.econ()["end_year"]))
			target = float(th["s_assets"])
		"A":
			target = float(th["s_assets"])
			parts.append("冲 S：净资产 %s / %s　商誉 %d / %d　连续盈利 %d 年（需 %d）　门店 %d / %d" % [Money.short(na), Money.short(target),
					c.reputation, int(th["s_reputation"]), _profitable_streak(), int(th["s_profitable_years"]), c.active_stores().size(), int(th["s_min_stores"])])
		_:
			parts.append("冲 A：净资产 %s / %s　商誉 %d / %d" % [Money.short(na), Money.short(target), c.reputation, int(th["a_reputation"])])
			if e["grade"] != "B":
				parts.append("（B 级需净资产 ≥ %s 且近一年盈利，近一年 %s）" % [Money.short(float(th["b_assets"])), Money.short(game.last_year_profit())])
	_goal_lbl.text = "　".join(parts)
	_goal_bar.value = clampf(na / target, 0.0, 1.0) * 100


func _refresh_execs(p: Dictionary) -> void:
	var c := game.company
	var ids := {}
	for e in c.executives:
		ids[e.id] = true
	for id in _exec_cards.keys():
		if not ids.has(id):
			_exec_cards[id].queue_free()
			_exec_cards.erase(id)
	if c.executives.is_empty() and _exec_row.get_child_count() == 0:
		_exec_row.add_child(ThemeBuilder.label("尚无高管——去「人才市场」延揽人才，人和系数才能超过 ×0.70", 20, Palette.TEXT_DIM))
	elif not c.executives.is_empty():
		for ch in _exec_row.get_children():
			if ch is Label:
				ch.queue_free()
	var clashing := RoleNames.clashing_ids(c.executives)
	for e in c.executives:
		if not _exec_cards.has(e.id):
			var card := ExecCard.new()
			_exec_row.add_child(card)
			_exec_cards[e.id] = card
		var score: float = p["role_details"].get(e.role, {}).get("score", 1.0)
		_exec_cards[e.id].show_exec(e, score, RoleNames.mood(e, clashing, c.financial_history))


func _show_statement(st: FinancialStatement, month_label: String) -> void:
	_stmt_title.text = "月度结账单 · " + month_label
	var other := st.total_cost - st.rent_expense - st.payroll_expense
	var rows := {"revenue": [st.gross_revenue, Palette.JADE], "rent": [-st.rent_expense, Palette.TEXT],
		"payroll": [-st.payroll_expense, Palette.TEXT], "other": [-other, Palette.TEXT],
		"net": [st.net_profit, Palette.JADE if st.net_profit >= 0 else Palette.CINNABAR],
		"cash": [st.ending_cash, Palette.AMBER if st.ending_cash >= 0 else Palette.CINNABAR]}
	for k in rows:
		_stmt_values[k].text = Money.short(rows[k][0])
		_stmt_values[k].add_theme_color_override("font_color", rows[k][1])


func _render_insight(lines: PackedStringArray) -> void:
	var out := PackedStringArray()
	for line in lines:
		var color := Palette.TEXT_DIM
		if line.begins_with("【天时】"):
			color = Palette.GOLD.lightened(0.2)
		elif line.begins_with("【地利】"):
			color = Palette.ELEMENT["Earth"].lightened(0.35)
		elif line.begins_with("【人和】"):
			color = Palette.JADE.lightened(0.1)
		elif "⚠" in line or "内耗+" in line:
			color = Palette.AMBER
		elif "降低" in line:
			color = Palette.JADE
		out.append("[color=%s]%s[/color]" % [Palette.hex(color), line.strip_edges() if line.begins_with(" ") else line])
	_insight.text = "\n".join(out)


func _render_forecast(text: String, title := "下月预告") -> void:
	var body := text.replace("【下月预告】", "")
	var arrow_color := Palette.TEXT
	if body.ends_with("↑"):
		arrow_color = Palette.JADE
	elif body.ends_with("↓"):
		arrow_color = Palette.CINNABAR
	_forecast.text = "[color=%s][b]%s[/b][/color]\n[color=%s]%s[/color]" % [Palette.hex(Palette.GOLD), title, Palette.hex(arrow_color), body]


# ─── 流程 ──────────────────────────────────────────────────────────────────
func _set_busy(b: bool) -> void:
	_busy = b
	for btn in [_advance_btn, _year_btn, _seal_btn]:
		btn.disabled = b


## 推进一个月；quiet 为 true 时（快进）不播放逐月音效与解读。返回是否已终局
func _step(quiet := false) -> bool:
	var c := game.company
	var label := "%d年%02d月" % [game.clock.year, game.clock.month]
	var season_before := game.clock.get_season_key(game.clock.month)
	var out := game.advance_month(_mkt_slider.value)
	var st: FinancialStatement = out["statement"]
	_show_statement(st, label)
	if out["event"] != null:
		_show_event(out["event"])
	if not quiet:
		_render_insight(Insight.explain_month(c, game.engine))
		Audio.sfx("report_print")
	if game.turn % 3 == 0 and not game.is_game_over():
		game.refresh_talent_market()
		if not quiet:
			_toast("人才市场已刷新：第 %d 季度，%d 位新候选人" % [game.talent_pool.quarter, game.talent_pool.available.size()], Palette.GOLD)
	var season_now := game.clock.get_season_key(game.clock.month)
	if season_now != season_before and not quiet:
		Audio.sfx("season_change")
	_refresh()
	return game.is_game_over()


func _on_advance() -> void:
	if _busy or game.is_game_over():
		return
	_set_busy(true)
	Audio.sfx("month_advance")
	_compass.spin(90.0, 0.8)
	var over := _step()
	var st := game.company.financial_history[-1]
	await get_tree().create_timer(0.35).timeout
	Audio.sfx("cash_gain" if st.net_profit >= 0 else "cash_loss")
	_render_forecast(Insight.forecast_next_month(game.clock, game.company.industry))
	_set_busy(false)
	if over:
		_finish()
	else:
		_autosave()


func _on_fast_year() -> void:
	if _busy or game.is_game_over():
		return
	_set_busy(true)
	Audio.sfx("month_advance")
	_compass.spin(360.0, 2.0)
	var cash0 := game.company.cash
	var profit := 0.0
	var events := 0
	var months := 0
	var over := false
	for i in 12:
		over = _step(true)
		months += 1
		profit += game.company.financial_history[-1].net_profit
		if game.game_log[-1].contains("事件："):
			events += 1
		await get_tree().create_timer(0.12).timeout
		if over:
			break
	_render_insight(Insight.explain_month(game.company, game.engine))
	_render_forecast(Insight.forecast_next_month(game.clock, game.company.industry))
	Audio.sfx("cash_gain" if profit >= 0 else "cash_loss")
	_toast("快进 %d 个月：累计净利润 %s，现金 %s → %s，突发事件 %d 起" % [months, Money.short(profit), Money.short(cash0), Money.short(game.company.cash), events],
			Palette.JADE if profit >= 0 else Palette.CINNABAR, 5.0)
	_set_busy(false)
	if over:
		_finish()
	else:
		_autosave()


func _on_seal() -> void:
	if _busy or game.is_game_over():
		return
	if not _seal_armed:
		_seal_armed = true
		_seal_btn.text = "确定提前封盘？再点一次"
		_seal_btn.add_theme_color_override("font_color", Palette.CINNABAR)
		get_tree().create_timer(4.0).timeout.connect(func():
			_seal_armed = false
			if is_instance_valid(_seal_btn):
				_seal_btn.text = "提前封盘结算"
				_seal_btn.add_theme_color_override("font_color", Palette.TEXT_DIM))
		return
	_finish(true)


func _finish(early := false) -> void:
	_set_busy(true)
	_logged = true
	var ending := game.check_ending()
	PlaytestLog.record_sandbox(game, office, "sealed" if early else ending["grade"])
	var auto := SaveGame.read("autosave")
	if auto.get("mode", "") == "sandbox":
		SaveGame.delete("autosave")
	Audio.stop_music(0.8)
	match ending["grade"]:
		"S", "A":
			Audio.sfx("victory")
			Audio.play_music("sting_victory", 0.2)
		"B", "C":
			Audio.play_music("sting_defeat", 0.2)
		_:
			Audio.sfx("bankrupt")
			Audio.play_music("sting_bankrupt", 0.2)
	var d := EndingDialog.new()
	d.game = game
	d.ending = ending
	d.early = early
	d.restart.connect(func(): new_game_requested.emit())
	d.back_to_title.connect(func(): exit_requested.emit())
	add_child(d)


func _open_talent() -> void:
	if _busy or game.is_game_over():
		return
	var d := TalentDialog.new()
	d.game = game
	d.months_to_refresh = 3 - game.turn % 3
	d.hired.connect(func(msg):
		_toast(msg, Palette.JADE)
		_refresh())
	add_child(d)


func _open_expansion() -> void:
	if _busy or game.is_game_over():
		return
	var d := ExpansionDialog.new()
	d.game = game
	d.opened.connect(func(msg):
		_toast(msg, Palette.JADE, 5.0)
		_refresh())
	add_child(d)


func _open_stores() -> void:
	if _busy or game.is_game_over():
		return
	var d := StoresDialog.new()
	d.game = game
	d.closed_store.connect(func(msg):
		_toast(msg, Palette.AMBER)
		_refresh())
	add_child(d)


func _open_office() -> void:
	if _busy or game.is_game_over():
		return
	var o := OfficeScreen.new()
	o.base = office
	o.cash = game.company.cash
	o.company_modifier = game.company.fengshui_modifier
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.confirmed.connect(_on_office_confirmed)
	o.closed.connect(func(): Audio.play_music("sandbox_era"))
	add_child(o)


func _on_office_confirmed(new_layout: OfficeLayout, cost: float) -> void:
	var c := game.company
	var old_mod := c.fengshui_modifier
	c.cash -= cost
	c.fengshui_modifier = OfficeLayout.apply_to_company(c.fengshui_modifier, office, new_layout)
	office = new_layout
	_toast("风水改造完成：花费 %s，公司风水修正 %+.1f%% → %+.1f%%" % [Money.short(cost), old_mod * 100, c.fengshui_modifier * 100], Palette.GOLD)
	_refresh()


func _show_event(evt: Dictionary) -> void:
	var sound := "event_opportunity"
	var color := Palette.JADE
	if evt.get("id", "") == "tengshe_audit" or "螣蛇" in str(evt.get("name", "")):
		sound = "event_tengshe"
		color = Palette.AMBER
	elif evt.get("type", "") == "crisis":
		sound = "event_crisis"
		color = Palette.CINNABAR
	Audio.sfx(sound)
	_toast("%s\n%s\n资金 %s　商誉 %+d" % [evt["name"], evt["desc"], PyFmt.signed_thousands(float(evt["effect_cash"])), int(evt["effect_reputation"])], color, 6.0)


func _autosave() -> void:
	if Settings.autosave and not game.is_game_over():
		SaveGame.save_sandbox("autosave", game, office)


func _save_to(slot: String) -> void:
	if SaveGame.save_sandbox(slot, game, office):
		_toast("已保存到「%s」" % SaveGame.SLOT_NAMES[slot], Palette.JADE)


func _toast(text: String, color: Color, seconds := 4.0) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(Palette.TERMINAL, 0.95), color, 2, 8, 14))
	var l := ThemeBuilder.label(text, 18, Palette.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(490, 0)
	p.add_child(l)
	p.modulate.a = 0.0
	_toast_box.add_child(p)
	while _toast_box.get_child_count() > 2:
		var old := _toast_box.get_child(0)
		_toast_box.remove_child(old)
		old.queue_free()
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(seconds)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


# ─── 系统菜单与快捷键 ──────────────────────────────────────────────────────
func _has_overlay() -> bool:
	for c in get_children():
		if c.is_in_group("overlay") and not c.is_queued_for_deletion():
			return true
	return false


func open_system_menu() -> void:
	var m := SystemMenu.new()
	m.save_requested.connect(func():
		var d := SaveSlotsDialog.new()
		d.mode = "save"
		d.slot_chosen.connect(_save_to)
		add_child(d))
	m.load_requested.connect(func():
		var d := SaveSlotsDialog.new()
		d.mode = "load"
		d.slot_chosen.connect(func(slot): load_requested.emit(slot))
		add_child(d))
	m.settings_requested.connect(func(): add_child(SettingsDialog.new()))
	m.title_requested.connect(func(): exit_requested.emit())
	add_child(m)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or _has_overlay():
		return
	match event.keycode:
		KEY_ESCAPE:
			open_system_menu()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if not _advance_btn.disabled:
				_on_advance()
		KEY_Y:
			if not _year_btn.disabled:
				_on_fast_year()
		KEY_H:
			_open_talent()
		KEY_N:
			_open_expansion()
		KEY_S:
			_open_stores()
		KEY_F:
			_open_office()
		_:
			return
	get_viewport().set_input_as_handled()
