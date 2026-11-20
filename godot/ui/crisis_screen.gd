extends Control
## 24小时危机公关指挥室：倒计时时钟 + 三阶段时间轴 + 舆情播报 + 应对选项 + 怒火/信任指标 + 在场高管 + 决策日志

signal exit_requested
signal restart_requested

const CrisisGauge := preload("res://ui/widgets/crisis_gauge.gd")
const BriefDialog := preload("res://ui/dialogs/crisis_brief_dialog.gd")
const EndingDialog := preload("res://ui/dialogs/crisis_ending_dialog.gd")
const SystemMenu := preload("res://ui/dialogs/system_menu.gd")
const SettingsDialog := preload("res://ui/dialogs/settings_dialog.gd")
const PORTRAIT := "res://assets/portraits/%s_%s.png"
const GATE_ICON := "res://assets/icons/gate_%s.png"

var crisis_id := CrisisWarRoom.DEFAULT_CRISIS
var room: CrisisWarRoom
var company: Company
var _busy := true                  ## 简报未关闭、动画进行中时不接受操作
var _logged := false
var _shown_hour := 0.0

var _clock: Label
var _stage_lbl: Label
var _cash_lbl: Label
var _rep_lbl: Label
var _timeline: HBoxContainer
var _headline: RichTextLabel
var _options: VBoxContainer
var _anger: Control
var _trust: Control
var _members: VBoxContainer
var _log: RichTextLabel
var _alarm: ColorRect


func _exit_tree() -> void:
	if not _logged and room and not room.is_resolved:
		PlaytestLog.record_crisis(room, company, "quit")


func _ready() -> void:
	room = CrisisWarRoom.create(crisis_id)
	company = CrisisWarRoom.create_company(crisis_id)
	_build()
	_anger.set_value(room.public_anger, false)
	_trust.set_value(room.brand_trust, false)
	_set_clock(0.0)
	_refresh()
	Audio.play_music("crisis_war_room", 1.0)
	var d := BriefDialog.new()
	d.crisis = CrisisWarRoom.definition(crisis_id)
	d.start.connect(_show_stage)
	add_child(d)


# ─── 布局 ──────────────────────────────────────────────────────────────────
func _build() -> void:
	var art := TextureRect.new()
	art.texture = load("res://assets/scenes/war_room.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(0.55, 0.5, 0.5)
	add_child(art)
	var veil := ColorRect.new()
	veil.color = Color(Palette.TERMINAL, 0.88)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	_alarm = ColorRect.new()                       # 怒火逼近封杀线时的红色脉冲
	_alarm.color = Color(Palette.CINNABAR, 0.0)
	_alarm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alarm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_alarm)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	root.add_child(_build_top_bar())
	_timeline = HBoxContainer.new()
	_timeline.add_theme_constant_override("separation", 6)
	root.add_child(_timeline)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_build_left())
	body.add_child(_build_right())


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 24)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(ThemeBuilder.label(company.name, 34, Palette.PAPER, ThemeBuilder.serif(900)))
	left.add_child(ThemeBuilder.label(CrisisWarRoom.definition(crisis_id)["case_title"], 18, Palette.TEXT_DIM))
	bar.add_child(left)

	var mid := VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var clock_row := HBoxContainer.new()
	clock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_row.add_theme_constant_override("separation", 10)
	var live := ThemeBuilder.label("● 距终局还剩", 22, Palette.CINNABAR, ThemeBuilder.serif(700))
	clock_row.add_child(live)
	_clock = ThemeBuilder.label("24:00", 60, Palette.CINNABAR.lightened(0.1), ThemeBuilder.mono())
	clock_row.add_child(_clock)
	clock_row.add_child(ThemeBuilder.label("小时", 22, Palette.TEXT_DIM, ThemeBuilder.serif(700)))
	mid.add_child(clock_row)
	_stage_lbl = ThemeBuilder.label("", 19, Palette.AMBER, ThemeBuilder.serif(700))
	_stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_stage_lbl)
	bar.add_child(mid)

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 26)
	_cash_lbl = _stat(right, "账面现金")
	_rep_lbl = _stat(right, "公司商誉")
	var menu := Button.new()
	menu.text = "菜单 (Esc)"
	menu.custom_minimum_size = Vector2(150, 64)
	menu.pressed.connect(open_system_menu)
	Audio.wire_button(menu)
	right.add_child(menu)
	bar.add_child(right)
	return bar


