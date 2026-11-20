extends Node
## 危机公关指挥室截图：走一遍卓越通关路线，在各阶段截图到 res://../store/screenshots/crisis/
## 用法：godot --path godot --resolution 1920x1080 res://tests/capture_crisis.tscn [-- 选项序列 输出前缀]
## 例如 -- 1 fail_ 走「推脱掩饰」直接被封杀的路线

const OUT := "res://../store/screenshots/crisis/"
var PATH := ["3", "1", "1"]            # 默认：秒级响应 → 景门发布会 → 千万质保金
var prefix := ""

var main: Control


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		PATH = Array(args[0].split(""))
	if args.size() >= 2:
		prefix = args[1]
	PlaytestLog.enabled = false
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
	if img.get_size() != Vector2i(1920, 1080):
		img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(OUT + prefix + name + ".png"))
	print("shot ", name)


func _key(ch: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = OS.find_keycode_from_string(ch)
	ev.unicode = ch.unicode_at(0)
	Input.parse_input_event(ev)


func _run() -> void:
	await _wait(1.0)
	await _shot("00_title")
	main.start_crisis("weight_loss_drug")
	await _wait(1.2)
	await _shot("01_brief")
	var cs: Node = main._screen
	for c in cs.get_children():
		if c.has_signal("start"):
			c.start.emit()
			c.close()
	await _wait(2.0)
	await _shot("02_stage1")
	for i in PATH.size():
		if cs.room.is_resolved:
			break
		_key(PATH[i])
		await _wait(0.9)
		if i == 0:
			await _shot("03_choice_feedback")
		await _wait(2.6)
		if i == 1:
			await _shot("04_stage3")
	await _wait(1.5)
	print("verdict=", cs.room.verdict_key, " anger=", cs.room.public_anger, " trust=", cs.room.brand_trust, " cash=", cs.company.cash)
	await _shot("05_ending")
	get_tree().quit()
