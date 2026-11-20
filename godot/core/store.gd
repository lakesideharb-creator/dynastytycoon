class_name Store
extends RefCounted
## 门店 / 研发中心（对应 src/models.py Store）

const DECAY_FLOOR := 0.65    ## 老化后营收最低保留比例（与 STORE_DECAY_FLOOR 一致）

var id: String
var name: String
var palace_id: String
var city_name: String
var base_revenue: float
var rent: float
var staff_cost: float
var is_active: bool = true
var age_months: int = 0
var decay_rate: float = 0.0          ## 每月营收衰减率，战役门店为 0
var maintenance_cost: float = 0.0
var invest: float = 0.0


static func from_dict(d: Dictionary) -> Store:
	var s := Store.new()
	s.id = str(d.get("id", ""))
	s.name = str(d.get("name", ""))
	s.palace_id = str(d.get("palace_id", ""))
	s.city_name = str(d.get("city_name", ""))
	s.base_revenue = float(d.get("base_revenue", 0.0))
	s.rent = float(d.get("rent", 0.0))
	s.staff_cost = float(d.get("staff_cost", 0.0))
	s.is_active = bool(d.get("is_active", true))
	s.age_months = int(d.get("age_months", 0))
	s.decay_rate = float(d.get("decay_rate", 0.0))
	s.maintenance_cost = float(d.get("maintenance_cost", 0.0))
	s.invest = float(d.get("invest", 0.0))
	return s


func effective_base_revenue() -> float:
	return base_revenue * maxf(DECAY_FLOOR, 1.0 - decay_rate * age_months)


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "palace_id": palace_id, "city_name": city_name,
			"base_revenue": base_revenue, "rent": rent, "staff_cost": staff_cost, "is_active": is_active,
			"age_months": age_months, "decay_rate": decay_rate, "maintenance_cost": maintenance_cost, "invest": invest}
