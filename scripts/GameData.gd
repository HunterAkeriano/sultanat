extends Node
## GameData — статический контент (data-driven, ТЗ §24.2). Весь геймплейный
## контент описан здесь, как требует ТЗ: провинции (§10), институты (§21.0),
## декреты наследия (§21.0), события (§12.3), ранги династии.
## Двуязычные поля разрешаются через loc(field).

func loc(d: Dictionary, base: String) -> String:
	# Возвращает d[base+"_"+lang] с откатом на ru.
	var k := base + "_" + Loc.lang
	if d.has(k):
		return d[k]
	return d.get(base + "_ru", "")

# ── Эпохи / эры (§21.7, динамический визуал) ──────────────────────
# Имя эпохи зависит от Стабильности — считывается мгновенно, без чисел.
func era_name() -> String:
	var s: float = GameState.stability
	if s >= 75: return "The Zenith" if Loc.lang == "en" else "Расцвет"
	if s >= 55: return "Stability" if Loc.lang == "en" else "Равновесие"
	if s >= 35: return "The Strain" if Loc.lang == "en" else "Напряжение"
	return "The Decline" if Loc.lang == "en" else "Закат"

# Линия султанов для смены правления (§18.2 + макет «Suleiman II»)
const SULTANS := [
	{"name_ru": "Султан Сулейман II", "name_en": "Sultan Suleiman II"},
	{"name_ru": "Султан Ахмед II",    "name_en": "Sultan Ahmed II"},
	{"name_ru": "Султан Мустафа II",  "name_en": "Sultan Mustafa II"},
	{"name_ru": "Султан Ахмед III",   "name_en": "Sultan Ahmed III"},
	{"name_ru": "Султан Махмуд I",    "name_en": "Sultan Mahmud I"},
	{"name_ru": "Султан Осман III",   "name_en": "Sultan Osman III"},
]

# Транслитерация мужских имён дома Османов для EN-локали.
# Имя наследника хранится по-русски (ключ), на экране подменяется по языку.
const SON_NAMES_EN := {
	"Мехмед": "Mehmed", "Селим": "Selim", "Баязид": "Bayezid", "Орхан": "Orhan",
	"Мурад": "Murad", "Джем": "Cem", "Ибрагим": "Ibrahim", "Коркут": "Korkut",
	"Джихангир": "Cihangir", "Шехзаде": "Şehzade", "Осман": "Osman", "Ахмед": "Ahmed",
	"Мустафа": "Mustafa", "Махмуд": "Mahmud", "Абдулла": "Abdullah", "Юсуф": "Yusuf",
	"Касым": "Kasım", "Алаэддин": "Alaeddin", "Савджи": "Savcı", "Эртугрул": "Ertuğrul",
	"Халил": "Halil", "Муса": "Musa",
}

func son_name_loc(n: String) -> String:
	return person_name_loc(n)

# Транслитерация женских имён (список случайных невест WIFE_NAMES)
const WIFE_NAMES_EN := {
	"Хюррем": "Hürrem", "Кёсем": "Kösem", "Нурбану": "Nurbanu", "Сафие": "Safiye",
	"Михримах": "Mihrimah", "Хандан": "Handan", "Турхан": "Turhan", "Гюльнуш": "Gülnuş",
	"Рабия": "Rabia", "Эмине": "Emine",
}

# Универсальная локализация имени члена династии (сын, жена, мать).
# Имена хранятся по-русски; на EN подменяются по картам транслитерации,
# а именные невесты — через name_en их определения.
func person_name_loc(n: String) -> String:
	if Loc.lang != "en" or n == "":
		return n
	if SON_NAMES_EN.has(n):
		return SON_NAMES_EN[n]
	if WIFE_NAMES_EN.has(n):
		return WIFE_NAMES_EN[n]
	for d in WIVES + WIVES_EXTRA:
		if str(d.get("name_ru", "")) == n:
			return str(d.get("name_en", n))
	return n

# Отображаемое имя жены: по id из определения (на текущем языке),
# для старых записей без id — транслитерация сохранённого имени.
func wife_display_name(w: Dictionary) -> String:
	var d := wife_def(str(w.get("id", "")))
	if not d.is_empty():
		return loc(d, "name")
	return person_name_loc(str(w.get("name", "")))

# ── Имена для династического древа ────────────────────────────────
const WIFE_NAMES := [
	"Хюррем", "Кёсем", "Нурбану", "Сафие", "Михримах",
	"Хандан", "Турхан", "Гюльнуш", "Рабия", "Эмине",
]
# Колесо удачи: секторы-призы (label — короткая подпись на секторе). Число
# секторов подхватывается автоматически из размера массива (WheelScreen).
const WHEEL_PRIZES := [
	{"label_key": "wheel.hazna_10k",   "kind": "hazna",        "amount": 10000.0, "weight": 2.2},
	{"label_key": "wheel.energy_2d",   "kind": "energy_unlim", "days": 2.0,       "weight": 1.2},
	{"label_key": "wheel.debt_10k",    "kind": "debt",         "amount": -10000.0,"weight": 1.7},
	{"label_key": "wheel.no_ads",      "kind": "no_ads",       "days": 1.0,       "weight": 1.6},
	{"label_key": "wheel.wife_coupon", "kind": "wife_coupon",                     "weight": 1.5},
	{"label_key": "wheel.amnesty",     "kind": "amnesty",                         "weight": 1.5},
	{"label_key": "wheel.ad",          "kind": "forced_ad",                       "weight": 1.6},
	{"label_key": "wheel.debt_20k",    "kind": "debt",         "amount": -20000.0,"weight": 1.1},
	{"label_key": "wheel.diplo_coupon","kind": "diplo_coupon",                    "weight": 1.4},
	# ── Новые слоты ───────────────────────────────────────────────
	{"label_key": "wheel.ad2",         "kind": "forced_ad",                       "weight": 1.6},
	{"label_key": "wheel.debt_50k",    "kind": "debt",         "amount": -50000.0,"weight": 0.6},
	{"label_key": "wheel.energy_1d",   "kind": "energy_unlim", "days": 1.0,       "weight": 1.5},
]

# ── Дополнительные невесты: больше имён, портреты по кругу ──
const WIVES_EXTRA := [
	{"id": "hatice", "name_ru": "Хатидже", "name_en": "Hatice",
		"from_ru": "дом анатолийского бейлербея", "from_en": "the house of the Anatolian beylerbey", "portrait": "wife_5"},
	{"id": "ayse", "name_ru": "Айше", "name_en": "Ayşe",
		"from_ru": "род крымских Гиреев", "from_en": "the Crimean Giray line", "portrait": "wife_6"},
	{"id": "fatma", "name_ru": "Фатьма", "name_en": "Fatma",
		"from_ru": "семья капудан-паши", "from_en": "the Kapudan Pasha's family", "portrait": "wife_1"},
	{"id": "mihrimah", "name_ru": "Михримах", "name_en": "Mihrimah",
		"from_ru": "богатый род Смирны", "from_en": "a wealthy house of Smyrna", "portrait": "wife_2"},
	{"id": "nurbanu", "name_ru": "Нурбану", "name_en": "Nurbanu",
		"from_ru": "венецианский знатный род", "from_en": "a noble Venetian family", "portrait": "wife_3"},
	{"id": "kosem", "name_ru": "Кёсем", "name_en": "Kösem",
		"from_ru": "греческий архонтский род", "from_en": "a Greek archon family", "portrait": "wife_4"},
	{"id": "handan", "name_ru": "Хандан", "name_en": "Handan",
		"from_ru": "боснийский бейский дом", "from_en": "a Bosnian bey's house", "portrait": "wife_5"},
	{"id": "halime", "name_ru": "Халиме", "name_en": "Halime",
		"from_ru": "абхазский княжеский род", "from_en": "an Abkhazian princely line", "portrait": "wife_6"},
]

# Наследники — только сыновья (мужские имена дома Османов)
const SON_NAMES := [
	"Мехмед", "Селим", "Баязид", "Орхан", "Мурад",
	"Джем", "Ибрагим", "Коркут", "Джихангир", "Шехзаде",
	"Осман", "Ахмед", "Мустафа", "Махмуд", "Абдулла",
	"Юсуф", "Касым", "Алаэддин", "Савджи", "Эртугрул",
	"Осман", "Ахмед", "Мустафа", "Махмуд", "Юсуф",
	"Касым", "Халил", "Эртугрул", "Алаэддин", "Муса",
]

func random_wife_name() -> String:
	return WIFE_NAMES[randi() % WIFE_NAMES.size()]

func random_child_name() -> String:
	# не повторяем имена уже имеющихся сыновей, если возможно
	var used := []
	for c in GameState.children:
		used.append(c.get("name", ""))
	var pool := []
	for n in SON_NAMES:
		if not used.has(n):
			pool.append(n)
	if pool.is_empty():
		pool = SON_NAMES
	return pool[randi() % pool.size()]

# ── Жёны (гарем, §династия). Четыре конкретные невесты; берутся только через
#    редкие события-предложения. У каждой один портрет
#    (assets/art/wives/<portrait>.webp; если арт отсутствует — фолбэк-медальон). ──
const WIVES := [
	{
		"id": "gulnus", "name_ru": "Гюльнуш", "name_en": "Gülnuş",
		"from_ru": "знатный род Мореи", "from_en": "the noble house of Morea",
		"portrait": "wife_1",
	},
	{
		"id": "emine", "name_ru": "Эмине", "name_en": "Emine",
		"from_ru": "влиятельный паша столицы", "from_en": "an influential pasha of the capital",
		"portrait": "wife_2",
	},
	{
		"id": "rabia", "name_ru": "Рабия", "name_en": "Rabia",
		"from_ru": "крымский хан, верный союзник", "from_en": "the Crimean Khan, a loyal ally",
		"portrait": "wife_3",
	},
	{
		"id": "safiye", "name_ru": "Сафие", "name_en": "Safiye",
		"from_ru": "старинный визирский дом", "from_en": "an old vizierial house",
		"portrait": "wife_4",
	},
]

func wife_def(id: String) -> Dictionary:
	for w in WIVES + WIVES_EXTRA:
		if w.id == id:
			return w
	return {}


# ── Провинции (§10.2, имена с макета карты) ───────────────────────
# base_income — Hazna/sec при полном развитии и лояльности.
const PROVINCES := [
	{
		"id": "rumelia", "name_ru": "Румелия", "name_en": "Rumelia",
		"sub_ru": "Врата в Европу", "sub_en": "Gateway to Europe",
		"souls": "4.2M", "base_income": 3120.0, "loyalty": 62.0,
		"development": 55.0, "fracture": 18.0, "core": false, "strategic": 8,
	},
	{
		"id": "anatolia", "name_ru": "Анатолия", "name_en": "Anatolia",
		"sub_ru": "Сердце империи", "sub_en": "The Imperial Heart",
		"souls": "6.8M", "base_income": 2850.0, "loyalty": 78.0,
		"development": 60.0, "fracture": 6.0, "core": true, "strategic": 10,
	},
	{
		"id": "egypt", "name_ru": "Египет", "name_en": "Egypt",
		"sub_ru": "Житница государства", "sub_en": "Breadbasket of the State",
		"souls": "2.1M", "base_income": 1450.0, "loyalty": 44.0,
		"development": 40.0, "fracture": 34.0, "core": false, "strategic": 9,
	},
	{
		"id": "levant", "name_ru": "Левант (Сирия)", "name_en": "The Levant",
		"sub_ru": "Перекрёсток караванов", "sub_en": "Crossroads of Caravans",
		"souls": "1.6M", "base_income": 980.0, "loyalty": 50.0,
		"development": 35.0, "fracture": 28.0, "core": false, "strategic": 6,
	},
	{
		"id": "iraq", "name_ru": "Ирак (Месопотамия)", "name_en": "Iraq",
		"sub_ru": "Земля двух рек", "sub_en": "Land of Two Rivers",
		"souls": "1.1M", "base_income": 760.0, "loyalty": 42.0,
		"development": 28.0, "fracture": 30.0, "core": false, "strategic": 7,
	},
	{
		"id": "hijaz", "name_ru": "Хиджаз (Аравия)", "name_en": "Hijaz",
		"sub_ru": "Хранитель святынь", "sub_en": "Guardian of the Holy Cities",
		"souls": "0.6M", "base_income": 540.0, "loyalty": 55.0,
		"development": 22.0, "fracture": 24.0, "core": false, "strategic": 9,
	},
	{
		"id": "tunisia", "name_ru": "Тунис", "name_en": "Tunisia",
		"sub_ru": "Дальний берег", "sub_en": "The Far Shore",
		"souls": "0.9M", "base_income": 610.0, "loyalty": 38.0,
		"development": 30.0, "fracture": 40.0, "core": false, "strategic": 4,
	},
	{
		"id": "libya", "name_ru": "Ливия (Триполитания)", "name_en": "Tripolitania",
		"sub_ru": "Пустынная окраина", "sub_en": "The Desert March",
		"souls": "0.5M", "base_income": 430.0, "loyalty": 36.0,
		"development": 20.0, "fracture": 44.0, "core": false, "strategic": 3,
	},
]

# ── Институты (§21.0, макет «Institutions») ───────────────────────
# kind: эффект апгрейда. wax: цвет печати.
const INSTITUTIONS := [
	{
		"id": "court", "name_ru": "Двор и Бюрократия", "name_en": "Court & Bureaucracy",
		"rank_ru": "Диван-ı Хюмаюн", "rank_en": "Divan-ı Hümâyun",
		"icon": "⚖", "wax_gold": true, "high_risk": false,
		"effect_ru": "Автосбор офлайн: %s касаний/сек", "effect_en": "Offline auto-collect: %s taps/sec",
		"kind": "auto_click",
		"base_cps": 1.0,          # уровень 1 — 1 касание/сек; далее +1 за уровень (линейно)
		"cps_growth": 0.0,        # не используется в линейной модели, оставлено для совместимости
		"unlock_cost": 18000.0,   # единоразовая покупка доступа (уровень 0 → 1) — дороже приглашения генштаба
		"base_cost": 13000.0,     # цена уровня 2
		"cost_mult": 1.5, "level": 0,
	},
	{
		"id": "navy", "name_ru": "Имперский флот", "name_en": "Imperial Navy",
		"rank_ru": "Капудан-паша", "rank_en": "Captain Pasha",
		"icon": "⚓", "wax_gold": true, "high_risk": false,
		"effect_ru": "+%d%% торговый доход", "effect_en": "+%d%% Trade Revenue",
		"per_level": 5.0, "kind": "income_mult",
		"base_cost": 3500.0, "cost_mult": 1.6, "level": 2,
	},
	{
		"id": "janissary", "name_ru": "Янычарский корпус", "name_en": "Janissary Corps",
		"rank_ru": "Капыкулу Оджаклары", "rank_en": "Kapıkulu Ocakları",
		"icon": "⚔", "wax_gold": false, "high_risk": true,
		"effect_ru": "+%d%% военная мощь · −2 лояльности/ур.", "effect_en": "+%d%% Military Power · -2 Loyalty/lvl",
		"per_level": 15.0, "kind": "army_loyalty",
		"base_cost": 8000.0, "cost_mult": 1.7, "level": 8,
	},
	{
		"id": "ulema", "name_ru": "Улемы", "name_en": "The Ulema",
		"rank_ru": "Шейх-уль-ислам", "rank_en": "Sheikh ul-Islam",
		"icon": "\u263D", "wax_gold": false, "high_risk": false,
		"effect_ru": "+%d%% легитимность", "effect_en": "+%d%% Legitimacy",
		"per_level": 5.0, "kind": "stability",
		"base_cost": 2500.0, "cost_mult": 1.5, "level": 3,
	},
]

func institution_def(id: String) -> Dictionary:
	for d in INSTITUTIONS:
		if str(d.id) == id:
			return d
	return {}

# ── Декреты наследия (§21.0, макет «Dynasty»). Покупаются за престиж. ──
const DECREES := [
	{
		"id": "golden_century", "name_ru": "Золотой век", "name_en": "Golden Century",
		"desc_ru": "+10% ко всему доходу (навсегда)", "desc_en": "+10% all income (Permanent)",
		"icon": "⚜", "cost": 5000, "kind": "income", "value": 0.10,
	},
	{
		"id": "sword_of_osman", "name_ru": "Меч Османа", "name_en": "Sword of Osman",
		"desc_ru": "+15% к стартовой армии", "desc_en": "+15% Army starting power",
		"icon": "⚔", "cost": 12000, "kind": "army", "value": 0.15,
	},
	{
		"id": "divan_efficiency", "name_ru": "Эффективный Диван", "name_en": "Divan Efficiency",
		"desc_ru": "−5% к стоимости апгрейдов", "desc_en": "-5% upgrade costs",
		"icon": "⚖", "cost": 25000, "kind": "cost", "value": 0.05,
	},
]

# ── Ранги династии по престижу (макет: Lv4 Eternal House → Undying 50k) ──
const DYNASTY_RANKS := [
	{"min": 0,      "lvl": 1, "ru": "Дом Османа",        "en": "House of Osman"},
	{"min": 5000,   "lvl": 2, "ru": "Восходящий Дом",    "en": "Rising House"},
	{"min": 15000,  "lvl": 3, "ru": "Высокий Дом",       "en": "Sublime House"},
	{"min": 30000,  "lvl": 4, "ru": "Вечный Дом",        "en": "Eternal House"},
	{"min": 50000,  "lvl": 5, "ru": "Нерушимая Династия","en": "The Undying Dynasty"},
]

func dynasty_rank(prestige: int) -> Dictionary:
	var cur: Dictionary = DYNASTY_RANKS[0]
	var nxt = null
	for r in DYNASTY_RANKS:
		if prestige >= r.min:
			cur = r
		elif nxt == null:
			nxt = r
	return {"current": cur, "next": nxt}

