extends Control
## 等轴测办公室视图：地砖、九宫着色、穿堂气流特效、家具（按深度排序）、悬停与放置预览
## 网格坐标 (x, y)：y=0 为北（窗），y=8 为南（门）。屏幕上北边在右上、南边在左下。

signal cell_clicked(cell: Vector2i)
signal cancelled

const TILE_W := 128.0
const TILE_H := 64.0
const SPRITE_SCALE := 0.5            ## 道具贴图 256×256 → 128×128
const SPRITE_LIFT := 0.30            ## 道具底部落在格子中心下方 TILE_H × 该比例处
const OFFICE_DIR := "res://assets/office/%s.png"

var layout: OfficeLayout
var show_palaces := true
var selected_id := ""
var ghost_sprite := ""               ## 放置预览所用贴图名
var ghost_ignore_id := ""            ## 移动物件时，原位置不算占用
var hover := Vector2i(-1, -1)
var _tex := {}
var _time := 0.0
var _font := ThemeBuilder.serif(700)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := OFFICE_DIR % name
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


func sprite_for(it: OfficeItem) -> String:
	if it.category == "desk":
		return OfficeLayout.data()["desk_sprites"].get(it.role, "desk_sales")
	for c in OfficeLayout.data()["catalog"]:
		if it.id == c["id"] or (it.category == c["category"] and c["category"] in ["screen", "plant"]):
			return c["sprite"]
	return it.category


# ─── 坐标换算 ──────────────────────────────────────────────────────────────
func origin() -> Vector2:
	var h := (layout.width + layout.height) * TILE_H / 2.0
	return Vector2(size.x / 2.0 + (layout.height - layout.width) * TILE_W / 4.0, (size.y - h) / 2.0 + 40.0)


func cell_center(c: Vector2i) -> Vector2:
	return origin() + Vector2((c.x - c.y) * TILE_W / 2.0, (c.x + c.y) * TILE_H / 2.0 + TILE_H / 2.0)


func cell_at(p: Vector2) -> Vector2i:
	var d := p - origin()
	var a := d.x / (TILE_W / 2.0)
	var b := d.y / (TILE_H / 2.0)
	return Vector2i(floori((a + b) / 2.0), floori((b - a) / 2.0))


func diamond(c: Vector2i, inset := 0.0) -> PackedVector2Array:
	var ctr := cell_center(c)
	var hw := TILE_W / 2.0 - inset * 2.0
	var hh := TILE_H / 2.0 - inset
	return PackedVector2Array([ctr + Vector2(0, -hh), ctr + Vector2(hw, 0), ctr + Vector2(0, hh), ctr + Vector2(-hw, 0)])


# ─── 输入 ──────────────────────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = cell_at(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var c := cell_at(event.position)
			if layout.in_bounds(c):
				cell_clicked.emit(c)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancelled.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover = Vector2i(-1, -1)


# ─── 绘制 ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	if layout == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0B0E12"))
	_draw_floor()
	if show_palaces:
		_draw_palaces()
	_draw_compass_labels()
	_draw_items()
	_draw_wind()                     # 画在家具之上，避免被屏风等挡住


func _draw_floor() -> void:
	for y in layout.height:
		for x in layout.width:
			var c := Vector2i(x, y)
			var name := "tile_floor"
			if c == layout.door:
				name = "tile_door"
			elif c == layout.window:
				name = "tile_window"
			elif y in layout.beam_rows:
				name = "tile_beam"
			var t := tex(name)
			var ctr := cell_center(c)
			if t:
				draw_texture_rect(t, Rect2(ctr - Vector2(TILE_W, TILE_H) / 2.0, Vector2(TILE_W, TILE_H)), false)
			else:
				draw_colored_polygon(diamond(c), Color("#C9A46A"))


func _draw_palaces() -> void:
	var blocks: Array = OfficeLayout.data()["grid"]["palace_blocks"]
	var elem_of := {}
	for p in DataTables.palaces():
		elem_of[p["id"]] = str(p.get("element", "Earth")).split("_")[0]
	for y in layout.height:
		for x in layout.width:
			var pid: String = blocks[y / 3][x / 3]
			var col: Color = Palette.ELEMENT.get(elem_of.get(pid, "Earth"), Palette.GOLD)
			draw_colored_polygon(diamond(Vector2i(x, y)), Color(col, 0.16))
	for by in 3:                     # 宫位分界线与宫名
		for bx in 3:
			var c0 := Vector2i(bx * 3, by * 3)
			var c2 := Vector2i(bx * 3 + 2, by * 3 + 2)
			var top := cell_center(c0) + Vector2(0, -TILE_H / 2.0)
			var right := cell_center(Vector2i(c2.x, c0.y)) + Vector2(TILE_W / 2.0, 0)
			var bottom := cell_center(c2) + Vector2(0, TILE_H / 2.0)
			var left := cell_center(Vector2i(c0.x, c2.y)) + Vector2(-TILE_W / 2.0, 0)
			draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(Palette.GOLD, 0.55), 1.5, true)
			var name := OfficeLayout.palace_name(blocks[by][bx]).split(" ")[0]
			var ctr := cell_center(Vector2i(bx * 3 + 1, by * 3 + 1))
			draw_string(_font, ctr + Vector2(-60, 8), name, HORIZONTAL_ALIGNMENT_CENTER, 120, 20, Color(Palette.INK, 0.55))


