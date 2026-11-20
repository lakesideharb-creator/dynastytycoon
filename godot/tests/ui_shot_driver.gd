extends Node
## ui_shots.gd 的驱动：加载主场景、按流程操作并截图

var out_dir := "user://shots"
var scenario_id := 1
var main_choice := "B"
var _main: Control
var _n := 0


func _ready() -> void:
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


func _run() -> void:
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