func _stat(parent: Control, caption: String) -> Label:
	var v := VBoxContainer.new()
	v.add_child(ThemeBuilder.label(caption, 16, Palette.TEXT_DIM))
	var l := ThemeBuilder.label("", 30, Palette.AMBER, ThemeBuilder.mono())
	v.add_child(l)
	parent.add_child(v)
	return l


func _panel(border := Palette.TERMINAL_LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(Palette.TERMINAL_PANEL, 0.94), border, 1, 8, 18))
	return p


func _build_left() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	var news := _panel(Palette.CINNABAR.darkened(0.2))
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 8)
	news.add_child(nv)
	nv.add_child(ThemeBuilder.label("● 舆情播报 LIVE", 20, Palette.CINNABAR, ThemeBuilder.serif(900)))
	_headline = RichTextLabel.new()
	_headline.bbcode_enabled = true
	_headline.fit_content = true
	_headline.scroll_active = false
	_headline.add_theme_font_override("normal_font", ThemeBuilder.serif(700))
	_headline.add_theme_font_size_override("normal_font_size", 26)
	_headline.add_theme_color_override("default_color", Palette.PAPER)
	nv.add_child(_headline)
	v.add_child(news)
	v.add_child(ThemeBuilder.label("董事长，请下达决断（按 1 / 2 / 3）", 22, Palette.GOLD, ThemeBuilder.serif(700)))
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 12)
	v.add_child(_options)
	return v


func _build_right() -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(640, 0)
	v.add_theme_constant_override("separation", 14)
	var gp := _panel()
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 10)
	gp.add_child(gv)
	_anger = CrisisGauge.new()
	_anger.caption = "公众怒火"
	_anger.hint = "越低越好"
	_anger.line = CrisisWarRoom.anger_ban_line()
	_anger.line_label = "封杀线 %d" % CrisisWarRoom.anger_ban_line()
	_anger.danger_above = true
	gv.add_child(_anger)
	_trust = CrisisGauge.new()
	_trust.caption = "品牌信任"
	_trust.hint = "越高越好"
	_trust.line = CrisisWarRoom.trust_death_line()
	_trust.line_label = "社死线 %d" % CrisisWarRoom.trust_death_line()
	_trust.danger_above = false
	gv.add_child(_trust)
	v.add_child(gp)

	var mp := _panel()
	_members = VBoxContainer.new()
	_members.add_theme_constant_override("separation", 10)
	mp.add_child(_members)
	v.add_child(mp)

	var lp := _panel()
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	lv.add_child(ThemeBuilder.label("决策日志", 20, Palette.GOLD, ThemeBuilder.serif(700)))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 17)
	_log.add_theme_color_override("default_color", Palette.TEXT)
	_log.text = "[color=%s]尚未下达任何决断。[/color]" % Palette.hex(Palette.TEXT_DIM)
	lv.add_child(_log)
	v.add_child(lp)
	return v


# ─── 刷新 ──────────────────────────────────────────────────────────────────
func _set_clock(h: float) -> void:
	_shown_hour = h
	var total := roundi((24.0 - h) * 60.0)                  # 显示剩余时间
	_clock.text = "%02d:%02d" % [total / 60, total % 60]