func _draw_compass_labels() -> void:
	var w := layout.width
	var h := layout.height
	var mid := func(a: Vector2i, b: Vector2i, out: Vector2) -> Vector2: return (cell_center(a) + cell_center(b)) / 2.0 + out
	var labels := [
		["北 · 落地窗", mid.call(Vector2i(0, 0), Vector2i(w - 1, 0), Vector2(70, -70))],
		["南 · 大门", mid.call(Vector2i(0, h - 1), Vector2i(w - 1, h - 1), Vector2(-150, 70))],
		["东", mid.call(Vector2i(w - 1, 0), Vector2i(w - 1, h - 1), Vector2(70, 50))],
		["西", mid.call(Vector2i(0, 0), Vector2i(0, h - 1), Vector2(-90, -40))],
	]
	for l in labels:
		draw_string(_font, l[1], l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.GOLD)


func _draw_wind() -> void:
	var d := layout.check_through_draft()
	var start := cell_center(layout.door)
	var finish := cell_center(layout.window)
	if d["draft"]:
		# 穿堂煞：冷色气流从大门笔直冲到窗户
		for k in 5:
			var offset := (k - 2) * 7.0
			var perp := Vector2(1, 2).normalized() * offset
			for s in 6:
				var t := fposmod(_time * 0.55 + s / 6.0 + k * 0.13, 1.0)
				var p0 := start.lerp(finish, t) + perp
				var p1 := start.lerp(finish, minf(1.0, t + 0.08)) + perp
				draw_line(p0, p1, Color(0.80, 0.90, 1.0, 0.75 * sin(t * PI)), 3.5, true)
	else:
		# 化煞：气流到遮挡物前放缓，分成两股绕行，回旋聚气（青碧色，与木地板区分）
		var qi := Color("#6FE3CF")
		var block := cell_center(Vector2i(layout.door.x, d["block_y"]))
		for k in 4:
			var t := fposmod(_time * 0.35 + k / 4.0, 1.0)
			var p := start.lerp(block, t * 0.8)
			draw_circle(p, 4.5, Color(qi, 0.85 * sin(t * PI)))
		for side in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for i in 17:
				var a := i / 16.0 * PI * 1.5 + _time * 1.2
				var r := 30.0 + 10.0 * (i / 16.0)
				pts.append(block + Vector2(side * (40 + r * cos(a)), -30 + r * 0.5 * sin(a)))
			draw_polyline(pts, Color(qi, 0.7 + 0.2 * sin(_time * 2.0)), 4.0, true)


func _draw_items() -> void:
	var list: Array = layout.items.values()
	list.sort_custom(func(a, b): return a.x + a.y < b.x + b.y or (a.x + a.y == b.x + b.y and a.x < b.x))
	var hover_drawn := false
	for it: OfficeItem in list:
		var c := Vector2i(it.x, it.y)
		if it.id == selected_id:
			draw_colored_polygon(diamond(c, 3), Color(Palette.AMBER, 0.35))
			draw_polyline(_closed(diamond(c, 3)), Palette.AMBER, 2.5, true)
		_draw_sprite(sprite_for(it), c, 1.0)
	if layout.in_bounds(hover):
		var ok := ghost_sprite == "" or layout.can_place(hover, ghost_ignore_id)
		var col := Palette.PAPER if ok else Palette.CINNABAR
		draw_polyline(_closed(diamond(hover, 2)), col, 2.5, true)
		if ghost_sprite != "":
			draw_colored_polygon(diamond(hover, 2), Color(col, 0.18))
			_draw_sprite(ghost_sprite, hover, 0.55)


func _draw_sprite(name: String, c: Vector2i, alpha: float) -> void:
	var t := tex(name)
	if t == null:
		return
	var s := Vector2(t.get_width(), t.get_height()) * SPRITE_SCALE
	var base := cell_center(c) + Vector2(0, TILE_H * SPRITE_LIFT)
	draw_texture_rect(t, Rect2(base - Vector2(s.x / 2.0, s.y), s), false, Color(1, 1, 1, alpha))


func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q
