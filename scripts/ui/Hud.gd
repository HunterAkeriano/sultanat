extends Control
## HUD — шапка игрового экрана: султан + год/эпоха + ряд из 4 ресурс-чипов (§21.4.1).

var _sultan_lbl: Label
var _year_lbl: Label
var _era_lbl: Label
var _root: VBoxContainer
var chips := {}        # ключ -> {value: Label, root: PanelContainer}
var gear_pressed: Callable

func build() -> void:
	# Непрозрачный фон шапки (как app-bar в референсе) — контент под неё не просвечивает.
	var bg := ColorRect.new()
	bg.color = Palette.SURFACE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var mc := MarginContainer.new()
	for s in ["left", "right", "top"]:
		mc.add_theme_constant_override("margin_" + s, Palette.SAFE_AREA)
	mc.add_theme_constant_override("margin_bottom", 4)
	root.add_child(mc)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	mc.add_child(col)

	# ── Строка шапки: тугра + имя султана | год + эпоха + ⚙ ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	col.add_child(header)

	var tughra := Palette.label("\u262A", 26, Palette.PRIMARY, true)  # ☪
	header.add_child(tughra)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 0)
	header.add_child(name_box)
	_sultan_lbl = Palette.label(GameState.current_sultan(), Palette.FS_TITLE, Palette.PRIMARY, true)
	name_box.add_child(_sultan_lbl)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 0)
	header.add_child(right)
	_year_lbl = Palette.label_caps("%s %d" % [Loc.t("common.year"), GameState.year], Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	_year_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_year_lbl)
	_era_lbl = Palette.label(GameData.era_name(), Palette.FS_TITLE, Palette.TERTIARY, true)
	_era_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_era_lbl)

	var gear := Button.new()
	gear.text = "\u2699"  # ⚙
	gear.flat = true
	gear.add_theme_font_size_override("font_size", 22)
	gear.add_theme_color_override("font_color", Palette.ON_SURFACE_VARIANT)
	gear.pressed.connect(func(): if gear_pressed.is_valid(): gear_pressed.call())
	right.add_child(gear)

	# ── Ряд ресурс-чипов ──
	var chips_row := HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 8)
	col.add_child(chips_row)
	_make_chip(chips_row, "hazna", "\u269C", Loc.t("res.hazna"))
	_make_chip(chips_row, "stability", "\u2696", Loc.t("res.stability"))
	_make_chip(chips_row, "army", "\u2694", Loc.t("res.army"))
	_make_chip(chips_row, "loyalty", "\u2665", Loc.t("res.loyalty"))

	# ── Второй ряд: Еда + Оппозиция (кризис-метры) ──
	var crisis_row := HBoxContainer.new()
	crisis_row.add_theme_constant_override("separation", 8)
	col.add_child(crisis_row)
	_make_chip(crisis_row, "food", "\u2698", Loc.t("res.food"))         # ⚘ колос
	_make_chip(crisis_row, "opposition", "\u2620", Loc.t("res.opposition"))  # ☠ оппозиция

	# ── Разделитель (нижняя граница app-bar) ──
	var sep := ColorRect.new()
	sep.color = Palette.PRIMARY_CONTAINER
	sep.custom_minimum_size = Vector2(0, 2)
	col.add_child(sep)

	# Шапка подстраивает свою высоту под содержимое (адаптив, без наложения).
	_root = root
	call_deferred("_apply_height")

func _apply_height() -> void:
	if is_instance_valid(_root):
		var h := _root.get_combined_minimum_size().y
		if h > 0.0:
			custom_minimum_size.y = h

func _make_chip(row: HBoxContainer, key: String, icon: String, _name: String) -> void:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", Palette.box(Palette.SURFACE_HIGH, 6, 1, Palette.PRIMARY.darkened(0.1), 8))
	row.add_child(pc)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	pc.add_child(v)
	var ico := Palette.label(icon, 16, Palette.ON_SURFACE_VARIANT)
	ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ico)
	var val := Palette.label("0", Palette.FS_BODY, Palette.ON_SURFACE)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(val)
	chips[key] = val

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