func _refresh() -> void:
	_cash_lbl.text = Money.short(company.cash)
	_rep_lbl.text = str(company.reputation)
	var st := room.current_stage()
	if room.is_resolved:
		_stage_lbl.text = "24小时已过 · 终局裁决" if room.hour >= 24 else "第 %d 小时 · 危机提前终结" % room.hour
	else:
		_stage_lbl.text = st["name"]
	_refresh_timeline()
	_refresh_members()
	var heat := clampf((room.public_anger - 60) / float(CrisisWarRoom.anger_ban_line() - 60), 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_alarm, "color:a", 0.10 * heat, 0.6)


func _refresh_timeline() -> void:
	for c in _timeline.get_children():
		c.queue_free()
	var cur := -1 if room.is_resolved else room.stage_index()
	var failed := room.is_resolved and room.grade() == "fail"
	var start := 0
	for i in room.stages().size():
		var st: Dictionary = room.stages()[i]
		var end := int(st["end_hour"])
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.size_flags_stretch_ratio = end - start
		var active := i == cur
		var done := end <= room.hour
		var broke := failed and end == room.hour          # 在这一阶段失败
		var bg := Color("#3A1A16") if active or broke else (Color("#1A2A22") if done else Palette.TERMINAL_PANEL)
		var border := Palette.CINNABAR if active or broke else (Palette.JADE.darkened(0.3) if done else Palette.TERMINAL_LINE)
		p.add_theme_stylebox_override("panel", ThemeBuilder.box(bg, border, 2 if active or broke else 1, 6, 8))
		var mark := "✗ " if broke else ("✓ " if done else ("▶ " if active else ""))
		var col := Palette.CINNABAR.lightened(0.2) if broke else (Palette.PAPER if active else (Palette.JADE if done else Palette.TEXT_DIM))
		var l := ThemeBuilder.label(mark + st["hours_range"], 18, col, ThemeBuilder.serif(700))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(l)
		_timeline.add_child(p)
		start = end


func _mood() -> String:
	if room.is_resolved:
		return "pleased" if room.grade() == "win" else "angry"
	if room.public_anger >= 75 or room.brand_trust <= 25:
		return "stressed"
	if room.public_anger <= 40 and room.brand_trust >= 55:
		return "pleased"
	return "neutral"


func _refresh_members() -> void:
	for c in _members.get_children():
		c.queue_free()
	_members.add_child(ThemeBuilder.label("指挥室在场高管", 20, Palette.GOLD, ThemeBuilder.serif(700)))
	var gated := {}                                  # 门派 → 需要它的应对
	for st in room.stages():
		for o in st["options"]:
			if o.get("special_gate", "") != "":
				gated[o["special_gate"]] = o["title"].split("】")[0].trim_prefix("【")
	var mood := _mood()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_members.add_child(row)
	var present := {}
	for e in company.executives:
		present[e.gate_id] = true
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 2)
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", ThemeBuilder.box(Palette.PAPER.darkened(0.08),
				Palette.GOLD if gated.has(e.gate_id) else Palette.GOLD.darkened(0.4), 2 if gated.has(e.gate_id) else 1, 6, 0))
		var pic := TextureRect.new()
		var path := PORTRAIT % [e.portrait, mood]
		if not ResourceLoader.exists(path):
			path = PORTRAIT % [e.portrait, "neutral"]
		pic.texture = load(path) if ResourceLoader.exists(path) else null
		pic.custom_minimum_size = Vector2(0, 120)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(pic)
		card.add_child(frame)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		var gi := TextureRect.new()
		var gp := GATE_ICON % e.gate_id
		gi.texture = load(gp) if ResourceLoader.exists(gp) else null
		gi.custom_minimum_size = Vector2(24, 24)
		gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(gi)
		head.add_child(ThemeBuilder.label(e.name, 21, Palette.PAPER, ThemeBuilder.serif(700)))
		card.add_child(head)
		card.add_child(ThemeBuilder.label("%s · %s" % [RoleNames.cn(e.role), e.gate_name], 15, Palette.TEXT_DIM))
		if gated.has(e.gate_id):
			card.add_child(ThemeBuilder.label("可主持：" + gated[e.gate_id], 15, Palette.GOLD))
		row.add_child(card)
	for g in gated:
		if not present.has(g):
			var l := ThemeBuilder.label("无%s高管在场：【%s】效果减半" % [_gate_name(g), gated[g]], 16, Palette.CINNABAR.lightened(0.1))
			_members.add_child(l)


