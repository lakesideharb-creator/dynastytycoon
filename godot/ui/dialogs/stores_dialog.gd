extends "res://ui/dialogs/modal.gd"
## 门店经营一览：按本月天时·地利·人和估算各店月利润，可关店回收残值（再点一次确认）

signal closed_store(msg: String)

var game: SandboxGame
var _list: VBoxContainer
var _msg: Label
var _armed := ""


func _ready() -> void:
	esc_closes = true
	card.custom_minimum_size = Vector2(1400, 0)
	var head := HBoxContainer.new()
	body.add_child(head)
	head.add_child(ink_label("门店经营一览", 32, INK_TEXT, 900, false))
	var note := sans_label("　预估按本月天时、地利、人和计算，不含高管薪酬与行政杂项。门店每月老化 %.1f%%，最低保留 %d%% 营收。" % [
		float(SandboxGame.econ()["store_decay_rate"]) * 100, roundi(Store.DECAY_FLOOR * 100)], 17, Color(INK_TEXT, 0.65))
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(note)
	var close_btn := option_button("", "关闭 (Esc)")
	close_btn.custom_minimum_size = Vector2(160, 48)
	close_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1340, clampf(game.company.active_stores().size() * 62 + 90, 200, 600))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_msg = sans_label("", 19, Palette.JADE.darkened(0.35), 700)
	body.add_child(_msg)
	_build()
	super._ready()


func _cell(text: String, w: float, size := 19, color := INK_TEXT, weight := 400) -> Label:
	var l := sans_label(text, size, color, weight)
	l.custom_minimum_size = Vector2(w, 0)
	return l


func _build() -> void:
	for c in _list.get_children():
		c.queue_free()
	var head := HBoxContainer.new()
	_list.add_child(head)
	for h in [["门店", 300], ["宫位", 160], ["营业", 110], ["老化", 110], ["月基础营收", 170], ["预估月利润", 180], ["关店残值", 160]]:
		head.add_child(_cell(h[0], h[1], 17, Color(INK_TEXT, 0.55), 700))
	var active := game.company.active_stores()
	var total := 0.0
	for s in active:
		var est := game.estimate_store_profit(s)
		total += est
		var row := HBoxContainer.new()
		_list.add_child(row)
		var decay := (1.0 - s.effective_base_revenue() / s.base_revenue) * 100.0 if s.base_revenue > 0 else 0.0
		row.add_child(_cell(s.name, 300, 19, INK_TEXT, 700))
		row.add_child(_cell(SandboxGame.palace_label(s.palace_id).split("·")[0], 160))
		row.add_child(_cell("%d 个月" % s.age_months, 110))
		row.add_child(_cell("-%d%%" % roundi(decay), 110, 19, Palette.CINNABAR.darkened(0.1) if decay >= 30 else INK_TEXT))
		row.add_child(_cell(Money.short(s.effective_base_revenue()), 170))
		row.add_child(_cell(Money.short(est), 180, 20, Palette.JADE.darkened(0.35) if est >= 0 else Palette.CINNABAR, 700))
		row.add_child(_cell(Money.short(game.salvage_value(s)), 160))
		var b := option_button("", "确认关店？" if _armed == s.id else "关店止损")
		b.custom_minimum_size = Vector2(150, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.disabled = active.size() <= 1
		if active.size() <= 1:
			b.tooltip_text = "最后一家营业网点无法关闭"
		b.pressed.connect(_on_close.bind(s.id))
		row.add_child(b)
	var closed := game.company.stores.size() - active.size()
	_list.add_child(sans_label("营业中 %d 家%s　·　本月预估合计 %s" % [active.size(), ("（已关闭 %d 家）" % closed) if closed > 0 else "", Money.short(total)],
			20, Palette.JADE.darkened(0.35) if total >= 0 else Palette.CINNABAR, 700))


func _on_close(store_id: String) -> void:
	if _armed != store_id:
		_armed = store_id
		_build()
		return
	_armed = ""
	var res := game.close_store(store_id)
	if res["ok"]:
		Audio.sfx("store_close")
		closed_store.emit(res["msg"])
	else:
		Audio.sfx("ui_error")
	_msg.text = res["msg"]
	_build()
