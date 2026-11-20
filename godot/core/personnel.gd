class_name PersonnelSystem
extends RefCounted
## 人和八门（对应 src/personnel.py）：适岗匹配与组织内耗

var role_gate_synergy := {}   ## "role|gate" -> score


func _init() -> void:
	for r in DataTables.engine()["role_gate_synergy"]:
		role_gate_synergy["%s|%s" % [r["role"], r["gate"]]] = float(r["score"])


func synergy(role: String, gate_id: String) -> float:
	return role_gate_synergy.get("%s|%s" % [role, gate_id], 1.0)


## 返回 {"friction": 0.0–0.5（三位小数）, "clash_log": Array[String]}
func calculate_internal_friction(executives: Array[Executive]) -> Dictionary:
	var clash_log: Array[String] = []
	var base := 0.0
	var counts := {}
	for e in executives:
		counts[e.gate_id] = counts.get(e.gate_id, 0) + 1
	var shang: int = counts.get("shang_men", 0)

	if shang >= 2:
		base += 0.25
		clash_log.append("【两伤相克】：团队内存在多名狼性伤门高管，各自为战争抢资源，内耗+25%")
	if shang >= 1 and counts.get("du_men", 0) >= 1:
		base += 0.15
		clash_log.append("【伤杜相争】：前线销售频繁催促功能上线，技术研发坚守质量拒绝配合，内耗+15%")
	if shang >= 1 and counts.get("sheng_men", 0) >= 1:
		base += 0.15
		clash_log.append("【生伤相争】：前线要求大量垫资放账，财务死守风控拒绝审批，内耗+15%")

	var ceo: Executive = null
	var cfo: Executive = null
	for e in executives:
		if ceo == null and e.role == "CEO":
			ceo = e
		if cfo == null and e.role == "CFO":
			cfo = e
	if ceo and ceo.gate_id == "shang_men":
		base += 0.10
		clash_log.append("【伤门司帅】：伤门暴烈，适合为先锋而非帅印，担任CEO致使团队压力剧增，内耗+10%")
	if ceo and cfo and ceo.gate_id == "jing_men" and cfo.gate_id == "sheng_men":
		base -= 0.10
		clash_log.append("【景生相融】：品牌愿景(景门)与务实算账(生门)形成互补合力，内耗降低10%")

	var xiu: int = counts.get("xiu_men", 0)
	if xiu > 0:
		var reduction := minf(0.25, xiu * 0.15)
		base -= reduction
		clash_log.append("【休门润木】：休门HR/COO调和人际矛盾，内耗降低 %d%%" % int(reduction * 100))

	return {"friction": PyFmt.round_to(maxf(0.0, minf(0.50, base)), 3), "clash_log": clash_log}


## 返回 {"value": f(P), "avg_match_score", "friction_ratio", "clash_log", "role_details", "f_person"}
func calculate_personnel_factor(executives: Array[Executive]) -> Dictionary:
	if executives.is_empty():
		return {"value": 0.70, "error": "无核心管理层", "avg_match_score": 0.0, "friction_ratio": 0.0,
				"clash_log": [], "role_details": {}, "f_person": 0.70}

	var total := 0.0
	var role_details := {}
	for e in executives:
		var stress_penalty := maxf(0.0, (e.stress - 60) * 0.005)
		var loyalty_bonus := (e.loyalty - 50) * 0.002
		var score := PyFmt.round_to(synergy(e.role, e.gate_id) - stress_penalty + loyalty_bonus, 3)
		total += score
		role_details[e.role] = {"name": e.name, "gate": e.gate_name, "score": score}

	var avg := total / executives.size()
	var fr := calculate_internal_friction(executives)
	var f_person := maxf(0.40, avg * (1.0 - fr["friction"]))
	var rounded := PyFmt.round_to(f_person, 3)
	return {"value": rounded, "avg_match_score": PyFmt.round_to(avg, 3), "friction_ratio": fr["friction"],
			"clash_log": fr["clash_log"], "role_details": role_details, "f_person": rounded}
