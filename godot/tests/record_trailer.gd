extends Node
## 宣传片素材录制：用 Godot Movie Maker 录下真实游戏画面，并打印各片段的起止时间（MARK）
## 用法：godot --path godot --resolution 1920x1080 --fixed-fps 30 --write-movie <输出.avi> res://tests/record_trailer.tscn

const PICKS := {"s1_summer": "A", "s1_rival": "B", "s1_winter": "B"}
const HARMONIOUS := [            # 风水改造步骤：把恶煞布局一步步调成和谐布局
	["place", "screen", Vector2i(4, 5)], ["place", "plant", Vector2i(4, 4)],
	["move", "p_desk", Vector2i(1, 0)], ["move", "f_desk", Vector2i(4, 1)],
	["move", "cto_desk", Vector2i(7, 4)], ["place", "pixiu", Vector2i(2, 0)],
	["place", "wenchang", Vector2i(8, 4)], ["place", "fishtank", Vector2i(7, 7)],
]

var main: Control
var t := 0.0


func _process(delta: float) -> void:
	t += delta


func _ready() -> void:
	Settings.autosave = false
	PlaytestLog.enabled = false
	AudioServer.set_bus_mute(0, true)
	main = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _mark(name: String) -> void:
	print("MARK %s %.2f" % [name, t])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _dialog(cs: Node, script_path: String) -> Node:
	for c in cs.get_children():
		if c.get_script() and c.get_script().resource_path == script_path and not c.is_queued_for_deletion():
			return c
	return null


## 先把要选的选项高亮一下（像鼠标悬停），再选
func _pick(d: Node, key: String, hold := 0.7) -> void:
	for b in d.find_children("*", "Button", true, false):
		if b.get_meta("hotkey", "") == key:
			b.add_theme_stylebox_override("normal", b.get_theme_stylebox("hover"))
			b.add_theme_color_override("font_color", Palette.CINNABAR)
	await _wait(hold)
	d.chosen.emit(key)
	d.close()


func _advance(cs: Node) -> void:
	cs._on_advance()
	await _wait(0.2)
	while cs._busy:
		await _wait(0.05)


func _handle_decisions(cs: Node, show := 1.6) -> void:
	await _wait(0.1)
	var d := _dialog(cs, "res://ui/dialogs/decision_dialog.gd")
	while d:
		_mark("decision_" + str(d.event["id"]))
		await _wait(show)
		await _pick(d, PICKS.get(d.event["id"], "A"))
		await _wait(0.6)
		d = _dialog(cs, "res://ui/dialogs/decision_dialog.gd")


func _office(cs: Node) -> void:
	cs._open_office()
	await _wait(0.1)
	var o: Node
	for c in cs.get_children():
		if c.has_signal("confirmed"):
			o = c
	_mark("office_open")
	await _wait(1.8)
	var cat := {}
	for c in OfficeLayout.data()["catalog"]:
		cat[c["id"]] = c
	for step in HARMONIOUS:
		if step[0] == "place":
			o._start_place(cat[step[1]])
			await _wait(0.35)
			o._on_cell(step[2])
		else:
			o._view.selected_id = step[1]
			o._refresh()
			o._start_move(o.draft.items[step[1]])
			await _wait(0.35)
			o._on_cell(step[2])
		_mark("office_step_" + step[1])
		await _wait(0.45)
	await _wait(1.2)
	_mark("office_confirm")
	o._on_confirm()
	await _wait(1.5)


func _run() -> void:
	_mark("title")
	await _wait(4.0)
	main.start_campaign(1)
	await _wait(0.05)
	var cs: Node = main._screen
	cs.rng.seed = 2026
	_mark("c1_opening")
	await _wait(2.6)
	await _pick(_dialog(cs, "res://ui/dialogs/main_choice_dialog.gd"), "B", 0.9)
	_mark("c1_chosen")
	await _wait(1.6)
	while not cs.runner.is_finished() and not cs.runner.bankrupt:
		if cs.runner.turn == 6:
			await _office(cs)
		_mark("month_%d" % (cs.runner.turn + 1))
		await _advance(cs)
		await _wait(1.0)
		await _handle_decisions(cs)
	_mark("ending")
	await _wait(4.0)
	print("WIN ", cs.runner.check_win())
	for sid in [2, 3]:
		main.start_campaign(sid)
		_mark("c%d_opening" % sid)
		await _wait(3.0)
		var mc := _dialog(main._screen, "res://ui/dialogs/main_choice_dialog.gd")
		mc.close()
		_mark("c%d_board" % sid)
		await _wait(3.0)
	_mark("end")
	get_tree().quit()
