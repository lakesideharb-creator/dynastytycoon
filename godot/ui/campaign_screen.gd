extends Control
## 战役主界面：左侧金融终端（结账单、现金走势、盈亏解读），右侧奇门罗盘（三才因子、下月预告、经营操作），
## 底部高管卡。所有规则由 CampaignRunner 驱动，界面只负责展示与输入。

signal exit_requested
signal restart_requested

const DecisionDialog := preload("res://ui/dialogs/decision_dialog.gd")
const MainChoiceDialog := preload("res://ui/dialogs/main_choice_dialog.gd")
const EndingDialog := preload("res://ui/dialogs/ending_dialog.gd")
const OfficeScreen := preload("res://ui/office_screen.gd")
const ExecCard := preload("res://ui/widgets/exec_card.gd")
const CashChart := preload("res://ui/widgets/cash_chart.gd")
const FactorGauge := preload("res://ui/widgets/factor_gauge.gd")
const SEASON_ICON := {"Spring": "spring", "Summer": "summer", "Autumn": "autumn", "Winter": "winter"}
const MAX_MARKETING := 300000.0

var scenario_id := 1
var runner: CampaignRunner
var rng := RandomNumberGenerator.new()
var start_cash := 0.0
var last_explain := PackedStringArray()
var last_forecast := ""

var _company_lbl: Label
var _date_lbl: Label
var _era_lbl: Label
var _season_icon: TextureRect
var _cash_lbl: Label
var _rep_lbl: Label
var _turn_lbl: Label
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
var _exec_row: HBoxContainer
var _exec_cards := {}
var _toast_box: VBoxContainer
var _busy := false
var office: OfficeLayout             ## 已生效的办公室布局（开局为恶煞布局，与终端版一致）
var _fs_btn: Button


func _ready() -> void:
	rng.randomize()
	runner = CampaignRunner.new(scenario_id)
	start_cash = runner.company.cash
	office = OfficeLayout.from_preset("chaotic")
	_build()
	_refresh()
	_show_turn_preview()
	Audio.play_season(runner.clock.get_season_key(runner.clock.month))
	if runner.main_choice == "":
		_open_main_choice.call_deferred()


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

	_exec_row = HBoxContainer.new()
	_exec_row.add_theme_constant_override("separation", 14)
	_exec_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_exec_row)

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
	left.add_child(ThemeBuilder.label(runner.meta["title"], 17, Palette.TEXT_DIM))
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
	_rep_lbl = _stat(bar, "商誉")
	_turn_lbl = _stat(bar, "进度")
	var back := Button.new()
	back.text = "返回标题"
	back.pressed.connect(func(): exit_requested.emit())
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
	p.add_child(h)
	h.add_child(ThemeBuilder.label("通关目标", 18, Palette.GOLD, ThemeBuilder.serif(700)))
	_goal_lbl = ThemeBuilder.label("", 18, Palette.TEXT)
	_goal_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_goal_lbl)
	_goal_bar = ProgressBar.new()
	_goal_bar.custom_minimum_size = Vector2(360, 14)
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
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	_compass_holder = Control.new()
	_compass_holder.custom_minimum_size = Vector2(0, 230)
	_compass_holder.clip_contents = true
	v.add_child(_compass_holder)
	_compass = Compass3D.new()
	_compass.base_scale = 0.36
	_compass_holder.add_child(_compass)
	_compass_holder.resized.connect(func(): _compass.position = _compass_holder.size / 2)

	_gauge = FactorGauge.new()
	v.add_child(_gauge)

	_forecast = RichTextLabel.new()
	_forecast.bbcode_enabled = true
	_forecast.fit_content = true
	_forecast.custom_minimum_size = Vector2(0, 66)
	v.add_child(_forecast)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var mkt := HBoxContainer.new()
	v.add_child(mkt)
	mkt.add_child(ThemeBuilder.label("本月营销预算", 18, Palette.TEXT_DIM))
	_mkt_slider = HSlider.new()
	_mkt_slider.min_value = 0
	_mkt_slider.max_value = MAX_MARKETING
	_mkt_slider.step = 10000
	_mkt_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mkt_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mkt_slider.tooltip_text = "营销加成随预算递增，超过 20 万不再增加"
	_mkt_slider.value_changed.connect(func(val): _mkt_lbl.text = Money.short(val) if val > 0 else "不投放")
	mkt.add_child(_mkt_slider)
	_mkt_lbl = ThemeBuilder.label("不投放", 18, Palette.AMBER, ThemeBuilder.mono())
	_mkt_lbl.custom_minimum_size = Vector2(110, 0)
	mkt.add_child(_mkt_lbl)

	var fs := Button.new()
	fs.text = "企业总部风水工位"
	fs.pressed.connect(_open_office)
	Audio.wire_button(fs)
	_fs_btn = fs
	v.add_child(fs)

	_advance_btn = Button.new()
	_advance_btn.text = "推进本月  ▶"
	_advance_btn.custom_minimum_size = Vector2(0, 62)
	_advance_btn.add_theme_font_size_override("font_size", 30)
	_advance_btn.add_theme_stylebox_override("normal", ThemeBuilder.box(Color("#3A2A12"), Palette.AMBER, 2, 8, 14))
	_advance_btn.add_theme_stylebox_override("hover", ThemeBuilder.box(Color("#4A3616"), Palette.AMBER.lightened(0.2), 2, 8, 14))
	_advance_btn.add_theme_color_override("font_color", Palette.AMBER.lightened(0.3))
	_advance_btn.pressed.connect(_on_advance)
	Audio.wire_button(_advance_btn)
	v.add_child(_advance_btn)
	return panel


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


