class_name Company
extends RefCounted
## 企业主体（对应 src/models.py Company）

var name: String
var industry: String
var cash: float
var executives: Array[Executive] = []
var stores: Array[Store] = []
var fengshui_modifier: float = 0.05
var reputation: int = 70
var active_gods: Array = []
var financial_history: Array[FinancialStatement] = []
## 营收修正器：{"factor", "months_left"(null=长期), "id_prefix"?, "palace"?, "label"?}
var revenue_modifiers: Array = []


func total_monthly_payroll() -> float:
	var total := 0.0
	for e in executives:
		total += e.salary
	return total


func active_stores() -> Array[Store]:
	var out: Array[Store] = []
	for s in stores:
		if s.is_active:
			out.append(s)
	return out


static func modifier_targets_store(modifier: Dictionary, store: Store) -> bool:
	var prefixes = modifier.get("id_prefix")
	var palaces = modifier.get("palace")
	if prefixes:
		var hit := false
		for p in prefixes:
			if store.id.begins_with(p):
				hit = true
				break
		if not hit:
			return false
	if palaces and not (store.palace_id in palaces):
		return false
	return true


func store_revenue_multiplier(store: Store) -> float:
	var mult := 1.0
	for m in revenue_modifiers:
		if modifier_targets_store(m, store):
			mult *= float(m["factor"])
	return mult


## 月末递减临时修正器的剩余月数，到期移除
func tick_revenue_modifiers() -> void:
	var kept := []
	for m in revenue_modifiers:
		if m.get("months_left") == null:
			kept.append(m)
		elif int(m["months_left"]) > 1:
			m["months_left"] = int(m["months_left"]) - 1
			kept.append(m)
	revenue_modifiers = kept
