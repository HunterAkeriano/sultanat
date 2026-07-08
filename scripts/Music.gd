extends Node
## Music — фоновая музыка (зациклена, тихая). Автозагрузка: живёт всё время,
## не пересоздаётся при перестройке интерфейса. Громкость задаётся VOLUME_DB.

const TRACK := "res://assets/audio/ambient_ramadan.mp3"
const VOLUME_DB := -20.0   # тихий фон (чем меньше, тем тише; -80 = тишина)

const CFG_PATH := "user://audio.cfg"

var _player: AudioStreamPlayer
var enabled: bool = true   # по умолчанию музыка ВКЛЮЧЕНА (первый запуск); дальше — сохранённый выбор игрока

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
	# На первом запуске музыка играет; если игрок уже когда-то её выключил —
	# уважаем сохранённый выбор.
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		enabled = bool(cfg.get_value("audio", "music", true))
	if enabled and _player.stream != null:
		_player.play()

func _on_finished() -> void:
	if enabled and _player != null:
		_player.play()

func set_enabled(on: bool) -> void:
	enabled = on
	# Запоминаем выбор между запусками
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("audio", "music", on)
	cfg.save(CFG_PATH)
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
