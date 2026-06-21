extends Node
## GameState — живое состояние партии + симуляция (ТЗ §24.4 тик, §27 формулы,
## §26 сохранения). Data-driven: правила здесь, контент в GameData.

const SAVE_PATH := "user://sotc_save.json"
const OFFLINE_CAP_SEC := 8 * 3600.0   # потолок офлайн-дохода — 8 часов

signal notify(text: String, good: bool)     # всплывающая обратная связь (§21.5)
signal event_started
signal event_resolved
signal reign_changed
signal coup_triggered                        # переворот: игра окончена, нужен рестарт

# ── Видимые ресурсы (HUD, §8 / макет §21.4.1) ─────────────────────
var hazna: float = 50.0
var stability: float = 64.0
var army: float = 58.0
var loyalty: float = 60.0
# Вспомогательные (в тексте/тултипах)
var legitimacy: float = 55.0
var external_pressure: float = 22.0
# Новые ресурсы кризис-слоя
var food: float = 62.0          # запас продовольствия (мало → бунты, нестабильность)
var opposition: float = 14.0    # сила оппозиции (100 → переворот)
var food_tool_level: int = 0    # улучшения амбаров/инструментов (дешевле закупка еды)
var game_over: bool = false     # переворот: игра заморожена до рестарта

var hazna_per_click: float = 1.0
var tap_count: int = 0          # всего касаний Печати (счётчик кликов)

# ── Провинции / институты / реформа ───────────────────────────────
var provinces: Array = []          # рабочие копии GameData.PROVINCES + состояние
var institutions: Dictionary = {}  # id -> level
var reform_progress: float = 42.0  # Низам-ı Джедид (макет показывает 42%)
var reform_done: bool = false

# ── Мета (сохраняется между правлениями) ──────────────────────────
var imperial_prestige: int = 0
var decrees_owned: Array = []
var sultan_index: int = 0

# ── Прочее ────────────────────────────────────────────────────────
var year: int = 1690
var _year_accum: float = 0.0
var lifetime_hazna: float = 0.0
var chronicle: Array = []          # {year,title,summary,chips}
var active_event = null            # текущий Имперский декрет или null
var _event_timer: float = 95.0
var _last_event_id: String = ""
var _save_accum: float = 0.0
var pending_offline: float = 0.0   # доход «пока тебя не было» (показать один раз)

func _ready() -> void:
	if not load_game():
		new_run(false)
	Loc.language_changed.connect(func(): pass)

# ════════════════════════════════════════════════════════════════
#  СИМУЛЯЦИЯ — тик (§24.4)
# ════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	# Авто-дохода нет — это кликер. Хазна растёт только от касаний Печати.
	# Тик отвечает лишь за «кризисный слой»: время, энтропию, трещины, реформу, события.
	if game_over:
		return                      # после переворота всё замирает до «Начать сначала»
	_advance_time(delta)
	_drift(delta)
	_grow_fractures(delta)
	_progress_reform(delta)

	# Очередь событий (§4.2 фаза событий). В кризис события учащаются.
	if active_event == null:
		var unrest := 1.0
		if food < 40.0:
			unrest += (40.0 - food) / 40.0 * 1.6     # голод → больше бунтов
		if opposition > 40.0:
			unrest += (opposition - 40.0) / 60.0 * 1.4
		if stability < 45.0:
			unrest += (45.0 - stability) / 45.0 * 1.0
		_event_timer -= delta * unrest
		if _event_timer <= 0.0:
			_try_spawn_event()

	# Автосейв ~ каждые 5 c (§26.1)
	_save_accum += delta
	if _save_accum >= 5.0:
		_save_accum = 0.0
		save_game()

func _advance_time(delta: float) -> void:
	# Год идёт медленно ради атмосферы (1 год ≈ 18 c реального времени).
	_year_accum += delta
	if _year_accum >= 18.0:
		_year_accum -= 18.0
		year += 1

