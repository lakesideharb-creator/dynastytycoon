extends Control
## 应用入口：在标题画面与战役画面之间切换

const TitleScreen := preload("res://ui/title_screen.gd")
const CampaignScreen := preload("res://ui/campaign_screen.gd")

var _screen: Control


func _ready() -> void:
	theme = ThemeBuilder.build()
	var bg := ColorRect.new()
	bg.color = Palette.TERMINAL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	show_title()


func _swap(next: Control) -> void:
	if _screen:
		_screen.queue_free()
	_screen = next
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)


func show_title() -> void:
	var t := TitleScreen.new()
	t.campaign_selected.connect(start_campaign)
	t.load_requested.connect(load_slot)
	_swap(t)
	Audio.play_music("theme_main")


func start_campaign(scenario_id: int, restore := {}) -> void:
	var c := CampaignScreen.new()
	c.scenario_id = scenario_id
	c.restore = restore
	c.exit_requested.connect(show_title)
	c.restart_requested.connect(func(): start_campaign(scenario_id))
	c.load_requested.connect(load_slot)
	_swap(c)


func load_slot(slot: String) -> void:
	var data := SaveGame.load_slot(slot)
	if data.is_empty():
		push_warning("存档无法读取：" + slot)
		return
	start_campaign(data["runner"].scenario_id, data)