static func _gate_name(id: String) -> String:
	for g in DataTables.load_json("eight_gates.json")["gates"]:
		if g["id"] == id:
			return g["name"]
	return id


# ─── 流程 ──────────────────────────────────────────────────────────────────
func _show_stage() -> void:
	var st := room.current_stage()
	if st.is_empty():
		return
	_refresh()
	Audio.sfx("event_crisis")
	_headline.text = st["event_headline"]
	_headline.visible_ratio = 0.0
	create_tween().tween_property(_headline, "visible_ratio", 1.0, 0.9)
	for c in _options.get_children():
		c.queue_free()
	var i := 0
	for o in st["options"]:
		i += 1
		var b := _option_button(o, i)
		b.modulate.a = 0.0
		_options.add_child(b)
		var tw := create_tween()
		tw.tween_interval(0.5 + 0.12 * i)
		tw.tween_property(b, "modulate:a", 1.0, 0.25)
	await get_tree().create_timer(0.6).timeout
	_busy = false


func _option_button(o: Dictionary, n: int) -> Button:
	var b := Button.new()
	b.set_meta("hotkey", str(n))
	b.custom_minimum_size = Vector2(0, 128)
	b.add_theme_stylebox_override("normal", ThemeBuilder.box(Color("#161B23"), Palette.TERMINAL_LINE, 1, 8, 0))
	b.add_theme_stylebox_override("hover", ThemeBuilder.box(Color("#221E1A"), Palette.AMBER, 2, 8, 0))
	b.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color("#2A1E14"), Palette.AMBER, 2, 8, 0))
	b.add_theme_stylebox_override("focus", ThemeBuilder.box(Color.TRANSPARENT, Palette.AMBER, 2, 8, 0))
	b.add_theme_stylebox_override("disabled", ThemeBuilder.box(Color("#12161C"), Palette.TERMINAL_LINE, 1, 8, 0))
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(ThemeBuilder.label(str(n), 26, Palette.AMBER, ThemeBuilder.mono()))
	var t := ThemeBuilder.label(o["title"], 22, Palette.PAPER, ThemeBuilder.serif(700))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var desc := ThemeBuilder.label(o["description"], 17, Palette.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)

	var d := CrisisWarRoom.effective_deltas(o, company)
	var stats := RichTextLabel.new()
	stats.bbcode_enabled = true
	stats.fit_content = true
	stats.scroll_active = false
	stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_font_size_override("normal_font_size", 18)
	var good_a := Palette.hex(Palette.JADE if d[0] < 0 else Palette.CINNABAR)
	var good_t := Palette.hex(Palette.JADE if d[1] > 0 else Palette.CINNABAR)
	var txt := "[color=%s]耗资 %s[/color]　　[color=%s]怒火 %s[/color]　　[color=%s]信任 %s[/color]" % [
		Palette.hex(Palette.AMBER), Money.short(float(o["cost"])), good_a, _signed(d[0]), good_t, _signed(d[1])]
	var gate: String = o.get("special_gate", "")
	if gate != "":
		if CrisisWarRoom.has_required_gate(o, company):
			var who := ""
			for e in company.executives:
				if e.gate_id == gate:
					who = e.name
			txt += "　　[color=%s]%s坐镇 · 全额生效[/color]" % [Palette.hex(Palette.GOLD), who]
		else:
			txt += "　　[color=%s]缺少专属高管 · 效果减半[/color]" % Palette.hex(Palette.CINNABAR)
	stats.text = txt
	v.add_child(stats)
	b.pressed.connect(_on_choose.bind(o, b))
	Audio.wire_button(b)
	return b


static func _signed(x: int) -> String:
	return ("+%d" % x) if x >= 0 else str(x)


