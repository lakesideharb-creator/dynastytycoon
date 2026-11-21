extends "res://ui/dialogs/modal.gd"
## 人才市场：本季度 8 位候选人；选人 → 指派岗位 → 开价，雇佣前预览人和系数与内耗的变化

signal hired(msg: String)

const PORTRAIT := "res://assets/portraits/%s.png"
const GATE_ICON := "res://assets/icons/gate_%s.png"
const STD_ROLES := ["CEO", "CFO", "CMO", "CTO", "COO"]

var game: SandboxGame
var months_to_refresh := 3
var _sel := -1
var _role := ""
var _grid: GridContainer
var _detail: VBoxContainer
var _roles_box: HBoxContainer
var _salary: HSlider
var _salary_lbl: Label
var _preview: RichTextLabel
var _hire_btn: Button
var _msg: Label


func _ready() -> void:
	esc_closes = true
	card.custom_minimum_size = Vector2(1620, 0)
	var head := HBoxContainer.new()
	body.add_child(head)
	head.add_child(ink_label("人才市场 · 第 %d 季度" % game.talent_pool.quarter, 32, INK_TEXT, 900, false))
	var note := sans_label("　每季度刷新一次，下次刷新在 %d 个月后。按岗位与门派相配延揽，人和系数越高，全部门店营收越高。" % months_to_refresh, 17, Color(INK_TEXT, 0.65))
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(note)
	var close_btn := option_button("", "关闭 (Esc)")
	close_btn.custom_minimum_size = Vector2(160, 48)
	close_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	body.add_child(_grid)

	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 10)
	body.add_child(_detail)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	_detail.add_child(row1)
	row1.add_child(ink_label("指派岗位", 20, INK_TEXT, 700, false))
	_roles_box = HBoxContainer.new()
	_roles_box.add_theme_constant_override("separation", 8)
	row1.add_child(_roles_box)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	_detail.add_child(row2)
	row2.add_child(ink_label("开出月薪", 20, INK_TEXT, 700, false))
	_salary = HSlider.new()
	_salary.custom_minimum_size = Vector2(520, 0)
	_salary.step = 1000
	_salary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_salary.value_changed.connect(func(_v): _refresh_detail())
	row2.add_child(_salary)
	_salary_lbl = sans_label("", 22, Palette.CINNABAR.darkened(0.2), 700)
	_salary_lbl.custom_minimum_size = Vector2(150, 0)
	row2.add_child(_salary_lbl)
	_hire_btn = option_button("", "延揽入阁")
	_hire_btn.custom_minimum_size = Vector2(220, 52)
	_hire_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hire_btn.pressed.connect(_on_hire)
	row2.add_child(_hire_btn)
	_preview = RichTextLabel.new()
	_preview.bbcode_enabled = true
	_preview.fit_content = true
	_preview.custom_minimum_size = Vector2(1560, 0)
	_preview.add_theme_font_override("normal_font", ThemeBuilder.serif(400))
	_preview.add_theme_font_size_override("normal_font_size", 19)
	_preview.add_theme_color_override("default_color", INK_TEXT)
	_detail.add_child(_preview)
	_msg = sans_label("", 19, Palette.CINNABAR, 700)
	body.add_child(_msg)
	_build_grid()
	super._ready()


func _build_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var pool := game.talent_pool.available
	if pool.is_empty():
		_grid.add_child(ink_label("本季度的候选人都已被延揽，等下个季度刷新。", 20, Color(INK_TEXT, 0.7)))
	for i in pool.size():
		_grid.add_child(_card(pool[i], i))
	_sel = -1
	_detail.visible = false


func _card(c: Dictionary, i: int) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(388, 176)
	b.add_theme_stylebox_override("normal", ThemeBuilder.box(Palette.PAPER.darkened(0.04), Palette.GOLD.darkened(0.2), 1, 8, 0))
	b.add_theme_stylebox_override("hover", ThemeBuilder.box(Palette.PAPER.lightened(0.25), Palette.CINNABAR, 2, 8, 0))
	b.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color("#F6E7C8"), Palette.CINNABAR, 3, 8, 0))
	b.add_theme_stylebox_override("hover_pressed", ThemeBuilder.box(Color("#F6E7C8"), Palette.CINNABAR, 3, 8, 0))
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	m.add_child(h)
	var pic := TextureRect.new()
	var path := PORTRAIT % c.get("portrait", "")
	pic.texture = load(path) if ResourceLoader.exists(path) else null
	pic.custom_minimum_size = Vector2(118, 150)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nh := HBoxContainer.new()
	nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nh.add_theme_constant_override("separation", 6)
	v.add_child(nh)
	var gi := TextureRect.new()
	var gp := GATE_ICON % c["gate"]
	gi.texture = load(gp) if ResourceLoader.exists(gp) else null
	gi.custom_minimum_size = Vector2(28, 28)
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nh.add_child(gi)
	nh.add_child(ink_label(c["name"], 24, INK_TEXT, 900, false))
	nh.add_child(ink_label(c["gate_name"], 18, Palette.CINNABAR.darkened(0.1), 700, false))
	v.add_child(sans_label("可任：" + " / ".join(Array(c["eligible_roles"]).map(func(r): return RoleNames.cn(r))), 16, Color(INK_TEXT, 0.8)))
	v.add_child(sans_label("特质：" + "·".join(PackedStringArray(c["traits"])), 16, Color(INK_TEXT, 0.65)))
	v.add_child(sans_label("要价 %s/月" % Money.short(float(c["asking_salary"])), 19, INK_TEXT, 700))
	v.add_child(sans_label("底线 %s/月" % Money.short(float(c["min_salary"])), 15, Color(INK_TEXT, 0.55)))
	b.pressed.connect(_select.bind(i))
	Audio.wire_button(b)
	return b