func _drift(delta: float) -> void:
	# Энтропия: империя угасает сама по себе (§1.1).
	external_pressure = clampf(external_pressure + 0.03 * delta, 0.0, 100.0)
	var avg_fr := _avg_fracture()
	var decay := (external_pressure / 100.0) * 0.25 + (avg_fr / 100.0) * 0.30
	# Стабильность растёт от развития провинций и сытости, падает от давления/трещин.
	var growth := 0.02 + (_avg_development() / 100.0) * 0.16 + (food / 100.0) * 0.12
	stability = clampf(stability - decay * delta + growth * delta, 0.0, 100.0)
	# Лёгкое восстановление лояльности к равновесию
	loyalty = clampf(loyalty + (50.0 - loyalty) * 0.004 * delta, 0.0, 100.0)

	# ── Еда (§8): расходуется заметно быстрее. Развитые провинции кормят лучше,
	#    запущенные — голодают. Нехватку приходится докупать в Снабжении. ──
	var production := _avg_development() * 0.010 + provinces_alive() * 0.018
	var consumption := 0.55 + external_pressure * 0.005 + provinces_alive() * 0.03
	food = clampf(food + (production - consumption) * delta, 0.0, 100.0)
	# Голод бьёт по стабильности и кормит оппозицию (чем меньше еды — тем сильнее)
	if food < 45.0:
		var hunger := (45.0 - food) / 45.0
		stability = clampf(stability - hunger * 0.45 * delta, 0.0, 100.0)
		opposition = clampf(opposition + hunger * 0.30 * delta, 0.0, 100.0)
		loyalty = clampf(loyalty - hunger * 0.16 * delta, 0.0, 100.0)

	# ── Оппозиция (§: заговоры/перевороты) ──
	var opp_d := 0.03                                    # медленный естественный рост
	if stability < 50.0:
		# при низкой стабильности оппозиция растёт резко (0 стабильности → ~0.7/с)
		opp_d += (50.0 - stability) / 50.0 * 0.70
	if loyalty < 45.0:
		opp_d += (45.0 - loyalty) / 45.0 * 0.16
	if food < 35.0:
		opp_d += (35.0 - food) / 35.0 * 0.18
	# Чем выше стабильность — тем сильнее гаснет оппозиция (плавно)
	if stability > 60.0:
		opp_d -= (stability - 60.0) / 40.0 * 0.18
	# Сытость тоже успокаивает
	if food > 65.0:
		opp_d -= (food - 65.0) / 35.0 * 0.05
	opposition = clampf(opposition + opp_d * delta, 0.0, 100.0)
	if opposition >= 100.0:
		_coup()

func _coup() -> void:
	# Переворот: правление свергнуто — конец игры. Симуляция замирает до рестарта.
	if game_over:
		return
	game_over = true
	active_event = null
	notify.emit(Loc.t("sys.coup"), false)
	coup_triggered.emit()

func start_over() -> void:
	# Полный сброс прогресса (как «Начать сначала» после переворота).
	game_over = false
	reset_save()
	reign_changed.emit()

func _grow_fractures(delta: float) -> void:
	# Упрощённая формула роста трещин (§11.3).
	for p in provinces:
		if p.lost:
			continue
		var d_fr := 0.018
		d_fr += external_pressure / 2200.0
		d_fr += (1.0 - p.loyalty / 100.0) * 0.025
		d_fr -= p.development / 4000.0
		p.fracture = clampf(p.fracture + d_fr * delta, 0.0, 100.0)
		if p.fracture >= 100.0:
			_lose_province(p)

func _lose_province(p: Dictionary) -> void:
	p.lost = true
	stability = clampf(stability - 6.0, 0.0, 100.0)
	loyalty = clampf(loyalty - 4.0, 0.0, 100.0)
	notify.emit("%s %s" % [GameData.loc(p, "name"), Loc.t("prov.lost")], false)

func _progress_reform(delta: float) -> void:
	if reform_done:
		return
	reform_progress = clampf(reform_progress + 0.05 * delta, 0.0, 100.0)
	if reform_progress >= 100.0:
		_complete_reform()

func _complete_reform() -> void:
	reform_done = true
	stability = clampf(stability + 8.0, 0.0, 100.0)
	army = clampf(army + 6.0, 0.0, 100.0)
	add_chronicle("Nizam-i Cedid", Loc.t("inst.reform_done"),
		[[Loc.t("inst.reform_done"), true]])
	notify.emit(Loc.t("inst.reform_done"), true)

