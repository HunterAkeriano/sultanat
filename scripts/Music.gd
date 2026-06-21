extends Node
## Music — фоновая музыка (зациклена, тихая). Автозагрузка: живёт всё время,
## не пересоздаётся при перестройке интерфейса. Громкость задаётся VOLUME_DB.

const TRACK := "res://assets/audio/ambient_ramadan.mp3"
const VOLUME_DB := -20.0   # тихий фон (чем меньше, тем тише; -80 = тишина)

var _player: AudioStreamPlayer
var enabled: bool = true

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = VOLUME_DB
	add_child(_player)
	if ResourceLoader.exists(TRACK):
		var stream = load(TRACK)
		# Зацикливание: у MP3/OGG в Godot 4 есть свойство loop.
		if "loop" in stream:
			stream.loop = true
		_player.stream = stream
		# Подстраховка: если поток не зациклится сам — перезапустим по окончании.
		_player.finished.connect(_on_finished)
		_player.play()

func _on_finished() -> void:
	if enabled and _player != null:
		_player.play()

func set_enabled(on: bool) -> void:
	enabled = on
	if _player == null:
		return
	if on:
		if not _player.playing:
			_player.play()
	else:
		_player.stop()

func set_volume_db(db: float) -> void:
	if _player != null:
		_player.volume_db = db
