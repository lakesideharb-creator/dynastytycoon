class_name CosmicClock
extends RefCounted
## 天时时钟（对应 src/cosmic_clock.py）：三元九运大运、四季月令、日辰神煞

var year: int
var month: int
var era_id: String
var era_name: String


func _init(start_year: int = 2024, start_month: int = 2) -> void:
	year = start_year
	month = start_month
	_set_era()


func _set_era() -> void:
	for e in DataTables.engine()["eras"]:
		if year <= int(e["until_year"]):
			era_id = e["id"]
			era_name = e["name"]
			return


func copy() -> CosmicClock:
	return CosmicClock.new(year, month)


func get_season_key(m: int) -> String:
	return DataTables.engine()["season_of_month"][str(m)]


func advance_month() -> void:
	month += 1
	if month > 12:
		month = 1
		year += 1
		_set_era()


## 返回 {"name", "mod", "desc"}
func get_current_sha() -> Dictionary:
	var shas: Array = DataTables.engine()["daily_shas"]
	return shas[(year * 12 + month) % shas.size()]


## 返回 {"value": 未舍入的 f(T), "f_time": 保留三位, "era_name", "era_mod", "season_name", "season_mod", "sha_name", "sha_mod", "sha_desc"}
func calculate_time_factor(industry: String) -> Dictionary:
	var t := DataTables.engine()
	var era_mod := float(t["era_weights"].get(era_id, {}).get(industry, 1.0))
	var season_key := get_season_key(month)
	var elem: String = t["industry_elements"].get(industry, t["default_industry_element"])
	var season_mod := float(t["season_multipliers"][season_key].get(elem, 1.0))
	var sha := get_current_sha()
	var f_time := era_mod * season_mod * float(sha["mod"])
	return {
		"value": f_time,
		"f_time": PyFmt.round_to(f_time, 3),
		"era_name": era_name,
		"era_mod": era_mod,
		"season_name": t["season_names"][str(month)],
		"season_mod": season_mod,
		"sha_name": sha["name"],
		"sha_mod": float(sha["mod"]),
		"sha_desc": sha["desc"],
	}
