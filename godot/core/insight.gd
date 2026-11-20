class_name Insight
## 经营复盘解读（对应 src/insight.py）：把 f(T)·f(S)·f(P) 拆成玩家看得懂的因果说明
## 输出文字必须与 Python 端逐字一致（由对照测试保证）。

const SEASON_ELEMENT := {"Spring": "Wood", "Summer": "Fire", "Autumn": "Metal", "Winter": "Water"}
const SEASON_CN := {"Spring": "春", "Summer": "夏", "Autumn": "秋", "Winter": "冬"}
const ELEMENT_CN := {"Wood": "木", "Fire": "火", "Earth": "土", "Metal": "金", "Water": "水"}
const GENERATES := {"Wood": "Fire", "Fire": "Earth", "Earth": "Metal", "Metal": "Water", "Water": "Wood"}
const OVERCOMES := {"Wood": "Earth", "Earth": "Water", "Water": "Fire", "Fire": "Metal", "Metal": "Wood"}


static func industry_element(industry: String) -> String:
	var t := DataTables.engine()
	return t["industry_elements"].get(industry, "Fire")


## 旺相休囚死：当令五行与行业五行的关系
static func season_relation(season_elem: String, industry_elem: String) -> String:
	var s: String = ELEMENT_CN[season_elem]
	var i: String = ELEMENT_CN[industry_elem]
	if season_elem == industry_elem:
		return "旺·%s当令，与行业同气" % s
	if GENERATES[season_elem] == industry_elem:
		return "相·%s生%s，得令相助" % [s, i]
	if GENERATES[industry_elem] == season_elem:
		return "休·%s生%s，行业泄气" % [i, s]
	if OVERCOMES[industry_elem] == season_elem:
		return "囚·%s克%s，耗力难展" % [i, s]
	return "死·%s克%s，受制最重" % [s, i]


static func time_line(clock: CosmicClock, industry: String, prefix: String = "") -> String:
	var d := clock.calculate_time_factor(industry)
	var season := clock.get_season_key(clock.month)
	var rel := season_relation(SEASON_ELEMENT[season], industry_element(industry))
	return "%s天时 ×%.2f = 大运 ×%.2f · %s季【%s】×%.2f · %s ×%.2f" % [
		prefix, d["value"], d["era_mod"], SEASON_CN[season], rel, d["season_mod"], d["sha_name"], d["sha_mod"]]


## 在 simulate_month 之后、advance 之前调用，解读刚结算的这个月
static func explain_month(company: Company, engine: CosmicSimulationEngine) -> PackedStringArray:
	var lines := PackedStringArray()
	var clock := engine.clock
	var t := DataTables.engine()
	var ind: String = t["industry_names"].get(company.industry, company.industry)
	var ind_elem: String = ELEMENT_CN[industry_element(company.industry)]
	lines.append("【天时】%s属%s。" % [ind, ind_elem] + time_line(clock, company.industry))
	lines.append("        " + str(clock.calculate_time_factor(company.industry)["sha_desc"]))

	# 地利：按宫位汇总门店，数量降序、同数量按首次出现顺序（与 Python Counter.most_common 一致）
	var order: Array[String] = []
	var counts := {}
	for s in company.active_stores():
		if not counts.has(s.palace_id):
			counts[s.palace_id] = 0
			order.append(s.palace_id)
		counts[s.palace_id] += 1
	var sorted_ids: Array[String] = []
	for pid in order:                       # 稳定插入排序
		var pos := sorted_ids.size()
		while pos > 0 and counts[sorted_ids[pos - 1]] < counts[pid]:
			pos -= 1
		sorted_ids.insert(pos, pid)
	var parts := PackedStringArray()
	for pid in sorted_ids:
		var pname: String = engine.palaces_sys.get_palace_info(pid).get("name", pid)
		parts.append("%s %d处 ×%.2f" % [pname, counts[pid], engine.palaces_sys.affinity(company.industry, pid)])
	lines.append("【地利】" + "；".join(parts) + "（另含风水修正 %+.0f%%）" % (company.fengshui_modifier * 100))

	# 人和
	var p := engine.personnel_sys.calculate_personnel_factor(company.executives)
	lines.append("【人和】×%.2f = 平均适岗 %.2f × (1 − 内耗 %.0f%%)" % [p["value"], p["avg_match_score"], p["friction_ratio"] * 100])
	var clash: Array = p["clash_log"]
	for i in mini(3, clash.size()):
		lines.append("        " + clash[i])
	for e in company.executives:
		if e.stress > 60:
			lines.append("        ⚠ %s%s 压力 %d（>60 开始拖累表现）" % [e.role, e.name, e.stress])

	for m in company.revenue_modifiers:
		var span: String = ("剩%d个月" % int(m["months_left"])) if m.get("months_left") else "长期"
		lines.append("【决策余波】%s ×%.2f（%s）" % [m.get("label", "营收修正"), m["factor"], span])
	return lines


static func forecast_next_month(clock: CosmicClock, industry: String) -> String:
	var nxt := clock.copy()
	nxt.advance_month()
	var f_now: float = clock.calculate_time_factor(industry)["value"]
	var f_next: float = nxt.calculate_time_factor(industry)["value"]
	var trend := "→"
	if f_next > f_now + 1e-9:
		trend = "↑"
	elif f_next < f_now - 1e-9:
		trend = "↓"
	return "【下月预告】%d年%02d月 " % [nxt.year, nxt.month] + time_line(nxt, industry) + "  " + trend
