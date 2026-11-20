class_name OfficeItem
extends RefCounted
## 办公室物件（对应 src/office_fengshui.py GridItem）

var id: String
var name: String
var category: String        ## desk / screen / plant / artifact / wall
var x: int
var y: int
var facing: String = "S"    ## N / S / E / W
var role: String = ""       ## President / Finance / CTO / Sales


static func from_dict(d: Dictionary) -> OfficeItem:
	var it := OfficeItem.new()
	it.id = str(d["id"])
	it.name = str(d.get("name", d["id"]))
	it.category = str(d["category"])
	it.x = int(d["x"])
	it.y = int(d["y"])
	it.facing = str(d.get("facing", "S"))
	it.role = str(d.get("role", ""))
	return it


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "category": category, "x": x, "y": y, "facing": facing, "role": role}


func duplicate_item() -> OfficeItem:
	return OfficeItem.from_dict(to_dict())
