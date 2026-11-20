class_name Executive
extends RefCounted
## 高管（对应 src/models.py Executive）

var id: String
var name: String
var gate_id: String          ## 如 kai_men、sheng_men
var gate_name: String        ## 开门、生门
var role: String             ## CEO、CFO、CTO、CMO、VP_Expansion…
var salary: float            ## 月薪
var loyalty: int = 80        ## 忠诚度 0–100
var stress: int = 20         ## 压力值 0–100
var special_trait: String = ""


static func from_dict(d: Dictionary) -> Executive:
	var e := Executive.new()
	e.id = str(d.get("id", ""))
	e.name = str(d.get("name", ""))
	e.gate_id = str(d.get("gate_id", ""))
	e.gate_name = str(d.get("gate_name", ""))
	e.role = str(d.get("role", ""))
	e.salary = float(d.get("salary", 0.0))
	e.loyalty = int(d.get("loyalty", 80))
	e.stress = int(d.get("stress", 20))
	e.special_trait = str(d.get("special_trait", ""))
	return e


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "gate_id": gate_id, "gate_name": gate_name, "role": role,
			"salary": salary, "loyalty": loyalty, "stress": stress, "special_trait": special_trait}
