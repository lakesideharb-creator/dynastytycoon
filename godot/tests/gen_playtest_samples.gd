extends SceneTree
## 生成模拟试玩记录：几位「虚拟试玩者」用游戏内同一套 PlaytestLog 记录战役、危机公关、自由沙盒的若干局，
## 用于 tools/analyze_playtests.py 的测试与示例报告。选择带偏好（模拟有人看懂、有人瞎选），部分局中途退出。
## 用法：godot --headless --path godot -s res://tests/gen_playtest_samples.gd -- <输出目录> [人数] [种子]

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/playtests"
	var testers := int(args[1]) if args.size() > 1 else 6
	rng.seed = int(args[2]) if args.size() > 2 else 2026
	DirAccess.make_dir_recursive_absolute(out_dir)
	PlaytestLog.enabled = true
	for i in testers:
		PlaytestLog.path = out_dir.path_join("玩家%d.jsonl" % (i + 1))
		if FileAccess.file_exists(PlaytestLog.path):
			DirAccess.remove_absolute(PlaytestLog.path)
		var skill := rng.randf()                    # 0 = 瞎选，1 = 看懂了
		for sid in [1, 3] if rng.randf() < 0.5 else [1, 2, 3]:
			_campaign(sid, skill)
		if rng.randf() < 0.3:
			_campaign(1, minf(1.0, skill + 0.3))     # 有人想再来一局
		_crisis(skill)
		_sandbox(skill)
	print("已生成 %d 位试玩者的记录 → %s" % [testers, out_dir])
	quit()


func _pick(options: Array, good: String, skill: float) -> String:
	return good if rng.randf() < skill and good in options else options[rng.randi_range(0, options.size() - 1)]


func _campaign(sid: int, skill: float) -> void:
	var r := CampaignRunner.new(sid)
	var good := {1: "B", 2: "B", 3: "B"}
	r.apply_main_choice(_pick(r.meta["main_choices"].keys(), r.meta.get("intended_main_choice", good[sid]), skill))
	var quit_at := rng.randi_range(2, r.duration()) if rng.randf() < 0.15 else -1
	while not r.is_finished():
		for ev in r.pending_decisions():
			var keys := []
			for o in ev["options"]:
				if r.option_available(o)["ok"]:
					keys.append(o["key"])
			r.apply_decision(ev["id"], _pick(keys, keys[0], skill * 0.5))
		if r.turn == quit_at:
			PlaytestLog.record(r, OfficeLayout.from_preset("chaotic"), "quit")
			return
		r.simulate_month(50000.0 * skill, true, rng)
		if not r.bankrupt:
			r.advance()
	var office := OfficeLayout.from_preset("harmonious" if rng.randf() < skill * 0.6 else "chaotic")
	PlaytestLog.record(r, office, "bankrupt" if r.bankrupt else ("win" if r.check_win() else "lose"))


func _crisis(skill: float) -> void:
	var room := CrisisWarRoom.create()
	var c := CrisisWarRoom.create_company()
	var best := ["stage1_active", "stage2_press_sincere", "stage3_fund"]
	var i := 0
	while not room.is_resolved:
		var ids := []
		for o in room.current_stage()["options"]:
			ids.append(o["id"])
		room.execute_choice(_pick(ids, best[i], skill), c)
		i += 1
		if not room.is_resolved and rng.randf() < 0.08:
			PlaytestLog.record_crisis(room, c, "quit")
			return
	PlaytestLog.record_crisis(room, c, room.grade())


func _sandbox(skill: float) -> void:
	var inds := SandboxGame.industries()
	var ind: String = inds[rng.randi_range(0, inds.size() - 1)]["key"]
	var home: String = SandboxGame.best_palaces(ind)[0] if rng.randf() < skill else ["kan_1", "kun_2", "zhen_3", "li_9"][rng.randi_range(0, 3)]
	var g := SandboxGame.create_new_game("试玩", ind, 6.0e6, home, rng)
	var quit_year := rng.randi_range(2025, 2033) if rng.randf() < 0.35 else 9999
	var hires := 0 if rng.randf() < 0.15 else rng.randi_range(1, 4)
	while not g.is_game_over():
		if g.clock.year >= quit_year:
			PlaytestLog.record_sandbox(g, OfficeLayout.from_preset("chaotic"), "quit")
			return
		if g.company.executives.size() < hires and not g.talent_pool.available.is_empty():
			var best := [-1.0, 0, "CEO"]
			for k in g.talent_pool.available.size():
				for role in ["CEO", "CFO", "CMO", "CTO"]:
					var s := g.engine.personnel_sys.synergy(role, g.talent_pool.available[k]["gate"])
					if rng.randf() > skill:
						s = rng.randf() * 1.5
					if s > best[0]:
						best = [s, k, role]
			g.hire_talent(best[1], best[2], int(g.talent_pool.available[best[1]]["asking_salary"]))
		if g.company.cash - 2.0e6 > (3 + 6 * skill) * g.monthly_fixed_cost():
			g.open_new_store("店", SandboxGame.best_palaces(ind)[0] if rng.randf() < skill else home, 2.0e6)
		g.advance_month(50000.0)
		if g.turn % 3 == 0:
			g.refresh_talent_market()
	PlaytestLog.record_sandbox(g, OfficeLayout.from_preset("chaotic"), g.check_ending()["grade"])