# ─── 刷新 ──────────────────────────────────────────────────────────────────
func _refresh() -> void:
	var c := runner.company
	var clk := runner.clock
	var t := DataTables.engine()
	var season := clk.get_season_key(clk.month)
	_company_lbl.text = c.name
	_date_lbl.text = "%d年%02d月　%s" % [clk.year, clk.month, t["season_names"][str(clk.month)]]
	_era_lbl.text = "%s　·　%s" % [clk.era_name, t["month_names"][clk.month - 1]]
	_season_icon.texture = load("res://assets/icons/season_%s.png" % SEASON_ICON[season])
	_cash_lbl.text = Money.short(c.cash)
	_cash_lbl.add_theme_color_override("font_color", Palette.AMBER if c.cash >= 0 else Palette.CINNABAR)
	_rep_lbl.text = "%d" % c.reputation
	_turn_lbl.text = "%d/%d月" % [mini(runner.turn, runner.duration()), runner.duration()]
	_refresh_goal()

	var f_t: float = clk.calculate_time_factor(c.industry)["value"]
	var active := c.active_stores()
	var f_s := 1.0
	if not active.is_empty():
		var sum := 0.0
		for s in active:
			sum += runner.engine.palaces_sys.calculate_store_space_factor(c.industry, s.palace_id, c.fengshui_modifier)
		f_s = sum / active.size()
	var p := runner.engine.personnel_sys.calculate_personnel_factor(c.executives)
	_gauge.set_values(f_t, f_s, p["value"])
	_chart.set_data(start_cash, c.financial_history, float(runner.meta.get("win_condition", {}).get("min_cash", 0.0)), runner.duration())
	_refresh_execs(p)


func _refresh_goal() -> void:
	var wc: Dictionary = runner.meta.get("win_condition", {})
	var c := runner.company
	var parts := PackedStringArray([runner.meta.get("win_condition_text", "")])
	var ratio := 0.0
	if float(wc.get("min_cash", 0)) > 0:
		ratio = c.cash / float(wc["min_cash"])
		parts.append("当前现金 %s / 目标 %s" % [Money.short(c.cash), Money.short(float(wc["min_cash"]))])
	if wc.has("final_month_profit") and not c.financial_history.is_empty():
		var last := c.financial_history[-1].net_profit
		ratio = last / float(wc["final_month_profit"])
		parts.append("上月净利润 %s / 目标 %s" % [Money.short(last), Money.short(float(wc["final_month_profit"]))])
	if wc.has("max_friction"):
		var fr: float = runner.engine.personnel_sys.calculate_personnel_factor(c.executives)["friction_ratio"]
		parts.append("当前内耗 %d%% / 上限 %d%%" % [roundi(fr * 100), roundi(float(wc["max_friction"]) * 100)])
	_goal_lbl.text = "　".join(parts)
	_goal_bar.value = clampf(ratio, 0.0, 1.0) * 100