# ── События / Имперские декреты (§12.3 + макеты) ──────────────────
# Каждый choice: label, optional req {stat:value}, optional cost (hazna),
# effects {stat: delta}  (stat ∈ hazna, stability, army, loyalty, legitimacy,
#   external_pressure, prov.<id>.fracture, prov.<id>.loyalty),
# summary_ru/summary_en — текст-резюме для Летописи.
# Плашки Летописи генерируются в EventsView из effects/cost на текущем языке —
# поле chips больше не используется и в данных не хранится.
# Бесплатный «запасной» выбор — подставляется, если у события нет ни одного
# доступного варианта (гарантия баланса: игрок никогда не застрянет).
const FALLBACK_CHOICE := {
	"label_ru": "Переждать смуту", "label_en": "Wait it out",
	"effects": {"stability": -4.0, "opposition": 5.0},
	"summary_ru": "Власть промедлила — проблему пустили на самотёк.",
	"summary_en": "The court hesitated — the matter was left to fester.",
}

const EVENTS := [
	{
		"id": "janissaries_pay",
		"image": "event_cauldron",
		"title_ru": "Янычары требуют жалованье", "title_en": "Janissaries Demand Pay",
		"body_ru": "«Очаг гудит, котлы перевёрнуты — знак мятежа. Янычарский корпус требует прибавки к жалованью, иначе двинется на дворец.»",
		"body_en": "\"The hearth is buzzing. The kettles are overturned—a sign of mutiny. The Janissary corps demands a pay increase, or they will march on the palace.\"",
		"choices": [
			{
				"label_ru": "Заплатить сполна", "label_en": "Pay in full",
				"cost": 5000.0,
				"effects": {"stability": 10.0, "loyalty": 6.0, "army": 4.0},
				"summary_ru": "Янычарам выплатили долг сполна, чтобы сохранить мир в столице.",
				"summary_en": "The Janissaries were paid in full to keep the peace in the capital.",
			},
			{
				"label_ru": "Урезать и заплатить часть", "label_en": "Cut and pay partial",
				"cost": 2000.0,
				"effects": {"stability": 3.0, "loyalty": -4.0, "army": 1.0},
				"summary_ru": "Жалованье урезали — мятеж отложен, но недовольство осталось.",
				"summary_en": "Pay was cut — the mutiny is delayed, but resentment lingers.",
			},
			{
				"label_ru": "Отказать и пригрозить", "label_en": "Refuse and threaten",
				"req": {"army": 60.0},
				"effects": {"stability": 6.0, "loyalty": -10.0, "army": -3.0, "legitimacy": 4.0},
				"summary_ru": "Султан пригрозил корпусу силой — порядок восстановлен страхом.",
				"summary_en": "The Sultan threatened the corps with force — order restored by fear.",
			},
		],
	},
	{
		"id": "serbia_autonomy",
		"image": "event_cauldron",
		"title_ru": "Сербия требует автономию", "title_en": "Serbia Demands Autonomy",
		"body_ru": "Из Белграда прибыл посланник. Сербские старейшины, опираясь на тайную поддержку России, требуют широкой автономии. Толпы на улицах. Австрия наблюдает. Что ты решишь, повелитель?",
		"body_en": "An envoy has arrived from Belgrade. The Serbian elders, backed in secret by Russia, demand broad autonomy. Crowds fill the streets. Austria watches. What will you decide, my lord?",
		"choices": [
			{
				"label_ru": "Подавить силой", "label_en": "Suppress by force",
				"req": {"army": 30.0},
				"effects": {"stability": 5.0, "loyalty": -10.0, "army": -5.0, "prov.rumelia.fracture": 12.0},
				"summary_ru": "Сербское выступление подавлено войсками — трещина на Балканах ширится.",
				"summary_en": "The Serbian uprising was crushed — the fracture in the Balkans widens.",
			},
			{
				"label_ru": "Предоставить автономию", "label_en": "Grant autonomy",
				"effects": {"stability": -8.0, "loyalty": 6.0, "prov.rumelia.fracture": -22.0},
				"summary_ru": "Сербии дарована автономия — трещина утихла, но прецедент создан.",
				"summary_en": "Serbia was granted autonomy — the fracture eased, but a precedent is set.",
			},
			{
				"label_ru": "Подкупить элиты", "label_en": "Bribe the elites",
				"cost": 1500.0,
				"effects": {"prov.rumelia.loyalty": 10.0, "prov.rumelia.fracture": -8.0},
				"summary_ru": "Сербских старейшин подкупили — спокойствие куплено за золото.",
				"summary_en": "The Serbian elders were bribed — calm bought with gold.",
			},
		],
	},
	{
		"id": "plague_istanbul",
		"image": "event_cauldron",
		"title_ru": "Чума в Стамбуле", "title_en": "Plague in Istanbul",
		"body_ru": "Великая хворь прорвалась за городские стены. Карантин ударит по торговле, но спасёт души. Купцы протестуют. Решай быстро, повелитель.",
		"body_en": "The Great Sickness breached the city walls. A quarantine will choke trade but spare lives. The merchants protest. Decide quickly, my lord.",
		"choices": [
			{
				"label_ru": "Ввести карантин", "label_en": "Enforce quarantine",
				"cost": 2500.0,
				"effects": {"stability": 2.0, "loyalty": -4.0, "legitimacy": 6.0},
				"summary_ru": "Введён карантин вопреки протестам купцов: торговля просела, но души спасены.",
				"summary_en": "Quarantine enacted despite merchant protests. Trade suffered, but souls were spared.",
			},
			{
				"label_ru": "Не вмешиваться", "label_en": "Do nothing",
				"effects": {"stability": -11.0, "loyalty": -16.0, "legitimacy": -6.0},
				"summary_ru": "Власть не вмешалась — хворь выкосила кварталы, народ ропщет.",
				"summary_en": "The state did nothing — the sickness ravaged the districts, the people seethe.",
			},
		],
	},
	{
		"id": "european_loan",
		"image": "event_cauldron",
		"title_ru": "Заём европейских банкиров", "title_en": "A Loan from Europe",
		"body_ru": "Кредиторы из Лондона и Парижа предлагают щедрый заём. Золото потечёт в казну сегодня — но завтра иностранцы потянутся к управлению долгом.",
		"body_en": "Creditors from London and Paris offer a generous loan. Gold will flow into the treasury today — but tomorrow foreigners will reach for the debt's reins.",
		"choices": [
			{
				"label_ru": "Принять заём", "label_en": "Take the loan",
				"effects": {"hazna": 12000.0, "stability": -4.0, "external_pressure": 12.0},
				"summary_ru": "Принят европейский заём: казна полна, но Управление долгом усиливает хватку.",
				"summary_en": "A European loan was accepted: the treasury is full, but the Debt Administration tightens its grip.",
			},
			{
				"label_ru": "Отказаться", "label_en": "Refuse",
				"effects": {"stability": -6.0, "external_pressure": -6.0, "legitimacy": 5.0},
				"summary_ru": "Заём отвергнут ради независимости — казна страдает, но честь сохранена.",
				"summary_en": "The loan was refused for the sake of independence — the treasury suffers, but honor is kept.",
			},
		],
	},

	# ── Рядовые события государства (§12: повседневное управление) ──
	{
		"id": "grand_bazaar", "image": "event_cauldron", "weight": 1.6,
		"title_ru": "Большой базар", "title_en": "The Grand Bazaar",
		"body_ru": "Купеческие гильдии просят построить новый крытый базар: оживит торговлю и накормит столицу, но строительство недёшево.",
		"body_en": "The merchant guilds petition for a new covered bazaar: it would enliven trade and feed the capital, but construction is costly.",
		"choices": [
			{
				"label_ru": "Профинансировать стройку", "label_en": "Fund the construction",
				"cost": 3000.0,
				"effects": {"stability": 6.0, "food": 8.0, "loyalty": 4.0},
				"summary_ru": "Возведён новый базар — торговля и снабжение столицы окрепли.",
				"summary_en": "A new bazaar rose — trade and the capital's supply grew stronger.",
			},
			{
				"label_ru": "Скромная починка рядов", "label_en": "Patch the old rows",
				"cost": 800.0,
				"effects": {"stability": 2.0, "food": 3.0},
				"summary_ru": "Старые торговые ряды подлатали — небольшое облегчение.",
				"summary_en": "The old market rows were patched — a modest relief.",
			},
			{
				"label_ru": "Отклонить прошение", "label_en": "Dismiss the petition",
				"effects": {"loyalty": -4.0},
				"summary_ru": "Прошение гильдий отклонено — купцы затаили обиду.",
				"summary_en": "The guilds' petition was dismissed — the merchants nurse a grievance.",
			},
		],
	},
	{
		"id": "market_dispute", "image": "event_cauldron", "weight": 2.1,
		"title_ru": "Спор на рынках", "title_en": "Trouble in the Markets",
		"body_ru": "Гильдии красильщиков и ткачей сцепились из-за пошлин. Базары гудят, кади ждёт твоего слова.",
		"body_en": "The dyers' and weavers' guilds are at each other's throats over duties. The bazaars buzz; the qadi awaits your word.",
		"choices": [
			{
				"label_ru": "Рассудить по справедливости", "label_en": "Mediate fairly",
				"effects": {"loyalty": 6.0, "stability": 2.0, "hazna": -500.0},
				"summary_ru": "Спор разрешён по справедливости — обе гильдии довольны.",
				"summary_en": "The dispute was settled fairly — both guilds are appeased.",
			},
			{
				"label_ru": "Ввести единую пошлину", "label_en": "Impose a flat duty",
				"effects": {"stability": -7.0, "hazna": 1500.0, "loyalty": -3.0},
				"summary_ru": "Введена единая пошлина — казна пополнилась, торговцы ворчат.",
				"summary_en": "A flat duty was imposed — the treasury gained, the traders grumble.",
			},
		],
	},
	{
		"id": "tax_farm_reform", "image": "event_cauldron", "weight": 1.4,
		"title_ru": "Откупа налогов", "title_en": "The Tax Farms",
		"body_ru": "Откупщики-мультазимы дерут с провинций три шкуры. Реформа сбора укрепит державу, но заденет влиятельных людей.",
		"body_en": "The tax-farmers bleed the provinces dry. Reforming collection would strengthen the state but offend powerful men.",
		"choices": [
			{
				"label_ru": "Провести реформу сбора", "label_en": "Reform collection",
				"cost": 2000.0,
				"effects": {"stability": 8.0, "opposition": -8.0, "loyalty": 5.0},
				"summary_ru": "Откупа урезаны, сбор упорядочен — народ вздохнул свободнее.",
				"summary_en": "Tax farms were curbed and collection ordered — the people breathe easier.",
			},
			{
				"label_ru": "Выжать максимум сейчас", "label_en": "Squeeze the maximum",
				"effects": {"hazna": 4000.0, "loyalty": -8.0, "opposition": 7.0, "food": -5.0},
				"summary_ru": "Из провинций выжали золото — казна полна, недовольство растёт.",
				"summary_en": "Gold was wrung from the provinces — the treasury is full, resentment grows.",
			},
		],
	},
	{
		"id": "aqueduct", "image": "event_cauldron", "weight": 1.3,
		"title_ru": "Водовод дал течь", "title_en": "The Aqueduct Cracks",
		"body_ru": "Древний водовод Валента дал течь — столице грозит нехватка воды, а с ней и хлеба.",
		"body_en": "The ancient Valens aqueduct is cracking — the capital faces a shortage of water, and bread with it.",
		"choices": [
			{
				"label_ru": "Полностью восстановить", "label_en": "Fully restore it",
				"cost": 2600.0,
				"effects": {"food": 10.0, "stability": 5.0, "loyalty": -2.0},
				"summary_ru": "Водовод восстановлен — вода и хлеб вернулись в столицу.",
				"summary_en": "The aqueduct was restored — water and bread returned to the capital.",
			},
			{
				"label_ru": "Залатать наспех", "label_en": "Patch it hastily",
				"cost": 600.0,
				"effects": {"food": 4.0, "loyalty": -2.0},
				"summary_ru": "Течь наспех залатали — временное облегчение.",
				"summary_en": "The leak was hastily patched — a temporary relief.",
			},
			{
				"label_ru": "Отложить ремонт", "label_en": "Delay the repair",
				"effects": {"food": -8.0, "stability": -4.0, "loyalty": -6.0},
				"summary_ru": "Ремонт отложен — столица осталась без воды, начались перебои с хлебом.",
				"summary_en": "The repair was delayed — the capital went thirsty, and bread grew scarce.",
			},
		],
	},
	{
		"id": "imperial_festival", "image": "event_cauldron", "weight": 1.2,
		"title_ru": "Имперское торжество", "title_en": "An Imperial Festival",
		"body_ru": "Придворные предлагают устроить пышное торжество — обрезание шехзаде. Народ любит зрелища, но казна знает им цену.",
		"body_en": "The court proposes a lavish festival for the prince's circumcision. The people love spectacle, but the treasury knows its price.",
		"choices": [
			{
				"label_ru": "Устроить пышно", "label_en": "Hold it lavishly",
				"cost": 2200.0,
				"effects": {"loyalty": 10.0, "opposition": -6.0, "stability": 4.0},
				"summary_ru": "Столица гуляла неделю — народ славит султана.",
				"summary_en": "The capital feasted for a week — the people hail the Sultan.",
			},
			{
				"label_ru": "Скромный праздник", "label_en": "A modest celebration",
				"effects": {"loyalty": 3.0, "hazna": -400.0},
				"summary_ru": "Праздник провели скромно — народ доволен, но без восторга.",
				"summary_en": "The celebration was modest — the people content, if unmoved.",
			},
		],
	},

	# ── Продовольственные/бунтовые события (открываются при нехватке еды) ──
	{
		"id": "grain_shortage", "image": "event_cauldron", "weight": 2.9, "max_food": 38.0,
		"title_ru": "Зерна не хватает", "title_en": "The Granaries Run Low",
		"body_ru": "Амбары пустеют, цена на хлеб взлетела. На улицах ропот — голодная толпа опасна.",
		"body_en": "The granaries empty and the price of bread soars. The streets murmur — a hungry crowd is a dangerous one.",
		"choices": [
			{
				"label_ru": "Закупить зерно у соседей", "label_en": "Buy grain abroad",
				"cost": 3500.0,
				"effects": {"food": 22.0, "stability": 2.0, "opposition": -5.0, "loyalty": -2.0},
				"summary_ru": "Зерно закуплено за морем — амбары полны, голод отступил.",
				"summary_en": "Grain was bought overseas — the granaries fill, hunger recedes.",
			},
			{
				"label_ru": "Открыть казённые амбары", "label_en": "Open the state granaries",
				"effects": {"food": 12.0, "stability": 2.0, "hazna": -400.0, "loyalty": -3.0},
				"summary_ru": "Открыты казённые амбары — народ накормлен на время.",
				"summary_en": "The state granaries were opened — the people fed, for now.",
			},
			{
				"label_ru": "Разогнать толпу силой", "label_en": "Disperse the crowd",
				"req": {"army": 25.0},
				"effects": {"stability": 2.0, "loyalty": -14.0, "opposition": 8.0, "food": 2.0},
				"summary_ru": "Толпу разогнали войсками — порядок ценой ненависти.",
				"summary_en": "The crowd was dispersed by troops — order at the price of hatred.",
			},
		],
	},
	{
		"id": "bread_riot", "image": "event_cauldron", "weight": 2.9, "max_food": 30.0,
		"title_ru": "Хлебный бунт", "title_en": "Bread Riot",
		"body_ru": "Толпа громит пекарни и склады. «Хлеба!» — кричат под стенами дворца. Промедление смерти подобно.",
		"body_en": "The mob ransacks bakeries and storehouses. \"Bread!\" they cry beneath the palace walls. To hesitate is to perish.",
		"choices": [
			{
				"label_ru": "Раздать хлеб из казны", "label_en": "Distribute bread",
				"cost": 2000.0,
				"effects": {"food": 14.0, "loyalty": 8.0, "stability": 2.0, "opposition": -6.0},
				"summary_ru": "Народу раздали хлеб — бунт утих, султана благословляют.",
				"summary_en": "Bread was handed out — the riot subsided, the Sultan is blessed.",
			},
			{
				"label_ru": "Пообещать реформы", "label_en": "Promise reforms",
				"effects": {"loyalty": 3.0, "opposition": -3.0, "stability": -8.0},
				"summary_ru": "Толпе пообещали перемены — гнев отложен, но не забыт.",
				"summary_en": "The crowd was promised change — its anger delayed, not forgotten.",
			},
		],
	},

	# ── Заговоры (открываются при высокой оппозиции) ──
	{
		"id": "vizier_plot", "image": "event_cauldron", "weight": 2.4, "min_opposition": 45.0,
		"title_ru": "Заговор визиря", "title_en": "The Vizier's Plot",
		"body_ru": "Доносят: великий визирь плетёт сети против трона, заручившись поддержкой части дивана. Медлить опасно.",
		"body_en": "Word comes: the Grand Vizier weaves a web against the throne, backed by part of the Divan. To delay is perilous.",
		"choices": [
			{
				"label_ru": "Казнить заговорщика", "label_en": "Execute the conspirator",
				"req": {"army": 30.0},
				"effects": {"opposition": -22.0, "stability": 5.0, "loyalty": -6.0},
				"summary_ru": "Визирь казнён у Ворот Блаженства — заговор обезглавлен.",
				"summary_en": "The Vizier was executed at the Gate of Felicity — the plot beheaded.",
			},
			{
				"label_ru": "Откупиться и сослать", "label_en": "Buy off and exile",
				"cost": 3000.0,
				"effects": {"opposition": -14.0, "stability": 2.0},
				"summary_ru": "Визиря осыпали золотом и отправили санджак-беем в глушь.",
				"summary_en": "The Vizier was showered with gold and exiled to a distant sanjak.",
			},
			{
				"label_ru": "Сделать вид, что не знаешь", "label_en": "Feign ignorance",
				"effects": {"opposition": 10.0, "stability": -4.0},
				"summary_ru": "Заговор оставлен без внимания — сети плетутся дальше.",
				"summary_en": "The plot was ignored — and the web is spun ever wider.",
			},
		],
	},
	{
		"id": "janissary_conspiracy", "image": "event_cauldron", "weight": 2.4, "min_opposition": 50.0,
		"title_ru": "Заговор янычар", "title_en": "Janissary Conspiracy",
		"body_ru": "В казармах Орты шепчутся о низложении. Котлы вот-вот перевернут. Корпус ждёт лишь искры.",
		"body_en": "In the Orta barracks they whisper of deposition. The kettles are about to overturn. The corps awaits only a spark.",
		"choices": [
			{
				"label_ru": "Подкупить агов", "label_en": "Bribe the aghas",
				"cost": 4000.0,
				"effects": {"opposition": -18.0, "loyalty": 4.0},
				"summary_ru": "Янычарских агов задобрили золотом — заговор рассыпался.",
				"summary_en": "The Janissary aghas were placated with gold — the plot crumbled.",
			},
			{
				"label_ru": "Перебить зачинщиков", "label_en": "Purge the ringleaders",
				"req": {"army": 45.0},
				"effects": {"opposition": -20.0, "loyalty": -10.0, "army": -5.0},
				"summary_ru": "Зачинщиков вырезали ночью — корпус усмирён страхом.",
				"summary_en": "The ringleaders were cut down by night — the corps cowed by fear.",
			},
			{
				"label_ru": "Уступить требованиям", "label_en": "Concede their demands",
				"effects": {"opposition": -8.0, "stability": -5.0, "army": 3.0},
				"summary_ru": "Требования корпуса удовлетворены — мятеж отложен, власть ослабла.",
				"summary_en": "The corps' demands were met — the mutiny delayed, the crown weakened.",
			},
		],
	},
	{
		"id": "pretender", "image": "event_cauldron", "weight": 2.6, "min_opposition": 62.0,
		"title_ru": "Самозванец", "title_en": "A Pretender Rises",
		"body_ru": "В Анатолии объявился самозванец, выдающий себя за потерянного шехзаде. К нему стекаются недовольные. Народ колеблется.",
		"body_en": "In Anatolia a pretender appears, claiming to be a lost prince. The discontented flock to him. The people waver.",
		"choices": [
			{
				"label_ru": "Снарядить погоню", "label_en": "Send a manhunt",
				"cost": 3500.0,
				"effects": {"opposition": -24.0, "stability": 4.0},
				"summary_ru": "Самозванца настигли и схватили — его голову выставили на Ипподроме.",
				"summary_en": "The pretender was hunted down — his head displayed at the Hippodrome.",
			},
			{
				"label_ru": "Опорочить его род", "label_en": "Discredit his claim",
				"effects": {"opposition": -10.0, "legitimacy": 4.0, "hazna": -800.0},
				"summary_ru": "Улемы объявили самозванца лжецом — часть сторонников отшатнулась.",
				"summary_en": "The ulema declared the pretender a liar — some supporters fell away.",
			},
			{
				"label_ru": "Не придать значения", "label_en": "Pay it no heed",
				"effects": {"opposition": 14.0, "stability": -6.0},
				"summary_ru": "Самозванца не тронули — его войско растёт день ото дня.",
				"summary_en": "The pretender was left alone — and his host swells by the day.",
			},
		],
	},

	# ── Бытовые события страны ──
	{
		"id": "cattle_plague", "image": "event_cauldron", "weight": 1.8,
		"title_ru": "Падёж скота", "title_en": "Cattle Plague",
		"body_ru": "В анатолийских стадах вспыхнул мор. Мясо и тягло под угрозой, крестьяне в тревоге.",
		"body_en": "A murrain strikes the Anatolian herds. Meat and draught animals are at risk; the peasants fret.",
		"choices": [
			{
				"label_ru": "Забить и возместить", "label_en": "Cull and compensate",
				"cost": 1600.0,
				"effects": {"stability": 2.0, "food": 4.0, "loyalty": -2.0},
				"summary_ru": "Больной скот забили, крестьянам возместили потери.",
				"summary_en": "The sick herds were culled and the peasants compensated.",
			},
			{
				"label_ru": "Объявить карантин", "label_en": "Quarantine the herds",
				"effects": {"stability": 2.0, "food": -5.0, "loyalty": -4.0},
				"summary_ru": "Стада заперли в карантин — мор отступил, но мяса меньше.",
				"summary_en": "The herds were quarantined — the plague eased, but meat grew scarce.",
			},
		],
	},
	{
		"id": "city_fire", "image": "event_cauldron", "weight": 1.7,
		"title_ru": "Пожар в столице", "title_en": "Fire in the Capital",
		"body_ru": "Огонь охватил деревянные кварталы Стамбула. Тысячи остались без крова, народ смотрит на дворец.",
		"body_en": "Fire engulfs the wooden quarters of Istanbul. Thousands are left homeless; the people look to the palace.",
		"choices": [
			{
				"label_ru": "Отстроить за казну", "label_en": "Rebuild at crown expense",
				"cost": 2200.0,
				"effects": {"stability": 2.0, "loyalty": -3.0},
				"summary_ru": "Кварталы отстроили за счёт казны — народ благодарен.",
				"summary_en": "The quarters were rebuilt at the crown's expense — the people are grateful.",
			},
			{
				"label_ru": "Организовать дружины", "label_en": "Organize fire brigades",
				"effects": {"loyalty": -3.0, "stability": -8.0},
				"summary_ru": "Пожарные дружины кое-как справились — без большой казны.",
				"summary_en": "Bucket brigades managed somehow — without great cost.",
			},
		],
	},
	{
		"id": "caravan_tribute", "image": "event_cauldron", "weight": 1.4,
		"title_ru": "Караван с данью", "title_en": "A Tribute Caravan",
		"body_ru": "Из дальних санджаков прибыл караван с данью. Дороги небезопасны, разбойники рыщут поблизости.",
		"body_en": "A caravan bearing tribute arrives from distant sanjaks. The roads are unsafe; bandits prowl nearby.",
		"choices": [
			{
				"label_ru": "Сопроводить с охраной", "label_en": "Escort with troops",
				"req": {"army": 30.0},
				"effects": {"hazna": 4500.0, "stability": 3.0},
				"summary_ru": "Караван довели под охраной — казна пополнилась сполна.",
				"summary_en": "The caravan was escorted safely — the treasury filled in full.",
			},
			{
				"label_ru": "Обложить пошлиной", "label_en": "Levy a toll",
				"effects": {"hazna": 2500.0, "loyalty": -3.0},
				"summary_ru": "С каравана взяли пошлину — золото есть, купцы недовольны.",
				"summary_en": "A toll was taken — gold flows, the merchants grumble.",
			},
		],
	},
	{
		"id": "madrasa_founding", "image": "event_cauldron", "weight": 1.2,
		"title_ru": "Основание медресе", "title_en": "Founding a Madrasa",
		"body_ru": "Улемы просят основать новое медресе. Учёность укрепит веру и закон, но содержание недёшево.",
		"body_en": "The ulema ask to found a new madrasa. Learning will strengthen faith and law, but its upkeep is costly.",
		"choices": [
			{
				"label_ru": "Основать пышно", "label_en": "Found it grandly",
				"cost": 2000.0,
				"effects": {"legitimacy": 6.0, "loyalty": 5.0, "stability": 4.0},
				"summary_ru": "Основано пышное медресе — улемы славят султана.",
				"summary_en": "A grand madrasa was founded — the ulema praise the Sultan.",
			},
			{
				"label_ru": "Скромная школа", "label_en": "A modest school",
				"effects": {"legitimacy": 2.0},
				"summary_ru": "Открыли скромную школу при мечети — малое благо.",
				"summary_en": "A modest mosque school was opened — a small boon.",
			},
		],
	},
	{
		"id": "wakf_dispute", "image": "event_cauldron", "weight": 1.7,
		"title_ru": "Спор о вакфе", "title_en": "A Waqf Dispute",
		"body_ru": "Богатый вакф остался без попечителя. Улемы и казначеи тянут его доходы каждый на себя.",
		"body_en": "A wealthy waqf endowment is left without a trustee. Ulema and treasurers each pull its revenues their way.",
		"choices": [
			{
				"label_ru": "В пользу улемов", "label_en": "Rule for the ulema",
				"effects": {"legitimacy": 5.0, "hazna": -800.0},
				"summary_ru": "Вакф отдан улемам — вера довольна, казна недосчиталась.",
				"summary_en": "The waqf went to the ulema — the faith is pleased, the treasury less so.",
			},
			{
				"label_ru": "В пользу казны", "label_en": "Rule for the treasury",
				"effects": {"hazna": 3000.0, "legitimacy": -5.0},
				"summary_ru": "Доходы вакфа влились в казну — улемы оскорблены.",
				"summary_en": "The waqf's revenues flowed to the treasury — the ulema are affronted.",
			},
		],
	},

	# ── Упадок армии (открываются при низкой армии) ──
	{
		"id": "desertion", "image": "event_cauldron", "weight": 2.6, "max_army": 42.0,
		"title_ru": "Дезертирство в войсках", "title_en": "Desertion in the Ranks",
		"body_ru": "Жалованье задержано, и солдаты бегут из лагерей. Армия тает на глазах.",
		"body_en": "Pay is in arrears and soldiers slip away from the camps. The army melts before your eyes.",
		"choices": [
			{
				"label_ru": "Выплатить жалованье", "label_en": "Pay the arrears",
				"cost": 3000.0,
				"effects": {"army": 12.0, "loyalty": 4.0},
				"summary_ru": "Жалованье выплачено — солдаты вернулись к знамёнам.",
				"summary_en": "The arrears were paid — the soldiers returned to the banners.",
			},
			{
				"label_ru": "Жёсткая дисциплина", "label_en": "Harsh discipline",
				"effects": {"stability": -7.0, "army": 6.0, "loyalty": -8.0, "opposition": 6.0},
				"summary_ru": "Беглецов наказали для острастки — порядок ценой страха.",
				"summary_en": "Deserters were punished as a warning — order at the price of fear.",
			},
		],
	},
	{
		"id": "recruit_shortage", "image": "event_cauldron", "weight": 2.6, "max_army": 40.0,
		"title_ru": "Нехватка солдат", "title_en": "Manpower Shortage",
		"body_ru": "Полки поредели, а границы неспокойны. Войску нужны новые руки — и поскорее.",
		"body_en": "The regiments are thin and the borders restless. The army needs fresh hands — and soon.",
		"choices": [
			{
				"label_ru": "Объявить набор", "label_en": "Levy fresh troops",
				"cost": 2200.0,
				"effects": {"stability": -7.0, "army": 14.0, "loyalty": -4.0},
				"summary_ru": "По провинциям объявлен набор — полки пополнились.",
				"summary_en": "A levy was called across the provinces — the regiments swelled.",
			},
			{
				"label_ru": "Нанять наёмников", "label_en": "Hire mercenaries",
				"cost": 4500.0,
				"effects": {"army": 20.0, "external_pressure": 6.0},
				"summary_ru": "Наняли наёмников — войско сильно, но казна и честь в убытке.",
				"summary_en": "Mercenaries were hired — a strong host, but treasury and honor suffer.",
			},
			{
				"label_ru": "Положиться на имеющихся", "label_en": "Make do",
				"effects": {"army": -4.0, "stability": -8.0},
				"summary_ru": "Решили обойтись своими — войско продолжает редеть.",
				"summary_en": "You chose to make do — the army keeps thinning.",
			},
		],
	},

	# ── Голод/крестьяне (открываются при нехватке еды) ──
	{
		"id": "peasant_discontent", "image": "event_cauldron", "weight": 2.6, "max_food": 46.0,
		"title_ru": "Недовольные крестьяне", "title_en": "Discontented Peasants",
		"body_ru": "Деревни ропщут: подати высоки, амбары пусты. Старосты шлют челобитные одну за другой.",
		"body_en": "The villages murmur: taxes are high, granaries empty. Headmen send petition after petition.",
		"choices": [
			{
				"label_ru": "Снизить подати", "label_en": "Lower the taxes",
				"effects": {"loyalty": 7.0, "stability": 2.0, "hazna": -700.0},
				"summary_ru": "Подати снижены — крестьяне вздохнули свободнее.",
				"summary_en": "Taxes were lowered — the peasants breathe easier.",
			},
			{
				"label_ru": "Раздать хлеб", "label_en": "Hand out grain",
				"cost": 1800.0,
				"effects": {"food": 12.0, "loyalty": 6.0},
				"summary_ru": "Народу раздали хлеб из казённых амбаров.",
				"summary_en": "Grain from the state stores was handed out to the people.",
			},
			{
				"label_ru": "Подавить ропот", "label_en": "Suppress the murmurs",
				"req": {"army": 25.0},
				"effects": {"stability": 2.0, "loyalty": -9.0, "opposition": 7.0},
				"summary_ru": "Недовольных усмирили войсками — тихо, но злобу затаили.",
				"summary_en": "The discontent were cowed by troops — quiet, but resentful.",
			},
		],
	},
	{
		"id": "crop_failure", "image": "event_cauldron", "weight": 2.6, "max_food": 44.0,
		"title_ru": "Неурожай", "title_en": "Crop Failure",
		"body_ru": "Засуха выжгла поля. Урожай скуден, и призрак голода бродит по деревням.",
		"body_en": "Drought has scorched the fields. The harvest is meagre, and the spectre of famine walks the villages.",
		"choices": [
			{
				"label_ru": "Закупить продовольствие", "label_en": "Buy provisions abroad",
				"cost": 3000.0,
				"effects": {"food": 18.0, "stability": 2.0},
				"summary_ru": "Зерно закуплено за морем — амбары снова полны.",
				"summary_en": "Grain was bought overseas — the granaries fill once more.",
			},
			{
				"label_ru": "Открыть резервы", "label_en": "Open the reserves",
				"effects": {"food": 9.0, "stability": -8.0},
				"summary_ru": "Открыли неприкосновенный запас — облегчение на время.",
				"summary_en": "The emergency reserves were opened — relief for a while.",
			},
		],
	},

	# ── Падение стабильности ──
	{
		"id": "provincial_unrest", "image": "event_cauldron", "weight": 2.6, "max_stability": 40.0,
		"title_ru": "Волнения в провинции", "title_en": "Provincial Unrest",
		"body_ru": "В одном из эялетов вспыхнули беспорядки. Наместник просит указаний, пока искра не стала пожаром.",
		"body_en": "Unrest flares in one of the eyalets. The governor begs for orders before the spark becomes a blaze.",
		"choices": [
			{
				"label_ru": "Послать наместника", "label_en": "Send a trusted governor",
				"cost": 2000.0,
				"effects": {"stability": 2.0, "loyalty": 4.0},
				"summary_ru": "Надёжный наместник усмирил край миром и золотом.",
				"summary_en": "A trusted governor settled the province with gold and calm.",
			},
			{
				"label_ru": "Ввести войска", "label_en": "March in troops",
				"req": {"army": 30.0},
				"effects": {"stability": 2.0, "loyalty": -7.0, "opposition": 5.0},
				"summary_ru": "Беспорядки подавлены войсками — порядок ценой крови.",
				"summary_en": "The unrest was crushed by troops — order at the price of blood.",
			},
			{
				"label_ru": "Пустить на самотёк", "label_en": "Let it burn out",
				"effects": {"stability": -7.0, "loyalty": -5.0},
				"summary_ru": "Беспорядки оставили тлеть — край всё глубже в смуте.",
				"summary_en": "The unrest was left to smoulder — the province sinks deeper into chaos.",
			},
		],
	},
	{
		"id": "divan_split", "image": "event_cauldron", "weight": 1.8, "max_stability": 46.0,
		"title_ru": "Раскол в Диване", "title_en": "A Split in the Divan",
		"body_ru": "Везиры Дивана сцепились в борьбе за влияние. Совет парализован, указы стоят.",
		"body_en": "The viziers of the Divan are locked in a struggle for influence. The council is paralyzed, decrees stalled.",
		"choices": [
			{
				"label_ru": "Примирить везиров", "label_en": "Reconcile the viziers",
				"cost": 1800.0,
				"effects": {"stability": 7.0, "loyalty": 4.0},
				"summary_ru": "Везиров примирили — Диван снова работает слаженно.",
				"summary_en": "The viziers were reconciled — the Divan works as one again.",
			},
			{
				"label_ru": "Сместить смутьянов", "label_en": "Dismiss the troublemakers",
				"effects": {"stability": 5.0, "loyalty": -6.0, "opposition": 6.0},
				"summary_ru": "Смутьянов сместили — порядок есть, обиженные затаились.",
				"summary_en": "The troublemakers were dismissed — order restored, the slighted seethe.",
			},
		],
	},

	# ── Рост оппозиции ──
	{
		"id": "seditious_pamphlets", "image": "event_cauldron", "weight": 2.6, "min_opposition": 35.0,
		"title_ru": "Крамольные памфлеты", "title_en": "Seditious Pamphlets",
		"body_ru": "По базарам ходят листки, что чернят султана. Слово опаснее сабли, если его не остановить.",
		"body_en": "Leaflets slandering the Sultan circulate through the bazaars. A word is sharper than a sabre if left unchecked.",
		"choices": [
			{
				"label_ru": "Цензура и аресты", "label_en": "Censor and arrest",
				"cost": 1500.0,
				"effects": {"stability": -7.0, "opposition": -12.0, "loyalty": -4.0},
				"summary_ru": "Печатников схватили, листки сожгли — ропот притих.",
				"summary_en": "The printers were seized and the leaflets burned — the murmuring fell quiet.",
			},
			{
				"label_ru": "Контр-пропаганда", "label_en": "Counter-propaganda",
				"effects": {"opposition": -6.0, "legitimacy": 4.0, "hazna": -600.0},
				"summary_ru": "Улемы и поэты восславили султана в ответ.",
				"summary_en": "Ulema and poets sang the Sultan's praises in answer.",
			},
			{
				"label_ru": "Не обращать внимания", "label_en": "Pay it no mind",
				"effects": {"opposition": 8.0, "stability": -8.0},
				"summary_ru": "Памфлеты оставили без ответа — их стало лишь больше.",
				"summary_en": "The pamphlets went unanswered — and only multiplied.",
			},
		],
	},
	{
		"id": "tax_protest", "image": "event_cauldron", "weight": 2.6, "min_opposition": 30.0,
		"title_ru": "Протест против налогов", "title_en": "Tax Protest",
		"body_ru": "Новые поборы взбесили горожан. Лавки закрываются, толпа собирается у мечети.",
		"body_en": "The new levies have enraged the townsfolk. Shops shutter, a crowd gathers at the mosque.",
		"choices": [
			{
				"label_ru": "Отменить новый налог", "label_en": "Repeal the new tax",
				"effects": {"opposition": -10.0, "loyalty": 5.0, "hazna": -800.0},
				"summary_ru": "Налог отменён — горожане ликуют, казна в убытке.",
				"summary_en": "The tax was repealed — the townsfolk rejoice, the treasury loses out.",
			},
			{
				"label_ru": "Обещать пересмотр", "label_en": "Promise a review",
				"effects": {"opposition": -4.0, "stability": -8.0},
				"summary_ru": "Толпе пообещали пересмотр — гнев отложен.",
				"summary_en": "The crowd was promised a review — its anger postponed.",
			},
			{
				"label_ru": "Разогнать силой", "label_en": "Disperse by force",
				"req": {"army": 25.0},
				"effects": {"stability": 2.0, "loyalty": -8.0, "opposition": 6.0},
				"summary_ru": "Протест разогнали войсками — улицы пусты, сердца полны злобы.",
				"summary_en": "The protest was scattered by troops — empty streets, bitter hearts.",
			},
		],
	},

	# ── Падение лояльности ──
	{
		"id": "noble_grievance", "image": "event_cauldron", "weight": 1.8, "max_loyalty": 42.0,
		"title_ru": "Знать ропщет", "title_en": "The Nobles Grumble",
		"body_ru": "Старая знать недовольна: их обходят милостями, а выскочки богатеют. Шёпот в коридорах крепнет.",
		"body_en": "The old nobility is sullen: favours pass them by while upstarts grow rich. The whispering in the halls swells.",
		"choices": [
			{
				"label_ru": "Пир и подарки", "label_en": "A feast and gifts",
				"cost": 2400.0,
				"effects": {"loyalty": 9.0, "stability": 3.0},
				"summary_ru": "Знать осыпали милостями на пиру — верность вернулась.",
				"summary_en": "The nobles were showered with favour at a feast — loyalty returned.",
			},
			{
				"label_ru": "Даровать привилегии", "label_en": "Grant privileges",
				"effects": {"loyalty": 6.0, "stability": -4.0},
				"summary_ru": "Знати даровали привилегии — верность куплена ценой власти.",
				"summary_en": "Privileges were granted — loyalty bought at the cost of authority.",
			},
			{
				"label_ru": "Не уступать", "label_en": "Yield nothing",
				"effects": {"loyalty": -6.0, "opposition": 6.0},
				"summary_ru": "Султан не уступил — знать затаила обиду.",
				"summary_en": "The Sultan yielded nothing — the nobles nurse a grudge.",
			},
		],
	},

	# ── ОСТРЫЕ / ОПАСНЫЕ события ──
	{
		"id": "famine", "image": "event_cauldron", "weight": 3.4, "max_food": 34.0,
		"title_ru": "Великий голод", "title_en": "The Great Famine",
		"body_ru": "Амбары пусты, на улицах умирают от голода. Народ на грани восстания — промедление будет стоить трона.",
		"body_en": "The granaries are empty; people die of hunger in the streets. The realm teeters on revolt — delay will cost the throne.",
		"choices": [
			{
				"label_ru": "Срочный ввоз зерна", "label_en": "Emergency grain import",
				"cost": 4200.0,
				"effects": {"food": 26.0, "stability": 2.0, "opposition": -6.0, "loyalty": -3.0},
				"summary_ru": "Зерно завезли из-за моря — голод отступил в последний миг.",
				"summary_en": "Grain was rushed in from overseas — famine receded at the last moment.",
			},
			{
				"label_ru": "Открыть все амбары", "label_en": "Open every granary",
				"effects": {"food": 13.0, "stability": -8.0, "loyalty": -5.0},
				"summary_ru": "Опустошили последние запасы — облегчение, но впереди голые амбары.",
				"summary_en": "The last stores were emptied — relief now, bare granaries ahead.",
			},
			{
				"label_ru": "Положиться на провидение", "label_en": "Trust to providence",
				"effects": {"stability": -11.0, "loyalty": -18.0, "opposition": 12.0},
				"summary_ru": "Власть бездействовала — голод выкосил деревни, народ проклинает султана.",
				"summary_en": "The crown did nothing — famine ravaged the villages, the people curse the Sultan.",
			},
		],
	},
	{
		"id": "city_disaster", "image": "event_cauldron", "weight": 2.5,
		"title_ru": "Стихия разрушила город", "title_en": "A City Laid Waste",
		"body_ru": "Землетрясение и пожары сравняли с землёй один из ваших городов. Кварталы, что вы поднимали годами, лежат в руинах.",
		"body_en": "Earthquake and fire have levelled one of your cities. The quarters you raised over years lie in ruins.",
		"choices": [
			{
				"label_ru": "Бросить казну на восстановление", "label_en": "Pour the treasury into rebuilding",
				"cost": 3200.0,
				"effects": {"raze_province": 0.55, "stability": 2.0, "loyalty": -3.0},
				"summary_ru": "Город отстраивают за счёт казны — потеряно немногое, но дорого.",
				"summary_en": "The city is rebuilt at crown expense — little was lost, but at great cost.",
			},
			{
				"label_ru": "Восстанавливать своими силами", "label_en": "Let it rebuild itself",
				"effects": {"raze_province": 0.15, "stability": -7.0, "loyalty": -9.0, "food": -4.0},
				"summary_ru": "Город оставили подниматься самому — почти всё развитие утрачено, прокачивать заново.",
				"summary_en": "The city was left to rebuild on its own — nearly all its development is lost; start it anew.",
			},
		],
	},
	{
		"id": "pasha_powergrab", "image": "event_cauldron", "weight": 2.4, "min_opposition": 38.0,
		"title_ru": "Паша рвётся к власти", "title_en": "A Pasha Grasps for Power",
		"body_ru": "Влиятельный паша собрал вокруг себя войско и казну. Он ещё кланяется трону — но всё ниже, и всё реже.",
		"body_en": "A powerful pasha has gathered troops and treasure about himself. He still bows to the throne — but lower, and less often.",
		"choices": [
			{
				"label_ru": "Сместить и казнить", "label_en": "Recall and execute him",
				"req": {"army": 40.0},
				"effects": {"opposition": -20.0, "stability": 5.0, "loyalty": -8.0},
				"summary_ru": "Пашу вызвали ко двору и казнили — урок для всех честолюбцев.",
				"summary_en": "The pasha was summoned and executed — a lesson to all the ambitious.",
			},
			{
				"label_ru": "Откупиться титулами", "label_en": "Buy him off with titles",
				"cost": 3600.0,
				"effects": {"opposition": -14.0, "stability": 2.0},
				"summary_ru": "Паше дали титулы и золото — его честолюбие пока утолено.",
				"summary_en": "The pasha was given titles and gold — his ambition sated, for now.",
			},
			{
				"label_ru": "Даровать автономию", "label_en": "Grant him autonomy",
				"effects": {"opposition": -8.0, "stability": -8.0, "legitimacy": -6.0},
				"summary_ru": "Паше отдали край в управление — мир куплен ценой власти султана.",
				"summary_en": "The pasha was granted his province — peace bought at the cost of the Sultan's authority.",
			},
		],
	},
	{
		"id": "foreign_ultimatum", "image": "event_cauldron", "weight": 2.7, "min_external_pressure": 30.0,
		"title_ru": "Иноземный ультиматум", "title_en": "A Foreign Ultimatum",
		"body_ru": "Послы великих держав ставят под сомнение ваш суверенитет: либо уступки и дань, либо война у границ.",
		"body_en": "The envoys of the great powers question your sovereignty: concessions and tribute, or war upon the borders.",
		"choices": [
			{
				"label_ru": "Заплатить дань", "label_en": "Pay the tribute",
				"cost": 4000.0,
				"effects": {"external_pressure": -18.0, "legitimacy": -6.0},
				"summary_ru": "Дань уплачена — давление спало, но честь державы задета.",
				"summary_en": "The tribute was paid — the pressure eased, but the realm's honor is stained.",
			},
			{
				"label_ru": "Гордо отказать", "label_en": "Refuse with pride",
				"effects": {"external_pressure": 12.0, "legitimacy": 9.0, "stability": 2.0},
				"summary_ru": "Послов выпроводили — народ ликует, но тучи на границах сгустились.",
				"summary_en": "The envoys were sent packing — the people cheer, but storm clouds gather at the borders.",
			},
			{
				"label_ru": "Искать союзников", "label_en": "Seek allies",
				"cost": 2600.0,
				"effects": {"external_pressure": -10.0, "legitimacy": 3.0},
				"summary_ru": "Через тайную дипломатию нашли союзников — давление ослабло.",
				"summary_en": "Through quiet diplomacy allies were found — the pressure slackened.",
			},
		],
	},
	{
		"id": "great_plague", "image": "event_cauldron", "weight": 2.3,
		"title_ru": "Чёрный мор", "title_en": "The Black Death",
		"body_ru": "Корабли принесли в порты чёрный мор. Он расползается по кварталам, не щадя ни бедных, ни знатных.",
		"body_en": "Ships have brought the black death to the ports. It creeps through the quarters, sparing neither poor nor noble.",
		"choices": [
			{
				"label_ru": "Строгий карантин", "label_en": "Strict quarantine",
				"cost": 3000.0,
				"effects": {"stability": 2.0, "legitimacy": 5.0, "food": -6.0, "loyalty": -5.0},
				"summary_ru": "Города заперли в карантин — мор сдержан ценой торговли и хлеба.",
				"summary_en": "The cities were sealed in quarantine — the plague checked at the cost of trade and bread.",
			},
			{
				"label_ru": "Молиться и ждать", "label_en": "Pray and wait",
				"effects": {"stability": -11.0, "loyalty": -14.0, "food": -6.0, "opposition": 7.0},
				"summary_ru": "Власть лишь молилась — мор выкосил кварталы, народ в отчаянии.",
				"summary_en": "The crown only prayed — the plague gutted the districts, the people despair.",
			},
		],
	},
	{
		"id": "succession_intrigue", "image": "event_cauldron", "weight": 2.4, "min_opposition": 55.0,
		"title_ru": "Интрига о престоле", "title_en": "Intrigue for the Throne",
		"body_ru": "В гареме и Диване зреет заговор: иные хотят посадить на трон другого. Кинжалы точат в тишине.",
		"body_en": "In the harem and the Divan a plot ripens: some would place another on the throne. Daggers are honed in silence.",
		"choices": [
			{
				"label_ru": "Раскрыть заговор", "label_en": "Expose the plot",
				"req": {"army": 35.0},
				"effects": {"opposition": -22.0, "loyalty": -5.0, "stability": 4.0},
				"summary_ru": "Заговорщиков схватили на рассвете — трон устоял.",
				"summary_en": "The plotters were seized at dawn — the throne held firm.",
			},
			{
				"label_ru": "Подкупить претендента", "label_en": "Bribe the pretender",
				"cost": 4000.0,
				"effects": {"opposition": -16.0},
				"summary_ru": "Соперника осыпали золотом — он отступил в тень.",
				"summary_en": "The rival was showered with gold — he withdrew into the shadows.",
			},
			{
				"label_ru": "Закрыть глаза", "label_en": "Look the other way",
				"effects": {"opposition": 12.0, "stability": -6.0},
				"summary_ru": "Заговор оставили без внимания — кинжалы всё ближе к трону.",
				"summary_en": "The plot was ignored — the daggers draw ever closer to the throne.",
			},
		],
	},
	{
		"id": "crush_dissent", "image": "event_cauldron", "weight": 2.7, "min_opposition": 42.0,
		"title_ru": "Народ бунтует", "title_en": "The People Revolt",
		"body_ru": "Недовольство переполнило чашу: толпы заполнили площади, оппозиция дерзит открыто. Армия готова усмирить улицы — но это стоит крови и сил.",
		"body_en": "Discontent has boiled over: crowds fill the squares, the opposition defies you openly. The army stands ready to pacify the streets — but it will cost blood and strength.",
		"choices": [
			{
				"label_ru": "Двинуть армию на усмирение", "label_en": "Send the army to pacify",
				"effects": {"opposition": -28.0, "army": -12.0, "loyalty": -10.0, "stability": 4.0},
				"summary_ru": "Армия очистила площади — оппозиция сломлена, но войско и любовь народа поредели.",
				"summary_en": "The army cleared the squares — the opposition is broken, but the host and the people's love are thinned.",
			},
			{
				"label_ru": "Пойти на уступки", "label_en": "Make concessions",
				"cost": 2800.0,
				"effects": {"opposition": -14.0, "loyalty": 6.0},
				"summary_ru": "Уступки и подачки утихомирили толпу — но мятежный дух остался.",
				"summary_en": "Concessions and handouts quieted the crowd — though the rebellious spirit lingers.",
			},
			{
				"label_ru": "Переждать бурю", "label_en": "Wait out the storm",
				"effects": {"opposition": 6.0, "stability": -4.0},
				"summary_ru": "Власть выжидала — недовольство только окрепло.",
				"summary_en": "The crown waited — the discontent only hardened.",
			},
		],
	},

	# ── ДИНАСТИЯ / СЕМЬЯ ──
	# Предложения руки: приходят только при объявленном поиске (req_seeking).
	# Каждое привязано к конкретной невесте (req_wife_available), но ИМЯ на экране
	# не называется — женитьба «вслепую». Картинка общая (портрет не показываем).
	# id совпадает с файлом озвучки ev_<id>_body.mp3.
	{
		"id": "offer_gulnus", "image_path": "res://assets/art/events/ev_bride_offer.png", "weight": 1.4,
		"req_seeking": true, "req_wife_available": "gulnus",
		"title_ru": "Невеста из Мореи", "title_en": "A Bride from the Morea",
		"body_ru": "Знатный род Мореи предлагает султану в жёны свою дочь. Союз скрепит верность дальних земель и подарит дому наследников. Лица её при дворе ещё не видели.",
		"body_en": "The noble house of the Morea offers the Sultan their daughter in marriage. The union would bind distant lands in loyalty and bless the house with heirs. None at court have yet seen her face.",
		"choices": [
			{
				"label_ru": "Принять предложение", "label_en": "Accept the offer",
				"effects": {"marry": 1.0, "legitimacy": 6.0, "loyalty": 5.0, "stability": 3.0},
				"summary_ru": "Султан взял новую супругу — двор и народ ликуют. Кого послала судьба — увидим.",
				"summary_en": "The Sultan has taken a new consort — court and people rejoice. Whom fate sent, we shall see.",
			},
			{
				"label_ru": "Пока отказать", "label_en": "Decline for now",
				"effects": {"loyalty": -2.0},
				"summary_ru": "Сватовство отклонили — род Мореи затаил обиду.",
				"summary_en": "The match was declined — the Morean house took offence.",
			},
		],
	},
	{
		"id": "offer_emine", "image_path": "res://assets/art/events/ev_bride_offer.png", "weight": 1.3,
		"req_seeking": true, "req_wife_available": "emine",
		"title_ru": "Дочь паши", "title_en": "The Pasha's Daughter",
		"body_ru": "Влиятельный паша столицы предлагает в жёны свою дочь. За ней — поддержка двора и тугой кошель приданого. Имени её пока не называют.",
		"body_en": "An influential pasha of the capital offers his daughter in marriage. With her come the court's backing and a heavy purse of dowry. Her name is not yet spoken.",
		"choices": [
			{
				"label_ru": "Принять предложение", "label_en": "Accept the offer",
				"effects": {"marry": 1.0, "hazna": 1500.0, "legitimacy": 4.0, "loyalty": 4.0},
				"summary_ru": "Султан взял новую супругу — паша щедро одарил казну.",
				"summary_en": "The Sultan has taken a new consort — the pasha endowed the treasury.",
			},
			{
				"label_ru": "Пока отказать", "label_en": "Decline for now",
				"effects": {"loyalty": -2.0},
				"summary_ru": "Султан отказал паше — при дворе шепчутся.",
				"summary_en": "The Sultan refused the pasha — the court murmurs.",
			},
		],
	},
	{
		"id": "offer_rabia", "image_path": "res://assets/art/events/ev_bride_offer.png", "weight": 1.2,
		"req_seeking": true, "req_wife_available": "rabia",
		"title_ru": "Союз с ханом", "title_en": "An Alliance with the Khan",
		"body_ru": "Крымский хан, верный союзник, предлагает в жёны свою дочь. Брак скрепит союз и приструнит врагов на северных рубежах. Под покрывалом — тайна до самой свадьбы.",
		"body_en": "The Crimean Khan, a loyal ally, offers his daughter in marriage. The match would seal the alliance and steady the northern frontier. Beneath the veil lies a secret until the wedding.",
		"choices": [
			{
				"label_ru": "Скрепить союз браком", "label_en": "Seal the alliance by marriage",
				"effects": {"marry": 1.0, "legitimacy": 5.0, "army": 4.0, "external_pressure": -4.0},
				"summary_ru": "Союз с ханом скреплён — северные рубежи спокойнее.",
				"summary_en": "The alliance with the Khan is sealed — the north grows calmer.",
			},
			{
				"label_ru": "Пока отказать", "label_en": "Decline for now",
				"effects": {"external_pressure": 3.0},
				"summary_ru": "Хан оскорблён отказом — на границе неспокойно.",
				"summary_en": "The Khan is slighted — the border stirs.",
			},
		],
	},
	{
		"id": "offer_safiye", "image_path": "res://assets/art/events/ev_bride_offer.png", "weight": 1.2,
		"req_seeking": true, "req_wife_available": "safiye",
		"title_ru": "Невеста визирского дома", "title_en": "A Bride of the Vizier's House",
		"body_ru": "Старинный визирский дом предлагает в жёны свою дочь. За союзом — опытные руки в Диване и крепкая опора трону. Её имя откроется лишь после свадьбы.",
		"body_en": "An old vizierial house offers their daughter in marriage. The match brings seasoned hands in the Divan and a firm prop to the throne. Her name will be revealed only after the wedding.",
		"choices": [
			{
				"label_ru": "Принять предложение", "label_en": "Accept the offer",
				"effects": {"marry": 1.0, "legitimacy": 5.0, "stability": 5.0, "loyalty": 3.0},
				"summary_ru": "Султан взял новую супругу — Диван сплотился вокруг трона.",
				"summary_en": "The Sultan has taken a new consort — the Divan rallied to the throne.",
			},
			{
				"label_ru": "Пока отказать", "label_en": "Decline for now",
				"effects": {"stability": -2.0},
				"summary_ru": "Визирский дом уязвлён отказом.",
				"summary_en": "The vizier's house is wounded by the refusal.",
			},
		],
	},
	{
		"id": "consort_plague", "image": "event_cauldron", "weight": 2.0,
		"req_living_wife": true, "min_external_pressure": 18.0, "max_food": 70.0,
		"title_ru": "Чёрный мор в гареме", "title_en": "Black Death in the Harem",
		"body_ru": "Чума проникла за стены гарема. Одна из жён слегла в горячке — лекари бессильны, остаётся лишь дорогой карантин и молитвы.",
		"body_en": "Plague has crept past the harem walls. One of the consorts has fallen to fever — the physicians are helpless; only a costly quarantine and prayer remain.",
		"choices": [
			{
				"label_ru": "Оплатить карантин и лекарей", "label_en": "Pay for quarantine and physicians",
				"cost": 2400.0,
				"effects": {"stability": 2.0, "legitimacy": 2.0},
				"summary_ru": "Карантин остановил заразу — гарем уцелел.",
				"summary_en": "The quarantine halted the contagion — the harem was spared.",
			},
			{
				"label_ru": "Уповать на судьбу", "label_en": "Leave it to fate",
				"effects": {"widow": 1.0, "stability": -8.0, "legitimacy": -3.0},
				"summary_ru": "Мор не пощадил — султан овдовел. Двор в трауре.",
				"summary_en": "The plague did not spare her — the Sultan is widowed. The court mourns.",
			},
		],
	},
	# ── Гибель жены: при низкой поддержке толпа врывается в покои ──
	{
		"id": "consort_mob", "image": "event_cauldron", "weight": 1.6,
		"req_living_wife": true, "max_loyalty": 38.0, "max_stability": 40.0,
		"title_ru": "Бунт у стен дворца", "title_en": "Riot at the Palace Walls",
		"body_ru": "Доведённые до отчаяния крестьяне осадили дворец. Толпа жаждет крови двора и грозит ворваться в гарем. Удержать её можно лишь силой или золотом.",
		"body_en": "Peasants driven to despair have besieged the palace. The mob thirsts for courtly blood and threatens to break into the harem. Only force or gold can hold them.",
		"choices": [
			{
				"label_ru": "Бросить янычар на защиту", "label_en": "Send Janissaries to defend",
				"req": {"army": 30.0},
				"effects": {"loyalty": -3.0},
				"summary_ru": "Янычары отбили толпу — гарем уцелел, но кровь пролита.",
				"summary_en": "The Janissaries drove off the mob — the harem held, though blood was spilled.",
			},
			{
				"label_ru": "Откупиться от вожаков", "label_en": "Buy off the ringleaders",
				"cost": 2000.0,
				"effects": {"loyalty": 2.0},
				"summary_ru": "Вожаков подкупили — толпа отступила от дворца.",
				"summary_en": "The ringleaders were bribed — the mob fell back from the palace.",
			},
			{
				"label_ru": "Бросить дворец на произвол", "label_en": "Abandon the palace to the mob",
				"effects": {"widow": 1.0, "loyalty": -4.0, "stability": -4.0},
				"summary_ru": "Толпа ворвалась внутрь — одна из жён погибла от рук бунтовщиков.",
				"summary_en": "The mob broke in — one of the consorts fell to the rioters.",
			},
		],
	},
	{
		"id": "royal_birth", "image": "event_cauldron", "weight": 1.8, "req_child_slot": true,
		"title_ru": "Рождение наследника", "title_en": "A Royal Birth",
		"body_ru": "Радостная весть из гарема: супруга подарила султану дитя. Династия обретает будущее.",
		"body_en": "Joyful news from the harem: the consort has given the Sultan a child. The dynasty gains a future.",
		"choices": [
			{
				"label_ru": "Устроить торжество", "label_en": "Hold a celebration",
				"cost": 1800.0,
				"effects": {"bear_child": 1.0, "legitimacy": 6.0, "loyalty": 6.0},
				"summary_ru": "Рождение наследника отметили пышным праздником.",
				"summary_en": "The birth of an heir was marked with a grand festival.",
			},
			{
				"label_ru": "Принять скромно", "label_en": "Receive it quietly",
				"effects": {"bear_child": 1.0, "legitimacy": 3.0},
				"summary_ru": "Наследника приняли без лишней пышности.",
				"summary_en": "The heir was welcomed without great ceremony.",
			},
		],
	},
	{
		"id": "prince_fever", "image": "event_cauldron", "weight": 1.6, "req_living_child": true,
		"title_ru": "Шехзаде слёг", "title_en": "The Prince Falls Ill",
		"body_ru": "Наследника свалила жестокая горячка. Придворные лекари разводят руками — спасти его может лишь дорогое лечение и лучшие врачи.",
		"body_en": "A cruel fever has struck the heir. The court physicians despair — only the finest doctors and costly care can save him.",
		"choices": [
			{
				"label_ru": "Призвать лучших лекарей", "label_en": "Summon the finest physicians",
				"cost": 2600.0,
				"effects": {"loyalty": 3.0, "stability": 2.0},
				"summary_ru": "Лучшие лекари выходили шехзаде — династия вздохнула с облегчением.",
				"summary_en": "The finest physicians saved the prince — the dynasty breathes again.",
			},
			{
				"label_ru": "Уповать на молитвы", "label_en": "Trust to prayers",
				"effects": {"kill_child": 1.0, "loyalty": -6.0, "stability": -4.0},
				"summary_ru": "Молитвы не помогли — шехзаде угас. Двор в трауре.",
				"summary_en": "Prayers did not avail — the prince passed. The court mourns.",
			},
		],
	},
	{
		"id": "prince_peril", "image": "event_cauldron", "weight": 1.5, "req_living_child": true,
		"title_ru": "Угроза наследнику", "title_en": "The Heir in Peril",
		"body_ru": "Мятежная толпа и вражеские лазутчики угрожают жизни шехзаде. Промедление может стоить династии будущего.",
		"body_en": "A rebellious mob and enemy agents threaten the heir's life. Hesitation may cost the dynasty its future.",
		"choices": [
			{
				"label_ru": "Стража из янычар", "label_en": "A guard of Janissaries",
				"req": {"army": 25.0},
				"effects": {"loyalty": 2.0},
				"summary_ru": "Янычары укрыли шехзаде за стенами — наследник цел.",
				"summary_en": "The Janissaries shielded the prince — the heir is safe.",
			},
			{
				"label_ru": "Тайно вывезти", "label_en": "Spirit him away",
				"cost": 2200.0,
				"effects": {"stability": -2.0},
				"summary_ru": "Наследника тайно вывезли в безопасное место.",
				"summary_en": "The heir was secretly spirited to safety.",
			},
			{
				"label_ru": "Понадеяться на судьбу", "label_en": "Leave it to fate",
				"effects": {"kill_child": 1.0, "loyalty": -7.0, "stability": -5.0},
				"summary_ru": "Беду не отвели — шехзаде погиб от рук врагов.",
				"summary_en": "The danger was not averted — the prince fell to his enemies.",
			},
		],
	},
	# ── Заговор наследника: при высокой оппозиции взрослый сын может свергнуть отца ──
	{
		"id": "heir_conspiracy", "image": "event_cauldron", "weight": 1.9,
		"req_adult_heir": true, "min_opposition": 35.0, "min_heir_wait_or_opposition": 62.0,
		"title_ru": "Заговор наследника", "title_en": "The Heir's Conspiracy",
		"body_ru": "Оппозиция сильна как никогда, а взрослый шехзаде нетерпелив. До трона доходят слухи: сын сговаривается с недовольными, чтобы низложить отца и взойти на трон самому.",
		"body_en": "Opposition is at its height, and the grown prince is impatient. Whispers reach the throne: the son is conspiring with the discontented to depose his father and seize the throne himself.",
		"choices": [
			{
				"label_ru": "Задобрить двор и сына", "label_en": "Appease the court and the prince",
				"cost": 3000.0,
				"effects": {"opposition": -14.0, "loyalty": 4.0},
				"summary_ru": "Золото и посулы остудили заговор — сын смирился... до поры.",
				"summary_en": "Gold and promises cooled the plot — the prince relented... for now.",
			},
			{
				"label_ru": "Раскрыть заговор силой", "label_en": "Crush the plot by force",
				"req": {"army": 35.0},
				"effects": {"opposition": -8.0, "loyalty": -4.0, "legitimacy": -3.0},
				"summary_ru": "Заговорщиков схватили — сын присмирел, но двор затаился.",
				"summary_en": "The plotters were seized — the prince cowed, the court wary.",
			},
			{
				"label_ru": "Не принимать всерьёз", "label_en": "Dismiss it as idle talk",
				"effects": {"usurp": 1.0},
				"summary_ru": "Промедление стоило трона: сын низложил отца. Держава расколота, посольства отозваны — новому султану достаётся тлеющий котёл.",
				"summary_en": "Hesitation cost the throne: the son deposed his father. The realm is split, envoys recalled — the new Sultan inherits a smouldering cauldron.",
			},
		],
	},
	# ── Генштаб требует личного участия султана ──
	{
		"id": "general_staff", "image": "event_cauldron", "weight": 1.5, "req_reform": true,
		"title_ru": "Генштаб требует вашего вмешательства",
		"title_en": "The General Staff Demands Your Involvement",
		"body_ru": "Генеральный штаб в растерянности: без султана армия не смеет решать судьбу державы. Военный совет настойчиво зовёт вас лично возглавить заседания — иначе приказы стоят, а смута зреет.",
		"body_en": "The General Staff is at a loss: without the Sultan, the army dares not decide the realm's fate. The war council insistently summons you to lead the sessions in person — otherwise orders stall and unrest festers.",
		"choices": [
			{
				"label_ru": "Прибыть на военный совет", "label_en": "Attend the war council",
				"cost": 20000.0, "staff_cost": true,
				"effects": {"stability": 16.0, "loyalty": 4.0, "army": 3.0, "join_staff": 1.0},
				"summary_ru": "Султан лично возглавил совет — армия воспряла, в державе порядок.",
				"summary_en": "The Sultan led the council in person — the army rallied, order restored.",
			},
			{
				"label_ru": "Отклонить приглашение", "label_en": "Decline the summons",
				"effects": {"opposition": 18.0, "stability": -4.0},
				"summary_ru": "Султан не явился — армия оскорблена, недовольство стремительно растёт.",
				"summary_en": "The Sultan stayed away — the army is slighted; discontent surges.",
			},
		],
	},
	# ── Совет генштаба: открывается после «Прибыть на военный совет» (join_staff) ──
	{
		"id": "staff_coup_fear", "weight": 1.5, "req_staff": true, "max_loyalty": 40.0,
		"image_path": "res://assets/art/events/staff_council.png",
		"title_ru": "Генштаб: угроза переворота",
		"title_en": "General Staff: Threat of a Coup",
		"body_ru": "На совете генштаб бьёт тревогу: поддержка власти народом слишком мала, и в столице зреет заговор. Генералы предлагают упредить удар и мобилизовать все силы — но казне это обойдётся дорого.",
		"body_en": "At the council the General Staff sounds the alarm: popular support for the throne is dangerously low and a plot is brewing in the capital. The generals urge a pre-emptive mobilisation of all forces — but it will cost the treasury dearly.",
		"choices": [
			{
				"label_ru": "Мобилизовать все силы для подавления", "label_en": "Mobilise all forces to suppress it",
				"cost": 20000.0, "staff_cost": true,
				"effects": {"loyalty": 18.0, "stability_to_50": 1.0, "opposition": -6.0},
				"summary_ru": "Силы стянуты к столице — заговор подавлен в зародыше, поддержка окрепла.",
				"summary_en": "Forces massed on the capital — the plot was crushed early, support firmed up.",
			},
			{
				"label_ru": "Ничего не делать", "label_en": "Do nothing",
				"effects": {"opposition": 7.0, "loyalty": -3.0},
				"summary_ru": "Султан промолчал — угроза переворота никуда не делась, в столице ропот.",
				"summary_en": "The Sultan did nothing — the coup threat lingers and the capital murmurs.",
			},
		],
	},
	{
		"id": "staff_opposition", "weight": 1.5, "req_staff": true, "min_opposition": 30.0,
		"image_path": "res://assets/art/events/staff_council.png",
		"title_ru": "Генштаб: рост оппозиции",
		"title_en": "General Staff: Rising Opposition",
		"body_ru": "Генеральный штаб обеспокоен: оппозиция набирает силу. Можно попытаться договориться мирно — или пустить в ход подкупленных людей и развалить её изнутри, что обойдётся казне недёшево.",
		"body_en": "The General Staff is worried: the opposition is gaining strength. You may try to settle matters peacefully — or unleash bribed agents to rot it from within, which the treasury will feel.",
		"choices": [
			{
				"label_ru": "Решить вопрос мирным путём", "label_en": "Settle the matter peacefully",
				"effects": {"opposition": -8.0, "loyalty": 2.0},
				"summary_ru": "Переговоры слегка остудили недовольных — оппозиция чуть отступила.",
				"summary_en": "Talks cooled the malcontents a little — the opposition eased somewhat.",
			},
			{
				"label_ru": "Подкупить и развалить изнутри", "label_en": "Bribe agents to break it from within",
				"cost": 20000.0, "staff_cost": true,
				"effects": {"opposition_mult": 0.5},
				"summary_ru": "Подкупленные люди раскололи оппозицию — её сила упала вдвое.",
				"summary_en": "Bribed agents split the opposition — its strength was cut in half.",
			},
		],
	},
	{
		"id": "staff_low_stability", "weight": 1.5, "req_staff": true, "max_stability": 40.0,
		"image_path": "res://assets/art/events/staff_council.png",
		"title_ru": "Генштаб: держава расшатана",
		"title_en": "General Staff: The Realm Is Shaken",
		"body_ru": "На совете генштаб мрачен: порядок в державе расшатан, гарнизоны ропщут, наместники своевольничают. Генералы предлагают ввести военное положение — но казне это обойдётся дорого.",
		"body_en": "At the council the General Staff is grim: order in the realm is shaken, garrisons grumble, governors defy the throne. The generals propose martial law — but it will cost the treasury dearly.",
		"choices": [
			{
				"label_ru": "Ввести военное положение", "label_en": "Declare martial law",
				"cost": 20000.0, "staff_cost": true,
				"effects": {"stability": 20.0, "loyalty": -6.0, "opposition": -4.0},
				"summary_ru": "Армия взяла улицы под контроль — порядок восстановлен, но народ притих недобро.",
				"summary_en": "The army took the streets — order was restored, though the people fell grimly silent.",
			},
			{
				"label_ru": "Обойтись увещеваниями", "label_en": "Rely on admonitions",
				"effects": {"stability": 4.0, "opposition": 3.0},
				"summary_ru": "Столицу успокоили словами — трещины замазаны, но не заделаны.",
				"summary_en": "The capital was soothed with words — the cracks were papered over, not mended.",
			},
		],
	},
	# ── БЫТОВЫЕ СОБЫТИЯ: непогода, разбой, набеги ──
	{
		"id": "bad_harvest", "image": "event_cauldron", "weight": 2.6, "max_food": 60.0,
		"title_ru": "Дожди сгубили урожай", "title_en": "Rains Ruin the Harvest",
		"body_ru": "Всё лето лили дожди — зерно гниёт прямо в полях. Крестьяне шепчутся по деревням: зимой есть будет нечего.",
		"body_en": "It rained all summer — the grain rots in the fields. Peasants whisper across the villages: come winter, there will be nothing to eat.",
		"choices": [
			{
				"label_ru": "Снизить налог на сёла", "label_en": "Lower the village tax",
				"effects": {"hazna": -1200.0, "food": 6.0, "stability": 2.0, "loyalty": -3.0},
				"summary_ru": "Сёлам скостили подать — люди вздохнули и сберегли зерно на сев.",
				"summary_en": "The villages' dues were eased — people breathed out and saved seed grain.",
			},
			{
				"label_ru": "Собрать налог как обычно", "label_en": "Collect the tax as usual",
				"effects": {"stability": -7.0, "hazna": 900.0, "loyalty": -12.0, "food": -6.0, "opposition": 4.0},
				"summary_ru": "Подати собрали до зёрнышка — казна полна, деревня зла и голодна.",
				"summary_en": "The dues were collected to the last grain — the treasury full, the village angry and hungry.",
			},
		],
	},
	{
		"id": "cossack_raid", "max_year": 1800, "image": "event_cauldron", "weight": 2.2, "min_external_pressure": 14.0,
		"title_ru": "Набег казаков", "title_en": "A Cossack Raid",
		"body_ru": "С севера налетели казаки: пограничное селение разграблено, скот угнан, хаты дымятся. Люди требуют защиты.",
		"body_en": "Cossacks swept in from the north: a border village plundered, cattle driven off, huts smoking. The people demand protection.",
		"choices": [
			{
				"label_ru": "Выслать сипахов в погоню", "label_en": "Send sipahis in pursuit",
				"req": {"army": 20.0},
				"effects": {"army": -3.0, "stability": 2.0, "external_pressure": -3.0, "loyalty": -3.0},
				"summary_ru": "Сипахи настигли налётчиков у брода — добро вернули, граница притихла.",
				"summary_en": "The sipahis caught the raiders at the ford — the goods returned, the border quiet.",
			},
			{
				"label_ru": "Откупиться и укрепить село", "label_en": "Pay off and fortify",
				"cost": 1800.0,
				"effects": {"stability": 2.0, "loyalty": -2.0},
				"summary_ru": "Селение отстроили и обнесли частоколом — набеги стали реже.",
				"summary_en": "The village was rebuilt and palisaded — the raids grew rarer.",
			},
			{
				"label_ru": "Граница сама разберётся", "label_en": "The border will cope",
				"effects": {"stability": -7.0, "loyalty": -11.0, "opposition": 5.0, "external_pressure": 3.0},
				"summary_ru": "Помощь не пришла — на границе запомнили равнодушие Порты.",
				"summary_en": "No help came — the frontier remembered the Porte's indifference.",
			},
		],
	},
	{
		"id": "hajduk_ambush", "image": "event_cauldron", "weight": 2.1, "min_opposition": 12.0,
		"title_ru": "Гайдуки на горной дороге", "title_en": "Hajduks on the Mountain Road",
		"body_ru": "В балканских теснинах гайдуки перехватили конвой с казённым серебром и украшениями для двора. Охрана перебита, сундуки исчезли в лесах.",
		"body_en": "In the Balkan defiles, hajduks seized a convoy of state silver and jewels for the court. The guards slain, the chests vanished into the woods.",
		"choices": [
			{
				"label_ru": "Прочесать горы", "label_en": "Comb the mountains",
				"req": {"army": 25.0},
				"effects": {"army": -4.0, "hazna": 1400.0, "stability": 2.0, "opposition": -3.0, "loyalty": -2.0},
				"summary_ru": "Отряды прочесали ущелья — часть серебра отбили, шайки рассеяны.",
				"summary_en": "Columns swept the gorges — part of the silver retaken, the bands scattered.",
			},
			{
				"label_ru": "Нанять горных проводников", "label_en": "Hire mountain guides",
				"cost": 1000.0,
				"effects": {"stability": 2.0, "loyalty": -1.0},
				"summary_ru": "Караваны повели тайными тропами — гайдуки остались ни с чем.",
				"summary_en": "The caravans took secret paths — the hajduks were left with nothing.",
			},
			{
				"label_ru": "Списать потери", "label_en": "Write off the loss",
				"effects": {"hazna": -1500.0, "stability": -8.0, "opposition": 3.0, "loyalty": -3.0},
				"summary_ru": "Сундуки так и сгинули — по дорогам пошла молва о слабой страже.",
				"summary_en": "The chests were never found — word of weak guards spread along the roads.",
			},
		],
	},
	{
		"id": "chumak_robbery", "image": "event_cauldron", "weight": 2.1,
		"title_ru": "Разбой на чумацком шляхе", "title_en": "Robbery on the Chumak Road",
		"body_ru": "Разбойники напали на обоз чумаков, вёзших соль и рыбу с юга. Возы сожжены, волы разбежались — торговцы боятся выходить на шлях.",
		"body_en": "Brigands fell upon a chumak train hauling salt and fish from the south. Wagons burned, oxen scattered — traders fear to take the road.",
		"choices": [
			{
				"label_ru": "Поставить разъезды на шляхе", "label_en": "Post patrols on the road",
				"cost": 1200.0,
				"effects": {"stability": 2.0, "food": 4.0, "loyalty": -2.0},
				"summary_ru": "Разъезды очистили шлях — обозы снова везут соль и рыбу.",
				"summary_en": "Patrols cleared the road — the trains haul salt and fish once more.",
			},
			{
				"label_ru": "Пусть купцы наймут охрану сами", "label_en": "Let merchants hire guards",
				"effects": {"stability": -7.0, "hazna": 300.0, "loyalty": -8.0, "food": -4.0},
				"summary_ru": "Купцы наняли охрану сами — цены на соль поползли вверх.",
				"summary_en": "The merchants hired their own guards — the price of salt crept upward.",
			},
		],
	},
	{
		"id": "storm_ruin", "image": "event_cauldron", "weight": 2.3, "max_stability": 70.0,
		"title_ru": "Буря разрушила дома", "title_en": "The Storm Wrecked the Homes",
		"body_ru": "Ночная буря сорвала крыши и повалила глинобитные дома в предместьях. Семьи ютятся на пепелищах и боятся остаться на улице к холодам.",
		"body_en": "A night storm tore off roofs and toppled mud-brick homes in the suburbs. Families huddle in the ruins, fearing the cold will find them homeless.",
		"choices": [
			{
				"label_ru": "Отстроить за счёт казны", "label_en": "Rebuild at state expense",
				"cost": 2200.0,
				"effects": {"stability": 2.0, "opposition": -3.0, "loyalty": -3.0},
				"summary_ru": "Плотники Порты подняли дома до холодов — беду пережили без обид.",
				"summary_en": "The Porte's carpenters raised the homes before the cold — the people bless the Sultan.",
			},
			{
				"label_ru": "Раздать лес и глину", "label_en": "Hand out timber and clay",
				"cost": 800.0,
				"effects": {"loyalty": -2.0, "stability": 2.0},
				"summary_ru": "Погорельцам раздали лес и глину — отстраиваются сами, но без обид.",
				"summary_en": "The victims got timber and clay — they rebuild themselves, without grudge.",
			},
			{
				"label_ru": "Казна не для крыш", "label_en": "The treasury is not for roofs",
				"effects": {"loyalty": -14.0, "opposition": 6.0, "stability": -8.0},
				"summary_ru": "Люди зимуют в землянках — на базарах открыто бранят Порту.",
				"summary_en": "People winter in dugouts — the bazaars curse the Porte openly.",
			},
		],
	},
	{
		"id": "locust_swarm", "image": "event_cauldron", "weight": 1.8, "max_food": 55.0,
		"title_ru": "Саранча над полями", "title_en": "Locusts over the Fields",
		"body_ru": "Из степи пришла саранча — тучей легла на поля у самой столицы. Крестьяне бьют в котлы и жгут солому, но поля чернеют на глазах.",
		"body_en": "Locusts came from the steppe — a cloud settled on the fields near the capital. Peasants bang cauldrons and burn straw, yet the fields blacken before their eyes.",
		"choices": [
			{
				"label_ru": "Поднять людей на борьбу", "label_en": "Rouse the people",
				"cost": 900.0,
				"effects": {"food": 8.0, "stability": 2.0, "loyalty": -3.0},
				"summary_ru": "Канавами и огнём отбили часть полей — урожай спасён не весь, но спасён.",
				"summary_en": "With trenches and fire part of the fields was saved — not all the harvest, but enough.",
			},
			{
				"label_ru": "Положиться на волю небес", "label_en": "Trust in heaven",
				"effects": {"food": -10.0, "loyalty": -8.0, "stability": -8.0},
				"summary_ru": "Саранча ушла, оставив чёрные поля — зима будет тощей.",
				"summary_en": "The locusts left blackened fields behind — the winter will be lean.",
			},
		],
	},
	# ── КАЗАКИ: новые набеги и перехваты янычарами (случайные потери) ──
	{
		"id": "cossack_boats", "max_year": 1800, "image": "event_cauldron", "weight": 2.0, "min_external_pressure": 10.0,
		"title_ru": "Чайки на рассвете", "title_en": "Chaikas at Dawn",
		"body_ru": "На рассвете казачьи чайки подошли к прибрежной пристани: амбары с зерном разграблены, склады подожжены, лодки рыбаков угнаны.",
		"body_en": "At dawn Cossack chaikas slipped up to the coastal wharf: the grain stores plundered, warehouses set alight, the fishermen's boats driven off.",
		"choices": [
			{
				"label_ru": "Построить сторожевые вышки", "label_en": "Raise watchtowers",
				"cost": 1600.0,
				"effects": {"stability": 2.0, "food": 3.0, "loyalty": -3.0},
				"summary_ru": "Вдоль берега встали вышки с дозорными — врасплох больше не застанут.",
				"summary_en": "Watchtowers rose along the shore — no more surprises from the sea.",
			},
			{
				"label_ru": "Возместить рыбакам убытки", "label_en": "Compensate the fishermen",
				"cost": 900.0,
				"effects": {"stability": 2.0, "loyalty": -2.0},
				"summary_ru": "Рыбакам раздали серебро на новые лодки — жизнь у воды продолжилась.",
				"summary_en": "The fishermen got silver for new boats — life by the water went on.",
			},
			{
				"label_ru": "Берег переживёт", "label_en": "The coast will endure",
				"effects": {"stability": -7.0, "loyalty": -8.0, "food": -5.0, "opposition": 4.0},
				"summary_ru": "Пристань осталась в головешках — приморские сёла запомнили молчание Порты.",
				"summary_en": "The wharf lay in embers — the seaside villages remembered the Porte's silence.",
			},
		],
	},
	{
		"id": "cossack_caravan", "max_year": 1800, "image": "event_cauldron", "weight": 2.0, "min_external_pressure": 12.0,
		"title_ru": "Казаки у переправы", "title_en": "Cossacks at the Crossing",
		"body_ru": "У степной переправы казаки перехватили купеческий караван: товар растащен, купцы бежали, бросив возы. Торговые дома требуют охраны дорог.",
		"body_en": "At the steppe crossing Cossacks seized a merchant caravan: goods carried off, the merchants fled leaving their wagons. The trading houses demand guarded roads.",
		"choices": [
			{
				"label_ru": "Нанять конвойные разъезды", "label_en": "Hire convoy patrols",
				"cost": 1400.0,
				"effects": {"stability": 2.0, "hazna": 600.0, "loyalty": -2.0},
				"summary_ru": "Караваны пошли под конвоем — пошлины снова капают в казну.",
				"summary_en": "The caravans moved under escort — tolls trickle into the treasury again.",
			},
			{
				"label_ru": "Поднять пошлину на охрану", "label_en": "Raise a protection toll",
				"effects": {"hazna": 800.0, "loyalty": -5.0, "stability": -8.0},
				"summary_ru": "Купцы платят за охрану из своего кармана — и ворчат на каждом базаре.",
				"summary_en": "The merchants pay for protection from their own purse — and grumble in every bazaar.",
			},
		],
	},
	{
		"id": "janissary_intercept", "max_year": 1800, "image": "event_cauldron", "weight": 1.6, "min_external_pressure": 12.0,
		"title_ru": "Янычары перехватили набег", "title_en": "Janissaries Intercept a Raid",
		"body_ru": "Дозор донёс о казачьем отряде, идущем к сёлам. Янычары успели встать у брода первыми. Бой будет — вопрос лишь, какой ценой.",
		"body_en": "Scouts report a Cossack band moving on the villages. The janissaries reached the ford first. A fight is coming — the only question is the price.",
		"choices": [
			{
				"label_ru": "Дать бой у брода", "label_en": "Give battle at the ford",
				"req": {"army": 20.0},
				"effects": {"army_loss_random": 5.0, "stability": 5.0, "loyalty": 4.0, "external_pressure": -3.0},
				"summary_ru": "Набег отбит у брода — сёла целы, но янычары понесли потери.",
				"summary_en": "The raid was broken at the ford — the villages stand, but the janissaries paid in blood.",
			},
			{
				"label_ru": "Пугнуть залпами издали", "label_en": "Scare them off with volleys",
				"effects": {"stability": 2.0, "external_pressure": 2.0},
				"summary_ru": "Залпы издали спугнули отряд — без крови, но казаки вернутся.",
				"summary_en": "Distant volleys scattered the band — no blood, but the Cossacks will return.",
			},
		],
	},
	{
		"id": "janissary_night_fight", "max_year": 1800, "image": "event_cauldron", "weight": 1.8, "min_external_pressure": 16.0,
		"title_ru": "Ночная сеча у села", "title_en": "Night Fight by the Village",
		"body_ru": "Казаки подошли к селу в темноте, но янычарская застава не спала. В ночи закипела сеча — село можно спасти, если ударить сейчас.",
		"body_en": "The Cossacks crept to the village in the dark, but the janissary picket was awake. A night melee boils — the village can be saved if you strike now.",
		"choices": [
			{
				"label_ru": "Ударить немедля", "label_en": "Strike at once",
				"req": {"army": 24.0},
				"effects": {"army_loss_random": 4.0, "stability": 2.0, "loyalty": 5.0, "opposition": -2.0},
				"summary_ru": "Село отбили в ночи — люди целы, но не все янычары увидели рассвет.",
				"summary_en": "The village was saved in the dark — the people live, but not every janissary saw the dawn.",
			},
			{
				"label_ru": "Держать заставу до утра", "label_en": "Hold the picket till dawn",
				"effects": {"stability": -8.0, "loyalty": -6.0, "opposition": 3.0},
				"summary_ru": "Застава выстояла, но село пожгли — уцелевшие не простят промедления.",
				"summary_en": "The picket held, but the village burned — the survivors will not forgive the delay.",
			},
		],
	},
	# ── ОППОЗИЦИЯ ДЕЙСТВУЕТ: митинги, подкуп, провокации (оппозиция растёт при любом выборе) ──
	{
		"id": "opposition_rally", "image": "event_cauldron", "weight": 2.5, "max_opposition": 65.0,
		"title_ru": "Митинг на площади", "title_en": "A Rally on the Square",
		"body_ru": "Оппозиция собрала митинг у большого базара: ораторы кричат о слабости Порты, толпа растёт с каждым часом. Улицы гудят.",
		"body_en": "The opposition rallies by the grand bazaar: orators cry of the Porte's weakness, the crowd swells by the hour. The streets are buzzing.",
		"choices": [
			{
				"label_ru": "Разогнать янычарами", "label_en": "Disperse with janissaries",
				"req": {"army": 18.0},
				"effects": {"opposition": 6.0, "loyalty": -6.0, "stability": 2.0},
				"summary_ru": "Площадь очистили прикладами — но по домам разошлась злая молва.",
				"summary_en": "The square was cleared with musket butts — and angry talk spread from house to house.",
			},
			{
				"label_ru": "Выслушать и пообещать", "label_en": "Listen and promise",
				"cost": 1200.0,
				"effects": {"stability": -7.0, "opposition": 5.0, "loyalty": 2.0},
				"summary_ru": "Глашатай зачитал обещания — толпа разошлась, но вожаки почуяли слабину.",
				"summary_en": "A herald read out promises — the crowd dispersed, but the ringleaders smelled weakness.",
			},
			{
				"label_ru": "Пусть выговорятся", "label_en": "Let them talk",
				"effects": {"opposition": 14.0, "stability": -8.0},
				"summary_ru": "Митинг шумел до ночи — оппозиция записала себе победу и новых сторонников.",
				"summary_en": "The rally roared till nightfall — the opposition counted a victory and new followers.",
			},
		],
	},
	{
		"id": "opposition_bribes", "image": "event_cauldron", "weight": 1.8, "max_opposition": 65.0,
		"title_ru": "Серебро оппозиции", "title_en": "The Opposition's Silver",
		"body_ru": "Доносят: люди оппозиции ходят по сёлам с кошелями — подкупают старост, кормят бедноту и шепчут против Порты.",
		"body_en": "Reports come in: opposition men walk the villages with purses — bribing elders, feeding the poor, whispering against the Porte.",
		"choices": [
			{
				"label_ru": "Контрразведка и аресты", "label_en": "Counter-agents and arrests",
				"cost": 1500.0,
				"effects": {"opposition": 6.0, "stability": 2.0},
				"summary_ru": "Часть казначеев оппозиции взяли с кошелями — но сеть оказалась шире, чем думали.",
				"summary_en": "Some of the opposition's paymasters were caught purse in hand — but the network ran wider than thought.",
			},
			{
				"label_ru": "Перекупить старост", "label_en": "Outbid for the elders",
				"cost": 2500.0,
				"effects": {"opposition": 5.0, "loyalty": 3.0},
				"summary_ru": "Казна пересыпала серебра больше — старосты присягнули, но торг запомнили все.",
				"summary_en": "The treasury poured out more silver — the elders swore anew, but everyone remembered the bidding.",
			},
			{
				"label_ru": "Мелочь, не стоит внимания", "label_en": "Petty coins, ignore it",
				"effects": {"opposition": 15.0, "loyalty": -5.0},
				"summary_ru": "Через месяц полдюжины сёл смотрели на Порту чужими глазами.",
				"summary_en": "Within a month half a dozen villages looked at the Porte with a stranger's eyes.",
			},
		],
	},
	{
		"id": "opposition_provocation", "image": "event_cauldron", "weight": 2.3, "max_opposition": 65.0,
		"title_ru": "Провокации у мечетей", "title_en": "Provocations at the Mosques",
		"body_ru": "После пятничной молитвы у мечетей появляются подстрекатели: разбрасывают памфлеты, затевают драки и кричат, что во всём виноват дворец.",
		"body_en": "After Friday prayers agitators appear by the mosques: scattering pamphlets, starting brawls, shouting that the palace is to blame for everything.",
		"choices": [
			{
				"label_ru": "Арестовать зачинщиков", "label_en": "Arrest the ringleaders",
				"req": {"army": 15.0},
				"effects": {"opposition": 7.0, "loyalty": -4.0, "stability": 2.0},
				"summary_ru": "Зачинщиков увели в цепях — у мечетей тихо, но шёпот стал злее.",
				"summary_en": "The ringleaders were led away in chains — quiet by the mosques, but the whispers grew darker.",
			},
			{
				"label_ru": "Успокоить через улемов", "label_en": "Calm through the ulema",
				"cost": 1200.0,
				"effects": {"opposition": 6.0, "stability": 2.0},
				"summary_ru": "Имамы с минбаров призвали к спокойствию — драки стихли, памфлеты остались.",
				"summary_en": "From the minbars the imams called for calm — the brawls faded, the pamphlets remained.",
			},
			{
				"label_ru": "Пусть шумят", "label_en": "Let them shout",
				"effects": {"opposition": 16.0, "stability": -8.0},
				"summary_ru": "Драки у мечетей стали привычными — оппозиция вербует в открытую.",
				"summary_en": "Brawls by the mosques became routine — the opposition recruits in the open.",
			},
		],
	},
	# ── КРИЗИСНЫЕ СОБЫТИЯ: стабильность падает, оппозиция растёт при любом выборе ──
	{
		"id": "cossack_winter_raids", "max_year": 1800, "image": "event_cauldron", "weight": 2.1, "min_external_pressure": 10.0,
		"title_ru": "Зимние набеги казаков", "title_en": "Winter Cossack Raids",
		"body_ru": "По первому льду казаки жгут зимовья и хутора: беженцы тянутся к городам, требуя крова и хлеба. По базарам шепчут, что Порта не может защитить своих.",
		"body_en": "On the first ice the Cossacks burn winter camps and farmsteads: refugees stream to the towns demanding shelter and bread. The bazaars whisper the Porte cannot protect its own.",
		"choices": [
			{
				"label_ru": "Зимний поход возмездия", "label_en": "A winter punitive march",
				"req": {"army": 22.0},
				"effects": {"army_loss_random": 4.0, "stability": -8.0, "opposition": 3.0, "external_pressure": -4.0},
				"summary_ru": "Поход по морозу дорого обошёлся — но станицы притихли до весны.",
				"summary_en": "The frost march cost dearly — but the camps fell silent till spring.",
			},
			{
				"label_ru": "Разместить беженцев", "label_en": "House the refugees",
				"cost": 1600.0,
				"effects": {"stability": -8.0, "opposition": 4.0, "loyalty": 3.0},
				"summary_ru": "Беженцев расселили по караван-сараям — города переполнены и ворчат.",
				"summary_en": "The refugees were housed in caravanserais — the towns are crowded and grumbling.",
			},
			{
				"label_ru": "Граница далеко от дворца", "label_en": "The border is far from the palace",
				"effects": {"stability": -8.0, "opposition": 9.0, "loyalty": -6.0},
				"summary_ru": "Беженцы замерзали у стен — оппозиция раздала им хлеб от своего имени.",
				"summary_en": "Refugees froze by the walls — the opposition handed them bread in its own name.",
			},
		],
	},
	{
		"id": "peasant_unrest", "image": "event_cauldron", "weight": 2.2, "max_loyalty": 60.0,
		"title_ru": "Крестьянские волнения", "title_en": "Peasant Unrest",
		"body_ru": "Три уезда отказались платить подати: сборщиков гонят вилами, старосты прячутся. Волнение расползается от села к селу.",
		"body_en": "Three districts refuse to pay their dues: collectors are chased off with pitchforks, the elders hide. The unrest creeps from village to village.",
		"choices": [
			{
				"label_ru": "Простить недоимки на год", "label_en": "Forgive a year of arrears",
				"cost": 1800.0,
				"effects": {"stability": -8.0, "opposition": 3.0, "loyalty": 5.0},
				"summary_ru": "Сёла выдохнули — но по державе пошёл слух, что вилы работают лучше прошений.",
				"summary_en": "The villages breathed out — but word spread that pitchforks work better than petitions.",
			},
			{
				"label_ru": "Карательный отряд", "label_en": "A punitive detachment",
				"req": {"army": 18.0},
				"effects": {"stability": -6.0, "opposition": 8.0, "loyalty": -7.0},
				"summary_ru": "Подати собрали штыками — деревня замолчала, но не простила.",
				"summary_en": "The dues were collected at bayonet point — the village fell silent, but did not forgive.",
			},
			{
				"label_ru": "Переждать — перегорит", "label_en": "Wait it out",
				"effects": {"stability": -8.0, "opposition": 11.0, "hazna": -900.0},
				"summary_ru": "К мятежным уездам присоединился четвёртый — подати так и не пришли.",
				"summary_en": "A fourth district joined the mutinous three — the dues never came.",
			},
		],
	},
	{
		"id": "palace_betrayal", "image": "event_cauldron", "weight": 1.5,
		"title_ru": "Предательство во дворце", "title_en": "Betrayal in the Palace",
		"body_ru": "Доверенный катиб дивана месяцами переписывал тайные бумаги для оппозиции. Его взяли с поличным у задней калитки — но сколько ушло раньше?",
		"body_en": "A trusted scribe of the divan spent months copying secret papers for the opposition. He was caught red-handed at the back gate — but how much slipped out before?",
		"choices": [
			{
				"label_ru": "Перевербовать и кормить ложью", "label_en": "Turn him, feed them lies",
				"cost": 2000.0,
				"effects": {"stability": -2.0, "opposition": 4.0},
				"summary_ru": "Катиб теперь носит оппозиции то, что велено, — но во дворце никто никому не верит.",
				"summary_en": "The scribe now carries what he is told to carry — but no one in the palace trusts anyone.",
			},
			{
				"label_ru": "Публичная казнь", "label_en": "A public execution",
				"effects": {"stability": -3.0, "opposition": 6.0, "loyalty": -3.0},
				"summary_ru": "Голова катиба у ворот дивана — оппозиция получила мученика.",
				"summary_en": "The scribe's head hangs by the divan gate — the opposition got a martyr.",
			},
			{
				"label_ru": "Тихо сослать — без шума", "label_en": "Exile him quietly",
				"effects": {"stability": -5.0, "opposition": 8.0},
				"summary_ru": "Ссылку заметили все — двор решил, что предательство сходит с рук.",
				"summary_en": "Everyone noticed the exile — the court concluded betrayal goes unpunished.",
			},
		],
	},
	{
		"id": "guard_plot", "image": "event_cauldron", "weight": 1.4, "min_opposition": 20.0,
		"title_ru": "Заговор стражи", "title_en": "The Guards' Plot",
		"body_ru": "Ночью схвачен бостанджи с кинжалом у опочивальни. На допросе он назвал троих товарищей: покушение готовила сама дворцовая охрана.",
		"body_en": "At night a bostanci was seized with a dagger by the bedchamber. Under questioning he named three comrades: the palace guard itself was plotting the assassination.",
		"choices": [
			{
				"label_ru": "Чистка охраны", "label_en": "Purge the guard",
				"req": {"army": 16.0},
				"effects": {"army_loss_random": 3.0, "stability": -3.0, "opposition": 5.0},
				"summary_ru": "Половину смены заменили верными — дворец цел, но спит вполглаза.",
				"summary_en": "Half the watch was replaced with loyal men — the palace stands, but sleeps with one eye open.",
			},
			{
				"label_ru": "Двойное жалованье страже", "label_en": "Double the guards' pay",
				"cost": 2500.0,
				"effects": {"stability": -2.0, "opposition": 4.0},
				"summary_ru": "Серебро купило тишину — но теперь стража знает себе цену.",
				"summary_en": "Silver bought silence — but now the guard knows its price.",
			},
			{
				"label_ru": "Помиловать ради спокойствия", "label_en": "Pardon them for calm's sake",
				"effects": {"stability": -8.0, "opposition": 12.0, "loyalty": -4.0},
				"summary_ru": "Помилованные вернулись в караул — по столице шепчут, что султан боится собственной стражи.",
				"summary_en": "The pardoned returned to their posts — the capital whispers the Sultan fears his own guard.",
			},
		],
	},
	{
		"id": "opposition_press", "image": "event_cauldron", "weight": 1.7, "max_opposition": 70.0,
		"title_ru": "Тайная типография", "title_en": "The Secret Press",
		"body_ru": "В подвале у пристани нашли типографию оппозиции: памфлеты о «слабом султане» расходятся по кофейням быстрее, чем их успевают жечь.",
		"body_en": "In a cellar by the wharf an opposition press was found: pamphlets about the \"weak Sultan\" spread through the coffeehouses faster than they can be burned.",
		"choices": [
			{
				"label_ru": "Накрыть сеть распространителей", "label_en": "Roll up the distribution net",
				"cost": 1300.0,
				"effects": {"stability": -2.0, "opposition": 5.0},
				"summary_ru": "Печатню разбили, разносчиков взяли — но списки читателей исчезли.",
				"summary_en": "The press was smashed, the couriers taken — but the readers' lists vanished.",
			},
			{
				"label_ru": "Печатать ответные памфлеты", "label_en": "Print counter-pamphlets",
				"cost": 900.0,
				"effects": {"stability": -3.0, "opposition": 6.0, "loyalty": 2.0},
				"summary_ru": "Кофейни читают обе стороны — и спорят до драк.",
				"summary_en": "The coffeehouses read both sides — and argue to the point of brawls.",
			},
			{
				"label_ru": "Бумага всё стерпит", "label_en": "Paper endures everything",
				"effects": {"stability": -6.0, "opposition": 13.0},
				"summary_ru": "Памфлеты дошли до провинций — там их читают вслух на площадях.",
				"summary_en": "The pamphlets reached the provinces — read aloud in the squares.",
			},
		],
	},
	{
		"id": "bandit_roads", "image": "event_cauldron", "weight": 1.7,
		"title_ru": "Разбойники на трактах", "title_en": "Bandits on the Highways",
		"body_ru": "Банды без знамён и веры грабят всех подряд: паломников, купцов, гонцов. Дороги пустеют, цены в городах ползут вверх.",
		"body_en": "Bands with no banner and no creed rob everyone alike: pilgrims, merchants, couriers. The roads empty, town prices creep upward.",
		"choices": [
			{
				"label_ru": "Виселицы у перекрёстков", "label_en": "Gallows at the crossroads",
				"req": {"army": 20.0},
				"effects": {"army_loss_random": 3.0, "stability": -2.0, "opposition": 4.0, "loyalty": -3.0},
				"summary_ru": "Тракты очистили облавами — но виселицы у дорог пугают и честный люд.",
				"summary_en": "Sweeps cleared the highways — but the roadside gallows frighten honest folk too.",
			},
			{
				"label_ru": "Платные конвои купцам", "label_en": "Paid merchant convoys",
				"cost": 1400.0,
				"effects": {"stability": -3.0, "opposition": 4.0, "hazna": 500.0},
				"summary_ru": "Караваны идут под охраной за плату — банды перекинулись на паломников.",
				"summary_en": "Caravans move under paid escort — the bands switched to pilgrims.",
			},
			{
				"label_ru": "Дороги — не забота дивана", "label_en": "Roads are not the divan's concern",
				"effects": {"stability": -7.0, "opposition": 10.0, "food": -4.0},
				"summary_ru": "Купцы наняли оппозицию охранять караваны — и платят ей, а не казне.",
				"summary_en": "The merchants hired the opposition to guard their caravans — and pay it, not the treasury.",
			},
		],
	},
	{
		"id": "treasury_theft", "image": "event_cauldron", "weight": 1.6,
		"title_ru": "Воровство в казне", "title_en": "Theft in the Treasury",
		"body_ru": "Ревизия сундуков не сошлась на тысячи акче: помощник дефтердара годами выносил серебро в переплётах счётных книг.",
		"body_en": "The chest audit came up thousands of akce short: the defterdar's aide had carried silver out for years in the bindings of the ledgers.",
		"choices": [
			{
				"label_ru": "Показательный суд дивана", "label_en": "A show trial before the divan",
				"effects": {"stability": -2.0, "opposition": 4.0, "hazna": 1200.0},
				"summary_ru": "Ворованное вернули, вора — на галеры. Но диван теперь трясёт каждую книгу.",
				"summary_en": "The stolen silver returned, the thief sent to the galleys. Now the divan shakes every ledger.",
			},
			{
				"label_ru": "Вернуть тихо, без суда", "label_en": "Recover quietly, no trial",
				"effects": {"stability": -4.0, "opposition": 6.0, "hazna": 2000.0},
				"summary_ru": "Серебро вернулось в сундуки, вор — в кресло. Писари сделали выводы.",
				"summary_en": "The silver returned to the chests, the thief to his chair. The clerks drew their conclusions.",
			},
			{
				"label_ru": "Не выносить сор из дивана", "label_en": "Keep it inside the divan",
				"effects": {"stability": -6.0, "opposition": 9.0, "hazna": -1500.0},
				"summary_ru": "Кражу замяли — и через месяц недосчитались уже в трёх канцеляриях.",
				"summary_en": "The theft was hushed — a month later three more offices came up short.",
			},
		],
	},
	{
		"id": "grain_embezzlers", "image": "event_cauldron", "weight": 1.6, "max_food": 75.0,
		"title_ru": "Расхитители амбаров", "title_en": "The Granary Embezzlers",
		"body_ru": "Смотрители казённых амбаров продают зерно на сторону, записывая его «сгнившим». Хлебные лавки пустеют, а у смотрителей — новые дома.",
		"body_en": "The keepers of the state granaries sell grain on the side, writing it off as \"rotted\". The bread stalls empty while the keepers build new houses.",
		"choices": [
			{
				"label_ru": "Внезапная ревизия", "label_en": "A surprise audit",
				"cost": 800.0,
				"effects": {"stability": -2.0, "opposition": 4.0, "food": 5.0},
				"summary_ru": "Зерно вернули в амбары, смотрителей — под замок. Их родня затаила злобу.",
				"summary_en": "The grain returned to the granaries, the keepers to the lockup. Their kin nursed a grudge.",
			},
			{
				"label_ru": "Повесить у амбарных ворот", "label_en": "Hang them at the granary gates",
				"effects": {"stability": -4.0, "opposition": 7.0, "food": 3.0, "loyalty": -3.0},
				"summary_ru": "Смотрители качаются у ворот — новые воруют осторожнее, народ отводит глаза.",
				"summary_en": "The keepers swing by the gates — the new ones steal more carefully, the people look away.",
			},
			{
				"label_ru": "Все воруют — держава стоит", "label_en": "Everyone steals — the state stands",
				"effects": {"stability": -6.0, "opposition": 10.0, "food": -8.0},
				"summary_ru": "К зиме амбары показали дно — хлебные очереди слушают ораторов оппозиции.",
				"summary_en": "By winter the granaries showed their bottoms — the bread lines listen to opposition orators.",
			},
		],
	},
]

