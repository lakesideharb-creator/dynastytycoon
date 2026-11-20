extends Node
## 全局设置（自动加载为 Settings，排在 Audio 之后）：音量、全屏、自动存档；保存在 user://settings.cfg

signal changed

const PATH := "user://settings.cfg"

var music := 0.8          ## 0–1
var sfx := 0.9            ## 0–1
var fullscreen := false
var autosave := true


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		music = clampf(float(cfg.get_value("audio", "music", music)), 0.0, 1.0)
		sfx = clampf(float(cfg.get_value("audio", "sfx", sfx)), 0.0, 1.0)
		fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
		autosave = bool(cfg.get_value("game", "autosave", autosave))
	apply()


func apply() -> void:
	_bus("Music", music)
	_bus("SFX", sfx)
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
	changed.emit()


func _bus(bus_name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("game", "autosave", autosave)
	cfg.save(PATH)


func set_value(key: String, value) -> void:
	set(key, value)
	apply()
	save()