# ════════════════════════════════════════════════════════════════
#  ЭКОНОМИКА (§27.1)
# ════════════════════════════════════════════════════════════════
# ════════════════════════════════════════════════════════════════
#  ЭКОНОМИКА — чистый кликер (§27.1, переработано)
#  Авто-дохода нет. Хазна растёт только от касаний Печати.
#  Прокачка (развитие провинций + институты + декреты) увеличивает
#  СУММУ за одно касание, а не доход в секунду.
# ════════════════════════════════════════════════════════════════
const BASE_TAP := 1.0              # базовая Хазна за касание
const PROV_TAP_FACTOR := 0.004     # вклад провинции в касание (от base_income)

# Сколько Хазны даёт провинция за одно касание (без множителя институтов)
func province_yield(p: Dictionary) -> float:
	if p.lost:
		return 0.0
	var dev_f: float = clampf(p.development / 50.0, 0.4, 2.0)
	var loy_f: float = clampf(0.4 + p.loyalty / 100.0, 0.4, 1.4)
	var fr_f: float = clampf(1.0 - p.fracture / 150.0, 0.3, 1.0)
	return float(p.base_income) * PROV_TAP_FACTOR * dev_f * loy_f * fr_f

func provinces_yield() -> float:
	var s := 0.0
	for p in provinces:
		s += province_yield(p)
	return s

# Множитель касания от институтов (Двор/Флот) и декрета «Золотой век»
func click_mult() -> float:
	var m := 1.0
	for def in GameData.INSTITUTIONS:
		if def.kind == "income_mult":
			var lvl: int = institutions.get(def.id, 0)
			m += (def.per_level * lvl) / 100.0
	if decrees_owned.has("golden_century"):
		m += 0.10
	return m

# Совместимость со старым именем (используется в UI провинций)
func income_mult() -> float:
	return click_mult()

# Полная ценность одного касания Печати
func click_value() -> float:
	return (BASE_TAP + provinces_yield()) * click_mult()

func tap_seal() -> void:
	var v := click_value()
	hazna += v
	lifetime_hazna += v
	tap_count += 1

# ════════════════════════════════════════════════════════════════
#  СНАБЖЕНИЕ — покупка еды и улучшение амбаров (§8)
# ════════════════════════════════════════════════════════════════
const FOOD_BUY_AMOUNT := 12.0          # сколько еды даёт одна закупка
const FOOD_BUY_BASE := 900.0           # базовая цена закупки
const FOOD_TOOL_BASE := 1800.0         # базовая цена улучшения амбаров
const FOOD_TOOL_DISCOUNT := 0.85       # каждый уровень: −15% к цене еды

func food_buy_cost() -> float:
	# Дороже, когда амбары почти полны; дешевле с улучшениями инструментов.
	var scarcity := 1.0 + (food / 100.0) * 0.6
	return FOOD_BUY_BASE * scarcity * pow(FOOD_TOOL_DISCOUNT, food_tool_level)

func can_buy_food() -> bool:
	return food < 100.0 and hazna >= food_buy_cost()

func buy_food() -> void:
	if not can_buy_food():
		return
	hazna -= food_buy_cost()
	food = clampf(food + FOOD_BUY_AMOUNT, 0.0, 100.0)
	notify.emit("+%d %s" % [int(FOOD_BUY_AMOUNT), Loc.t("res.food")], true)

func food_tool_cost() -> float:
	return FOOD_TOOL_BASE * pow(1.7, food_tool_level)

func can_upgrade_food_tool() -> bool:
	return hazna >= food_tool_cost()

func upgrade_food_tool() -> void:
	if not can_upgrade_food_tool():
		return
	hazna -= food_tool_cost()
	food_tool_level += 1
	notify.emit("%s %d" % [Loc.t("prov.granaries"), food_tool_level], true)

# ════════════════════════════════════════════════════════════════
#  ПРОВИНЦИИ (§11.4)
# ════════════════════════════════════════════════════════════════
func invest_cost(p: Dictionary) -> float:
	return p.invest_base * pow(1.6, p.invest_level)

func can_invest(p: Dictionary) -> bool:
	return not p.lost and hazna >= invest_cost(p)

