extends Node
## Notifications — локальные пуш-уведомления, когда игрок НЕ в игре.
## При сворачивании приложения планируем серию напоминаний, при возврате — отменяем.
##
## Показ делает плагин «Notification Scheduler» (godot-mobile-plugins).
## Установка: AssetLib в редакторе → "NotificationScheduler" → Download →
## Install в корень проекта → включить в Project Settings → Plugins.
## Также нужен Android Gradle Build (см. README плагина).
## Без плагина этот код тихо бездействует (в редакторе/на ПК — тоже).

const CHANNEL_ID := "sotc_reminders"
const NOTIF_IDS := [101, 102, 103, 104]

# Пул флейвор-фраз для напоминаний (кроме уведомления о заряде батареи).
# Тексты живут в Loc; выбираются случайно и не повторяются в одной серии.
const FLAVOR_KEYS := [
	"notif.day1", "notif.day2", "notif.day3", "notif.day4",
	"notif.day5", "notif.day6", "notif.day7", "notif.day8", "notif.day9",
]

var _sched: Node = null            # узел NotificationScheduler из аддона
var _cls_channel: Script = null    # класс NotificationChannel (билдер)
var _cls_data: Script = null       # класс NotificationData (билдер)

func _ready() -> void:
	# Классы аддона ищем по глобальному списку script-классов —
	# так не зависим от точного пути установки.
	var cls_sched := _global_class("NotificationScheduler")
	_cls_channel = _global_class("NotificationChannel")
	_cls_data = _global_class("NotificationData")
	if cls_sched == null:
		return
	_sched = cls_sched.new()
	add_child(_sched)
	# Разрешение на уведомления (Android 13+)
	if _sched.has_method("has_post_notifications_permission") \
			and not _sched.has_post_notifications_permission():
		if _sched.has_method("request_post_notifications_permission"):
			_sched.request_post_notifications_permission()
	# Канал уведомлений (Android 8+)
	if _cls_channel != null and _sched.has_method("create_notification_channel"):
		var ch = _cls_channel.new()
		_b(ch, "set_id", CHANNEL_ID)
		_b(ch, "set_name", "Напоминания")
		_b(ch, "set_description", "Империя зовёт султана")
		if ch.has_method("set_importance"):
			ch.set_importance(3)
		_sched.create_notification_channel(ch)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_schedule_all()
		NOTIFICATION_APPLICATION_RESUMED:
			_cancel_all()

func _schedule_all() -> void:
	if _sched == null or _cls_data == null:
		return
	_cancel_all()
	var title := "Закат Полумесяца"
	# 1) Батарея зарядилась — ровно к моменту полного заряда
	if GameState.energy_recharging and not GameState.energy_unlimited():
		var sec := int(ceil(GameState.energy_full_in_sec()))
		if sec > 60:
			_schedule(NOTIF_IDS[0], title, Loc.t("notif.energy"), sec)
	# 2..4) Три «зова империи» на разное время. Каждое сообщение — случайная
	# фраза из FLAVOR_KEYS (без повторов в серии), задержка тоже слегка «дышит»,
	# чтобы уведомления не приходили одинаково у всех игроков.
	var pool := FLAVOR_KEYS.duplicate()
	pool.shuffle()
	# Слот 1: ~4–8 часов (первое напоминание в тот же день)
	var t1 := randi_range(4 * 3600, 8 * 3600)
	# Слот 2: ~24 часа ± 3 часа (следующий день)
	var t2 := 24 * 3600 + randi_range(-3 * 3600, 3 * 3600)
	# Слот 3: ~48 часов ± 6 часов (через два дня — самое тревожное)
	var t3 := 48 * 3600 + randi_range(-6 * 3600, 6 * 3600)
	_schedule(NOTIF_IDS[1], title, Loc.t(str(pool[0])), t1)
	_schedule(NOTIF_IDS[2], title, Loc.t(str(pool[1])), t2)
	_schedule(NOTIF_IDS[3], title, Loc.t(str(pool[2])), t3)

func _schedule(id: int, title: String, text: String, delay_sec: int) -> void:
	var d = _cls_data.new()
	_b(d, "set_id", id)
	_b(d, "set_channel_id", CHANNEL_ID)
	_b(d, "set_title", title)
	_b(d, "set_content", text)
	_b(d, "set_small_icon_name", "ic_notification")
	# Имя сеттера задержки менялось между версиями — пробуем известные
	for m in ["set_delay", "set_delay_seconds", "set_initial_delay"]:
		if d.has_method(m):
			d.call(m, delay_sec)
			break
	if _sched.has_method("schedule"):
		_sched.schedule(d)
	elif _sched.has_method("schedule_notification"):
		_sched.schedule_notification(d)

func _cancel_all() -> void:
	if _sched == null:
		return
	for id in NOTIF_IDS:
		for m in ["cancel", "cancel_notification"]:
			if _sched.has_method(m):
				_sched.call(m, id)
				break

# ── Утилиты ──
func _global_class(nm: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == nm:
			return load(str(c.get("path", "")))
	return null

func _b(obj: Object, method: String, val) -> void:
	if obj.has_method(method):
		obj.call(method, val)
