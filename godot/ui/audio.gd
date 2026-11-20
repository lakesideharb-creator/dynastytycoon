extends Node
## 全局音频（自动加载为 Audio）
## 音乐：两个播放器交替、换曲时交叉淡入淡出（思路沿用 Ninefold Gate 的 MusicPlayer）
## 音效：小型播放器池，同一音效可叠放
## 资源：res://assets/music/{id}.ogg、res://assets/sfx/{id}.ogg（已统一到 -14 LUFS，见 tools/audio_master.py）

const MUSIC_DIR := "res://assets/music/%s.ogg"
const SFX_DIR := "res://assets/sfx/%s.ogg"
const MUSIC_DB := -4.0
const SFX_DB := -2.0
const SEASON_TRACK := {
	"Spring": "season_spring_wood", "Summer": "season_summer_fire",
	"Autumn": "season_autumn_metal", "Winter": "season_winter_water",
}
const STING_TRACKS := ["sting_victory", "sting_defeat", "sting_bankrupt"]

var current := ""
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _sfx: Array[AudioStreamPlayer] = []
var _cache := {}


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	for i in 8:
		var s := AudioStreamPlayer.new()
		s.bus = "SFX"
		s.volume_db = SFX_DB
		add_child(s)
		_sfx.append(s)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## 换到某首曲子（同一首不打断）；短曲（结局）不循环
func play_music(track: String, fade := 1.8) -> void:
	if track == current:
		return
	var stream := _stream(MUSIC_DIR % track) as AudioStreamOggVorbis
	if stream == null:
		push_warning("缺少音乐：" + track)
		return
	stream.loop = not (track in STING_TRACKS)
	current = track
	var old := _music[_active]
	_active = 1 - _active
	var nxt := _music[_active]
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(nxt, "volume_db", MUSIC_DB, fade).set_ease(Tween.EASE_OUT)
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, fade).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(old.stop)


func play_season(season_key: String) -> void:
	play_music(SEASON_TRACK.get(season_key, "theme_main"))


func stop_music(fade := 1.5) -> void:
	current = ""
	for p in _music:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, fade)
			tw.tween_callback(p.stop)


func sfx(id: String, volume_offset := 0.0) -> void:
	var stream := _stream(SFX_DIR % id)
	if stream == null:
		push_warning("缺少音效：" + id)
		return
	for p in _sfx:
		if not p.playing:
			p.stream = stream
			p.volume_db = SFX_DB + volume_offset
			p.play()
			return
	_sfx[0].stream = stream          # 全忙时抢占最早的
	_sfx[0].play()


## 按钮统一接上点击/悬停音
func wire_button(b: BaseButton) -> void:
	b.pressed.connect(func(): sfx("ui_click"))
	b.mouse_entered.connect(func():
		if not b.disabled:
			sfx("ui_hover", -4.0))
