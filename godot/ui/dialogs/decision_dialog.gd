extends "res://ui/dialogs/modal.gd"
## 董事会紧急议题：决策卡插画 + 情境 + 选项（缺门派高管/现金不足的选项置灰并说明原因）

signal chosen(key: String)

var event: Dictionary
var runner: CampaignRunner


func _ready() -> void:
	card.custom_minimum_size = Vector2(1080, 0)
	var head := HBoxContainer.new()
	body.add_child(head)
	head.add_child(ink_label("董事会紧急议题", 20, Palette.CINNABAR, 700, false))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(ink_label("第 %d 月" % runner.turn, 20, Color(INK_TEXT, 0.6), 400, false))

	var art_path := "res://assets/events/%s.png" % event["id"]
	if ResourceLoader.exists(art_path):
		var art := TextureRect.new()
		art.texture = load(art_path)
		art.custom_minimum_size = Vector2(1024, 300)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.clip_contents = true
		body.add_child(art)

	body.add_child(ink_label(event["title"], 32, INK_TEXT, 900))
	var desc := ink_label(event["desc"], 21, Color(INK_TEXT, 0.85))
	desc.custom_minimum_size = Vector2(1024, 0)
	body.add_child(desc)
	for opt in event["options"]:
		var avail := runner.option_available(opt)
		var b := option_button(opt["key"], opt["label"], avail["ok"], avail["reason"])
		var key: String = opt["key"]
		b.pressed.connect(func():
			Audio.sfx("ui_confirm")
			chosen.emit(key)
			close())
		body.add_child(b)
	super._ready()
	Audio.sfx("decision_open")