# ════════════════════════════════════════════════════════════════
#  ДИПЛОМАТИЧЕСКИЕ СОБЫТИЯ — открываются уровнем отношений (rel_country
#  + rel_below/rel_above). Плохие отношения: пошлины, стычки, унижения.
#  Отличные отношения: кредиты, праздники, караваны.
# ════════════════════════════════════════════════════════════════
const DIPLO_EVENTS := [
	{
		"id": "austria_transit_tax", "image": "event_cauldron", "weight": 2.0,
		"rel_country": "austria", "rel_below": 60.0, "rel_above": 25.0,
		"title_ru": "Вена поднимает мыто", "title_en": "Vienna Raises Tolls",
		"body_ru": "«Отношения с Австрией остыли — цесарцы подняли пошлины на проезд чумацких обозов через свои земли. Хлеб в столице дорожает.»",
		"body_en": "\"Relations with Austria have cooled — the Kaiser raised tolls on chumak caravans crossing his lands. Bread in the capital grows dearer.\"",
		"choices": [
			{
				"label_ru": "Оплатить мыто из казны", "label_en": "Pay the tolls",
				"cost": 2500.0,
				"effects": {"food": 5.0},
				"summary_ru": "Казна оплатила мыто — обозы прошли, амбары пополнились.",
				"summary_en": "The treasury paid the tolls — the caravans passed, granaries were restocked.",
			},
			{
				"label_ru": "Искать обходные шляхи", "label_en": "Seek detour routes",
				"effects": {"food": -7.0, "stability": -3.0},
				"summary_ru": "Обозы пошли в обход — часть груза потеряна, народ ропщет на дорогой хлеб.",
				"summary_en": "The caravans took detours — cargo was lost, and the people grumble over costly bread.",
			},
		],
	},
	{
		"id": "austria_border_clash", "image": "event_battle", "weight": 2.4,
		"rel_country": "austria", "rel_below": 25.0,
		"title_ru": "Стычки на австрийской границе", "title_en": "Clashes on the Austrian Border",
		"body_ru": "«Вена закрыла проезд чумакам вовсе. На порубежье — стычки разъездов, горят хутора. Империя не может делать вид, что ничего не происходит.»",
		"body_en": "\"Vienna has closed the roads to chumaks entirely. Border patrols clash, farmsteads burn. The Empire cannot pretend nothing is happening.\"",
		"choices": [
			{
				"label_ru": "Выслать сипахов", "label_en": "Send the sipahis",
				"cost": 3000.0,
				"effects": {"army_loss_random": 5.0, "stability": 2.0, "external_pressure": 3.0},
				"summary_ru": "Сипахи отогнали цесарские разъезды — граница притихла, но Вена запомнит.",
				"summary_en": "The sipahis drove off the Kaiser's patrols — the border quieted, but Vienna will remember.",
			},
			{
				"label_ru": "Откупиться и замириться", "label_en": "Pay off and reconcile",
				"cost": 6000.0,
				"effects": {"rel_austria": 12.0, "stability": 1.0},
				"summary_ru": "Золото сгладило обиды — Вена приоткрыла шляхи.",
				"summary_en": "Gold smoothed the grudges — Vienna reopened the roads a crack.",
			},
			{
				"label_ru": "Стерпеть", "label_en": "Endure it",
				"effects": {"stability": -9.0, "loyalty": -4.0},
				"summary_ru": "Порубежье оставили гореть — народ шепчет, что султан слаб.",
				"summary_en": "The borderlands were left to burn — the people whisper the Sultan is weak.",
			},
		],
	},
	{
		"id": "moscow_transit_tax", "image": "event_cauldron", "weight": 2.0,
		"rel_country": "moscow", "rel_below": 60.0, "rel_above": 25.0,
		"title_ru": "Москва поднимает проезжую пошлину", "title_en": "Moscow Raises Transit Duty",
		"body_ru": "«Царские воеводы подняли пошлину с чумацких возов на северных шляхах. Соль и хлеб идут в столицу дороже прежнего.»",
		"body_en": "\"The Tsar's voivodes raised the duty on chumak wagons along the northern roads. Salt and grain reach the capital dearer than before.\"",
		"choices": [
			{
				"label_ru": "Заплатить пошлину", "label_en": "Pay the duty",
				"cost": 2500.0,
				"effects": {"food": 5.0},
				"summary_ru": "Пошлину уплатили — обозы дошли без потерь.",
				"summary_en": "The duty was paid — the caravans arrived without losses.",
			},
			{
				"label_ru": "Везти степью, в обход застав", "label_en": "Haul through the steppe",
				"effects": {"food": -7.0, "stability": -3.0},
				"summary_ru": "Степные шляхи взяли своё — часть обозов пропала без вести.",
				"summary_en": "The steppe roads took their toll — some caravans vanished without a trace.",
			},
		],
	},
	{
		"id": "moscow_border_clash", "image": "event_battle", "weight": 2.4,
		"rel_country": "moscow", "rel_below": 25.0,
		"title_ru": "Казачьи разъезды на порубежье", "title_en": "Cossack Raids on the Frontier",
		"body_ru": "«С Москвой разлад — на порубежье зачастили казачьи разъезды: жгут заставы, угоняют скот. Днепровская граница дымится.»",
		"body_en": "\"Relations with Moscow have soured — Cossack raiders burn outposts and drive off cattle. The Dnieper frontier is smouldering.\"",
		"choices": [
			{
				"label_ru": "Укрепить заставы", "label_en": "Fortify the outposts",
				"cost": 3000.0,
				"effects": {"army_loss_random": 4.0, "stability": 2.0},
				"summary_ru": "Заставы укрепили — набеги отбиты, хоть и не без потерь.",
				"summary_en": "The outposts were fortified — the raids were repelled, though not without losses.",
			},
			{
				"label_ru": "Отправить посольство с дарами", "label_en": "Send an embassy with gifts",
				"cost": 6000.0,
				"effects": {"rel_moscow": 12.0, "stability": 1.0},
				"summary_ru": "Дары смягчили царя — разъезды отозвали с порубежья.",
				"summary_en": "The gifts softened the Tsar — the raiders were recalled from the frontier.",
			},
			{
				"label_ru": "Не отвечать", "label_en": "Do not respond",
				"effects": {"stability": -9.0, "loyalty": -4.0},
				"summary_ru": "Набеги остались без ответа — приграничные санджаки теряют веру в Порту.",
				"summary_en": "The raids went unanswered — the border sanjaks lose faith in the Porte.",
			},
		],
	},
	{
		"id": "diplo_citizens_humiliated", "image": "event_cauldron", "weight": 2.2,
		"rel_country": "poland", "rel_below": 20.0,
		"title_ru": "Османских купцов унижают в Речи Посполитой", "title_en": "Ottoman Merchants Humiliated in the Commonwealth",
		"body_ru": "«Шляхта глумится над османскими купцами: товары отбирают, самих сажают в колодки на потеху толпе. Весть дошла до базаров столицы — народ кипит.»",
		"body_en": "\"The szlachta mock Ottoman merchants: goods seized, men put in stocks for the crowd's amusement. Word reached the capital's bazaars — the people seethe.\"",
		"choices": [
			{
				"label_ru": "Потребовать извинений и виры", "label_en": "Demand apology and payment",
				"cost": 2000.0,
				"effects": {"rel_poland": 8.0, "stability": -2.0},
				"summary_ru": "Посольство добилось извинений — обида сглажена, но осадок остался.",
				"summary_en": "The embassy secured an apology — the insult was smoothed over, but a bitterness remains.",
			},
			{
				"label_ru": "Ответные пошлины на их товары", "label_en": "Retaliatory tariffs",
				"effects": {"hazna": 2000.0, "external_pressure": 4.0, "stability": -3.0},
				"summary_ru": "Порта ударила пошлинами — казна пополнилась, но напряжение растёт.",
				"summary_en": "The Porte struck back with tariffs — the treasury gained, but tensions rise.",
			},
			{
				"label_ru": "Проглотить обиду", "label_en": "Swallow the insult",
				"effects": {"stability": -10.0, "loyalty": -6.0},
				"summary_ru": "Порта смолчала — на базарах говорят, что честь империи стоит дешевле соли.",
				"summary_en": "The Porte stayed silent — in the bazaars they say the Empire's honor is cheaper than salt.",
			},
		],
	},
	{
		"id": "diplo_festival_invite", "image": "event_feast", "weight": 1.6,
		"rel_country": "austria", "rel_above": 80.0,
		"title_ru": "Приглашение на императорский праздник", "title_en": "Invitation to the Imperial Festival",
		"body_ru": "«Вена шлёт золочёное приглашение: император даёт большой праздник и ждёт османское посольство как почётного гостя. Дружба цветёт.»",
		"body_en": "\"Vienna sends a gilded invitation: the Emperor holds a great festival and awaits the Ottoman embassy as guest of honor. Friendship blooms.\"",
		"choices": [
			{
				"label_ru": "Отправить пышное посольство", "label_en": "Send a lavish embassy",
				"cost": 3500.0,
				"effects": {"rel_austria": 8.0, "stability": 4.0, "loyalty": 3.0},
				"summary_ru": "Посольство блистало — о щедрости Порты говорят при всех дворах Европы.",
				"summary_en": "The embassy dazzled — all the courts of Europe speak of the Porte's splendor.",
			},
			{
				"label_ru": "Вежливо отказаться", "label_en": "Politely decline",
				"effects": {"rel_austria": -8.0},
				"summary_ru": "Порта сослалась на дела — в Вене пожали плечами, но запомнили.",
				"summary_en": "The Porte pleaded busyness — Vienna shrugged, but took note.",
			},
		],
	},
	{
		"id": "diplo_credit_offer", "image": "event_feast", "weight": 1.6,
		"rel_country": "moscow", "rel_above": 80.0,
		"title_ru": "Московский торговый кредит", "title_en": "Muscovite Trade Credit",
		"body_ru": "«Дружба с Москвой приносит плоды: царские купцы предлагают Порте выгодный торговый кредит под честное слово султана.»",
		"body_en": "\"Friendship with Moscow bears fruit: the Tsar's merchants offer the Porte a favorable trade credit on the Sultan's word of honor.\"",
		"choices": [
			{
				"label_ru": "Принять кредит", "label_en": "Accept the credit",
				"effects": {"hazna": 8000.0, "external_pressure": 2.0},
				"summary_ru": "Казна пополнилась московским серебром — но слово султана теперь в залоге.",
				"summary_en": "The treasury swelled with Muscovite silver — but the Sultan's word is now pledged.",
			},
			{
				"label_ru": "Отказаться с достоинством", "label_en": "Decline with dignity",
				"effects": {"stability": 2.0},
				"summary_ru": "Порта не берёт в долг — двор оценил гордость султана.",
				"summary_en": "The Porte borrows from no one — the court admired the Sultan's pride.",
			},
		],
	},
	{
		"id": "persia_caravans", "image": "event_feast", "weight": 1.6,
		"rel_country": "persia", "rel_above": 75.0,
		"title_ru": "Шёлковые караваны из Исфахана", "title_en": "Silk Caravans from Isfahan",
		"body_ru": "«Мир с Персией открыл восточные шляхи: шёлковые караваны из Исфахана просят охраны — и щедро платят за неё Порте.»",
		"body_en": "\"Peace with Persia opened the eastern roads: silk caravans from Isfahan ask for escort — and pay the Porte handsomely for it.\"",
		"choices": [
			{
				"label_ru": "Дать охрану", "label_en": "Provide escort",
				"cost": 1500.0,
				"effects": {"hazna": 6000.0, "rel_persia": 4.0},
				"summary_ru": "Караваны прошли под османской охраной — пошлины озолотили казну.",
				"summary_en": "The caravans passed under Ottoman escort — the tolls gilded the treasury.",
			},
			{
				"label_ru": "Пусть идут сами", "label_en": "Let them fend for themselves",
				"effects": {"rel_persia": -5.0},
				"summary_ru": "Караваны пошли без охраны — в Исфахане сочли это неучтивостью.",
				"summary_en": "The caravans went unescorted — Isfahan took it as a discourtesy.",
			},
		],
	},
]

