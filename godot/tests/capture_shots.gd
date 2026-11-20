extends Node
## 商店页截图：自动走一遍第一关（通关路线），在关键画面截图到 res://../store/screenshots/
## 用法：godot --path godot --resolution 1920x1080 res://tests/capture_shots.tscn

const OUT := "res://../store/screenshots/"
const PICKS := {"s1_summer": "A", "s1_rival": "B", "s1_winter": "B"}

var main: Control


func _ready() -> void:
	Settings.autosave = false          # 不覆盖玩家自己的自动存档
	PlaytestLog.enabled = false        # 不写入试玩记录
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("shot ", name, " ", img.get_size())
	if img.get_size() != Vector2i(1920, 1080):
		img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _dialog(cs: Node, script_path: String) -> Node:
	for c in cs.get_children():
		if c.get_script() and c.get_script().resource_path == script_path and not c.is_queued_for_deletion():
			return c
	return null


func _run() -> void:
	await _wait(3.0)
	await _shot("01_title")
	main.start_campaign(1)
	await _wait(1.5)
	var cs: Node = main._screen
	cs.rng.seed = 2026
	await _shot("02_opening_choice")
	var mc := _dialog(cs, "res://ui/dialogs/main_choice_dialog.gd")
	mc.chosen.emit("B")
	mc.close()
	await _wait(1.0)
	var decision_shot := false
	var office_shot := false
	var main_shot := false
	while not cs.runner.is_finished() and not cs.runner.bankrupt:
		var d := _dialog(cs, "res://ui/dialogs/decision_dialog.gd")
		if d:
			await _wait(0.8)
			if not decision_shot:
				await _shot("04_decision")
				decision_shot = true
			d.chosen.emit(PICKS.get(d.event["id"], "A"))
			d.close()
			await _wait(0.8)
			continue
		if cs.runner.turn == 9 and not main_shot:
			for t in cs._toast_box.get_children():
				t.queue_free()
			await _wait(0.8)
			await _shot("03_campaign")
			main_shot = true
		if cs.runner.turn == 6 and not office_shot:
			cs._open_office()
			await _wait(1.5)
			await _shot("05_office")
			for c in cs.get_children():
				if c.has_method("_close") and c.has_signal("confirmed"):
					c.queue_free()
			await _wait(0.5)
			office_shot = true
		if not cs._advance_btn.disabled and not cs._busy:
			cs._on_advance()
		await _wait(0.6)
		while cs._busy:
			await _wait(0.1)
	await _wait(2.5)
	print("win=", cs.runner.check_win(), " cash=", cs.runner.company.cash)
	await _shot("06_ending")
	get_tree().quit()
