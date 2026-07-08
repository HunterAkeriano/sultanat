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
var sim_paused: bool = false    # главное меню открыто ИЛИ окно свёрнуто — симуляция стоит
var _bg_paused_at: float = 0.0  # unix-время когда игра ушла в фон (0 — не в фоне)
var wheel_next_ts: float = 0.0  # unix-время, когда колесо удачи снова доступно
const WHEEL_COOLDOWN_SEC := 4.0 * 3600.0   # колесо доступно раз в 4 часа

# ── Энергия: ~30 минут игры на полном баке, восстановление за 1 час отдыха ──
const ENERGY_MAX := 30.0
const ENERGY_DRAIN_PER_SEC := ENERGY_MAX / (30.0 * 60.0)   # весь бак за 30 мин игры
const ENERGY_REGEN_PER_SEC := ENERGY_MAX / (60.0 * 60.0)   # полный бак за 1 час
var energy: float = ENERGY_MAX
var energy_recharging := false      # подзарядка идёт только после ПОЛНОГО разряда
var _energy_warned := false
signal energy_depleted

# ── Призы колеса: безлимит энергии, «без рекламы», купон, долги ──
var energy_unlim_until_ts: float = 0.0   # безлимит энергии до (unix)
var no_ads_until_ts: float = 0.0         # без рекламы до (unix)
var wife_coupon := false                 # купон −80% на поиск жены (одноразовый)
var diplo_coupon := false                # купон посла: улучшение отношений за 2000 (одноразовый)
var debt_amnesty := false                # прощение долгов (одноразовое, сгорает при первом долге)

# ── Монетизация: заглушки до подключения AdMob / Google Play Billing ──
const ADS_STUB_REWARDS := true   # TODO ADMOB: поставить false — награды только за реальный просмотр
var no_ads_forever := false      # покупка «Убрать рекламу навсегда» (глушит принудительную)
var golden_firman := false       # покупка «Золотой фирман»: +25% хазны с касаний
var wheel_respin_used := false   # «ещё раз за ролик» — 1 раз на спин
var wheel_doubled := false       # «удвоить приз» — 1 раз на спин
var coup_second_used := false    # «второй шанс» после переворота — 1 раз за правление
var daily_last_day := 0          # unix-день последней ежедневной награды
var daily_streak := 0
var quests_done := {}            # выполненные задания: id -> true
var _inter_last_ts := 0.0        # лимитер принудительной рекламы

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
var generation: int = 0              # поколение династии (0 — стартовый султан); растёт при наследовании
var sultan_name: String = ""         # имя текущего правителя; для gen 0 берётся из SULTANS[0]

# ── Семья / династическое древо (за текущее правление) ────────────
var wives: Array = []               # [{id, name, alive, married_year}], максимум 4 (четыре конкретные невесты)
var children: Array = []            # [{name, alive, gender, born, mother}] — один сын-наследник
var ancestors: Array = []           # летопись династии: ушедшие правители остаются на древе
var used_wife_ids: Array = []       # невесты прошлых правлений: жёны не повторяются на древе
var sultan_pidx: int = 0            # индекс внешности правителя (0 = базовый портрет первого султана)
var used_son_idx: Array = []        # использованные внешности наследников: son_N не повторяются
var relations: Dictionary = {       # дипломатия: отношения 0..100 с соседями
	"moscow": 55.0, "poland": 55.0, "austria": 55.0, "persia": 55.0, "crimea": 100.0,
}
                                    # [{sultan, generation, wife_name, wife_id, end_year, by_force}]
var seeking_wife: bool = false      # объявлен платный поиск невесты — идут предложения руки
const MAX_WIVES := 4
const WIFE_SEARCH_COST := 20000.0   # цена объявить поиск жены
const MAX_HEIRS := 1                 # один сын-наследник
const HEIR_ADULT_AGE := 14          # с этого возраста сын может взойти на трон

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
var _pending_succession: bool = false  # заговор сына: наследование после закрытия события
var staff_engaged: bool = false    # султан присоединился к совету генштаба (за текущее правление)
var _staff_recall_timer := 0.0     # генштаб напоминает о себе, пока султан не вошёл в совет

func _ready() -> void:
	# Применяем сохранённую кадровую частоту (переключается в настройках)
	Engine.max_fps = fps_setting()
	if not load_game():
		new_run(false)
	Loc.language_changed.connect(func(): pass)

# ════════════════════════════════════════════════════════════════
#  СИМУЛЯЦИЯ — тик (§24.4)
# ════════════════════════════════════════════════════════════════
var _sim_tick: float = 0.0
const SIM_TICK_INTERVAL := 0.05   # 20 Гц — симуляции стратегии этого хватает

func _process(delta: float) -> void:
	# Симуляция дёргается 20 раз в секунду, а не каждый кадр — на 60/120 Гц
	# экране это разница в 3-6 раз меньше нагрузки на CPU. Игрок не заметит:
	# события/энергия/оппозиция меняются медленно.
	_sim_tick += delta
	if _sim_tick < SIM_TICK_INTERVAL:
		return
	delta = _sim_tick   # передаём накопленное время, чтобы скорость игры не менялась
	_sim_tick = 0.0
	# Авто-дохода в тике нет — это кликер; автосбор Двора начисляется офлайн при загрузке.
	# Тик отвечает лишь за «кризисный слой»: время, энтропию, трещины, реформу, события.
	if game_over or sim_paused:
		# В меню энергия восстанавливается ТОЛЬКО если заряд был потрачен полностью.
		# Частично севшая батарейка в меню не пополняется.
		if energy_recharging:
			energy = minf(ENERGY_MAX, energy + ENERGY_REGEN_PER_SEC * delta)
			if energy >= ENERGY_MAX:
				energy_recharging = false   # зарядилась — фаза окончена
		if energy >= 1.0:
			_energy_warned = false
		return                      # после переворота/в меню всё замирает
	# Во время игры энергия тратится (кроме безлимита); на нуле — выход в меню.
	# Начал играть — фаза подзарядки СБРАСЫВАЕТСЯ: следующая пойдёт только
	# после нового полного разряда. Иначе батарея «доливалась» между сессиями.
	if energy_recharging and energy > 0.0:
		energy_recharging = false
	if energy_unlimited():
		energy = ENERGY_MAX
	else:
		energy = maxf(0.0, energy - ENERGY_DRAIN_PER_SEC * delta)
	if energy <= 0.0:
		energy_recharging = true    # полный разряд — только теперь идёт пополнение
		if not _energy_warned:
			_energy_warned = true
			notify.emit(Loc.t("energy.empty"), false)
			energy_depleted.emit()
		return
	_advance_time(delta)
	_update_frenzy()   # раж Печати гаснет по таймеру или при остановке касаний
	_drift(delta)
	if game_over:
		return   # переворот случился в ЭТОМ тике — дальше ничего не происходит
	_grow_fractures(delta)
	_progress_reform(delta)

	# Очередь событий (§4.2 фаза событий). В кризис события учащаются.
	# Пока идёт раж Печати — таймер событий заморожен: событие появится
	# сразу после того, как раж закончится (гонец не мешает клацать).
	if active_event == null and not frenzy_active():
		var unrest := 1.0
		if food < 40.0:
			unrest += (40.0 - food) / 40.0 * 1.6     # голод → больше бунтов
		if opposition > 40.0:
			unrest += (opposition - 40.0) / 60.0 * 1.4
		if stability < 45.0:
			unrest += (45.0 - stability) / 45.0 * 1.0
		_event_timer -= delta * minf(unrest, 2.6)   # потолок: в кризис заметно чаще, но без лавины
		if _event_timer <= 0.0:
			_try_spawn_event()

	# Напоминание генштаба: султан отклонил приглашение (или не смог заплатить) —
	# совет зовёт снова каждые 45 c, когда в казне есть НУЖНАЯ сумма (20 000).
	if reform_done and not staff_engaged and active_event == null and not frenzy_active():
		_staff_recall_timer -= delta
		if _staff_recall_timer <= 0.0:
			_staff_recall_timer = 45.0
			if hazna >= 20000.0:
				_force_event("general_staff")

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

