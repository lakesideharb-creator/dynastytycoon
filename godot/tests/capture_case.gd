extends Node
## 关卡实机走查：从标题画面进入指定关卡，按给定路线走完，在标题、选关、开局决断、每张决策卡、月度画面和结局截图
## 用法：godot --path godot --resolution 1920x1080 res://tests/capture_case.tscn -- <输出目录> <关卡> <路线>
## 路线与 tools/campaign_paths.py 输出相同，例如 B|s4_dealers=B|s4_marathon=A|s4_copycat=A

var main: Control
var out_dir := "user://case_shots/"
var sid := 4
var main_pick := "B"
var picks := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0].trim_suffix("/") + "/"
	if args.size() > 1:
		sid = int(args[1])
	if args.size() > 2:
		var parts := args[2].split("|")
		main_pick = parts[0]
		for p in parts.slice(1):
			var kv := p.split("=")
			picks[kv[0]] = kv[1]
	Settings.autosave = false          # 不覆盖玩家自己的自动存档
	PlaytestLog.enabled = false        # 不写入试玩记录
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
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
	img.save_png(ProjectSettings.globalize_path(out_dir + name + ".png"))
	print("shot ", name)


func _dialog(cs: Node, script_path: String) -> Node:
	for c in cs.get_children():
		if c.get_script() and c.get_script().resource_path == script_path and not c.is_queued_for_deletion():
			return c
	return null


func _run() -> void:
	await _wait(2.5)
	await _shot("00_title")
	main._screen._open_cases()
	await _wait(1.0)
	await _shot("00_cases")
	main.start_campaign(sid)
	await _wait(1.5)
	var cs: Node = main._screen
	cs.rng.seed = 2026
	await _shot("01_opening_choice")
	var mc := _dialog(cs, "res://ui/dialogs/main_choice_dialog.gd")
	mc.chosen.emit(main_pick)
	mc.close()
	await _wait(1.0)
	await _shot("02_month1")
	while not cs.runner.is_finished() and not cs.runner.bankrupt:
		var d := _dialog(cs, "res://ui/dialogs/decision_dialog.gd")
		if d:
			await _wait(0.8)
			await _shot("03_decision_%s" % d.event["id"])
			d.chosen.emit(picks.get(d.event["id"], "C"))
			d.close()
			await _wait(0.8)
			continue
		if cs.runner.turn == 8:
			await _shot("04_month8")
		if not cs._advance_btn.disabled and not cs._busy:
			cs._on_advance()
		await _wait(0.6)
		while cs._busy:
			await _wait(0.1)
	await _wait(2.5)
	print("win=", cs.runner.check_win(), " cash=", cs.runner.company.cash, " bankrupt=", cs.runner.bankrupt)
	await _shot("05_ending")
	get_tree().quit()