func _refresh_execs(p: Dictionary) -> void:
	var c := runner.company
	var ids := {}
	for e in c.executives:
		ids[e.id] = true
	for id in _exec_cards.keys():
		if not ids.has(id):
			_exec_cards[id].queue_free()
			_exec_cards.erase(id)
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
		var color := Palette.TEXT
		if line.begins_with("【天时】"):
			color = Palette.GOLD.lightened(0.2)
		elif line.begins_with("【地利】"):
			color = Palette.ELEMENT["Earth"].lightened(0.35)
		elif line.begins_with("【人和】"):
			color = Palette.JADE.lightened(0.1)
		elif line.begins_with("【决策余波】"):
			color = Color("#8FB3C9")
		elif "⚠" in line or "内耗+" in line:
			color = Palette.AMBER
		elif "降低" in line:
			color = Palette.JADE
		else:
			color = Palette.TEXT_DIM
		out.append("[color=%s]%s[/color]" % [Palette.hex(color), line.strip_edges() if line.begins_with(" ") else line])
	_insight.text = "\n".join(out)


func _render_forecast(text: String, title := "下月预告") -> void:
	var body := text.replace("【下月预告】", "")
	var arrow_color := Palette.TEXT
	if body.ends_with("↑"):
		arrow_color = Palette.JADE
	elif body.ends_with("↓"):
		arrow_color = Palette.CINNABAR
	_forecast.text = "[color=%s][b]%s[/b][/color]\n[color=%s]%s[/color]" % [
		Palette.hex(Palette.GOLD), title, Palette.hex(arrow_color), body]


func _show_turn_preview() -> void:
	var c := runner.company
	_render_forecast(Insight.time_line(runner.clock, c.industry), "本月天时（%d年%02d月）" % [runner.clock.year, runner.clock.month])
	if c.financial_history.is_empty():
		_insight.text = "[color=%s]尚未结算。做出开局决断后，按「推进本月」结算第一个月。\n每月结算后，这里会用天时、地利、人和三方面解释盈亏来源。[/color]" % Palette.hex(Palette.TEXT_DIM)


# ─── 流程 ──────────────────────────────────────────────────────────────────
func _open_main_choice() -> void:
	var d := MainChoiceDialog.new()
	d.meta = runner.meta
	d.chosen.connect(_on_main_chosen)
	add_child(d)


func _on_main_chosen(key: String) -> void:
	var msg := runner.apply_main_choice(key)
	_compass.spin(200.0, 1.0)
	_toast(msg, Palette.GOLD)
	var a := office.audit()
	if a["score"] < 50:
		_toast("总部风水评分仅 %d/100，有 %d 处恶煞（如穿堂煞）拖累全部门店营收。可点「企业总部风水工位」调理。" % [a["score"], a["shas"].size()], Palette.CINNABAR, 7.0)
	_refresh()
	_check_decisions()


func _check_decisions() -> void:
	var pending := runner.pending_decisions()
	if pending.is_empty():
		Audio.play_season(runner.clock.get_season_key(runner.clock.month))
		_advance_btn.disabled = false
		return
	_advance_btn.disabled = true
	Audio.play_music("decision_tension", 1.0)
	var d := DecisionDialog.new()
	d.event = pending[0]
	d.runner = runner
	d.chosen.connect(func(key):
		var before := runner.company.executives.size()
		var res := runner.apply_decision(pending[0]["id"], key)
		_toast(res["message"], Palette.PAPER)
		var after := runner.company.executives.size()
		if after < before:
			Audio.sfx("exec_leave")
		elif after > before:
			Audio.sfx("exec_hire")
		_refresh()
		_check_decisions.call_deferred())
	add_child(d)