# Сложность растёт с династией: каждое поколение +6% ко всей энтропии
# (распад стабильности, давление, недовольство, голод, охлаждение отношений).
# Потолок ×1.6 — десятое поколение живёт в постоянном пожаре.
func difficulty() -> float:
	return minf(1.0 + float(generation) * 0.06, 1.6)

func _drift(delta: float) -> void:
	# Энтропия: империя угасает сама по себе (§1.1).
	_relations_decay(delta)
	external_pressure = clampf(external_pressure + 0.03 * difficulty() * delta, 0.0, 100.0)
	# Стабильность больше НЕ капает сама по себе: она падает только по
	# конкретным причинам — высокая оппозиция, нехватка еды или эффекты
	# событий (обрабатываются отдельно, в _apply_effects). Пассивный слой
	# оставили только для роста, чтобы после кризиса держава могла оправиться.
	var decay := 0.0
	if opposition > 60.0:
		# Сильная оппозиция расшатывает державу пропорционально своей силе:
		# 60% → 0, 100% → ~0.6/с (сопоставимо с прежним пиковым распадом).
		decay += (opposition - 60.0) / 40.0 * 0.60 * difficulty()
	# Стабильность растёт от развития провинций и сытости.
	# Пассивный рост умеренный: при хорошем хозяйстве стабильность СЛЕГКА
	# подрастает сама, но главный рычаг — события и решения.
	var growth := 0.02 + (_avg_development() / 100.0) * 0.09 + (food / 100.0) * 0.07
	stability = clampf(stability - decay * delta + growth * delta, 0.0, 100.0)
	# Лёгкое восстановление лояльности к равновесию
	loyalty = clampf(loyalty + (50.0 - loyalty) * 0.004 * delta, 0.0, 100.0)

	# ── Еда (§8): расходуется заметно быстрее. Развитые провинции кормят лучше,
	#    запущенные — голодают. Нехватку приходится докупать в Снабжении.
	#    Недовольство провинций (трещины) больше НЕ бьёт по стабильности напрямую —
	#    вместо этого оно ускоряет проедание запасов и раздувает оппозицию. ──
	var avg_fr := _avg_fracture()
	var production := _avg_development() * 0.010 + provinces_alive() * 0.018
	var consumption := (0.66 + external_pressure * 0.005 + provinces_alive() * 0.035 \
			+ (avg_fr / 100.0) * 0.40) * difficulty()
	food = clampf(food + (production - consumption) * delta, 0.0, 100.0)
	# Голод бьёт по стабильности и кормит оппозицию (чем меньше еды — тем сильнее).
	# Это ЯВНАЯ причина падения стабильности (не «сама по себе» — а именно от голода).
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
	# Недовольство провинций подпитывает оппозицию: 0% → 0, 100% средних
	# трещин → +0.30/с. Раньше это било по стабильности напрямую; теперь
	# идёт через оппозицию (а высокая оппозиция уже точит стабильность).
	if avg_fr > 0.0:
		opp_d += (avg_fr / 100.0) * 0.30
	# Чем выше стабильность — тем сильнее гаснет оппозиция (плавно)
	if stability > 60.0:
		opp_d -= (stability - 60.0) / 40.0 * 0.18
	# Сытость тоже успокаивает
	if food > 65.0:
		opp_d -= (food - 65.0) / 35.0 * 0.05
	opposition = clampf(opposition + opp_d * delta, 0.0, 100.0)
	if opposition >= 100.0:
		# Оппозиция на максимуме: взрослый сын свергает отца и садится на трон
		# (играем дальше за него). Если наследника нет — дворцовый переворот, конец игры.
		if has_adult_heir():
			_usurp_by_son()
		else:
			_coup()

func _coup() -> void:
	# Переворот: правление свергнуто — конец игры. Симуляция замирает до рестарта.
	if game_over:
		return
	game_over = true
	active_event = null
	notify.emit(Loc.t("sys.coup"), false)
	coup_triggered.emit()

func _usurp_by_son() -> void:
	# Сын-наследник свергает отца и захватывает трон. Игра продолжается за сына.
	if game_over:
		return
	active_event = null
	notify.emit(Loc.t("dyn.usurp"), false)
	succeed_to_son(true)

func start_over() -> void:
	# Полный сброс прогресса (как «Начать сначала» после переворота).
	game_over = false
	# Обнуляем раж Печати: у новой партии не должно быть висящего кулдауна
	# от предыдущей жизни.
	frenzy_until = 0.0
	frenzy_cd_until = 0.0
	combo_taps = 0
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
		# Вложения окупаются: каждый уровень инвестиций замедляет рост
		# недовольства на 10% (мультипликативно)
		d_fr *= pow(0.9, p.invest_level)
		d_fr *= difficulty()   # поздние поколения — беспокойнее
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

func _force_event(eid: String) -> void:
	if active_event != null:
		return
	for e in GameData.EVENTS:
		if str(e.get("id", "")) == eid:
			active_event = e
			_last_event_id = eid
			event_started.emit()   # без сигнала гонец не приходил, а событие молча блокировало очередь
			return

func _complete_reform() -> void:
	reform_done = true
	stability = clampf(stability + 8.0, 0.0, 100.0)
	army = clampf(army + 6.0, 0.0, 100.0)
	add_chronicle({
		"title_ru": "Низам-и Джедид", "title_en": "Nizam-i Cedid",
		"summary_key": "inst.reform_done",
		"extra": [["inst.reform_done", true]],
	})
	notify.emit(Loc.t("inst.reform_done"), true)
	# Подсказка игроку о цене входа в военный совет: приглашение вернётся,
	# как только в казне соберётся 20 000.
	notify.emit(Loc.t("quest.staff_cost") % Palette.fmt_int(20000), true)
	# Реформа завершена → генштаб немедленно требует султана. Если сейчас
	# нечем платить и совет отклонён — приглашение вернётся, когда в казне
	# будет достаточно (см. напоминание в тике).
	_staff_recall_timer = 45.0
	_force_event("general_staff")

# ════════════════════════════════════════════════════════════════
#  ЭКОНОМИКА (§27.1)
# ════════════════════════════════════════════════════════════════
# ════════════════════════════════════════════════════════════════
#  ЭКОНОМИКА — чистый кликер (§27.1, переработано)
#  Хазна растёт от касаний Печати; автосбор Двора работает только офлайн.
#  Прокачка (развитие провинций + институты + декреты) увеличивает
#  СУММУ за одно касание, а не доход в секунду.
# ════════════════════════════════════════════════════════════════
const BASE_TAP := 16.8             # базовая Хазна за касание. Подобрано так, чтобы на
                                   # СТАРТЕ новой игры касание давало ровно 58
                                   # (с базовыми провинциями и Флотом 2 ур.: ×1.1)
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

# Полная ценность одного касания Печати (в раже — в FRENZY_MULT раз больше)
func click_value() -> float:
	var v := (BASE_TAP + provinces_yield()) * click_mult()
	if frenzy_active():
		v *= FRENZY_MULT
	return v

