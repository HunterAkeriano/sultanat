extends Node
## Voice — озвучка событий. Проигрывает тело события (ev_<id>_body.mp3) при
## открытии письма, чуть тише обычного и с лёгким приглушением фоновой музыки.
## Файлы, которых ещё нет, просто пропускаются.

const DIR := "res://assets/audio/events/"
const VOLUME_DB := -7.0          # «чуть тише» (меньше число — тише)
const MUSIC_DUCK_DB := -30.0     # фоновая музыка приглушается на время речи
const MUSIC_NORMAL_DB := -20.0   # обычная громкость музыки

var _player: AudioStreamPlayer
var enabled: bool = true

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_player.finished.connect(_on_finished)

func play_event_body(id: String) -> void:
	if id == "":
		return
	play_clip(DIR + "ev_%s_body.mp3" % id)

func play_clip(path: String) -> void:
	# Универсальное воспроизведение озвучки (тело события, гонец и т.п.).
	if not enabled or path == "":
		return
	if not ResourceLoader.exists(path):
		return                       # файла ещё нет — просто молчим
	var stream = load(path)
	if "loop" in stream:
		stream.loop = false
	_player.stream = stream
	_duck(true)
	_player.play()

func stop() -> void:
	if _player != null and _player.playing:
		_player.stop()
	_duck(false)

func _on_finished() -> void:
	_duck(false)

func _duck(on: bool) -> void:
	var m := get_node_or_null("/root/Music")
	if m != null:
		m.set_volume_db(MUSIC_DUCK_DB if on else MUSIC_NORMAL_DB)

func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		stop()
