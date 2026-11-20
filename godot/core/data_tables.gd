class_name DataTables
## 数值表加载器：与 Python 端（src/tables.py）读同一份 JSON。
## res://data/ 下的文件由 tools/sync_godot_data.py 从仓库根目录 data/ 同步过来，不要直接改。

const DATA_DIR := "res://data/"

static var _cache := {}


static func load_json(file_name: String) -> Variant:
	if _cache.has(file_name):
		return _cache[file_name]
	var path := DATA_DIR + file_name
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("无法读取数据文件：%s" % path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		push_error("JSON 解析失败：%s" % path)
		return {}
	_cache[file_name] = data
	return data


static func engine() -> Dictionary:
	return load_json("engine_tables.json")


static func scenarios() -> Array:
	return load_json("campaign_scenarios.json").get("scenarios", [])


static func random_events() -> Dictionary:
	return load_json("random_events.json")


static func palaces() -> Array:
	return load_json("nine_palaces.json").get("palaces", [])