func tap_seal() -> void:
	_track_combo()
	var v := click_value()
	if golden_firman:
		v *= 1.25   # «Золотой фирман»: +25% с касаний
	hazna += v
	lifetime_hazna += v
	tap_count += 1

# ── Автосбор («Двор и Бюрократия», kind = auto_click) ──────────────
# Работает ТОЛЬКО офлайн: пока игрок отсутствует, Двор «прожимает» Печать
# сам. Уровень 0 — автосбора нет. Уровень 1 — base_cps касаний/сек,
# каждый следующий уровень: +cps_growth (сложным процентом).
# Потолок накопления — OFFLINE_CAP_SEC (объявлена в шапке файла).

func auto_clicks_per_sec() -> float:
	var lvl: int = institutions.get("court", 0)
	if lvl <= 0:
		return 0.0
	var def := GameData.institution_def("court")
	if def.is_empty() or str(def.get("kind", "")) != "auto_click":
		return 0.0
	# Линейная модель: 1-й уровень даёт base_cps касаний/сек, каждый
	# следующий уровень добавляет ещё столько же. При base_cps = 1.0
	# это ровно N касаний/сек на N-м уровне.
	return float(def.base_cps) * float(lvl)

# ── Комбо-раж Печати: серия быстрых касаний включает ×3 к хазне ────
const FRENZY_TAPS := 50         # сколько быстрых касаний подряд нужно для ража
const FRENZY_GAP := 0.8         # пауза дольше этой (сек) — серия и раж сбрасываются
const FRENZY_DURATION := 30.0   # раж длится максимум 30 секунд
const FRENZY_COOLDOWN := 30.0   # пауза между ражами: новый можно зажечь через 30 секунд
const FRENZY_MULT := 3.0        # множитель хазны за касание во время ража

var combo_taps: int = 0         # текущая серия быстрых касаний
var frenzy_until: float = 0.0   # unix-время конца ража (0 — не активен)
var frenzy_cd_until: float = 0.0  # unix-время конца кулдауна после ража
var _last_tap_ts: float = 0.0

func frenzy_active() -> bool:
	return frenzy_until > 0.0 and Time.get_unix_time_from_system() < frenzy_until

func frenzy_cd_left() -> float:
	return maxf(0.0, frenzy_cd_until - Time.get_unix_time_from_system())

func _track_combo() -> void:
	var now := Time.get_unix_time_from_system()
	if now - _last_tap_ts > FRENZY_GAP:
		combo_taps = 0
	_last_tap_ts = now
	combo_taps += 1
	if combo_taps >= FRENZY_TAPS and frenzy_until <= 0.0 and now >= frenzy_cd_until:
		frenzy_until = now + FRENZY_DURATION

func _update_frenzy() -> void:
	# Раж гаснет, если игрок остановился ИЛИ прошло время. Серия обнуляется,
	# и включается кулдаун — следующий раж не раньше чем через минуту.
	if frenzy_until <= 0.0:
		return
	var now := Time.get_unix_time_from_system()
	if now >= frenzy_until or now - _last_tap_ts > FRENZY_GAP:
		frenzy_until = 0.0
		combo_taps = 0
		frenzy_cd_until = now + FRENZY_COOLDOWN

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
	return FOOD_BUY_BASE * scarcity * pow(FOOD_TOOL_DISCOUNT, food_tool_level) * chumak_tariff_mult()

func can_buy_food() -> bool:
	# 99.5+ отображается как «100%» — покупку закрываем там же, чтобы не было
	# ситуации «на экране 100%, а зерно всё ещё продают».
	return food < 99.5 and hazna >= food_buy_cost()

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
	# Развитие страны — благо: оппозиция гаснет, стабильность заметно растёт.
	opposition = clampf(opposition - 1.6, 0.0, 100.0)
	stability = clampf(stability + 3.0, 0.0, 100.0)
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
	# Подавление — насилие: народное настроение падает, оппозиция растёт.
	# Стабильность при этом не трогаем (сила держит порядок ценой настроения народа).
	loyalty = clampf(loyalty - 4.0, 0.0, 100.0)
	opposition = clampf(opposition + 3.0, 0.0, 100.0)
	notify.emit("%s ➜ %s" % [Loc.t("prov.suppress"), GameData.loc(p, "name")], false)

# ════════════════════════════════════════════════════════════════
#  ИНСТИТУТЫ (§21.0)
# ════════════════════════════════════════════════════════════════
func institution_cost(def: Dictionary) -> float:
	var lvl: int = institutions.get(def.id, 0)
	var c: float
	if str(def.get("kind", "")) == "auto_click":
		if lvl == 0:
			# Единоразовая покупка доступа к автосбору (уровень 0 → 1)
			c = float(def.get("unlock_cost", def.base_cost))
		else:
			# После доступа цена ПАДАЕТ (base_cost < unlock_cost)
			# и дальше растёт умеренно с каждым уровнем.
			c = def.base_cost * pow(def.cost_mult, lvl - 1)
	else:
		c = def.base_cost * pow(def.cost_mult, lvl)
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
	if int(institutions[def.id]) >= 3:
		grant_quest("institute3", 2000.0, Loc.t("quest.inst"))
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
#  ДИПЛОМАТИЯ: отношения с соседями (0..100)
# ════════════════════════════════════════════════════════════════
const DIPLO_COUNTRIES := ["moscow", "poland", "austria", "persia", "crimea"]
const REL_DECAY := 0.19            # отношения тают сами: ~3.4 пункта за игровой год
const REL_STEP := 18.0             # шаг улучшения/ухудшения

func relation(id: String) -> float:
	return float(relations.get(id, 50.0))

func is_vassal(id: String) -> bool:
	return id == "crimea"          # Крымское ханство — вассал, отношения закреплены

func set_relation(id: String, v: float) -> void:
	if is_vassal(id):
		relations[id] = 100.0
		return
	relations[id] = clampf(v, 0.0, 100.0)

func improve_relation_cost() -> float:
	# Фиксированная цена; купон посла с колеса фортуны сбивает её до 2000.
	return 2000.0 if diplo_coupon else 5000.0

func can_improve_relation(id: String) -> bool:
	return not is_vassal(id) and relation(id) < 100.0 and hazna >= improve_relation_cost()

func improve_relation(id: String) -> void:
	if not can_improve_relation(id):
		return
	hazna -= improve_relation_cost()
	if diplo_coupon:
		diplo_coupon = false   # купон одноразовый
	set_relation(id, relation(id) + REL_STEP)
	notify.emit("%s: +%d%%" % [Loc.t("diplo." + id), int(REL_STEP)], true)

func worsen_relation(id: String) -> void:
	if is_vassal(id) or relation(id) <= 0.0:
		return
	set_relation(id, relation(id) - REL_STEP)
	notify.emit("%s: -%d%%" % [Loc.t("diplo." + id), int(REL_STEP)], false)

func chumak_tariff_mult() -> float:
	# Пошлины на чумацкие обозы: Австрия и Московия контролируют торговые шляхи.
	# Плохие отношения → мыто дороже; совсем плохие → проезд закрыт, обходные пути.
	var m := 1.0
	for id in ["austria", "moscow"]:
		var r := relation(id)
		if r < 25.0:
			m += 0.45
		elif r < 60.0:
			m += 0.20
	return m

