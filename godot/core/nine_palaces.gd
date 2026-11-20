class_name NinePalacesSystem
extends RefCounted
## 地利九宫（对应 src/nine_palaces.py）

var industry_affinities: Dictionary
var palaces_data := {}


func _init() -> void:
	industry_affinities = DataTables.engine()["industry_affinities"]
	for p in DataTables.palaces():
		palaces_data[p["id"]] = p


func get_palace_info(palace_id: String) -> Dictionary:
	return palaces_data.get(palace_id, {"id": palace_id, "name": palace_id, "element": "Earth", "base_rent_multiplier": 1.0})


func affinity(industry: String, palace_id: String) -> float:
	return float(industry_affinities.get(industry, {}).get(palace_id, 1.0))


func calculate_store_space_factor(industry: String, palace_id: String, fengshui_modifier: float = 0.0) -> float:
	return PyFmt.round_to(affinity(industry, palace_id) * (1.0 + fengshui_modifier), 3)