func _on_choose(o: Dictionary, b: Button) -> void:
	if _busy or room.is_resolved:
		return
	_busy = true
	for c in _options.get_children():
		if c is Button:
			c.disabled = c != b
	b.add_theme_stylebox_override("disabled", ThemeBuilder.box(Color("#2A1E14"), Palette.AMBER, 2, 8, 0))
	b.disabled = true
	var st := room.current_stage()
	var before_anger := room.public_anger
	var d := CrisisWarRoom.effective_deltas(o, company)
	room.execute_choice(o["id"], company)
	Audio.sfx("ui_confirm")
	await get_tree().create_timer(0.25).timeout
	Audio.sfx("cash_loss", -4.0)
	_anger.set_value(room.public_anger)
	_trust.set_value(room.brand_trust)
	Audio.sfx("forecast_up" if room.public_anger < before_anger else "forecast_down", -2.0)
	_append_log(st, o, d)
	_cash_lbl.text = Money.short(company.cash)
	_rep_lbl.text = str(company.reputation)
	await get_tree().create_timer(0.9).timeout

	Audio.sfx("month_advance")                       # 时钟快进到本阶段结束
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_clock, _shown_hour, float(room.hour), 1.1)
	await tw.finished
	if room.is_resolved:
		_finish()
	else:
		_show_stage()


func _append_log(st: Dictionary, o: Dictionary, d: Array[int]) -> void:
	if room.choices.size() == 1:
		_log.text = ""
	var note := "" if CrisisWarRoom.has_required_gate(o, company) else "（效果减半）"
	_log.append_text("[color=%s]%s[/color]　%s%s\n　[color=%s]怒火 %s → %d[/color]　[color=%s]信任 %s → %d[/color]　[color=%s]耗资 %s[/color]\n" % [
		Palette.hex(Palette.AMBER), st["hours_range"].split(" (")[0], o["title"].split("】")[0] + "】", note,
		Palette.hex(Palette.JADE if d[0] < 0 else Palette.CINNABAR), _signed(d[0]), room.public_anger,
		Palette.hex(Palette.JADE if d[1] > 0 else Palette.CINNABAR), _signed(d[1]), room.brand_trust,
		Palette.hex(Palette.TEXT_DIM), Money.short(float(o["cost"]))])


func _finish() -> void:
	_logged = true
	var grade := room.grade()
	PlaytestLog.record_crisis(room, company, grade)
	_refresh()
	for c in _options.get_children():
		c.queue_free()
	_headline.text = room.verdict
	Audio.stop_music(0.6)
	match grade:
		"win":
			Audio.sfx("victory")
			Audio.play_music("sting_victory", 0.2)
		"pass":
			Audio.play_music("sting_defeat", 0.2)
		_:
			Audio.sfx("bankrupt")
			Audio.play_music("sting_bankrupt", 0.2)
	await get_tree().create_timer(1.2).timeout
	var d := EndingDialog.new()
	d.room = room
	d.company = company
	d.restart.connect(func(): restart_requested.emit())
	d.back_to_title.connect(func(): exit_requested.emit())
	add_child(d)


# ─── 系统菜单与快捷键 ──────────────────────────────────────────────────────
func _has_overlay() -> bool:
	for c in get_children():
		if c.is_in_group("overlay") and not c.is_queued_for_deletion():
			return true
	return false


func open_system_menu() -> void:
	var m := SystemMenu.new()
	m.allow_save = false
	m.settings_requested.connect(func(): add_child(SettingsDialog.new()))
	m.title_requested.connect(func(): exit_requested.emit())
	add_child(m)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or _has_overlay():
		return
	if event.keycode == KEY_ESCAPE:
		open_system_menu()
		get_viewport().set_input_as_handled()
		return
	var ch := String.chr(event.unicode) if event.unicode > 0 else ""
	for b in _options.get_children():
		if b is Button and b.get_meta("hotkey", "") == ch and not b.disabled:
			b.pressed.emit()
			get_viewport().set_input_as_handled()
			return