# ════════════════════════════════════════════════════════════════
#  ВОЕННЫЕ СОБЫТИЯ — учения поднимают репутацию армии за золото,
#  беды (питание, болезни) роняют её.
# ════════════════════════════════════════════════════════════════
const ARMY_EVENTS := [
	{
		"id": "janissary_drills", "image": "event_battle", "weight": 1.8,
		"title_ru": "Большие учения янычар", "title_en": "Grand Janissary Drills",
		"body_ru": "«Ага янычар просит казну на большие учения корпуса: стрельбы, штурмы, смотр перед народом. Дорого — но оджак истосковался по делу.»",
		"body_en": "\"The Agha of the Janissaries asks the treasury for grand corps drills: musketry, assaults, a public review. Costly — but the ojak yearns for action.\"",
		"choices": [
			{
				"label_ru": "Выделить золото на учения", "label_en": "Fund the drills",
				"cost": 3500.0,
				"effects": {"army": 7.0, "stability": 1.0},
				"summary_ru": "Учения прогремели на весь Стамбул — оджак горд и предан.",
				"summary_en": "The drills thundered across Istanbul — the ojak is proud and loyal.",
			},
			{
				"label_ru": "Казна пуста, не время", "label_en": "The treasury is empty",
				"effects": {"army": -3.0},
				"summary_ru": "Оджак ворчит: султан жалеет пороха для своих солдат.",
				"summary_en": "The ojak grumbles: the Sultan begrudges powder for his own soldiers.",
			},
		],
	},
	{
		"id": "navy_exercises", "image": "event_battle", "weight": 1.7,
		"title_ru": "Манёвры флота у Золотого Рога", "title_en": "Fleet Manoeuvres off the Golden Horn",
		"body_ru": "«Капудан-паша предлагает вывести галеры на большие манёвры: экипажи застоялись в гавани, порох сыреет. Флот хочет показать себя султану.»",
		"body_en": "\"The Kapudan Pasha proposes grand galley manoeuvres: the crews idle in harbour, the powder grows damp. The fleet wishes to show itself to the Sultan.\"",
		"choices": [
			{
				"label_ru": "Оплатить манёвры", "label_en": "Fund the manoeuvres",
				"cost": 4000.0,
				"effects": {"army": 7.0},
				"summary_ru": "Галеры прошли строем под пушечный салют — морская слава Порты жива.",
				"summary_en": "The galleys sailed in formation under cannon salute — the Porte's naval glory lives.",
			},
			{
				"label_ru": "Пусть стоят в гавани", "label_en": "Let them idle in harbour",
				"effects": {"army": -3.0},
				"summary_ru": "Экипажи разбредаются по кабакам — флот ржавеет у причалов.",
				"summary_en": "The crews drift to the taverns — the fleet rusts at its moorings.",
			},
		],
	},
	{
		"id": "army_bad_food", "image": "event_cauldron", "weight": 2.2,
		"title_ru": "Гнилой провиант в казармах", "title_en": "Rotten Rations in the Barracks",
		"body_ru": "«Янычары опрокинули котлы: сухари с червями, солонина протухла. Перевёрнутый котёл у оджака — древний знак бунта. Нужно действовать быстро.»",
		"body_en": "\"The Janissaries have overturned their kettles: weevils in the biscuit, the salt meat spoiled. An overturned kettle is the ojak's ancient sign of revolt. Act quickly.\"",
		"choices": [
			{
				"label_ru": "Закупить свежий провиант", "label_en": "Buy fresh provisions",
				"cost": 2800.0,
				"effects": {"army": 3.0, "loyalty": 1.0},
				"summary_ru": "Котлы снова кипят — оджак сыт, обида забыта.",
				"summary_en": "The kettles boil again — the ojak is fed, the grievance forgotten.",
			},
			{
				"label_ru": "Пусть едят что дают", "label_en": "Let them eat what they're given",
				"effects": {"stability": -7.0, "army": -8.0, "loyalty": -2.0},
				"summary_ru": "Оджак затаил злобу — у костров шепчут о султане, что морит солдат.",
				"summary_en": "The ojak nurses its anger — by the fires they whisper of a Sultan who starves his soldiers.",
			},
		],
	},
	{
		"id": "janissary_disease", "image": "event_cauldron", "weight": 2.1,
		"title_ru": "Кровавый понос в казармах", "title_en": "The Bloody Flux in the Barracks",
		"body_ru": "«В янычарских казармах вспыхнула дизентерия — «кровавый понос», бич военных лагерей. Больные валятся десятками, здоровые ропщут и боятся котлов.»",
		"body_en": "\"Dysentery — the bloody flux, scourge of army camps — has broken out in the Janissary barracks. The sick fall by the dozen; the healthy grumble and fear the kettles.\"",
		"choices": [
			{
				"label_ru": "Созвать лекарей и хакимов", "label_en": "Summon the physicians",
				"cost": 3600.0,
				"effects": {"army": -2.0, "stability": 2.0},
				"summary_ru": "Лекари отделили больных, наладили чистую воду — мор отступил малой кровью.",
				"summary_en": "The physicians isolated the sick and secured clean water — the plague receded with few losses.",
			},
			{
				"label_ru": "Запереть казармы на карантин", "label_en": "Seal the barracks",
				"effects": {"army": -6.0, "stability": -8.0},
				"summary_ru": "Мор выгорел за запертыми дверями — оджак не простит этих недель.",
				"summary_en": "The flux burned out behind locked doors — the ojak will not forgive those weeks.",
			},
			{
				"label_ru": "На всё воля Аллаха", "label_en": "It is God's will",
				"effects": {"stability": -7.0, "army": -12.0, "loyalty": -3.0},
				"summary_ru": "Мор гулял по казармам месяц — корпус поредел, доверие армии подорвано.",
				"summary_en": "The flux ranged the barracks for a month — the corps is thinned, the army's trust broken.",
			},
		],
	},
	{
		"id": "camp_typhus", "image": "event_cauldron", "weight": 2.0,
		"title_ru": "Лагерная лихорадка у сипахов", "title_en": "Camp Fever Among the Sipahis",
		"body_ru": "«В походном лагере сипахов вспыхнул сыпной тиф — «лагерная лихорадка», что косит войска хуже вражеских сабель. Вши разносят хворь от костра к костру.»",
		"body_en": "\"Typhus — the camp fever that reaps armies worse than enemy sabres — has broken out among the sipahis. Lice carry the sickness from fire to fire.\"",
		"choices": [
			{
				"label_ru": "Новые шатры, бани и чистое бельё", "label_en": "New tents, baths and clean linen",
				"cost": 4200.0,
				"effects": {"army": -1.0, "stability": 2.0},
				"summary_ru": "Лагерь отмыли и переодели — лихорадка угасла, не разгоревшись.",
				"summary_en": "The camp was scrubbed and re-clothed — the fever died before it could spread.",
			},
			{
				"label_ru": "Распустить лагерь по домам", "label_en": "Disband the camp",
				"effects": {"stability": -7.0, "army": -7.0, "external_pressure": 2.0},
				"summary_ru": "Сипахи разъехались — хворь затихла, но границы месяц стояли оголёнными.",
				"summary_en": "The sipahis dispersed — the fever faded, but the borders stood bare for a month.",
			},
			{
				"label_ru": "Поход не остановить", "label_en": "The march must go on",
				"effects": {"stability": -7.0, "army_loss_random": 7.0, "army": -6.0},
				"summary_ru": "Войско шло, оставляя могилы вдоль дороги — тиф собрал свою дань сполна.",
				"summary_en": "The army marched on, leaving graves along the road — the typhus took its full toll.",
			},
		],
	},
	{
		"id": "galley_scurvy", "image": "event_cauldron", "weight": 2.0,
		"title_ru": "Цинга на галерах", "title_en": "Scurvy on the Galleys",
		"body_ru": "«Капудан-паша доносит: у гребцов и матросов кровоточат дёсны, выпадают зубы — цинга. Дальний дозор в море оставил флот без свежей пищи.»",
		"body_en": "\"The Kapudan Pasha reports: the rowers' gums bleed, their teeth fall out — scurvy. A long patrol at sea left the fleet without fresh food.\"",
		"choices": [
			{
				"label_ru": "Лимоны, лук и свежая зелень", "label_en": "Lemons, onions and fresh greens",
				"cost": 2600.0,
				"effects": {"army": 2.0},
				"summary_ru": "Трюмы забили цитрусами анатолийских садов — экипажи ожили за неделю.",
				"summary_en": "The holds were packed with Anatolian citrus — the crews revived within a week.",
			},
			{
				"label_ru": "Вернуть флот в гавань", "label_en": "Recall the fleet to harbour",
				"effects": {"stability": -7.0, "army": -5.0, "external_pressure": 2.0},
				"summary_ru": "Галеры вернулись лечиться — море осталось без османского дозора.",
				"summary_en": "The galleys returned to heal — the sea was left without Ottoman watch.",
			},
			{
				"label_ru": "Дозор важнее зубов", "label_en": "The patrol matters more than teeth",
				"effects": {"stability": -7.0, "army": -9.0, "loyalty": -2.0},
				"summary_ru": "Флот выстоял дозор на гнилых сухарях — команды поредели и озлобились.",
				"summary_en": "The fleet held its patrol on rotten biscuit — the crews thinned and grew bitter.",
			},
		],
	},
	{
		"id": "smallpox_capital", "image": "event_cauldron", "weight": 1.5,
		"title_ru": "Оспа в столице", "title_en": "Smallpox in the Capital",
		"body_ru": "«По махаллям столицы ползёт оспа: базары пустеют, богатые бегут в загородные яли. Хакимы вспоминают старое искусство прививания — вариоляцию.»",
		"body_en": "\"Smallpox creeps through the capital's quarters: bazaars empty, the rich flee to country villas. The hakims recall the old art of inoculation — variolation.\"",
		"choices": [
			{
				"label_ru": "Оплатить прививание народа", "label_en": "Fund variolation for the people",
				"cost": 4500.0,
				"effects": {"stability": 3.0, "loyalty": 4.0},
				"summary_ru": "Хакимы прививали днём и ночью — мор отступил, народ славит султана-заступника.",
				"summary_en": "The hakims inoculated day and night — the pox receded; the people praise their protector-Sultan.",
			},
			{
				"label_ru": "Закрыть базары и бани", "label_en": "Close the bazaars and baths",
				"effects": {"stability": -4.0, "hazna": -1500.0},
				"summary_ru": "Столица замерла на месяц — мор угас, но торговля понесла убытки.",
				"summary_en": "The capital froze for a month — the pox faded, but trade took its losses.",
			},
			{
				"label_ru": "Мор приходит и уходит", "label_en": "Plagues come and go",
				"effects": {"stability": -7.0, "loyalty": -5.0},
				"summary_ru": "Оспа выкосила махалли — на площадях шепчут, что султану нет дела до народа.",
				"summary_en": "The pox reaped the quarters — in the squares they whisper the Sultan cares nothing for his people.",
			},
		],
	},
]
