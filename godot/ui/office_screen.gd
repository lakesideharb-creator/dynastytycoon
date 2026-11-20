extends Control
## 企业总部风水工位：在草稿布局上购置/移动/移除物件，实时看到评分变化，确认后才扣款生效。
## 费用 = 草稿相对已生效布局的差异：新增物件按目录价，移动过的工位按岗位搬迁费，移除不退款。

signal confirmed(new_layout: OfficeLayout, cost: float)
signal closed

const IsoView := preload("res://ui/widgets/iso_office_view.gd")

var base: OfficeLayout          ## 已生效的布局（不修改）
var cash := 0.0                 ## 当前账面现金，用于判断能否负担
var company_modifier := 0.0     ## 公司当前风水修正（关卡初始值 + 历次改造 + 随机事件）
var draft: OfficeLayout
var mode := "idle"              ## idle / place / move
var place_catalog: Dictionary = {}
var _view: Control
var _score_lbl: RichTextLabel
var _cost_lbl: Label
var _hint: Label
var _catalog_box: VBoxContainer
var _sel_box: VBoxContainer
var _audit: RichTextLabel
var _confirm: Button
var _discard: Button


func _ready() -> void:
	add_to_group("overlay")
	draft = base.copy()
	var bg := ColorRect.new()
	bg.color = Palette.TERMINAL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var head := HBoxContainer.new()
	left.add_child(head)
	head.add_child(ThemeBuilder.label("企业总部风水工位", 32, Palette.PAPER, ThemeBuilder.serif(900)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var toggle := CheckButton.new()
	toggle.text = "显示九宫"
	toggle.button_pressed = true
	toggle.toggled.connect(func(on): _view.show_palaces = on)
	head.add_child(toggle)
	_view = IsoView.new()
	_view.layout = draft
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.cell_clicked.connect(_on_cell)
	_view.cancelled.connect(_cancel_mode)
	left.add_child(_view)
	_hint = ThemeBuilder.label("", 19, Palette.AMBER)
	left.add_child(_hint)

	row.add_child(_build_side())
	_refresh()
	Audio.play_music("fengshui_studio")
	if base.check_through_draft()["draft"]:
		Audio.sfx("sha_detected")


func _build_side() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	_score_lbl = RichTextLabel.new()
	_score_lbl.bbcode_enabled = true
	_score_lbl.fit_content = true
	_score_lbl.add_theme_font_override("normal_font", ThemeBuilder.serif(700))
	_score_lbl.add_theme_font_size_override("normal_font_size", 24)
	v.add_child(_score_lbl)
	_cost_lbl = ThemeBuilder.label("", 19, Palette.TEXT)
	v.add_child(_cost_lbl)

	v.add_child(ThemeBuilder.label("购置", 20, Palette.GOLD, ThemeBuilder.serif(700)))
	_catalog_box = VBoxContainer.new()
	_catalog_box.add_theme_constant_override("separation", 6)
	v.add_child(_catalog_box)
	for c in OfficeLayout.data()["catalog"]:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = c["desc"]
		b.set_meta("catalog", c)
		b.pressed.connect(_start_place.bind(c))
		Audio.wire_button(b)
		_catalog_box.add_child(b)

	_sel_box = VBoxContainer.new()
	_sel_box.add_theme_constant_override("separation", 6)
	v.add_child(_sel_box)

	v.add_child(ThemeBuilder.label("风水审计", 20, Palette.GOLD, ThemeBuilder.serif(700)))
	_audit = RichTextLabel.new()
	_audit.bbcode_enabled = true
	_audit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_audit.add_theme_font_size_override("normal_font_size", 17)
	v.add_child(_audit)

	var btns := HBoxContainer.new()
	v.add_child(btns)
	_confirm = Button.new()
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.custom_minimum_size = Vector2(0, 56)
	_confirm.add_theme_stylebox_override("normal", ThemeBuilder.box(Color("#3A2A12"), Palette.AMBER, 2, 8, 12))
	_confirm.add_theme_color_override("font_color", Palette.AMBER.lightened(0.3))
	_confirm.pressed.connect(_on_confirm)
	Audio.wire_button(_confirm)
	btns.add_child(_confirm)
	_discard = Button.new()
	_discard.custom_minimum_size = Vector2(170, 56)
	_discard.pressed.connect(_on_discard)
	Audio.wire_button(_discard)
	btns.add_child(_discard)
	return panel


# ─── 费用与刷新 ────────────────────────────────────────────────────────────
func _catalog_of(it: OfficeItem) -> Dictionary:
	for c in OfficeLayout.data()["catalog"]:
		if it.id == c["id"] or it.id.begins_with(c["id"] + "_"):
			return c
	return {}


func draft_cost() -> float:
	var total := 0.0
	var move_cost: Dictionary = OfficeLayout.data()["desk_move_cost"]
	for it: OfficeItem in draft.items.values():
		var orig: OfficeItem = base.items.get(it.id)
		if orig == null:
			total += float(_catalog_of(it).get("cost", 0))
		elif it.category == "desk" and (orig.x != it.x or orig.y != it.y):
			total += float(move_cost.get(it.role, 30000))
	return total


func has_changes() -> bool:
	if draft.items.size() != base.items.size():
		return true
	for it: OfficeItem in draft.items.values():
		var orig: OfficeItem = base.items.get(it.id)
		if orig == null or orig.x != it.x or orig.y != it.y:
			return true
	return false


func _refresh() -> void:
	var a0 := base.audit()
	var a1 := draft.audit()
	var col := Palette.JADE if a1["score"] > a0["score"] else (Palette.CINNABAR if a1["score"] < a0["score"] else Palette.TEXT)
	var projected := OfficeLayout.apply_to_company(company_modifier, base, draft)
	_score_lbl.text = "风水评分 [color=%s]%d[/color] → [color=%s][b]%d[/b][/color]\n[font_size=19]公司风水修正（作用于全部门店营收） %+.1f%% → [color=%s]%+.1f%%[/color][/font_size]" % [
		Palette.hex(Palette.TEXT_DIM), a0["score"], Palette.hex(col), a1["score"],
		company_modifier * 100, Palette.hex(col), projected * 100]
	var cost := draft_cost()
	_cost_lbl.text = "本次改造费用 %s　·　账面现金 %s" % [Money.short(cost), Money.short(cash)]
	_cost_lbl.add_theme_color_override("font_color", Palette.CINNABAR if cost > cash else Palette.TEXT)

	for b: Button in _catalog_box.get_children():
		var c: Dictionary = b.get_meta("catalog")
		var owned: bool = c.get("unique", false) and draft.items.has(c["id"])
		b.text = "  %s　%s%s" % [c["name"], Money.short(float(c["cost"])), "　（已摆放）" if owned else ""]
		b.disabled = owned or cost + float(c["cost"]) > cash

	var lines := PackedStringArray()
	for p in a1["perks"]:
		lines.append("[color=%s]✓ %s[/color]" % [Palette.hex(Palette.JADE), p])
	for s in a1["shas"]:
		lines.append("[color=%s]✗ %s[/color]" % [Palette.hex(Palette.CINNABAR), s])
	for r in a1["recs"]:
		lines.append("[color=%s]» %s[/color]" % [Palette.hex(Palette.GOLD), r])
	_audit.text = "\n".join(lines)

	var changed := has_changes()
	_confirm.text = ("确认改造（%s）" % Money.short(cost)) if changed else "无改动"
	_confirm.disabled = not changed or cost > cash
	_discard.text = "放弃改动" if changed else "返回"
	_refresh_selection()
	_refresh_hint()


func _refresh_selection() -> void:
	for c in _sel_box.get_children():
		c.queue_free()
	var it: OfficeItem = draft.items.get(_view.selected_id)
	if it == null:
		return
	var pname := OfficeLayout.palace_name(draft.palace_at(it.x, it.y))
	_sel_box.add_child(ThemeBuilder.label("已选中：%s　·　%s" % [it.name, pname], 19, Palette.AMBER))
	var h := HBoxContainer.new()
	_sel_box.add_child(h)
	var mv := Button.new()
	if it.category == "desk":
		var orig: OfficeItem = base.items.get(it.id)
		var fee := float(OfficeLayout.data()["desk_move_cost"].get(it.role, 30000))
		var already_moved: bool = orig != null and (orig.x != it.x or orig.y != it.y)
		mv.text = "移动工位（搬迁费 %s）" % Money.short(fee) if not already_moved else "再次移动（不另收费）"
	else:
		mv.text = "移动"
	mv.pressed.connect(func(): _start_move(it))
	Audio.wire_button(mv)
	h.add_child(mv)
	if it.category != "desk":
		var rm := Button.new()
		rm.text = "移除"
		rm.tooltip_text = "移除已生效的物件不退款"
		rm.pressed.connect(func():
			draft.remove_item(it.id)
			_view.selected_id = ""
			_refresh())
		Audio.wire_button(rm)
		h.add_child(rm)


func _refresh_hint() -> void:
	match mode:
		"place":
			_hint.text = "点击空格放置【%s】　·　右键取消" % place_catalog["name"]
		"move":
			_hint.text = "点击空格把【%s】移过去　·　右键取消" % draft.items[_view.selected_id].name
		_:
			_hint.text = "点击家具选中；从右侧购置屏风、招财树或风水法器。门、窗所在格不能摆放。"


# ─── 操作 ──────────────────────────────────────────────────────────────────
func _start_place(c: Dictionary) -> void:
	mode = "place"
	place_catalog = c
	_view.selected_id = ""
	_view.ghost_sprite = c["sprite"]
	_view.ghost_ignore_id = ""
	_refresh()


func _start_move(it: OfficeItem) -> void:
	mode = "move"
	_view.ghost_sprite = _view.sprite_for(it)
	_view.ghost_ignore_id = it.id
	_refresh_hint()


func _cancel_mode() -> void:
	mode = "idle"
	_view.ghost_sprite = ""
	_view.ghost_ignore_id = ""
	_refresh()


func _new_id(c: Dictionary) -> String:
	if c.get("unique", false):
		return c["id"]
	var n := 1
	while draft.items.has("%s_%d" % [c["id"], n]) or base.items.has("%s_%d" % [c["id"], n]):
		n += 1
	return "%s_%d" % [c["id"], n]


func _on_cell(cell: Vector2i) -> void:
	var before_draft: bool = draft.check_through_draft()["draft"]
	match mode:
		"place":
			if not draft.can_place(cell):
				Audio.sfx("ui_error")
				return
			var c := place_catalog
			draft.add_item(OfficeItem.from_dict({"id": _new_id(c), "name": c["name"], "category": c["category"],
					"x": cell.x, "y": cell.y, "facing": "N"}))
			Audio.sfx(c.get("sfx", "place_furniture"))
			_cancel_mode()
		"move":
			var it: OfficeItem = draft.items[_view.selected_id]
			if not draft.can_place(cell, it.id):
				Audio.sfx("ui_error")
				return
			it.x = cell.x
			it.y = cell.y
			Audio.sfx("place_furniture")
			_cancel_mode()
		_:
			var it := draft.item_at(cell.x, cell.y)
			_view.selected_id = it.id if it else ""
			_refresh()
	if before_draft and not draft.check_through_draft()["draft"]:
		Audio.sfx("sha_resolved")


func _on_confirm() -> void:
	var gained: bool = draft.audit()["score"] > base.audit()["score"]
	if gained:
		Audio.sfx("fengshui_score_up")
	confirmed.emit(draft, draft_cost())
	_close()


func _on_discard() -> void:
	_close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if mode != "idle":
			_cancel_mode()
		else:
			_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	closed.emit()
	queue_free()
