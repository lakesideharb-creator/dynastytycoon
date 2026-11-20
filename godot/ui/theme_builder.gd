class_name ThemeBuilder
## 全局主题：终端深色底 + 宣纸/鎏金点缀。
## 字体暂用系统宋体/苹方（SystemFont），网页导出前需改为打包的 Noto Serif SC（见 godot/README.md）。

## 注意：macOS 上 "PingFang SC" 会解析成 PingFang HK（缺简体字，如"杂"），因此不用苹方
const SERIF := ["Songti SC", "STSong", "Noto Serif SC", "Source Han Serif SC", "SimSun"]
const SANS := ["Hiragino Sans GB", "STHeiti", "Heiti SC", "Noto Sans SC", "Microsoft YaHei"]
const MONO := ["Menlo", "Monaco", "Consolas", "DejaVu Sans Mono"]

static var _sans_fallback: SystemFont


## 主字体 + 显式回落到简体中文黑体（避免系统自动回落到繁体字体）
static func font(names: Array, weight := 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	if names != SANS:
		if _sans_fallback == null:
			_sans_fallback = SystemFont.new()
			_sans_fallback.font_names = PackedStringArray(SANS)
		f.fallbacks = [_sans_fallback]
	return f


static func serif(weight := 400) -> SystemFont:
	return font(SERIF, weight)


## 等宽数字，中文回落到黑体
static func mono() -> SystemFont:
	return font(MONO, 400)


static func box(bg: Color, border := Color.TRANSPARENT, border_w := 0, radius := 6, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font(SANS)
	t.default_font_size = 22

	t.set_color("font_color", "Label", Palette.TEXT)
	t.set_stylebox("panel", "PanelContainer", box(Palette.TERMINAL_PANEL, Palette.TERMINAL_LINE, 1, 8, 16))

	t.set_font("normal_font", "RichTextLabel", font(SANS))
	t.set_font("bold_font", "RichTextLabel", font(SANS, 700))
	t.set_font("mono_font", "RichTextLabel", mono())
	t.set_color("default_color", "RichTextLabel", Palette.TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 20)
	t.set_font_size("bold_font_size", "RichTextLabel", 20)
	t.set_font_size("mono_font_size", "RichTextLabel", 20)
	t.set_constant("line_separation", "RichTextLabel", 7)

	t.set_font("font", "Button", serif(700))
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_color", "Button", Palette.TEXT)
	t.set_color("font_hover_color", "Button", Palette.PAPER)
	t.set_color("font_pressed_color", "Button", Palette.AMBER)
	t.set_color("font_disabled_color", "Button", Palette.TEXT_DIM)
	t.set_stylebox("normal", "Button", box(Color("#1E252F"), Palette.GOLD.darkened(0.35), 1, 6, 12))
	t.set_stylebox("hover", "Button", box(Color("#28313D"), Palette.GOLD, 1, 6, 12))
	t.set_stylebox("pressed", "Button", box(Color("#12171D"), Palette.AMBER, 2, 6, 12))
	t.set_stylebox("disabled", "Button", box(Color("#161A20"), Palette.TERMINAL_LINE, 1, 6, 12))
	t.set_stylebox("focus", "Button", box(Color.TRANSPARENT, Palette.AMBER, 2, 6, 12))

	t.set_stylebox("slider", "HSlider", box(Palette.TERMINAL_LINE, Color.TRANSPARENT, 0, 3, 3))
	t.set_stylebox("grabber_area", "HSlider", box(Palette.GOLD.darkened(0.2), Color.TRANSPARENT, 0, 3, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Palette.GOLD, Color.TRANSPARENT, 0, 3, 3))

	t.set_stylebox("background", "ProgressBar", box(Color("#0B0E12"), Palette.TERMINAL_LINE, 1, 3, 0))
	t.set_stylebox("fill", "ProgressBar", box(Palette.GOLD, Color.TRANSPARENT, 0, 3, 0))
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("separation", "VBoxContainer", 10)
	return t


## 小工具：带字号/颜色/字体的标签
static func label(text: String, size := 20, color := Palette.TEXT, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if f:
		l.add_theme_font_override("font", f)
	return l
