extends Node
## Sfx — звуковые эффекты интерфейса. Звуки проигрываются точечно:
##   Sfx.click()    — кнопка «Вложить»  (ui_click.mp3)
##   Sfx.suppress() — кнопка «Подавить» (suppress.mp3)
## Файлы кладутся в assets/audio/; пока какого-то нет — просто тишина.

const VOLUME_DB := 12.0
const CLICK := "res://assets/audio/ui_click.mp3"
const SUPPRESS := "res://assets/audio/suppress.mp3"
const CHOICE := "res://assets/audio/event_choice.mp3"
const BUY_FOOD := "res://assets/audio/buy_food.mp3"
const UPGRADE := "res://assets/audio/upgrade_granary.mp3"
const OPEN_LETTER := "res://assets/audio/open_letter.mp3"
const PAGE_FLIP := "res://assets/audio/page_flip.mp3"
const RESTART := "res://assets/audio/restart.mp3"
const FRENZY_WHOOSH := "res://assets/audio/frenzy_whoosh.mp3"

var enabled: bool = true
var _player: AudioStreamPlayer
var _frenzy_player: AudioStreamPlayer   # отдельный канал для тапов в раже,
                                        # чтобы не срезать другие UI-звуки
var _cache := {}

# Индивидуальная громкость отдельных звуков (по умолчанию — VOLUME_DB).
# Монеты и стройка сделаны тише остальных.
var _vol := {
	CLICK: 4.0,
	SUPPRESS: 4.0,
	BUY_FOOD: 0.0,
	UPGRADE: 0.0,
	OPEN_LETTER: 2.0,
	PAGE_FLIP: -6.0,
	RESTART: 2.0,
	FRENZY_WHOOSH: -18.0,   # ощутимо тише — 60 «свистов» за 30 секунд не должны резать уши
}

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_frenzy_player = AudioStreamPlayer.new()
	_frenzy_player.bus = "Master"
	_frenzy_player.volume_db = _vol[FRENZY_WHOOSH]
	add_child(_frenzy_player)

func _get_stream(path: String):
	if _cache.has(path):
		return _cache[path]
	if ResourceLoader.exists(path):
		var s = load(path)
		if "loop" in s:
			s.loop = false
		_cache[path] = s
		return s
	return null

func play(path: String) -> void:
	if not enabled:
		return
	var s = _get_stream(path)
	if s == null:
		return
	_player.volume_db = _vol.get(path, VOLUME_DB)
	_player.stream = s
	_player.play()

func click() -> void:
	play(CLICK)

func suppress() -> void:
	play(SUPPRESS)

func choice() -> void:
	play(CHOICE)

func buy_food() -> void:
	play(BUY_FOOD)

func upgrade() -> void:
	play(UPGRADE)

func open_letter() -> void:
	play(OPEN_LETTER)

func page_flip() -> void:
	play(PAGE_FLIP)

func restart() -> void:
	play(RESTART)

const FRENZY_WHOOSH_INTERVAL := 0.18   # минимум сек между свистами (был 0.35 — слишком редко)

var _last_whoosh_ts: float = 0.0

# Свист касания в раже. Играется на отдельном плеере, чтобы быстрые тапы
# не резали друг друга (обычный play() перезапускает единственный поток).
# Дополнительно ограничен по частоте: даже при 10 тапах/сек звучит не чаще
# ~3 раз в секунду, иначе свисты накладываются друг на друга и превращаются в шум.
func frenzy_whoosh() -> void:
	if not enabled:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_whoosh_ts < FRENZY_WHOOSH_INTERVAL:
		return
	_last_whoosh_ts = now
	var s = _get_stream(FRENZY_WHOOSH)
	if s == null:
		return
	_frenzy_player.stream = s
	# Лёгкий разброс высоты, чтобы свисты не сливались в один шум
	_frenzy_player.pitch_scale = randf_range(0.94, 1.08)
	_frenzy_player.play()

func set_enabled(on: bool) -> void:
	enabled = on
