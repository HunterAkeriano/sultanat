extends Control
## HUD — шапка игрового экрана: султан + год/эпоха + ряд ресурс-чипов (§21.4.1).

const StatCardScript := preload("res://scripts/ui/StatCard.gd")

var _sultan_lbl: Label
var _year_lbl: Label
var _era_lbl: Label
var _root: VBoxContainer
var chips := {}        # ключ -> {value: Label, root: PanelContainer}
var menu_pressed: Callable

func build() -> void:
	# Полупрозрачная тёмная панель.
	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.055, 0.078, 0.0)   # без своей подложки: фон единый с игрой
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var mc := MarginContainer.new()
	for s in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + s, Palette.SAFE_AREA)
	mc.add_theme_constant_override("margin_top", 6)
	mc.add_theme_constant_override("margin_bottom", 4)
	root.add_child(mc)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	mc.add_child(col)

	# ── Шапка: имя (слева) | год + эпоха + ⚙ (справа) ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	col.add_child(header)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.size_flags_vertical = Control.SIZE_FILL
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(name_box)
	# ☰ — возврат в главное меню (сверху, на уровне года)
	var burger := Button.new()
	burger.text = "\u2630"
	burger.flat = true
	burger.focus_mode = Control.FOCUS_NONE
	burger.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	burger.add_theme_font_size_override("font_size", 16)
	burger.add_theme_color_override("font_color", Palette.ON_SURFACE_VARIANT)
	burger.pressed.connect(func(): if menu_pressed.is_valid(): menu_pressed.call())
	name_box.add_child(burger)
	# Имя султана — ниже, на уровне названия эпохи
	_sultan_lbl = Palette.label(GameState.current_sultan(), Palette.FS_TITLE, Palette.PRIMARY, true)
	_sultan_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_box.add_child(_sultan_lbl)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 0)
	header.add_child(right)
	_year_lbl = Palette.label_caps("", Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	_year_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_year_lbl)
	_era_lbl = Palette.label(GameData.era_name(), Palette.FS_TITLE, Palette.TERTIARY, true)
	_era_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_era_lbl)

	# ── Ряд 1: три арочные карточки. Центральная арка — Хазна — выделена,
	#    крупнее и стоит выше. Боковые арки того же общего слота высоты,
	#    но их острия визуально СДВИНУТЫ ВНИЗ через MarginContainer сверху:
	#    так центральная возвышается над ними, а низ у всех трёх ровный. ──
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	col.add_child(row1)
	var central_h := 140.0
	var side_h := 100.0
	var top_drop := int(central_h - side_h)   # сколько пикселей боковые опущены вниз
	_make_side_arch(row1, "stability", "\u2696", side_h, top_drop, Palette.SECONDARY, "")
	_make_card(row1, "hazna", "\u269C", "arch", central_h, Palette.PRIMARY, "", true)
	_make_side_arch(row1, "army", "\u2694", side_h, top_drop, Palette.SECONDARY, "")

	# ── Ряд 2: две скруглённые карточки — Лояльность и Еда ──
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	col.add_child(row2)
	_make_card(row2, "loyalty", "\u2665", "round", 60.0, Palette.SECONDARY, "")
	_make_card(row2, "food", "🌾", "round", 60.0, Palette.SECONDARY, "")

	# ── Ряд 3: широкая карточка — Оппозиция ──
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	col.add_child(row3)
	_make_card(row3, "opposition", "\u2620", "round", 60.0, Palette.SECONDARY, "")

	# Фиксированная высота шапки с запасом под шапку + 3 ряда —
	# ничего не налезает и не обрезается.
	custom_minimum_size.y = 400.0

func _apply_height() -> void:
	pass

func _make_card(row: HBoxContainer, key: String, icon: String, shape: String, h: float, value_color: Color, caption: String = "", highlighted: bool = false) -> void:
	var card = StatCardScript.new()
	# Выделенная (центральная) карточка получает бОльший вес — растягивается сильнее
	if highlighted:
		card.highlighted = true
		card.size_flags_stretch_ratio = 1.35
	card.setup(icon, shape, value_color, h)
	if caption != "":
		card.set_caption(caption)
	row.add_child(card)
	chips[key] = card.value_label()

# Боковая арка: сама карточка укороченная (h), но обёрнута в MarginContainer
# с top_drop сверху — визуально её острие ниже, чем у центральной арки.
func _make_side_arch(row: HBoxContainer, key: String, icon: String, h: float, top_drop: int, value_color: Color, caption: String) -> void:
	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("margin_top", top_drop)
	row.add_child(wrap)
	var card = StatCardScript.new()
	card.setup(icon, "arch", value_color, h)
	if caption != "":
		card.set_caption(caption)
	wrap.add_child(card)
	chips[key] = card.value_label()

func _safe_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var alt := path.get_basename() + ".webp"
	if ResourceLoader.exists(alt):
		return load(alt)
	return null

func update_view() -> void:
	_sultan_lbl.text = GameState.current_sultan()
	_year_lbl.text = "%s %d" % [Loc.t("common.year"), GameState.year]
	_era_lbl.text = GameData.era_name()
	_era_lbl.add_theme_color_override("font_color",
		Palette.SECONDARY if GameState.stability >= 55 else Palette.TERTIARY)

	chips["hazna"].text = Palette.fmt(GameState.hazna)
	chips["hazna"].add_theme_color_override("font_color", Palette.PRIMARY)
	_set_stat("stability", GameState.stability, true)
	_set_stat("army", GameState.army, false)
	_set_stat("loyalty", GameState.loyalty, true)
	_set_stat("food", GameState.food, true)
	_set_opposition(GameState.opposition)

func _set_opposition(v: float) -> void:
	# Оппозиция: чем выше — тем опаснее (инверсные цвета).
	var lbl: Label = chips["opposition"]
	lbl.text = "%d%%" % int(round(v))
	var c := Palette.SECONDARY
	if v >= 70.0:
		c = Palette.TERTIARY
	elif v >= 45.0:
		c = Palette.PRIMARY
	lbl.add_theme_color_override("font_color", c)

func _set_stat(key: String, v: float, pct: bool) -> void:
	var lbl: Label = chips[key]
	lbl.text = ("%d%%" % int(round(v))) if pct else str(int(round(v)))
	var c := Palette.SECONDARY
	if v < 30.0:
		c = Palette.TERTIARY
	elif v < 50.0:
		c = Palette.PRIMARY
	lbl.add_theme_color_override("font_color", c)