# Короткое описание текущего эффекта отношений с конкретной страной — что
# именно даёт баф/дебаф прямо сейчас. Используется в окне дипломатии.
func relation_effect_text(id: String) -> String:
	var r := relation(id)
	match id:
		"austria", "moscow":
			# Торговые пути: пошлина влияет на цену закупки зерна
			if r < 25.0:
				return Loc.t("diplo.eff.trade_bad") % 45
			elif r < 60.0:
				return Loc.t("diplo.eff.trade_mid") % 20
			else:
				return Loc.t("diplo.eff.trade_ok")
		"crimea":
			# Вассал — стабильно на 100
			return Loc.t("diplo.eff.vassal")
		"poland", "persia":
			# У них нет прямой экономики, но приграничные события чаще при плохих
			if r < 30.0:
				return Loc.t("diplo.eff.border_bad")
			elif r < 60.0:
				return Loc.t("diplo.eff.border_mid")
			else:
				return Loc.t("diplo.eff.border_ok")
	return ""

func _relations_decay(delta: float) -> void:
	for id in relations:
		if not is_vassal(str(id)):
			relations[id] = clampf(float(relations[id]) - REL_DECAY * difficulty() * delta, 0.0, 100.0)
		else:
			relations[id] = 100.0

# ════════════════════════════════════════════════════════════════
#  СОБЫТИЯ (§12)
# ════════════════════════════════════════════════════════════════
func _try_spawn_event() -> void:
	# Пул событий с учётом условий. Помимо min_opposition/max_food события могут
	# открываться при упадке статов: max_army, max_stability, max_loyalty.
	var pool: Array = []
	var weights: Array = []
	for e in GameData.EVENTS + GameData.DIPLO_EVENTS + GameData.ARMY_EVENTS:
		if e.id == _last_event_id:
			continue
		if not _event_eligible(e):
			continue
		pool.append(e)
		var w := float(e.get("weight", 1.0))
		# Игрок заплатил за поиск невесты — предложения руки идут втрое чаще
		if seeking_wife and e.get("req_seeking", false):
			w *= 3.0
		# События генштаба не теряются в общем пуле: втрое чаще при своих условиях
		if e.get("req_staff", false):
			w *= 3.0
		# Дипломатические кризисы в приоритете при плохих отношениях:
		# чем ниже отношения относительно порога события — тем чаще оно
		# выпадает. На нуле — пятикратный вес (стычки сыплются одна за другой).
		if e.has("rel_country") and e.has("rel_below"):
			var rv := relation(str(e.get("rel_country")))
			var lim := float(e.get("rel_below", 100.0))
			w *= 1.0 + clampf((lim - rv) / maxf(lim, 1.0), 0.0, 1.0) * 4.0
		# Заговор наследника: если сын давно готов, но отец держит трон,
		# событие мощно поднимается в весе. От 3 лет ожидания — ×2,
		# от 6 лет — ×4, к 10 годам — фактически в очередь на выпадение.
		if str(e.get("id", "")) == "heir_conspiracy":
			var wait := heir_ready_years()
			if wait >= 3:
				w *= 1.0 + minf(float(wait - 2) * 0.7, 8.0)
		weights.append(w)
	if pool.is_empty():
		for e in GameData.EVENTS + GameData.DIPLO_EVENTS + GameData.ARMY_EVENTS:
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
	# Заговор наследника: базовый порог min_opposition уже смягчён, но чтобы
	# событие не выпадало на ровном месте, требуем ЛИБО высокой оппозиции,
	# ЛИБО долгого ожидания сына на «скамейке» (3+ игровых года после
	# совершеннолетия). Порог оппозиции для мгновенного триггера —
	# min_heir_wait_or_opposition.
	if e.has("min_heir_wait_or_opposition"):
		var oppo_high := opposition >= float(e.get("min_heir_wait_or_opposition"))
		var waited := heir_ready_years() >= 3
		if not oppo_high and not waited:
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
	# Семейные условия
	if e.get("req_can_marry", false) and not has_free_wife_slot():
		return false
	if e.has("req_wife_available") and not available_wife_ids().has(str(e.get("req_wife_available"))):
		return false
	if e.get("req_spouse", false) and not has_wife():
		return false
	if e.get("req_living_wife", false) and living_wives_count() == 0:
		return false
	if e.get("req_child_slot", false) and (not has_wife() or children.size() >= MAX_HEIRS):
		return false
	if e.get("req_living_child", false) and living_children_count() == 0:
		return false
	if e.get("req_adult_heir", false) and not has_adult_heir():
		return false
	if e.get("req_staff", false) and not staff_engaged:
		return false
	if e.get("req_seeking", false) and not seeking_wife:
		return false
	# История движется: после max_year событие уходит из пула (казаки — до 1800)
	if e.has("max_year") and year > int(e.get("max_year")):
		return false
	# Генштаб зовёт только после завершения реформы Низам-и Джедид
	if e.get("req_reform", false) and not reform_done:
		return false
	# Дипломатия: событие привязано к уровню отношений со страной
	if e.has("rel_country"):
		var rv := relation(str(e.get("rel_country")))
		if rv > float(e.get("rel_below", 101.0)):
			return false
		if rv < float(e.get("rel_above", -1.0)):
			return false
	return true

# ── Семья: помощники ──────────────────────────────────────────────
func living_children_count() -> int:
	var n := 0
	for c in children:
		if c.get("alive", true):
			n += 1
	return n

# ── Жёны / гарем ──
func living_wives() -> Array:
	var arr: Array = []
	for w in wives:
		if w.get("alive", true):
			arr.append(w)
	return arr

func living_wives_count() -> int:
	return living_wives().size()

func has_wife() -> bool:
	return living_wives_count() > 0

func wife_ids() -> Array:
	# id всех когда-либо взятых жён (живых и усопших) — их нельзя посватать снова
	var ids: Array = []
	for w in wives:
		ids.append(str(w.get("id", "")))
	return ids

func available_wife_ids() -> Array:
	# Кандидатки из GameData.WIVES: не в гареме сейчас И не были жёнами
	# прошлых султанов (жёны на древе не повторяются). Если династия
	# исчерпала весь список — открываем второй круг (лучше повтор, чем тупик).
	var taken := wife_ids()
	var out: Array = []
	for d in GameData.WIVES + GameData.WIVES_EXTRA:
		var id := str(d.id)
		if not taken.has(id) and not used_wife_ids.has(id):
			out.append(id)
	if out.is_empty():
		used_wife_ids.clear()
		for d in GameData.WIVES + GameData.WIVES_EXTRA:
			if not taken.has(str(d.id)):
				out.append(str(d.id))
	return out

func has_free_wife_slot() -> bool:
	# Одна жена за раз: новую невесту можно взять, только если живой жены нет
	# (например, прежняя погибла), и осталась свободная кандидатка.
	return living_wives_count() == 0 and not available_wife_ids().is_empty()

func can_seek_wife() -> bool:
	# Можно объявить поиск: нет живой жены, поиск ещё не объявлен, есть кандидатка.
	return has_free_wife_slot() and not seeking_wife

func pay_to_seek_wife() -> bool:
	# Платный поиск невесты: списываем хазну и включаем предложения руки (рандомная жена).
	if not can_seek_wife():
		return false
	var cost := wife_search_cost()
	if hazna < cost:
		notify.emit(Loc.t("dyn.seek_poor"), false)
		return false
	hazna -= cost
	if wife_coupon:
		wife_coupon = false   # купон одноразовый
	seeking_wife = true
	_event_timer = minf(_event_timer, randf_range(8.0, 16.0))   # сваты не заставят себя ждать
	notify.emit(Loc.t("dyn.seek_started"), true)
	save_game()
	return true

# ── Энергия: хелперы для интерфейса ──
# ── Кадровая частота: 60 или 120, хранится вместе с настройками звука ──
func fps_setting() -> int:
	var cfg := ConfigFile.new()
	if cfg.load("user://audio.cfg") == OK:
		return int(cfg.get_value("video", "fps", 60))
	return 60

