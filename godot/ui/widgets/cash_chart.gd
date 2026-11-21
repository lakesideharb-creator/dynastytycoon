extends Control
## 现金走势：终端风格折线图，带通关目标线（min_cash）与零线

var values: Array[float] = []
var target := 0.0
var months_total := 12
var start_cash := 0.0
var left_label := "开局"
var right_label := ""          ## 为空时显示「第N月」
var goal_label := "通关线 "
var _font := ThemeBuilder.mono()


func set_data(start: float, history: Array, goal: float, total: int) -> void:
	start_cash = start
	values.clear()
	for st in history:
		values.append(st.ending_cash)
	target = goal
	months_total = total
	queue_redraw()


func _fmt(v: float) -> String:
	if absf(v) >= 1e8:
		return "%.2f亿" % (v / 1e8)
	return "%.0f万" % (v / 1e4)


func _draw() -> void:
	var r := Rect2(Vector2(70, 10), size - Vector2(90, 34))
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0B0E12"))
	var pts: Array[float] = [start_cash]
	pts.append_array(values)
	var lo := minf(0.0, pts.min())
	var hi := maxf(maxf(target, pts.max()), 1.0) * 1.08
	var y_of := func(v: float) -> float: return r.end.y - (v - lo) / (hi - lo) * r.size.y
	var x_of := func(i: int) -> float: return r.position.x + r.size.x * i / float(maxi(1, months_total))

	for k in 5:                                   # 网格与刻度
		var v := lo + (hi - lo) * k / 4.0
		var y: float = y_of.call(v)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Palette.TERMINAL_LINE, 1.0)
		draw_string(_font, Vector2(4, y + 6), _fmt(v), HORIZONTAL_ALIGNMENT_LEFT, 64, 15, Palette.TEXT_DIM)
	if lo < 0:
		var y0: float = y_of.call(0.0)
		draw_line(Vector2(r.position.x, y0), Vector2(r.end.x, y0), Palette.CINNABAR.darkened(0.3), 1.5)
	if target > 0:
		var yt: float = y_of.call(target)
		draw_dashed_line(Vector2(r.position.x, yt), Vector2(r.end.x, yt), Palette.GOLD, 2.0, 10.0)
		draw_string(_font, Vector2(r.end.x - 170, yt - 8), goal_label + _fmt(target), HORIZONTAL_ALIGNMENT_RIGHT, 170, 15, Palette.GOLD)

	var line := PackedVector2Array()
	for i in pts.size():
		line.append(Vector2(x_of.call(i), y_of.call(pts[i])))
	if line.size() >= 2:
		var fill := line.duplicate()
		fill.append(Vector2(line[-1].x, r.end.y))
		fill.append(Vector2(line[0].x, r.end.y))
		draw_colored_polygon(fill, Color(Palette.AMBER, 0.10))
		draw_polyline(line, Palette.AMBER, 3.0, true)
	for p in line:
		draw_circle(p, 4.0, Palette.AMBER)
	draw_string(_font, Vector2(r.position.x, size.y - 4), left_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.TEXT_DIM)
	draw_string(_font, Vector2(r.end.x - 90, size.y - 4), right_label if right_label != "" else "第%d月" % months_total, HORIZONTAL_ALIGNMENT_RIGHT, 90, 14, Palette.TEXT_DIM)
