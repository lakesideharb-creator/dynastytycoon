extends PanelContainer
## 高管卡：立绘（按状态切换表情）+ 姓名/岗位/门派 + 适岗分 + 压力/忠诚条

const PORTRAIT := "res://assets/portraits/%s_%s.png"
const GATE_ICON := "res://assets/icons/gate_%s.png"
const MOOD_TEXT := {"neutral": "", "pleased": "顺心", "stressed": "疲惫", "angry": "冲突"}
const MOOD_COLOR := {"pleased": Palette.JADE, "stressed": Palette.AMBER, "angry": Palette.CINNABAR}

var _portrait: TextureRect
var _name: Label
var _role: Label
var _gate: TextureRect
var _score: Label
var _mood: Label
var _stress: ProgressBar
var _loyalty: ProgressBar
var _mood_id := ""


func _init() -> void:
	custom_minimum_size = Vector2(300, 0)
	add_theme_stylebox_override("panel", ThemeBuilder.box(Color("#12171E"), Palette.TERMINAL_LINE, 1, 8, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ThemeBuilder.box(Palette.PAPER.darkened(0.08), Palette.GOLD.darkened(0.3), 1, 6, 0))
	row.add_child(frame)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(112, 112)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_portrait)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	info.add_child(head)
	_gate = TextureRect.new()
	_gate.custom_minimum_size = Vector2(30, 30)
	_gate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_gate)
	_name = ThemeBuilder.label("", 24, Palette.PAPER, ThemeBuilder.serif(700))
	head.add_child(_name)
	_mood = ThemeBuilder.label("", 16, Palette.AMBER)
	head.add_child(_mood)
	_role = ThemeBuilder.label("", 17, Palette.TEXT_DIM)
	info.add_child(_role)
	_score = ThemeBuilder.label("", 17, Palette.GOLD)
	info.add_child(_score)
	_stress = _bar(info, "压力", Palette.CINNABAR)
	_loyalty = _bar(info, "忠诚", Palette.JADE)


func _bar(parent: Control, caption: String, color: Color) -> ProgressBar:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	parent.add_child(h)
	h.add_child(ThemeBuilder.label(caption, 15, Palette.TEXT_DIM))
	var b := ProgressBar.new()
	b.max_value = 100
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 10)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("fill", ThemeBuilder.box(color, Color.TRANSPARENT, 0, 3, 0))
	h.add_child(b)
	return b


## mood：neutral / pleased / stressed / angry
func show_exec(e: Executive, score: float, mood: String) -> void:
	_name.text = e.name
	_role.text = "%s · %s" % [RoleNames.cn(e.role), e.gate_name]
	_score.text = "适岗 %.2f" % score
	_stress.value = e.stress
	_loyalty.value = e.loyalty
	var gate_path := GATE_ICON % e.gate_id
	_gate.texture = load(gate_path) if ResourceLoader.exists(gate_path) else null
	_mood.text = MOOD_TEXT.get(mood, "")
	_mood.add_theme_color_override("font_color", MOOD_COLOR.get(mood, Palette.TEXT_DIM))
	if mood == _mood_id:
		return
	_mood_id = mood
	var path := PORTRAIT % [e.portrait, mood]
	if not ResourceLoader.exists(path):
		path = PORTRAIT % [e.portrait, "neutral"]
	if not ResourceLoader.exists(path):                 # 人才市场通用头像只有一张（talent_{门派}_{m|f}.png）
		path = "res://assets/portraits/%s.png" % e.portrait
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
		_portrait.modulate = Color(1, 1, 1, 0.3)
		create_tween().tween_property(_portrait, "modulate:a", 1.0, 0.35)