func set_fps_setting(v: int) -> void:
	Engine.max_fps = v
	var cfg := ConfigFile.new()
	cfg.load("user://audio.cfg")
	cfg.set_value("video", "fps", v)
	cfg.save("user://audio.cfg")

func energy_fraction() -> float:
	return clampf(energy / ENERGY_MAX, 0.0, 1.0)

func can_play() -> bool:
	return energy_unlimited() or energy >= 1.0

func energy_full_in_sec() -> float:
	return maxf(0.0, (ENERGY_MAX - energy) / ENERGY_REGEN_PER_SEC)

# Батарея энергии работает штатно (тратится в игре, копится в меню).
const TEST_UNLIMITED_ENERGY := false
# Кнопки-читы («жена/наследник мгновенно») скрыты в настройках.
const TEST_DEBUG_BUTTONS := false

# ── Тестовые читы (работают только при TEST_DEBUG_BUTTONS) ──
func debug_instant_wife() -> void:
	if not TEST_DEBUG_BUTTONS:
		return
	if has_wife():
		notify.emit("ТЕСТ: жена уже есть", false)
		return
	for id in available_wife_ids():
		var nm := marry_wife(str(id))
		if nm != "":
			seeking_wife = false
			notify.emit("ТЕСТ: жена — %s" % nm, true)
			save_game()
			return
	notify.emit("ТЕСТ: свободных невест нет", false)

func debug_instant_heir() -> void:
	if not TEST_DEBUG_BUTTONS:
		return
	if not heir().is_empty():
		notify.emit("ТЕСТ: наследник уже есть", false)
		return
	var nm := GameData.random_child_name()
	add_heir(nm)
	notify.emit("ТЕСТ: наследник — %s" % nm, true)
	save_game()

func energy_unlimited() -> bool:
	if TEST_UNLIMITED_ENERGY:
		return true
	return Time.get_unix_time_from_system() < energy_unlim_until_ts

func energy_unlim_left_sec() -> float:
	return maxf(0.0, energy_unlim_until_ts - Time.get_unix_time_from_system())

func ads_disabled() -> bool:
	return Time.get_unix_time_from_system() < no_ads_until_ts

func wife_search_cost() -> float:
	return WIFE_SEARCH_COST * (0.2 if wife_coupon else 1.0)

func _settle_debt() -> void:
	# Прощение долгов: одноразово сжигает минус на балансе.
	if hazna < 0.0 and debt_amnesty:
		debt_amnesty = false
		hazna = 0.0
		notify.emit(Loc.t("debt.forgiven"), true)

# ── Реклама и покупки (единые точки; сейчас — заглушки) ──
# TODO ADMOB: заменить заглушку реальным показом RewardedAd;
# on_reward вызывать ТОЛЬКО после полного просмотра ролика.
func request_rewarded(_tag: String, on_reward: Callable) -> void:
	if ADS_STUB_REWARDS:
		on_reward.call()
		notify.emit(Loc.t("ads.stub"), true)
		save_game()
		return
	notify.emit(Loc.t("ads.not_ready"), false)

# Хук принудительной рекламы (не чаще раза в 4 минуты; глушится покупкой
# «Убрать рекламу» и призом «День без рекламы»). TODO ADMOB: показать interstitial.
func force_interstitial() -> void:
	# Принудительный показ (сектор колеса «Реклама»). Уважает купленный
	# «Без рекламы навсегда» и активный приз «Без рекламы».
	if no_ads_forever or ads_disabled():
		return
	_inter_last_ts = Time.get_unix_time_from_system()
	# TODO ADMOB: InterstitialAd.show()

func maybe_interstitial() -> void:
	if no_ads_forever or ads_disabled():
		return
	var now := Time.get_unix_time_from_system()
	if now - _inter_last_ts < 240.0:
		return
	_inter_last_ts = now
	# TODO ADMOB: InterstitialAd.show()

# TODO BILLING: заменить на Google Play Billing (покупка по sku).
func request_purchase(_sku: String) -> void:
	notify.emit(Loc.t("iap.soon"), false)

# ── Ежедневная награда за вход (цикл из 3 дней) ──
func claim_daily() -> void:
	var day := int(Time.get_unix_time_from_system() / 86400.0)
	if day <= daily_last_day:
		return
	daily_streak = daily_streak + 1 if day == daily_last_day + 1 else 1
	daily_last_day = day
	match (daily_streak - 1) % 3:
		0:
			hazna += 1500.0
			notify.emit("%s %s" % [Loc.t("daily.title"), Loc.t("daily.d1")], true)
		1:
			energy = ENERGY_MAX
			energy_recharging = false
			notify.emit("%s %s" % [Loc.t("daily.title"), Loc.t("daily.d2")], true)
		2:
			wheel_next_ts = 0.0
			notify.emit("%s %s" % [Loc.t("daily.title"), Loc.t("daily.d3")], true)
	save_game()

# ── Задания-достижения: одноразовая награда хазной ──
func grant_quest(qid: String, reward: float, title: String) -> void:
	if quests_done.get(qid, false):
		return
	quests_done[qid] = true
	hazna += reward
	notify.emit("%s %s (+%s \u269C)" % [Loc.t("quest.done"), title, Palette.fmt_int(int(reward))], true)
	save_game()

# ── Колесо удачи: доступно раз в 4 часа, выигрыш применяется к игре ──
func wheel_available() -> bool:
	return Time.get_unix_time_from_system() >= wheel_next_ts

func wheel_seconds_left() -> float:
	return maxf(0.0, wheel_next_ts - Time.get_unix_time_from_system())

func pick_wheel_prize() -> int:
	var weights: Array = []
	for p in GameData.WHEEL_PRIZES:
		weights.append(float(p.get("weight", 1.0)))
	return _weighted_pick(weights)

func apply_wheel_prize(idx: int) -> void:
	var p: Dictionary = GameData.WHEEL_PRIZES[idx]
	var kind := str(p.get("kind", ""))
	var good := true
	match kind:
		"hazna":
			hazna += float(p.get("amount", 0.0))
		"debt":
			hazna += float(p.get("amount", 0.0))   # amount отрицательный — уходим в минус
			good = false
			_settle_debt()
		"energy_unlim":
			energy_unlim_until_ts = Time.get_unix_time_from_system() + float(p.get("days", 1.0)) * 86400.0
			energy = ENERGY_MAX
		"no_ads":
			no_ads_until_ts = Time.get_unix_time_from_system() + float(p.get("days", 1.0)) * 86400.0
		"wife_coupon":
			wife_coupon = true
		"diplo_coupon":
			diplo_coupon = true
		"forced_ad":
			good = false
			force_interstitial()   # выпал сектор «Реклама» — принудительный показ
		"amnesty":
			if hazna < 0.0:
				hazna = 0.0
				notify.emit(Loc.t("debt.forgiven"), true)
			else:
				debt_amnesty = true
				notify.emit(Loc.t("debt.amnesty_kept"), true)
	wheel_next_ts = Time.get_unix_time_from_system() + WHEEL_COOLDOWN_SEC
	wheel_respin_used = false
	wheel_doubled = false
	notify.emit("%s %s" % [Loc.t("wheel.won"), str(p.get("label", ""))], good)
	save_game()

func marry_wife(id: String) -> String:
	# Добавляет конкретную невесту по id; возвращает её имя (для уведомления).
	# Только одна живая жена за раз.
	if has_wife():
		return ""
	if wife_ids().has(id):
		return ""
	var d := GameData.wife_def(id)
	if d.is_empty():
		return ""
	var nm := GameData.loc(d, "name")
	wives.append({"id": id, "name": nm, "alive": true, "married_year": year})
	if not used_wife_ids.has(id):
		used_wife_ids.append(id)
	return nm

