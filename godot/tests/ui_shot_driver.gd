extends Node
## ui_shots.gd 的驱动：加载主场景、按流程操作并截图

var out_dir := "user://shots"
var scenario_id := 1
var main_choice := "B"
var mode := "play"                   ## play：完整一局；systems：存档/读档/设置流程
var _main: Control
var _n := 0


func _ready() -> void:
	SaveGame.dir = "user://shot_saves/"          # 不碰玩家真实存档
	PlaytestLog.enabled = false                   # 不写玩家的试玩记录（只改内存，不保存设置）
	for slot in SaveGame.SLOTS:
		SaveGame.delete(slot)
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(120.0).timeout.connect(func():
		push_error("截图超时")
		get_tree().quit(2))
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s.png" % [out_dir, _n, name]
	img.save_png(path)
	print("截图 ", path, " ", img.get_size())


func _dialog(cls_path: String) -> Node:
	for c in _main._screen.get_children():
		if c.get_script() and c.get_script().resource_path == cls_path and not c.is_queued_for_deletion():
			return c
	return null


func _office_tour() -> void:
	var screen = _main._screen
	screen._open_office()
	await _wait(1.0)
	var o: Control = null
	for c in screen.get_children():
		if c.get_script() and c.get_script().resource_path == "res://ui/office_screen.gd":
			o = c
	await _shot("office_initial")
	var cat := {}
	for c in OfficeLayout.data()["catalog"]:
		cat[c["id"]] = c
	o._start_place(cat["screen"])
	o._view.hover = Vector2i(4, 5)
	await _wait(0.4)
	await _shot("office_placing")
	o._on_cell(Vector2i(4, 5))                       # 屏风挡住中轴
	o._on_cell(Vector2i(4, 3))                       # 选中总裁桌 → 移到西北乾位、背靠北墙
	o._start_move(o.draft.items["p_desk"])
	o._on_cell(Vector2i(1, 0))
	o._on_cell(Vector2i(4, 7))                       # 财务桌 → 正北坎位
	o._start_move(o.draft.items["f_desk"])
	o._on_cell(Vector2i(4, 1))
	o._start_place(cat["pixiu"])
	o._on_cell(Vector2i(2, 0))
	o._on_cell(Vector2i(1, 0))                       # 选中总裁桌，展示选中态
	await _wait(0.8)
	await _shot("office_renovated")
	o._on_confirm()
	await _wait(0.8)
	await _shot("after_renovation")


func _overlay(script_path: String) -> Node:
	var screen = _main._screen
	for c in screen.get_children():
		if c.get_script() and c.get_script().resource_path == script_path and not c.is_queued_for_deletion():
			return c
	return null


func _run_systems() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)
	await _wait(1.0)
	_main.start_campaign(scenario_id)
	await _wait(1.0)
	var mc := _dialog("res://ui/dialogs/main_choice_dialog.gd")
	mc.chosen.emit(main_choice)
	mc.close()
	await _wait(0.6)
	var screen = _main._screen
	while screen.runner.turn < 3:
		var dd := _dialog("res://ui/dialogs/decision_dialog.gd")
		if dd:
			dd.chosen.emit(dd.event["options"][0]["key"])
			dd.close()
			await _wait(0.4)
			continue
		screen._on_advance()
		await _wait(0.9)
	screen.open_system_menu()
	await _wait(0.6)
	await _shot("system_menu")
	_overlay("res://ui/dialogs/system_menu.gd").close()
	screen._save_to("slot1")
	await _wait(0.3)
	var d = load("res://ui/dialogs/save_slots_dialog.gd").new()
	d.mode = "load"
	screen.add_child(d)
	await _wait(0.6)
	await _shot("load_slots")
	d.close()
	screen.add_child(load("res://ui/dialogs/settings_dialog.gd").new())
	await _wait(0.6)
	await _shot("settings")
	_overlay("res://ui/dialogs/settings_dialog.gd").close()
	await _wait(0.3)
	_main.show_title()
	await _wait(1.0)
	await _shot("title_continue")
	_main.load_slot("slot1")
	await _wait(1.2)
	await _shot("loaded_slot1")
	get_tree().quit(0)


func _run() -> void:
	if mode == "systems":
		await _run_systems()
		return
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)
	await _wait(1.2)
	await _shot("title")

	_main.start_campaign(scenario_id)
	await _wait(1.2)
	await _shot("main_choice")
	var mc := _dialog("res://ui/dialogs/main_choice_dialog.gd")
	mc.chosen.emit(main_choice)
	mc.close()
	await _wait(1.0)
	await _shot("campaign_start")
	await _office_tour()

	var screen = _main._screen
	var decision_shots := 0
	var month_shots := 0
	while not screen.runner.is_finished():
		var dd := _dialog("res://ui/dialogs/decision_dialog.gd")
		if dd:
			await _wait(0.6)
			if decision_shots < 2:
				decision_shots += 1
				await _shot("decision_%s" % dd.event["id"])
			var pick := ""
			for o in dd.event["options"]:
				if screen.runner.option_available(o)["ok"]:
					pick = o["key"]
					break
			dd.chosen.emit(pick)
			dd.close()
			await _wait(0.4)
			continue
		screen._on_advance()
		await _wait(0.9)
		if screen.runner.turn in [3, 7] and month_shots < 2:
			month_shots += 1
			await _shot("month_%d" % (screen.runner.turn - 1))
	await _wait(1.0)
	await _shot("ending")
	get_tree().quit(0)
