extends "res://ui/dialogs/modal.gd"
## 战役中的系统菜单（Esc）：继续 / 保存 / 读取 / 设置 / 返回标题

signal save_requested
signal load_requested
signal settings_requested
signal title_requested

var allow_save := true          ## 危机公关等不支持存档的模式设为 false


func _ready() -> void:
	esc_closes = true
	card.custom_minimum_size = Vector2(560, 0)
	body.add_child(ink_label("董事长办公室", 34, INK_TEXT, 900))
	for item in [["1", "继续经营", ""], ["2", "保存进度", "save_requested"], ["3", "读取存档", "load_requested"],
			["4", "设置", "settings_requested"], ["5", "返回标题", "title_requested"]]:
		var b := option_button(item[0], item[1])
		var sig: String = item[2]
		if not allow_save and sig in ["save_requested", "load_requested"]:
			continue
		b.pressed.connect(func():
			close()
			if sig != "":
				emit_signal(sig))
		body.add_child(b)
	var hint := ink_label("快捷键：空格 推进本月　F 风水工位　Esc 本菜单" if allow_save else "危机公关为一局 24 小时的短战，不支持存档。快捷键：1/2/3 下达决断　Esc 本菜单", 17, Color(INK_TEXT, 0.6), 400)
	hint.custom_minimum_size = Vector2(500, 0)
	body.add_child(hint)
	super._ready()
