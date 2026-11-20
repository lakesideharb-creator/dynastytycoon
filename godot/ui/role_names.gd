class_name RoleNames
## 岗位中文名与高管情绪判定（界面用）

const CN := {
	"CEO": "首席执行官", "CFO": "首席财务官", "CTO": "首席技术官", "CMO": "首席营销官",
	"COO": "首席运营官", "VP_Expansion": "拓展副总裁", "CSO": "首席销售官", "CDO": "首席数字官",
}


static func cn(role: String) -> String:
	return CN.get(role, role)


## 当前卷入八门冲突的高管 id（与 PersonnelSystem 的内耗规则对应）
static func clashing_ids(executives: Array[Executive]) -> Dictionary:
	var by_gate := {}
	for e in executives:
		by_gate.get_or_add(e.gate_id, []).append(e)
	var shang: Array = by_gate.get("shang_men", [])
	var out := {}
	var mark := func(list: Array):
		for e in list:
			out[e.id] = true
	if shang.size() >= 2:
		mark.call(shang)
	if shang.size() >= 1 and by_gate.has("du_men"):
		mark.call(shang)
		mark.call(by_gate["du_men"])
	if shang.size() >= 1 and by_gate.has("sheng_men"):
		mark.call(shang)
		mark.call(by_gate["sheng_men"])
	for e in executives:
		if e.role == "CEO":
			if e.gate_id == "shang_men":
				out[e.id] = true
			break
	return out


## 情绪：冲突 > 压力过高 > 本月利润上升 > 平常
static func mood(e: Executive, clashing: Dictionary, history: Array) -> String:
	if clashing.has(e.id):
		return "angry"
	if e.stress > 60:
		return "stressed"
	if history.size() >= 1:
		var last: float = history[-1].net_profit
		var prev: float = history[-2].net_profit if history.size() >= 2 else 0.0
		if last > 0 and last >= prev:
			return "pleased"
	return "neutral"