func invest(p: Dictionary) -> void:
	if not can_invest(p):
		return
	hazna -= invest_cost(p)
	p.invest_level += 1
	p.development = clampf(p.development + 6.0, 0.0, 100.0)
	p.loyalty = clampf(p.loyalty + 4.0, 0.0, 100.0)
	p.fracture = clampf(p.fracture - 6.0, 0.0, 100.0)
	# Развитие страны — благо: оппозиция гаснет, стабильность чуть растёт.
	opposition = clampf(opposition - 1.6, 0.0, 100.0)
	stability = clampf(stability + 0.6, 0.0, 100.0)
	notify.emit("+%s ➜ %s" % [Loc.t("prov.invest"), GameData.loc(p, "name")], true)

func suppress_cost(p: Dictionary) -> float:
	return p.base_income * 0.3

func can_suppress(p: Dictionary) -> bool:
	return not p.lost and hazna >= suppress_cost(p) and army >= 2.0

func suppress(p: Dictionary) -> void:
	if not can_suppress(p):
		return
	hazna -= suppress_cost(p)
	p.fracture = clampf(p.fracture - 14.0, 0.0, 100.0)
	p.loyalty = clampf(p.loyalty - 6.0, 0.0, 100.0)
	army = clampf(army - 1.0, 0.0, 100.0)
	# Подавление — насилие: оппозиция растёт, стабильность падает.
	opposition = clampf(opposition + 3.0, 0.0, 100.0)
	stability = clampf(stability - 2.5, 0.0, 100.0)
	notify.emit("%s ➜ %s" % [Loc.t("prov.suppress"), GameData.loc(p, "name")], false)

# ════════════════════════════════════════════════════════════════
#  ИНСТИТУТЫ (§21.0)
# ════════════════════════════════════════════════════════════════
func institution_cost(def: Dictionary) -> float:
	var lvl: int = institutions.get(def.id, 0)
	var c: float = def.base_cost * pow(def.cost_mult, lvl)
	if decrees_owned.has("divan_efficiency"):
		c *= 0.95
	return c

func can_upgrade(def: Dictionary) -> bool:
	return hazna >= institution_cost(def)

func upgrade_institution(def: Dictionary) -> void:
	if not can_upgrade(def):
		return
	hazna -= institution_cost(def)
	institutions[def.id] = institutions.get(def.id, 0) + 1
	match def.kind:
		"army_loyalty":  # Янычары: +армия, −лояльность (HIGH RISK)
			army = clampf(army + 6.0, 0.0, 100.0)
			loyalty = clampf(loyalty - 2.0, 0.0, 100.0)
		"stability":     # Улемы: +стабильность/легитимность
			stability = clampf(stability + 3.0, 0.0, 100.0)
			legitimacy = clampf(legitimacy + 3.0, 0.0, 100.0)
		_:
			pass
	notify.emit("%s · %s %d" % [GameData.loc(def, "name"), Loc.t("inst.level"), institutions[def.id]], true)

func accelerate_reform() -> void:
	if reform_done:
		return
	var cost := 600.0
	if hazna < cost:
		return
	hazna -= cost
	reform_progress = clampf(reform_progress + 8.0, 0.0, 100.0)
	if reform_progress >= 100.0:
		_complete_reform()

# ════════════════════════════════════════════════════════════════
#  СОБЫТИЯ (§12)
# ════════════════════════════════════════════════════════════════
func _try_spawn_event() -> void:
	# Пул событий с учётом условий. Помимо min_opposition/max_food события могут
	# открываться при упадке статов: max_army, max_stability, max_loyalty.
	var pool: Array = []
	var weights: Array = []
	for e in GameData.EVENTS:
		if e.id == _last_event_id:
			continue
		if not _event_eligible(e):
			continue
		pool.append(e)
		weights.append(float(e.get("weight", 1.0)))
	if pool.is_empty():
		for e in GameData.EVENTS:
			if _event_eligible(e):
				pool.append(e); weights.append(float(e.get("weight", 1.0)))
	if pool.is_empty():
		return
	active_event = pool[_weighted_pick(weights)]
	_last_event_id = active_event.id
	event_started.emit()

