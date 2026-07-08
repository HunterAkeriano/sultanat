extends Control
## SettingsPanel — оверлей настроек (§6.1): язык RU/EN, сброс прогресса,
## «Об игре». Плюс попап офлайн-дохода (§26) при возвращении в игру.

signal language_toggled

var _btn_ru: Button
var _btn_en: Button
var _music_btn: Button
var _fps_btn: Button
var _voice_btn: Button
var _sfx_btn: Button
var _reset_btn: Button
var _reset_armed := false
var _settings_root: Control
var _offline_root: Control
var _offline_lbl: Label
var _offline_x2: Button
var _offline_amount := 0.0

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
	var card_bg := Palette.SURFACE_CONTAINER
	card_bg.a = 0.88   # слегка полупрозрачная — фон просвечивает
	card.add_theme_stylebox_override("panel", Palette.tezhip(card_bg, 12, 18))
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
	_music_btn = Button.new()
	_music_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_glass_button(_music_btn, true)
	_music_btn.pressed.connect(_on_toggle_music)
	v.add_child(_music_btn)
	_refresh_music_btn()

	# ВРЕМЕННО ДЛЯ ТЕСТА: мгновенные жена и наследник
	if GameState.TEST_DEBUG_BUTTONS:
		v.add_child(Palette.label_caps("ТЕСТ", Palette.FS_LABEL, Palette.TERTIARY))
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 8)
		v.add_child(trow)
		var twife := Button.new()
		twife.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		twife.custom_minimum_size = Vector2(0, 40)
		Palette.style_glass_button(twife, false)
		twife.text = "\u2764 Жена"
		twife.pressed.connect(func(): GameState.debug_instant_wife())
		trow.add_child(twife)
		var their := Button.new()
		their.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		their.custom_minimum_size = Vector2(0, 40)
		Palette.style_glass_button(their, false)
		their.text = "\u265A Наследник"
		their.pressed.connect(func(): GameState.debug_instant_heir())
		trow.add_child(their)

	# Кадровая частота: 60 ↔ 120
	_fps_btn = Button.new()
	_fps_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_glass_button(_fps_btn, true)
	_fps_btn.pressed.connect(_on_toggle_fps)
	v.add_child(_fps_btn)
	_refresh_fps_btn()

	# Озвучка (вкл/выкл)
	_voice_btn = Button.new()
	_voice_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_glass_button(_voice_btn, true)
	_voice_btn.pressed.connect(_on_toggle_voice)
	v.add_child(_voice_btn)
	_refresh_voice_btn()

	# Звуки интерфейса (вкл/выкл)
	_sfx_btn = Button.new()
	_sfx_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_glass_button(_sfx_btn, true)
	_sfx_btn.pressed.connect(_on_toggle_sfx)
	v.add_child(_sfx_btn)
	_refresh_sfx_btn()

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

	var sep2 := ColorRect.new()
	sep2.color = Palette.OUTLINE_VARIANT
	sep2.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep2)

	# ── Низ карты (всегда виден): сброс + закрыть ──
	_reset_btn = Button.new()
	_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_glass_button(_reset_btn, false)
	_reset_btn.text = Loc.t("set.reset")
	_reset_btn.pressed.connect(_on_reset)
	outer.add_child(_reset_btn)

	var close_btn := Button.new()
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_glass_button(close_btn, true)
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

	var tughra := Palette.label("\u269C", 28, Palette.PRIMARY, true)
	tughra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tughra)
	var cap := Palette.label(Loc.t("set.offline"), Palette.FS_BODY, Palette.ON_SURFACE_VARIANT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(cap)
	_offline_lbl = Palette.label("+0 \u269C", Palette.FS_HEADLINE, Palette.PRIMARY, true)
	_offline_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_offline_lbl)
	_offline_x2 = Button.new()
	_offline_x2.custom_minimum_size = Vector2(0, 44)
	Palette.style_glass_button(_offline_x2, true)
	_offline_x2.pressed.connect(_on_offline_double)
	v.add_child(_offline_x2)
	var ok := Button.new()
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_glass_button(ok, true)
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
		_rebuild_panel()   # тексты панели «запечены» при build — пересобираем на новом языке
		return
	_refresh_lang_buttons()

func _rebuild_panel() -> void:
	for c in get_children():
		c.queue_free()
	build()
	open()

func _refresh_lang_buttons() -> void:
	Palette.style_glass_button(_btn_ru, Loc.lang == "ru")
	Palette.style_glass_button(_btn_en, Loc.lang == "en")

func _on_toggle_fps() -> void:
	GameState.set_fps_setting(60 if GameState.fps_setting() == 120 else 120)
	_refresh_fps_btn()

func _refresh_fps_btn() -> void:
	var v := GameState.fps_setting()
	_fps_btn.text = "%s: %d" % [Loc.t("set.fps"), v]
	Palette.style_glass_button(_fps_btn, v == 120)

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
	Palette.style_glass_button(_music_btn, on)

func _on_toggle_voice() -> void:
	var vo := get_node_or_null("/root/Voice")
	if vo != null:
		vo.set_enabled(not vo.enabled)
	_refresh_voice_btn()

func _refresh_voice_btn() -> void:
	var on := true
	var vo := get_node_or_null("/root/Voice")
	if vo != null:
		on = vo.enabled
	_voice_btn.text = "%s: %s" % [Loc.t("set.voice"), Loc.t("set.on") if on else Loc.t("set.off")]
	Palette.style_glass_button(_voice_btn, on)

func _on_toggle_sfx() -> void:
	var sx := get_node_or_null("/root/Sfx")
	if sx != null:
		sx.set_enabled(not sx.enabled)
	_refresh_sfx_btn()

func _refresh_sfx_btn() -> void:
	var on := true
	var sx := get_node_or_null("/root/Sfx")
	if sx != null:
		on = sx.enabled
	_sfx_btn.text = "%s: %s" % [Loc.t("set.sfx"), Loc.t("set.on") if on else Loc.t("set.off")]
	Palette.style_glass_button(_sfx_btn, on)

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


func _animate_open() -> void:
	# Плавное открытие: фейд + лёгкий «наезд» (как у древа и дипломатии)
	pivot_offset = size / 2.0
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func open() -> void:
	_reset_armed = false
	_reset_btn.text = Loc.t("set.reset")
	_refresh_lang_buttons()
	_offline_root.visible = false
	_settings_root.visible = true
	var was := visible
	visible = true
	if not was:
		_animate_open()

func close() -> void:
	_settings_root.visible = false
	if not _offline_root.visible:
		visible = false

func _on_offline_double() -> void:
	if _offline_amount <= 0.0:
		return
	GameState.request_rewarded("offline_x2", _grant_offline_double)

func _grant_offline_double() -> void:
	GameState.hazna += _offline_amount
	_offline_lbl.text = "+%s \u269C \u00D72" % Palette.fmt(_offline_amount * 2.0)
	_offline_amount = 0.0
	_offline_x2.visible = false
	GameState.save_game()

func show_offline(amount: float) -> void:
	_offline_amount = amount
	_offline_x2.text = "\u00D72  " + Loc.t("offline.double")
	_offline_x2.visible = amount > 0.0
	_offline_lbl.text = "+%s \u269C" % Palette.fmt(amount)
	_offline_root.visible = true
	var was := visible
	visible = true
	if not was:
		_animate_open()