func _on_advance() -> void:
	if _busy or runner.is_finished():
		return
	_busy = true
	_advance_btn.disabled = true
	Audio.sfx("month_advance")
	_compass.spin(90.0, 0.8)
	var c := runner.company
	var friction_before: float = runner.engine.personnel_sys.calculate_personnel_factor(c.executives)["friction_ratio"]
	var label := "%d年%02d月" % [runner.clock.year, runner.clock.month]
	var season_before := runner.clock.get_season_key(runner.clock.month)

	var out := runner.simulate_month(_mkt_slider.value, true, rng)
	var st: FinancialStatement = out["statement"]
	last_explain = Insight.explain_month(c, runner.engine)
	last_forecast = Insight.forecast_next_month(runner.clock, c.industry)
	_show_statement(st, label)
	_render_insight(last_explain)
	Audio.sfx("report_print")
	await get_tree().create_timer(0.35).timeout
	Audio.sfx("cash_gain" if st.net_profit >= 0 else "cash_loss")
	if out["event"] != null:
		_show_event(out["event"])
	var friction_after: float = runner.engine.personnel_sys.calculate_personnel_factor(c.executives)["friction_ratio"]
	if friction_after > friction_before:
		Audio.sfx("friction_clash")

	if runner.bankrupt:
		_refresh()
		_finish()
		return
	_render_forecast(last_forecast)
	if last_forecast.ends_with("↑"):
		Audio.sfx("forecast_up", -3.0)
	elif last_forecast.ends_with("↓"):
		Audio.sfx("forecast_down", -3.0)
	runner.advance()
	_mkt_slider.value = 0
	_refresh()
	_busy = false
	if runner.is_finished():
		_finish()
		return
	var season_now := runner.clock.get_season_key(runner.clock.month)
	if season_now != season_before:
		Audio.sfx("season_change")
		_toast("节气更替：入%s，%s" % [Insight.SEASON_CN[season_now] + "季", DataTables.engine()["season_names"][str(runner.clock.month)]], Palette.GOLD)
	_check_decisions()


func _open_office() -> void:
	if _busy or runner.is_finished():
		return
	var o := OfficeScreen.new()
	o.base = office
	o.cash = runner.company.cash
	o.company_modifier = runner.company.fengshui_modifier
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.confirmed.connect(_on_office_confirmed)
	o.closed.connect(func(): Audio.play_season(runner.clock.get_season_key(runner.clock.month)))
	add_child(o)


## 改造生效：扣款，风水修正按布局评分的变化量叠加（保留关卡初始值与随机事件的影响），夹在 -25%～+35%
func _on_office_confirmed(new_layout: OfficeLayout, cost: float) -> void:
	var c := runner.company
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


func _finish() -> void:
	_advance_btn.disabled = true
	Audio.stop_music(0.8)
	if runner.bankrupt:
		Audio.sfx("bankrupt")
		Audio.play_music("sting_bankrupt", 0.2)
	elif runner.check_win():
		Audio.sfx("victory")
		Audio.play_music("sting_victory", 0.2)
	else:
		Audio.play_music("sting_defeat", 0.2)
	var d := EndingDialog.new()
	d.runner = runner
	d.restart.connect(func(): restart_requested.emit())
	d.back_to_title.connect(func(): exit_requested.emit())
	add_child(d)


func _toast(text: String, color: Color, seconds := 4.0) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(Palette.TERMINAL, 0.95), color, 2, 8, 14))
	var l := ThemeBuilder.label(text, 18, Palette.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(490, 0)
	p.add_child(l)
	p.modulate.a = 0.0
	_toast_box.add_child(p)
	while _toast_box.get_child_count() > 2:          # 最多同时显示两条，旧的先撤
		var old := _toast_box.get_child(0)
		_toast_box.remove_child(old)
		old.queue_free()
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(seconds)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
