class_name Effects
## 数据驱动的效果系统（对应 src/effects.py），类型定义见该文件文档字符串。

const TYPES := ["cash", "reputation", "fengshui", "fengshui_set", "revenue_mod", "store_field",
		"store_cost", "add_stores", "exec", "add_exec"]
const FENGSHUI_MIN := -0.25
const FENGSHUI_MAX := 0.35
const STORE_NUMERIC_FIELDS := ["base_revenue", "rent", "staff_cost", "maintenance_cost"]
const EXEC_SETTABLE := ["role", "salary", "loyalty", "stress", "special_trait"]
const FIELD_LABELS := {"staff_cost": "人工成本", "rent": "租金", "base_revenue": "基础营收", "maintenance_cost": "维护成本"}


static func _exec_matches(e: Executive, match: Dictionary) -> bool:
	if match.get("all", false):
		return true
	for k in match:
		var attr: String = "gate_id" if k == "gate" else k
		if str(e.get(attr)) != str(match[k]):
			return false
	return true


static func build_stores(spec: Dictionary) -> Array[Store]:
	var out: Array[Store] = []
	var count := int(spec.get("count", 0))
	if count <= 0:
		out.append(Store.from_dict(spec))
		return out
	for i in range(1, count + 1):
		var d := spec.duplicate()
		var nn := "%02d" % i
		d["id"] = str(spec["id"]).replace("{nn}", nn)
		d["name"] = str(spec["name"]).replace("{nn}", nn)
		out.append(Store.from_dict(d))
	return out


static func apply_effects(company: Company, effects: Array) -> Array[String]:
	var notes: Array[String] = []
	for eff in effects:
		var t: String = eff["type"]
		match t:
			"cash":
				company.cash += float(eff["amount"])
				notes.append("资金 " + PyFmt.signed_thousands(float(eff["amount"])))
			"reputation":
				company.reputation = clampi(company.reputation + int(eff["delta"]), 0, 100)
				notes.append("商誉 %+d" % int(eff["delta"]))
			"fengshui":
				company.fengshui_modifier = PyFmt.round_to(clampf(company.fengshui_modifier + float(eff["delta"]), FENGSHUI_MIN, FENGSHUI_MAX), 3)
				notes.append("风水 %+.0f%%" % (float(eff["delta"]) * 100))
			"fengshui_set":
				company.fengshui_modifier = float(eff["value"])
				notes.append("风水修正设为 %+.0f%%" % (float(eff["value"]) * 100))
			"revenue_mod":
				var mod := {"factor": float(eff["factor"]), "months_left": eff.get("months")}
				for k in ["id_prefix", "palace", "label"]:
					if eff.has(k):
						mod[k] = eff[k]
				if mod["months_left"] != null:
					mod["months_left"] = int(mod["months_left"])
				company.revenue_modifiers.append(mod)
				var span: String = ("%d个月" % int(eff["months"])) if eff.get("months") else "长期"
				notes.append("%s ×%.2f（%s）" % [eff.get("label", "营收"), float(eff["factor"]), span])
			"store_field", "store_cost":
				var field: String = eff["field"]
				assert(field in STORE_NUMERIC_FIELDS, "store_field 不支持字段: " + field)
				for st in company.stores:
					if st.is_active and Company.modifier_targets_store(eff, st):
						var v: float = st.get(field)
						if eff.has("factor"):
							v = v * float(eff["factor"])
						if eff.has("add"):
							v = v + float(eff["add"])
						st.set(field, v)
				if eff.has("factor"):
					notes.append("%s ×%.2f" % [FIELD_LABELS[field], float(eff["factor"])])
				else:
					notes.append(FIELD_LABELS[field] + " " + PyFmt.signed_thousands(float(eff["add"])))
			"add_stores":
				var new_stores := build_stores(eff)
				company.stores.append_array(new_stores)
				notes.append("新增门店 %d 家" % new_stores.size())
			"exec":
				var targets: Array[Executive] = []
				for e in company.executives:
					if _exec_matches(e, eff["match"]):
						targets.append(e)
				for e in targets:
					if eff.get("remove", false):
						company.executives.erase(e)
						notes.append("%s%s离职" % [e.role, e.name])
						continue
					e.stress = clampi(e.stress + int(eff.get("stress", 0)), 0, 100)
					e.loyalty = clampi(e.loyalty + int(eff.get("loyalty", 0)), 0, 100)
					if eff.has("set_role"):
						e.role = eff["set_role"]
					for k in eff.get("set", {}):
						assert(k in EXEC_SETTABLE, "exec.set 不支持字段: " + k)
						var v = eff["set"][k]
						if k in ["loyalty", "stress"]:
							v = int(v)
						elif k == "salary":
							v = float(v)
						e.set(k, v)
			"add_exec":
				var ex := Executive.from_dict(eff)
				company.executives.append(ex)
				notes.append("%s%s加入" % [ex.role, ex.name])
			_:
				push_error("未知效果类型: " + t)
	return notes
