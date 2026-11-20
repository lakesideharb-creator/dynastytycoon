extends "res://ui/dialogs/modal.gd"
## 存档列表：mode = "save"（手动三格）或 "load"（含自动存档）

signal slot_chosen(slot: String)

var mode := "load"


func _ready() -> void:
	esc_closes = true
	card.custom_minimum_size = Vector2(980, 0)
	body.add_child(ink_label("保存进度" if mode == "save" else "读取存档", 34, INK_TEXT, 900))
	var i := 0
	for slot in SaveGame.SLOTS:
		if mode == "save" and slot == "autosave":
			continue
		i += 1
		var s := SaveGame.summary(slot)
		var text: String = s["name"] + "　"
		if s["exists"]:
			var when: String = s["saved_at"].replace("T", " ").substr(5, 11)     # MM-DD HH:MM
			text += "%s\n　　%s · 第%d/%d月 · 现金 %s · %s" % [
				_short_title(s["title"]), s["date"], s["turn"], s["duration"], Money.short(s["cash"]), when]
		else:
			text += "（空）"
		var enabled: bool = mode == "save" or s["exists"]
		var key := str(i)
		var b := option_button(key, text, enabled)
		b.add_theme_font_override("font", ThemeBuilder.font(ThemeBuilder.SANS, 700))
		b.custom_minimum_size = Vector2(0, 78)
		var sl: String = slot
		b.pressed.connect(func():
			Audio.sfx("ui_confirm")
			slot_chosen.emit(sl)
			close())
		body.add_child(b)
	var back := option_button("", "返回")
	back.pressed.connect(close)
	body.add_child(back)
	super._ready()


func _short_title(t: String) -> String:
	var k := t.find("：")
	return t.substr(k + 1) if k >= 0 else t
