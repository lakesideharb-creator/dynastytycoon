extends Control
## 模态对话框基类：压暗背景 + 居中宣纸卡片（决策层用宣纸、经营层用终端，两层视觉区分）

const INK_TEXT := Color("#2A241C")

var card: PanelContainer
var body: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeBuilder.box(Palette.PAPER, Palette.GOLD, 2, 10, 28))
	center.add_child(card)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	card.add_child(body)


func _ready() -> void:
	card.modulate = Color(1, 1, 1, 0)
	card.pivot_offset = card.size / 2
	card.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel()
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func ink_label(text: String, size := 22, color := INK_TEXT, weight := 400, wrap := true) -> Label:
	var l := ThemeBuilder.label(text, size, color, ThemeBuilder.serif(weight))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## 含金额/符号的文字用黑体（宋体的 ¥ 字形为空白）
func sans_label(text: String, size := 22, color := INK_TEXT, weight := 400) -> Label:
	var l := ThemeBuilder.label(text, size, color, ThemeBuilder.font(ThemeBuilder.SANS, weight))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## 宣纸风格选项按钮：左侧字母徽记 + 文字；不可选时显示原因
func option_button(key: String, text: String, enabled := true, reason := "") -> Button:
	var b := Button.new()
	b.text = ("  %s   " % key if key else "  ") + text + (("    （%s）" % reason) if reason else "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_override("font", ThemeBuilder.serif(700))
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", INK_TEXT)
	b.add_theme_color_override("font_hover_color", Palette.CINNABAR)
	b.add_theme_color_override("font_pressed_color", Palette.CINNABAR)
	b.add_theme_color_override("font_disabled_color", Color(INK_TEXT, 0.4))
	b.add_theme_stylebox_override("normal", ThemeBuilder.box(Palette.PAPER.darkened(0.05), Palette.GOLD.darkened(0.2), 1, 6, 12))
	b.add_theme_stylebox_override("hover", ThemeBuilder.box(Palette.PAPER.lightened(0.3), Palette.CINNABAR, 2, 6, 12))
	b.add_theme_stylebox_override("pressed", ThemeBuilder.box(Palette.PAPER.darkened(0.12), Palette.CINNABAR, 2, 6, 12))
	b.add_theme_stylebox_override("disabled", ThemeBuilder.box(Palette.PAPER.darkened(0.1), Color(INK_TEXT, 0.15), 1, 6, 12))
	b.add_theme_stylebox_override("focus", ThemeBuilder.box(Color.TRANSPARENT, Palette.CINNABAR, 2, 6, 12))
	Audio.wire_button(b)
	return b


func close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)
