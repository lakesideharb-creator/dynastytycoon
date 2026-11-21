class_name TalentPool
extends RefCounted
## 人才市场（对应 src/talent_pool.py）：40 位候选人模板中每次抽取 8 位，议价与雇佣
## 候选人为字典：{name, gate, gate_name, eligible_roles, asking_salary, min_salary, traits, portrait}

var available: Array[Dictionary] = []
var quarter := 0
var rng: RandomNumberGenerator


func _init(r: RandomNumberGenerator = null) -> void:
	rng = r if r else RandomNumberGenerator.new()
	if r == null:
		rng.randomize()


static func data() -> Dictionary:
	return DataTables.load_json("sandbox.json")


static func gate_name(gate: String) -> String:
	return data()["gate_names"].get(gate, gate)


## 由模板生成候选人（要价与底线的算法与 Python 一致；asking 为 -1 时随机抽取要价）
static func candidate_from(tpl: Dictionary, asking: int, r: RandomNumberGenerator = null) -> Dictionary:
	var econ: Dictionary = data()["economy"]
	var scale := float(econ["talent_salary_scale"])
	var sal_min := int(float(tpl["salary_range"][0]) * scale)
	var sal_max := int(float(tpl["salary_range"][1]) * scale)
	if asking < 0:
		asking = r.randi_range(int(sal_min * float(econ["talent_ask_floor"])), sal_max)
	# 立绘：通用门派头像，男女按姓名稳定选取
	var sex := "f" if tpl["name"].hash() % 2 == 0 else "m"
	return {
		"name": tpl["name"], "gate": tpl["gate"], "gate_name": gate_name(tpl["gate"]),
		"eligible_roles": Array(tpl["roles"]).duplicate(), "asking_salary": asking,
		"min_salary": int(sal_min * float(econ["talent_min_ratio"])), "traits": Array(tpl["traits"]).duplicate(),
		"portrait": "talent_%s_%s" % [tpl["gate"], sex],
	}


static func template(name: String) -> Dictionary:
	for t in data()["talent_templates"]:
		if t["name"] == name:
			return t
	return {}


func refresh_market(pool_size: int = -1) -> Array[Dictionary]:
	if pool_size < 0:
		pool_size = int(data()["economy"]["talent_pool_size"])
	quarter += 1
	var tpls: Array = data()["talent_templates"].duplicate()
	# 不放回抽样
	for i in range(tpls.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = tpls[i]
		tpls[i] = tpls[j]
		tpls[j] = tmp
	available.clear()
	for t in tpls.slice(0, mini(pool_size, tpls.size())):
		available.append(candidate_from(t, -1, rng))
	return available


static func negotiate(candidate: Dictionary, offer: int) -> bool:
	return offer >= int(candidate["min_salary"])


## 雇佣成功返回 Executive 并从市场移除；报价低于底线返回 null
func hire(candidate: Dictionary, role: String, salary: int) -> Executive:
	var idx := available.find(candidate)
	if idx < 0 or not negotiate(candidate, salary):
		return null
	available.remove_at(idx)
	return to_executive(candidate, role, salary, rng)


static func to_executive(c: Dictionary, role: String, salary: int, r: RandomNumberGenerator = null) -> Executive:
	var e := Executive.new()
	var tag := "%06x" % (r.randi() & 0xFFFFFF if r else randi() & 0xFFFFFF)
	e.id = "exec_%s_%s" % [String(c["name"]).left(4), tag]
	e.name = c["name"]
	e.gate_id = c["gate"]
	e.gate_name = c["gate_name"]
	e.role = role
	e.salary = salary
	e.stress = 0
	e.special_trait = "·".join(PackedStringArray(Array(c["traits"]).slice(0, 2)))
	e.portrait = c.get("portrait", "")
	return e


func to_dict() -> Dictionary:
	return {"quarter": quarter, "available": available.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	quarter = int(d.get("quarter", 0))
	available.clear()
	for c in d.get("available", []):
		available.append(c)
