extends "res://ui/dialogs/modal.gd"
## 开局：关卡背景 + 通关目标 + 开局三选一

signal chosen(key: String)

var meta: Dictionary


func _ready() -> void:
	card.custom_minimum_size = Vector2(1120, 0)
	body.add_child(ink_label(meta.get("methodology", ""), 19, Palette.GOLD.darkened(0.3), 700))
	body.add_child(ink_label(meta["title"], 34, INK_TEXT, 900))
	var brief := ink_label(meta.get("brief", ""), 21, Color(INK_TEXT, 0.88))
	brief.custom_minimum_size = Vector2(1064, 0)
	body.add_child(brief)
	var goal := ink_label("通关目标：" + meta.get("win_condition_text", ""), 21, Palette.CINNABAR, 700)
	goal.custom_minimum_size = Vector2(1064, 0)
	body.add_child(goal)
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", ThemeBuilder.box(Palette.GOLD, Color.TRANSPARENT, 0, 0, 1))
	body.add_child(sep)
	body.add_child(ink_label("董事长，请下达开局决断：", 22, INK_TEXT, 700))
	var choices: Dictionary = meta.get("choices", {})
	for key in meta["main_choices"]:
		var name: String = choices.get(key, {}).get("name", meta["main_choices"][key]["result"])
		var b := option_button(key, name)
		var k: String = key
		b.pressed.connect(func():
			Audio.sfx("ui_confirm")
			chosen.emit(k)
			close())
		body.add_child(b)
	super._ready()
