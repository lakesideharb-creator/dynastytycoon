extends Node
## 自由沙盒截图与冒烟测试：开局 → 人才市场雇人 → 九宫拓店 → 推进/快进 → 门店一览 → 存读档 → 打到终局
## 用法：godot --path godot --resolution 1920x1080 res://tests/capture_sandbox.tscn
## 截图输出到 res://../store/screenshots/sandbox/；存档写在独立的 user://shot_saves/，不影响玩家存档。

const OUT := "res://../store/screenshots/sandbox/"

var main: Control


func _ready() -> void:
	Settings.autosave = false
	PlaytestLog.enabled = false
	SaveGame.dir = "user://shot_saves/"
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
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("shot ", name)


func _overlay(node: Node, script_path: String) -> Node:
	for c in node.get_children():
		if c.get_script() and c.get_script().resource_path == script_path and not c.is_queued_for_deletion():
			return c
	return null


func _wait_idle(s: Node) -> void:
	while s._busy:
		await _wait(0.05)


## 雇一位与空缺岗位最相配的候选人（按适岗分）
func _hire_best(s: Node) -> String:
	s._open_talent()
	await _wait(0.4)
	var d := _overlay(s, "res://ui/dialogs/talent_market_dialog.gd")
	var g: SandboxGame = s.game
	var filled := {}
	for e in g.company.executives:
		filled[e.role] = true
	var best := [-1.0, -1, ""]
	for i in g.talent_pool.available.size():
		var c: Dictionary = g.talent_pool.available[i]
		for r in ["CEO", "CFO", "CMO", "CTO"]:
			if not filled.has(r):
				var syn := g.engine.personnel_sys.synergy(r, c["gate"])
				if syn > best[0]:
					best = [syn, i, r]
	d._select(best[1])
	d._role = best[2]
	d._refresh_roles()
	d._refresh_detail()
	await _wait(0.3)
	d._on_hire()
	var msg: String = d._msg.text
	d.close()
	await _wait(0.3)
	return msg


func _run() -> void:
	await _wait(1.0)
	await _shot("00_title")
	main.show_sandbox_setup()
	await _wait(1.0)
	await _shot("01_setup")
	main._screen._pick_industry("Cultural_Food")
	await _wait(0.3)
	main._screen._on_start()
	await _wait(1.5)
	var s: Node = main._screen
	await _shot("02_start")

	s._open_talent()
	await _wait(0.5)
	var td := _overlay(s, "res://ui/dialogs/talent_market_dialog.gd")
	td._select(0)
	await _wait(0.3)
	await _shot("03_talent")
	td._role = "CFO"
	td._refresh_roles()
	td._refresh_detail()
	await _wait(0.2)
	await _shot("03b_talent_role")
	td.close()
	await _wait(0.3)
	for i in 2:
		print("hire: ", await _hire_best(s))

	s._open_expansion()
	await _wait(0.6)
	await _shot("04_expansion")
	var ed := _overlay(s, "res://ui/dialogs/expansion_dialog.gd")
	ed._on_open()
	await _wait(0.5)

	for i in 3:
		s._on_advance()
		await _wait(0.2)
		await _wait_idle(s)
		await _wait(0.4)
	print("hire: ", await _hire_best(s))
	for i in 2:
		s._on_fast_year()
		await _wait(0.2)
		await _wait_idle(s)
	# 有余钱就再开一家
	if s.game.company.cash > 4.0e6:
		s._open_expansion()
		await _wait(0.4)
		_overlay(s, "res://ui/dialogs/expansion_dialog.gd")._on_open()
		await _wait(0.4)
	s._on_advance()
	await _wait(0.2)
	await _wait_idle(s)
	await _wait(4.5)            # 等提示框淡出
	await _shot("05_running")

	s._open_stores()
	await _wait(0.5)
	await _shot("06_stores")
	_overlay(s, "res://ui/dialogs/stores_dialog.gd").close()
	await _wait(0.3)

	SaveGame.save_sandbox("slot1", s.game, s.office)
	var cash_before: float = s.game.company.cash
	main.load_slot("slot1")
	await _wait(1.0)
	s = main._screen
	print("reload ok=", is_equal_approx(s.game.company.cash, cash_before), " turn=", s.game.turn)

	# 后续年份直接推进引擎（界面快进在前面已验证；后台窗口帧率受限，逐月走界面太慢）
	var g: SandboxGame = s.game
	for y in 2:                             # 先用界面快进两年
		s._on_fast_year()
		await _wait(0.2)
		await _wait_idle(s)
	while not g.is_game_over():
		if g.company.cash > 6.0e6 and g.company.active_stores().size() < 8:
			g.open_new_store("分店", SandboxGame.best_palaces(g.company.industry)[0], 3.0e6)
		g.advance_month(100000.0)
		if g.turn % 3 == 0:
			g.refresh_talent_market()
	if not g.company.financial_history.is_empty():
		s._show_statement(g.company.financial_history[-1], "%d年12月" % (g.clock.year - 1))
	s._refresh()
	s._finish()
	Engine.time_scale = 1.0
	await _wait(1.5)
	var e: Dictionary = s.game.check_ending()
	print("ending=", e["grade"], " turn=", s.game.turn, " assets=", s.game.net_assets(), " stores=", s.game.company.active_stores().size())
	await _shot("07_ending")
	get_tree().quit()
