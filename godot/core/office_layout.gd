class_name OfficeLayout
extends RefCounted
## 企业总部风水工位（对应 src/office_fengshui.py OfficeLayoutManager）
## 网格、宫位、预设与物件目录见 data/office_items.json。审计结果与 Python 逐字一致（对照测试保证）。

var width: int
var height: int
var door: Vector2i
var window: Vector2i
var beam_rows: Array = []
var items := {}     ## id -> OfficeItem（保持插入顺序，审计按此顺序输出）


static func data() -> Dictionary:
	return DataTables.load_json("office_items.json")


func _init() -> void:
	var g: Dictionary = data()["grid"]
	width = int(g["width"])
	height = int(g["height"])
	door = Vector2i(int(g["door"][0]), int(g["door"][1]))
	window = Vector2i(int(g["window"][0]), int(g["window"][1]))
	for r in g["beam_rows"]:
		beam_rows.append(int(r))


static func from_preset(preset: String) -> OfficeLayout:
	var o := OfficeLayout.new()
	for spec in data()["presets"][preset]:
		o.add_item(OfficeItem.from_dict(spec))
	return o


func copy() -> OfficeLayout:
	var o := OfficeLayout.new()
	for it in items.values():
		o.add_item(it.duplicate_item())
	return o


func add_item(it: OfficeItem) -> void:
	items[it.id] = it


func remove_item(id: String) -> void:
	items.erase(id)


func palace_at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= width or y >= height:
		return "zhong_5"
	return data()["grid"]["palace_blocks"][y / 3][x / 3]


static func palace_name(pid: String) -> String:
	return data()["palace_names"].get(pid, pid)


func item_at(x: int, y: int) -> OfficeItem:
	for it in items.values():
		if it.x == x and it.y == y:
			return it
	return null


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


## 能否把物件放到 c：在界内、不是门/窗格、没被其他物件占用
func can_place(c: Vector2i, ignore_id := "") -> bool:
	if not in_bounds(c) or c == door or c == window:
		return false
	var other := item_at(c.x, c.y)
	return other == null or other.id == ignore_id


func is_blocked(x: int, y: int) -> bool:
	for it in items.values():
		if it.x == x and it.y == y and it.category in data()["blocking_categories"]:
			return true
	return false


## 穿堂煞射线检测：大门到落地窗的中轴线上（不含两端）有无屏风/绿植阻隔
## 返回 {"draft": bool, "desc": String, "block_y": 第一个阻隔物所在行（无则 -1）}
func check_through_draft() -> Dictionary:
	var lo := mini(door.y, window.y) + 1
	var hi := maxi(door.y, window.y)
	for y in range(hi - 1, lo - 1, -1):         # 从大门一侧向窗户方向找第一个阻隔物（仅用于特效）
		if is_blocked(door.x, y):
			return {"draft": false, "block_y": y,
					"desc": "【藏风聚气】：中轴线已设置玄关/屏风遮挡，气流迂回婉转，化解穿堂风。"}
	return {"draft": true, "block_y": -1,
			"desc": "【穿堂大煞】：大门与落地大窗在正中轴直通对穿！气乘风则散，每月产生 15% 资金跑冒与坏账。"}


## 返回 {"score", "modifier", "perks", "shas", "recs"}
func audit() -> Dictionary:
	var score := 50
	var perks: Array[String] = []
	var shas: Array[String] = []
	var recs: Array[String] = []

	var draft := check_through_draft()
	if draft["draft"]:
		score -= 18
		shas.append(draft["desc"])
		recs.append("建议在中轴线 (x=4, y=4或5) 摆放【玄关屏风】或【高叶发财树】切断穿堂气流。")
	else:
		score += 10
		perks.append(draft["desc"])

	for it: OfficeItem in items.values():
		var palace := palace_at(it.x, it.y)
		var pname := palace_name(palace)
		if it.role == "President":
			if palace in ["qian_6", "gen_8"]:
				score += 15
				perks.append("【乾位得位】：总裁办公桌坐落于 %s，权威威信稳固，战略决策洞察力+15%%。" % pname)
			else:
				score -= 8
				shas.append("【乾坤失位】：总裁桌落于 %s，非首领之位，容易被下属架空。" % pname)
				recs.append("建议将总裁办公室调整至西北乾位 (0-2, 0-2)。")
			if it.facing == "S" and it.y == 0:
				score += 10
				perks.append("【背后实墙】：总裁椅后依实墙靠山，前方视野开阔，得贵人与资方坚实支持。")
			elif it.facing == "S" and it.y > 0 and not is_blocked(it.x, it.y - 1):
				score -= 10
				shas.append("【背门而坐】：总裁背后空旷悬虚无靠山，容易突遭背刺与合同纠纷。")
				recs.append("建议总裁工位紧贴北实墙 (y=0) 或背后加设高大书架玄关。")
		elif it.role == "Finance":
			if palace == "kan_1":
				score += 15
				perks.append("【深水藏金】：财务室坐落于正北坎一深水位，水主流动生财，资金跑冒滴漏率清零。")
			elif palace == "li_9":
				score -= 12
				shas.append("【水火相克】：财务室落于正南离火位，火烈蒸水，企业开支不可遏制大失血。")
				recs.append("财务工位切忌置于正南离火位，必须迁入正北坎水位避光隐蔽处。")
		elif it.role == "CTO":
			if palace in ["zhen_3", "kan_1"]:
				score += 12
				perks.append("【极客雷动】：研发团队坐落于 %s，灵感迸发，技术专利研发提速 20%%。" % pname)
		elif it.role == "Sales":
			if palace in ["zhen_3", "xun_4"]:
				score += 10
				perks.append("【战鼓雷鸣】：销售先锋坐落于 %s，狼性签单欲望大增。" % pname)

		if it.category == "desk" and it.y in beam_rows:
			score -= 12
			shas.append("【横梁压顶】：%s 正上方横贯建筑承重梁，高管长期受压易生暗疾，精力扣减30点！" % it.name)
			recs.append("建议将 %s 移出 y=3 承重梁投影线，或增设石膏吊顶包覆。" % it.name)

		if it.category == "artifact":
			if it.id == "pixiu" and palace in ["qian_6", "zhong_5"]:
				score += 10
				perks.append("【招财貔貅】：汉白玉貔貅坐落于首领乾位，外部顶级资方参访意向提升 20%。")
			elif it.id == "wenchang" and palace in ["zhen_3", "kan_1"]:
				score += 10
				perks.append("【文昌高耸】：九层紫铜文昌塔镇守研发核心区，技术代码崩溃概率降为零。")
			elif it.id == "fishtank" and palace in ["xun_4", "kan_1"]:
				score += 8
				perks.append("【聚宝活水】：水草造景鱼缸激活东南巽位，现金流周转速度提升 15%。")

	var final_score := clampi(score, 5, 100)
	return {"score": final_score, "modifier": PyFmt.round_to((final_score - 50) / 100.0 * 0.40, 3),
			"perks": perks, "shas": shas, "recs": recs}


## 改造生效后公司风水修正：审计修正值的变化 × modifier_weight 叠加到原值，夹在 -25%～+35%（与 play.py 一致）
static func apply_to_company(company_modifier: float, before: OfficeLayout, after: OfficeLayout) -> float:
	var delta: float = after.audit()["modifier"] - before.audit()["modifier"]
	return PyFmt.round_to(clampf(company_modifier + delta * float(data()["modifier_weight"]), Effects.FENGSHUI_MIN, Effects.FENGSHUI_MAX), 3)


func to_array() -> Array:
	return items.values().map(func(it): return it.to_dict())