func _event_eligible(e: Dictionary) -> bool:
	if opposition < e.get("min_opposition", 0.0):
		return false
	if external_pressure < e.get("min_external_pressure", 0.0):
		return false
	if food > e.get("max_food", 101.0):
		return false
	if army > e.get("max_army", 101.0):
		return false
	if stability > e.get("max_stability", 101.0):
		return false
	if loyalty > e.get("max_loyalty", 101.0):
		return false
	return true

func _weighted_pick(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := randf() * total
	for i in range(weights.size()):
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1

# Гарантия: всегда есть хотя бы один доступный (бесплатный) выбор (§баланс)
func resolved_choices(ev) -> Array:
	if ev == null:
		return []
	var arr: Array = ev.choices.duplicate()
	var has_free := false
	for ch in arr:
		if not ch.has("cost") and not ch.has("req"):
			has_free = true
			break
	if not has_free:
		arr.append(GameData.FALLBACK_CHOICE)
	return arr

func choose_event(choice_index: int) -> void:
	if active_event == null:
		return
	var choices := resolved_choices(active_event)
	if choice_index < 0 or choice_index >= choices.size():
		return
	var ch: Dictionary = choices[choice_index]
	# Требования (§13.1)
	if ch.has("req"):
		for stat in ch.req:
			if get(stat) < ch.req[stat]:
				return
	if ch.has("cost") and hazna < ch.cost:
		return
	if ch.has("cost"):
		hazna -= ch.cost
	_apply_effects(ch.effects)
	_react_to_decision(ch.effects)
	add_chronicle(GameData.loc(active_event, "title"), GameData.loc(ch, "summary"), ch.get("chips", []))
	active_event = null
	_event_timer = randf_range(22.0, 42.0)
	event_resolved.emit()

func _react_to_decision(eff: Dictionary) -> void:
	# §оппозиция: ЛЮБОЕ решение её двигает. Полезные для страны решения её гасят,
	# вредные/агрессивные — раздувают. Народное настроение угасает от неприятных
	# (болезненных) решений.
	var sd: float = float(eff.get("stability", 0.0))
	var ld: float = float(eff.get("loyalty", 0.0))
	var fd: float = float(eff.get("food", 0.0))
	var leg: float = float(eff.get("legitimacy", 0.0))
	var ad: float = float(eff.get("army", 0.0))
	var ext: float = float(eff.get("external_pressure", 0.0))
	# «Польза для страны» (чем выше — тем правильнее решение)
	var good: float = sd + ld + fd + leg * 0.6 + ad * 0.35 - ext
	for k in eff:
		var ks: String = str(k)
		if ks.ends_with(".fracture"):
			good -= float(eff[k])
		elif ks.ends_with(".loyalty") or ks.ends_with(".development"):
			good += float(eff[k])
	# Оппозиция реагирует на любое решение (если у выбора нет явного эффекта на неё)
	if not eff.has("opposition"):
		var shift: float = -good * 0.30
		if absf(shift) < 1.0:
			shift = 1.0   # нейтральные решения слегка раздражают оппозицию
		opposition = clampf(opposition + shift, 0.0, 100.0)
	# Народное настроение (лояльность) угасает от болезненных решений
	var hardship: float = maxf(-(sd + fd), 0.0)
	if hardship > 0.0:
		loyalty = clampf(loyalty - hardship * 0.18, 0.0, 100.0)

func _apply_effects(effects: Dictionary) -> void:
	for key_any in effects:
		var key: String = key_any
		var val: float = effects[key]
		if key == "raze_province":
			_raze_random_province(val)        # стихия: развитие города сброшено
		elif key.begins_with("prov."):
			var parts := key.split(".")  # prov.<id>.<attr>
			var p = _province_by_id(parts[1])
			if p != null and not p.lost:
				p[parts[2]] = clampf(p[parts[2]] + val, 0.0, 100.0)
		elif key == "hazna":
			hazna = maxf(hazna + val, 0.0)
		else:
			set(key, clampf(get(key) + val, 0.0, 100.0))

func _raze_random_province(keep_frac: float) -> void:
	# Стихия разрушает один из развитых городов: его развитие сбрасывается
	# (вложенные ранее «клики» теряются — провинцию надо прокачивать заново).
	var candidates: Array = []
	for p in provinces:
		if not p.lost and p.development > 16.0:
			candidates.append(p)
	if candidates.is_empty():
		return
	var p = candidates[randi() % candidates.size()]
	p.development = maxf(8.0, p.development * keep_frac)
	p.invest_level = int(p.development / 12.0)
	p.fracture = clampf(p.fracture + 18.0, 0.0, 100.0)
	p.loyalty = clampf(p.loyalty - 8.0, 0.0, 100.0)
	notify.emit("%s — %s" % [GameData.loc(p, "name"), Loc.t("prov.razed")], false)

# ════════════════════════════════════════════════════════════════
#  ДИНАСТИЯ / ПРЕСТИЖ (§18, §21.0)
# ════════════════════════════════════════════════════════════════
func prestige_gain_preview() -> int:
	var held := 0
	for p in provinces:
		if not p.lost:
			held += 1
	var g := lifetime_hazna / 2000.0 + held * 50.0 + float(year - 1690) * 20.0 + stability
	return int(floor(maxf(g, 0.0)))

func begin_new_reign() -> void:
	imperial_prestige += prestige_gain_preview()
	sultan_index = (sultan_index + 1) % GameData.SULTANS.size()
	new_run(true)
	reign_changed.emit()
	notify.emit(Loc.t("dyn.new_reign"), true)
	save_game()

func buy_decree(def: Dictionary) -> void:
	if decrees_owned.has(def.id) or imperial_prestige < def.cost:
		return
	imperial_prestige -= def.cost
	decrees_owned.append(def.id)
	if def.id == "sword_of_osman":
		army = clampf(army * 1.15, 0.0, 100.0)
	notify.emit(GameData.loc(def, "name"), true)
	save_game()

# ════════════════════════════════════════════════════════════════
#  ИНИЦИАЛИЗАЦИЯ / ХРОНИКА
# ════════════════════════════════════════════════════════════════
func new_run(keep_meta: bool) -> void:
	hazna = 50.0
	stability = 64.0
	army = 58.0
	loyalty = 60.0
	legitimacy = 55.0
	external_pressure = 22.0
	food = 62.0
	opposition = 14.0
	food_tool_level = 0
	reform_progress = 42.0
	reform_done = false
	year = 1690
	_year_accum = 0.0
	lifetime_hazna = 0.0
	_event_timer = 14.0
	active_event = null
	chronicle.clear()
	institutions.clear()
	for def in GameData.INSTITUTIONS:
		institutions[def.id] = def.level
	provinces.clear()
	for src in GameData.PROVINCES:
		var p: Dictionary = src.duplicate(true)
		p.lost = false
		p.invest_level = 0
		p.invest_base = src.base_income * 0.8
		provinces.append(p)
	if decrees_owned.has("sword_of_osman"):
		army = clampf(army * 1.15, 0.0, 100.0)
	# Стартовые карточки Летописи из макета «Летопись» (§21.4.6)
	add_chronicle("The Cauldron of Unrest" if Loc.lang == "en" else "Котёл смуты",
		"The Janissaries demanded back-pay. You drained the treasury to keep the peace." if Loc.lang == "en" else "Янычары требовали жалованье. Казну опустошили, чтобы сохранить мир.",
		[["+10 Stability", true], ["-5,000 Hazna", false]])
	add_chronicle("Plague in Istanbul" if Loc.lang == "en" else "Чума в Стамбуле",
		"Quarantine was enacted despite merchant protests. Souls were spared." if Loc.lang == "en" else "Введён карантин вопреки купцам. Души спасены.",
		[["Legitimacy Preserved" if Loc.lang == "en" else "Легитимность сохранена", true]])

func add_chronicle(title: String, summary: String, chips: Array) -> void:
	chronicle.push_front({"year": year, "title": title, "summary": summary, "chips": chips})
	if chronicle.size() > 40:
		chronicle.resize(40)

func reset_save() -> void:
	imperial_prestige = 0
	tap_count = 0
	decrees_owned.clear()
	sultan_index = 0
	new_run(false)
	save_game()
	notify.emit(Loc.t("set.reset"), true)

# ── helpers ───────────────────────────────────────────────────────
func _province_by_id(id: String):
	for p in provinces:
		if p.id == id:
			return p
	return null

func _avg_fracture() -> float:
	var sum := 0.0
	var n := 0
	for p in provinces:
		if not p.lost:
			sum += p.fracture
			n += 1
	return sum / maxf(n, 1) if n > 0 else 0.0

func current_sultan() -> String:
	return GameData.SULTANS[sultan_index]

func _avg_development() -> float:
	var sum := 0.0
	var n := 0
	for p in provinces:
		if not p.lost:
			sum += p.development
			n += 1
	return sum / maxf(n, 1) if n > 0 else 0.0

func provinces_alive() -> int:
	var n := 0
	for p in provinces:
		if not p.lost:
			n += 1
	return n

# ════════════════════════════════════════════════════════════════
#  СОХРАНЕНИЕ / ЗАГРУЗКА (§25.4, §26)
# ════════════════════════════════════════════════════════════════
func save_game() -> void:
	var prov_save: Array = []
	for p in provinces:
		prov_save.append({
			"id": p.id, "loyalty": p.loyalty, "development": p.development,
			"fracture": p.fracture, "lost": p.lost, "invest_level": p.invest_level,
		})
	var data := {
		"version": 1,
		"lang": Loc.lang,
		"time": Time.get_unix_time_from_system(),
		"hazna": hazna, "stability": stability, "army": army, "loyalty": loyalty,
		"legitimacy": legitimacy, "external_pressure": external_pressure,
		"food": food, "opposition": opposition, "food_tool_level": food_tool_level,
		"reform_progress": reform_progress, "reform_done": reform_done,
		"year": year, "lifetime_hazna": lifetime_hazna, "tap_count": tap_count,
		"institutions": institutions, "provinces": prov_save,
		"imperial_prestige": imperial_prestige, "decrees_owned": decrees_owned,
		"sultan_index": sultan_index, "chronicle": chronicle,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return false

	Loc.lang = data.get("lang", "ru")
	hazna = data.get("hazna", 50.0)
	stability = data.get("stability", 64.0)
	army = data.get("army", 58.0)
	loyalty = data.get("loyalty", 60.0)
	legitimacy = data.get("legitimacy", 55.0)
	external_pressure = data.get("external_pressure", 22.0)
	food = data.get("food", 62.0)
	opposition = data.get("opposition", 14.0)
	food_tool_level = int(data.get("food_tool_level", 0))
	reform_progress = data.get("reform_progress", 42.0)
	reform_done = data.get("reform_done", false)
	year = int(data.get("year", 1690))
	lifetime_hazna = data.get("lifetime_hazna", 0.0)
	tap_count = int(data.get("tap_count", 0))
	imperial_prestige = int(data.get("imperial_prestige", 0))
	decrees_owned = data.get("decrees_owned", [])
	sultan_index = int(data.get("sultan_index", 0))
	chronicle = data.get("chronicle", [])

	institutions.clear()
	var inst_saved: Dictionary = data.get("institutions", {})
	for def in GameData.INSTITUTIONS:
		institutions[def.id] = int(inst_saved.get(def.id, def.level))

	# Восстановить провинции поверх дефиниций
	provinces.clear()
	var saved_map := {}
	for sp in data.get("provinces", []):
		saved_map[sp.id] = sp
	for src in GameData.PROVINCES:
		var p: Dictionary = src.duplicate(true)
		p.invest_base = src.base_income * 0.8
		var sp = saved_map.get(src.id, null)
		if sp:
			p.loyalty = sp.get("loyalty", src.loyalty)
			p.development = sp.get("development", src.development)
			p.fracture = sp.get("fracture", src.fracture)
			p.lost = sp.get("lost", false)
			p.invest_level = int(sp.get("invest_level", 0))
		else:
			p.lost = false
			p.invest_level = 0
		provinces.append(p)

	if chronicle.is_empty():
		add_chronicle("House of Osman" if Loc.lang == "en" else "Дом Османа", "", [])

	# Офлайн-дохода нет — это кликер. Хазна зарабатывается только касаниями.
	pending_offline = 0.0
	return true
