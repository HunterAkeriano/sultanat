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
	var s := GameState.stability
	if s >= 75: return "The Zenith" if Loc.lang == "en" else "Расцвет"
	if s >= 55: return "Stability" if Loc.lang == "en" else "Равновесие"
	if s >= 35: return "The Strain" if Loc.lang == "en" else "Напряжение"
	return "The Decline" if Loc.lang == "en" else "Закат"

# Линия султанов для смены правления (§18.2 + макет «Suleiman II»)
const SULTANS := [
	"Sultan Suleiman II", "Sultan Ahmed II", "Sultan Mustafa II",
	"Sultan Ahmed III", "Sultan Mahmud I", "Sultan Osman III",
]

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
		"effect_ru": "+%d%% сбор налогов", "effect_en": "+%d%% Tax Collection",
		"per_level": 10.0, "kind": "income_mult",
		"base_cost": 1200.0, "cost_mult": 1.55, "level": 5,
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
		"icon": "☪", "wax_gold": false, "high_risk": false,
		"effect_ru": "+%d%% легитимность", "effect_en": "+%d%% Legitimacy",
		"per_level": 5.0, "kind": "stability",
		"base_cost": 2500.0, "cost_mult": 1.5, "level": 3,
	},
]

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
# chips — плашки для Летописи, summary — текст-резюме.
# Бесплатный «запасной» выбор — подставляется, если у события нет ни одного
# доступного варианта (гарантия баланса: игрок никогда не застрянет).
const FALLBACK_CHOICE := {
	"label_ru": "Переждать смуту", "label_en": "Wait it out",
	"effects": {"stability": -4.0, "opposition": 5.0},
	"summary_ru": "Власть промедлила — проблему пустили на самотёк.",
	"summary_en": "The court hesitated — the matter was left to fester.",
	"chips": [["−4 Стабильность", false], ["+5 Оппозиция", false]],
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
				"chips": [["+10 Стабильность", true], ["−5,000 Хазна", false]],
			},
			{
				"label_ru": "Урезать и заплатить часть", "label_en": "Cut and pay partial",
				"cost": 2000.0,
				"effects": {"stability": 3.0, "loyalty": -4.0, "army": 1.0},
				"summary_ru": "Жалованье урезали — мятеж отложен, но недовольство осталось.",
				"summary_en": "Pay was cut — the mutiny is delayed, but resentment lingers.",
				"chips": [["−2,000 Хазна", false], ["−4 Лояльность", false]],
			},
			{
				"label_ru": "Отказать и пригрозить", "label_en": "Refuse and threaten",
				"req": {"army": 60.0},
				"effects": {"stability": 6.0, "loyalty": -10.0, "army": -3.0, "legitimacy": 4.0},
				"summary_ru": "Султан пригрозил корпусу силой — порядок восстановлен страхом.",
				"summary_en": "The Sultan threatened the corps with force — order restored by fear.",
				"chips": [["+6 Стабильность", true], ["−10 Лояльность", false]],
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
				"chips": [["+5 Авторитет", true], ["Трещина Румелии ↑", false]],
			},
			{
				"label_ru": "Предоставить автономию", "label_en": "Grant autonomy",
				"effects": {"stability": -8.0, "loyalty": 6.0, "prov.rumelia.fracture": -22.0},
				"summary_ru": "Сербии дарована автономия — трещина утихла, но прецедент создан.",
				"summary_en": "Serbia was granted autonomy — the fracture eased, but a precedent is set.",
				"chips": [["+6 Лояльность", true], ["Прецедент автономии", false]],
			},
			{
				"label_ru": "Подкупить элиты", "label_en": "Bribe the elites",
				"cost": 1500.0,
				"effects": {"prov.rumelia.loyalty": 10.0, "prov.rumelia.fracture": -8.0},
				"summary_ru": "Сербских старейшин подкупили — спокойствие куплено за золото.",
				"summary_en": "The Serbian elders were bribed — calm bought with gold.",
				"chips": [["−1,500 Хазна", false], ["Румелия успокоена", true]],
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
				"effects": {"stability": 4.0, "loyalty": -3.0, "legitimacy": 6.0},
				"summary_ru": "Введён карантин вопреки протестам купцов: торговля просела, но души спасены.",
				"summary_en": "Quarantine enacted despite merchant protests. Trade suffered, but souls were spared.",
				"chips": [["Легитимность сохранена", true]],
			},
			{
				"label_ru": "Не вмешиваться", "label_en": "Do nothing",
				"effects": {"stability": -10.0, "loyalty": -12.0, "legitimacy": -6.0},
				"summary_ru": "Власть не вмешалась — хворь выкосила кварталы, народ ропщет.",
				"summary_en": "The state did nothing — the sickness ravaged the districts, the people seethe.",
				"chips": [["−12 Лояльность", false], ["−10 Стабильность", false]],
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
				"chips": [["+12,000 Хазна", true], ["Внешнее давление ↑", false]],
			},
			{
				"label_ru": "Отказаться", "label_en": "Refuse",
				"effects": {"stability": -6.0, "external_pressure": -6.0, "legitimacy": 5.0},
				"summary_ru": "Заём отвергнут ради независимости — казна страдает, но честь сохранена.",
				"summary_en": "The loan was refused for the sake of independence — the treasury suffers, but honor is kept.",
				"chips": [["Независимость", true], ["Казна напряжена", false]],
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
				"chips": [["+8 Еда", true], ["+6 Стабильность", true]],
			},
			{
				"label_ru": "Скромная починка рядов", "label_en": "Patch the old rows",
				"cost": 800.0,
				"effects": {"stability": 2.0, "food": 3.0},
				"summary_ru": "Старые торговые ряды подлатали — небольшое облегчение.",
				"summary_en": "The old market rows were patched — a modest relief.",
				"chips": [["+3 Еда", true]],
			},
			{
				"label_ru": "Отклонить прошение", "label_en": "Dismiss the petition",
				"effects": {"loyalty": -4.0},
				"summary_ru": "Прошение гильдий отклонено — купцы затаили обиду.",
				"summary_en": "The guilds' petition was dismissed — the merchants nurse a grievance.",
				"chips": [["−4 Лояльность", false]],
			},
		],
	},
	{
		"id": "market_dispute", "image": "event_cauldron", "weight": 1.6,
		"title_ru": "Спор на рынках", "title_en": "Trouble in the Markets",
		"body_ru": "Гильдии красильщиков и ткачей сцепились из-за пошлин. Базары гудят, кади ждёт твоего слова.",
		"body_en": "The dyers' and weavers' guilds are at each other's throats over duties. The bazaars buzz; the qadi awaits your word.",
		"choices": [
			{
				"label_ru": "Рассудить по справедливости", "label_en": "Mediate fairly",
				"effects": {"loyalty": 6.0, "stability": 3.0, "hazna": -500.0},
				"summary_ru": "Спор разрешён по справедливости — обе гильдии довольны.",
				"summary_en": "The dispute was settled fairly — both guilds are appeased.",
				"chips": [["+6 Лояльность", true]],
			},
			{
				"label_ru": "Ввести единую пошлину", "label_en": "Impose a flat duty",
				"effects": {"hazna": 1500.0, "loyalty": -3.0},
				"summary_ru": "Введена единая пошлина — казна пополнилась, торговцы ворчат.",
				"summary_en": "A flat duty was imposed — the treasury gained, the traders grumble.",
				"chips": [["+1,500 Хазна", true], ["−3 Лояльность", false]],
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
				"chips": [["+8 Стабильность", true], ["−8 Оппозиция", true]],
			},
			{
				"label_ru": "Выжать максимум сейчас", "label_en": "Squeeze the maximum",
				"effects": {"hazna": 4000.0, "loyalty": -8.0, "opposition": 7.0, "food": -5.0},
				"summary_ru": "Из провинций выжали золото — казна полна, недовольство растёт.",
				"summary_en": "Gold was wrung from the provinces — the treasury is full, resentment grows.",
				"chips": [["+4,000 Хазна", true], ["+7 Оппозиция", false]],
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
				"effects": {"food": 10.0, "stability": 5.0},
				"summary_ru": "Водовод восстановлен — вода и хлеб вернулись в столицу.",
				"summary_en": "The aqueduct was restored — water and bread returned to the capital.",
				"chips": [["+10 Еда", true], ["+5 Стабильность", true]],
			},
			{
				"label_ru": "Залатать наспех", "label_en": "Patch it hastily",
				"cost": 600.0,
				"effects": {"food": 4.0},
				"summary_ru": "Течь наспех залатали — временное облегчение.",
				"summary_en": "The leak was hastily patched — a temporary relief.",
				"chips": [["+4 Еда", true]],
			},
			{
				"label_ru": "Отложить ремонт", "label_en": "Delay the repair",
				"effects": {"food": -8.0, "stability": -4.0},
				"summary_ru": "Ремонт отложен — столица осталась без воды, начались перебои с хлебом.",
				"summary_en": "The repair was delayed — the capital went thirsty, and bread grew scarce.",
				"chips": [["−8 Еда", false], ["−4 Стабильность", false]],
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
				"chips": [["+10 Лояльность", true], ["−6 Оппозиция", true]],
			},
			{
				"label_ru": "Скромный праздник", "label_en": "A modest celebration",
				"effects": {"loyalty": 3.0, "hazna": -400.0},
				"summary_ru": "Праздник провели скромно — народ доволен, но без восторга.",
				"summary_en": "The celebration was modest — the people content, if unmoved.",
				"chips": [["+3 Лояльность", true]],
			},
		],
	},

	# ── Продовольственные/бунтовые события (открываются при нехватке еды) ──
	{
		"id": "grain_shortage", "image": "event_cauldron", "weight": 2.2, "max_food": 38.0,
		"title_ru": "Зерна не хватает", "title_en": "The Granaries Run Low",
		"body_ru": "Амбары пустеют, цена на хлеб взлетела. На улицах ропот — голодная толпа опасна.",
		"body_en": "The granaries empty and the price of bread soars. The streets murmur — a hungry crowd is a dangerous one.",
		"choices": [
			{
				"label_ru": "Закупить зерно у соседей", "label_en": "Buy grain abroad",
				"cost": 3500.0,
				"effects": {"food": 22.0, "stability": 6.0, "opposition": -5.0},
				"summary_ru": "Зерно закуплено за морем — амбары полны, голод отступил.",
				"summary_en": "Grain was bought overseas — the granaries fill, hunger recedes.",
				"chips": [["+22 Еда", true], ["+6 Стабильность", true]],
			},
			{
				"label_ru": "Открыть казённые амбары", "label_en": "Open the state granaries",
				"effects": {"food": 12.0, "stability": 2.0, "loyalty": 3.0, "hazna": -400.0},
				"summary_ru": "Открыты казённые амбары — народ накормлен на время.",
				"summary_en": "The state granaries were opened — the people fed, for now.",
				"chips": [["+12 Еда", true], ["+3 Лояльность", true]],
			},
			{
				"label_ru": "Разогнать толпу силой", "label_en": "Disperse the crowd",
				"req": {"army": 25.0},
				"effects": {"stability": 3.0, "loyalty": -10.0, "opposition": 8.0, "food": 2.0},
				"summary_ru": "Толпу разогнали войсками — порядок ценой ненависти.",
				"summary_en": "The crowd was dispersed by troops — order at the price of hatred.",
				"chips": [["−10 Лояльность", false], ["+8 Оппозиция", false]],
			},
		],
	},
	{
		"id": "bread_riot", "image": "event_cauldron", "weight": 2.2, "max_food": 30.0,
		"title_ru": "Хлебный бунт", "title_en": "Bread Riot",
		"body_ru": "Толпа громит пекарни и склады. «Хлеба!» — кричат под стенами дворца. Промедление смерти подобно.",
		"body_en": "The mob ransacks bakeries and storehouses. \"Bread!\" they cry beneath the palace walls. To hesitate is to perish.",
		"choices": [
			{
				"label_ru": "Раздать хлеб из казны", "label_en": "Distribute bread",
				"cost": 2000.0,
				"effects": {"food": 14.0, "loyalty": 8.0, "stability": 6.0, "opposition": -6.0},
				"summary_ru": "Народу раздали хлеб — бунт утих, султана благословляют.",
				"summary_en": "Bread was handed out — the riot subsided, the Sultan is blessed.",
				"chips": [["+8 Лояльность", true], ["−6 Оппозиция", true]],
			},
			{
				"label_ru": "Пообещать реформы", "label_en": "Promise reforms",
				"effects": {"loyalty": 3.0, "opposition": -3.0, "stability": -2.0},
				"summary_ru": "Толпе пообещали перемены — гнев отложен, но не забыт.",
				"summary_en": "The crowd was promised change — its anger delayed, not forgotten.",
				"chips": [["−3 Оппозиция", true]],
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
				"chips": [["−22 Оппозиция", true], ["−6 Лояльность", false]],
			},
			{
				"label_ru": "Откупиться и сослать", "label_en": "Buy off and exile",
				"cost": 3000.0,
				"effects": {"opposition": -14.0, "stability": 2.0},
				"summary_ru": "Визиря осыпали золотом и отправили санджак-беем в глушь.",
				"summary_en": "The Vizier was showered with gold and exiled to a distant sanjak.",
				"chips": [["−14 Оппозиция", true]],
			},
			{
				"label_ru": "Сделать вид, что не знаешь", "label_en": "Feign ignorance",
				"effects": {"opposition": 10.0, "stability": -4.0},
				"summary_ru": "Заговор оставлен без внимания — сети плетутся дальше.",
				"summary_en": "The plot was ignored — and the web is spun ever wider.",
				"chips": [["+10 Оппозиция", false]],
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
				"chips": [["−18 Оппозиция", true]],
			},
			{
				"label_ru": "Перебить зачинщиков", "label_en": "Purge the ringleaders",
				"req": {"army": 45.0},
				"effects": {"opposition": -20.0, "loyalty": -10.0, "army": -5.0},
				"summary_ru": "Зачинщиков вырезали ночью — корпус усмирён страхом.",
				"summary_en": "The ringleaders were cut down by night — the corps cowed by fear.",
				"chips": [["−20 Оппозиция", true], ["−10 Лояльность", false]],
			},
			{
				"label_ru": "Уступить требованиям", "label_en": "Concede their demands",
				"effects": {"opposition": -8.0, "stability": -5.0, "army": 3.0},
				"summary_ru": "Требования корпуса удовлетворены — мятеж отложен, власть ослабла.",
				"summary_en": "The corps' demands were met — the mutiny delayed, the crown weakened.",
				"chips": [["−8 Оппозиция", true], ["−5 Стабильность", false]],
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
				"chips": [["−24 Оппозиция", true]],
			},
			{
				"label_ru": "Опорочить его род", "label_en": "Discredit his claim",
				"effects": {"opposition": -10.0, "legitimacy": 4.0, "hazna": -800.0},
				"summary_ru": "Улемы объявили самозванца лжецом — часть сторонников отшатнулась.",
				"summary_en": "The ulema declared the pretender a liar — some supporters fell away.",
				"chips": [["−10 Оппозиция", true]],
			},
			{
				"label_ru": "Не придать значения", "label_en": "Pay it no heed",
				"effects": {"opposition": 14.0, "stability": -6.0},
				"summary_ru": "Самозванца не тронули — его войско растёт день ото дня.",
				"summary_en": "The pretender was left alone — and his host swells by the day.",
				"chips": [["+14 Оппозиция", false]],
			},
		],
	},

	# ── Бытовые события страны ──
	{
		"id": "cattle_plague", "image": "event_cauldron", "weight": 1.4,
		"title_ru": "Падёж скота", "title_en": "Cattle Plague",
		"body_ru": "В анатолийских стадах вспыхнул мор. Мясо и тягло под угрозой, крестьяне в тревоге.",
		"body_en": "A murrain strikes the Anatolian herds. Meat and draught animals are at risk; the peasants fret.",
		"choices": [
			{
				"label_ru": "Забить и возместить", "label_en": "Cull and compensate",
				"cost": 1600.0,
				"effects": {"stability": 4.0, "loyalty": 5.0, "food": 4.0},
				"summary_ru": "Больной скот забили, крестьянам возместили потери.",
				"summary_en": "The sick herds were culled and the peasants compensated.",
				"chips": [["+5 Лояльность", true], ["+4 Еда", true]],
			},
			{
				"label_ru": "Объявить карантин", "label_en": "Quarantine the herds",
				"effects": {"stability": 3.0, "food": -5.0},
				"summary_ru": "Стада заперли в карантин — мор отступил, но мяса меньше.",
				"summary_en": "The herds were quarantined — the plague eased, but meat grew scarce.",
				"chips": [["+3 Стабильность", true], ["−5 Еда", false]],
			},
		],
	},
	{
		"id": "city_fire", "image": "event_cauldron", "weight": 1.3,
		"title_ru": "Пожар в столице", "title_en": "Fire in the Capital",
		"body_ru": "Огонь охватил деревянные кварталы Стамбула. Тысячи остались без крова, народ смотрит на дворец.",
		"body_en": "Fire engulfs the wooden quarters of Istanbul. Thousands are left homeless; the people look to the palace.",
		"choices": [
			{
				"label_ru": "Отстроить за казну", "label_en": "Rebuild at crown expense",
				"cost": 2200.0,
				"effects": {"stability": 6.0, "loyalty": 8.0},
				"summary_ru": "Кварталы отстроили за счёт казны — народ благодарен.",
				"summary_en": "The quarters were rebuilt at the crown's expense — the people are grateful.",
				"chips": [["+8 Лояльность", true]],
			},
			{
				"label_ru": "Организовать дружины", "label_en": "Organize fire brigades",
				"effects": {"loyalty": 3.0, "stability": -2.0},
				"summary_ru": "Пожарные дружины кое-как справились — без большой казны.",
				"summary_en": "Bucket brigades managed somehow — without great cost.",
				"chips": [["+3 Лояльность", true]],
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
				"chips": [["+4,500 Хазна", true]],
			},
			{
				"label_ru": "Обложить пошлиной", "label_en": "Levy a toll",
				"effects": {"hazna": 2500.0, "loyalty": -3.0},
				"summary_ru": "С каравана взяли пошлину — золото есть, купцы недовольны.",
				"summary_en": "A toll was taken — gold flows, the merchants grumble.",
				"chips": [["+2,500 Хазна", true], ["−3 Лояльность", false]],
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
				"chips": [["+6 Легитимность", true]],
			},
			{
				"label_ru": "Скромная школа", "label_en": "A modest school",
				"effects": {"legitimacy": 2.0},
				"summary_ru": "Открыли скромную школу при мечети — малое благо.",
				"summary_en": "A modest mosque school was opened — a small boon.",
				"chips": [["+2 Легитимность", true]],
			},
		],
	},
	{
		"id": "wakf_dispute", "image": "event_cauldron", "weight": 1.3,
		"title_ru": "Спор о вакфе", "title_en": "A Waqf Dispute",
		"body_ru": "Богатый вакф остался без попечителя. Улемы и казначеи тянут его доходы каждый на себя.",
		"body_en": "A wealthy waqf endowment is left without a trustee. Ulema and treasurers each pull its revenues their way.",
		"choices": [
			{
				"label_ru": "В пользу улемов", "label_en": "Rule for the ulema",
				"effects": {"legitimacy": 5.0, "hazna": -800.0},
				"summary_ru": "Вакф отдан улемам — вера довольна, казна недосчиталась.",
				"summary_en": "The waqf went to the ulema — the faith is pleased, the treasury less so.",
				"chips": [["+5 Легитимность", true]],
			},
			{
				"label_ru": "В пользу казны", "label_en": "Rule for the treasury",
				"effects": {"hazna": 3000.0, "legitimacy": -5.0},
				"summary_ru": "Доходы вакфа влились в казну — улемы оскорблены.",
				"summary_en": "The waqf's revenues flowed to the treasury — the ulema are affronted.",
				"chips": [["+3,000 Хазна", true], ["−5 Легитимность", false]],
			},
		],
	},

	# ── Упадок армии (открываются при низкой армии) ──
	{
		"id": "desertion", "image": "event_cauldron", "weight": 2.0, "max_army": 42.0,
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
				"chips": [["+12 Армия", true]],
			},
			{
				"label_ru": "Жёсткая дисциплина", "label_en": "Harsh discipline",
				"effects": {"army": 6.0, "loyalty": -8.0, "opposition": 6.0},
				"summary_ru": "Беглецов наказали для острастки — порядок ценой страха.",
				"summary_en": "Deserters were punished as a warning — order at the price of fear.",
				"chips": [["+6 Армия", true], ["−8 Лояльность", false]],
			},
		],
	},
	{
		"id": "recruit_shortage", "image": "event_cauldron", "weight": 2.0, "max_army": 40.0,
		"title_ru": "Нехватка солдат", "title_en": "Manpower Shortage",
		"body_ru": "Полки поредели, а границы неспокойны. Войску нужны новые руки — и поскорее.",
		"body_en": "The regiments are thin and the borders restless. The army needs fresh hands — and soon.",
		"choices": [
			{
				"label_ru": "Объявить набор", "label_en": "Levy fresh troops",
				"cost": 2200.0,
				"effects": {"army": 14.0, "loyalty": -4.0},
				"summary_ru": "По провинциям объявлен набор — полки пополнились.",
				"summary_en": "A levy was called across the provinces — the regiments swelled.",
				"chips": [["+14 Армия", true], ["−4 Лояльность", false]],
			},
			{
				"label_ru": "Нанять наёмников", "label_en": "Hire mercenaries",
				"cost": 4500.0,
				"effects": {"army": 20.0, "external_pressure": 6.0},
				"summary_ru": "Наняли наёмников — войско сильно, но казна и честь в убытке.",
				"summary_en": "Mercenaries were hired — a strong host, but treasury and honor suffer.",
				"chips": [["+20 Армия", true]],
			},
			{
				"label_ru": "Положиться на имеющихся", "label_en": "Make do",
				"effects": {"army": -4.0, "stability": -3.0},
				"summary_ru": "Решили обойтись своими — войско продолжает редеть.",
				"summary_en": "You chose to make do — the army keeps thinning.",
				"chips": [["−4 Армия", false]],
			},
		],
	},

	# ── Голод/крестьяне (открываются при нехватке еды) ──
	{
		"id": "peasant_discontent", "image": "event_cauldron", "weight": 2.0, "max_food": 46.0,
		"title_ru": "Недовольные крестьяне", "title_en": "Discontented Peasants",
		"body_ru": "Деревни ропщут: подати высоки, амбары пусты. Старосты шлют челобитные одну за другой.",
		"body_en": "The villages murmur: taxes are high, granaries empty. Headmen send petition after petition.",
		"choices": [
			{
				"label_ru": "Снизить подати", "label_en": "Lower the taxes",
				"effects": {"loyalty": 7.0, "stability": 4.0, "hazna": -700.0},
				"summary_ru": "Подати снижены — крестьяне вздохнули свободнее.",
				"summary_en": "Taxes were lowered — the peasants breathe easier.",
				"chips": [["+7 Лояльность", true]],
			},
			{
				"label_ru": "Раздать хлеб", "label_en": "Hand out grain",
				"cost": 1800.0,
				"effects": {"food": 12.0, "loyalty": 6.0},
				"summary_ru": "Народу раздали хлеб из казённых амбаров.",
				"summary_en": "Grain from the state stores was handed out to the people.",
				"chips": [["+12 Еда", true]],
			},
			{
				"label_ru": "Подавить ропот", "label_en": "Suppress the murmurs",
				"req": {"army": 25.0},
				"effects": {"stability": 3.0, "loyalty": -9.0, "opposition": 7.0},
				"summary_ru": "Недовольных усмирили войсками — тихо, но злобу затаили.",
				"summary_en": "The discontent were cowed by troops — quiet, but resentful.",
				"chips": [["−9 Лояльность", false], ["+7 Оппозиция", false]],
			},
		],
	},
	{
		"id": "crop_failure", "image": "event_cauldron", "weight": 2.0, "max_food": 44.0,
		"title_ru": "Неурожай", "title_en": "Crop Failure",
		"body_ru": "Засуха выжгла поля. Урожай скуден, и призрак голода бродит по деревням.",
		"body_en": "Drought has scorched the fields. The harvest is meagre, and the spectre of famine walks the villages.",
		"choices": [
			{
				"label_ru": "Закупить продовольствие", "label_en": "Buy provisions abroad",
				"cost": 3000.0,
				"effects": {"food": 18.0, "stability": 3.0},
				"summary_ru": "Зерно закуплено за морем — амбары снова полны.",
				"summary_en": "Grain was bought overseas — the granaries fill once more.",
				"chips": [["+18 Еда", true]],
			},
			{
				"label_ru": "Открыть резервы", "label_en": "Open the reserves",
				"effects": {"food": 9.0, "stability": -3.0},
				"summary_ru": "Открыли неприкосновенный запас — облегчение на время.",
				"summary_en": "The emergency reserves were opened — relief for a while.",
				"chips": [["+9 Еда", true], ["−3 Стабильность", false]],
			},
		],
	},

	# ── Падение стабильности ──
	{
		"id": "provincial_unrest", "image": "event_cauldron", "weight": 2.0, "max_stability": 40.0,
		"title_ru": "Волнения в провинции", "title_en": "Provincial Unrest",
		"body_ru": "В одном из эялетов вспыхнули беспорядки. Наместник просит указаний, пока искра не стала пожаром.",
		"body_en": "Unrest flares in one of the eyalets. The governor begs for orders before the spark becomes a blaze.",
		"choices": [
			{
				"label_ru": "Послать наместника", "label_en": "Send a trusted governor",
				"cost": 2000.0,
				"effects": {"stability": 8.0, "loyalty": 4.0},
				"summary_ru": "Надёжный наместник усмирил край миром и золотом.",
				"summary_en": "A trusted governor settled the province with gold and calm.",
				"chips": [["+8 Стабильность", true]],
			},
			{
				"label_ru": "Ввести войска", "label_en": "March in troops",
				"req": {"army": 30.0},
				"effects": {"stability": 6.0, "loyalty": -7.0, "opposition": 5.0},
				"summary_ru": "Беспорядки подавлены войсками — порядок ценой крови.",
				"summary_en": "The unrest was crushed by troops — order at the price of blood.",
				"chips": [["+6 Стабильность", true], ["−7 Лояльность", false]],
			},
			{
				"label_ru": "Пустить на самотёк", "label_en": "Let it burn out",
				"effects": {"stability": -6.0, "loyalty": -5.0},
				"summary_ru": "Беспорядки оставили тлеть — край всё глубже в смуте.",
				"summary_en": "The unrest was left to smoulder — the province sinks deeper into chaos.",
				"chips": [["−6 Стабильность", false]],
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
				"chips": [["+7 Стабильность", true]],
			},
			{
				"label_ru": "Сместить смутьянов", "label_en": "Dismiss the troublemakers",
				"effects": {"stability": 5.0, "loyalty": -6.0, "opposition": 6.0},
				"summary_ru": "Смутьянов сместили — порядок есть, обиженные затаились.",
				"summary_en": "The troublemakers were dismissed — order restored, the slighted seethe.",
				"chips": [["+5 Стабильность", true], ["+6 Оппозиция", false]],
			},
		],
	},

	# ── Рост оппозиции ──
	{
		"id": "seditious_pamphlets", "image": "event_cauldron", "weight": 2.0, "min_opposition": 35.0,
		"title_ru": "Крамольные памфлеты", "title_en": "Seditious Pamphlets",
		"body_ru": "По базарам ходят листки, что чернят султана. Слово опаснее сабли, если его не остановить.",
		"body_en": "Leaflets slandering the Sultan circulate through the bazaars. A word is sharper than a sabre if left unchecked.",
		"choices": [
			{
				"label_ru": "Цензура и аресты", "label_en": "Censor and arrest",
				"cost": 1500.0,
				"effects": {"opposition": -12.0, "loyalty": -4.0},
				"summary_ru": "Печатников схватили, листки сожгли — ропот притих.",
				"summary_en": "The printers were seized and the leaflets burned — the murmuring fell quiet.",
				"chips": [["−12 Оппозиция", true]],
			},
			{
				"label_ru": "Контр-пропаганда", "label_en": "Counter-propaganda",
				"effects": {"opposition": -6.0, "legitimacy": 4.0, "hazna": -600.0},
				"summary_ru": "Улемы и поэты восславили султана в ответ.",
				"summary_en": "Ulema and poets sang the Sultan's praises in answer.",
				"chips": [["−6 Оппозиция", true]],
			},
			{
				"label_ru": "Не обращать внимания", "label_en": "Pay it no mind",
				"effects": {"opposition": 8.0, "stability": -3.0},
				"summary_ru": "Памфлеты оставили без ответа — их стало лишь больше.",
				"summary_en": "The pamphlets went unanswered — and only multiplied.",
				"chips": [["+8 Оппозиция", false]],
			},
		],
	},
	{
		"id": "tax_protest", "image": "event_cauldron", "weight": 2.0, "min_opposition": 30.0,
		"title_ru": "Протест против налогов", "title_en": "Tax Protest",
		"body_ru": "Новые поборы взбесили горожан. Лавки закрываются, толпа собирается у мечети.",
		"body_en": "The new levies have enraged the townsfolk. Shops shutter, a crowd gathers at the mosque.",
		"choices": [
			{
				"label_ru": "Отменить новый налог", "label_en": "Repeal the new tax",
				"effects": {"opposition": -10.0, "loyalty": 5.0, "hazna": -800.0},
				"summary_ru": "Налог отменён — горожане ликуют, казна в убытке.",
				"summary_en": "The tax was repealed — the townsfolk rejoice, the treasury loses out.",
				"chips": [["−10 Оппозиция", true]],
			},
			{
				"label_ru": "Обещать пересмотр", "label_en": "Promise a review",
				"effects": {"opposition": -4.0, "stability": -2.0},
				"summary_ru": "Толпе пообещали пересмотр — гнев отложен.",
				"summary_en": "The crowd was promised a review — its anger postponed.",
				"chips": [["−4 Оппозиция", true]],
			},
			{
				"label_ru": "Разогнать силой", "label_en": "Disperse by force",
				"req": {"army": 25.0},
				"effects": {"stability": 4.0, "loyalty": -8.0, "opposition": 6.0},
				"summary_ru": "Протест разогнали войсками — улицы пусты, сердца полны злобы.",
				"summary_en": "The protest was scattered by troops — empty streets, bitter hearts.",
				"chips": [["−8 Лояльность", false]],
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
				"chips": [["+9 Лояльность", true]],
			},
			{
				"label_ru": "Даровать привилегии", "label_en": "Grant privileges",
				"effects": {"loyalty": 6.0, "stability": -4.0},
				"summary_ru": "Знати даровали привилегии — верность куплена ценой власти.",
				"summary_en": "Privileges were granted — loyalty bought at the cost of authority.",
				"chips": [["+6 Лояльность", true], ["−4 Стабильность", false]],
			},
			{
				"label_ru": "Не уступать", "label_en": "Yield nothing",
				"effects": {"loyalty": -6.0, "opposition": 6.0},
				"summary_ru": "Султан не уступил — знать затаила обиду.",
				"summary_en": "The Sultan yielded nothing — the nobles nurse a grudge.",
				"chips": [["−6 Лояльность", false]],
			},
		],
	},

	# ── ОСТРЫЕ / ОПАСНЫЕ события ──
	{
		"id": "famine", "image": "event_cauldron", "weight": 2.6, "max_food": 34.0,
		"title_ru": "Великий голод", "title_en": "The Great Famine",
		"body_ru": "Амбары пусты, на улицах умирают от голода. Народ на грани восстания — промедление будет стоить трона.",
		"body_en": "The granaries are empty; people die of hunger in the streets. The realm teeters on revolt — delay will cost the throne.",
		"choices": [
			{
				"label_ru": "Срочный ввоз зерна", "label_en": "Emergency grain import",
				"cost": 4200.0,
				"effects": {"food": 26.0, "stability": 6.0, "opposition": -6.0},
				"summary_ru": "Зерно завезли из-за моря — голод отступил в последний миг.",
				"summary_en": "Grain was rushed in from overseas — famine receded at the last moment.",
				"chips": [["+26 Еда", true], ["−6 Оппозиция", true]],
			},
			{
				"label_ru": "Открыть все амбары", "label_en": "Open every granary",
				"effects": {"food": 13.0, "stability": -3.0, "loyalty": 3.0},
				"summary_ru": "Опустошили последние запасы — облегчение, но впереди голые амбары.",
				"summary_en": "The last stores were emptied — relief now, bare granaries ahead.",
				"chips": [["+13 Еда", true], ["−3 Стабильность", false]],
			},
			{
				"label_ru": "Положиться на провидение", "label_en": "Trust to providence",
				"effects": {"stability": -12.0, "loyalty": -12.0, "opposition": 12.0},
				"summary_ru": "Власть бездействовала — голод выкосил деревни, народ проклинает султана.",
				"summary_en": "The crown did nothing — famine ravaged the villages, the people curse the Sultan.",
				"chips": [["−12 Стабильность", false], ["+12 Оппозиция", false]],
			},
		],
	},
	{
		"id": "city_disaster", "image": "event_cauldron", "weight": 1.9,
		"title_ru": "Стихия разрушила город", "title_en": "A City Laid Waste",
		"body_ru": "Землетрясение и пожары сравняли с землёй один из ваших городов. Кварталы, что вы поднимали годами, лежат в руинах.",
		"body_en": "Earthquake and fire have levelled one of your cities. The quarters you raised over years lie in ruins.",
		"choices": [
			{
				"label_ru": "Бросить казну на восстановление", "label_en": "Pour the treasury into rebuilding",
				"cost": 3200.0,
				"effects": {"raze_province": 0.55, "stability": 3.0, "loyalty": 3.0},
				"summary_ru": "Город отстраивают за счёт казны — потеряно немногое, но дорого.",
				"summary_en": "The city is rebuilt at crown expense — little was lost, but at great cost.",
				"chips": [["Город частично спасён", true]],
			},
			{
				"label_ru": "Восстанавливать своими силами", "label_en": "Let it rebuild itself",
				"effects": {"raze_province": 0.15, "stability": -6.0, "loyalty": -5.0, "food": -4.0},
				"summary_ru": "Город оставили подниматься самому — почти всё развитие утрачено, прокачивать заново.",
				"summary_en": "The city was left to rebuild on its own — nearly all its development is lost; start it anew.",
				"chips": [["Развитие города утрачено", false]],
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
				"chips": [["−20 Оппозиция", true], ["−8 Лояльность", false]],
			},
			{
				"label_ru": "Откупиться титулами", "label_en": "Buy him off with titles",
				"cost": 3600.0,
				"effects": {"opposition": -14.0, "stability": 2.0},
				"summary_ru": "Паше дали титулы и золото — его честолюбие пока утолено.",
				"summary_en": "The pasha was given titles and gold — his ambition sated, for now.",
				"chips": [["−14 Оппозиция", true]],
			},
			{
				"label_ru": "Даровать автономию", "label_en": "Grant him autonomy",
				"effects": {"opposition": -8.0, "stability": -8.0, "legitimacy": -6.0},
				"summary_ru": "Паше отдали край в управление — мир куплен ценой власти султана.",
				"summary_en": "The pasha was granted his province — peace bought at the cost of the Sultan's authority.",
				"chips": [["−8 Оппозиция", true], ["−8 Стабильность", false]],
			},
		],
	},
	{
		"id": "foreign_ultimatum", "image": "event_cauldron", "weight": 2.1, "min_external_pressure": 30.0,
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
				"chips": [["−18 Давление", true], ["−6 Легитимность", false]],
			},
			{
				"label_ru": "Гордо отказать", "label_en": "Refuse with pride",
				"effects": {"external_pressure": 12.0, "legitimacy": 9.0, "stability": 5.0},
				"summary_ru": "Послов выпроводили — народ ликует, но тучи на границах сгустились.",
				"summary_en": "The envoys were sent packing — the people cheer, but storm clouds gather at the borders.",
				"chips": [["+9 Легитимность", true], ["+12 Давление", false]],
			},
			{
				"label_ru": "Искать союзников", "label_en": "Seek allies",
				"cost": 2600.0,
				"effects": {"external_pressure": -10.0, "legitimacy": 3.0},
				"summary_ru": "Через тайную дипломатию нашли союзников — давление ослабло.",
				"summary_en": "Through quiet diplomacy allies were found — the pressure slackened.",
				"chips": [["−10 Давление", true]],
			},
		],
	},
	{
		"id": "great_plague", "image": "event_cauldron", "weight": 1.8,
		"title_ru": "Чёрный мор", "title_en": "The Black Death",
		"body_ru": "Корабли принесли в порты чёрный мор. Он расползается по кварталам, не щадя ни бедных, ни знатных.",
		"body_en": "Ships have brought the black death to the ports. It creeps through the quarters, sparing neither poor nor noble.",
		"choices": [
			{
				"label_ru": "Строгий карантин", "label_en": "Strict quarantine",
				"cost": 3000.0,
				"effects": {"stability": 5.0, "legitimacy": 5.0, "food": -6.0, "loyalty": -2.0},
				"summary_ru": "Города заперли в карантин — мор сдержан ценой торговли и хлеба.",
				"summary_en": "The cities were sealed in quarantine — the plague checked at the cost of trade and bread.",
				"chips": [["+5 Стабильность", true], ["−6 Еда", false]],
			},
			{
				"label_ru": "Молиться и ждать", "label_en": "Pray and wait",
				"effects": {"stability": -9.0, "loyalty": -9.0, "food": -6.0, "opposition": 7.0},
				"summary_ru": "Власть лишь молилась — мор выкосил кварталы, народ в отчаянии.",
				"summary_en": "The crown only prayed — the plague gutted the districts, the people despair.",
				"chips": [["−9 Стабильность", false], ["+7 Оппозиция", false]],
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
				"chips": [["−22 Оппозиция", true]],
			},
			{
				"label_ru": "Подкупить претендента", "label_en": "Bribe the pretender",
				"cost": 4000.0,
				"effects": {"opposition": -16.0},
				"summary_ru": "Соперника осыпали золотом — он отступил в тень.",
				"summary_en": "The rival was showered with gold — he withdrew into the shadows.",
				"chips": [["−16 Оппозиция", true]],
			},
			{
				"label_ru": "Закрыть глаза", "label_en": "Look the other way",
				"effects": {"opposition": 12.0, "stability": -6.0},
				"summary_ru": "Заговор оставили без внимания — кинжалы всё ближе к трону.",
				"summary_en": "The plot was ignored — the daggers draw ever closer to the throne.",
				"chips": [["+12 Оппозиция", false]],
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
				"chips": [["−28 Оппозиция", true], ["−12 Армия", false]],
			},
			{
				"label_ru": "Пойти на уступки", "label_en": "Make concessions",
				"cost": 2800.0,
				"effects": {"opposition": -14.0, "loyalty": 6.0},
				"summary_ru": "Уступки и подачки утихомирили толпу — но мятежный дух остался.",
				"summary_en": "Concessions and handouts quieted the crowd — though the rebellious spirit lingers.",
				"chips": [["−14 Оппозиция", true]],
			},
			{
				"label_ru": "Переждать бурю", "label_en": "Wait out the storm",
				"effects": {"opposition": 6.0, "stability": -4.0},
				"summary_ru": "Власть выжидала — недовольство только окрепло.",
				"summary_en": "The crown waited — the discontent only hardened.",
				"chips": [["+6 Оппозиция", false]],
			},
		],
	},
]
