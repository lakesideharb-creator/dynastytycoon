extends SceneTree
## 运行：godot --headless --path godot -s res://tests/run_tests.gd
## 与 Python 引擎逐项对照（golden 数据由 tools/export_golden.py 生成），并测试 Godot 端独有的逻辑。
## 全部通过时退出码为 0。

const GOLDEN := "res://tests/golden/"
const REL_TOL := 1e-9

var passed := 0
var failed := 0
var failures: Array[String] = []


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	test_factors()
	for sid in [1, 2, 3]:
		test_campaign(sid)
	test_office()
	test_saves()
	test_playtest_log()
	test_event_system()
	test_effects_edge_cases()
	test_runner_rules()
	print("")
	for f in failures.slice(0, 30):
		print("FAIL " + f)
	if failures.size() > 30:
		print("… 另有 %d 处失败" % (failures.size() - 30))
	print("通过 %d 项，失败 %d 项，用时 %.1f 秒" % [passed, failed, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failed > 0 else 0)


# ─── 断言工具 ────────────────────────────────────────────────────────────────
func _ok(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		failures.append(msg)


func _close(a: float, b: float, msg: String) -> void:
	var tol := maxf(REL_TOL * maxf(absf(a), absf(b)), 1e-9)
	_ok(absf(a - b) <= tol, "%s：Godot %.10f ≠ Python %.10f" % [msg, a, b])


func _load_golden(file_name: String) -> Dictionary:
	var f := FileAccess.open(GOLDEN + file_name, FileAccess.READ)
	assert(f != null, "缺少 golden 文件：" + file_name)
	return JSON.parse_string(f.get_as_text())


func _team(rows: Array) -> Array[Executive]:
	var team: Array[Executive] = []
	for r in rows:
		team.append(Executive.from_dict(r))
	return team


# ─── 因子表对照 ──────────────────────────────────────────────────────────────
func test_factors() -> void:
	var g := _load_golden("factors.json")
	for r in g["time"]:
		var clk := CosmicClock.new(int(r["year"]), int(r["month"]))
		var d := clk.calculate_time_factor(r["industry"])
		var tag := "天时 %d-%02d %s" % [r["year"], r["month"], r["industry"]]
		_close(d["value"], r["f_time"], tag)
		_close(d["era_mod"], r["era_mod"], tag + " 大运")
		_close(d["season_mod"], r["season_mod"], tag + " 月令")
		_ok(d["sha_name"] == r["sha_name"], tag + " 神煞")

	var ps := NinePalacesSystem.new()
	for r in g["space"]:
		_close(ps.calculate_store_space_factor(r["industry"], r["palace"], r["fengshui"]), r["f_space"],
				"地利 %s %s %.2f" % [r["industry"], r["palace"], r["fengshui"]])

	var pers := PersonnelSystem.new()
	for i in g["personnel"].size():
		var r: Dictionary = g["personnel"][i]
		var p := pers.calculate_personnel_factor(_team(r["team"]))
		_close(p["value"], r["f_person"], "人和 #%d" % i)
		_close(p["friction_ratio"], r["friction"], "内耗 #%d" % i)
		_close(p["avg_match_score"], r["avg"], "适岗 #%d" % i)
		_ok(Array(p["clash_log"]) == Array(r["clash_log"]), "冲突日志 #%d" % i)


# ─── 战役逐月对照 ────────────────────────────────────────────────────────────
func test_campaign(sid: int) -> void:
	var g := _load_golden("campaign_%d.json" % sid)
	for path_data in g["paths"]:
		var path: String = path_data["path"]
		var parts := path.split("|")
		var picks := {}
		for p in parts.slice(1):
			var kv := p.split("=")
			picks[kv[0]] = kv[1]
		var r := CampaignRunner.new(sid)
		r.apply_main_choice(parts[0])
		var month_idx := 0
		var tag_base := "关卡%d %s" % [sid, path]
		while not r.is_finished():
			for ev in r.pending_decisions():
				var res := r.apply_decision(ev["id"], picks.get(ev["id"], "?"))
				_ok(res["ok"], "%s 决策 %s 无法执行：%s" % [tag_base, ev["id"], res["message"]])
			var out := r.simulate_month(0.0, false)
			if month_idx >= path_data["months"].size():
				_ok(false, tag_base + " 月数多于 Python")
				break
			var gm: Dictionary = path_data["months"][month_idx]
			var tag := "%s 第%d月" % [tag_base, month_idx + 1]
			var sd: Dictionary = out["statement"].to_dict()
			for k in gm["statement"]:
				_close(float(sd[k]), float(gm["statement"][k]), "%s %s" % [tag, k])
			_close(r.company.cash, gm["cash"], tag + " 现金")
			var lines := Insight.explain_month(r.company, r.engine)
			_ok(Array(lines) == Array(gm["explain"]), "%s 解读文字不一致\n  Godot：%s\n  Python：%s" % [tag, "｜".join(lines), "｜".join(PackedStringArray(gm["explain"]))])
			var fc := Insight.forecast_next_month(r.clock, r.company.industry)
			_ok(fc == gm["forecast"], "%s 预告不一致\n  Godot：%s\n  Python：%s" % [tag, fc, gm["forecast"]])
			month_idx += 1
			if not r.bankrupt:
				r.advance()
		_ok(month_idx == path_data["months"].size(), tag_base + " 月数不一致")
		_ok(r.check_win() == path_data["win"], tag_base + " 胜负不一致")
		_ok(r.bankrupt == path_data["bankrupt"], tag_base + " 破产判定不一致")
		_close(r.company.cash, path_data["final_cash"], tag_base + " 期末现金")
		_close(r.company.fengshui_modifier, path_data["fengshui"], tag_base + " 风水")
		_ok(r.company.reputation == int(path_data["reputation"]), tag_base + " 商誉")
		_ok(r.company.active_stores().size() == int(path_data["active_stores"]), tag_base + " 门店数")
		var p := r.engine.personnel_sys.calculate_personnel_factor(r.company.executives)
		_close(p["friction_ratio"], path_data["friction"], tag_base + " 内耗")
		_ok(r.company.executives.size() == path_data["executives"].size(), tag_base + " 高管人数")
		for i in mini(r.company.executives.size(), path_data["executives"].size()):
			var e := r.company.executives[i]
			var ge: Dictionary = path_data["executives"][i]
			_ok(e.name == ge["name"] and e.role == ge["role"] and e.stress == int(ge["stress"])
					and e.loyalty == int(ge["loyalty"]) and is_equal_approx(e.salary, float(ge["salary"])),
					"%s 高管 %s 状态不一致" % [tag_base, ge["name"]])


# ─── 风水审计对照 ────────────────────────────────────────────────────────────
func test_office() -> void:
	var g := _load_golden("office.json")
	for i in g["layouts"].size():
		var row: Dictionary = g["layouts"][i]
		var o := OfficeLayout.new()
		for spec in row["items"]:
			o.add_item(OfficeItem.from_dict(spec))
		var a := o.audit()
		var tag := "风水布局 #%d" % i
		_ok(a["score"] == int(row["score"]), "%s 评分 Godot %d ≠ Python %d" % [tag, a["score"], row["score"]])
		_close(a["modifier"], row["modifier"], tag + " 修正值")
		for k in ["perks", "shas", "recs"]:
			_ok(Array(a[k]) == Array(row[k]), "%s %s 文字不一致\n  Godot：%s\n  Python：%s" % [tag, k, "｜".join(a[k]), "｜".join(PackedStringArray(row[k]))])
	# 预设与布局编辑辅助
	var chaotic := OfficeLayout.from_preset("chaotic")
	_ok(chaotic.audit()["score"] == 5 and OfficeLayout.from_preset("harmonious").audit()["score"] == 100, "两个预设的评分")
	_ok(not chaotic.can_place(chaotic.door) and not chaotic.can_place(chaotic.window), "门窗格不能放物件")
	_ok(not chaotic.can_place(Vector2i(4, 3)) and chaotic.can_place(Vector2i(4, 3), "p_desk"), "被占格只允许原物件自身")
	var draft := chaotic.copy()
	draft.add_item(OfficeItem.from_dict({"id": "screen_1", "name": "屏风", "category": "screen", "x": 4, "y": 5}))
	_ok(chaotic.items.size() == 3 and draft.items.size() == 4, "copy() 得到独立副本")
	_ok(draft.check_through_draft()["block_y"] == 5 and not draft.check_through_draft()["draft"], "屏风挡住穿堂煞")
	# 改造对公司修正：审计变化 × 0.3（-0.18 → +0.20，变化 0.38 → +0.114），并夹在上限内
	var full := OfficeLayout.from_preset("harmonious")
	_close(OfficeLayout.apply_to_company(0.08, chaotic, full), 0.194, "满配改造后公司修正")
	_close(OfficeLayout.apply_to_company(0.30, chaotic, full), 0.35, "公司修正封顶 +35%")


# ─── 存档：读 Python 存档继续玩、Godot 自身往返 ───────────────────────────────
func _finish_path(r: CampaignRunner, picks: Dictionary) -> void:
	while not r.is_finished():
		for ev in r.pending_decisions():
			r.apply_decision(ev["id"], picks[ev["id"]])
		r.simulate_month(0.0, false)
		if not r.bankrupt:
			r.advance()


func _picks(path: String) -> Dictionary:
	var picks := {}
	for p in path.split("|").slice(1):
		var kv := p.split("=")
		picks[kv[0]] = kv[1]
	return picks


func test_saves() -> void:
	var g := _load_golden("saves.json")
	for fx in g["fixtures"]:
		var tag := "读 Python 存档 关卡%d" % fx["scenario_id"]
		var loaded := SaveGame.from_dict(fx["save"])
		var r: CampaignRunner = loaded["runner"]
		_ok(r.turn == int(fx["save"]["progress"]["turn"]) and r.main_choice == fx["save"]["progress"]["main_choice"], tag + " 进度恢复")
		_ok(loaded["office"].audit()["score"] == 100, tag + " 办公室布局恢复")
		var before := r.company.financial_history.size()
		_finish_path(r, _picks(fx["path"]))
		var after := r.company.financial_history.slice(before)
		_ok(after.size() == fx["after_months"].size(), tag + " 续玩月数")
		for i in mini(after.size(), fx["after_months"].size()):
			var sd: Dictionary = after[i].to_dict()
			for k in fx["after_months"][i]:
				_close(float(sd[k]), float(fx["after_months"][i][k]), "%s 续玩第%d月 %s" % [tag, i + 1, k])
		_close(r.company.cash, fx["final_cash"], tag + " 期末现金")
		_ok(r.check_win() == fx["win"], tag + " 胜负")

	# Godot 自身往返：存档 → JSON 文本 → 读档，与不中断的那一局结果完全相同
	var path := "B|s1_summer=A|s1_rival=B|s1_winter=A"
	var a := CampaignRunner.new(1)
	a.apply_main_choice("B")
	var office := OfficeLayout.from_preset("chaotic")
	office.add_item(OfficeItem.from_dict({"id": "screen_1", "name": "屏风", "category": "screen", "x": 4, "y": 5}))
	while a.turn < 5:
		for ev in a.pending_decisions():
			a.apply_decision(ev["id"], _picks(path)[ev["id"]])
		a.simulate_month(0.0, false)
		a.advance()
	var text := JSON.stringify(SaveGame.to_dict(a, office))
	DirAccess.make_dir_recursive_absolute("res://tests/out")            # 供 Python 端读取验证（tests/test_godot_parity.py）
	var out := FileAccess.open("res://tests/out/godot_save.json", FileAccess.WRITE)
	if out:
		out.store_string(text)
		out.close()
	var data: Dictionary = JSON.parse_string(text)
	for k in ["version", "scenario_id", "year", "month", "progress", "office_items", "company"]:
		_ok(data.has(k), "存档包含 Python 读档所需字段 " + k)
	var b_loaded := SaveGame.from_dict(data)
	var b: CampaignRunner = b_loaded["runner"]
	_ok(b_loaded["office"].items.has("screen_1"), "往返后办公室物件保留")
	_ok(Array(b.company.revenue_modifiers.map(func(m): return m["label"])) == Array(a.company.revenue_modifiers.map(func(m): return m["label"])), "往返后决策余波保留")
	_finish_path(a, _picks(path))
	_finish_path(b, _picks(path))
	_close(b.company.cash, a.company.cash, "往返后续玩期末现金")
	_ok(b.company.financial_history.size() == a.company.financial_history.size(), "往返后历史月数")
	_ok(b.check_win() == a.check_win(), "往返后胜负")


func test_playtest_log() -> void:
	PlaytestLog.path = "user://test_playtest_log.jsonl"
	PlaytestLog.clear()
	var r := CampaignRunner.new(1)
	PlaytestLog.record(r, null, "quit")
	_ok(PlaytestLog.count() == 0, "未做开局决断时不记录")
	r.apply_main_choice("B")
	r.simulate_month(0.0, false)
	PlaytestLog.record(r, OfficeLayout.from_preset("chaotic"), "quit")
	PlaytestLog.record(r, null, "lose")
	_ok(PlaytestLog.count() == 2, "每局一行")
	var row: Dictionary = JSON.parse_string(PlaytestLog.read_all().split("\n")[0])
	for k in ["time", "scenario", "outcome", "months_played", "main_choice", "decisions", "cash", "friction", "fengshui", "office_score"]:
		_ok(row.has(k), "试玩记录包含字段 " + k)
	_ok(row["outcome"] == "quit" and int(row["office_score"]) == 5 and row["main_choice"] == "B", "试玩记录内容")
	PlaytestLog.clear()
	PlaytestLog.path = "user://playtest_log.jsonl"


# ─── Godot 端独有逻辑 ────────────────────────────────────────────────────────
func test_event_system() -> void:
	var es := EventSystem.new()
	var food := es.eligible_events("Cultural_Food")
	var ai := es.eligible_events("AI_Tech")
	var ids_food := food.map(func(e): return e["id"])
	var ids_ai := ai.map(func(e): return e["id"])
	_ok("viral_marketing" in ids_food and not ("viral_marketing" in ids_ai), "烘焙事件只在餐饮行业出现")
	_ok("tech_viral_demo" in ids_ai and not ("tech_viral_demo" in ids_food), "科技事件只在 AI 行业出现")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c := Company.new()
	c.industry = "AI_Tech"
	c.reputation = 99
	c.fengshui_modifier = 0.34
	var hits := 0
	for i in 2000:
		if es.trigger_monthly_event(c, rng) != null:
			hits += 1
	_ok(absf(hits / 2000.0 - es.trigger_chance) < 0.04, "事件触发频率约为 %.0f%%（实测 %.1f%%）" % [es.trigger_chance * 100, hits / 20.0])
	_ok(c.reputation >= 0 and c.reputation <= 100, "商誉夹在 0–100")
	_ok(c.fengshui_modifier >= -0.25 and c.fengshui_modifier <= 0.35, "风水夹在 -0.25–0.35")


func test_effects_edge_cases() -> void:
	var c := Company.new()
	c.cash = 1000.0
	c.reputation = 98
	c.executives = _team([{"id": "1", "name": "甲", "gate_id": "jing_men", "role": "CEO", "salary": 1, "stress": 90, "loyalty": 50}])
	c.stores.append_array(Effects.build_stores({"id": "li_{nn}", "name": "店{nn}", "count": 2, "palace_id": "li_9",
			"city_name": "成都", "base_revenue": 100, "rent": 10, "staff_cost": 20}))
	Effects.apply_effects(c, [
		{"type": "cash", "amount": -200}, {"type": "reputation", "delta": 10}, {"type": "fengshui", "delta": 1.0},
		{"type": "exec", "match": {"all": true}, "stress": 30, "loyalty": -5},
		{"type": "store_field", "field": "staff_cost", "factor": 0.5, "id_prefix": ["li_01"]},
		{"type": "revenue_mod", "factor": 1.5, "months": 2, "palace": ["li_9"]},
	])
	_ok(c.cash == 800.0 and c.reputation == 100 and c.fengshui_modifier == 0.35, "现金/商誉/风水效果与上下限")
	_ok(c.executives[0].stress == 100 and c.executives[0].loyalty == 45, "高管压力与忠诚夹在 0–100")
	_ok(c.stores.size() == 2 and c.stores[1].id == "li_02" and c.stores[1].name == "店02", "批量开店的 {nn} 序号")
	_ok(c.stores[0].staff_cost == 10.0 and c.stores[1].staff_cost == 20.0, "门店字段修改只作用于匹配门店")
	_ok(c.store_revenue_multiplier(c.stores[0]) == 1.5, "营收修正器生效")
	c.tick_revenue_modifiers()
	c.tick_revenue_modifiers()
	_ok(c.revenue_modifiers.is_empty(), "临时修正器到期移除")
	Effects.apply_effects(c, [{"type": "exec", "match": {"name": "甲"}, "remove": true}])
	_ok(c.executives.is_empty(), "高管离职")


func test_runner_rules() -> void:
	var r := CampaignRunner.new(3)
	r.apply_main_choice("B")            # 不聘休门 COO
	while r.turn < 3:
		r.simulate_month(0.0, false)
		r.advance()
	var evs := r.pending_decisions()
	_ok(evs.size() == 1 and evs[0]["id"] == "s3_scientist", "第3个月出现首席科学家议题")
	var xiu_opt: Dictionary = {}
	for o in evs[0]["options"]:
		if o.get("requires_gate") == "xiu_men":
			xiu_opt = o
	_ok(not r.option_available(xiu_opt)["ok"], "缺少休门高管时调解选项不可选")
	_ok(not r.apply_decision("s3_scientist", xiu_opt["key"])["ok"], "不可选的选项不能执行")

	var r2 := CampaignRunner.new(2)
	r2.apply_main_choice("C")
	while r2.turn < 3:
		r2.simulate_month(0.0, false)
		r2.advance()
	_ok(r2.pending_decisions().is_empty(), "未签对赌时不出现对赌条款议题")