func kill_random_wife() -> String:
	var alive := living_wives()
	if alive.is_empty():
		return ""
	var w = alive[randi() % alive.size()]
	w.alive = false
	return str(w.get("name", ""))

func add_heir(nm: String, _gender: String = "m") -> void:
	# Один сын-наследник; год рождения нужен для «взросления» и права наследовать.
	if children.size() < MAX_HEIRS:
		var mother := ""
		var lw := living_wives()
		if not lw.is_empty():
			mother = str(lw[randi() % lw.size()].get("name", ""))
		children.append({"name": nm, "alive": true, "gender": "m", "born": year,
			"mother": mother, "pidx": _pick_son_idx()})

# Случайная свободная внешность наследника (1..6, без повторов в династии;
# исчерпали все шесть — открывается второй круг). Дополнительно исключается
# внешность ТЕКУЩЕГО султана, чтобы отец и сын не получили один и тот же
# портрет (это раньше могло случиться на первом сыне: stultan_pidx = 0, но
# файл-заглушка sultan.png внешне похож на heir_1_adult, и даже после
# первого наследования индекс султана в used_son_idx не всегда был).
func _pick_son_idx() -> int:
	var free: Array = []
	for i in range(1, 7):
		if used_son_idx.has(i):
			continue
		if i == sultan_pidx:
			continue
		# У стартового султана (gen 0) sultan_pidx = 0, но арт «султан.png»
		# внешне очень похож на heir_1_adult (один типаж: седой в белой чалме).
		# Чтобы отец и сын не читались как один человек, резервируем внешность 1
		# для линии стартового султана.
		if generation == 0 and sultan_pidx == 0 and i == 1:
			continue
		free.append(i)
	if free.is_empty():
		# Все шесть внешностей уже задействованы — открываем второй круг,
		# но всё равно избегаем портрета текущего султана.
		used_son_idx.clear()
		for i in range(1, 7):
			if i != sultan_pidx:
				free.append(i)
	if free.is_empty():
		free = [2]   # страховка: если по какой-то причине пул пуст
	var idx: int = free[randi() % free.size()]
	used_son_idx.append(idx)
	return idx

func heir() -> Dictionary:
	# Первый живой сын (наследник) или {} если нет.
	for c in children:
		if c.get("alive", true):
			return c
	return {}

func heir_age() -> int:
	var h := heir()
	if h.is_empty():
		return 0
	return year - int(h.get("born", year))

func heir_ready_years() -> int:
	# Сколько игровых лет наследник уже готов сесть на трон, но всё ещё ждёт.
	# 0 — совершеннолетия нет вообще; иначе — возраст − HEIR_ADULT_AGE.
	if not has_adult_heir():
		return 0
	return heir_age() - HEIR_ADULT_AGE

func has_adult_heir() -> bool:
	var h := heir()
	if h.is_empty():
		return false
	return heir_age() >= HEIR_ADULT_AGE

func kill_random_child() -> String:
	var alive: Array = []
	for c in children:
		if c.get("alive", true):
			alive.append(c)
	if alive.is_empty():
		return ""
	var c = alive[randi() % alive.size()]
	c.alive = false
	return c.name

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

# ── Цены событий растут с богатством: у богатого султана просят больше ──
# Базовый множитель ×2 (события должны бить по казне), богатство ощущается
# уже с 10k хазны (степень 0.7), потолок ×25. Округление до 50 для аккуратных сумм.
func event_cost_mult() -> float:
	var m := maxf(1.0, pow(maxf(hazna, 0.0) / 10000.0, 0.7))
	return minf(m * 2.0, 25.0)

func event_choice_cost(ch: Dictionary) -> float:
	if not ch.has("cost"):
		return 0.0
	# Цены генштаба: базово 20 000; если казна больше — забирают 80% всего
	if ch.get("staff_cost", false):
		return roundf((hazna * 0.8 if hazna > 20000.0 else 20000.0) / 50.0) * 50.0
	return roundf(float(ch.cost) * event_cost_mult() / 50.0) * 50.0

# Событие, где ВСЕ выборы платные: бесплатного выхода нет — платим даже в долг.
func event_all_paid(ev) -> bool:
	if ev == null:
		return false
	for ch in ev.choices:
		if not ch.has("cost"):
			return false
	return true

# Гарантия: всегда есть хотя бы один доступный выбор (§баланс).
# Исключение: событие, где все выборы платные, — там игрок платит (можно в минус).
func resolved_choices(ev) -> Array:
	if ev == null:
		return []
	var arr: Array = ev.choices.duplicate()
	var has_free := false
	for ch in arr:
		if not ch.has("cost") and not ch.has("req"):
			has_free = true
			break
	if not has_free and not event_all_paid(ev):
		arr.append(GameData.FALLBACK_CHOICE)
	return arr

func choose_event(choice_index: int) -> void:
	if game_over:
		return   # после переворота решения не принимаются
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
	var pay := event_choice_cost(ch)
	if ch.has("cost") and hazna < pay and not event_all_paid(active_event):
		return
	if ch.has("cost"):
		hazna -= pay
		_settle_debt()
	if str(active_event.get("id", "")) in ["plague_istanbul", "great_plague"]:
		grant_quest("survive_plague", 1500.0, Loc.t("quest.plague"))
	_apply_effects(ch.effects)
	_react_to_decision(ch.effects)
	add_chronicle({
		"title_ru": active_event.get("title_ru", ""), "title_en": active_event.get("title_en", ""),
		"summary_ru": ch.get("summary_ru", ""), "summary_en": ch.get("summary_en", ""),
		"effects": ch.get("effects", {}).duplicate(),
		"cost": pay if ch.has("cost") else 0.0,
	})
	active_event = null
	_event_timer = randf_range(28.0, 48.0)
	event_resolved.emit()
	# Заговор наследника: если выбран исход «сын захватывает трон» — наследуем после
	# закрытия модалки (чтобы не ломать поток события).
	if _pending_succession:
		_pending_succession = false
		succeed_to_son(true)

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
	if not eff.has("opposition") and not eff.has("opposition_mult"):
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
		elif key == "marry":
			# Если событие привязано к конкретной невесте (req_wife_available) — женим на ней;
			# иначе выпадает случайная доступная. Имя на экране заранее не показываем.
			var wid: String = ""
			if active_event != null:
				wid = str(active_event.get("req_wife_available", ""))
			var avail := available_wife_ids()
			if wid == "" or not avail.has(wid):
				wid = str(avail[randi() % avail.size()]) if not avail.is_empty() else ""
			if wid != "":
				var wnm := marry_wife(wid)
				if wnm != "":
					seeking_wife = false   # женился — поиск завершён
					notify.emit("%s: %s" % [Loc.t("dyn.wed"), wnm], true)
		elif key == "widow":
			var dead_w := kill_random_wife()
			if dead_w != "":
				notify.emit("%s: %s" % [Loc.t("dyn.wife_lost"), GameData.person_name_loc(dead_w)], false)
		elif key == "usurp":
			# Заговор наследника удался: сын захватит трон после закрытия события.
			if has_adult_heir():
				_pending_succession = true
		elif key == "join_staff":
			staff_engaged = true            # султан вошёл в военный совет — открываются события генштаба
		elif key == "stability_to_50":
			stability = maxf(stability, 50.0)
		elif key == "opposition_mult":
			opposition = clampf(opposition * val, 0.0, 100.0)
		elif key == "army_loss_random":
			# Случайные потери в стычке. Чем больше потери — тем сильнее
			# падает доверие армии (репутация янычар страдает ощутимо).
			var loss := float(randi_range(3, int(maxf(val * 1.7, 3.0))))
			army = clampf(army - loss, 0.0, 100.0)
			notify.emit("%s %d" % [Loc.t("ev.skirmish_losses"), int(loss)], false)   # напр. 0.5 — снизить вдвое
		elif key == "bear_child":
			var nm := GameData.random_child_name()
			add_heir(nm)
			notify.emit("%s: %s" % [Loc.t("dyn.born"), GameData.person_name_loc(nm)], true)
		elif key == "kill_child":
			var dead := kill_random_child()
			if dead != "":
				notify.emit("%s: %s" % [Loc.t("dyn.died"), GameData.person_name_loc(dead)], false)
		elif key.begins_with("prov."):
			var parts := key.split(".")  # prov.<id>.<attr>
			var p = _province_by_id(parts[1])
			if p != null and not p.lost:
				p[parts[2]] = clampf(p[parts[2]] + val, 0.0, 100.0)
		elif key == "hazna":
			var before := hazna
			hazna += val
			if before >= 0.0 and hazna < 0.0:
				hazna = 0.0   # эффекты событий сами долг не создают
		elif key.begins_with("rel_"):
			set_relation(key.substr(4), relation(key.substr(4)) + val)
		else:
			set(key, clampf(get(key) + event_stat_delta(key, val), 0.0, 100.0))

