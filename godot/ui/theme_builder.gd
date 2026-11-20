class_name ThemeBuilder
## 全局主题：终端深色底 + 宣纸/鎏金点缀。
## 字体：打包的 Noto Serif SC / Noto Sans SC 子集（OFL 授权，见 assets/fonts/），保留字重轴，
## 所有平台（含网页版）显示一致。由 tools/subset_fonts.py 生成，新增大量文案后需重新裁剪。

const SERIF_FILE := "res://assets/fonts/NotoSerifSC-subset.ttf"
const SANS_FILE := "res://assets/fonts/NotoSansSC-subset.ttf"
## 字体族标识（保持旧接口：font(ThemeBuilder.SANS, 700) 等写法不变）
const SERIF := ["serif"]
const SANS := ["sans"]
const MONO := ["mono"]

static var _files := {}
static var _cache := {}


static func _file(path: String) -> FontFile:
	if not _files.has(path):
		_files[path] = load(path)
	return _files[path]


static func _tag(name: String) -> int:
	return TextServerManager.get_primary_interface().name_to_tag(name)


## 指定字体族与字重；宋体缺字时回落到黑体；mono 为黑体 + 等宽数字（tnum）
static func font(family: Array, weight := 400) -> Font:
	var key := "%s/%d" % [family[0], weight]
	if _cache.has(key):
		return _cache[key]
	var fv := FontVariation.new()
	fv.base_font = _file(SERIF_FILE if family == SERIF else SANS_FILE)
	fv.variation_opentype = {_tag("wght"): weight}
	if family == MONO:
		fv.opentype_features = {_tag("tnum"): 1}
	if family == SERIF:
		fv.fallbacks = [font(SANS, weight)]
	_cache[key] = fv
	return fv


static func serif(weight := 400) -> Font:
	return font(SERIF, weight)


## 等宽数字
static func mono() -> Font:
	return font(MONO, 500)


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
