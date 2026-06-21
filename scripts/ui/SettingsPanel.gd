extends Control
## SettingsPanel — оверлей настроек (§6.1): язык RU/EN, сброс прогресса,
## «Об игре». Плюс попап офлайн-дохода (§26) при возвращении в игру.

signal language_toggled

var _btn_ru: Button
var _btn_en: Button
var _music_btn: Button
var _reset_btn: Button
var _reset_armed := false
var _settings_root: Control
var _offline_root: Control
var _offline_lbl: Label

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_settings_root = _build_settings()
	add_child(_settings_root)
	_offline_root = _build_offline()
	add_child(_offline_root)

func _dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim

func _build_settings() -> Control:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.visible = false
	var dim := _dim()
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	wrap.add_child(dim)

	# Карта на (почти) весь экран с прокруткой — адаптивно под любой размер.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", Palette.SAFE_AREA)
	margin.add_theme_constant_override("margin_right", Palette.SAFE_AREA)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 56)
	wrap.add_child(margin)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Palette.tezhip(Palette.SURFACE_CONTAINER, 12, 18))
	margin.add_child(card)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	card.add_child(outer)

	outer.add_child(Palette.label(Loc.t("set.title"), Palette.FS_TITLE, Palette.PRIMARY, true))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 16)
	scroll.add_child(v)

	# Язык
	v.add_child(Palette.label_caps(Loc.t("set.language"), Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT))
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	v.add_child(lang_row)
	_btn_ru = Button.new()
	_btn_ru.text = "Русский"
	_btn_ru.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_ru.pressed.connect(func(): _set_lang("ru"))
	lang_row.add_child(_btn_ru)
	_btn_en = Button.new()
	_btn_en.text = "English"
	_btn_en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_en.pressed.connect(func(): _set_lang("en"))
	lang_row.add_child(_btn_en)

	# Музыка (вкл/выкл)
	v.add_child(Palette.label_caps(Loc.t("set.music"), Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT))
	_music_btn = Button.new()
	_music_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(_music_btn, true)
	_music_btn.pressed.connect(_on_toggle_music)
	v.add_child(_music_btn)
	_refresh_music_btn()

	var sep := ColorRect.new()
	sep.color = Palette.OUTLINE_VARIANT
	sep.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep)

	# ── Легенда показателей ──
	v.add_child(Palette.label_caps(Loc.t("set.legend"), Palette.FS_LABEL, Palette.PRIMARY))
	_legend_row(v, "\u269C", Loc.t("res.hazna"), Loc.t("leg.hazna"), Palette.PRIMARY)
	_legend_row(v, "\u2696", Loc.t("res.stability"), Loc.t("leg.stability"), Palette.SECONDARY)
	_legend_row(v, "\u2694", Loc.t("res.army"), Loc.t("leg.army"), Palette.ON_SURFACE)
	_legend_row(v, "\u2665", Loc.t("res.loyalty"), Loc.t("leg.loyalty"), Palette.SECONDARY)
	_legend_row(v, "\u2698", Loc.t("res.food"), Loc.t("leg.food"), Palette.SECONDARY)
	_legend_row(v, "\u2620", Loc.t("res.opposition"), Loc.t("leg.opposition"), Palette.TERTIARY)
	_legend_row(v, "\u2693", Loc.t("res.pressure"), Loc.t("leg.pressure"), Palette.ON_SURFACE_VARIANT)

	var sep2 := ColorRect.new()
	sep2.color = Palette.OUTLINE_VARIANT
	sep2.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep2)

	# Об игре
	var about := Palette.label(Loc.t("set.about_text"), Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(about)

	# ── Низ карты (всегда виден): сброс + закрыть ──
	_reset_btn = Button.new()
	_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(_reset_btn, false)
	_reset_btn.text = Loc.t("set.reset")
	_reset_btn.pressed.connect(_on_reset)
	outer.add_child(_reset_btn)

	var close_btn := Button.new()
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(close_btn, true)
	close_btn.text = Loc.t("set.close")
	close_btn.pressed.connect(close)
	outer.add_child(close_btn)

	return wrap

func _legend_row(parent: VBoxContainer, icon: String, name: String, desc: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var ic := Palette.label(icon, 18, col)
	ic.custom_minimum_size = Vector2(24, 0)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	row.add_child(box)
	box.add_child(Palette.label(name, Palette.FS_BODY, col, true))
	var d := Palette.label(desc, Palette.FS_LABEL, Palette.ON_SURFACE_VARIANT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(d)

func _build_offline() -> Control:
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.visible = false
	wrap.add_child(_dim())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(310, 0)
	card.add_theme_stylebox_override("panel", Palette.tezhip(Palette.SURFACE_LOWEST, 12, 20))
	center.add_child(card)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var tughra := Palette.label("\u262A", 28, Palette.PRIMARY, true)
	tughra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tughra)
	var cap := Palette.label(Loc.t("set.offline"), Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(cap)
	_offline_lbl = Palette.label("+0 \u262A", Palette.FS_HEADLINE, Palette.PRIMARY, true)
	_offline_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_offline_lbl)
	var ok := Button.new()
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(ok, true)
	ok.text = Loc.t("common.confirm")
	ok.pressed.connect(_on_offline_ok)
	v.add_child(ok)

	return wrap

func _on_offline_ok() -> void:
	_offline_root.visible = false
	if not _settings_root.visible:
		visible = false

func _set_lang(l: String) -> void:
	if l != Loc.lang:
		Loc.set_lang(l)
		language_toggled.emit()
	_refresh_lang_buttons()

func _refresh_lang_buttons() -> void:
	Palette.style_button(_btn_ru, Loc.lang == "ru")
	Palette.style_button(_btn_en, Loc.lang == "en")

func _on_toggle_music() -> void:
	var m := get_node_or_null("/root/Music")
	if m != null:
		m.set_enabled(not m.enabled)
	_refresh_music_btn()

func _refresh_music_btn() -> void:
	var on := true
	var m := get_node_or_null("/root/Music")
	if m != null:
		on = m.enabled
	_music_btn.text = "%s: %s" % [Loc.t("set.music"), Loc.t("set.on") if on else Loc.t("set.off")]
	Palette.style_button(_music_btn, on)

func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = Loc.t("common.confirm") + "?"
		return
	_reset_armed = false
	_reset_btn.text = Loc.t("set.reset")
	GameState.reset_save()
	language_toggled.emit()   # форсируем полную пересборку UI
	close()

func open() -> void:
	_reset_armed = false
	_reset_btn.text = Loc.t("set.reset")
	_refresh_lang_buttons()
	_offline_root.visible = false
	_settings_root.visible = true
	visible = true

func close() -> void:
	_settings_root.visible = false
	if not _offline_root.visible:
		visible = false

func show_offline(amount: float) -> void:
	_offline_lbl.text = "+%s \u262A" % Palette.fmt(amount)
	_offline_root.visible = true
	visible = true