# Насколько на самом деле сдвинется стат от эффекта события (баланс).
# Стабильность реагирует на события резко: удары ×2.2, успокоение ×1.6 —
# иначе она «слишком стабильная» и решения не ощущаются.
func event_stat_delta(key: String, val: float) -> float:
	if key == "stability":
		return val * 1.6   # единый усилитель: кризис бьёт, но не сносит треть шкалы
	return val

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
	# Кнопка «Передать Печать наследнику» — добровольная передача трона сыну.
	# Требует живого взрослого наследника.
	if not has_adult_heir():
		notify.emit(Loc.t("dyn.no_adult_heir"), false)
		return
	succeed_to_son(false)

func succeed_to_son(by_force: bool) -> void:
	# Сын восходит на трон: новое поколение, его имя и взрослый портрет, новое правление
	# (жёны/наследник обнуляются — султан-сын сам ищет жену и растит сына). Мета (престиж,
	# декреты, поколение) сохраняется. by_force=true — захват власти, иначе добровольно.
	var h := heir()
	var son_name := str(h.get("name", "")) if not h.is_empty() else GameData.random_child_name()
	# Летопись династии: уходящий султан с супругой НЕ пропадают с древа —
	# они сохраняются как предки и рисуются над новым правителем.
	var wrec := {}
	var mother := str(h.get("mother", "")) if not h.is_empty() else ""
	for wf in wives:
		if mother != "" and str(wf.get("name", "")) == mother:
			wrec = wf
			break
	if wrec.is_empty() and not wives.is_empty():
		wrec = wives.back()
	ancestors.append({
		"sultan": current_sultan(),
		"generation": generation,
		"pidx": sultan_pidx,
		"wife_name": str(wrec.get("name", "")),
		"wife_id": str(wrec.get("id", "")),
		"end_year": year,
		"by_force": by_force,
	})
	imperial_prestige += prestige_gain_preview()
	# Экономика касаний переживает смену правителя: институты, провинции
	# (развитие/вложения) и амбары не сбрасываются — хазна за клик та же.
	var keep_inst := institutions.duplicate(true)
	var keep_prov := provinces.duplicate(true)
	var keep_food_tool := food_tool_level
	generation += 1
	coup_second_used = false
	if generation >= 3:
		grant_quest("gen3", 3000.0, Loc.t("quest.gen3"))
	sultan_index = (sultan_index + 1) % GameData.SULTANS.size()
	# Храним «голое» имя наследника: титул («Султан/Sultan») и транслитерация
	# добавляются в current_sultan() на текущем языке.
	sultan_name = son_name
	sultan_pidx = int(h.get("pidx", ((generation - 1) % 6) + 1)) if not h.is_empty() else _pick_son_idx()
	new_run(true)
	if by_force:
		# Захват власти — не «народ ликует». Держава принимает нового султана
		# как узурпатора: стабильность вдвое ниже обычного стартового значения
		# правления, отношения со всеми державами разрушены, оппозиция ещё
		# горит от вчерашнего заговора.
		stability = 50.0
		loyalty = 55.0
		opposition = 30.0
		for cid in DIPLO_COUNTRIES:
			if not is_vassal(cid):
				relations[cid] = 0.0
	else:
		# Добровольная передача — народ ликует, держава едина.
		stability = 100.0
		loyalty = 100.0
		opposition = 0.0
	# Возвращаем накопленную экономику: хазна за клик не сбивается
	institutions = keep_inst
	provinces = keep_prov
	food_tool_level = keep_food_tool
	reign_changed.emit()
	notify.emit("%s %s" % [Loc.t("dyn.new_sultan"), current_sultan()], true)
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
	staff_engaged = false
	seeking_wife = false
	wives = []
	children = []
	reform_progress = 42.0
	reform_done = false
	year = 1690
	_year_accum = 0.0
	lifetime_hazna = 0.0
	_event_timer = 24.0
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
	add_chronicle({
		"title_ru": "Котёл смуты", "title_en": "The Cauldron of Unrest",
		"summary_ru": "Янычары требовали жалованье. Казну опустошили, чтобы сохранить мир.",
		"summary_en": "The Janissaries demanded back-pay. You drained the treasury to keep the peace.",
		"effects": {"stability": 10.0}, "cost": 5000.0,
	})
	add_chronicle({
		"title_ru": "Чума в Стамбуле", "title_en": "Plague in Istanbul",
		"summary_ru": "Введён карантин вопреки купцам. Души спасены.",
		"summary_en": "Quarantine was enacted despite merchant protests. Souls were spared.",
		"extra": [["chr.legit_saved", true]],
	})

# Летопись хранит ДАННЫЕ (тексты на обоих языках + эффекты/цену), а не готовые
# строки: текст собирается в EventsView на текущем языке, поэтому записи
# корректно переводятся при смене локали. Поля записи:
#   title_ru/title_en, summary_ru/summary_en — снимок текстов;
#   summary_key — альтернатива: ключ Loc.t() вместо пары summary_*;
#   effects {stat: delta}, cost — из них EventsView генерирует плашки;
#   extra [[loc_key, good], ...] — доп. плашки по ключам локализации.
# Старый формат ({title, summary, chips}) из прежних сейвов EventsView
# продолжает отображать как есть (без перевода).
func add_chronicle(entry: Dictionary) -> void:
	entry["year"] = int(year)
	chronicle.push_front(entry)
	if chronicle.size() > 40:
		chronicle.resize(40)

