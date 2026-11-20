extends Control
## 危机指标条：公众怒火 / 品牌信任。带警戒线（封杀线、社死线）、数值滚动动画与变动飘字

var caption := ""
var hint := ""                  ## 标题右侧的小字说明
var line := 85.0                ## 警戒线位置（0–100）
var line_label := ""
var danger_above := true        ## true：数值高于警戒线危险（怒火）；false：低于危险（信任）
var shown := 0.0                ## 当前显示值（动画中）
var _delta_text := ""
var _delta_color := Color.WHITE
var _delta_alpha := 0.0
var _serif := ThemeBuilder.serif(700)
var _mono := ThemeBuilder.mono()


func _init() -> void:
	custom_minimum_size = Vector2(0, 122)


func color_for(v: float) -> Color:
	var risk := (v - line) / 100.0 if danger_above else (line - v) / 100.0
	if risk >= 0.0:
		return Palette.CINNABAR
	if (danger_above and v >= line - 20) or (not danger_above and v <= line + 20):
		return Palette.AMBER
	return Palette.JADE


func set_value(v: float, animate := true) -> void:
	if not animate:
		shown = v
		queue_redraw()
		return
	var d := roundi(v - shown)
	if d != 0:
		_delta_text = ("+%d" % d) if d > 0 else str(d)
		var good := (d < 0) if danger_above else (d > 0)
		_delta_color = Palette.JADE if good else Palette.CINNABAR
		_delta_alpha = 1.0
		var fade := create_tween()
		fade.tween_interval(0.9)
		fade.tween_method(func(a): _delta_alpha = a; queue_redraw(), 1.0, 0.0, 0.8)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(x): shown = x; queue_redraw(), shown, v, 0.9)


func _draw() -> void:
	var w := size.x
	var col := color_for(shown)
	draw_string(_serif, Vector2(0, 30), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.PAPER)
	var cap_w := _serif.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(_serif, Vector2(cap_w + 14, 29), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.TEXT_DIM)
	var num := "%d" % roundi(shown)
	draw_string(_mono, Vector2(w - 150, 38), num, HORIZONTAL_ALIGNMENT_RIGHT, 110, 44, col)
	draw_string(_mono, Vector2(w - 40, 38), "/100", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.TEXT_DIM)
	if _delta_alpha > 0.0:
		draw_string(_mono, Vector2(w - 260, 36), _delta_text, HORIZONTAL_ALIGNMENT_RIGHT, 100, 30, Color(_delta_color, _delta_alpha))

	var bar := Rect2(Vector2(0, 56), Vector2(w, 26))
	draw_rect(bar, Color("#0B0E12"))
	draw_rect(Rect2(bar.position, Vector2(w * clampf(shown / 100.0, 0.0, 1.0), bar.size.y)), col.darkened(0.12))
	for k in range(1, 10):                         # 刻度
		var x := w * k / 10.0
		draw_line(Vector2(x, bar.end.y - 6), Vector2(x, bar.end.y), Color(Palette.TEXT_DIM, 0.4), 1.0)
	var lx := w * line / 100.0
	draw_line(Vector2(lx, bar.position.y - 6), Vector2(lx, bar.end.y + 6), Palette.CINNABAR, 3.0)
	var danger := Rect2(Vector2(lx, bar.position.y), Vector2(w - lx, bar.size.y)) if danger_above \
			else Rect2(bar.position, Vector2(lx, bar.size.y))
	draw_rect(danger, Color(Palette.CINNABAR, 0.14))
	var lw := _serif.get_string_size(line_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var tx := clampf(lx - lw / 2.0, 0.0, w - lw)
	draw_string(_serif, Vector2(tx, bar.end.y + 26), line_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.CINNABAR.lightened(0.15))