func _select(i: int) -> void:
	_sel = i
	for k in _grid.get_child_count():
		var b := _grid.get_child(k)
		if b is Button:
			b.set_pressed_no_signal(k == i)
	var c: Dictionary = game.talent_pool.available[i]
	for r in _roles_box.get_children():
		r.queue_free()
	var roles: Array = Array(c["eligible_roles"]).duplicate()
	for r in STD_ROLES:
		if r not in roles:
			roles.append(r)
	_role = roles[0]
	for r in roles:
		var rb := option_button("", RoleNames.cn(r))
		rb.toggle_mode = true
		rb.autowrap_mode = TextServer.AUTOWRAP_OFF
		rb.custom_minimum_size = Vector2(150, 44)
		rb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		rb.set_meta("role", r)
		rb.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color("#F6E7C8"), Palette.CINNABAR, 2, 6, 10))
		var syn := game.engine.personnel_sys.synergy(r, c["gate"])
		rb.tooltip_text = "%s × %s 适岗 %.2f" % [RoleNames.cn(r), c["gate_name"], syn]
		if syn >= 1.3:
			rb.text += " ★"
		rb.pressed.connect(func():
			_role = r
			_refresh_roles()
			_refresh_detail())
		_roles_box.add_child(rb)
	_salary.min_value = floorf(float(c["min_salary"]) * 0.85 / 1000.0) * 1000.0
	_salary.max_value = ceilf(float(c["asking_salary"]) * 1.3 / 1000.0) * 1000.0
	_salary.value = float(c["asking_salary"])
	_detail.visible = true
	_msg.text = ""
	_refresh_roles()
	_refresh_detail()


func _refresh_roles() -> void:
	for rb in _roles_box.get_children():
		if rb is Button:
			rb.set_pressed_no_signal(rb.get_meta("role") == _role)


func _refresh_detail() -> void:
	if _sel < 0:
		return
	var c: Dictionary = game.talent_pool.available[_sel]
	var salary := int(_salary.value)
	_salary_lbl.text = Money.short(salary) + "/月"
	var ps := game.engine.personnel_sys
	var before := ps.calculate_personnel_factor(game.company.executives)
	var team: Array[Executive] = game.company.executives.duplicate()
	team.append(TalentPool.to_executive(c, _role, salary))
	var after := ps.calculate_personnel_factor(team)
	var syn := ps.synergy(_role, c["gate"])
	var lines := PackedStringArray()
	var up := float(after["value"]) >= float(before["value"])
	lines.append("[b]%s 任 %s[/b]　适岗 [b]%.2f[/b]%s　　人和 ×%.2f → [color=%s][b]×%.2f[/b][/color]　　内耗 %d%% → %d%%" % [
		c["name"], RoleNames.cn(_role), syn, "（相配）" if syn >= 1.3 else ("（不太相配）" if syn < 1.0 else ""),
		float(before["value"]), Palette.hex(Palette.JADE.darkened(0.3) if up else Palette.CINNABAR), float(after["value"]),
		roundi(float(before["friction_ratio"]) * 100), roundi(float(after["friction_ratio"]) * 100)])
	var clash: Array = after["clash_log"]
	if clash.size() > Array(before["clash_log"]).size():
		lines.append("[color=%s]⚠ %s[/color]" % [Palette.hex(Palette.CINNABAR), clash[-1].strip_edges()])
	for e in game.company.executives:
		if e.role == _role:
			lines.append("[color=%s]⚠ 已有%s %s，岗位重叠[/color]" % [Palette.hex(Palette.AMBER.darkened(0.3)), RoleNames.cn(_role), e.name])
	var cap := game.company.cash * float(SandboxGame.econ()["hire_salary_cash_cap"])
	var notes := PackedStringArray(["每月薪酬支出 +%s" % Money.short(salary)])
	if salary < int(c["min_salary"]):
		notes.append("[color=%s]低于底线 %s，会被拒绝[/color]" % [Palette.hex(Palette.CINNABAR), Money.short(float(c["min_salary"]))])
	if salary > cap:
		notes.append("[color=%s]超过现金的 10%%（%s），风险过高无法开价[/color]" % [Palette.hex(Palette.CINNABAR), Money.short(cap)])
	lines.append("　".join(notes))
	_preview.text = "\n".join(lines)
	_hire_btn.disabled = salary > cap


func _on_hire() -> void:
	if _sel < 0:
		return
	var res := game.hire_talent(_sel, _role, int(_salary.value))
	if res["ok"]:
		Audio.sfx("exec_hire")
		hired.emit(res["msg"])
		_build_grid()
		_msg.add_theme_color_override("font_color", Palette.JADE.darkened(0.35))
	else:
		Audio.sfx("ui_error")
		_msg.add_theme_color_override("font_color", Palette.CINNABAR)
	_msg.text = res["msg"]