func reset_save() -> void:
	imperial_prestige = 0
	tap_count = 0
	decrees_owned.clear()
	sultan_index = 0
	generation = 0
	sultan_name = ""
	ancestors = []
	used_wife_ids = []
	sultan_pidx = 0
	used_son_idx = []
	relations = {"moscow": 55.0, "poland": 55.0, "austria": 55.0, "persia": 55.0, "crimea": 100.0}
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
	# Имя правителя собирается на ТЕКУЩЕМ языке при каждом обращении:
	# для наследника — «Султан/Sultan» + транслитерированное имя,
	# для стартового султана — локализованное имя из исторического списка.
	if sultan_name != "":
		return "%s %s" % [Loc.t("dyn.sultan_prefix"), GameData.son_name_loc(sultan_name)]
	return GameData.loc(GameData.SULTANS[0], "name")

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
		"generation": generation, "sultan_name": sultan_name,
		"staff_engaged": staff_engaged,
		"seeking_wife": seeking_wife,
		"wheel_next_ts": wheel_next_ts,
		"energy": energy, "energy_recharging": energy_recharging,
		"diplo_coupon": diplo_coupon,
		"energy_unlim_until_ts": energy_unlim_until_ts,
		"no_ads_until_ts": no_ads_until_ts,
		"wife_coupon": wife_coupon,
		"debt_amnesty": debt_amnesty,
		"no_ads_forever": no_ads_forever,
		"golden_firman": golden_firman,
		"wheel_respin_used": wheel_respin_used,
		"wheel_doubled": wheel_doubled,
		"coup_second_used": coup_second_used,
		"daily_last_day": daily_last_day,
		"daily_streak": daily_streak,
		"quests_done": quests_done,
		"wives": wives, "children": children, "ancestors": ancestors,
		"used_wife_ids": used_wife_ids,
		"sultan_pidx": sultan_pidx, "used_son_idx": used_son_idx,
		"relations": relations,
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
	generation = int(data.get("generation", 0))
	sultan_name = str(data.get("sultan_name", ""))
	# Совместимость со старыми сейвами: раньше имя хранилось с «запечённым»
	# титулом («Султан Мехмед»). Убираем префикс — титул теперь добавляется
	# при отображении на текущем языке.
	for pfx in ["Султан ", "Sultan "]:
		if sultan_name.begins_with(pfx):
			sultan_name = sultan_name.substr(pfx.length())
			break
	ancestors = data.get("ancestors", []) if data.get("ancestors", []) is Array else []
	used_wife_ids = data.get("used_wife_ids", []) if data.get("used_wife_ids", []) is Array else []
	sultan_pidx = int(data.get("sultan_pidx", 0))
	used_son_idx = data.get("used_son_idx", []) if data.get("used_son_idx", []) is Array else []
	var rel_saved = data.get("relations", {})
	if rel_saved is Dictionary:
		for id in DIPLO_COUNTRIES:
			if rel_saved.has(id):
				relations[id] = clampf(float(rel_saved[id]), 0.0, 100.0)
	relations["crimea"] = 100.0
	staff_engaged = bool(data.get("staff_engaged", false))
	seeking_wife = bool(data.get("seeking_wife", false))
	wheel_next_ts = float(data.get("wheel_next_ts", 0.0))
	# Энергия: восстанавливаем за время отсутствия (пока игра была закрыта).
	var away := maxf(0.0, Time.get_unix_time_from_system() - float(data.get("time", Time.get_unix_time_from_system())))
	energy_recharging = bool(data.get("energy_recharging", false))
	diplo_coupon = bool(data.get("diplo_coupon", false))
	energy = float(data.get("energy", ENERGY_MAX))
	if energy_recharging:
		energy = minf(ENERGY_MAX, energy + away * ENERGY_REGEN_PER_SEC)
		if energy >= ENERGY_MAX:
			energy_recharging = false
	energy_unlim_until_ts = float(data.get("energy_unlim_until_ts", 0.0))
	no_ads_until_ts = float(data.get("no_ads_until_ts", 0.0))
	wife_coupon = bool(data.get("wife_coupon", false))
	debt_amnesty = bool(data.get("debt_amnesty", false))
	no_ads_forever = bool(data.get("no_ads_forever", false))
	golden_firman = bool(data.get("golden_firman", false))
	wheel_respin_used = bool(data.get("wheel_respin_used", false))
	wheel_doubled = bool(data.get("wheel_doubled", false))
	coup_second_used = bool(data.get("coup_second_used", false))
	daily_last_day = int(data.get("daily_last_day", 0))
	daily_streak = int(data.get("daily_streak", 0))
	quests_done = data.get("quests_done", {})
	chronicle = data.get("chronicle", [])
	# Жёны: новый формат — массив "wives"; миграция старого "spouse_name" в одну жену.
	wives = []
	if data.has("wives"):
		for w in data.get("wives", []):
			if typeof(w) == TYPE_DICTIONARY:
				wives.append({
					"id": str(w.get("id", "")),
					"name": str(w.get("name", "?")),
					"alive": bool(w.get("alive", true)),
					"married_year": int(w.get("married_year", year)),
				})
	else:
		var legacy := str(data.get("spouse_name", ""))
		if legacy != "":
			# Старый сейв с единственной супругой — сопоставим её первой кандидатке.
			var lid := ""
			if not GameData.WIVES.is_empty():
				lid = str(GameData.WIVES[0].id)
			wives.append({"id": lid, "name": legacy, "alive": true, "married_year": year})
	children = []
	for c in data.get("children", []):
		if typeof(c) == TYPE_DICTIONARY:
			var rec := {
				"name": str(c.get("name", "?")),
				"alive": bool(c.get("alive", true)),
				"gender": "m",
				"born": int(c.get("born", year)),
				"mother": str(c.get("mother", "")),
			}
			# Внешность (pidx) была потеряна в старых сейвах — на лету
			# восстанавливаем свободную, избегая портрета текущего султана.
			var pidx := int(c.get("pidx", 0))
			if pidx <= 0 or pidx == sultan_pidx:
				pidx = _pick_son_idx()
			elif not used_son_idx.has(pidx):
				used_son_idx.append(pidx)
			rec["pidx"] = pidx
			children.append(rec)

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
		add_chronicle({"title_ru": "Дом Османа", "title_en": "House of Osman"})

	# Офлайн-автосбор Двора: копится ТОЛЬКО пока игрока нет в игре.
	# Начисляем сразу (попап «пока тебя не было» лишь показывает сумму;
	# кнопка ×2 за рекламу добавляет её ещё раз).
	_credit_offline_income(away)
	return true

# Начисляет офлайн-автосбор Двора за прошедшее время `seconds`.
# Используется при загрузке игры (время между сохранением и запуском) и при
# возврате из фона (свёрнутая игра стоит на паузе, но доход Двора идёт).
# Обновляет pending_offline, чтобы UI показал попап «пока тебя не было».
func _credit_offline_income(seconds: float) -> void:
	var cps := auto_clicks_per_sec()
	if cps > 0.0 and seconds > 5.0:
		var gain := cps * minf(seconds, OFFLINE_CAP_SEC) * click_value()
		hazna += gain
		lifetime_hazna += gain
		pending_offline = gain
	else:
		pending_offline = 0.0

# Вызывается извне когда приложение уходит в фон / возвращается.
# Симуляция на паузе: события/тик стоят, но офлайн-автосбор при возврате
# доначисляется за пропущенное время (у автосбора уже потолок OFFLINE_CAP_SEC).
func on_app_paused() -> void:
	if game_over:
		return
	_bg_paused_at = Time.get_unix_time_from_system()
	sim_paused = true
	save_game()

func on_app_resumed() -> void:
	if game_over:
		return
	if _bg_paused_at > 0.0:
		var away := maxf(0.0, Time.get_unix_time_from_system() - _bg_paused_at)
		_bg_paused_at = 0.0
		_credit_offline_income(away)
	# Симуляция возобновляется, если не открыто главное меню
	# (там своя пауза — sim_paused ставится/снимается в MenuScreen).
	# Здесь безопасно снять флаг: если игрок вернулся прямо в меню,
	# MenuScreen выставит его обратно при следующем открытии.
	sim_paused = false
